import os

# Must be set before the app is imported: env vars override backend/.env.
os.environ["ENVIRONMENT"] = "test"
os.environ["DB_NAME"] = "stock_advisor_test"
os.environ["EMAIL_BACKEND"] = "memory"
os.environ["GOOGLE_CLIENT_IDS"] = '["test-client-id"]'
os.environ["BACKGROUND_JOBS"] = "false"  # tests run alert checks / live ticks explicitly

import asyncio  # noqa: E402
import re  # noqa: E402
from collections.abc import AsyncIterator, Iterator  # noqa: E402
from pathlib import Path  # noqa: E402
from urllib.parse import unquote  # noqa: E402

import pytest  # noqa: E402
from alembic.config import Config  # noqa: E402
from httpx import ASGITransport, AsyncClient  # noqa: E402
from sqlalchemy import text  # noqa: E402

from alembic import command  # noqa: E402
from app.ai import background  # noqa: E402
from app.core.config import settings  # noqa: E402
from app.core.rate_limit import limiter  # noqa: E402
from app.db.session import SessionLocal, engine  # noqa: E402
from app.main import app  # noqa: E402
from app.market_data.seed import seed_catalog  # noqa: E402
from app.services import practice  # noqa: E402
from app.services.email import memory_outbox  # noqa: E402

assert settings.db_name == "stock_advisor_test", "tests must never touch the dev database"

# Tables reset between tests (children first); plans keep their migration seed data.
_RESET_TABLES = [
    "invites",
    "lesson_progress",
    "holdings",
    "practice_orders",
    "practice_positions",
    "practice_accounts",
    "digests",
    "job_runs",
    "price_bars_daily",
    "asset_insights",
    "news_article_assets",
    "news_articles",
    "chat_messages",
    "chat_conversations",
    "notifications",
    "alerts",
    "watchlist_items",
    "watchlists",
    "email_tokens",
    "refresh_tokens",
    "oauth_accounts",
    "user_plans",
    "user_profiles",
    "users",
]

PASSWORD = "Secret123"


@pytest.fixture(scope="session", autouse=True)
def migrated_db() -> Iterator[None]:
    """Bring the test schema to head using the real migrations.

    Downgrades are checked manually per migration (DDL is slow on the shared MySQL server).
    """
    cfg = Config(str(Path(__file__).resolve().parents[1] / "alembic.ini"))
    command.upgrade(cfg, "head")
    asyncio.run(_seed_catalog())
    yield


async def _seed_catalog() -> None:
    async with SessionLocal() as session:
        await seed_catalog(session)


@pytest.fixture(autouse=True)
async def clean_state() -> AsyncIterator[None]:
    async with engine.begin() as conn:
        # DELETE, not TRUNCATE: TRUNCATE is DDL in MySQL and is slow on a shared server.
        for table in _RESET_TABLES:
            await conn.execute(text(f"DELETE FROM `{table}`"))
        # Keep the curated catalog; drop assets that tests added through search.
        await conn.execute(text("DELETE FROM assets WHERE popularity IS NULL"))
    memory_outbox.clear()
    limiter.reset()
    background.clear()
    practice.closed_until.clear()
    yield


@pytest.fixture
async def client() -> AsyncIterator[AsyncClient]:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test/api/v1") as c:
        yield c


async def onboard(
    client: AsyncClient,
    tokens: dict,
    assets: list[str] | None = None,
    regions: list[str] | None = None,
) -> None:
    response = await client.put(
        "/users/me/profile",
        headers=bearer(tokens),
        json={
            "experience_level": "beginner",
            "risk_profile": "balanced",
            "investment_horizon": "long",
            "asset_interests": assets or ["stocks"],
            "region_interests": regions or ["global"],
        },
    )
    assert response.status_code == 200, response.text


async def register(
    client: AsyncClient, email: str = "ana@example.com", password: str = PASSWORD, name: str = "Ana"
) -> dict:
    response = await client.post(
        "/auth/register", json={"email": email, "password": password, "full_name": name}
    )
    assert response.status_code == 201, response.text
    return response.json()


def bearer(tokens: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def token_from_last_email(to: str) -> str:
    email = next(e for e in reversed(memory_outbox) if e.to == to)
    match = re.search(r"token=([^\s&\"]+)", email.text)
    assert match, email.text
    return unquote(match.group(1))


@pytest.fixture
def llm(monkeypatch: pytest.MonkeyPatch):
    """Replace the model with a ScriptedLLM: `scripted = llm(say("Hi"), call("get_quote", …))`."""
    from app.ai import agent
    from tests.test_copilot import ScriptedLLM

    def install(*rounds, fail: bool = False) -> ScriptedLLM:
        scripted = ScriptedLLM(*rounds, fail=fail)
        monkeypatch.setattr(agent, "provider", scripted)
        return scripted

    return install


@pytest.fixture
async def user(client: AsyncClient) -> dict:
    """A registered, onboarded user (stocks + crypto, Middle East); returns its tokens."""
    tokens = await register(client)
    await onboard(client, tokens, assets=["stocks", "crypto"], regions=["middle_east"])
    return tokens


@pytest.fixture
async def free_limits():
    """Change Free-plan limits for one test: `await free_limits(alerts=1)`. The limits that were
    there before are restored exactly afterwards (plans aren't cleared between tests)."""
    from sqlalchemy import select, update

    from app.db.models import Plan

    async with SessionLocal() as session:
        original = dict(
            (await session.execute(select(Plan.limits).where(Plan.code == "free"))).scalar_one()
        )

    async def change(**limits) -> None:
        async with SessionLocal() as session:
            await session.execute(
                update(Plan).where(Plan.code == "free").values(limits={**original, **limits})
            )
            await session.commit()

    yield change
    async with SessionLocal() as session:
        await session.execute(update(Plan).where(Plan.code == "free").values(limits=original))
        await session.commit()


@pytest.fixture
def fakes(monkeypatch: pytest.MonkeyPatch):
    """Fake Yahoo/CoinGecko providers (never call real APIs in unit tests)."""
    from app.market_data import service as market
    from app.market_data.types import Range
    from tests.fakes import FakeProvider

    providers = {
        "yahoo": FakeProvider("yahoo"),
        "coingecko": FakeProvider("coingecko", (Range.d1,)),
    }
    monkeypatch.setattr(market, "providers", providers)
    market.cache.clear()
    yield providers
    market.cache.clear()


GOOGLE_TOKEN = "fake-google-id-token-123456"


@pytest.fixture
def google_identity(monkeypatch: pytest.MonkeyPatch) -> dict:
    """Replaces Google's token verification; mutate the returned dict to change the identity."""
    from app.api.v1 import auth as auth_routes
    from app.services.google_auth import GoogleAuthError, GoogleIdentity

    identity = {
        "subject": "g-123",
        "email": "ana@example.com",
        "email_verified": True,
        "name": "Ana Google",
    }

    async def fake_verify(token: str) -> GoogleIdentity:
        if token != GOOGLE_TOKEN:
            raise GoogleAuthError("Invalid Google token")
        return GoogleIdentity(**identity)

    monkeypatch.setattr(auth_routes, "verify_google_id_token", fake_verify)
    return identity
