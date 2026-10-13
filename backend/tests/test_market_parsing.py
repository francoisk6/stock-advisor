import asyncio
from datetime import datetime

import pandas as pd
import pytest

from app.market_data.cache import TTLCache
from app.market_data.providers import coingecko, yahoo
from app.market_data.regions import yahoo_location
from app.market_data.types import AssetType, ProviderError


def test_yahoo_location_by_suffix() -> None:
    assert yahoo_location("2222.SR", "EQUITY") == ("SA", "middle_east")
    assert yahoo_location("COMI.CA", "EQUITY") == ("EG", "africa")
    assert yahoo_location("^TASI.SR", "INDEX") == ("SA", "middle_east")
    assert yahoo_location("AAPL", "EQUITY") == ("US", "north_america")
    assert yahoo_location("EURUSD=X", "CURRENCY") == (None, "global")


def test_yahoo_display_symbols() -> None:
    assert yahoo.display_symbol("EURUSD=X", AssetType.forex) == "EUR/USD"
    assert yahoo.display_symbol("^GSPC", AssetType.index) == "GSPC"
    assert yahoo.display_symbol("2222.SR", AssetType.stock) == "2222.SR"


def test_yahoo_search_skips_futures_and_crypto() -> None:
    found = yahoo.parse_search(
        [
            {"symbol": "AAPL", "quoteType": "EQUITY", "longname": "Apple Inc.", "exchange": "NMS"},
            {"symbol": "SAAPL=F", "quoteType": "FUTURE", "shortname": "Apple futures"},
            {"symbol": "BTC-USD", "quoteType": "CRYPTOCURRENCY", "shortname": "Bitcoin"},
            {"symbol": "EMAAR.AE", "quoteType": "EQUITY", "shortname": "Emaar", "exchange": "DFM"},
        ]
    )
    assert [(f.symbol, f.exchange, f.region) for f in found] == [
        ("AAPL", "NASDAQ", "north_america"),
        ("EMAAR.AE", "Dubai Financial Market", "middle_east"),
    ]


def test_yahoo_info_parsing() -> None:
    details = yahoo.parse_info(
        {
            "regularMarketPrice": 341.27,
            "regularMarketPreviousClose": 340.97,
            "regularMarketTime": 1791921601,
            "marketState": "REGULAR",
            "currency": "USD",
            "marketCap": 4.98e12,
            "trailingPE": float("nan"),
            "dividendYield": 0.32,
            "sector": "Technology",
            "longBusinessSummary": "Makes phones.",
        }
    )
    assert details.quote.market_open is True
    assert details.quote.change_percent == pytest.approx(0.088, abs=1e-3)
    stats = {s.key: (s.value, s.unit) for s in details.stats}
    assert stats["dividend_yield"] == (0.32, "percent")
    assert "pe_ratio" not in stats  # NaN dropped
    assert stats["sector"] == ("Technology", "text")
    assert details.description == "Makes phones."


def test_yahoo_candles_convert_to_utc_and_skip_gaps() -> None:
    index = pd.DatetimeIndex(["2026-10-13 10:00", "2026-10-13 10:05"], tz="Asia/Riyadh")
    frame = pd.DataFrame(
        {
            "Open": [1.0, None],
            "High": [2.0, 2.0],
            "Low": [0.5, 0.5],
            "Close": [1.5, 1.5],
            "Volume": [10, 10],
        },
        index=index,
    )
    candles = yahoo.parse_candles(frame)
    assert len(candles) == 1
    assert candles[0].time == datetime(2026, 10, 13, 7, 0)


def test_coingecko_market_and_ohlc_parsing() -> None:
    details = coingecko.parse_market(
        {
            "current_price": 110.0,
            "price_change_24h": 10.0,
            "last_updated": "2026-10-13T20:00:00.000Z",
            "market_cap": 1e12,
            "market_cap_rank": 1,
            "ath_change_percentage": -25.5,
            "max_supply": None,
        }
    )
    assert details.quote.previous_close == 100.0
    assert details.quote.as_of == datetime(2026, 10, 13, 20, 0)
    keys = [s.key for s in details.stats]
    assert keys == ["market_cap", "market_cap_rank", "from_all_time_high"]

    candles = coingecko.parse_ohlc([[1791921600000, 1, 2, 0.5, 1.5]])
    assert candles[0].close == 1.5 and candles[0].time.year == 2026


async def test_cache_coalesces_concurrent_fetches() -> None:
    cache = TTLCache()
    calls = 0

    async def fetch() -> int:
        nonlocal calls
        calls += 1
        await asyncio.sleep(0.01)
        return 42

    results = await asyncio.gather(*(cache.get_or_fetch("k", 60, fetch) for _ in range(5)))
    assert results == [42] * 5 and calls == 1


async def test_cache_serves_stale_value_when_refresh_fails() -> None:
    cache = TTLCache(stale_for=3600)

    async def ok() -> str:
        return "fresh"

    async def broken() -> str:
        raise ProviderError("down")

    await cache.get_or_fetch("k", 60, ok)
    assert await cache.get_or_fetch("k", 0, broken) == "fresh"  # ttl 0 forces a refresh
    with pytest.raises(ProviderError):
        await cache.get_or_fetch("other", 60, broken)


def test_coingecko_search_keeps_ranked_coins_only() -> None:
    found = coingecko.parse_search(
        {
            "coins": [
                {"id": "nvidia-tokenized", "symbol": "nvdax", "name": "NVIDIA xStock"},
                {"id": "dogecoin", "symbol": "doge", "name": "Dogecoin", "market_cap_rank": 9},
                {"id": "bitcoin", "symbol": "btc", "name": "Bitcoin", "market_cap_rank": 1},
            ]
        }
    )
    assert [f.symbol for f in found] == ["BTC", "DOGE"]
