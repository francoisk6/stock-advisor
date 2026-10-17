"""A copilot request from any transport (WebSocket now): checks, storage, streamed events."""

from collections.abc import AsyncIterator
from dataclasses import asdict
from typing import Any

from app.ai import agent
from app.core.errors import AppError
from app.db.models import User
from app.db.session import SessionLocal
from app.repositories import assets as assets_repo
from app.services import chat as chat_service

MAX_QUESTION_LENGTH = 2000


async def handle(user_id: int, request: dict[str, Any]) -> AsyncIterator[dict[str, Any]]:
    """Yields chat events as dicts: conversation, status, delta, action, done, error."""
    question = " ".join(str(request.get("text") or "").split())
    if not question:
        yield {"event": "error", "detail": "Please type a question."}
        return
    if len(question) > MAX_QUESTION_LENGTH:
        yield {
            "event": "error",
            "detail": "That's a bit long; please keep it under 2,000 characters.",
        }
        return

    async with SessionLocal() as session:
        user = await session.get(User, user_id)
        if user is None or not user.is_active:
            yield {"event": "error", "detail": "Please sign in again."}
            return

        used, limit = await chat_service.usage(session, user)
        if limit is not None and used >= limit:
            yield {
                "event": "error",
                "detail": f"You've used all {limit} copilot questions for today. "
                "They reset at midnight (UTC).",
            }
            return

        try:
            conversation_id = request.get("conversation_id")
            if conversation_id:
                conversation = await chat_service.get_owned(session, user, int(conversation_id))
            else:
                conversation = await chat_service.start(session, user, question)
        except (AppError, ValueError):
            yield {"event": "error", "detail": "We couldn't find this conversation."}
            return
        asset_id = request.get("asset_id")
        context_asset = (
            await assets_repo.get(session, int(asset_id)) if str(asset_id).isdigit() else None
        )

        await chat_service.add_message(session, conversation, "user", question)
        yield {
            "event": "conversation",
            "conversation_id": conversation.id,
            "title": conversation.title,
        }

        async for event in agent.answer(session, user, conversation, question, context_asset):
            if isinstance(event, agent.Status):
                yield {"event": "status", "text": event.text}
            elif isinstance(event, agent.Delta):
                yield {"event": "delta", "text": event.text}
            elif isinstance(event, agent.Retract):
                yield {"event": "retract"}
            elif isinstance(event, agent.Action):
                yield {"event": "action", "card": event.card}
            elif isinstance(event, agent.Failed):
                yield {"event": "error", "detail": event.detail}
            elif isinstance(event, agent.Done):
                remaining = None if limit is None else max(0, limit - used - 1)
                yield {"event": "done", **asdict(event), "remaining_today": remaining}
