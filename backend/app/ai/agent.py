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
from app.ai.prompts import NEWS_RETRY, TURN_REMINDER, USE_RESULTS, system_prompt
from app.ai.provider import LLMProvider
from app.ai.types import AIUnavailable, ChatMessage, TextDelta, ToolCall, ToolCalls
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


# The small model sometimes receives headlines and still says it has no data.
_NO_DATA_CLAIM = re.compile(
    r"\b(don'?t|do not|doesn'?t) have\b[^.\n]{0,40}\b(data|news|information|access)\b"
    r"|\b(can'?t|cannot|unable to) (provide|access|see|find)\b",
    re.IGNORECASE,
)


_REF = re.compile(r"\[[^\]\n]*\]\(([a-z]\d+)\)|\[([a-z]\d+)\](?!\()")


def cites_results(answer: str, sources: dict[str, tuple[str, str]]) -> bool:
    return any((m.group(1) or m.group(2)) in sources for m in _REF.finditer(answer))


def ignores_results(question: str, answer: str, tools_used: set[str], sources: dict) -> bool:
    """News/web results arrived but the answer claims it has none, or (for a why/news
    question) cites none of them, e.g. links a URL it made up."""
    if not (tools_used & NEWS_TOOLS) or not sources:
        return False
    if _NO_DATA_CLAIM.search(answer):
        return True
    return bool(_WHY_QUESTION.search(question)) and not cites_results(answer, sources)


def needs_news_retry(question: str, answer: str, tools_used: set[str]) -> bool:
    if tools_used & NEWS_TOOLS:
        return False
    return bool(_NEWS_CLAIM.search(answer) or _WHY_QUESTION.search(question))


_HTTP_LINK = re.compile(r"\[([^\]\n]+)\]\((https?://[^)\s]+)\)")


def drop_foreign_links(text: str, sources: dict[str, tuple[str, str]]) -> str:
    """Keep only links to what the tools returned this turn; a URL the model typed itself
    may be invented, so it becomes plain text."""
    allowed = {url for url, _ in sources.values()}
    return _HTTP_LINK.sub(lambda m: m.group(0) if m.group(2) in allowed else m.group(1), text)


def with_sources(text: str, sources: dict[str, tuple[str, str]], limit: int = 3) -> str:
    """News/web results were used but the answer cites nothing: list what was read, so every
    such answer shows its sources (small models sometimes forget)."""
    if not sources or "](http" in text:
        return text
    seen: dict[str, str] = {}
    for url, name in sources.values():
        seen.setdefault(name, url)
    links = ", ".join(f"[{name}]({url})" for name, url in list(seen.items())[:limit])
    return f"{text}\n\nSources: {links}"


_LINK = re.compile(r"\[([^\]\n]+)\]\(([a-z]\d+)\)")
_BARE = re.compile(r"\[([a-z]\d+)\](?!\()")


def resolve_citations(text: str, sources: dict[str, tuple[str, str]]) -> str:
    """Turn citation references into links. Sources map a reference to (url, source name).

    [Reuters](n1) -> [Reuters](https://…); a bare [n1] (small models do that too) ->
    [Reuters](https://…); unknown references become plain text / disappear, and so do links
    to URLs that aren't among the sources.
    """

    def swap(match: re.Match[str]) -> str:
        known = sources.get(match.group(2))
        return f"[{match.group(1)}]({known[0]})" if known else match.group(1)

    def swap_bare(match: re.Match[str]) -> str:
        known = sources.get(match.group(1))
        return f"[{known[1]}]({known[0]})" if known else ""

    return drop_foreign_links(_BARE.sub(swap_bare, _LINK.sub(swap, text)), sources)


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
    searched = False
    nudged = False
    for _ in range(settings.ai_max_tool_rounds):
        round_text = ""
        calls = []
        async for event in provider.stream_chat(messages, toolbox.SPECS):
            if isinstance(event, TextDelta):
                round_text += event.text
                yield Delta(event.text)
            elif isinstance(event, ToolCalls):
                calls = event.calls
        if calls and round_text.strip():
            # "Let me check…" before a lookup is filler, not part of the answer.
            yield Retract()
            round_text_for_answer = ""
        else:
            round_text_for_answer = round_text
        answer += round_text_for_answer
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
            if retried and not searched and not (tools_used & NEWS_TOOLS):
                # Asked twice and still no lookup ("I don't have live data"): search for it.
                searched = True
                yield Retract()
                forced = [ToolCall("web_search", {"query": question})]
                messages.append(ChatMessage("assistant", "", tool_calls=forced))
                async for event in _run_calls(forced, ctx, actions, messages, tools_used):
                    yield event
                messages.append(ChatMessage("system", USE_RESULTS))
                answer = ""
                continue
            # Only when results actually arrived: "no news found" is honest if none did.
            if not nudged and ignores_results(question, answer, tools_used, ctx.sources):
                # It was given headlines but claims it has none: make it use them.
                nudged = True
                yield Retract()
                messages.append(ChatMessage("assistant", round_text))
                messages.append(ChatMessage("system", USE_RESULTS))
                answer = ""
                continue
            yield answer.strip()
            return
        messages.append(ChatMessage("assistant", round_text, tool_calls=calls))
        async for event in _run_calls(calls, ctx, actions, messages, tools_used):
            yield event
    yield Delta(TOO_MANY_STEPS)
    yield (answer + TOO_MANY_STEPS).strip()


async def _run_calls(
    calls: list[ToolCall],
    ctx: toolbox.ToolContext,
    actions: list[dict[str, Any]],
    messages: list[ChatMessage],
    tools_used: set[str],
) -> AsyncIterator[AgentEvent]:
    """Run tool calls, append their results to the conversation, yield status/action events."""
    for call in calls:
        tools_used.add(call.name)
        yield Status(toolbox.status_text(call))
        try:
            result = await toolbox.run_tool(ctx, call)
        except Exception:  # a broken tool must not kill the conversation
            logger.exception("Tool %s failed", call.name)
            result = toolbox.ToolResult({"error": "This lookup failed. Try again later."})
        logger.info("Tool %s done; %d citable sources so far", call.name, len(ctx.sources))
        if result.action is not None:
            actions.append(result.action)
            yield Action(result.action)
        messages.append(
            ChatMessage("tool", json.dumps(result.data, default=str), tool_name=call.name)
        )


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
    text = with_sources(resolve_citations(text, ctx.sources), ctx.sources)
    row = await chat_service.add_message(session, conversation, "assistant", text, actions)
    yield Done(row.id, text, actions)
