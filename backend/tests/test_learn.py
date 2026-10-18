import json

from httpx import AsyncClient

from app.learn import glossary
from tests.conftest import bearer
from tests.test_copilot import ask, call, say


def test_glossary_content_is_consistent() -> None:
    terms = glossary.terms()
    ids = {t.id for t in terms}
    assert len(ids) == len(terms) >= 50
    for t in terms:
        assert t.category in glossary.CATEGORIES, t.id
        assert set(t.related) <= ids, t.id
        assert t.short.endswith(".") and len(t.short) <= 120, t.id
    # Every key figure on the asset page has an entry ("Explain this" links to it).
    for figure in (
        "market cap",
        "p/e ratio",
        "dividend yield",
        "expense ratio",
        "day range",
        "52-week range",
        "average volume",
        "beta",
        "sector",
        "industry",
        "rank",
        "24h volume",
        "circulating supply",
        "max supply",
        "all-time high",
    ):
        assert glossary.find(figure) is not None, figure


def test_find_matches_names_aliases_and_questions() -> None:
    assert glossary.find("P/E").id == "pe-ratio"
    assert glossary.find("what does p/e mean?").id == "pe-ratio"
    assert glossary.find("ETFs").id == "etf"
    assert glossary.find("Bid–ask spread").id == "bid-ask-spread"
    assert glossary.find("ETF (exchange-traded fund)").id == "etf"
    assert glossary.find("quantum foam") is None
    assert glossary.find("") is None


async def test_glossary_api(client: AsyncClient, user: dict) -> None:
    response = await client.get("/learn/glossary", headers=bearer(user))
    assert response.status_code == 200
    terms = response.json()
    assert [t["term"].lower() for t in terms] == sorted(t["term"].lower() for t in terms)
    pe = next(t for t in terms if t["id"] == "pe-ratio")
    assert pe["category"] == "valuation" and "eps" in pe["related"]

    one = await client.get("/learn/glossary/etf", headers=bearer(user))
    assert one.json()["term"].startswith("ETF")
    missing = await client.get("/learn/glossary/nope", headers=bearer(user))
    assert missing.status_code == 404 and "glossary" in missing.json()["detail"]
    # Unknown or hostile languages fall back to English (the value names a file).
    other = await client.get("/learn/glossary/etf?lang=../../x", headers=bearer(user))
    assert other.status_code == 200
    assert (await client.get("/learn/glossary")).status_code == 401


async def test_copilot_explains_terms_from_the_glossary(user: dict, llm) -> None:
    scripted = llm(
        call("explain_term", term="price to earnings"),
        say("P/E compares the price with yearly profit per share."),
    )
    events = await ask(user, "Tell me about price to earnings")

    result = json.loads(next(m.content for m in scripted.calls[1] if m.role == "tool"))
    assert result["found"] and result["term"] == "P/E ratio"
    assert result["explanation"] == glossary.get("pe-ratio").body
    assert events[-1]["actions"] == [
        {"type": "glossary_term", "term_id": "pe-ratio", "name": "P/E ratio"}
    ]
    statuses = [e["text"] for e in events if e["event"] == "status"]
    assert "Looking up “price to earnings” in the glossary…" in statuses


async def test_unknown_term_lets_the_model_explain(user: dict, llm) -> None:
    scripted = llm(call("explain_term", term="quantum foam"), say("That's physics."))
    events = await ask(user, "What is quantum foam?")
    result = json.loads(next(m.content for m in scripted.calls[1] if m.role == "tool"))
    assert result["found"] is False
    assert events[-1]["actions"] == []


async def test_definition_questions_get_the_glossary_text_first(user: dict, llm) -> None:
    scripted = llm(
        # Looks it up again anyway: no second card.
        call("explain_term", term="ETF"),
        say("An ETF is a basket of investments; beginners like the spread."),
    )
    events = await ask(user, "What is an ETF and why do beginners like them?")

    first_round = scripted.calls[0]
    assert (
        first_round[-1].role == "tool" and "basket of many investments" in first_round[-1].content
    )
    assert events[-1]["actions"] == [
        {"type": "glossary_term", "term_id": "etf", "name": "ETF (exchange-traded fund)"}
    ]
    # "why" in a definition question is not a news question: no retry, no forced search.
    assert "retract" not in [e["event"] for e in events]
    assert len(scripted.calls) == 2


def test_news_questions_are_told_apart() -> None:
    from app.ai.agent import _NEWS_QUESTION, glossary_term_asked

    for q in ("Why did Bitcoin move today?", "why is Aramco down", "Any news on Tesla?"):
        assert _NEWS_QUESTION.search(q), q
    for q in ("What is an ETF and why do beginners like them?", "Why do people buy gold?"):
        assert not _NEWS_QUESTION.search(q), q
    assert glossary_term_asked("What does P/E mean?") == "P/E ratio"
    assert glossary_term_asked("Explain market cap") == "Market capitalization"
    assert glossary_term_asked("How is Apple doing?") is None
    assert glossary_term_asked("What is the weather?") is None
