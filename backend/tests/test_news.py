from datetime import datetime, timedelta
from types import SimpleNamespace

import pytest
from httpx import AsyncClient

from app.core.time import utcnow
from app.market_data.types import ProviderError
from app.news import service as news_service
from app.news.google_news import NewsItem, news_query, parse_feed, short_name
from tests.conftest import bearer, register


def asset(name: str, asset_type: str = "stock", symbol: str = "X") -> SimpleNamespace:
    return SimpleNamespace(name=name, asset_type=asset_type, symbol=symbol)


def test_short_names_and_queries() -> None:
    assert short_name(asset("Saudi Aramco (Saudi Arabian Oil Company)")) == "Saudi Aramco"
    assert short_name(asset("NVIDIA Corporation")) == "NVIDIA"
    assert short_name(asset("Emaar Properties PJSC")) == "Emaar Properties"
    assert short_name(asset("QNB (Qatar National Bank)")) == "Qatar National Bank"
    assert short_name(asset("stc (Saudi Telecom Company)")) == "Saudi Telecom"
    assert news_query(asset("Bitcoin", "crypto")) == '"Bitcoin" crypto when:7d'
    assert news_query(asset("Euro / US Dollar", "forex", "EUR/USD")) == (
        '"EUR/USD" exchange rate when:7d'
    )
    assert news_query(asset("Gold", "commodity")) == '"Gold" price when:7d'


def test_parse_feed() -> None:
    xml = """<rss><channel>
      <item><title>Aramco profit rises - Reuters</title><link>https://n/1</link>
        <pubDate>Fri, 16 Oct 2026 20:31:51 GMT</pubDate><source url="x">Reuters</source></item>
      <item><title>No date</title><link>https://n/2</link></item>
    </channel></rss>"""
    (item,) = parse_feed(xml)
    assert item.title == "Aramco profit rises"  # " - Reuters" moved to source
    assert item.source == "Reuters"
    assert item.published_at == datetime(2026, 10, 16, 20, 31, 51)


class FakeNews:
    name = "google_news"

    def __init__(self) -> None:
        self.queries: list[str] = []
        self.fail = False
        self.items: list[NewsItem] = []

    async def search(self, query: str) -> list[NewsItem]:
        self.queries.append(query)
        if self.fail:
            raise ProviderError("down")
        return self.items


@pytest.fixture
def fake_news(monkeypatch: pytest.MonkeyPatch) -> FakeNews:
    fake = FakeNews()
    monkeypatch.setattr(news_service, "provider", fake)
    news_service.fetched.clear()
    yield fake
    news_service.fetched.clear()


async def test_news_endpoint_stores_dedupes_and_caches(
    client: AsyncClient, fake_news: FakeNews
) -> None:
    user = await register(client)
    aramco = await client.get("/assets/search", params={"q": "2222"}, headers=bearer(user))
    asset_id = aramco.json()[0]["id"]
    now = utcnow()
    fake_news.items = [
        NewsItem("Old story", "https://n/old", "Archive", now - timedelta(days=30)),
        NewsItem("Aramco profit rises", "https://n/1", "Reuters", now - timedelta(hours=2)),
        NewsItem("Aramco profit rises", "https://n/1", "Reuters", now - timedelta(hours=2)),
        NewsItem("Oil climbs", "https://n/2", "WSJ", now - timedelta(hours=1)),
        NewsItem("Oil  climbs", "https://n/2b", "WSJ", now - timedelta(hours=1)),  # syndicated
    ]

    first = (await client.get(f"/assets/{asset_id}/news", headers=bearer(user))).json()
    assert [n["title"] for n in first] == ["Oil climbs", "Aramco profit rises"]  # newest first
    assert first[0]["source"] == "WSJ" and first[0]["url"] == "https://n/2"
    assert fake_news.queries == ['"Saudi Aramco" stock when:7d']

    await client.get(f"/assets/{asset_id}/news", headers=bearer(user))
    assert len(fake_news.queries) == 1  # refreshed at most every 30 minutes

    news_service.fetched.clear()
    fake_news.fail = True  # source down: stored headlines still shown
    again = (await client.get(f"/assets/{asset_id}/news", headers=bearer(user))).json()
    assert [n["title"] for n in again] == ["Oil climbs", "Aramco profit rises"]
