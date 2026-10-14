from datetime import timedelta

import pytest
from httpx import AsyncClient
from sqlalchemy import update

from app.core.time import utcnow
from app.db.models import Alert, Plan
from app.db.session import SessionLocal
from app.jobs.runner import run_alert_check
from app.market_data import service
from app.market_data.types import Range
from app.services.email import memory_outbox
from tests.conftest import bearer, register, token_from_last_email
from tests.fakes import FakeProvider


@pytest.fixture
def fakes(monkeypatch: pytest.MonkeyPatch) -> dict[str, FakeProvider]:
    providers = {
        "yahoo": FakeProvider("yahoo"),
        "coingecko": FakeProvider("coingecko", ranges=(Range.d1, Range.y1)),
    }
    monkeypatch.setattr(service, "providers", providers)
    service.cache.clear()
    yield providers
    service.cache.clear()


@pytest.fixture
async def user(client: AsyncClient) -> dict:
    return await register(client)


async def asset_id(client: AsyncClient, user: dict, query: str) -> int:
    hits = await client.get("/assets/search", params={"q": query}, headers=bearer(user))
    return hits.json()[0]["id"]


async def set_free_limit(key: str, value: int) -> None:
    async with SessionLocal() as session:
        plan = (await session.execute(Plan.__table__.select().where(Plan.code == "free"))).first()
        limits = dict(plan.limits)
        limits[key] = value
        await session.execute(update(Plan).where(Plan.code == "free").values(limits=limits))
        await session.commit()


@pytest.fixture
async def restore_limits():
    yield
    await set_free_limit("watchlist_assets", 25)
    await set_free_limit("alerts", 10)


# --- watchlist ------------------------------------------------------------------------------


async def test_watchlist_add_remove_and_detail_flag(
    client: AsyncClient, user: dict, fakes: dict
) -> None:
    empty = (await client.get("/watchlist", headers=bearer(user))).json()
    assert empty["name"] == "My watchlist" and empty["items"] == [] and empty["limit"] == 25

    aramco = await asset_id(client, user, "2222")
    btc = await asset_id(client, user, "btc")
    await client.put(f"/watchlist/assets/{aramco}", headers=bearer(user))
    again = await client.put(f"/watchlist/assets/{aramco}", headers=bearer(user))  # idempotent
    full = (await client.put(f"/watchlist/assets/{btc}", headers=bearer(user))).json()

    assert again.status_code == 200
    assert [i["symbol"] for i in full["items"]] == ["2222.SR", "BTC"]
    assert full["items"][0]["quote"]["price"] == 110.0
    detail = (await client.get(f"/assets/{aramco}", headers=bearer(user))).json()
    assert detail["in_watchlist"] is True

    after = (await client.delete(f"/watchlist/assets/{aramco}", headers=bearer(user))).json()
    assert [i["symbol"] for i in after["items"]] == ["BTC"]
    detail = (await client.get(f"/assets/{aramco}", headers=bearer(user))).json()
    assert detail["in_watchlist"] is False

    assert (await client.put("/watchlist/assets/999999", headers=bearer(user))).status_code == 404


async def test_watchlist_plan_limit(
    client: AsyncClient, user: dict, fakes: dict, restore_limits
) -> None:
    await set_free_limit("watchlist_assets", 1)
    first = await asset_id(client, user, "2222")
    second = await asset_id(client, user, "btc")
    assert (await client.put(f"/watchlist/assets/{first}", headers=bearer(user))).status_code == 200
    blocked = await client.put(f"/watchlist/assets/{second}", headers=bearer(user))
    assert blocked.status_code == 403
    assert "up to 1 assets" in blocked.json()["detail"]


async def test_watchlists_are_private(client: AsyncClient, user: dict, fakes: dict) -> None:
    other = await register(client, email="bob@example.com")
    btc = await asset_id(client, user, "btc")
    await client.put(f"/watchlist/assets/{btc}", headers=bearer(user))
    assert (await client.get("/watchlist", headers=bearer(other))).json()["items"] == []


# --- alerts ---------------------------------------------------------------------------------


async def create_alert(client, user, asset, kind, threshold, **extra) -> dict:
    response = await client.post(
        "/alerts",
        headers=bearer(user),
        json={"asset_id": asset, "kind": kind, "threshold": threshold, **extra},
    )
    assert response.status_code == 201, response.text
    return response.json()


async def test_alert_crud_validation_and_ownership(
    client: AsyncClient, user: dict, fakes: dict
) -> None:
    btc = await asset_id(client, user, "btc")
    alert = await create_alert(client, user, btc, "price_above", "120.5")
    assert alert["asset"]["symbol"] == "BTC" and alert["threshold"] == 120.5
    assert alert["is_active"] and alert["notify_email"]

    for bad in (
        {"kind": "price_above", "threshold": 0},
        {"kind": "move_up", "threshold": 80},
        {"kind": "explode", "threshold": 5},
    ):
        response = await client.post("/alerts", headers=bearer(user), json={"asset_id": btc, **bad})
        assert response.status_code in (400, 422), bad

    listed = (await client.get("/alerts", params={"asset_id": btc}, headers=bearer(user))).json()
    assert [a["id"] for a in listed] == [alert["id"]]

    paused = await client.patch(
        f"/alerts/{alert['id']}", headers=bearer(user), json={"is_active": False, "threshold": 130}
    )
    assert paused.json()["is_active"] is False and paused.json()["threshold"] == 130

    stranger = await register(client, email="eve@example.com")
    assert (
        await client.delete(f"/alerts/{alert['id']}", headers=bearer(stranger))
    ).status_code == 404
    assert (await client.delete(f"/alerts/{alert['id']}", headers=bearer(user))).status_code == 204
    assert (await client.get("/alerts", headers=bearer(user))).json() == []


