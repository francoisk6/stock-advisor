from datetime import timedelta

import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.ai import agent, background
from app.core.time import utcnow
from app.db.models import Notification
from app.db.session import SessionLocal
from app.jobs import daily
from app.market_data import service as market
from app.market_data.types import Range
from app.news import service as news_service
from app.news.google_news import NewsItem
from app.services.email import memory_outbox
from tests.conftest import bearer, onboard, register, token_from_last_email
from tests.fakes import FakeProvider
from tests.test_copilot import ScriptedLLM, say
from tests.test_news import FakeNews

BRIEF = (
    "## Your markets\n- Bitcoin is up 10%.\n## In the news\n- According to [Reuters](n1), "
    "ETF demand rose.\n## Worth watching today\n- Central bank comments."
)


@pytest.fixture
def setup(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setattr(
        market,
        "providers",
        {"yahoo": FakeProvider("yahoo"), "coingecko": FakeProvider("coingecko", (Range.d1,))},
    )
    news = FakeNews()
    news.items = [
        NewsItem(
            "Bitcoin ETF demand rises",
            "https://news.example/etf",
            "Reuters",
            utcnow() - timedelta(hours=3),
        )
    ]
    monkeypatch.setattr(news_service, "provider", news)
    market.cache.clear()
    news_service.fetched.clear()
    memory_outbox.clear()

    def llm(*rounds, fail: bool = False) -> ScriptedLLM:
        scripted = ScriptedLLM(*rounds, fail=fail)
        monkeypatch.setattr(agent, "provider", scripted)
        return scripted

    yield llm
    market.cache.clear()
    news_service.fetched.clear()


async def test_brief_from_watchlist_with_sources_once_a_day(client: AsyncClient, setup) -> None:
    scripted = setup(say(BRIEF))
    user = await register(client)
    await onboard(client, user, assets=["crypto"], regions=["global"])
    btc = await client.get("/assets/search", params={"q": "btc"}, headers=bearer(user))
    await client.put(f"/watchlist/assets/{btc.json()[0]['id']}", headers=bearer(user))

    assert (await client.get("/digest/today", headers=bearer(user))).json() is None
    started = await client.post("/digest/today", headers=bearer(user))
    assert started.json()["status"] == "writing"
    await background.wait(f"digest:{user['user']['id']}")
    made = (await client.get("/digest/today", headers=bearer(user))).json()
    assert made["status"] == "ready"
    assert "[Reuters](https://news.example/etf)" in made["content"]

    facts = scripted.calls[0][1].content
    assert "Bitcoin (BTC, crypto): $110.00, +10.00% vs previous close" in facts
    assert "[n1] BTC — Reuters: Bitcoin ETF demand rises" in facts
    assert "experience beginner" in facts

    again = await client.post("/digest/today", headers=bearer(user))
    assert again.json()["status"] == "ready" and again.json()["content"] == made["content"]
    assert len(scripted.calls) == 1  # one brief per user per day


async def test_brief_writer_down(client: AsyncClient, setup) -> None:
    setup(fail=True)
    user = await register(client)
    await onboard(client, user)
    await client.post("/digest/today", headers=bearer(user))
    await background.wait(f"digest:{user['user']['id']}")
    down = (await client.get("/digest/today", headers=bearer(user))).json()
    assert down["status"] == "failed" and "try again" in down["detail"]


async def test_morning_job_notifies_and_emails_opted_in_users(client: AsyncClient, setup) -> None:
    setup(say(BRIEF), say(BRIEF), say(BRIEF))
    ana = await register(client, email="ana@example.com")
    await onboard(client, ana, assets=["crypto"])  # brief covers popular crypto (Bitcoin)
    await client.post(
        "/auth/verify-email", json={"token": token_from_last_email("ana@example.com")}
    )
    prefs = await client.put(
        "/users/me/preferences", json={"digest_email": True}, headers=bearer(ana)
    )
    assert prefs.json()["profile"]["digest_email"] is True
    bob = await register(client, email="bob@example.com")
    await onboard(client, bob, assets=["crypto"])  # email not wanted
    await register(client, email="new@example.com")  # not onboarded: skipped
    memory_outbox.clear()

    today = utcnow().date()
    assert await daily.run_once_per_day("morning_briefs", today, daily.morning_briefs)
    assert not await daily.run_once_per_day("morning_briefs", today, daily.morning_briefs)

    async with SessionLocal() as session:
        kinds = [n.kind for n in (await session.execute(select(Notification))).scalars()]
    assert kinds == ["digest", "digest"]
    assert [e.to for e in memory_outbox] == ["ana@example.com"]
    email = memory_outbox[0]
    assert email.subject == "Your 2-minute morning brief"
    assert "Reuters (https://news.example/etf)" in email.text
    assert '<a href="https://news.example/etf">Reuters</a>' in email.html
