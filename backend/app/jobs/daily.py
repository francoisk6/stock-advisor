"""Once-a-day jobs, recorded in job_runs so restarts don't repeat them."""

import asyncio
import logging
from collections.abc import Awaitable, Callable
from datetime import date, timedelta
from decimal import Decimal

from sqlalchemy import select, union
from sqlalchemy.dialects.mysql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai import digest as digest_service
from app.core.config import settings
from app.core.time import utcnow
from app.db.models import (
    Alert,
    Asset,
    Digest,
    JobRun,
    PriceBarDaily,
    User,
    UserProfile,
    WatchlistItem,
)
from app.db.session import SessionLocal
from app.market_data import service as market
from app.market_data.types import Candle, ProviderError, Range
from app.realtime.hub import hub
from app.schemas.notifications import notification_out
from app.services import notifications as notifications_service
from app.services.email import digest_email, send_email

logger = logging.getLogger(__name__)

PAUSE_BETWEEN_ASSETS_SECONDS = 1.0  # gentle on free sources and the shared server
# A run still marked "running" after this long was cut off (crash, restart, --reload).
ABANDONED_AFTER = timedelta(hours=1)


async def run_once_per_day(
    name: str, day: date, job: Callable[[AsyncSession], Awaitable[str]]
) -> bool:
    """Run `job` unless it already ran (or is running) for `day`. Returns True if it ran."""
    async with SessionLocal() as session:
        run = await session.get(JobRun, (name, day))
        if run is not None:
            abandoned = run.status == "running" and utcnow() - run.started_at > ABANDONED_AFTER
            if not abandoned:
                return False
            logger.warning("Daily job %s for %s was cut off; running it again", name, day)
            run.started_at, run.finished_at, run.detail = utcnow(), None, None
        else:
            run = JobRun(name=name, day=day, started_at=utcnow(), status="running")
            session.add(run)
        await session.commit()
        try:
            detail = await job(session)
            run.status, run.detail = "done", detail[:500]
        except Exception as exc:
            logger.exception("Daily job %s failed", name)
            run.status, run.detail = "failed", str(exc)[:500]
        run.finished_at = utcnow()
        await session.commit()
        return True


Bar = tuple[float, float, float, float, float | None]  # open, high, low, close, volume


def daily_bars(candles: list[Candle]) -> dict[date, Bar]:
    """Group intraday or daily candles into one bar per UTC day (open, high, low, close, vol)."""
    days: dict[date, list[Candle]] = {}
    for candle in sorted(candles, key=lambda c: c.time):
        days.setdefault(candle.time.date(), []).append(candle)
    bars = {}
    for day, group in days.items():
        volumes = [c.volume for c in group if c.volume is not None]
        bars[day] = (
            group[0].open,
            max(c.high for c in group),
            min(c.low for c in group),
            group[-1].close,
            sum(volumes) if volumes else None,
        )
    return bars


async def tracked_assets(session: AsyncSession) -> list[Asset]:
    """Curated catalog + anything on a watchlist or with an alert."""
    ids = union(
        select(Asset.id).where(Asset.popularity.is_not(None), Asset.is_active.is_(True)),
        select(WatchlistItem.asset_id),
        select(Alert.asset_id),
    ).subquery()
    result = await session.execute(select(Asset).where(Asset.id.in_(select(ids))))
    return list(result.scalars())


def _dec(value: float | None) -> Decimal | None:
    return None if value is None else Decimal(str(value))


async def store_daily_prices(session: AsyncSession) -> str:
    """Save the last month of daily bars for tracked assets (today excluded: not final)."""
    today = utcnow().date()
    saved = failed = 0
    for asset in await tracked_assets(session):
        try:
            candles = await market.providers[asset.provider].history(
                asset.provider_symbol, Range.m1
            )
        except ProviderError:
            failed += 1
            continue
        rows = [
            {
                "asset_id": asset.id,
                "day": day,
                "open": _dec(o),
                "high": _dec(h),
                "low": _dec(lo),
                "close": _dec(c),
                "volume": _dec(v),
            }
            for day, (o, h, lo, c, v) in daily_bars(candles).items()
            if day < today
        ]
        if rows:
            stmt = insert(PriceBarDaily).values(rows)
            await session.execute(
                stmt.on_duplicate_key_update(
                    open=stmt.inserted.open,
                    high=stmt.inserted.high,
                    low=stmt.inserted.low,
                    close=stmt.inserted.close,
                    volume=stmt.inserted.volume,
                )
            )
            await session.commit()
            saved += len(rows)
        await asyncio.sleep(PAUSE_BETWEEN_ASSETS_SECONDS)
    return f"{saved} daily bars saved, {failed} assets unavailable"


async def morning_briefs(session: AsyncSession) -> str:
    """Write today's brief for every active, onboarded user (one at a time, off-peak)."""
    users = list(
        (
            await session.execute(
                select(User)
                .join(UserProfile)
                .where(User.is_active.is_(True), UserProfile.onboarding_completed_at.is_not(None))
            )
        ).scalars()
    )
    written = 0
    for user in users:
        try:
            if await digest_service.today_for(session, user) is not None:
                continue
            digest = await digest_service.create_today(session, user)
        except Exception:
            logger.exception("Morning brief failed for user %s", user.id)
            continue
        if digest is None:
            continue
        written += 1
        await deliver_brief(session, user, digest)
    return f"{written} briefs written for {len(users)} users"


async def deliver_brief(session: AsyncSession, user: User, digest: Digest) -> None:
    """In-app notification (live if the app is open) + email when the user asked for it."""
    notification = notifications_service.build(
        user.id,
        "digest",
        "Your morning brief is ready",
        "What moved in your markets, the news behind it, and what to watch today.",
    )
    session.add(notification)
    await session.commit()
    await hub.notify_user(
        user.id,
        {
            "type": "notification",
            "notification": notification_out(notification).model_dump(mode="json"),
            "unread_count": await notifications_service.unread_count(session, user.id),
        },
    )
    if user.profile.digest_email and user.email_verified and digest.emailed_at is None:
        first_name = user.full_name.split()[0] if user.full_name.strip() else ""
        await send_email(
            digest_email(
                user.email,
                first_name,
                digest.content,
                f"{settings.frontend_url.rstrip('/')}/brief",
            )
        )
        digest.emailed_at = utcnow()
        await session.commit()
