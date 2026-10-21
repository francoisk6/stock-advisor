"""Tools the copilot can call. Results are compact JSON facts (with source + time) for the model;
app actions also return a card the chat shows (and the user can undo from)."""

import re
from collections.abc import Awaitable, Callable
from dataclasses import dataclass, field
from decimal import Decimal, InvalidOperation
from typing import Any
from urllib.parse import urlparse

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.types import ToolCall, ToolSpec
from app.core.errors import AppError
from app.db.models import Asset, User
from app.db.session import SessionLocal
from app.learn import glossary
from app.market_data import service as market
from app.market_data.types import ProviderError, Quote, Range
from app.news import service as news_service
from app.news import web_search as web
from app.repositories import assets as assets_repo
from app.services import alerts as alerts_service
from app.services import portfolio as portfolio_service
from app.services import practice as practice_service
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
    # Short references the model cites ("n1", "w2") -> (url, source name), swapped in after
    # the answer.
    sources: dict[str, tuple[str, str]] = field(default_factory=dict)
    question: str = ""  # the user's message this turn (checks that trades were asked for)

    def cite(self, prefix: str, url: str, label: str) -> str:
        for ref, (known, _) in self.sources.items():
            if known == url:
                return ref
        ref = f"{prefix}{sum(r.startswith(prefix) for r in self.sources) + 1}"
        self.sources[ref] = (url, label)
        return ref


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
    # Our curated catalog before the providers' search: "Saudi Aramco" must be 2222.SR, not a
    # smaller company whose name happens to start with the same words.
    local = await assets_repo.search_local(session, q, limit=5)
    curated = [a for a in local if a.popularity is not None]
    if curated or local:
        return (curated or local)[0]
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
            {"done": True, "added": _asset_brief(asset)},
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
            {"done": True, "removed": _asset_brief(asset)},
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
                "asset": _asset_brief(asset),
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


async def get_news(ctx: ToolContext, args: dict[str, Any]) -> ToolResult:
    async def run(asset: Asset) -> ToolResult:
        articles = await news_service.news_for(ctx.session, asset, limit=6)
        if not articles:
            return ToolResult(
                {"asset": asset.symbol, "headlines": [], "note": "No news from the last 7 days."}
            )
        return ToolResult(
            {
                "asset": asset.symbol,
                "headlines": [
                    {
                        "title": a.title,
                        "source": a.source,
                        "published_utc": a.published_at.isoformat(timespec="minutes"),
                        "link": ctx.cite("n", a.url, a.source),
                    }
                    for a in articles
                ],
            }
        )

    return await _with_asset(ctx, args, run)


async def web_search(ctx: ToolContext, args: dict[str, Any]) -> ToolResult:
    query = str(args.get("query", "")).strip()
    if not query:
        return ToolResult({"error": "Please give a search query."})
    try:
        results = await web.search(query)
    except ProviderError:
        return ToolResult({"error": "Web search is unavailable right now."})
    return ToolResult(
        {
            "results": [
                {
                    "title": r.title,
                    "snippet": r.snippet,
                    "link": ctx.cite("w", r.url, urlparse(r.url).netloc.removeprefix("www.")),
                }
                for r in results
            ]
        }
    )


async def explain_term(ctx: ToolContext, args: dict[str, Any]) -> ToolResult:
    term = glossary.find(str(args.get("term", "")))
    if term is None:
        return ToolResult(
            {
                "found": False,
                "note": "Not in the app's glossary. Explain it briefly in plain words, or use "
                "web_search if you are not sure what it means.",
            }
        )
    return ToolResult(
        {
            "found": True,
            "term": term.term,
            "short": term.short,
            "explanation": term.body,
            "example": term.example,
        },
        # A link to the full glossary entry (nothing to undo).
        action={"type": "glossary_term", "term_id": term.id, "name": term.term},
    )


def _money(value: Any) -> float:
    return round(float(value), 2)


