import json
from collections.abc import AsyncIterator

import httpx
import pytest
from httpx import AsyncClient

from app.ai import agent
from app.ai.ollama import OllamaProvider, parse_tool_calls
from app.ai.types import (
    AIUnavailable,
    ChatMessage,
    Finished,
    ProviderEvent,
    TextDelta,
    ToolCall,
    ToolCalls,
    ToolSpec,
)
from app.market_data import service as market
from app.market_data.types import Range
from app.services import copilot
from tests.conftest import bearer, register
from tests.fakes import FakeProvider


class ScriptedLLM:
    """Plays back one scripted list of events per model call and records what it was sent."""

    name = "scripted"

    def __init__(self, *rounds: list[ProviderEvent], fail: bool = False) -> None:
        self.rounds = list(rounds)
        self.fail = fail
        self.calls: list[list[ChatMessage]] = []

    async def stream_chat(
        self, messages: list[ChatMessage], tools: list[ToolSpec]
    ) -> AsyncIterator[ProviderEvent]:
        self.calls.append(list(messages))
        if self.fail:
            raise AIUnavailable("down")
        events = self.rounds.pop(0) if self.rounds else [TextDelta("(no script)")]
        for event in events:
            yield event
        yield Finished()


def say(*parts: str) -> list[ProviderEvent]:
    return [TextDelta(p) for p in parts]


def call(name: str, **arguments) -> list[ProviderEvent]:
    return [ToolCalls([ToolCall(name, arguments)])]


@pytest.fixture
def fakes(monkeypatch: pytest.MonkeyPatch) -> dict[str, FakeProvider]:
    providers = {
        "yahoo": FakeProvider("yahoo"),
        "coingecko": FakeProvider("coingecko", (Range.d1,)),
    }
    monkeypatch.setattr(market, "providers", providers)
    market.cache.clear()
    yield providers
    market.cache.clear()


async def ask(user: dict, text: str, **extra) -> list[dict]:
    return [e async for e in copilot.handle(user["user"]["id"], {"text": text, **extra})]


def kinds(events: list[dict]) -> list[str]:
    return [e["event"] for e in events]


async def test_plain_answer_is_streamed_and_saved(client: AsyncClient, user: dict, llm) -> None:
    scripted = llm(say("Hello", " Ana!"))
    events = await ask(user, "  hi   there ")

    assert kinds(events) == ["conversation", "status", "delta", "delta", "done"]
    assert events[0]["title"] == "hi there"
    done = events[-1]
    assert done["text"] == "Hello Ana!" and done["remaining_today"] == 4  # Free: 5 a day

    system = scripted.calls[0][0]
    assert system.role == "system"
    assert (
        "experience beginner" in system.content and "Do not tell the user to buy" in system.content
    )
    assert scripted.calls[0][-2] == ChatMessage("user", "hi there")
    assert scripted.calls[0][-1].role == "system"  # per-turn reminder after the question
    assert "THIS turn" in scripted.calls[0][-1].content

    convo = (
        await client.get(
            f"/chat/conversations/{events[0]['conversation_id']}", headers=bearer(user)
        )
    ).json()
    assert [(m["role"], m["content"]) for m in convo["messages"]] == [
        ("user", "hi there"),
        ("assistant", "Hello Ana!"),
    ]


async def test_tool_results_go_back_to_the_model(user: dict, llm, fakes) -> None:
    scripted = llm(call("get_quote", asset="BTC"), say("Bitcoin is at $110 (CoinGecko)."))
    events = await ask(user, "How is bitcoin doing?")

    assert "Looking up the price of BTC…" in [e.get("text") for e in events]
    tool_message = scripted.calls[1][-1]
    assert tool_message.role == "tool" and tool_message.tool_name == "get_quote"
    facts = json.loads(tool_message.content)
    assert facts["symbol"] == "BTC" and facts["price"] == 110.0
    assert facts["change_percent_today"] == 10.0 and facts["source"] == "CoinGecko"
    assert scripted.calls[1][-2].tool_calls[0].name == "get_quote"
    assert events[-1]["text"] == "Bitcoin is at $110 (CoinGecko)."


