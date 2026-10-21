from __future__ import annotations

from datetime import date
from decimal import Decimal

from sqlalchemy import BigInteger, Date, ForeignKey, Numeric, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin
from app.db.models.asset import Asset


class Holding(TimestampMixin, Base):
    """Something the user really owns, entered by hand (no broker connection).

    One row per asset: total units and the average price paid, in the asset's currency.
    """

    __tablename__ = "holdings"
    __table_args__ = (UniqueConstraint("user_id", "asset_id"),)

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    asset_id: Mapped[int] = mapped_column(ForeignKey("assets.id"), index=True, nullable=False)
    quantity: Mapped[Decimal] = mapped_column(Numeric(24, 8), nullable=False)
    average_price: Mapped[Decimal] = mapped_column(Numeric(24, 8), nullable=False)
    bought_on: Mapped[date | None] = mapped_column(Date)
    note: Mapped[str | None] = mapped_column(String(200))

    asset: Mapped[Asset] = relationship(lazy="joined")
