"""'Your 2-minute morning brief': per user, generated off-peak (and on demand)."""

import logging
from datetime import timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai import agent, slot
from app.ai.agent import resolve_citations
from app.ai.types import ChatMessage, TextDelta
from app.core.money import format_money, format_percent
from app.core.time import utcnow
from app.db.models import Asset, Digest, Holding, User
from app.db.session import SessionLocal
from app.market_data import service as market
from app.news import service as news_service
from app.services import watchlist as watchlist_service

logger = logging.getLogger(__name__)

MAX_ASSETS = 6
HEADLINES_PER_ASSET = 2
MAX_HEADLINES = 8
NEWS_WINDOW = timedelta(hours=36)

SYSTEM = (
    "You write 'Your 2-minute morning brief' for one investor, using ONLY the facts given. "
    "Format (markdown, at most 200 words):\n"
    "## Your markets\n- one short bullet per asset: today's move only (no reasons here)\n"
    "## In the news\n- 2–4 bullets, each written as 'According to [Source](n1), …' using the "
    "headline's reference\n"
    "## Worth watching today\n- 1–2 bullets on things to keep an eye on (no predictions)\n"
    "Rules: never tell the reader to buy, sell or hold, and never repeat a headline's "
    "buy/sell/'good idea' opinion — describe the topic instead. Only say a headline is about "
    "an asset if the headline names it, and only give a reason for a move if a headline "
    "states it. No metaphors or 'like a …' comparisons; instead explain any finance term in "
    "a few plain words. If there are no headlines, skip that section."
)


async def brief_assets(session: AsyncSession, user: User) -> list[Asset]:
    """The user's portfolio holdings (largest amount invested first, roughly: currencies
    aren't converted here) and watchlist, or popular assets in their markets if both are
    empty."""
    held = await session.execute(
        select(Holding)
        .where(Holding.user_id == user.id)
        .order_by((Holding.quantity * Holding.average_price).desc())
    )
    watchlist = await watchlist_service.get_default(session, user)
    assets = list(
        {
            a.id: a
            for a in [h.asset for h in held.scalars()] + [item.asset for item in watchlist.items]
        }.values()
    )
    if not assets:
        assets = await market.popular_for(session, user.profile)
    return assets[:MAX_ASSETS]


async def build(session: AsyncSession, user: User) -> str | None:
    """Write today's brief text, or None if there is nothing to write about."""
    assets = await brief_assets(session, user)
    if not assets:
        return None
    quotes = await market.quotes_for(assets)

    market_lines = []
    for asset in assets:
        quote = quotes.get(asset.id)
        if quote is None:
            market_lines.append(f"- {asset.name} ({asset.symbol}): price unavailable")
            continue
        change = (
            "no change data"
            if quote.change_percent is None
            else f"{format_percent(quote.change_percent)} vs previous close"
        )
        market_lines.append(
            f"- {asset.name} ({asset.symbol}, {asset.asset_type}): "
            f"{format_money(quote.price, quote.currency or asset.currency)}, {change}"
        )

    sources: dict[str, tuple[str, str]] = {}
    news_lines = []
    since = utcnow() - NEWS_WINDOW
    for asset in assets:
        recent = [
            h
            for h in await news_service.news_for(session, asset, limit=HEADLINES_PER_ASSET * 2)
            if h.published_at >= since
        ][:HEADLINES_PER_ASSET]
        for headline in recent:
            if len(sources) >= MAX_HEADLINES:
                break
            ref = f"n{len(sources) + 1}"
            sources[ref] = (headline.url, headline.source)
            news_lines.append(f"[{ref}] {asset.symbol} — {headline.source}: {headline.title}")

    level = user.profile.experience_level or "beginner"
    name = user.full_name.split()[0] if user.full_name.strip() else "there"
    facts = (
        f"Reader: {name}, experience {level}, risk comfort "
        f"{user.profile.risk_profile or 'unknown'}.\n"
        f"Date: {utcnow():%A %d %B %Y}.\n\n"
        "Markets (latest prices):\n" + "\n".join(market_lines) + "\n\n"
        "Headlines (last 36 hours):\n" + ("\n".join(news_lines) or "(none)")
    )
    text = ""
    async with slot.slot:
        async for event in agent.provider.stream_chat(
            [ChatMessage("system", SYSTEM), ChatMessage("user", facts)], []
        ):
            if isinstance(event, TextDelta):
                text += event.text
    return resolve_citations(text.strip(), sources) or None


async def today_for(session: AsyncSession, user: User) -> Digest | None:
    return (
        await session.execute(
            select(Digest).where(Digest.user_id == user.id, Digest.day == utcnow().date())
        )
    ).scalar_one_or_none()


async def create_today(session: AsyncSession, user: User) -> Digest | None:
    """Today's brief, writing it if needed (one per user per day)."""
    existing = await today_for(session, user)
    if existing is not None:
        return existing
    content = await build(session, user)
    if content is None:
        return None
    digest = Digest(user_id=user.id, day=utcnow().date(), content=content, created_at=utcnow())
    session.add(digest)
    await session.commit()
    return digest


async def write_for(user_id: int) -> None:
    """Background: write today's brief for one user (own database session)."""
    async with SessionLocal() as session:
        user = await session.get(User, user_id)
        if user is not None:
            await create_today(session, user)
