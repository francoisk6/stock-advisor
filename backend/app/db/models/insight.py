from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    BigInteger,
    Date,
    DateTime,
    ForeignKey,
    Numeric,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import UTC_NOW_DEFAULT, Base


class AssetInsight(Base):
    """AI text about an asset shared by all users, e.g. today's "why did it move?"."""

    __tablename__ = "asset_insights"
    __table_args__ = (UniqueConstraint("asset_id", "kind", "day"),)

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    asset_id: Mapped[int] = mapped_column(
        ForeignKey("assets.id", ondelete="CASCADE"), index=True, nullable=False
    )
    kind: Mapped[str] = mapped_column(String(20), nullable=False)  # why_move
    day: Mapped[date] = mapped_column(Date, nullable=False)  # UTC
    content: Mapped[str] = mapped_column(Text, nullable=False)
    change_percent: Mapped[Decimal | None] = mapped_column(Numeric(10, 4))
    created_at: Mapped[datetime] = mapped_column(
        DateTime, server_default=UTC_NOW_DEFAULT, nullable=False
    )
