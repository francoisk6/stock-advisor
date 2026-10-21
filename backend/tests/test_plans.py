from httpx import AsyncClient
from sqlalchemy import select

from app.db.models import Plan, User, UserPlan
from app.db.session import SessionLocal
from tests.conftest import bearer
from tests.test_copilot import ask, say


async def test_plans_compare_free_and_pro(client: AsyncClient, user: dict) -> None:
    data = (await client.get("/plans", headers=bearer(user))).json()
    assert [p["code"] for p in data] == ["free", "pro"]
    free, pro = data
    assert free["limits"] == {
        "ai_messages_per_day": 5,
        "watchlist_assets": 3,
        "alerts": 10,
        "portfolio_holdings": 50,
    }
    assert pro["price_monthly_usd"] == 4.99 and pro["price_yearly_usd"] == 39.99
    assert pro["for_sale"] is False  # payments come at launch
    assert (
        pro["limits"]["ai_messages_per_day"] is None and pro["limits"]["watchlist_assets"] is None
    )


async def test_usage_counts_what_was_used(client: AsyncClient, user: dict, llm, fakes) -> None:
    llm(say("Hi!"))
    await ask(user, "hello")
    btc = (await client.get("/assets/search?q=btc", headers=bearer(user))).json()[0]["id"]
    await client.put(f"/watchlist/assets/{btc}", headers=bearer(user))

    usage = (await client.get("/plans/usage", headers=bearer(user))).json()
    assert usage["plan"] == "free" and usage["plan_name"] == "Free"
    items = {i["key"]: (i["used"], i["limit"]) for i in usage["items"]}
    assert items == {
        "ai_messages_per_day": (1, 5),
        "watchlist_assets": (1, 3),
        "alerts": (0, 10),
        "portfolio_holdings": (0, 50),
    }
    assert usage["pro_interest_at"] is None


async def test_free_watchlist_limit_points_to_pro(client: AsyncClient, user: dict, fakes) -> None:
    ids = [a["id"] for a in (await client.get("/assets/popular", headers=bearer(user))).json()]
    for asset_id in ids[:3]:
        assert (await client.put(f"/watchlist/assets/{asset_id}", headers=bearer(user))).is_success
    fourth = await client.put(f"/watchlist/assets/{ids[3]}", headers=bearer(user))
    assert fourth.status_code == 403
    assert fourth.json()["code"] == "plan_limit"
    assert "up to 3 assets" in fourth.json()["detail"]
    assert "Pro (coming soon) has no limit" in fourth.json()["detail"]


async def test_pro_interest_is_recorded_once(client: AsyncClient, user: dict) -> None:
    first = (await client.post("/plans/pro/interest", headers=bearer(user))).json()
    again = (await client.post("/plans/pro/interest", headers=bearer(user))).json()
    assert first["pro_interest_at"] is not None
    assert again["pro_interest_at"] == first["pro_interest_at"]


async def test_pro_users_have_no_limits(client: AsyncClient, user: dict) -> None:
    from app.core.time import utcnow

    async with SessionLocal() as session:
        pro = (await session.execute(select(Plan).where(Plan.code == "pro"))).scalar_one()
        # Same second as the Free plan from signing up: the newer row must win.
        session.add(UserPlan(user_id=user["user"]["id"], plan_id=pro.id, started_at=utcnow()))
        await session.commit()
    usage = (await client.get("/plans/usage", headers=bearer(user))).json()
    assert usage["plan"] == "pro"
    limits = {i["key"]: i["limit"] for i in usage["items"]}
    assert limits["ai_messages_per_day"] is None and limits["watchlist_assets"] is None


async def test_testers_get_pro_and_lose_it(client: AsyncClient, user: dict) -> None:
    from app.services import plans

    async with SessionLocal() as session:
        me = await session.get(User, user["user"]["id"])
        grant = await plans.grant_pro(session, me, days=30)
        assert grant.provider == "internal" and grant.provider_ref == "tester"
    usage = (await client.get("/plans/usage", headers=bearer(user))).json()
    assert usage["plan"] == "pro"

    async with SessionLocal() as session:
        me = await session.get(User, user["user"]["id"])
        assert await plans.revoke_pro(session, me) == 1
    usage = (await client.get("/plans/usage", headers=bearer(user))).json()
    assert usage["plan"] == "free"


async def test_pro_interest_list(client: AsyncClient, user: dict) -> None:
    from app.services import plans

    await client.post("/plans/pro/interest", headers=bearer(user))
    async with SessionLocal() as session:
        rows = await plans.pro_interest(session)
    assert [(email, name) for email, name, _ in rows] == [("ana@example.com", "Ana")]
