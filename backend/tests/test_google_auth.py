from httpx import AsyncClient

from tests.conftest import GOOGLE_TOKEN, PASSWORD, register, token_from_last_email


async def google_login(client: AsyncClient, token: str = GOOGLE_TOKEN):
    return await client.post("/auth/google", json={"id_token": token})


async def test_google_creates_verified_user_without_password(
    client: AsyncClient, google_identity: dict
) -> None:
    response = await google_login(client)
    assert response.status_code == 200
    user = response.json()["user"]
    assert user["email_verified"] is True
    assert user["has_password"] is False
    assert user["auth_providers"] == ["google"]
    assert user["full_name"] == "Ana Google"
    assert user["plan"]["code"] == "free"

    again = await google_login(client)
    assert again.json()["user"]["id"] == user["id"]


async def test_google_rejects_invalid_token(client: AsyncClient, google_identity: dict) -> None:
    response = await google_login(client, token="tampered-token-000000000")
    assert response.status_code == 401


async def test_google_rejects_unverified_google_email(
    client: AsyncClient, google_identity: dict
) -> None:
    google_identity["email_verified"] = False
    assert (await google_login(client)).status_code == 401


async def test_google_links_verified_account_and_keeps_password(
    client: AsyncClient, google_identity: dict
) -> None:
    created = await register(client)
    await client.post(
        "/auth/verify-email", json={"token": token_from_last_email("ana@example.com")}
    )

    linked = (await google_login(client)).json()["user"]
    assert linked["id"] == created["user"]["id"]
    assert linked["has_password"] is True
    assert linked["full_name"] == "Ana"  # existing name kept
    password_login = await client.post(
        "/auth/login", json={"email": "ana@example.com", "password": PASSWORD}
    )
    assert password_login.status_code == 200


async def test_google_takeover_of_unverified_account_drops_password(
    client: AsyncClient, google_identity: dict
) -> None:
    # Someone registered the victim's email with their own password but never verified it.
    squatter = await register(client)

    linked = (await google_login(client)).json()["user"]
    assert linked["id"] == squatter["user"]["id"]
    assert linked["has_password"] is False
    assert linked["email_verified"] is True

    squatter_login = await client.post(
        "/auth/login", json={"email": "ana@example.com", "password": PASSWORD}
    )
    assert squatter_login.status_code == 401
    squatter_refresh = await client.post(
        "/auth/refresh", json={"refresh_token": squatter["refresh_token"]}
    )
    assert squatter_refresh.status_code == 401
