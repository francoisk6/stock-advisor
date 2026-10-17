from datetime import timedelta

import pytest
from httpx import AsyncClient

from app.ai import agent
from app.core.time import utcnow
from app.market_data import service as market
from app.market_data.types import Range
from app.news import service as news_service
from app.news.google_news import NewsItem
from tests.conftest import bearer, register
from tests.fakes import FakeProvider
from tests.test_copilot import ScriptedLLM, say
from tests.test_news import FakeNews


@pytest.fixture
def setup(monkeypatch: pytest.MonkeyPatch):
    providers = {
        "yahoo": FakeProvider("yahoo"),
        "coingecko": FakeProvider("coingecko", (Range.d1,)),
    }
    monkeypatch.setattr(market, "providers", providers)  # +10% today
    news = FakeNews()
    monkeypatch.setattr(news_service, "provider", news)
    market.cache.clear()
    news_service.fetched.clear()

    def llm(*rounds, fail: bool = False) -> ScriptedLLM:
        scripted = ScriptedLLM(*rounds, fail=fail)
        monkeypatch.setattr(agent, "provider", scripted)
        return scripted

    yield providers, news, llm
    market.cache.clear()
    news_service.fetched.clear()


async def _btc(client: AsyncClient, user: dict) -> int:
    return (await client.get("/assets/search", params={"q": "btc"}, headers=bearer(user))).json()[
        0
    ]["id"]


async def test_explains_with_sources_and_is_shared(client: AsyncClient, setup) -> None:
    _, news, llm = setup
    news.items = [
        NewsItem(
            "ETF inflows jump", "https://news.example/etf", "Reuters", utcnow() - timedelta(hours=2)
        )
    ]
    scripted = llm(say("Bitcoin rose 10% today. According to [Reuters](n1), ETF inflows jumped."))
    user = await register(client)
    btc = await _btc(client, user)

    first = await client.post(f"/assets/{btc}/why", headers=bearer(user))
    assert first.status_code == 200
    body = first.json()
    assert body["content"] == (
        "Bitcoin rose 10% today. According to [Reuters](https://news.example/etf), ETF inflows "
        "jumped."
    )
    assert body["change_percent"] == pytest.approx(10.0)
    prompt = scripted.calls[0][1].content
    assert "[n1]" in prompt and "Reuters: ETF inflows jump" in prompt and "+10.00%" in prompt
    assert scripted.calls[0][0].role == "system"

    other = await register(client, email="bob@example.com")
    again = await client.post(f"/assets/{btc}/why", headers=bearer(other))
    assert again.json()["content"] == body["content"]
    assert len(scripted.calls) == 1  # shared: generated once per asset per day


async def test_quiet_day_no_news_and_model_down(client: AsyncClient, setup) -> None:
    providers, news, llm = setup
    user = await register(client)
    btc = await _btc(client, user)

    scripted = llm(say("unused"))
    no_news = await client.post(f"/assets/{btc}/why", headers=bearer(user))
    assert "couldn't find news" in no_news.json()["content"]
    assert scripted.calls == []  # nothing to summarise: the model isn't used

    aramco = await client.get("/assets/search", params={"q": "2222"}, headers=bearer(user))
    aramco_id = aramco.json()[0]["id"]
    news.items = [NewsItem("Oil climbs", "https://n/oil", "WSJ", utcnow())]
    llm(fail=True)
    down = await client.post(f"/assets/{aramco_id}/why", headers=bearer(user))
    assert down.status_code == 503 and "try again" in down.json()["detail"]

    market.cache.clear()

    class Flat(FakeProvider):
        async def quotes(self, symbols):
            quotes = await super().quotes(symbols)
            for q in quotes.values():
                q.previous_close = q.price / 1.005  # +0.5%
            return quotes

    providers["yahoo"] = Flat("yahoo")
    quiet = await client.post(f"/assets/{aramco_id}/why", headers=bearer(user))
    assert quiet.status_code == 400 and "normal day" in quiet.json()["detail"]