async def test_app_actions_return_cards(client: AsyncClient, user: dict, llm, fakes) -> None:
    llm(
        [
            ToolCalls(
                [
                    ToolCall("add_to_watchlist", {"asset": "2222.SR"}),
                    ToolCall(
                        "create_alert", {"asset": "2222.SR", "kind": "move_down", "threshold": 5}
                    ),
                ]
            )
        ],
        say("Done: Aramco is on your watchlist and I'll tell you if it falls 5% in a day."),
    )
    events = await ask(user, "Follow Aramco and warn me if it drops 5% in a day")

    cards = [e["card"] for e in events if e["event"] == "action"]
    assert [c["type"] for c in cards] == ["watchlist_added", "alert_created"]
    assert cards[1]["kind"] == "move_down" and cards[1]["threshold"] == 5.0
    assert events[-1]["actions"] == cards

    watchlist = (await client.get("/watchlist", headers=bearer(user))).json()
    assert [i["symbol"] for i in watchlist["items"]] == ["2222.SR"]
    alerts = (await client.get("/alerts", headers=bearer(user))).json()
    assert alerts[0]["kind"] == "move_down"


async def test_tool_errors_are_explained_by_the_model(user: dict, llm, fakes) -> None:
    scripted = llm(
        [
            ToolCalls(
                [
                    ToolCall("get_quote", {"asset": "zzzz-nothing"}),
                    ToolCall("create_alert", {"asset": "BTC", "kind": "explode", "threshold": 1}),
                    ToolCall("no_such_tool", {}),
                ]
            )
        ],
        say("Sorry, I couldn't find that."),
    )
    events = await ask(user, "price of zzzz?")
    results = [json.loads(m.content) for m in scripted.calls[1] if m.role == "tool"]
    assert "No asset found" in results[0]["error"]
    assert "kind must be" in results[1]["error"]
    assert "Unknown tool" in results[2]["error"]
    assert events[-1]["event"] == "done"


async def test_daily_limit(user: dict, llm, free_limits) -> None:
    await free_limits(ai_messages_per_day=1)
    llm(say("one"), say("two"))
    first = await ask(user, "first")
    second = await ask(user, "second")
    assert first[-1]["event"] == "done" and first[-1]["remaining_today"] == 0
    assert kinds(second) == ["error"] and second[0]["code"] == "plan_limit"
    assert "used all 1 copilot questions for today on the Free plan" in second[0]["detail"]
    assert "Pro (coming soon) has no daily limit" in second[0]["detail"]


async def test_model_down_and_endless_tools(client: AsyncClient, user: dict, llm, fakes) -> None:
    llm(fail=True)
    events = await ask(user, "hello?")
    assert events[-1] == {"event": "error", "detail": agent.UNAVAILABLE}
    usage = (await client.get("/chat/usage", headers=bearer(user))).json()
    assert usage == {"used_today": 0, "limit": 5}  # failed answers don't count

    llm(*[call("get_quote", asset="BTC")] * 10)
    events = await ask(user, "loop forever")
    assert "more steps than I can take" in events[-1]["text"]


async def test_follow_ups_use_history_and_context(
    client: AsyncClient, user: dict, llm, fakes
) -> None:
    llm(say("Aramco is an oil company."))
    first = await ask(user, "What is Aramco?")
    conversation_id = first[0]["conversation_id"]

    aramco = (await client.get("/assets/search", params={"q": "2222"}, headers=bearer(user))).json()
    scripted = llm(say("It pays a dividend."))
    await ask(
        user, "Does it pay dividends?", conversation_id=conversation_id, asset_id=aramco[0]["id"]
    )
    sent = scripted.calls[0]
    assert [m.content for m in sent[1:-1]] == [
        "What is Aramco?",
        "Aramco is an oil company.",
        "Does it pay dividends?",
    ]
    assert "looking at Saudi Aramco (Saudi Arabian Oil Company) (2222.SR" in sent[0].content

    other = await register(client, email="bob@example.com")
    stolen = [
        e
        async for e in copilot.handle(
            other["user"]["id"], {"text": "hi", "conversation_id": conversation_id}
        )
    ]
    assert stolen == [{"event": "error", "detail": "We couldn't find this conversation."}]


