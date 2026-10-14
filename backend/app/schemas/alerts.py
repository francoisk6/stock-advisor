from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field

from app.schemas.market import AssetOut
from app.services.alerts import AlertKind


class AlertCreateIn(BaseModel):
    asset_id: int
    kind: AlertKind
    threshold: Decimal = Field(gt=0, max_digits=24, decimal_places=10)
    notify_email: bool = True


class AlertUpdateIn(BaseModel):
    threshold: Decimal | None = Field(default=None, gt=0, max_digits=24, decimal_places=10)
    notify_email: bool | None = None
    is_active: bool | None = None


class AlertOut(BaseModel):
    id: int
    asset: AssetOut
    kind: AlertKind
    threshold: float
    notify_email: bool
    is_active: bool
    last_triggered_at: datetime | None
    trigger_count: int
    created_at: datetime
