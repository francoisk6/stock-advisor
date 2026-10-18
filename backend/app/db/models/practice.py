from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    BigInteger,
    DateTime,
    ForeignKey,
    Numeric,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import UTC_NOW_DEFAULT, Base, TimestampMixin
from app.db.models.asset import Asset

# Practice money is US dollars (cents); quantities allow crypto-sized fractions.
USD = Numeric(18, 2)
QUANTITY = Numeric(24, 8)
PRICE = Numeric(24, 8)
FX = Numeric(20, 10)


class PracticeAccount(TimestampMixin, Base):
    """A user's practice (paper trading) account: virtual US dollars, real prices."""

    __tablename__ = "practice_accounts"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False
    )
    starting_cash: Mapped[Decimal] = mapped_column(USD, nullable=False)
    cash: Mapped[Decimal] = mapped_column(USD, nullable=False)
    started_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=UTC_NOW_DEFAULT
    )  # moves on reset

    positions: Mapped[list[PracticePosition]] = relationship(
        back_populates="account", cascade="all, delete-orphan", lazy="selectin"
    )


class PracticePosition(TimestampMixin, Base):
    """How much of one asset the account holds, and what it cost (in USD and the asset's
    own currency, so gains can be shown both ways)."""

    __tablename__ = "practice_positions"
    __table_args__ = (UniqueConstraint("account_id", "asset_id"),)

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    account_id: Mapped[int] = mapped_column(
        ForeignKey("practice_accounts.id", ondelete="CASCADE"), nullable=False
    )
    asset_id: Mapped[int] = mapped_column(ForeignKey("assets.id"), index=True, nullable=False)
    quantity: Mapped[Decimal] = mapped_column(QUANTITY, nullable=False)
    cost_usd: Mapped[Decimal] = mapped_column(USD, nullable=False)
    cost_local: Mapped[Decimal] = mapped_column(PRICE, nullable=False)

    account: Mapped[PracticeAccount] = relationship(back_populates="positions")
    asset: Mapped[Asset] = relationship(lazy="joined")


class PracticeOrder(Base):
    """A buy or sell. Filled orders are the trade history; orders placed while the market is
    closed stay pending until it opens."""

    __tablename__ = "practice_orders"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    account_id: Mapped[int] = mapped_column(
        ForeignKey("practice_accounts.id", ondelete="CASCADE"), index=True, nullable=False
    )
    asset_id: Mapped[int] = mapped_column(ForeignKey("assets.id"), index=True, nullable=False)
    side: Mapped[str] = mapped_column(String(4), nullable=False)  # buy | sell
    # What was asked: a number of units, or (buys) a dollar amount.
    quantity: Mapped[Decimal | None] = mapped_column(QUANTITY)
    amount_usd: Mapped[Decimal | None] = mapped_column(USD)
    # pending | filled | cancelled | rejected | undone
    status: Mapped[str] = mapped_column(String(10), nullable=False, index=True)
    source: Mapped[str] = mapped_column(String(10), nullable=False, default="app")
    # Cash set aside for a pending buy (so it can't be spent twice).
    reserved_usd: Mapped[Decimal] = mapped_column(USD, nullable=False, default=Decimal(0))
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=UTC_NOW_DEFAULT
    )
    # Fill: units, price in the asset's currency, USD per unit of that currency, USD total.
    filled_at: Mapped[datetime | None] = mapped_column(DateTime)
    filled_quantity: Mapped[Decimal | None] = mapped_column(QUANTITY)
    price: Mapped[Decimal | None] = mapped_column(PRICE)
    currency: Mapped[str | None] = mapped_column(String(10))
    fx_rate: Mapped[Decimal | None] = mapped_column(FX)
    total_usd: Mapped[Decimal | None] = mapped_column(USD)
    # Sells: the cost basis that left the position (gain = total_usd - cost_usd_removed).
    cost_usd_removed: Mapped[Decimal | None] = mapped_column(USD)
    cost_local_removed: Mapped[Decimal | None] = mapped_column(PRICE)
    note: Mapped[str | None] = mapped_column(String(255))  # why it was rejected, etc.

    asset: Mapped[Asset] = relationship(lazy="joined")
