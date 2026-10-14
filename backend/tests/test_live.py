import pytest
from starlette.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from app.jobs.runner import run_alert_check
from app.main import app
from app.market_data import service
from app.market_data.types import Range
from tests.fakes import FakeProvider

PASSWORD = "Secret123"


@pytest.fixture
def live_client(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setattr(
        service,
        "providers",
        {"yahoo": FakeProvider("yahoo"), "coingecko": FakeProvider("coingecko", (Range.d1,))},
    )
    service.cache.clear()
    with TestClient(app, base_url="http://test") as client:
        yield client
    service.cache.clear()


def _signup(client: TestClient) -> tuple[str, int]:
    tokens = client.post(
        "/api/v1/auth/register", json={"email": "liv@example.com", "password": PASSWORD}
    ).json()
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    btc = client.get("/api/v1/assets/search", params={"q": "btc"}, headers=headers).json()[0]
    return tokens["access_token"], btc["id"]


def test_socket_rejects_missing_or_bad_token(live_client: TestClient) -> None:
    for first_message in ({"type": "subscribe", "asset_ids": [1]}, {"type": "auth", "token": "x"}):
        with live_client.websocket_connect("/api/v1/ws") as ws:
            ws.send_json(first_message)
            assert ws.receive_json() == {"type": "error", "detail": "Not signed in"}
            with pytest.raises(WebSocketDisconnect) as closed:
                ws.receive_json()
            assert closed.value.code == 4401


def test_socket_streams_prices_and_notifications(live_client: TestClient) -> None:
    token, btc = _signup(live_client)
    headers = {"Authorization": f"Bearer {token}"}
    with live_client.websocket_connect("/api/v1/ws") as ws:
        ws.send_json({"type": "auth", "token": token})
        assert ws.receive_json() == {"type": "ready"}

        ws.send_json({"type": "subscribe", "asset_ids": [btc, "junk"]})
        message = ws.receive_json()
        assert message["type"] == "quotes"
        assert message["quotes"][str(btc)]["price"] == 110.0
        assert message["quotes"][str(btc)]["change_percent"] == pytest.approx(10.0)

        live_client.post(
            "/api/v1/alerts",
            headers=headers,
            json={"asset_id": btc, "kind": "price_above", "threshold": 100},
        )
        assert live_client.portal.call(run_alert_check) == 1
        pushed = ws.receive_json()
        assert pushed["type"] == "notification"
        assert pushed["notification"]["title"] == "BTC is above $100.00"
        assert pushed["unread_count"] == 1
