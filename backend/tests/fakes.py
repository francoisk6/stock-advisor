from datetime import datetime

from app.market_data.types import Candle, Details, FoundAsset, ProviderError, Quote, Range, Stat


class FakeProvider:
    """Stands in for Yahoo/CoinGecko: canned data, call counting, optional failure."""

    def __init__(self, name: str, ranges: tuple[Range, ...] = tuple(Range)) -> None:
        self.name = name
        self.ranges = ranges
        self.calls: list[tuple[str, object]] = []
        self.fail = False
        self.search_results: list[FoundAsset] = []
        self.missing: set[str] = set()

    def _check(self) -> None:
        if self.fail:
            raise ProviderError(f"{self.name} is down")

    async def quotes(self, symbols: list[str]) -> dict[str, Quote]:
        self.calls.append(("quotes", tuple(symbols)))
        self._check()
        return {
            s: Quote(price=110.0, previous_close=100.0, currency="", as_of=datetime(2026, 10, 13))
            for s in symbols
            if s not in self.missing
        }

    async def details(self, symbol: str) -> Details:
        self.calls.append(("details", symbol))
        self._check()
        return Details(
            quote=Quote(
                price=110.0, previous_close=100.0, currency="SAR", as_of=datetime(2026, 10, 13)
            ),
            stats=[Stat("market_cap", 2.5e12, "compact"), Stat("sector", "Energy", "text")],
            description="An oil company.",
        )

    async def history(self, symbol: str, range_: Range) -> list[Candle]:
        self.calls.append(("history", (symbol, range_)))
        self._check()
        return [
            Candle(datetime(2026, 10, d), 100.0 + d, 102.0 + d, 99.0 + d, 101.0 + d, 1000.0)
            for d in range(1, 6)
        ]

    async def search(self, query: str) -> list[FoundAsset]:
        self.calls.append(("search", query))
        self._check()
        return self.search_results

    def count(self, kind: str) -> int:
        return sum(1 for c in self.calls if c[0] == kind)
