from datetime import timedelta
from decimal import Decimal

import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.core.time import utcnow
from app.db.models import Asset, Notification
from app.db.session import SessionLocal
from app.jobs.runner import run_practice_fills
from app.market_data import service as market
from app.market_data.types import Range
from app.services import practice
from tests.conftest import bearer, register
from tests.fakes import FakeProvider


@pytest.fixture
def fakes(monkeypatch: pytest.MonkeyPatch) -> dict[str, FakeProvider]:
    yahoo = FakeProvider("yahoo")
    yahoo.market_open = True
    yahoo.as_of = utcnow()
    yahoo.prices.update({"AAPL": 200.0, "SARUSD=X": 0.25, "GBPUSD=X": 1.25, "SHEL.L": 2000.0})
    crypto = FakeProvider("coingecko", (Range.d1,))
    crypto.prices["bitcoin"] = 80000.0
    providers = {"yahoo": yahoo, "coingecko": crypto}
    monkeypatch.setattr(market, "providers", providers)
    market.cache.clear()
    yield providers
    market.cache.clear()


async def asset_id(symbol: str) -> int:
    async with SessionLocal() as session:
        return (await session.execute(select(Asset.id).where(Asset.symbol == symbol))).scalar_one()


async def order(client: AsyncClient, tokens: dict, symbol: str, side: str, **amount):
    body = {"asset_id": await asset_id(symbol), "side": side}
    body.update({k: str(v) for k, v in amount.items()})
    return await client.post("/practice/orders", headers=bearer(tokens), json=body)


async def account(client: AsyncClient, tokens: dict) -> dict:
    response = await client.get("/practice", headers=bearer(tokens))
    assert response.status_code == 200, response.text
    return response.json()


async def test_account_opens_with_practice_cash(client: AsyncClient, user: dict) -> None:
    data = await account(client, user)
    assert data["starting_cash"] == data["cash"] == data["total_value"] == 10000
    assert data["gain_usd"] == 0 and data["positions"] == [] and data["pending"] == []
    assert (await client.get("/practice")).status_code == 401


async def test_buy_by_amount_and_by_units_with_currency_conversion(
    client: AsyncClient, user: dict, fakes
) -> None:
    bought = await order(client, user, "AAPL", "buy", amount_usd="1000")
    assert bought.status_code == 201, bought.text
    b = bought.json()
    assert b["status"] == "filled" and b["filled_quantity"] == 5 and b["total_usd"] == 1000

    # Aramco is priced in riyals: 110 SAR x 0.25 USD = $27.50 a share.
    aramco = (await order(client, user, "2222.SR", "buy", quantity="10")).json()
    assert aramco["price"] == 110 and aramco["currency"] == "SAR"
    assert aramco["fx_rate"] == 0.25 and aramco["total_usd"] == 275

    # London prices are in pence: 2000 GBp = £20 = $25.
    shell = (await order(client, user, "SHEL.L", "buy", quantity="2")).json()
    assert shell["total_usd"] == 50

    fakes["yahoo"].prices["AAPL"] = 220.0
    market.cache.clear()
    data = await account(client, user)
    assert data["cash"] == 10000 - 1000 - 275 - 50
    apple = next(p for p in data["positions"] if p["asset"]["symbol"] == "AAPL")
    assert apple["quantity"] == 5 and apple["average_price"] == 200
    assert apple["value_usd"] == 1100 and apple["gain_usd"] == 100 and apple["gain_percent"] == 10
    assert data["positions"][0]["asset"]["symbol"] == "AAPL"  # biggest first
    assert data["total_value"] == 10100 and data["gain_usd"] == 100 and data["gain_percent"] == 1


async def test_crypto_trades_around_the_clock(client: AsyncClient, user: dict, fakes) -> None:
    fakes["yahoo"].market_open = False  # stock markets closed; crypto still trades
    result = (await order(client, user, "BTC", "buy", amount_usd="100")).json()
    assert result["status"] == "filled" and result["filled_quantity"] == 0.00125


