from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import Date, DateTime, ForeignKey, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import UTC_NOW_DEFAULT, Base


class PriceBarDaily(Base):
    """One trading day of an asset (UTC date). Filled nightly; backs charts when sources fail."""

    __tablename__ = "price_bars_daily"

    asset_id: Mapped[int] = mapped_column(
        ForeignKey("assets.id", ondelete="CASCADE"), primary_key=True
    )
    day: Mapped[date] = mapped_column(Date, primary_key=True)
    open: Mapped[Decimal] = mapped_column(Numeric(24, 10), nullable=False)
    high: Mapped[Decimal] = mapped_column(Numeric(24, 10), nullable=False)
    low: Mapped[Decimal] = mapped_column(Numeric(24, 10), nullable=False)
    close: Mapped[Decimal] = mapped_column(Numeric(24, 10), nullable=False)
    volume: Mapped[Decimal | None] = mapped_column(Numeric(30, 4))


class JobRun(Base):
    """Daily background jobs: which day they ran for, so a restart doesn't run them twice."""

    __tablename__ = "job_runs"

    name: Mapped[str] = mapped_column(String(40), primary_key=True)
    day: Mapped[date] = mapped_column(Date, primary_key=True)
    started_at: Mapped[datetime] = mapped_column(
        DateTime, server_default=UTC_NOW_DEFAULT, nullable=False
    )
    finished_at: Mapped[datetime | None] = mapped_column(DateTime)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="running")
    detail: Mapped[str | None] = mapped_column(String(500))
