from typing import Protocol

from app.market_data.types import Candle, Details, FoundAsset, Quote, Range


class MarketDataProvider(Protocol):
    """A source of prices for some asset types. Symbols are the provider's own identifiers."""

    name: str
    ranges: tuple[Range, ...]

    async def quotes(self, symbols: list[str]) -> dict[str, Quote]:
        """Latest prices for many symbols at once; missing symbols are left out."""
        ...

    async def details(self, symbol: str) -> Details:
        """Quote plus key figures for one asset."""
        ...

    async def history(self, symbol: str, range_: Range) -> list[Candle]: ...

    async def search(self, query: str) -> list[FoundAsset]: ...
