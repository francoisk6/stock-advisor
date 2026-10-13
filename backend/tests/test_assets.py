import pytest
from httpx import AsyncClient

from app.market_data import service
from app.market_data.types import AssetType, FoundAsset, Range
from tests.conftest import bearer, onboard, register
from tests.fakes import FakeProvider


@pytest.fixture
def fake_providers(monkeypatch: pytest.MonkeyPatch) -> dict[str, FakeProvider]:
    fakes = {
        "yahoo": FakeProvider("yahoo"),
        "coingecko": FakeProvider("coingecko", ranges=(Range.d1, Range.w1, Range.m1, Range.y1)),
    }
    monkeypatch.setattr(service, "providers", fakes)
    service.cache.clear()
    yield fakes
    service.cache.clear()


@pytest.fixture
async def user(client: AsyncClient) -> dict:
    return await register(client)


async def _asset_id(client: AsyncClient, user: dict, query: str) -> int:
    response = await client.get("/assets/search", params={"q": query}, headers=bearer(user))
    return response.json()[0]["id"]


async def test_market_endpoints_require_sign_in(client: AsyncClient) -> None:
    assert (await client.get("/assets/popular")).status_code == 401
    assert (await client.get("/assets/search", params={"q": "aapl"})).status_code == 401


async def test_popular_follows_interests_and_markets(
    client: AsyncClient, user: dict, fake_providers: dict
) -> None:
    await onboard(client, user, assets=["stocks", "crypto"], regions=["middle_east"])

    response = await client.get("/assets/popular", headers=bearer(user))
    assert response.status_code == 200
    items = response.json()
    types = [a["asset_type"] for a in items]
    regions = {a["region"] for a in items}

    # Stocks first (interest order), only Middle East + global, nothing from the US.
    assert types[0] in ("stock", "index") and "crypto" in types
    assert types.index("crypto") > max(i for i, t in enumerate(types) if t in ("stock", "index"))
    assert regions == {"middle_east", "global"}
    assert items[0]["symbol"] == "2222.SR"
    # One batched upstream call per provider, quotes attached with catalog currency.
    assert fake_providers["yahoo"].count("quotes") == 1
    assert fake_providers["coingecko"].count("quotes") == 1
    aramco = items[0]["quote"]
    assert aramco["price"] == 110.0 and aramco["change_percent"] == pytest.approx(10.0)
    assert aramco["currency"] == "SAR"

    # Second load within a minute is served from the cache.
    await client.get("/assets/popular", headers=bearer(user))
    assert fake_providers["yahoo"].count("quotes") == 1


async def test_popular_global_includes_all_regions_and_type_filter(
    client: AsyncClient, user: dict, fake_providers: dict
) -> None:
    await onboard(client, user, assets=["stocks"], regions=["global"])
    items = (await client.get("/assets/popular", headers=bearer(user))).json()
    assert {"north_america", "europe", "middle_east", "asia_pacific"} <= {
        a["region"] for a in items
    }

    gold = await client.get("/assets/popular", params={"type": "commodity"}, headers=bearer(user))
    assert {a["asset_type"] for a in gold.json()} == {"commodity"}


async def test_popular_survives_provider_outage(
    client: AsyncClient, user: dict, fake_providers: dict
) -> None:
    await onboard(client, user, assets=["crypto"], regions=["global"])
    first = (await client.get("/assets/popular", headers=bearer(user))).json()
    assert all(a["quote"] for a in first)

    fake_providers["coingecko"].fail = True
    service.cache._values = {  # age the cached quotes past their 60 s freshness
        k: (t - 120, v) for k, (t, v) in service.cache._values.items()
    }
    second = (await client.get("/assets/popular", headers=bearer(user))).json()
    assert [a["quote"]["price"] for a in second] == [a["quote"]["price"] for a in first]

    service.cache.clear()  # nothing cached and the source is down: list still loads
    third = (await client.get("/assets/popular", headers=bearer(user))).json()
    assert third and all(a["quote"] is None for a in third)


