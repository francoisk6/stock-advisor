from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field, model_validator

from app.schemas.market import AssetOut
from app.services.practice import Side


class OrderIn(BaseModel):
    """Buy/sell a number of units, or a dollar amount's worth."""

    asset_id: int
    side: Side
    quantity: Decimal | None = Field(default=None, gt=0, max_digits=24, decimal_places=8)
    amount_usd: Decimal | None = Field(default=None, gt=0, max_digits=18, decimal_places=2)

    @model_validator(mode="after")
    def _one_amount(self) -> "OrderIn":
        if (self.quantity is None) == (self.amount_usd is None):
            raise ValueError("Give either quantity or amount_usd.")
        return self


class PracticeQuoteOut(BaseModel):
    """What an order would fill at right now (for the order preview)."""

    asset_id: int
    price: float
    currency: str
    usd_rate: float  # US dollars per unit of `currency`
    usd_price: float
    market_open: bool
    as_of: datetime
    held_quantity: float
    available_cash: float


class OrderOut(BaseModel):
    id: int
    asset: AssetOut
    side: Side
    quantity: float | None
    amount_usd: float | None
    status: str  # pending | filled | cancelled | rejected | undone
    source: str
    created_at: datetime
    filled_at: datetime | None
    filled_quantity: float | None
    price: float | None
    currency: str | None
    fx_rate: float | None
    total_usd: float | None
    gain_usd: float | None  # sells: what was locked in
    reserved_usd: float
    note: str | None


class PositionOut(BaseModel):
    asset: AssetOut
    quantity: float
    average_price: float  # in `currency`
    currency: str
    price: float | None
    change_percent: float | None
    usd_rate: float | None
    as_of: datetime | None
    cost_usd: float
    value_usd: float | None
    gain_usd: float | None
    gain_percent: float | None
    share_percent: float | None  # of the account's total value


class AccountOut(BaseModel):
    starting_cash: float
    cash: float
    reserved_usd: float
    available_cash: float
    positions_value: float
    total_value: float
    gain_usd: float
    gain_percent: float
    realized_usd: float
    started_at: datetime
    prices_complete: bool
    positions: list[PositionOut]
    pending: list[OrderOut]