async def test_conversation_list_and_delete(client: AsyncClient, user: dict, llm) -> None:
    llm(say("a"), say("b"))
    await ask(user, "first question")
    await ask(user, "second question")
    listed = (await client.get("/chat/conversations", headers=bearer(user))).json()
    assert [c["title"] for c in listed] == ["second question", "first question"]
    removed = await client.delete(f"/chat/conversations/{listed[0]['id']}", headers=bearer(user))
    assert removed.status_code == 204
    assert len((await client.get("/chat/conversations", headers=bearer(user))).json()) == 1


async def test_empty_and_too_long_questions(user: dict) -> None:
    assert (await ask(user, "   "))[0]["detail"] == "Please type a question."
    assert "under 2,000" in (await ask(user, "x" * 2001))[0]["detail"]


# --- Ollama wire format ---------------------------------------------------------------------


def test_parse_tool_calls_accepts_string_arguments() -> None:
    calls = parse_tool_calls(
        [
            {"function": {"name": "get_quote", "arguments": '{"asset": "BTC"}'}},
            {"function": {"name": "get_watchlist", "arguments": {}}},
            {"function": {}},
        ]
    )
    assert calls == [ToolCall("get_quote", {"asset": "BTC"}), ToolCall("get_watchlist", {})]


async def test_ollama_streaming_parsing() -> None:
    sent: list[dict] = []

    def handler(request: httpx.Request) -> httpx.Response:
        sent.append(json.loads(request.content))
        lines = [
            {"message": {"role": "assistant", "content": "Let me check"}, "done": False},
            {
                "message": {
                    "role": "assistant",
                    "content": "",
                    "tool_calls": [
                        {"function": {"name": "get_quote", "arguments": {"asset": "BTC"}}}
                    ],
                },
                "done": False,
            },
            {
                "message": {"role": "assistant", "content": ""},
                "done": True,
                "prompt_eval_count": 120,
                "eval_count": 15,
                "total_duration": 2_500_000_000,
            },
        ]
        return httpx.Response(200, text="\n".join(json.dumps(x) for x in lines))

    provider = OllamaProvider(transport=httpx.MockTransport(handler))
    tools = [ToolSpec("get_quote", "price", {"type": "object", "properties": {}})]
    events = [
        e
        async for e in provider.stream_chat(
            [ChatMessage("user", "btc?"), ChatMessage("tool", "{}", tool_name="get_quote")], tools
        )
    ]

    assert events[0] == TextDelta("Let me check")
    assert events[1] == ToolCalls([ToolCall("get_quote", {"asset": "BTC"})])
    assert events[2] == Finished(prompt_tokens=120, output_tokens=15, seconds=2.5)
    body = sent[0]
    assert body["stream"] is True and body["think"] is False
    assert body["options"]["num_thread"] == 4
    assert body["tools"][0]["function"]["name"] == "get_quote"
    assert body["messages"][1] == {"role": "tool", "content": "{}", "tool_name": "get_quote"}


async def test_ollama_errors_become_unavailable() -> None:
    provider = OllamaProvider(
        transport=httpx.MockTransport(lambda r: httpx.Response(404, text="model not found"))
    )
    with pytest.raises(AIUnavailable, match="model not found"):
        [e async for e in provider.stream_chat([ChatMessage("user", "x")], [])]


async def test_common_names_resolve_to_the_curated_asset(
    client: AsyncClient, user: dict, llm, fakes
) -> None:
    # Yahoo would rank "Saudi Aramco Base Oil Company" (2223.SR) first for this query.
    from app.market_data.types import AssetType, FoundAsset

    fakes["yahoo"].search_results = [
        FoundAsset(
            "yahoo",
            "2223.SR",
            "2223.SR",
            "Saudi Aramco Base Oil Company",
            AssetType.stock,
            "Tadawul",
            "middle_east",
            "SA",
        ),
    ]
    scripted = llm(call("add_to_watchlist", asset="Saudi Aramco"), say("Added."))
    await ask(user, "add saudi aramco")
    added = json.loads(scripted.calls[1][-1].content)["added"]
    assert added["symbol"] == "2222.SR"
    assert added["name"] == "Saudi Aramco (Saudi Arabian Oil Company)"