async def test_selling_locks_in_gains(client: AsyncClient, user: dict, fakes) -> None:
    await order(client, user, "AAPL", "buy", quantity="10")  # $2,000
    fakes["yahoo"].prices["AAPL"] = 250.0
    market.cache.clear()

    too_many = await order(client, user, "AAPL", "sell", quantity="11")
    assert too_many.status_code == 400
    assert too_many.json()["detail"] == "You have 10 AAPL to sell (worth about $2,500.00)."

    sold = (await order(client, user, "AAPL", "sell", quantity="4")).json()
    assert sold["total_usd"] == 1000 and sold["gain_usd"] == 200  # cost of 4 was $800
    data = await account(client, user)
    assert data["realized_usd"] == 200 and data["cash"] == 9000
    assert data["positions"][0]["quantity"] == 6 and data["positions"][0]["cost_usd"] == 1200

    # A dollar amount just over what's left (6 x $250 = $1,500) sells everything...
    rest = (await order(client, user, "AAPL", "sell", amount_usd="1510")).json()
    assert rest["filled_quantity"] == 6
    data = await account(client, user)
    assert data["positions"] == [] and data["cash"] == 10500 and data["gain_usd"] == 500


async def test_much_more_than_held_is_refused(client: AsyncClient, user: dict, fakes) -> None:
    await order(client, user, "AAPL", "buy", quantity="6")  # worth $1,200
    over = await order(client, user, "AAPL", "sell", amount_usd="1300")
    assert over.status_code == 400 and "You have 6 AAPL to sell" in over.json()["detail"]


async def test_friendly_refusals(client: AsyncClient, user: dict, fakes) -> None:
    poor = await order(client, user, "AAPL", "buy", amount_usd="20000")
    assert poor.status_code == 400
    assert "you have $10,000.00 of practice cash available" in poor.json()["detail"]

    index = await order(client, user, "SPX", "buy", amount_usd="100")
    assert index.status_code == 400 and "is a score" in index.json()["detail"]

    nothing = await order(client, user, "AAPL", "sell", quantity="1")
    assert nothing.json()["detail"] == "You don't have any AAPL in your practice account."

    tiny = await order(client, user, "AAPL", "buy", amount_usd="0.50")
    assert tiny.status_code == 400 and "smallest order is $1.00" in tiny.json()["detail"]

    both = await client.post(
        "/practice/orders",
        headers=bearer(user),
        json={
            "asset_id": await asset_id("AAPL"),
            "side": "buy",
            "quantity": "1",
            "amount_usd": "5",
        },
    )
    assert both.status_code == 422

    fakes["yahoo"].missing.add("SARUSD=X")
    no_rate = await order(client, user, "2222.SR", "buy", quantity="1")
    assert no_rate.status_code == 503 and "convert SAR" in no_rate.json()["detail"]


async def test_closed_market_orders_wait_for_the_open(
    client: AsyncClient, user: dict, fakes
) -> None:
    fakes["yahoo"].market_open = False
    waiting = (await order(client, user, "AAPL", "buy", amount_usd="1000")).json()
    assert waiting["status"] == "pending" and waiting["reserved_usd"] == 1000
    data = await account(client, user)
    assert data["available_cash"] == 9000 and data["cash"] == 10000
    assert [o["id"] for o in data["pending"]] == [waiting["id"]]

    # Reserved cash can't be spent twice.
    again = await order(client, user, "AAPL", "buy", amount_usd="9500")
    assert again.status_code == 400

    assert await run_practice_fills() == 0  # still closed
    checks = fakes["yahoo"].count("details")
    market.cache.clear()
    assert await run_practice_fills() == 0
    assert fakes["yahoo"].count("details") == checks  # closed: not asked again right away

    practice.closed_until.clear()  # 5 minutes later
    fakes["yahoo"].market_open = True
    fakes["yahoo"].prices["AAPL"] = 250.0  # opens higher
    market.cache.clear()
    assert await run_practice_fills() == 1

    data = await account(client, user)
    assert data["pending"] == [] and data["cash"] == 9000
    assert data["positions"][0]["quantity"] == 4  # $1,000 at the opening price of $250
    async with SessionLocal() as session:
        note = (await session.execute(select(Notification))).scalar_one()
    assert note.kind == "practice" and note.title == "Bought 4 AAPL (practice)"
    assert "filled when the market opened, at $250.00" in note.body


