from datetime import datetime

from pydantic import BaseModel


class PlanInfoOut(BaseModel):
    code: str
    name: str
    price_monthly_usd: float | None
    price_yearly_usd: float | None
    for_sale: bool  # Pro becomes available at launch
    limits: dict[str, int | None]  # the limits the app shows; None = unlimited


class UsageItemOut(BaseModel):
    key: str
    used: int
    limit: int | None


class UsageOut(BaseModel):
    plan: str  # code of the user's current plan
    plan_name: str
    items: list[UsageItemOut]
    pro_interest_at: datetime | None
