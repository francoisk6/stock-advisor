"""Tools the copilot can call. Results are compact JSON facts (with source + time) for the model;
app actions also return a card the chat shows (and the user can undo from)."""

from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation
from typing import Any

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.types import ToolCall, ToolSpec
from app.core.errors import AppError
from app.db.models import Asset, User
from app.market_data import service as market
from app.market_data.types import Quote, Range
from app.services import alerts as alerts_service
from app.services import watchlist as watchlist_service

ASSET_PARAM = {
    "type": "string",
    "description": "Ticker symbol or name, e.g. AAPL, 2222.SR, Bitcoin, EUR/USD, Gold",
}


@dataclass
class ToolResult:
    data: dict[str, Any]
    action: dict[str, Any] | None = None


@dataclass
class ToolContext:
    session: AsyncSession
    user: User


Handler = Callable[[ToolContext, dict[str, Any]], Awaitable[ToolResult]]


@dataclass
class Tool:
    spec: ToolSpec
    handler: Handler
    status: Callable[[dict[str, Any]], str]  # shown to the user while it runs


# --- helpers ------------------------------------------------------------------------------


async def resolve_asset(session: AsyncSession, query: str) -> Asset | None:
    """Exact symbol in our catalog first (curated before others), otherwise a search."""
    q = (query or "").strip()
    if not q:
        return None
    result = await session.execute(
        select(Asset)
        .where(
            Asset.is_active.is_(True),
            or_(Asset.symbol == q, Asset.provider_symbol == q, Asset.name == q),
        )
        .order_by(Asset.popularity.is_(None), Asset.popularity)
        .limit(1)
    )
    asset = result.scalar_one_or_none()
    if asset is not None:
        return asset
    hits = await market.search(session, q, limit=5)
    return hits[0] if hits else None


def _asset_brief(asset: Asset) -> dict[str, Any]:
    return {
        "symbol": asset.symbol,
        "name": asset.name,
        "type": asset.asset_type,
        "exchange": asset.exchange,
        "currency": asset.currency,
    }


def _quote_facts(quote: Quote | None, asset: Asset) -> dict[str, Any]:
    if quote is None:
        return {"price": None, "note": "No price available right now."}
    return {
        "price": round(quote.price, 6),
        "currency": quote.currency or asset.currency,
        "change_percent_today": (
            None if quote.change_percent is None else round(quote.change_percent, 2)
        ),
        "market_open": quote.market_open,
        "as_of_utc": quote.as_of.isoformat(timespec="minutes"),
        "source": market.SOURCE_NAMES.get(asset.provider, asset.provider),
    }


def _not_found(query: str) -> ToolResult:
    return ToolResult({"error": f"No asset found for '{query}'. Try search_assets."})


async def _with_asset(
    ctx: ToolContext, args: dict[str, Any], run: Callable[[Asset], Awaitable[ToolResult]]
) -> ToolResult:
    query = str(args.get("asset", ""))
    asset = await resolve_asset(ctx.session, query)
    if asset is None:
        return _not_found(query)
    try:
        return await run(asset)
    except AppError as exc:  # e.g. plan limit, data source down: let the model explain
        return ToolResult({"error": exc.message})


# --- handlers -----------------------------------------------------------------------------


async def search_assets(ctx: ToolContext, args: dict[str, Any]) -> ToolResult:
    hits = await market.search(ctx.session, str(args.get("query", "")), limit=5)
    return ToolResult({"results": [_asset_brief(a) for a in hits]})


async def get_quote(ctx: ToolContext, args: dict[str, Any]) -> ToolResult:
    async def run(asset: Asset) -> ToolResult:
        quotes = await market.quotes_for([asset])
        return ToolResult({**_asset_brief(asset), **_quote_facts(quotes.get(asset.id), asset)})

    return await _with_asset(ctx, args, run)


