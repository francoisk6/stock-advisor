"""One copilot turn: model ⇄ tools loop, streamed as events for the chat UI."""

import asyncio
import json
import logging
from collections.abc import AsyncIterator
from dataclasses import dataclass, field
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.ai import tools as toolbox
from app.ai.ollama import OllamaProvider
from app.ai.prompts import system_prompt
from app.ai.provider import LLMProvider
from app.ai.types import AIUnavailable, ChatMessage, TextDelta, ToolCalls
from app.core.config import settings
from app.db.models import Asset, ChatConversation, User
from app.services import chat as chat_service

logger = logging.getLogger(__name__)

provider: LLMProvider = OllamaProvider()

# The model serves one request at a time (OLLAMA_NUM_PARALLEL=1); others wait their turn.
_slot = asyncio.Semaphore(1)
_waiting = 0

TOO_MANY_STEPS = (
    "\n\nSorry, this question needed more steps than I can take at once. "
    "Could you ask it in smaller parts?"
)
UNAVAILABLE = "The copilot is unavailable right now. Please try again in a few minutes."


@dataclass
class Status:
    text: str


@dataclass
class Delta:
    text: str


@dataclass
class Action:
    card: dict[str, Any]


@dataclass
class Done:
    message_id: int
    text: str
    actions: list[dict[str, Any]] = field(default_factory=list)


@dataclass
class Failed:
    detail: str


AgentEvent = Status | Delta | Action | Done | Failed


async def _model_turn(
    messages: list[ChatMessage], ctx: toolbox.ToolContext, actions: list[dict[str, Any]]
) -> AsyncIterator[AgentEvent | str]:
    """Run model rounds until it answers without tools. Yields events; the final yielded str is
    the full answer text."""
    answer = ""
    for _ in range(settings.ai_max_tool_rounds):
        round_text = ""
        calls = []
        async for event in provider.stream_chat(messages, toolbox.SPECS):
            if isinstance(event, TextDelta):
                round_text += event.text
                yield Delta(event.text)
            elif isinstance(event, ToolCalls):
                calls = event.calls
        answer += round_text
        if not calls:
            yield answer.strip()
            return
        messages.append(ChatMessage("assistant", round_text, tool_calls=calls))
        for call in calls:
            yield Status(toolbox.status_text(call))
            try:
                result = await toolbox.run_tool(ctx, call)
            except Exception:  # a broken tool must not kill the conversation
                logger.exception("Tool %s failed", call.name)
                result = toolbox.ToolResult({"error": "This lookup failed. Try again later."})
            if result.action is not None:
                actions.append(result.action)
                yield Action(result.action)
            messages.append(
                ChatMessage("tool", json.dumps(result.data, default=str), tool_name=call.name)
            )
    yield Delta(TOO_MANY_STEPS)
    yield (answer + TOO_MANY_STEPS).strip()


async def answer(
    session: AsyncSession,
    user: User,
    conversation: ChatConversation,
    question: str,
    context_asset: Asset | None = None,
) -> AsyncIterator[AgentEvent]:
    """Stream one answer. The question must already be saved; the answer is saved at the end."""
    global _waiting
    history = await chat_service.recent_messages(
        session, conversation.id, settings.ai_history_messages + 1
    )
    messages = [ChatMessage("system", system_prompt(user, context_asset))]
    messages += [ChatMessage(m.role, m.content) for m in history]  # includes the question
    ctx = toolbox.ToolContext(session, user)
    actions: list[dict[str, Any]] = []

    queued = _slot.locked()
    if queued:
        _waiting += 1
        yield Status(f"The copilot is helping someone else — you're number {_waiting} in line…")
    try:
        async with _slot:
            if queued:
                _waiting -= 1
                queued = False
            yield Status("Thinking…")
            text = ""
            async for event in _model_turn(messages, ctx, actions):
                if isinstance(event, str):
                    text = event
                else:
                    yield event
    except AIUnavailable:
        logger.exception("Copilot model call failed")
        yield Failed(UNAVAILABLE)
        return
    finally:
        if queued:  # cancelled while still waiting in line
            _waiting -= 1
    if not text:
        text = "Done." if actions else "Sorry, I couldn't come up with an answer. Please try again."
    row = await chat_service.add_message(session, conversation, "assistant", text, actions)
    yield Done(row.id, text, actions)
