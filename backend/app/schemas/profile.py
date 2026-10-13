from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field


class ExperienceLevel(str, Enum):
    beginner = "beginner"
    intermediate = "intermediate"
    advanced = "advanced"


class RiskProfile(str, Enum):
    conservative = "conservative"
    balanced = "balanced"
    aggressive = "aggressive"


class InvestmentHorizon(str, Enum):
    short = "short"  # < 1 year
    medium = "medium"  # 1-5 years
    long = "long"  # 5+ years


class AssetInterest(str, Enum):
    stocks = "stocks"
    crypto = "crypto"
    etfs = "etfs"
    commodities = "commodities"
    forex = "forex"


class RegionInterest(str, Enum):
    global_ = "global"
    north_america = "north_america"
    europe = "europe"
    middle_east = "middle_east"
    asia_pacific = "asia_pacific"
    latin_america = "latin_america"
    africa = "africa"


class ProfileOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    experience_level: ExperienceLevel | None
    risk_profile: RiskProfile | None
    investment_horizon: InvestmentHorizon | None
    asset_interests: list[AssetInterest]
    region_interests: list[RegionInterest]
    preferred_language: str
    preferred_currency: str
    onboarding_completed_at: datetime | None


class ProfileUpdateIn(BaseModel):
    """Onboarding quiz answers (all required) — also used to edit them later."""

    experience_level: ExperienceLevel
    risk_profile: RiskProfile
    investment_horizon: InvestmentHorizon
    asset_interests: list[AssetInterest] = Field(min_length=1, max_length=len(AssetInterest))
    region_interests: list[RegionInterest] = Field(min_length=1, max_length=len(RegionInterest))
    preferred_language: str = Field(default="en", pattern=r"^[a-z]{2}(-[A-Z]{2})?$")
    preferred_currency: str = Field(default="USD", pattern=r"^[A-Z]{3}$")
