"""One copilot turn: model ⇄ tools loop, streamed as events for the chat UI."""

import json
import logging
import re
from collections.abc import AsyncIterator
from dataclasses import dataclass, field
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.ai import slot as model_slot
from app.ai import tools as toolbox
from app.ai.ollama import OllamaProvider
from app.ai.prompts import NEWS_RETRY, TURN_REMINDER, system_prompt
from app.ai.provider import LLMProvider
from app.ai.types import AIUnavailable, ChatMessage, TextDelta, ToolCalls
from app.core.config import settings
from app.db.models import Asset, ChatConversation, User
from app.services import chat as chat_service

logger = logging.getLogger(__name__)

provider: LLMProvider = OllamaProvider()


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


@dataclass
class Retract:
    """Discard the text streamed so far (the answer is being redone)."""


AgentEvent = Status | Delta | Action | Done | Failed | Retract

# Answers that talk about news/causes must be backed by a news or web lookup in the same turn.
_NEWS_CLAIM = re.compile(
    r"according to|report(s|ed)|news|headline|analysts? (say|said)|due to|because of|driven by",
    re.IGNORECASE,
)
_WHY_QUESTION = re.compile(r"\bwhy\b|\bnews\b|what happened|what's happening", re.IGNORECASE)
NEWS_TOOLS = {"get_news", "web_search"}


def needs_news_retry(question: str, answer: str, tools_used: set[str]) -> bool:
    if tools_used & NEWS_TOOLS:
        return False
    return bool(_NEWS_CLAIM.search(answer) or _WHY_QUESTION.search(question))


_LINK = re.compile(r"\[([^\]\n]+)\]\(([a-z]\d+)\)")
_BARE = re.compile(r"\[([a-z]\d+)\](?!\()")


def resolve_citations(text: str, sources: dict[str, tuple[str, str]]) -> str:
    """Turn citation references into links. Sources map a reference to (url, source name).

    [Reuters](n1) -> [Reuters](https://…); a bare [n1] (small models do that too) ->
    [Reuters](https://…); unknown references become plain text / disappear.
    """

    def swap(match: re.Match[str]) -> str:
        known = sources.get(match.group(2))
        return f"[{match.group(1)}]({known[0]})" if known else match.group(1)

    def swap_bare(match: re.Match[str]) -> str:
        known = sources.get(match.group(1))
        return f"[{known[1]}]({known[0]})" if known else ""

    return _BARE.sub(swap_bare, _LINK.sub(swap, text))


async def _model_turn(
    messages: list[ChatMessage],
    ctx: toolbox.ToolContext,
    actions: list[dict[str, Any]],
    question: str,
) -> AsyncIterator[AgentEvent | str]:
    """Run model rounds until it answers without tools. Yields events; the final yielded str is
    the full answer text."""
    answer = ""
    tools_used: set[str] = set()
    retried = False
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
            if not retried and needs_news_retry(question, answer, tools_used):
                # Possibly invented news: take the answer back and make the model look it up.
                retried = True
                yield Retract()
                yield Status("Checking the latest news…")
                messages.append(ChatMessage("assistant", round_text))
                messages.append(ChatMessage("system", NEWS_RETRY))
                answer = ""
                continue
            yield answer.strip()
            return
        messages.append(ChatMessage("assistant", round_text, tool_calls=calls))
        for call in calls:
            tools_used.add(call.name)
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
    history = await chat_service.recent_messages(
        session, conversation.id, settings.ai_history_messages + 1
    )
    messages = [ChatMessage("system", system_prompt(user, context_asset))]
    messages += [ChatMessage(m.role, m.content) for m in history]  # includes the question
    messages.append(ChatMessage("system", TURN_REMINDER))
    ctx = toolbox.ToolContext(session, user)
    actions: list[dict[str, Any]] = []

    queued = model_slot.slot.locked()
    if queued:
        model_slot.waiting += 1
        yield Status(
            f"The copilot is helping someone else — you're number {model_slot.waiting} in line…"
        )
    try:
        async with model_slot.slot:
            if queued:
                model_slot.waiting -= 1
                queued = False
            yield Status("Thinking…")
            text = ""
            async for event in _model_turn(messages, ctx, actions, question):
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
            model_slot.waiting -= 1
    if not text:
        text = "Done." if actions else "Sorry, I couldn't come up with an answer. Please try again."
    text = resolve_citations(text, ctx.sources)
    row = await chat_service.add_message(session, conversation, "assistant", text, actions)
    yield Done(row.id, text, actions)
