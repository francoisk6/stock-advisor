from datetime import datetime, time

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import NotFoundError
from app.core.time import utcnow
from app.db.models import ChatConversation, ChatMessageRow, User
from app.services.plans import plan_limit

TITLE_LENGTH = 60


async def get_owned(session: AsyncSession, user: User, conversation_id: int) -> ChatConversation:
    conversation = await session.get(ChatConversation, conversation_id)
    if conversation is None or conversation.user_id != user.id:
        raise NotFoundError("We couldn't find this conversation.")
    return conversation


async def start(session: AsyncSession, user: User, first_message: str) -> ChatConversation:
    title = " ".join(first_message.split())
    if len(title) > TITLE_LENGTH:
        title = title[: TITLE_LENGTH - 1].rstrip() + "…"
    conversation = ChatConversation(user_id=user.id, title=title)
    session.add(conversation)
    await session.commit()
    return conversation


async def recent_messages(
    session: AsyncSession, conversation_id: int, limit: int
) -> list[ChatMessageRow]:
    result = await session.execute(
        select(ChatMessageRow)
        .where(ChatMessageRow.conversation_id == conversation_id)
        .order_by(ChatMessageRow.id.desc())
        .limit(limit)
    )
    return list(reversed(list(result.scalars())))


async def add_message(
    session: AsyncSession,
    conversation: ChatConversation,
    role: str,
    content: str,
    actions: list | None = None,
) -> ChatMessageRow:
    row = ChatMessageRow(
        conversation_id=conversation.id,
        user_id=conversation.user_id,
        role=role,
        content=content,
        actions=actions or [],
        created_at=utcnow(),
    )
    session.add(row)
    conversation.updated_at = utcnow()
    await session.commit()
    return row


async def list_conversations(session: AsyncSession, user: User) -> list[ChatConversation]:
    result = await session.execute(
        select(ChatConversation)
        .where(ChatConversation.user_id == user.id)
        .order_by(ChatConversation.updated_at.desc(), ChatConversation.id.desc())
        .limit(50)
    )
    return list(result.scalars())


async def delete(session: AsyncSession, conversation: ChatConversation) -> None:
    await session.delete(conversation)
    await session.commit()


# --- daily quota (answered questions per UTC day) ------------------------------------------


async def answers_today(session: AsyncSession, user: User) -> int:
    start_of_day = datetime.combine(utcnow().date(), time.min)
    result = await session.execute(
        select(func.count())
        .select_from(ChatMessageRow)
        .where(
            ChatMessageRow.user_id == user.id,
            ChatMessageRow.role == "assistant",
            ChatMessageRow.created_at >= start_of_day,
        )
    )
    return int(result.scalar_one())


async def usage(session: AsyncSession, user: User) -> tuple[int, int | None]:
    """(used today, daily limit or None for unlimited)."""
    return await answers_today(session, user), plan_limit(user, "ai_messages_per_day")
