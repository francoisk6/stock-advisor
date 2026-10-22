import pytest
from httpx import AsyncClient

from app.core.config import Settings, settings
from app.db.session import SessionLocal
from app.services import invites
from tests.conftest import PASSWORD, register
from tests.test_google_auth import google_login


@pytest.fixture
def closed_beta(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "invite_only", True)


async def invite(email: str) -> None:
    async with SessionLocal() as session:
        await invites.add(session, email, note="test")


def signup(email: str) -> dict:
    return {"email": email, "password": PASSWORD, "full_name": "Ana"}


async def test_open_signup_when_not_invite_only(client: AsyncClient) -> None:
    assert (await client.post("/auth/register", json=signup("ana@example.com"))).status_code == 201


async def test_closed_beta_needs_an_invite(client: AsyncClient, closed_beta) -> None:
    refused = await client.post("/auth/register", json=signup("ana@example.com"))
    assert refused.status_code == 403 and refused.json()["code"] == "invite_only"
    assert "closed beta" in refused.json()["detail"]

    await invite("  Ana@Example.com ")  # stored lowercase, trimmed
    welcome = await client.post("/auth/register", json=signup("ana@example.com"))
    assert welcome.status_code == 201
    async with SessionLocal() as session:
        [used] = await invites.all_invites(session)
    assert used.email == "ana@example.com" and used.used_at is not None

    # Existing accounts always sign in.
    login = await client.post(
        "/auth/login", json={"email": "ana@example.com", "password": PASSWORD}
    )
    assert login.status_code == 200


async def test_closed_beta_google_signup(
    client: AsyncClient, closed_beta, google_identity: dict
) -> None:
    refused = await google_login(client)
    assert refused.status_code == 403 and refused.json()["code"] == "invite_only"

    await invite("ana@example.com")
    assert (await google_login(client)).status_code == 200


async def test_closed_beta_lets_existing_accounts_link_google(
    client: AsyncClient, google_identity: dict, monkeypatch: pytest.MonkeyPatch
) -> None:
    await register(client)  # created before the beta closed
    monkeypatch.setattr(settings, "invite_only", True)
    assert (await google_login(client)).status_code == 200


def test_production_settings_are_checked() -> None:
    safe = Settings(
        _env_file=None,  # not the dev .env
        jwt_secret="x" * 40,
        environment="prod",
        email_backend="smtp",
        frontend_url="https://universal-stock-advisor.trade",
        cors_origins=["https://universal-stock-advisor.trade"],
        db_name="stock_advisor_prod",
    )
    assert safe.production_problems() == []
    unsafe = Settings(
        _env_file=None,
        jwt_secret="x" * 40,
        environment="prod",
        debug=True,
        frontend_url="http://localhost:8210",
        cors_origin_regex=".*",
    )
    problems = " | ".join(unsafe.production_problems())
    for expected in (
        "DEBUG",
        "EMAIL_BACKEND",
        "FRONTEND_URL",
        "CORS_ORIGINS",
        "CORS_ORIGIN_REGEX",
        "DB_NAME",
    ):
        assert expected in problems, expected


async def test_security_headers(client: AsyncClient) -> None:
    response = await client.get("/health")
    assert response.headers["x-content-type-options"] == "nosniff"
    assert response.headers["x-frame-options"] == "DENY"
    assert "strict-transport-security" not in response.headers  # only in production