async def test_news_and_web_answers_cite_real_links(user: dict, llm, fakes, monkeypatch) -> None:
    from datetime import timedelta

    from app.core.time import utcnow
    from app.news import service as news_service
    from app.news import web_search
    from app.news.google_news import NewsItem
    from tests.test_news import FakeNews

    news = FakeNews()
    news.items = [
        NewsItem(
            "Aramco profit rises",
            "https://news.example/aramco",
            "Reuters",
            utcnow() - timedelta(hours=1),
        )
    ]
    monkeypatch.setattr(news_service, "provider", news)
    news_service.fetched.clear()

    async def fake_search(query: str, limit: int = 5):
        return [web_search.WebResult("P/E explained", "https://web.example/pe", "Price ÷ EPS")]

    monkeypatch.setattr(web_search, "search", fake_search)

    scripted = llm(
        [
            ToolCalls(
                [
                    ToolCall("get_news", {"asset": "2222.SR"}),
                    ToolCall("web_search", {"query": "what is p/e"}),
                ]
            )
        ],
        say(
            "Aramco rose after results ([Reuters](n1)). P/E is price ÷ earnings "
            "([guide](w1)). Also [Made up](n9). Bare refs too [n1][n7]."
        ),
    )
    events = await ask(user, "Why did Aramco move, and what is P/E?")

    results = [json.loads(m.content) for m in scripted.calls[1] if m.role == "tool"]
    assert results[0]["headlines"][0] == {
        "title": "Aramco profit rises",
        "source": "Reuters",
        "published_utc": results[0]["headlines"][0]["published_utc"],
        "link": "n1",
    }
    assert results[1]["results"][0]["link"] == "w1"  # short refs, not long URLs
    statuses = [e["text"] for e in events if e["event"] == "status"]
    assert "Reading the latest news about 2222.SR…" in statuses
    assert "Searching the web for “what is p/e”…" in statuses

    final = events[-1]["text"]
    assert "[Reuters](https://news.example/aramco)" in final
    assert "[guide](https://web.example/pe)" in final
    assert "Also Made up." in final  # an invented reference is not turned into a link
    assert final.endswith("Bare refs too [Reuters](https://news.example/aramco).")


async def test_invented_news_is_retracted_and_looked_up(
    user: dict, llm, fakes, monkeypatch
) -> None:
    from app.news import service as news_service
    from tests.test_news import FakeNews

    monkeypatch.setattr(news_service, "provider", FakeNews())
    news_service.fetched.clear()
    scripted = llm(
        say("According to recent news, Bitcoin rose on ETF demand."),  # no lookup: invented
        call("get_news", asset="BTC"),
        say("I found no news about Bitcoin from the last 7 days."),
    )
    events = await ask(user, "Why did Bitcoin move today?")

    kinds_seen = kinds(events)
    assert "retract" in kinds_seen
    assert kinds_seen.index("retract") < len(kinds_seen) - 1
    assert (
        scripted.calls[1][-1].role == "system"
        and "may be invented" in scripted.calls[1][-1].content
    )
    assert events[-1]["text"] == "I found no news about Bitcoin from the last 7 days."


async def test_refusing_twice_triggers_a_web_search(user: dict, llm, monkeypatch) -> None:
    from app.news import web_search

    async def fake_search(query: str, limit: int = 5):
        assert query == "Why did Bitcoin move today?"
        return [web_search.WebResult("BTC slips", "https://web.example/btc", "Outflows")]

    monkeypatch.setattr(web_search, "search", fake_search)
    scripted = llm(
        say("I don't have live data on today's Bitcoin movement."),
        say("I can't check today's data."),  # asked again, still no lookup
        say("Bitcoin slipped on outflows ([web.example](w1))."),
    )
    events = await ask(user, "Why did Bitcoin move today?")

    last_round = scripted.calls[2]
    assert last_round[-1].content.startswith("You DID receive results")
    assert last_round[-2].role == "tool" and "w1" in last_round[-2].content
    assert "Searching the web for “Why did Bitcoin move today?”…" in [
        e["text"] for e in events if e["event"] == "status"
    ]
    assert (
        events[-1]["text"]
        == "Bitcoin slipped on outflows ([web.example](https://web.example/btc))."
    )


