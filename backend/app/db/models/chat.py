from __future__ import annotations

from datetime import datetime
from typing import Any

from sqlalchemy import JSON, BigInteger, DateTime, ForeignKey, Index, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import UTC_NOW_DEFAULT, Base, TimestampMixin


class ChatConversation(TimestampMixin, Base):
    __tablename__ = "chat_conversations"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    title: Mapped[str] = mapped_column(String(120), nullable=False)

    messages: Mapped[list[ChatMessageRow]] = relationship(
        back_populates="conversation",
        cascade="all, delete-orphan",
        order_by="ChatMessageRow.id",
    )


class ChatMessageRow(Base):
    """What the user saw: their question, or the copilot's final answer + action cards.

    Tool calls and raw tool results are not stored; they are rebuilt on each turn.
    """

    __tablename__ = "chat_messages"
    __table_args__ = (Index("ix_chat_messages_conversation", "conversation_id", "id"),)

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    conversation_id: Mapped[int] = mapped_column(
        ForeignKey("chat_conversations.id", ondelete="CASCADE"), nullable=False
    )
    # Denormalized for the daily quota count.
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    role: Mapped[str] = mapped_column(String(10), nullable=False)  # user | assistant
    content: Mapped[str] = mapped_column(Text, nullable=False)
    actions: Mapped[list[dict[str, Any]]] = mapped_column(JSON, nullable=False, default=list)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, server_default=UTC_NOW_DEFAULT, nullable=False
    )

    conversation: Mapped[ChatConversation] = relationship(back_populates="messages")


Index(
    "ix_chat_messages_user_role_created",
    ChatMessageRow.user_id,
    ChatMessageRow.role,
    ChatMessageRow.created_at,
)
