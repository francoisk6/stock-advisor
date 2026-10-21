from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import TYPE_CHECKING, Any

from sqlalchemy import JSON, BigInteger, Boolean, DateTime, ForeignKey, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin

if TYPE_CHECKING:
    from app.db.models.user import User


class Plan(TimestampMixin, Base):
    """Subscription plan ("free", "pro"). Limits are data, so tiers can change without deploys."""

    __tablename__ = "plans"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    code: Mapped[str] = mapped_column(String(20), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(50), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    limits: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False, default=dict)
    # Prices in US dollars (None: not for sale). Payment providers come at launch.
    price_monthly_usd: Mapped[Decimal | None] = mapped_column(Numeric(8, 2))
    price_yearly_usd: Mapped[Decimal | None] = mapped_column(Numeric(8, 2))


class UserPlan(TimestampMixin, Base):
    """A user's subscription to a plan.

    Provider-agnostic: internal, stripe, google_play, app_store.
    """

    __tablename__ = "user_plans"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    plan_id: Mapped[int] = mapped_column(ForeignKey("plans.id"), nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="active")
    started_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    ends_at: Mapped[datetime | None] = mapped_column(DateTime)
    provider: Mapped[str] = mapped_column(String(20), nullable=False, default="internal")
    provider_ref: Mapped[str | None] = mapped_column(String(255))

    user: Mapped[User] = relationship(back_populates="plans")
    plan: Mapped[Plan] = relationship(lazy="joined")
