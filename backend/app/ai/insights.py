"""'Why did it move?': a short AI summary of today's headlines for one asset, shared by all
users (one per asset per UTC day, refreshed every few hours)."""

from datetime import timedelta
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai import agent, slot
from app.ai.agent import resolve_citations
from app.ai.types import ChatMessage, TextDelta
from app.core.errors import AppError
from app.core.money import format_money, format_percent
from app.core.time import utcnow
from app.db.models import Asset, AssetInsight
from app.db.session import SessionLocal
from app.market_data import service as market
from app.news import service as news_service

MIN_MOVE_PERCENT = 2.0
REFRESH_AFTER = timedelta(hours=3)
NO_NEWS = (
    "We couldn't find news from the last few days that explains today's move. Prices "
    "sometimes move without one clear reason — for example when many investors buy or sell "
    "at the same time."
)

SYSTEM = (
    "You explain to a beginner investor why an asset's price moved today, using ONLY the "
    "headlines given. Write at most 90 words: one sentence on the move, then the 1–3 most "
    "relevant reasons from the headlines, each with its source as a markdown link using the "
    "headline's reference, e.g. [Reuters](n1). Say 'according to' — headlines are reports, not "
    "facts. If no headline explains the move, say so plainly. No predictions, no advice to buy "
    "or sell. Plain words; explain any finance term in a few words."
)


class InsightUnavailable(AppError):
    status_code = 503


async def cached(session: AsyncSession, asset: Asset) -> AssetInsight | None:
    """Today's explanation if it's still fresh."""
    existing = (
        await session.execute(
            select(AssetInsight).where(
                AssetInsight.asset_id == asset.id,
                AssetInsight.kind == "why_move",
                AssetInsight.day == utcnow().date(),
            )
        )
    ).scalar_one_or_none()
    if existing is not None and utcnow() - existing.created_at < REFRESH_AFTER:
        return existing
    return None


async def check_move(asset: Asset) -> None:
    """Fast checks before writing: raises a friendly error on normal days / missing prices."""
    quote = (await market.quotes_for([asset])).get(asset.id)
    if quote is None or quote.change_percent is None:
        raise InsightUnavailable("Today's price isn't available yet, so we can't explain it.")
    if abs(quote.change_percent) < MIN_MOVE_PERCENT:
        raise AppError(
            f"{asset.symbol} moved only {format_percent(quote.change_percent)} today — "
            "that's a normal day, so there's nothing special to explain."
        )


async def write(asset_id: int) -> None:
    """Write (or refresh) today's explanation. Slow: runs in the background, own session."""
    async with SessionLocal() as session:
        asset = await session.get(Asset, asset_id)
        if asset is None:
            return
        quote = (await market.quotes_for([asset])).get(asset.id)
        if quote is None or quote.change_percent is None:
            return
        headlines = await news_service.news_for(session, asset, limit=8)
        if not headlines:
            content = NO_NEWS
        else:
            sources = {f"n{i}": (h.url, h.source) for i, h in enumerate(headlines, 1)}
            lines = "\n".join(
                f"[n{i}] {h.published_at:%Y-%m-%d %H:%M} UTC — {h.source}: {h.title}"
                for i, h in enumerate(headlines, 1)
            )
            facts = (
                f"Asset: {asset.name} ({asset.symbol}, {asset.asset_type}).\n"
                f"Today: {format_percent(quote.change_percent)} to "
                f"{format_money(quote.price, quote.currency or asset.currency)} "
                f"(data from {market.SOURCE_NAMES.get(asset.provider, asset.provider)}).\n"
                f"Headlines (newest first):\n{lines}"
            )
            text = ""
            async with slot.slot:
                async for event in agent.provider.stream_chat(
                    [ChatMessage("system", SYSTEM), ChatMessage("user", facts)], []
                ):
                    if isinstance(event, TextDelta):
                        text += event.text
            content = resolve_citations(text.strip(), sources) or NO_NEWS

        today = utcnow().date()
        existing = (
            await session.execute(
                select(AssetInsight).where(
                    AssetInsight.asset_id == asset.id,
                    AssetInsight.kind == "why_move",
                    AssetInsight.day == today,
                )
            )
        ).scalar_one_or_none()
        if existing is None:
            existing = AssetInsight(asset_id=asset.id, kind="why_move", day=today, content=content)
            session.add(existing)
        existing.content = content
        existing.change_percent = Decimal(str(round(quote.change_percent, 4)))
        existing.created_at = utcnow()
        await session.commit()
