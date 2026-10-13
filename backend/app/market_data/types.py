from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum


class AssetType(str, Enum):
    stock = "stock"
    etf = "etf"
    index = "index"
    fund = "fund"
    crypto = "crypto"
    forex = "forex"
    commodity = "commodity"


class Range(str, Enum):
    """Chart ranges offered to users."""

    d1 = "1D"
    w1 = "1W"
    m1 = "1M"
    m6 = "6M"
    y1 = "1Y"
    y5 = "5Y"


@dataclass
class Quote:
    price: float
    previous_close: float | None
    currency: str
    as_of: datetime  # naive UTC
    market_open: bool | None = None

    @property
    def change(self) -> float | None:
        return None if self.previous_close is None else self.price - self.previous_close

    @property
    def change_percent(self) -> float | None:
        if not self.previous_close:
            return None
        return (self.price - self.previous_close) / self.previous_close * 100


@dataclass
class Candle:
    time: datetime  # naive UTC, start of the bar
    open: float
    high: float
    low: float
    close: float
    volume: float | None = None


@dataclass
class Stat:
    """One key figure. `key` maps to a plain-language explanation in the app."""

    key: str
    value: float | str
    unit: str = "number"  # number | money | percent | text | compact


@dataclass
class Details:
    quote: Quote | None
    stats: list[Stat] = field(default_factory=list)
    description: str | None = None


@dataclass
class FoundAsset:
    """A search hit from a provider, before it is stored in our catalog."""

    provider: str
    provider_symbol: str
    symbol: str
    name: str
    asset_type: AssetType
    exchange: str | None
    region: str
    country: str | None
    currency: str | None = None
    logo_url: str | None = None


class ProviderError(Exception):
    """The upstream data source failed or is rate limiting us."""
