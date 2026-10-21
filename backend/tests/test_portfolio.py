import json

import pytest
from httpx import AsyncClient

from app.core.time import utcnow
from app.market_data import service as market
from app.market_data.types import Range
from app.services import plans
from tests.conftest import bearer, register
from tests.fakes import FakeProvider
from tests.test_practice import asset_id


@pytest.fixture
def fakes(monkeypatch: pytest.MonkeyPatch) -> dict[str, FakeProvider]:
    yahoo = FakeProvider("yahoo")
    yahoo.as_of = utcnow()
    yahoo.prices.update({"AAPL": 200.0, "2222.SR": 110.0, "SARUSD=X": 0.25})
    crypto = FakeProvider("coingecko", (Range.d1,))
    crypto.prices["bitcoin"] = 80000.0
    providers = {"yahoo": yahoo, "coingecko": crypto}
    monkeypatch.setattr(market, "providers", providers)
    market.cache.clear()
    yield providers
    market.cache.clear()


async def add(client: AsyncClient, tokens: dict, symbol: str, quantity, price, **extra):
    body = {
        "asset_id": await asset_id(symbol),
        "quantity": str(quantity),
        "average_price": str(price),
        **extra,
    }
    return await client.post("/portfolio/holdings", headers=bearer(tokens), json=body)


async def three_holdings(client: AsyncClient, user: dict) -> dict:
    await add(client, user, "AAPL", 10, 150)  # worth $2,000, cost $1,500
    await add(client, user, "2222.SR", 100, 100)  # 100 x SAR 110 x 0.25 = $2,750, cost $2,500
    response = await add(client, user, "BTC", "0.01", 60000)  # worth $800, cost $600
    assert response.status_code == 201, response.text
    return response.json()


async def test_empty_portfolio(client: AsyncClient, user: dict, fakes) -> None:
    data = (await client.get("/portfolio", headers=bearer(user))).json()
    assert data["currency"] == "USD" and data["total_value"] == 0
    assert data["holdings"] == [] and data["risks"] == [] and data["gain_percent"] is None


async def test_values_allocation_and_risks(client: AsyncClient, user: dict, fakes) -> None:
    data = await three_holdings(client, user)
    assert data["total_value"] == 5550 and data["total_cost"] == 4600 and data["gain"] == 950
    assert [h["asset"]["symbol"] for h in data["holdings"]] == ["2222.SR", "AAPL", "BTC"]
    aramco = data["holdings"][0]
    assert aramco["currency"] == "SAR" and aramco["price"] == 110
    assert aramco["value"] == 2750 and aramco["gain"] == 250 and aramco["gain_percent"] == 10
    assert round(aramco["share_percent"], 1) == 49.5

    assert {s["key"]: s["value"] for s in data["by_type"]} == {"stock": 4750, "crypto": 800}
    assert {s["key"]: s["value"] for s in data["by_currency"]} == {"USD": 2800, "SAR": 2750}
    risks = {r["code"]: r for r in data["risks"]}
    assert set(risks) == {"concentration", "few_holdings"}
    assert risks["concentration"]["params"] == {
        "symbol": "2222.SR",
        "percent": 49.5,
        "drop_if_30": 14.9,
    }
    assert risks["few_holdings"]["params"] == {"count": 3}


async def test_values_in_the_users_currency(client: AsyncClient, user: dict, fakes) -> None:
    await three_holdings(client, user)
    data = (
        await client.put("/portfolio/currency", headers=bearer(user), json={"currency": "sar"})
    ).json()
    assert data["currency"] == "SAR"
    assert data["total_value"] == 22200  # $5,550 / 0.25
    apple = next(h for h in data["holdings"] if h["asset"]["symbol"] == "AAPL")
    assert apple["value"] == 8000 and apple["price"] == 200 and apple["currency"] == "USD"
    # Now dollars are the foreign currency: 50.5% of the value.
    foreign = next(r for r in data["risks"] if r["code"] == "foreign_currency")
    assert foreign["params"] == {"percent": 50.5, "currency": "SAR"}

    fakes["yahoo"].missing.add("XYZUSD=X")
    bad = await client.put("/portfolio/currency", headers=bearer(user), json={"currency": "XYZ"})
    assert bad.status_code == 400 and "XYZ" in bad.json()["detail"]


async def test_adding_more_averages_the_price(client: AsyncClient, user: dict, fakes) -> None:
    await add(client, user, "AAPL", 10, 150)
    data = (await add(client, user, "AAPL", 10, 250, bought_on="2026-01-05")).json()
    apple = data["holdings"][0]
    assert apple["quantity"] == 20 and apple["average_price"] == 200
    assert apple["bought_on"] == "2026-01-05"


