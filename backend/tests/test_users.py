from httpx import AsyncClient

from app.services.google_auth import GoogleIdentity
from tests.conftest import PASSWORD, bearer, register

ONBOARDING = {
    "experience_level": "beginner",
    "risk_profile": "balanced",
    "investment_horizon": "long",
    "asset_interests": ["stocks", "crypto", "stocks"],
    "region_interests": ["global", "middle_east"],
    "preferred_language": "en",
    "preferred_currency": "USD",
}


async def test_onboarding_saves_profile_once_completed(client: AsyncClient) -> None:
    tokens = await register(client)

    response = await client.put("/users/me/profile", json=ONBOARDING, headers=bearer(tokens))
    assert response.status_code == 200
    profile = response.json()["profile"]
    assert profile["experience_level"] == "beginner"
    assert profile["asset_interests"] == ["stocks", "crypto"]
    completed_at = profile["onboarding_completed_at"]
    assert completed_at is not None

    edited = {**ONBOARDING, "risk_profile": "conservative"}
    again = (await client.put("/users/me/profile", json=edited, headers=bearer(tokens))).json()[
        "profile"
    ]
    assert again["risk_profile"] == "conservative"
    assert again["onboarding_completed_at"] == completed_at


async def test_onboarding_validates_choices(client: AsyncClient) -> None:
    tokens = await register(client)
    for bad in (
        {**ONBOARDING, "risk_profile": "yolo"},
        {**ONBOARDING, "asset_interests": []},
        {**ONBOARDING, "preferred_currency": "usd"},
    ):
        response = await client.put("/users/me/profile", json=bad, headers=bearer(tokens))
        assert response.status_code == 422


async def test_update_name(client: AsyncClient) -> None:
    tokens = await register(client)
    response = await client.patch(
        "/users/me", json={"full_name": "  Ana Maria "}, headers=bearer(tokens)
    )
    assert response.status_code == 200
    assert response.json()["full_name"] == "Ana Maria"


async def test_change_password_requires_current_and_rotates_sessions(
    client: AsyncClient,
) -> None:
    tokens = await register(client)

    wrong = await client.post(
        "/users/me/password",
        json={"current_password": "nope", "new_password": "NewSecret456"},
        headers=bearer(tokens),
    )
    assert wrong.status_code == 400

    ok = await client.post(
        "/users/me/password",
        json={"current_password": PASSWORD, "new_password": "NewSecret456"},
        headers=bearer(tokens),
    )
    assert ok.status_code == 200
    assert ok.json()["refresh_token"] != tokens["refresh_token"]
    old = await client.post("/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert old.status_code == 401


async def test_google_only_user_can_set_password(client: AsyncClient, monkeypatch) -> None:
    from app.api.v1 import auth as auth_routes

    async def fake_verify(token: str) -> GoogleIdentity:
        return GoogleIdentity(subject="g-1", email="gina@example.com", email_verified=True, name="")

    monkeypatch.setattr(auth_routes, "verify_google_id_token", fake_verify)
    tokens = (await client.post("/auth/google", json={"id_token": "x" * 30})).json()

    response = await client.post(
        "/users/me/password", json={"new_password": "MyFirst123"}, headers=bearer(tokens)
    )
    assert response.status_code == 200
    assert response.json()["user"]["has_password"] is True
    login = await client.post(
        "/auth/login", json={"email": "gina@example.com", "password": "MyFirst123"}
    )
    assert login.status_code == 200


async def test_delete_account(client: AsyncClient) -> None:
    tokens = await register(client)

    wrong = await client.request(
        "DELETE", "/users/me", json={"password": "nope"}, headers=bearer(tokens)
    )
    assert wrong.status_code == 400

    deleted = await client.request(
        "DELETE", "/users/me", json={"password": PASSWORD}, headers=bearer(tokens)
    )
    assert deleted.status_code == 204
    assert (await client.get("/users/me", headers=bearer(tokens))).status_code == 401
    login = await client.post(
        "/auth/login", json={"email": "ana@example.com", "password": PASSWORD}
    )
    assert login.status_code == 401