async def test_plain_answers_are_not_retried(user: dict, llm) -> None:
    scripted = llm(say("A P/E ratio compares a share price with yearly profit per share."))
    events = await ask(user, "What is a P/E ratio?")
    assert "retract" not in kinds(events)
    assert len(scripted.calls) == 1


async def test_uncited_news_answers_get_a_sources_line(user: dict, llm, fakes, monkeypatch) -> None:
    from app.news import service as news_service
    from tests.test_news import FakeNews

    news = FakeNews()
    from datetime import timedelta

    from app.core.time import utcnow
    from app.news.google_news import NewsItem

    news.items = [
        NewsItem("Bitcoin ETF outflows", "https://n.example/1", "Reuters", utcnow()),
        NewsItem(
            "Bitcoin tests $82K", "https://n.example/2", "CoinDesk", utcnow() - timedelta(hours=1)
        ),
    ]
    monkeypatch.setattr(news_service, "provider", news)
    news_service.fetched.clear()
    llm(
        [TextDelta("Let me check the news."), ToolCalls([ToolCall("get_news", {"asset": "BTC"})])],
        say("Bitcoin slipped as ETF investors pulled money out."),  # forgot to cite
    )
    events = await ask(user, "Why did Bitcoin move today?")
    kinds_seen = kinds(events)
    assert kinds_seen.index("retract") < kinds_seen.index("status", 2)  # filler taken back
    final = events[-1]["text"]
    assert not final.startswith("Let me check")
    assert final.endswith(
        "Sources: [Reuters](https://n.example/1), [CoinDesk](https://n.example/2)"
    )


async def test_answer_that_ignores_fetched_news_is_redone(
    user: dict, llm, fakes, monkeypatch
) -> None:
    from app.core.time import utcnow
    from app.news import service as news_service
    from app.news.google_news import NewsItem
    from tests.test_news import FakeNews

    news = FakeNews()
    news.items = [NewsItem("Bitcoin ETF outflows", "https://n.example/1", "Reuters", utcnow())]
    monkeypatch.setattr(news_service, "provider", news)
    news_service.fetched.clear()
    scripted = llm(
        call("get_news", asset="BTC"),
        say("I don't have today's Bitcoin news, check CoinGecko."),  # ignores the results
        say("According to [Reuters](n1), ETF investors pulled money out."),
    )
    events = await ask(user, "Why did Bitcoin move today?")
    assert scripted.calls[2][-1].content.startswith("You DID receive results")
    assert events[-1]["text"] == (
        "According to [Reuters](https://n.example/1), ETF investors pulled money out."
    )


async def test_honest_no_news_answer_is_not_redone(user: dict, llm, fakes, monkeypatch) -> None:
    from app.news import service as news_service
    from tests.test_news import FakeNews

    monkeypatch.setattr(news_service, "provider", FakeNews())  # finds nothing
    news_service.fetched.clear()
    scripted = llm(call("get_news", asset="BTC"), say("I can't find recent Bitcoin news."))
    events = await ask(user, "Why did Bitcoin move today?")
    assert len(scripted.calls) == 2 and events[-1]["text"] == "I can't find recent Bitcoin news."


async def test_invented_links_are_removed_and_uncited_answers_redone(
    user: dict, llm, fakes, monkeypatch
) -> None:
    from app.core.time import utcnow
    from app.news import service as news_service
    from app.news.google_news import NewsItem
    from tests.test_news import FakeNews

    news = FakeNews()
    news.items = [NewsItem("Bitcoin ETF outflows", "https://n.example/1", "Reuters", utcnow())]
    monkeypatch.setattr(news_service, "provider", news)
    news_service.fetched.clear()
    scripted = llm(
        call("get_news", asset="BTC"),
        # Cites a URL it typed itself, none of the fetched headlines -> redone once.
        say("According to [CoinGecko](https://www.coingecko.com/x), rates rose."),
        # Still mixes in a made-up link: that link loses its URL; the real one stays.
        say("According to [Reuters](n1), outflows grew; see [Blog](https://made.up/y)."),
    )
    events = await ask(user, "Why did Bitcoin move today?")
    assert scripted.calls[2][-1].content.startswith("You DID receive results")
    assert events[-1]["text"] == (
        "According to [Reuters](https://n.example/1), outflows grew; see Blog."
    )
