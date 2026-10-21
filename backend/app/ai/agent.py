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
from app.ai.prompts import (
    ACTION_RETRY,
    FIGURES_RETRY,
    NEWS_RETRY,
    TURN_REMINDER,
    USE_RESULTS,
    system_prompt,
)
from app.ai.provider import LLMProvider
from app.ai.types import AIUnavailable, ChatMessage, TextDelta, ToolCall, ToolCalls
from app.core.config import settings
from app.db.models import Asset, ChatConversation, User
from app.learn import glossary
from app.learn import lessons as lessons_content
from app.services import chat as chat_service

logger = logging.getLogger(__name__)

provider: LLMProvider = OllamaProvider()


ACTION_NOT_DONE = (
    "Sorry, I couldn't do that this time, so nothing was changed. Please say exactly what "
    "to do, e.g. “Buy $200 of Apple in my practice account”."
)
FIGURES_NOT_CHECKED = (
    "Sorry, I couldn't look up the numbers for that just now, so I won't guess. "
    "Please ask again in a moment."
)
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
# Wording that presents news: always needs a news lookup in the same turn.
_NEWS_CLAIM = re.compile(
    r"according to|report(s|ed)|news|headline|analysts? (say|said)", re.IGNORECASE
)
# Causes ("dropped due to rising rates"): invented when nothing was looked up at all, but
# normal in answers built from the user's own data ("risky because of one big holding").
_CAUSE_CLAIM = re.compile(r"due to|because of|driven by", re.IGNORECASE)
# Questions that need today's news: price moves and current events, not every "why"
# ("what is an ETF and why do beginners like them?" is a definition).
_NEWS_QUESTION = re.compile(
    r"\bnews\b|\bheadlines?\b|what happened|what's happening|what is happening"
    r"|\bwhy\b[^?]*\b(move[sd]?|moving|up|down|falls?|falling|fell|drops?|dropped|dropping"
    r"|rises?|rising|rose|jump(s|ed)?|surge[sd]?|crash(es|ed)?|today|this week|price)\b",
    re.IGNORECASE,
)
# "What is …", "what does … mean", "explain …": answered from the glossary when it has the term.
_DEFINITION_QUESTION = re.compile(
    r"^\s*(what(?:'s| is| are| does| do)|define|explain|meaning of)\b", re.IGNORECASE
)
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
    return bool(_NEWS_QUESTION.search(question)) and not cites_results(answer, sources)


# "You sold all your Bitcoin" without a tool call: the real model claimed a trade it never
# made. Actions only happen through tools, so such a claim must be backed by one.
_ACTION_CLAIM = re.compile(
    r"\b(you|i|we)('ve| have)?\s+(just\s+|now\s+|successfully\s+)?"
    r"(bought|sold|placed|added|removed|created|set up|cancell?ed)\b"
    r"|\b(has|have) been (bought|sold|placed|added|removed|created|set up|cancell?ed)\b",
    re.IGNORECASE,
)
# Reading the current state makes "you bought … earlier" a fact, not a claim.
STATE_TOOLS = {"get_practice_account", "get_portfolio", "get_watchlist", "list_alerts"}


def claims_unmade_action(
    answer: str, tools_used: set[str], actions: list[dict[str, Any]] | None = None
) -> bool:
    """The answer says something was bought/added/created, but no action happened this turn
    (an action tool that was refused doesn't count)."""
    if any(a.get("type") not in ("glossary_term", "lesson") for a in actions or []):
        return False
    if tools_used & STATE_TOOLS:
        return False
    return bool(_ACTION_CLAIM.search(answer))


_CARD_TOOLS = {
    "watchlist_added": "add_to_watchlist",
    "watchlist_removed": "remove_from_watchlist",
    "alert_created": "create_alert",
    "practice_order": "practice_trade",
    "glossary_term": "explain_term",
    "lesson": "find_lesson",
}