async def get_asset_details(ctx: ToolContext, args: dict[str, Any]) -> ToolResult:
    async def run(asset: Asset) -> ToolResult:
        details = await market.details_for(ctx.session, asset)
        description = (details.description or "")[:600]
        return ToolResult(
            {
                **_asset_brief(asset),
                **_quote_facts(details.quote, asset),
                "key_figures": {s.key: s.value for s in details.stats},
                "about": description or None,
            }
        )

    return await _with_asset(ctx, args, run)


async def get_price_history(ctx: ToolContext, args: dict[str, Any]) -> ToolResult:
    try:
        range_ = Range(str(args.get("range", "1M")).upper())
    except ValueError:
        range_ = Range.m1

    async def run(asset: Asset) -> ToolResult:
        candles = await market.history_for(asset, range_)
        if len(candles) < 2:
            return ToolResult({"error": "Not enough price data for this period."})
        high = max(candles, key=lambda c: c.high)
        low = min(candles, key=lambda c: c.low)
        first, last = candles[0], candles[-1]
        return ToolResult(
            {
                **_asset_brief(asset),
                "range": range_.value,
                "from_utc": first.time.isoformat(timespec="minutes"),
                "to_utc": last.time.isoformat(timespec="minutes"),
                "start_price": round(first.open, 6),
                "end_price": round(last.close, 6),
                "change_percent": round((last.close - first.open) / first.open * 100, 2),
                "highest": {"price": round(high.high, 6), "date": high.time.date().isoformat()},
                "lowest": {"price": round(low.low, 6), "date": low.time.date().isoformat()},
                "source": market.SOURCE_NAMES.get(asset.provider, asset.provider),
            }
        )

    return await _with_asset(ctx, args, run)


async def get_watchlist(ctx: ToolContext, args: dict[str, Any]) -> ToolResult:
    watchlist = await watchlist_service.get_default(ctx.session, ctx.user)
    assets = [item.asset for item in watchlist.items]
    quotes = await market.quotes_for(assets)
    return ToolResult(
        {"items": [{**_asset_brief(a), **_quote_facts(quotes.get(a.id), a)} for a in assets]}
    )


async def add_to_watchlist(ctx: ToolContext, args: dict[str, Any]) -> ToolResult:
    async def run(asset: Asset) -> ToolResult:
        await watchlist_service.add(ctx.session, ctx.user, asset)
        return ToolResult(
            {"done": True, "added": asset.symbol},
            {
                "type": "watchlist_added",
                "asset_id": asset.id,
                "symbol": asset.symbol,
                "name": asset.name,
            },
        )

    return await _with_asset(ctx, args, run)


async def remove_from_watchlist(ctx: ToolContext, args: dict[str, Any]) -> ToolResult:
    async def run(asset: Asset) -> ToolResult:
        await watchlist_service.remove(ctx.session, ctx.user, asset.id)
        return ToolResult(
            {"done": True, "removed": asset.symbol},
            {
                "type": "watchlist_removed",
                "asset_id": asset.id,
                "symbol": asset.symbol,
                "name": asset.name,
            },
        )

    return await _with_asset(ctx, args, run)


async def create_alert(ctx: ToolContext, args: dict[str, Any]) -> ToolResult:
    try:
        kind = alerts_service.AlertKind(str(args.get("kind")))
        threshold = Decimal(str(args.get("threshold")))
    except (ValueError, InvalidOperation):
        return ToolResult(
            {
                "error": "kind must be price_above, price_below, move_up or move_down; "
                "threshold must be a number."
            }
        )

    async def run(asset: Asset) -> ToolResult:
        alert = await alerts_service.create(ctx.session, ctx.user, asset, kind, threshold, True)
        return ToolResult(
            {
                "done": True,
                "alert_id": alert.id,
                "kind": kind.value,
                "threshold": float(threshold),
                "asset": asset.symbol,
            },
            {
                "type": "alert_created",
                "alert_id": alert.id,
                "asset_id": asset.id,
                "symbol": asset.symbol,
                "name": asset.name,
                "kind": kind.value,
                "threshold": float(threshold),
                "currency": asset.currency,
            },
        )

    return await _with_asset(ctx, args, run)