async def get_practice_account(ctx: ToolContext, args: dict[str, Any]) -> ToolResult:
    s = await practice_service.summary(ctx.session, ctx.user)
    start = s.account.starting_cash
    return ToolResult(
        {
            "note": "Practice account: virtual US dollars, real prices. Not real money.",
            "started_utc": s.account.started_at.date().isoformat(),
            "starting_cash_usd": _money(start),
            "cash_usd": _money(s.account.cash),
            "available_cash_usd": _money(s.available_cash),
            "total_value_usd": _money(s.total_value),
            "gain_usd": _money(s.gain_usd),
            "gain_percent": round(float(s.gain_usd / start * 100), 2),
            "realized_gain_usd": _money(s.realized_usd),
            "positions": [
                {
                    "symbol": v.position.asset.symbol,
                    "name": v.position.asset.name,
                    "quantity": float(v.position.quantity),
                    "value_usd": None if v.value_usd is None else _money(v.value_usd),
                    "cost_usd": _money(v.position.cost_usd),
                    "gain_usd": None if v.gain_usd is None else _money(v.gain_usd),
                }
                for v in s.positions
            ],
            "waiting_orders": [
                {
                    "side": o.side,
                    "symbol": o.asset.symbol,
                    "quantity": None if o.quantity is None else float(o.quantity),
                    "amount_usd": None if o.amount_usd is None else _money(o.amount_usd),
                    "note": "waits for the market to open",
                }
                for o in s.pending
            ],
        }
    )


# Plain descriptions of the portfolio risk notes, for the model.
RISK_TEXT = {
    "concentration": "{symbol} is {percent}% of the portfolio; if it fell 30%, the whole "
    "portfolio would fall about {drop_if_30}%.",
    "crypto_share": "{percent}% is in crypto, which can swing a lot in a day.",
    "foreign_currency": "{percent}% is priced in currencies other than {currency}, so "
    "exchange rates move its value too.",
    "few_holdings": "Only {count} holdings: one bad result matters a lot.",
    "one_region": "Everything is in one region ({region}).",
    "spread": "Spread over {count} holdings; the biggest is {top_percent}%.",
}


async def get_portfolio(ctx: ToolContext, args: dict[str, Any]) -> ToolResult:
    p = await portfolio_service.summary(ctx.session, ctx.user)
    if not p.holdings:
        return ToolResult({"holdings": [], "note": "The user hasn't added any holdings yet."})
    cur = p.currency
    return ToolResult(
        {
            "note": f"Real holdings the user entered by hand; values in {cur} at today's "
            "exchange rates.",
            "currency": cur,
            "total_value": _money(p.total_value),
            "gain": _money(p.gain),
            "change_today": _money(p.day_change),
            "holdings": [
                {
                    "symbol": h.holding.asset.symbol,
                    "name": h.holding.asset.name,
                    "quantity": float(h.holding.quantity),
                    "value": None if h.value is None else _money(h.value),
                    "gain": None if h.gain is None else _money(h.gain),
                    "share_percent": None if h.value is None else round(p.share(h.value), 1),
                }
                for h in p.holdings
            ],
            "by_type_percent": {k: round(p.share(v), 1) for k, v in p.by_type.items()},
            "risk_notes": [RISK_TEXT[r.code].format(**r.params) for r in p.risks],
        }
    )


def practice_card(order: Any, asset: Asset) -> dict[str, Any]:
    def f(value: Decimal | None) -> float | None:
        return None if value is None else float(value)

    return {
        "type": "practice_order",
        "order_id": order.id,
        "asset_id": asset.id,
        "symbol": asset.symbol,
        "name": asset.name,
        "side": order.side,
        "status": order.status,
        "quantity": f(
            order.filled_quantity if order.filled_quantity is not None else order.quantity
        ),
        "amount_usd": f(order.amount_usd),
        "total_usd": f(order.total_usd),
        "note": order.note,
    }


# A trade size the user actually gave: a number, or "all"/"everything"/"half".
_SIZE_GIVEN = re.compile(r"\d|\b(all|everything|half|whole)\b", re.IGNORECASE)
_SELL_ALL = re.compile(r"\b(all|everything|whole)\b", re.IGNORECASE)
_NUMBER = re.compile(r"\d[\d,]*(?:\.\d+)?")