def _card_call(card: dict[str, Any]) -> ToolCall:
    """The tool call that produced an action card (enough for the model to recognise it)."""
    name = _CARD_TOOLS.get(card.get("type", ""), str(card.get("type")))
    if name == "find_lesson":
        return ToolCall(name, {"topic": card.get("name")})
    if name == "explain_term":
        return ToolCall(name, {"term": card.get("name")})
    args: dict[str, Any] = {"asset": card.get("symbol")}
    for key in ("side", "kind", "threshold"):
        if card.get(key) is not None:
            args[key] = card[key]
    return ToolCall(name, args)


def history_messages(message: Any) -> list[ChatMessage]:
    """A stored message as the model sees it. Past actions are replayed as the tool calls
    and results that did them: history otherwise holds only answers like "you bought
    0.004 BTC", which teach the model that saying so is enough (and a plain-text note
    about them got copied into answers)."""
    if message.role != "assistant" or not message.actions:
        return [ChatMessage(message.role, message.content)]
    calls = [_card_call(card) for card in message.actions]
    replay = [ChatMessage("assistant", "", tool_calls=calls)]
    replay += [
        ChatMessage("tool", json.dumps({"done": True, **card}, default=str), tool_name=call.name)
        for call, card in zip(calls, message.actions, strict=True)
    ]
    return [*replay, ChatMessage("assistant", message.content)]


# "What's my portfolio worth?" is about the user's things, not a definition.
_ABOUT_THEIR_THINGS = re.compile(r"\b(my|mine|our|your)\b", re.IGNORECASE)


# "I'd like to learn how diversification works": the model explained from memory instead of
# offering the lesson, so the backend looks the lesson up first.
_LEARNING_INTENT = re.compile(r"\b(learn|lessons?|teach me|quiz|course)\b", re.IGNORECASE)


def lesson_asked(question: str) -> str | None:
    """The lesson topic of a "teach me / I want to learn …" question, if a lesson covers it."""
    if not _LEARNING_INTENT.search(question):
        return None
    return question if lessons_content.find(question) else None


def glossary_term_asked(question: str) -> str | None:
    """The glossary term a definition question asks about ("What does P/E mean?")."""
    if not _DEFINITION_QUESTION.search(question) or _ABOUT_THEIR_THINGS.search(question):
        return None
    term = glossary.find(question)
    return term.term if term else None


# Money amounts and percentages ("$8,090", "80.9%", "SAR 25.80").
_FIGURE = re.compile(r"[$€£¥₹]\s?\d|\b\d[\d,]*(\.\d+)?\s?%|\b[A-Z]{3}\s?\d[\d,]*\.\d", re.UNICODE)


# Worked examples ("If a stock is $100, a 10% drop…") are fine without a lookup.
_HYPOTHETICAL = re.compile(
    r"\b(for example|example:|e\.g\.|imagine|suppose|say you|let's say|if a stock|if you "
    r"(buy|invest|had))\b",
    re.IGNORECASE,
)


def states_figures_from_memory(answer: str, tools_used: set[str], question: str = "") -> bool:
    """Figures with no lookup at all this turn: rule 1 says they must come from tools (the
    model reused numbers from earlier answers and mixed in practice-account money)."""
    if tools_used or question.strip().lower().startswith("if "):
        return False
    return bool(_FIGURE.search(answer)) and not _HYPOTHETICAL.search(answer)


def needs_news_retry(question: str, answer: str, tools_used: set[str]) -> bool:
    if tools_used & NEWS_TOOLS:
        return False
    if "explain_term" in tools_used and not _NEWS_QUESTION.search(question):
        return False  # a definition from the glossary, not news
    if _NEWS_CLAIM.search(answer) or _NEWS_QUESTION.search(question):
        return True
    return not tools_used and bool(_CAUSE_CLAIM.search(answer))


_HTTP_LINK = re.compile(r"\[([^\]\n]+)\]\((https?://[^)\s]+)\)")