async def list_alerts(ctx: ToolContext, args: dict[str, Any]) -> ToolResult:
    alerts = await alerts_service.list_for_user(ctx.session, ctx.user)
    return ToolResult(
        {
            "alerts": [
                {
                    "asset": a.asset.symbol,
                    "kind": a.kind,
                    "threshold": float(a.threshold),
                    "active": a.is_active,
                }
                for a in alerts
            ]
        }
    )


# --- registry -----------------------------------------------------------------------------


def _spec(name: str, description: str, properties: dict[str, Any], required: list[str]) -> ToolSpec:
    return ToolSpec(
        name, description, {"type": "object", "properties": properties, "required": required}
    )


TOOLS: dict[str, Tool] = {
    t.spec.name: t
    for t in [
        Tool(
            _spec(
                "search_assets",
                "Find stocks, ETFs, crypto, currencies or commodities by name or ticker.",
                {"query": {"type": "string"}},
                ["query"],
            ),
            search_assets,
            lambda a: f"Searching for “{a.get('query', '')}”…",
        ),
        Tool(
            _spec(
                "get_quote",
                "Latest price and today's change for one asset.",
                {"asset": ASSET_PARAM},
                ["asset"],
            ),
            get_quote,
            lambda a: f"Looking up the price of {a.get('asset', '')}…",
        ),
        Tool(
            _spec(
                "get_asset_details",
                "Price, key figures (market cap, P/E, dividend yield, "
                "52-week range…) and a short description of one asset.",
                {"asset": ASSET_PARAM},
                ["asset"],
            ),
            get_asset_details,
            lambda a: f"Checking the key figures of {a.get('asset', '')}…",
        ),
        Tool(
            _spec(
                "get_price_history",
                "How the price moved over a period: start, end, change %, highest and lowest.",
                {
                    "asset": ASSET_PARAM,
                    "range": {"type": "string", "enum": [r.value for r in Range]},
                },
                ["asset", "range"],
            ),
            get_price_history,
            lambda a: f"Looking at {a.get('asset', '')} over {a.get('range', '1M')}…",
        ),
        Tool(
            _spec("get_watchlist", "The user's watchlist with latest prices.", {}, []),
            get_watchlist,
            lambda a: "Checking your watchlist…",
        ),
        Tool(
            _spec(
                "add_to_watchlist",
                "Add an asset to the user's watchlist.",
                {"asset": ASSET_PARAM},
                ["asset"],
            ),
            add_to_watchlist,
            lambda a: f"Adding {a.get('asset', '')} to your watchlist…",
        ),
        Tool(
            _spec(
                "remove_from_watchlist",
                "Remove an asset from the user's watchlist.",
                {"asset": ASSET_PARAM},
                ["asset"],
            ),
            remove_from_watchlist,
            lambda a: f"Removing {a.get('asset', '')} from your watchlist…",
        ),
        Tool(
            _spec(
                "create_alert",
                "Create a price alert. price_above/price_below use a price "
                "in the asset's currency; move_up/move_down use a daily percent (e.g. 5).",
                {
                    "asset": ASSET_PARAM,
                    "kind": {"type": "string", "enum": [k.value for k in alerts_service.AlertKind]},
                    "threshold": {"type": "number"},
                },
                ["asset", "kind", "threshold"],
            ),
            create_alert,
            lambda a: f"Creating an alert for {a.get('asset', '')}…",
        ),
        Tool(
            _spec("list_alerts", "The user's price alerts.", {}, []),
            list_alerts,
            lambda a: "Checking your alerts…",
        ),
    ]
}

SPECS = [t.spec for t in TOOLS.values()]


async def run_tool(ctx: ToolContext, call: ToolCall) -> ToolResult:
    tool = TOOLS.get(call.name)
    if tool is None:
        return ToolResult({"error": f"Unknown tool {call.name}."})
    return await tool.handler(ctx, call.arguments)


def status_text(call: ToolCall) -> str:
    tool = TOOLS.get(call.name)
    return tool.status(call.arguments) if tool else "Working on it…"
