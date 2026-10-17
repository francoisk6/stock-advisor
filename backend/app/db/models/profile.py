from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import JSON, Boolean, DateTime, ForeignKey, String, false
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin

if TYPE_CHECKING:
    from app.db.models.user import User


class UserProfile(TimestampMixin, Base):
    """Personalization answers from the onboarding quiz (allowed values: app.schemas.profile)."""

    __tablename__ = "user_profiles"

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    experience_level: Mapped[str | None] = mapped_column(String(20))
    risk_profile: Mapped[str | None] = mapped_column(String(20))
    investment_horizon: Mapped[str | None] = mapped_column(String(20))
    asset_interests: Mapped[list[str]] = mapped_column(JSON, nullable=False, default=list)
    region_interests: Mapped[list[str]] = mapped_column(JSON, nullable=False, default=list)
    preferred_language: Mapped[str] = mapped_column(String(10), nullable=False, default="en")
    preferred_currency: Mapped[str] = mapped_column(String(3), nullable=False, default="USD")
    onboarding_completed_at: Mapped[datetime | None] = mapped_column(DateTime)
    # Also email the morning brief (it's always in the app).
    digest_email: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default=false()
    )

    user: Mapped[User] = relationship(back_populates="profile")