def drop_foreign_links(text: str, sources: dict[str, tuple[str, str]]) -> str:
    """Keep only links to what the tools returned this turn; a URL the model typed itself
    may be invented, so it becomes plain text."""
    allowed = {url for url, _ in sources.values()}
    return _HTTP_LINK.sub(lambda m: m.group(0) if m.group(2) in allowed else m.group(1), text)


# Buy/sell judgements the small model slips in despite the rules ("buying Apple is a good
# starting point"). Sentences with them are dropped from the final answer.
_ADVICE = re.compile(
    r"\byou should (buy|sell|invest|start|consider (buying|selling))\b"
    r"|\bi(?:'d| would)? (recommend|suggest)\b"
    r"|\b(good|great|smart|safe|solid) (starting point|investment|buy|choice|pick|bet|"
    r"opportunity|time to (buy|sell|invest))\b"
    r"|\bworth (buying|investing)\b|\bmust[- ]buy\b",
    re.IGNORECASE,
)
# A sentence ends at . ! ? followed by a space or the line end ("$343.46" is not an end).
_SENTENCE = re.compile(r"\S.*?(?:[.!?](?=\s|$)|$)\s*")


def drop_advice(text: str) -> str:
    lines = []
    for line in text.split("\n"):
        kept = "".join(s for s in _SENTENCE.findall(line) if not _ADVICE.search(s))
        if kept.strip(" -*•") or not line.strip():
            lines.append(kept.rstrip() if kept.strip() else kept.strip())
    return re.sub(r"\n{3,}", "\n\n", "\n".join(lines)).strip()


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
    action_retried = False
    figures_retried = False
    if topic := lesson_asked(question):
        lookup = [ToolCall("find_lesson", {"topic": topic})]
        messages.append(ChatMessage("assistant", "", tool_calls=lookup))
        async for event in _run_calls(lookup, ctx, actions, messages, tools_used):
            yield event
    if term := glossary_term_asked(question):
        # The small model often explains terms from memory: give it the vetted text first.
        lookup = [ToolCall("explain_term", {"term": term})]
        messages.append(ChatMessage("assistant", "", tool_calls=lookup))
        async for event in _run_calls(lookup, ctx, actions, messages, tools_used):
            yield event
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
            if claims_unmade_action(answer, tools_used, actions):
                yield Retract()
                if not action_retried:
                    action_retried = True
                    messages.append(ChatMessage("assistant", round_text))
                    messages.append(ChatMessage("system", ACTION_RETRY.format(question=question)))
                    answer = ""
                    continue
                # Still claiming something that never happened: say so honestly.
                yield Delta(ACTION_NOT_DONE)
                yield ACTION_NOT_DONE
                return
            if states_figures_from_memory(answer, tools_used, question):
                yield Retract()
                if not figures_retried:
                    figures_retried = True
                    messages.append(ChatMessage("assistant", round_text))
                    messages.append(ChatMessage("system", FIGURES_RETRY))
                    answer = ""
                    continue
                # Numbers must come from this turn's lookups, never from memory.
                yield Delta(FIGURES_NOT_CHECKED)
                yield FIGURES_NOT_CHECKED
                return
            if not retried and needs_news_retry(question, answer, tools_used):
                # Possibly invented news: take the answer back and make the model look it up.
                retried = True
                yield Retract()
                yield Status("Checking the latest news…")
                messages.append(ChatMessage("assistant", round_text))
                messages.append(ChatMessage("system", NEWS_RETRY))
                answer = ""
                continue
            if (
                retried
                and not searched
                and not (tools_used & NEWS_TOOLS)
                and _NEWS_QUESTION.search(question)
            ):
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
        if result.action is not None and result.action not in actions:
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
    for m in history:  # includes the question
        messages += history_messages(m)
    messages.append(ChatMessage("system", TURN_REMINDER))
    ctx = toolbox.ToolContext(session, user, question=question)
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
    text = with_sources(resolve_citations(drop_advice(text), ctx.sources), ctx.sources)
    row = await chat_service.add_message(session, conversation, "assistant", text, actions)
    yield Done(row.id, text, actions)
