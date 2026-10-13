from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.profile import ProfileOut


class PlanOut(BaseModel):
    code: str
    name: str
    limits: dict[str, Any]


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: str
    full_name: str
    email_verified: bool
    has_password: bool
    auth_providers: list[str]
    created_at: datetime
    profile: ProfileOut
    plan: PlanOut


class UserUpdateIn(BaseModel):
    full_name: str = Field(min_length=1, max_length=100)