async def test_search_finds_catalog_and_adds_provider_hits(
    client: AsyncClient, user: dict, fake_providers: dict
) -> None:
    fake_providers["yahoo"].search_results = [
        FoundAsset(
            "yahoo",
            "EMAAR.AE",
            "EMAAR.AE",
            "Emaar Properties",
            AssetType.stock,
            "Dubai Financial Market",
            "middle_east",
            "AE",
        ),
        FoundAsset(
            "yahoo",
            "EMAARDEV.AE",
            "EMAARDEV.AE",
            "Emaar Development",
            AssetType.stock,
            "Dubai Financial Market",
            "middle_east",
            "AE",
        ),
    ]

    first = (await client.get("/assets/search", params={"q": "emaar"}, headers=bearer(user))).json()
    symbols = [a["symbol"] for a in first]
    assert symbols[0] == "EMAAR.AE"  # from the catalog, not duplicated by the provider hit
    assert symbols.count("EMAAR.AE") == 1 and "EMAARDEV.AE" in symbols

    again = (await client.get("/assets/search", params={"q": "emaar"}, headers=bearer(user))).json()
    assert [a["id"] for a in again] == [a["id"] for a in first]  # stored once, same ids


async def test_search_by_symbol_and_when_providers_fail(
    client: AsyncClient, user: dict, fake_providers: dict
) -> None:
    for fake in fake_providers.values():
        fake.fail = True
    hits = (await client.get("/assets/search", params={"q": "btc"}, headers=bearer(user))).json()
    assert hits[0]["symbol"] == "BTC"
    gold = (await client.get("/assets/search", params={"q": "gold"}, headers=bearer(user))).json()
    assert gold[0]["name"] == "Gold"


async def test_asset_detail(client: AsyncClient, user: dict, fake_providers: dict) -> None:
    asset_id = await _asset_id(client, user, "2222")
    response = await client.get(f"/assets/{asset_id}", headers=bearer(user))
    assert response.status_code == 200
    body = response.json()
    assert body["name"] == "Saudi Arabian Oil Company"
    assert body["data_source"] == "Yahoo Finance"
    assert body["ranges"] == ["1D", "1W", "1M", "6M", "1Y", "5Y"]
    assert {"key": "sector", "value": "Energy", "unit": "text"} in body["stats"]
    assert body["description"] == "An oil company."

    assert (await client.get("/assets/999999", headers=bearer(user))).status_code == 404


async def test_history_ranges_cache_and_errors(
    client: AsyncClient, user: dict, fake_providers: dict
) -> None:
    btc = await _asset_id(client, user, "btc")

    ok = await client.get(f"/assets/{btc}/history", params={"range": "1M"}, headers=bearer(user))
    assert ok.status_code == 200
    body = ok.json()
    assert body["range"] == "1M" and body["currency"] == "USD"
    assert body["candles"][0] == {
        "t": "2026-10-01T00:00:00",
        "o": 101.0,
        "h": 103.0,
        "l": 100.0,
        "c": 102.0,
        "v": 1000.0,
    }
    await client.get(f"/assets/{btc}/history", params={"range": "1M"}, headers=bearer(user))
    assert fake_providers["coingecko"].count("history") == 1

    too_long = await client.get(
        f"/assets/{btc}/history", params={"range": "5Y"}, headers=bearer(user)
    )
    assert too_long.status_code == 400
    assert "isn't available" in too_long.json()["detail"]

    fake_providers["coingecko"].fail = True
    down = await client.get(f"/assets/{btc}/history", params={"range": "1D"}, headers=bearer(user))
    assert down.status_code == 503
    assert "try again" in down.json()["detail"]

    bad = await client.get(f"/assets/{btc}/history", params={"range": "2Y"}, headers=bearer(user))
    assert bad.status_code == 422


async def test_search_ranks_exact_and_name_matches_first(
    client: AsyncClient, user: dict, fake_providers: dict
) -> None:
    fake_providers["yahoo"].search_results = [
        FoundAsset(
            "yahoo",
            "NVDX",
            "NVDX",
            "T-Rex 2X Long NVIDIA",
            AssetType.etf,
            "Cboe",
            "north_america",
            "US",
        ),
        FoundAsset(
            "yahoo",
            "NVD.DE",
            "NVD.DE",
            "NVIDIA Corporation",
            AssetType.stock,
            "XETRA",
            "europe",
            "DE",
        ),
    ]
    hits = (await client.get("/assets/search", params={"q": "nvidia"}, headers=bearer(user))).json()
    assert [h["symbol"] for h in hits] == ["NVDA", "NVD.DE", "NVDX"]
