"""Market data for the API: catalog lookups + provider calls, behind a shared cache."""

import asyncio

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.db.models import Asset, UserProfile
from app.market_data.cache import TTLCache
from app.market_data.providers.base import MarketDataProvider
from app.market_data.providers.coingecko import CoinGeckoProvider
from app.market_data.providers.yahoo import YahooProvider
from app.market_data.types import AssetType, Candle, Details, ProviderError, Quote, Range
from app.repositories import assets as assets_repo

providers: dict[str, MarketDataProvider] = {
    "yahoo": YahooProvider(),
    "coingecko": CoinGeckoProvider(),
}
SOURCE_NAMES = {"yahoo": "Yahoo Finance", "coingecko": "CoinGecko"}

cache = TTLCache()
STALE_SECONDS = 6 * 3600
QUOTE_TTL = 60
DETAILS_TTL = 60
SEARCH_TTL = 600
HISTORY_TTL = {Range.d1: 120, Range.w1: 600}
HISTORY_DEFAULT_TTL = 3600

# Onboarding interest -> asset types shown in "popular".
INTEREST_TYPES: dict[str, list[AssetType]] = {
    "stocks": [AssetType.stock, AssetType.index],
    "etfs": [AssetType.etf, AssetType.fund],
    "crypto": [AssetType.crypto],
    "commodities": [AssetType.commodity],
    "forex": [AssetType.forex],
}

UNAVAILABLE = "Live market data is temporarily unavailable. Please try again in a minute."


class MarketDataUnavailable(AppError):
    status_code = 503


def _provider(asset: Asset) -> MarketDataProvider:
    return providers[asset.provider]


def ranges_for(asset: Asset) -> list[Range]:
    return list(_provider(asset).ranges)


def _with_currency(quote: Quote, asset: Asset) -> Quote:
    if not quote.currency and asset.currency:
        quote.currency = asset.currency
    return quote


async def quotes_for(assets: list[Asset]) -> dict[int, Quote | None]:
    """Latest quotes, one upstream call per provider for whatever isn't cached."""
    result: dict[int, Quote | None] = {}
    by_provider: dict[str, list[Asset]] = {}
    for asset in assets:
        cached = cache.peek(f"q:{asset.provider}:{asset.provider_symbol}", QUOTE_TTL)
        if cached is not None:
            result[asset.id] = cached
        else:
            by_provider.setdefault(asset.provider, []).append(asset)

    async def fetch(provider_name: str, missing: list[Asset]) -> None:
        symbols = sorted({a.provider_symbol for a in missing})
        try:
            fetched = await providers[provider_name].quotes(symbols)
        except ProviderError:
            fetched = {}
        for asset in missing:
            key = f"q:{asset.provider}:{asset.provider_symbol}"
            quote = fetched.get(asset.provider_symbol)
            if quote is not None:
                quote = _with_currency(quote, asset)
                cache.put(key, quote)
            else:
                quote = cache.peek(key, STALE_SECONDS)  # last known price beats nothing
            result[asset.id] = quote

    await asyncio.gather(*(fetch(name, missing) for name, missing in by_provider.items()))
    return result


async def details_for(session: AsyncSession, asset: Asset) -> Details:
    try:
        details: Details = await cache.get_or_fetch(
            f"d:{asset.provider}:{asset.provider_symbol}",
            DETAILS_TTL,
            lambda: _provider(asset).details(asset.provider_symbol),
        )
    except ProviderError as exc:
        raise MarketDataUnavailable(UNAVAILABLE) from exc
    if details.quote is not None:
        if details.quote.currency and not asset.currency:
            asset.currency = details.quote.currency  # search hits arrive without a currency
            await session.commit()
        _with_currency(details.quote, asset)
        cache.put(f"q:{asset.provider}:{asset.provider_symbol}", details.quote)
    return details


async def history_for(asset: Asset, range_: Range) -> list[Candle]:
    if range_ not in _provider(asset).ranges:
        raise AppError(f"The {range_.value} chart isn't available for this asset yet.")
    try:
        return await cache.get_or_fetch(
            f"h:{asset.provider}:{asset.provider_symbol}:{range_.value}",
            HISTORY_TTL.get(range_, HISTORY_DEFAULT_TTL),
            lambda: _provider(asset).history(asset.provider_symbol, range_),
        )
    except ProviderError as exc:
        raise MarketDataUnavailable(UNAVAILABLE) from exc


async def search(session: AsyncSession, query: str, limit: int = 20) -> list[Asset]:
    """Catalog matches first, then new matches from providers (added to the catalog)."""
    local = await assets_repo.search_local(session, query, limit)
    if len(query.strip()) < 2 or len(local) >= limit:
        return rank_results(local, query)

    async def provider_search(name: str) -> list:
        try:
            return await cache.get_or_fetch(
                f"s:{name}:{query.strip().lower()}",
                SEARCH_TTL,
                lambda: providers[name].search(query.strip()),
            )
        except ProviderError:
            return []  # search still works from the catalog

    found_lists = await asyncio.gather(*(provider_search(name) for name in providers))
    seen = {(a.provider, a.provider_symbol) for a in local}
    new = []
    for found in (f for found_list in found_lists for f in found_list):
        if (found.provider, found.provider_symbol) not in seen:
            seen.add((found.provider, found.provider_symbol))
            new.append(found)
    stored = await assets_repo.upsert_found(session, new[: limit - len(local)])
    return rank_results([*local, *stored], query)


def rank_results(assets: list[Asset], query: str) -> list[Asset]:
    """Exact symbol, then names starting with the query, then curated; otherwise keep order."""
    q = query.strip().lower()

    def key(asset: Asset) -> tuple[int, int, int, int]:
        exact = asset.symbol.lower() == q or asset.provider_symbol.lower() == q
        return (
            0 if exact else 1,
            0 if asset.name.lower().startswith(q) else 1,
            0 if asset.popularity is not None else 1,
            asset.popularity or 0,
        )

    return sorted(assets, key=key)


async def popular_for(
    session: AsyncSession, profile: UserProfile, asset_type: AssetType | None = None
) -> list[Asset]:
    """Curated assets matching the user's interests and markets, in interest order."""
    if asset_type is not None:
        types = [asset_type]
    else:
        interests = profile.asset_interests or list(INTEREST_TYPES)
        types = [t for i in interests for t in INTEREST_TYPES.get(i, [])]
    regions = profile.region_interests or ["global"]
    region_filter = None if "global" in regions else regions
    assets = await assets_repo.popular(session, [t.value for t in types], region_filter)
    type_rank = {t.value: i for i, t in enumerate(types)}
    region_rank = {r: i for i, r in enumerate(regions)}
    return sorted(
        assets,
        key=lambda a: (
            type_rank.get(a.asset_type, 99),
            region_rank.get(a.region, 50),
            a.popularity or 0,
        ),
    )
