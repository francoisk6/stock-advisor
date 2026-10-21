from httpx import AsyncClient

from app.learn import glossary, lessons
from tests.conftest import bearer, onboard, register
from tests.test_copilot import ask, call, say


def test_lesson_content_is_consistent() -> None:
    all_lessons = lessons.lessons()
    ids = [x.id for x in all_lessons]
    assert len(ids) == len(set(ids)) >= 8
    term_ids = {t.id for t in glossary.terms()}
    for x in all_lessons:
        assert x.level in ("beginner", "intermediate"), x.id
        assert set(x.terms) <= term_ids, x.id
        assert x.sections and 3 <= x.minutes <= 8, x.id
        assert len(x.quiz) == 3, x.id
        for q in x.quiz:
            assert len(q.options) == 4 and 0 <= q.answer < 4, (x.id, q.question)
            assert len(set(q.options)) == 4 and q.explanation, (x.id, q.question)
    # Right answers aren't always in the same place.
    positions = {q.answer for x in all_lessons for q in x.quiz}
    assert positions == {0, 1, 2, 3}


def test_find_lesson_by_topic() -> None:
    assert lessons.find("What's a P/E ratio?").id == "reading-company-numbers"
    assert lessons.find("how do exchange rates affect me").id == "currencies-and-your-money"
    assert lessons.find("reading charts").id == "reading-a-price-chart"
    assert lessons.find("pizza") is None


async def test_lessons_suggested_from_interests(client: AsyncClient) -> None:
    tokens = await register(client)
    await onboard(client, tokens, assets=["crypto"])  # beginner
    data = (await client.get("/learn/lessons", headers=bearer(tokens))).json()
    suggested = [x["id"] for x in data if x["suggested"]]
    assert "what-moves-crypto" in suggested
    assert "what-is-a-stock" not in suggested  # not interested in stocks
    assert "reading-company-numbers" not in suggested  # intermediate
    assert data[: len(suggested)] == [x for x in data if x["suggested"]]  # first
    assert len(data) == len(lessons.lessons())


async def test_lesson_hides_answers_and_quiz_scores(client: AsyncClient, user: dict) -> None:
    lesson = (await client.get("/learn/lessons/what-moves-crypto", headers=bearer(user))).json()
    assert lesson["sections"][0]["heading"] == "Price = what buyers will pay"
    assert lesson["quiz"][0].keys() == {"question", "options"}  # no answer before submitting
    assert lesson["done"] is False

    url = "/learn/lessons/what-moves-crypto/quiz"
    first = (await client.post(url, headers=bearer(user), json={"answers": [1, 0, 0]})).json()
    assert first["score"] == 2 and first["total"] == 3
    assert [r["correct"] for r in first["results"]] == [True, False, True]
    assert (
        first["results"][1]["answer"] == 2
        and "recovery phrase" in first["results"][1]["explanation"]
    )
    second = (await client.post(url, headers=bearer(user), json={"answers": [0, 0, 0]})).json()
    assert second["score"] == 1 and second["best_score"] == 2  # best is kept

    listed = (await client.get("/learn/lessons", headers=bearer(user))).json()
    crypto = next(x for x in listed if x["id"] == "what-moves-crypto")
    assert crypto["done"] and crypto["best_score"] == 2 and not crypto["suggested"]

    short = await client.post(url, headers=bearer(user), json={"answers": [1]})
    assert short.status_code == 400 and "all 3 questions" in short.json()["detail"]
    missing = await client.get("/learn/lessons/nope", headers=bearer(user))
    assert missing.status_code == 404


async def test_copilot_points_to_a_lesson(user: dict, llm) -> None:
    llm(call("find_lesson", topic="diversification"), say("Here's a short lesson."))
    events = await ask(user, "I want to learn about diversification")
    assert events[-1]["actions"] == [
        {
            "type": "lesson",
            "lesson_id": "risk-and-diversification",
            "name": "Risk and diversification",
        }
    ]


def test_glossary_matches_plural_phrases() -> None:
    assert glossary.find("how do exchange rates work").id == "exchange-rate"


async def test_learning_questions_get_the_lesson_first(user: dict, llm) -> None:
    scripted = llm(say("Diversification spreads risk; the lesson below goes further."))
    events = await ask(user, "I'd like to learn how diversification works")
    first_round = scripted.calls[0]
    assert first_round[-1].role == "tool" and "Risk and diversification" in first_round[-1].content
    assert events[-1]["actions"] == [
        {
            "type": "lesson",
            "lesson_id": "risk-and-diversification",
            "name": "Risk and diversification",
        }
    ]
    assert len(scripted.calls) == 1  # no retries


def test_learning_intent() -> None:
    from app.ai.agent import lesson_asked

    assert lesson_asked("Teach me about crypto wallets")
    assert lesson_asked("Is there a lesson on ETFs?")
    assert lesson_asked("How is Apple doing?") is None
    assert lesson_asked("I want to learn to cook") is None  # no lesson on that
