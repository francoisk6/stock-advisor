from datetime import date
from decimal import Decimal
from typing import Any

from pydantic import BaseModel, Field

from app.schemas.market import AssetOut


class HoldingIn(BaseModel):
    quantity: Decimal = Field(gt=0, max_digits=24, decimal_places=8)
    average_price: Decimal = Field(ge=0, max_digits=24, decimal_places=8)  # asset's currency
    bought_on: date | None = None
    note: str | None = Field(default=None, max_length=200)


class HoldingCreateIn(HoldingIn):
    asset_id: int


class CurrencyIn(BaseModel):
    currency: str = Field(pattern=r"^[A-Za-z]{3}$")


class HoldingOut(BaseModel):
    id: int
    asset: AssetOut
    quantity: float
    average_price: float  # in `currency`
    currency: str
    bought_on: date | None
    note: str | None
    price: float | None
    change_percent: float | None
    value: float | None  # in the portfolio's display currency
    cost: float | None
    gain: float | None
    gain_percent: float | None
    share_percent: float | None


class SliceOut(BaseModel):
    key: str  # asset type, region or currency code
    value: float
    percent: float


class RiskOut(BaseModel):
    code: str
    level: str
    params: dict[str, Any]


class PortfolioOut(BaseModel):
    currency: str
    total_value: float
    total_cost: float
    gain: float
    gain_percent: float | None
    day_change: float
    prices_complete: bool
    holdings: list[HoldingOut]
    by_type: list[SliceOut]
    by_region: list[SliceOut]
    by_currency: list[SliceOut]
    risks: list[RiskOut]
