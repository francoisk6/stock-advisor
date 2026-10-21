from dataclasses import dataclass
from datetime import datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.core.time import utcnow
from app.db.models import Alert, Holding, Plan, User, UserPlan, UserProfile
from app.services.users import active_plan


class PlanLimitReached(AppError):
    status_code = 403
    code = "plan_limit"


PRO_SOON = "Pro (coming soon) has no limit."

# Limits the app shows, in display order (keys of Plan.limits).
SHOWN_LIMITS = ("ai_messages_per_day", "watchlist_assets", "alerts", "portfolio_holdings")


def plan_limit(user: User, key: str) -> int | None:
    """The user's limit for `key` (None = unlimited)."""
    value = active_plan(user).limits.get(key)
    return None if value is None else int(value)


def check_limit(user: User, key: str, current: int, message: str) -> None:
    limit = plan_limit(user, key)
    if limit is not None and current >= limit:
        raise PlanLimitReached(message.format(limit=limit, plan=active_plan(user).name))


async def plans(session: AsyncSession) -> list[Plan]:
    result = await session.execute(select(Plan).where(Plan.code.in_(("free", "pro"))))
    return sorted(result.scalars(), key=lambda p: p.code != "free")


@dataclass
class Usage:
    key: str
    used: int
    limit: int | None  # None = unlimited


async def usage(session: AsyncSession, user: User) -> list[Usage]:
    """What the user has used of each limit the app shows."""
    from app.services import chat as chat_service  # chat imports plans indirectly
    from app.services import watchlist as watchlist_service

    async def count(model, *where) -> int:
        result = await session.execute(select(func.count()).select_from(model).where(*where))
        return int(result.scalar_one())

    watchlist = await watchlist_service.get_default(session, user)
    used = {
        "ai_messages_per_day": await chat_service.answers_today(session, user),
        "watchlist_assets": len(watchlist.items),
        "alerts": await count(Alert, Alert.user_id == user.id, Alert.is_active.is_(True)),
        "portfolio_holdings": await count(Holding, Holding.user_id == user.id),
    }
    return [Usage(key, used[key], plan_limit(user, key)) for key in SHOWN_LIMITS]


async def register_pro_interest(session: AsyncSession, user: User) -> None:
    if user.profile.pro_interest_at is None:
        user.profile.pro_interest_at = utcnow()
        await session.commit()


# --- testers (no payments yet) -------------------------------------------------------------

TESTER_REF = "tester"


async def grant_pro(session: AsyncSession, user: User, days: int | None) -> UserPlan:
    """Give a tester Pro for `days` (None: until revoked). Recorded as an internal grant, so
    real subscriptions (Stripe / stores) can sit next to it later."""
    pro = (await session.execute(select(Plan).where(Plan.code == "pro"))).scalar_one()
    now = utcnow()
    grant = UserPlan(
        user_id=user.id,
        plan_id=pro.id,
        status="active",
        started_at=now,
        ends_at=None if days is None else now + timedelta(days=days),
        provider="internal",
        provider_ref=TESTER_REF,
    )
    session.add(grant)
    await session.commit()
    return grant


async def revoke_pro(session: AsyncSession, user: User) -> int:
    """End a tester's internal Pro grants now; returns how many were active."""
    now = utcnow()
    rows = await session.execute(
        select(UserPlan)
        .join(Plan)
        .where(
            UserPlan.user_id == user.id,
            Plan.code == "pro",
            UserPlan.provider == "internal",
            UserPlan.status == "active",
        )
    )
    ended = 0
    for grant in rows.scalars():
        if grant.ends_at is None or grant.ends_at > now:
            ended += 1
        grant.status = "ended"
        grant.ends_at = min(grant.ends_at or now, now)
    await session.commit()
    return ended


async def pro_interest(session: AsyncSession) -> list[tuple[str, str, datetime]]:
    """(email, name, when) of everyone who asked to hear when Pro is ready."""
    rows = await session.execute(
        select(User.email, User.full_name, UserProfile.pro_interest_at)
        .join(UserProfile, UserProfile.user_id == User.id)
        .where(UserProfile.pro_interest_at.is_not(None), User.is_active.is_(True))
        .order_by(UserProfile.pro_interest_at)
    )
    return [tuple(r) for r in rows.all()]
