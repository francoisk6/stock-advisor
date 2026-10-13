"""Stocks, ETFs, indices, currencies and commodities via Yahoo Finance (yfinance).

yfinance is unofficial and Yahoo's terms forbid commercial use: fine for development, must be
replaced by a licensed provider before paid plans launch (see CLAUDE.md).
"""

import asyncio
import math
from datetime import datetime, timezone
from typing import Any

import pandas as pd
import yfinance as yf

from app.market_data.regions import exchange_name, yahoo_location
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

# (period, interval) per chart range.
RANGE_PARAMS: dict[Range, tuple[str, str]] = {
    Range.d1: ("1d", "5m"),
    Range.w1: ("5d", "30m"),
    Range.m1: ("1mo", "1d"),
    Range.m6: ("6mo", "1d"),
    Range.y1: ("1y", "1d"),
    Range.y5: ("5y", "1wk"),
}

QUOTE_TYPES: dict[str, AssetType] = {
    "EQUITY": AssetType.stock,
    "ETF": AssetType.etf,
    "INDEX": AssetType.index,
    "MUTUALFUND": AssetType.fund,
    "CURRENCY": AssetType.forex,
}

# yfinance is blocking; keep concurrent upstream calls low (shared server, Yahoo rate limits).
_slots = asyncio.Semaphore(2)


async def _run(fn, *args, **kwargs):
    async with _slots:
        try:
            return await asyncio.to_thread(fn, *args, **kwargs)
        except ProviderError:
            raise
        except Exception as exc:  # yfinance raises many exception types
            raise ProviderError(f"Yahoo request failed: {exc}") from exc


def _num(value: Any) -> float | None:
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    return None if math.isnan(number) or math.isinf(number) else number


def _utc(ts: pd.Timestamp) -> datetime:
    if ts.tzinfo is not None:
        ts = ts.tz_convert("UTC")
    return ts.to_pydatetime().replace(tzinfo=None)


def parse_candles(frame: pd.DataFrame) -> list[Candle]:
    candles = []
    for ts, row in frame.iterrows():
        o, h, low, c = (_num(row.get(k)) for k in ("Open", "High", "Low", "Close"))
        if None in (o, h, low, c):
            continue
        candles.append(
            Candle(time=_utc(ts), open=o, high=h, low=low, close=c, volume=_num(row.get("Volume")))
        )
    return candles


def parse_download_quotes(frame: pd.DataFrame, symbols: list[str]) -> dict[str, Quote]:
    """Daily bars from yf.download(group_by="ticker") -> last close vs previous close."""
    quotes: dict[str, Quote] = {}
    for symbol in symbols:
        try:
            # group_by="ticker" gives (ticker, field) columns, even for a single symbol.
            if isinstance(frame.columns, pd.MultiIndex):
                closes = frame[symbol]["Close"].dropna()
            else:
                closes = frame["Close"].dropna()
        except KeyError:
            continue
        if closes.empty:
            continue
        previous = _num(closes.iloc[-2]) if len(closes) > 1 else None
        quotes[symbol] = Quote(
            price=float(closes.iloc[-1]),
            previous_close=previous,
            currency="",  # filled from our catalog
            as_of=_utc(closes.index[-1]),
        )
    return quotes


def parse_info(info: dict[str, Any]) -> Details:
    price = _num(info.get("regularMarketPrice")) or _num(info.get("currentPrice"))
    quote = None
    if price is not None:
        ts = info.get("regularMarketTime")
        as_of = (
            datetime.fromtimestamp(ts, tz=timezone.utc).replace(tzinfo=None)
            if isinstance(ts, int | float)
            else datetime.now(timezone.utc).replace(tzinfo=None)
        )
        state = info.get("marketState")
        quote = Quote(
            price=price,
            previous_close=_num(info.get("regularMarketPreviousClose"))
            or _num(info.get("previousClose")),
            currency=str(info.get("currency") or ""),
            as_of=as_of,
            market_open=None if state is None else state == "REGULAR",
        )

    stats: list[Stat] = []

    def add(key: str, value: Any, unit: str) -> None:
        if unit == "text":
            if value:
                stats.append(Stat(key, str(value), unit))
            return
        number = _num(value)
        if number is not None:
            stats.append(Stat(key, number, unit))

    add("market_cap", info.get("marketCap"), "compact")
    add("pe_ratio", info.get("trailingPE"), "number")
    add("dividend_yield", info.get("dividendYield"), "percent")  # already in percent
    add("expense_ratio", info.get("netExpenseRatio"), "percent")  # already in percent
    add("day_low", info.get("regularMarketDayLow") or info.get("dayLow"), "money")
    add("day_high", info.get("regularMarketDayHigh") or info.get("dayHigh"), "money")
    add("week52_low", info.get("fiftyTwoWeekLow"), "money")
    add("week52_high", info.get("fiftyTwoWeekHigh"), "money")
    add("avg_volume", info.get("averageVolume"), "compact")
    add("beta", info.get("beta"), "number")
    add("sector", info.get("sector"), "text")
    add("industry", info.get("industry"), "text")

    description = info.get("longBusinessSummary")
    return Details(quote=quote, stats=stats, description=description or None)


def parse_search(results: list[dict[str, Any]]) -> list[FoundAsset]:
    found = []
    for item in results:
        asset_type = QUOTE_TYPES.get(str(item.get("quoteType")))
        symbol = item.get("symbol")
        if asset_type is None or not symbol:  # skips futures, options, crypto (CoinGecko)
            continue
        country, region = yahoo_location(symbol, str(item.get("quoteType")))
        found.append(
            FoundAsset(
                provider="yahoo",
                provider_symbol=symbol,
                symbol=display_symbol(symbol, asset_type),
                name=item.get("longname") or item.get("shortname") or symbol,
                asset_type=asset_type,
                exchange=exchange_name(item.get("exchange"), item.get("exchDisp")),
                region=region,
                country=country,
            )
        )
    return found


def display_symbol(symbol: str, asset_type: AssetType) -> str:
    if asset_type == AssetType.forex and symbol.endswith("=X") and len(symbol) == 8:
        return f"{symbol[:3]}/{symbol[3:6]}"
    return symbol.lstrip("^")


class YahooProvider:
    name = "yahoo"
    ranges = tuple(Range)

    async def quotes(self, symbols: list[str]) -> dict[str, Quote]:
        if not symbols:
            return {}
        frame = await _run(
            yf.download,
            symbols,
            period="5d",
            interval="1d",
            progress=False,
            group_by="ticker",
            threads=False,
            auto_adjust=True,
        )
        if frame is None or frame.empty:
            raise ProviderError("Yahoo returned no prices")
        return parse_download_quotes(frame, symbols)

    async def details(self, symbol: str) -> Details:
        info = await _run(lambda: yf.Ticker(symbol).info)
        if not info:
            raise ProviderError(f"No data for {symbol}")
        return parse_info(info)

    async def history(self, symbol: str, range_: Range) -> list[Candle]:
        period, interval = RANGE_PARAMS[range_]
        frame = await _run(
            lambda: yf.Ticker(symbol).history(period=period, interval=interval, auto_adjust=True)
        )
        if frame is None or frame.empty:
            raise ProviderError(f"No history for {symbol}")
        return parse_candles(frame)

    async def search(self, query: str) -> list[FoundAsset]:
        results = await _run(lambda: yf.Search(query, max_results=10, news_count=0).quotes)
        return parse_search(results or [])
