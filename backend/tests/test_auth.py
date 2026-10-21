from datetime import timedelta

from httpx import AsyncClient
from sqlalchemy import update

from app.core.time import utcnow
from app.db.models import RefreshToken
from app.db.session import SessionLocal
from app.services.email import memory_outbox
from tests.conftest import PASSWORD, bearer, register, token_from_last_email


async def test_register_creates_free_user_and_sends_verification(client: AsyncClient) -> None:
    body = await register(client, email="Ana@Example.com")

    user = body["user"]
    assert body["token_type"] == "bearer"
    assert user["email"] == "ana@example.com"
    assert user["full_name"] == "Ana"
    assert user["email_verified"] is False
    assert user["has_password"] is True
    assert user["plan"]["code"] == "free"
    assert user["plan"]["limits"]["watchlist_assets"] == 3
    assert user["profile"]["onboarding_completed_at"] is None
    assert [e.to for e in memory_outbox] == ["ana@example.com"]
    assert "/verify-email?token=" in memory_outbox[0].text


async def test_register_duplicate_email_conflicts(client: AsyncClient) -> None:
    await register(client)
    response = await client.post(
        "/auth/register", json={"email": "ANA@example.com", "password": PASSWORD}
    )
    assert response.status_code == 409


async def test_register_rejects_weak_password(client: AsyncClient) -> None:
    for weak in ("short1", "onlyletters", "12345678"):
        response = await client.post(
            "/auth/register", json={"email": "bob@example.com", "password": weak}
        )
        assert response.status_code == 422, weak


async def test_login_success_and_generic_failures(client: AsyncClient) -> None:
    await register(client)

    ok = await client.post("/auth/login", json={"email": "ana@example.com", "password": PASSWORD})
    assert ok.status_code == 200
    assert ok.json()["user"]["email"] == "ana@example.com"

    wrong = await client.post("/auth/login", json={"email": "ana@example.com", "password": "x"})
    unknown = await client.post(
        "/auth/login", json={"email": "nobody@example.com", "password": PASSWORD}
    )
    assert wrong.status_code == unknown.status_code == 401
    assert wrong.json() == unknown.json() == {"detail": "Invalid email or password"}


async def test_login_rate_limited_per_email(client: AsyncClient) -> None:
    await register(client)
    statuses = [
        (
            await client.post("/auth/login", json={"email": "ana@example.com", "password": "x"})
        ).status_code
        for _ in range(11)
    ]
    assert statuses[:10] == [401] * 10
    assert statuses[10] == 429


async def test_me_requires_valid_token(client: AsyncClient) -> None:
    assert (await client.get("/users/me")).status_code == 401
    bad = await client.get("/users/me", headers={"Authorization": "Bearer nope"})
    assert bad.status_code == 401

    tokens = await register(client)
    me = await client.get("/users/me", headers=bearer(tokens))
    assert me.status_code == 200
    assert me.json()["email"] == "ana@example.com"


async def test_refresh_rotates_tokens(client: AsyncClient) -> None:
    tokens = await register(client)

    first = await client.post("/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert first.status_code == 200
    rotated = first.json()
    assert rotated["refresh_token"] != tokens["refresh_token"]

    # Immediate reuse (e.g. two tabs) is rejected but does not kill the new session.
    again = await client.post("/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert again.status_code == 401
    ok = await client.post("/auth/refresh", json={"refresh_token": rotated["refresh_token"]})
    assert ok.status_code == 200


async def test_refresh_reuse_after_grace_revokes_family(client: AsyncClient) -> None:
    tokens = await register(client)
    rotated = (
        await client.post("/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    ).json()

    async with SessionLocal() as session:
        await session.execute(
            update(RefreshToken)
            .where(RefreshToken.revoked_at.is_not(None))
            .values(revoked_at=utcnow() - timedelta(minutes=5))
        )
        await session.commit()

    replay = await client.post("/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert replay.status_code == 401
    # The legitimate rotated token is now revoked too.
    after = await client.post("/auth/refresh", json={"refresh_token": rotated["refresh_token"]})
    assert after.status_code == 401


async def test_logout_revokes_refresh_token(client: AsyncClient) -> None:
    tokens = await register(client)
    out = await client.post("/auth/logout", json={"refresh_token": tokens["refresh_token"]})
    assert out.status_code == 200
    response = await client.post("/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert response.status_code == 401


async def test_verify_email_flow(client: AsyncClient) -> None:
    tokens = await register(client)
    token = token_from_last_email("ana@example.com")

    assert (await client.post("/auth/verify-email", json={"token": token})).status_code == 200
    me = (await client.get("/users/me", headers=bearer(tokens))).json()
    assert me["email_verified"] is True

    # Clicking the link twice is fine; a bogus link is not.
    assert (await client.post("/auth/verify-email", json={"token": token})).status_code == 200
    bogus = await client.post("/auth/verify-email", json={"token": "x" * 40})
    assert bogus.status_code == 400


async def test_resend_verification_invalidates_previous_link(client: AsyncClient) -> None:
    tokens = await register(client)
    old_token = token_from_last_email("ana@example.com")

    resend = await client.post("/auth/resend-verification", headers=bearer(tokens))
    assert resend.status_code == 200
    new_token = token_from_last_email("ana@example.com")

    assert (await client.post("/auth/verify-email", json={"token": old_token})).status_code == 400
    assert (await client.post("/auth/verify-email", json={"token": new_token})).status_code == 200


async def test_forgot_and_reset_password(client: AsyncClient) -> None:
    tokens = await register(client)
    memory_outbox.clear()

    unknown = await client.post("/auth/forgot-password", json={"email": "nobody@example.com"})
    known = await client.post("/auth/forgot-password", json={"email": "ana@example.com"})
    assert unknown.status_code == known.status_code == 202
    assert unknown.json() == known.json()
    assert [e.to for e in memory_outbox] == ["ana@example.com"]

    reset_token = token_from_last_email("ana@example.com")
    reset = await client.post(
        "/auth/reset-password", json={"token": reset_token, "new_password": "NewSecret456"}
    )
    assert reset.status_code == 200

    old_login = await client.post(
        "/auth/login", json={"email": "ana@example.com", "password": PASSWORD}
    )
    new_login = await client.post(
        "/auth/login", json={"email": "ana@example.com", "password": "NewSecret456"}
    )
    assert old_login.status_code == 401
    assert new_login.status_code == 200
    assert new_login.json()["user"]["email_verified"] is True

    # Existing sessions were signed out and the link is single-use.
    stale = await client.post("/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert stale.status_code == 401
    reuse = await client.post(
        "/auth/reset-password", json={"token": reset_token, "new_password": "Another789"}
    )
    assert reuse.status_code == 400
