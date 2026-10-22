from __future__ import annotations

from datetime import datetime

from sqlalchemy import BigInteger, DateTime, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import UTC_NOW_DEFAULT, Base


class Invite(Base):
    """An email allowed to create an account while the beta is invite-only (INVITE_ONLY)."""

    __tablename__ = "invites"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)  # lowercase
    note: Mapped[str | None] = mapped_column(String(200))
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=UTC_NOW_DEFAULT
    )
    used_at: Mapped[datetime | None] = mapped_column(DateTime)  # account created
