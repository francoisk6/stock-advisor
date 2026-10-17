from datetime import datetime
from typing import Any

from fastapi import APIRouter, status
from pydantic import BaseModel

from app.api.deps import CurrentUser, SessionDep
from app.services import chat as chat_service

router = APIRouter(prefix="/chat", tags=["chat"])


class ConversationOut(BaseModel):
    id: int
    title: str
    updated_at: datetime


class ChatMessageOut(BaseModel):
    id: int
    role: str
    content: str
    actions: list[dict[str, Any]]
    created_at: datetime


class ConversationDetailOut(ConversationOut):
    messages: list[ChatMessageOut]


class UsageOut(BaseModel):
    used_today: int
    limit: int | None


@router.get("/usage", response_model=UsageOut)
async def chat_usage(user: CurrentUser, session: SessionDep) -> UsageOut:
    used, limit = await chat_service.usage(session, user)
    return UsageOut(used_today=used, limit=limit)


@router.get("/conversations", response_model=list[ConversationOut])
async def list_conversations(user: CurrentUser, session: SessionDep) -> list[ConversationOut]:
    return [
        ConversationOut(id=c.id, title=c.title, updated_at=c.updated_at)
        for c in await chat_service.list_conversations(session, user)
    ]


@router.get("/conversations/{conversation_id}", response_model=ConversationDetailOut)
async def get_conversation(
    conversation_id: int, user: CurrentUser, session: SessionDep
) -> ConversationDetailOut:
    conversation = await chat_service.get_owned(session, user, conversation_id)
    messages = await chat_service.recent_messages(session, conversation.id, limit=200)
    return ConversationDetailOut(
        id=conversation.id,
        title=conversation.title,
        updated_at=conversation.updated_at,
        messages=[
            ChatMessageOut(
                id=m.id,
                role=m.role,
                content=m.content,
                actions=m.actions,
                created_at=m.created_at,
            )
            for m in messages
        ],
    )


@router.delete("/conversations/{conversation_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_conversation(conversation_id: int, user: CurrentUser, session: SessionDep) -> None:
    await chat_service.delete(session, await chat_service.get_owned(session, user, conversation_id))
