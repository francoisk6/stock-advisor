"""Crypto via the public CoinGecko API (no key).

Keyless limits: a few requests per minute and at most 365 days of history, so the app
offers ranges up to 1Y for crypto and leans on caching. A Demo key can be added later.
"""

import asyncio
import time
from datetime import datetime, timezone
from typing import Any

import httpx

from app.market_data.types import (
    AssetType,
    Candle,
    Details,
    FoundAsset,
    ProviderError,
    Quote,
    Range,
    Stat,
)

BASE_URL = "https://api.coingecko.com/api/v3"
VS_CURRENCY = "usd"

# OHLC granularity is decided by CoinGecko: 1 day -> 30 min, 7-30 days -> 4 h, more -> 4 days.
RANGE_DAYS: dict[Range, int] = {
    Range.d1: 1,
    Range.w1: 7,
    Range.m1: 30,
    Range.m6: 180,
    Range.y1: 365,
}

# Space out calls; the keyless API rate-limits aggressively.
MIN_INTERVAL_SECONDS = 1.5


def _utc_ms(ms: float) -> datetime:
    return datetime.fromtimestamp(ms / 1000, tz=timezone.utc).replace(tzinfo=None)


def _iso(value: str | None) -> datetime:
    if not value:
        return datetime.now(timezone.utc).replace(tzinfo=None)
    return (
        datetime.fromisoformat(value.replace("Z", "+00:00"))
        .astimezone(timezone.utc)
        .replace(tzinfo=None)
    )


def parse_market(item: dict[str, Any]) -> Details:
    price = item.get("current_price")
    quote = None
    if price is not None:
        change = item.get("price_change_24h")
        quote = Quote(
            price=float(price),
            previous_close=float(price) - float(change) if change is not None else None,
            currency="USD",
            as_of=_iso(item.get("last_updated")),
            market_open=True,  # crypto trades 24/7
        )
    stats: list[Stat] = []
    for key, field, unit in (
        ("market_cap", "market_cap", "compact"),
        ("market_cap_rank", "market_cap_rank", "number"),
        ("volume_24h", "total_volume", "compact"),
        ("day_low", "low_24h", "money"),
        ("day_high", "high_24h", "money"),
        ("circulating_supply", "circulating_supply", "compact"),
        ("max_supply", "max_supply", "compact"),
        ("all_time_high", "ath", "money"),
        ("from_all_time_high", "ath_change_percentage", "percent"),
    ):
        value = item.get(field)
        if value is not None:
            stats.append(Stat(key, float(value), unit))
    return Details(quote=quote, stats=stats)


def parse_ohlc(rows: list[list[float]]) -> list[Candle]:
    return [
        Candle(time=_utc_ms(t), open=float(o), high=float(h), low=float(lo), close=float(c))
        for t, o, h, lo, c in rows
    ]


def parse_search(payload: dict[str, Any], limit: int = 5) -> list[FoundAsset]:
    """Ranked coins only: unranked hits are mostly obscure tokens (e.g. "tokenized" stocks)."""
    coins = sorted(
        (c for c in payload.get("coins", []) if c.get("id") and c.get("market_cap_rank")),
        key=lambda c: c["market_cap_rank"],
    )
    return [
        FoundAsset(
            provider="coingecko",
            provider_symbol=coin["id"],
            symbol=str(coin.get("symbol", coin["id"])).upper(),
            name=coin.get("name") or coin["id"],
            asset_type=AssetType.crypto,
            exchange="Crypto",
            region="global",
            country=None,
            currency="USD",
            logo_url=coin.get("large") or coin.get("thumb"),
        )
        for coin in coins[:limit]
    ]


class CoinGeckoProvider:
    name = "coingecko"
    ranges = tuple(RANGE_DAYS)

    def __init__(self) -> None:
        self._lock = asyncio.Lock()
        self._last_call = 0.0

    async def _get(self, path: str, params: dict[str, Any]) -> Any:
        async with self._lock:
            wait = MIN_INTERVAL_SECONDS - (time.monotonic() - self._last_call)
            if wait > 0:
                await asyncio.sleep(wait)
            try:
                async with httpx.AsyncClient(base_url=BASE_URL, timeout=20) as client:
                    response = await client.get(path, params=params)
            except httpx.HTTPError as exc:
                raise ProviderError(f"CoinGecko unreachable: {exc}") from exc
            finally:
                self._last_call = time.monotonic()
        if response.status_code == 429:
            raise ProviderError("CoinGecko rate limit reached")
        if response.status_code >= 400:
            raise ProviderError(f"CoinGecko error {response.status_code}")
        return response.json()

    async def markets(self, ids: list[str]) -> dict[str, Details]:
        payload = await self._get(
            "/coins/markets",
            {"vs_currency": VS_CURRENCY, "ids": ",".join(ids), "per_page": 250},
        )
        return {item["id"]: parse_market(item) for item in payload}

    async def quotes(self, symbols: list[str]) -> dict[str, Quote]:
        if not symbols:
            return {}
        markets = await self.markets(symbols)
        return {coin: d.quote for coin, d in markets.items() if d.quote is not None}

    async def details(self, symbol: str) -> Details:
        markets = await self.markets([symbol])
        if symbol not in markets:
            raise ProviderError(f"No data for {symbol}")
        return markets[symbol]

    async def history(self, symbol: str, range_: Range) -> list[Candle]:
        days = RANGE_DAYS.get(range_)
        if days is None:
            raise ProviderError(f"Range {range_.value} is not available for crypto")
        rows = await self._get(f"/coins/{symbol}/ohlc", {"vs_currency": VS_CURRENCY, "days": days})
        return parse_ohlc(rows)

    async def search(self, query: str) -> list[FoundAsset]:
        return parse_search(await self._get("/search", {"query": query}))
