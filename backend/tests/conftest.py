import os

# Must be set before the app is imported: env vars override backend/.env.
os.environ["ENVIRONMENT"] = "test"
os.environ["DB_NAME"] = "stock_advisor_test"
os.environ["EMAIL_BACKEND"] = "memory"
os.environ["GOOGLE_CLIENT_IDS"] = '["test-client-id"]'

import re  # noqa: E402
from collections.abc import AsyncIterator, Iterator  # noqa: E402
from pathlib import Path  # noqa: E402
from urllib.parse import unquote  # noqa: E402

import pytest  # noqa: E402
from alembic.config import Config  # noqa: E402
from httpx import ASGITransport, AsyncClient  # noqa: E402
from sqlalchemy import text  # noqa: E402

from alembic import command  # noqa: E402
from app.core.config import settings  # noqa: E402
from app.core.rate_limit import limiter  # noqa: E402
from app.db.session import engine  # noqa: E402
from app.main import app  # noqa: E402
from app.services.email import memory_outbox  # noqa: E402

assert settings.db_name == "stock_advisor_test", "tests must never touch the dev database"

# Tables reset between tests (children first); plans keep their migration seed data.
_RESET_TABLES = [
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
    yield


@pytest.fixture(autouse=True)
async def clean_state() -> AsyncIterator[None]:
    async with engine.begin() as conn:
        # DELETE, not TRUNCATE: TRUNCATE is DDL in MySQL and is slow on a shared server.
        for table in _RESET_TABLES:
            await conn.execute(text(f"DELETE FROM `{table}`"))
    memory_outbox.clear()
    limiter.reset()
    yield


@pytest.fixture
async def client() -> AsyncIterator[AsyncClient]:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test/api/v1") as c:
        yield c


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