async def test_edit_delete_and_refusals(client: AsyncClient, user: dict, fakes) -> None:
    data = (await add(client, user, "AAPL", 10, 150)).json()
    holding_id = data["holdings"][0]["id"]

    edited = await client.put(
        f"/portfolio/holdings/{holding_id}",
        headers=bearer(user),
        json={"quantity": "4", "average_price": "180", "note": "From my bonus"},
    )
    apple = edited.json()["holdings"][0]
    assert apple["quantity"] == 4 and apple["average_price"] == 180
    assert apple["note"] == "From my bonus"

    index = await add(client, user, "SPX", 1, 100)
    assert index.status_code == 400 and "is a score" in index.json()["detail"]
    zero = await add(client, user, "AAPL", 0, 100)
    assert zero.status_code == 422

    other = await register(client, email="bo@example.com")
    stranger = await client.delete(f"/portfolio/holdings/{holding_id}", headers=bearer(other))
    assert stranger.status_code == 404
    gone = await client.delete(f"/portfolio/holdings/{holding_id}", headers=bearer(user))
    assert gone.status_code == 204
    assert (await client.get("/portfolio", headers=bearer(user))).json()["holdings"] == []


async def test_free_plan_limit(client: AsyncClient, user: dict, fakes, monkeypatch) -> None:
    monkeypatch.setattr(plans, "plan_limit", lambda user, key: 1)
    assert (await add(client, user, "AAPL", 1, 100)).status_code == 201
    over = await add(client, user, "BTC", 1, 100)
    assert over.status_code == 403 and "up to 1 holdings" in over.json()["detail"]
    # Buying more of something already tracked is not a new holding.
    assert (await add(client, user, "AAPL", 1, 100)).status_code == 201


async def test_copilot_reads_the_portfolio(client: AsyncClient, user: dict, llm, fakes) -> None:
    from tests.test_copilot import ask, call, say

    await three_holdings(client, user)
    scripted = llm(call("get_portfolio"), say("Aramco is half of it."))
    await ask(user, "How risky is my portfolio?")
    data = json.loads(next(m.content for m in scripted.calls[1] if m.role == "tool"))
    assert data["total_value"] == 5550 and data["holdings"][0]["symbol"] == "2222.SR"
    assert data["risk_notes"][0].startswith("2222.SR is 49.5% of the portfolio")


async def test_brief_covers_holdings_and_watchlist(client: AsyncClient, user: dict, fakes) -> None:
    from app.ai import digest
    from app.db.models import User
    from app.db.session import SessionLocal

    await add(client, user, "AAPL", 1, 100)
    await client.put(f"/watchlist/assets/{await asset_id('BTC')}", headers=bearer(user))
    async with SessionLocal() as session:
        me = await session.get(User, user["user"]["id"])
        assets = await digest.brief_assets(session, me)
    assert [a.symbol for a in assets] == ["AAPL", "BTC"]


def test_explanations_from_own_data_are_not_news_claims() -> None:
    from app.ai.agent import needs_news_retry

    q = "How risky is my portfolio?"
    answer = "It's risky because of one big holding, due to its 72% share."
    assert not needs_news_retry(q, answer, {"get_portfolio"})
    # The same causes with no lookup at all may be invented.
    assert needs_news_retry("Is Bitcoin volatile?", "It fell due to rising rates.", set())
    assert needs_news_retry(q, "According to reports, tech fell.", {"get_portfolio"})


async def test_figures_need_a_lookup_in_the_same_turn(
    client: AsyncClient, user: dict, llm, fakes
) -> None:
    from tests.test_copilot import ask, call, say

    await add(client, user, "AAPL", 10, 150)
    scripted = llm(
        say("Your portfolio is worth $10,000 in virtual dollars."),  # from memory
        call("get_portfolio"),
        say("Your portfolio is worth $2,000."),
    )
    events = await ask(user, "What's my portfolio worth?")
    assert scripted.calls[1][-1].content.startswith("Your answer contains figures")
    assert events[-1]["text"] == "Your portfolio is worth $2,000."


async def test_figures_never_shown_unchecked(user: dict, llm) -> None:
    from tests.test_copilot import ask, say

    llm(say("You have $10,000."), say("I checked: you have $10,000."))
    events = await ask(user, "And my practice account?")
    assert events[-1]["text"].startswith("Sorry, I couldn't look up the numbers")


def test_figures_are_recognised() -> None:
    from app.ai.agent import states_figures_from_memory

    for text in ("Worth $8,090.", "Apple is 80.9% of it.", "Aramco is SAR 25.80 today."):
        assert states_figures_from_memory(text, set()), text
    assert not states_figures_from_memory("A P/E compares price and profit.", set())
    assert not states_figures_from_memory("Worth $8,090.", {"get_portfolio"})
    example = "For example, if a stock is $100, a 10% drop makes it $90."
    assert not states_figures_from_memory(example, set())
    assert not states_figures_from_memory("It ends at $99.", set(), "If it falls 10%…?")
