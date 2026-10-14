from httpx import ASGITransport, AsyncClient

from app.main import app


async def test_health_ok() -> None:
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.get("/api/v1/health")

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["app"] == "Stock Adviser API"


async def test_cors_allows_lan_origin_when_configured(monkeypatch) -> None:
    from app.core.config import settings
    from app.main import create_app

    monkeypatch.setattr(settings, "cors_origin_regex", r"^http://192\.168\.\d{1,3}\.\d{1,3}:8210$")
    lan_app = create_app()

    async def preflight(origin: str) -> str | None:
        async with AsyncClient(
            transport=ASGITransport(app=lan_app), base_url="http://test"
        ) as client:
            response = await client.options(
                "/api/v1/health",
                headers={"Origin": origin, "Access-Control-Request-Method": "GET"},
            )
        return response.headers.get("access-control-allow-origin")

    assert await preflight("http://192.168.150.101:8210") == "http://192.168.150.101:8210"
    assert await preflight("http://localhost:8210") == "http://localhost:8210"
    assert await preflight("http://evil.example:8210") is None