async def practice_trade(ctx: ToolContext, args: dict[str, Any]) -> ToolResult:
    if ctx.question and not _SIZE_GIVEN.search(ctx.question):
        # The model picked "$500" for "I want to buy some Apple": never trade a made-up size.
        return ToolResult(
            {
                "error": "The user didn't say how much. Don't trade yet: ask how much they "
                "want to buy or sell, in dollars or units, in their practice account."
            }
        )
    try:
        side = practice_service.Side(str(args.get("side", "")).lower())
    except ValueError:
        return ToolResult({"error": "side must be buy or sell."})
    raw_quantity = args.get("quantity")
    sell_all = str(raw_quantity).strip().lower() == "all"
    if side == practice_service.Side.sell and _SELL_ALL.search(ctx.question):
        # "Sell all my bitcoin": the model once passed a dollar amount from an earlier turn.
        sell_all, raw_quantity, args = True, None, {**args, "amount_usd": None}
    try:
        quantity = None if raw_quantity in (None, "") or sell_all else Decimal(str(raw_quantity))
        amount = args.get("amount_usd")
        amount_usd = None if amount in (None, "") else Decimal(str(amount).lstrip("$"))
    except InvalidOperation:
        return ToolResult({"error": "quantity and amount_usd must be numbers."})
    given = amount_usd if amount_usd is not None else quantity
    numbers = {Decimal(n.replace(",", "")) for n in _NUMBER.findall(ctx.question)}
    if given is not None and numbers and given not in numbers:
        return ToolResult(
            {
                "error": f"The user's message doesn't mention {given}. Use exactly the amount "
                "they gave, or ask them how much."
            }
        )

    async def run(asset: Asset) -> ToolResult:
        # Own session: a refused order must not leave the chat's session holding a row lock.
        async with SessionLocal() as session:
            user = await session.get(User, ctx.user.id)
            own_asset = await session.get(Asset, asset.id)
            nonlocal quantity
            if sell_all and side == practice_service.Side.sell:
                _, quantity = await practice_service.cash_and_holding(session, user, asset.id)
                if not quantity:
                    return ToolResult({"error": f"There is no {asset.symbol} to sell."})
            order = await practice_service.place_order(
                session,
                user,
                own_asset,
                side,
                quantity=quantity,
                amount_usd=amount_usd,
                source="copilot",
            )
            card = practice_card(order, own_asset)
        result = {k: v for k, v in card.items() if k not in ("type", "order_id", "asset_id")}
        result["practice_money"] = True
        if order.status == "pending":
            result["note"] = "The market is closed; the order waits and fills when it opens."
        return ToolResult(result, card)

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
            _spec(
                "get_news",
                "Latest news headlines about one asset (last 7 days), with "
                "source, time and a link reference to cite.",
                {"asset": ASSET_PARAM},
                ["asset"],
            ),
            get_news,
            lambda a: f"Reading the latest news about {a.get('asset', '')}…",
        ),
        Tool(
            _spec(
                "web_search",
                "Search the web for general questions (definitions, events, "
                "companies). Returns titles, snippets and link references to cite.",
                {"query": {"type": "string"}},
                ["query"],
            ),
            web_search,
            lambda a: f"Searching the web for “{a.get('query', '')}”…",
        ),
        Tool(
            _spec(
                "explain_term",
                "The app's vetted plain-language explanation of an investing term "
                "(P/E ratio, ETF, volatility, market cap, dividend, …). Use it for "
                "'what is / what does … mean' questions.",
                {"term": {"type": "string", "description": "The term, e.g. 'P/E ratio'"}},
                ["term"],
            ),
            explain_term,
            lambda a: f"Looking up “{a.get('term', '')}” in the glossary…",
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
            _spec(
                "get_portfolio",
                "The user's REAL portfolio (holdings they entered by hand): value, gains, "
                "allocation and risk notes. Read-only.",
                {},
                [],
            ),
            get_portfolio,
            lambda a: "Looking at your portfolio…",
        ),
        Tool(
            _spec(
                "get_practice_account",
                "The user's practice account (virtual dollars, real prices): cash, "
                "holdings, gains and waiting orders.",
                {},
                [],
            ),
            get_practice_account,
            lambda a: "Checking your practice account…",
        ),
        Tool(
            _spec(
                "practice_trade",
                "Buy or sell in the user's practice account (virtual dollars) — use it for "
                "every buy/sell request, e.g. 'sell all my bitcoin' -> side sell, quantity "
                "'all'. Give amount_usd (dollars) OR quantity (units, or 'all').",
                {
                    "asset": ASSET_PARAM,
                    "side": {"type": "string", "enum": ["buy", "sell"]},
                    "amount_usd": {"type": "number"},
                    "quantity": {"type": "string", "description": "Units, e.g. '2', or 'all'"},
                },
                ["asset", "side"],
            ),
            practice_trade,
            lambda a: f"Placing a practice {a.get('side', 'trade')} for {a.get('asset', '')}…",
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
