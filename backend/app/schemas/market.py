from datetime import datetime

from pydantic import BaseModel, ConfigDict


class AssetOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    symbol: str
    name: str
    asset_type: str
    exchange: str | None
    country: str | None
    region: str
    currency: str | None
    logo_url: str | None


class QuoteOut(BaseModel):
    price: float
    change: float | None
    change_percent: float | None
    previous_close: float | None
    currency: str
    as_of: datetime
    market_open: bool | None


class AssetWithQuoteOut(AssetOut):
    quote: QuoteOut | None


class StatOut(BaseModel):
    key: str
    value: float | str
    unit: str


class AssetDetailOut(AssetOut):
    quote: QuoteOut | None
    stats: list[StatOut]
    description: str | None
    ranges: list[str]
    data_source: str


class CandleOut(BaseModel):
    t: datetime
    o: float
    h: float
    l: float  # noqa: E741 - compact OHLC field names keep chart payloads small
    c: float
    v: float | None


class HistoryOut(BaseModel):
    range: str
    currency: str | None
    candles: list[CandleOut]