async def test_alert_plan_limit_counts_active_only(
    client: AsyncClient, user: dict, fakes: dict, restore_limits
) -> None:
    await set_free_limit("alerts", 1)
    btc = await asset_id(client, user, "btc")
    first = await create_alert(client, user, btc, "price_above", 200)
    blocked = await client.post(
        "/alerts", headers=bearer(user), json={"asset_id": btc, "kind": "move_up", "threshold": 5}
    )
    assert blocked.status_code == 403
    await client.patch(f"/alerts/{first['id']}", headers=bearer(user), json={"is_active": False})
    await create_alert(client, user, btc, "move_up", 5)  # room again
    reactivate = await client.patch(
        f"/alerts/{first['id']}", headers=bearer(user), json={"is_active": True}
    )
    assert reactivate.status_code == 403


# --- checking -------------------------------------------------------------------------------


async def test_price_alert_fires_once_and_switches_off(
    client: AsyncClient, user: dict, fakes: dict
) -> None:
    # Confirm the email so alert emails are allowed.
    await client.post(
        "/auth/verify-email", json={"token": token_from_last_email("ana@example.com")}
    )
    memory_outbox.clear()
    btc = await asset_id(client, user, "btc")  # fake price 110, previous close 100
    hit = await create_alert(client, user, btc, "price_above", 105)
    await create_alert(client, user, btc, "price_below", 90)  # not reached
    quiet = await create_alert(client, user, btc, "price_above", 105, notify_email=False)

    assert await run_alert_check() == 2
    assert await run_alert_check() == 0  # one-shot: already switched off

    alerts = {a["id"]: a for a in (await client.get("/alerts", headers=bearer(user))).json()}
    assert alerts[hit["id"]]["is_active"] is False and alerts[hit["id"]]["trigger_count"] == 1
    assert alerts[quiet["id"]]["is_active"] is False

    inbox = (await client.get("/notifications", headers=bearer(user))).json()
    assert inbox["unread_count"] == 2
    assert inbox["items"][0]["title"] == "BTC is above $105.00"
    assert "$110.00 (+10.00% today)" in inbox["items"][0]["body"]
    assert [e.subject for e in memory_outbox] == ["Price alert: BTC is above $105.00"]
    assert f"/assets/{btc}" in memory_outbox[0].text


async def test_unverified_users_get_in_app_only(
    client: AsyncClient, user: dict, fakes: dict
) -> None:
    memory_outbox.clear()
    btc = await asset_id(client, user, "btc")
    await create_alert(client, user, btc, "price_above", 105)
    assert await run_alert_check() == 1
    assert memory_outbox == []
    assert (await client.get("/notifications", headers=bearer(user))).json()["unread_count"] == 1


async def test_daily_move_alert_fires_once_per_day(
    client: AsyncClient, user: dict, fakes: dict
) -> None:
    aramco = await asset_id(client, user, "2222")  # fake +10% today
    up = await create_alert(client, user, aramco, "move_up", 5)
    await create_alert(client, user, aramco, "move_down", 5)  # wrong direction
    await create_alert(client, user, aramco, "move_up", 15)  # not big enough

    assert await run_alert_check() == 1
    assert await run_alert_check() == 0  # same day
    inbox = (await client.get("/notifications", headers=bearer(user))).json()
    assert inbox["items"][0]["title"] == "2222.SR moved +10.00% today"
    assert "SAR 110.00" in inbox["items"][0]["body"]

    async with SessionLocal() as session:  # pretend it fired yesterday
        await session.execute(
            update(Alert)
            .where(Alert.id == up["id"])
            .values(last_triggered_at=utcnow() - timedelta(days=1))
        )
        await session.commit()
    assert await run_alert_check() == 1
    still = (await client.get("/alerts", params={"asset_id": aramco}, headers=bearer(user))).json()
    assert next(a for a in still if a["id"] == up["id"])["is_active"] is True


async def test_no_price_means_no_alert(client: AsyncClient, user: dict, fakes: dict) -> None:
    btc = await asset_id(client, user, "btc")
    await create_alert(client, user, btc, "price_above", 1)
    fakes["coingecko"].fail = True
    assert await run_alert_check() == 0


async def test_notifications_mark_read(client: AsyncClient, user: dict, fakes: dict) -> None:
    btc = await asset_id(client, user, "btc")
    await create_alert(client, user, btc, "price_above", 1)
    await create_alert(client, user, btc, "price_below", 1000)
    await run_alert_check()

    inbox = (await client.get("/notifications", headers=bearer(user))).json()
    assert inbox["unread_count"] == 2
    first = inbox["items"][0]["id"]
    await client.post(f"/notifications/{first}/read", headers=bearer(user))
    inbox = (await client.get("/notifications", headers=bearer(user))).json()
    assert inbox["unread_count"] == 1
    assert next(i for i in inbox["items"] if i["id"] == first)["read"] is True

    other = await register(client, email="bob@example.com")
    await client.post("/notifications/read-all", headers=bearer(other))  # can't touch Ana's
    assert (await client.get("/notifications", headers=bearer(user))).json()["unread_count"] == 1
    await client.post("/notifications/read-all", headers=bearer(user))
    assert (await client.get("/notifications", headers=bearer(user))).json()["unread_count"] == 0
