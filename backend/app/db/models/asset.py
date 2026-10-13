from sqlalchemy import BigInteger, Boolean, Index, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin


class Asset(TimestampMixin, Base):
    """Anything a user can follow: stock, ETF, index, crypto, currency pair, commodity.

    Prices are not stored here; they come from `provider` using `provider_symbol`.
    Seeded with popular assets (`popularity` set); search results are added on demand.
    """

    __tablename__ = "assets"
    __table_args__ = (
        UniqueConstraint("provider", "provider_symbol"),
        Index("ix_assets_symbol", "symbol"),
        Index("ix_assets_name", "name"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    symbol: Mapped[str] = mapped_column(String(32), nullable=False)  # shown to users
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    asset_type: Mapped[str] = mapped_column(String(20), nullable=False)
    exchange: Mapped[str | None] = mapped_column(String(100))
    country: Mapped[str | None] = mapped_column(String(2))
    region: Mapped[str] = mapped_column(String(20), nullable=False)
    currency: Mapped[str | None] = mapped_column(String(10))
    provider: Mapped[str] = mapped_column(String(20), nullable=False)
    provider_symbol: Mapped[str] = mapped_column(String(64), nullable=False)
    logo_url: Mapped[str | None] = mapped_column(String(500))
    # Lower = more popular within its region; null = not in the curated popular list.
    popularity: Mapped[int | None] = mapped_column(Integer)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