async def test_pending_orders_can_be_cancelled(client: AsyncClient, user: dict, fakes) -> None:
    fakes["yahoo"].market_open = False
    waiting = (await order(client, user, "AAPL", "buy", quantity="2")).json()
    other = await register(client, email="bo@example.com")
    stranger = await client.delete(f"/practice/orders/{waiting['id']}", headers=bearer(other))
    assert stranger.status_code == 404

    cancelled = await client.delete(f"/practice/orders/{waiting['id']}", headers=bearer(user))
    assert cancelled.json()["status"] == "cancelled"
    assert (await account(client, user))["available_cash"] == 10000
    again = await client.delete(f"/practice/orders/{waiting['id']}", headers=bearer(user))
    assert again.status_code == 400

    fakes["yahoo"].market_open = True
    market.cache.clear()
    assert await run_practice_fills() == 0


async def test_undo_takes_an_order_back(client: AsyncClient, user: dict, fakes) -> None:
    first = (await order(client, user, "AAPL", "buy", quantity="5")).json()
    second = (await order(client, user, "AAPL", "buy", quantity="1")).json()

    blocked = await client.post(f"/practice/orders/{first['id']}/undo", headers=bearer(user))
    assert blocked.status_code == 400 and "traded AAPL again" in blocked.json()["detail"]

    undone = await client.post(f"/practice/orders/{second['id']}/undo", headers=bearer(user))
    assert undone.json()["status"] == "undone"
    data = await account(client, user)
    assert data["cash"] == 9000 and data["positions"][0]["quantity"] == 5

    fakes["yahoo"].prices["AAPL"] = 300.0
    market.cache.clear()
    sold = (await order(client, user, "AAPL", "sell", quantity="5")).json()
    assert (await account(client, user))["positions"] == []
    await client.post(f"/practice/orders/{sold['id']}/undo", headers=bearer(user))
    data = await account(client, user)
    assert data["cash"] == 9000
    assert data["positions"][0]["quantity"] == 5 and data["positions"][0]["cost_usd"] == 1000


async def test_reset_starts_over(client: AsyncClient, user: dict, fakes) -> None:
    await order(client, user, "AAPL", "buy", amount_usd="500")
    reset = await client.post("/practice/reset", headers=bearer(user))
    assert reset.json()["cash"] == 10000 and reset.json()["positions"] == []
    history = await client.get("/practice/orders", headers=bearer(user))
    assert history.json() == []


async def test_order_preview_quote(client: AsyncClient, user: dict, fakes) -> None:
    await order(client, user, "2222.SR", "buy", quantity="4")
    quote = await client.get(f"/practice/quote/{await asset_id('2222.SR')}", headers=bearer(user))
    q = quote.json()
    assert q["price"] == 110 and q["currency"] == "SAR" and q["usd_price"] == 27.5
    assert q["market_open"] is True and q["held_quantity"] == 4 and q["available_cash"] == 9890


def test_money_stays_decimal() -> None:
    from app.services.practice import _cents, _units

    assert _cents(Decimal("0.005")) == Decimal("0.01")
    assert _units(Decimal("0.123456789")) == Decimal("0.12345678")


async def test_open_with_an_old_price_counts_as_closed(
    client: AsyncClient, user: dict, fakes
) -> None:
    fakes["yahoo"].as_of = utcnow() - timedelta(days=2)  # "open", but Friday's price
    waiting = (await order(client, user, "AAPL", "buy", quantity="1")).json()
    assert waiting["status"] == "pending"
