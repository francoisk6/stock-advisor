from datetime import datetime, timedelta

import pytest
from httpx import AsyncClient
from sqlalchemy import func, select

from app.core.time import utcnow
from app.db.models import JobRun, PriceBarDaily
from app.db.session import SessionLocal
from app.jobs import daily
from app.market_data import service as market
from app.market_data.types import Candle, Range
from tests.conftest import bearer, register
from tests.fakes import FakeProvider


def test_intraday_candles_become_daily_bars() -> None:
    day = datetime(2026, 10, 14)
    bars = daily.daily_bars(
        [
            Candle(day + timedelta(hours=8), 10, 12, 9, 11, 100),
            Candle(day + timedelta(hours=4), 9, 10, 8, 10, 50),  # earlier, listed later
            Candle(day + timedelta(days=1), 11, 11, 11, 11, None),
        ]
    )
    assert bars[day.date()] == (9, 12, 8, 11, 150)  # first open, max, min, last close, sum
    assert bars[(day + timedelta(days=1)).date()][4] is None


class RecentProvider(FakeProvider):
    """Five daily candles ending yesterday, so they're inside the stored-history window."""

    async def history(self, symbol: str, range_: Range) -> list[Candle]:
        await super().history(symbol, range_)  # records the call, honours `fail`
        start = datetime.combine(utcnow().date(), datetime.min.time()) - timedelta(days=5)
        return [
            Candle(start + timedelta(days=d), 100.0 + d, 102.0 + d, 99.0 + d, 101.0 + d, 1000.0)
            for d in range(5)
        ]


@pytest.fixture
def fakes(monkeypatch: pytest.MonkeyPatch):
    providers = {
        "yahoo": RecentProvider("yahoo"),
        "coingecko": RecentProvider("coingecko", (Range.d1, Range.m1)),
    }
    monkeypatch.setattr(market, "providers", providers)
    monkeypatch.setattr(daily, "PAUSE_BETWEEN_ASSETS_SECONDS", 0)
    market.cache.clear()
    yield providers
    market.cache.clear()


async def test_daily_prices_job_runs_once_and_backs_charts(client: AsyncClient, fakes) -> None:
    today = utcnow().date()
    assert await daily.run_once_per_day("daily_prices", today, daily.store_daily_prices)
    assert not await daily.run_once_per_day("daily_prices", today, daily.store_daily_prices)

    async with SessionLocal() as session:
        run = await session.get(JobRun, ("daily_prices", today))
        assert run.status == "done" and "daily bars saved" in run.detail
        count = (await session.execute(select(func.count()).select_from(PriceBarDaily))).scalar()
        assert count == 78 * 5  # every curated asset, 5 fake days (all before today)

    # Data source down and nothing cached: the 1M chart comes from stored bars.
    user = await register(client)
    btc = await client.get("/assets/search", params={"q": "btc"}, headers=bearer(user))
    btc_id = btc.json()[0]["id"]
    market.cache.clear()
    fakes["coingecko"].fail = True
    chart = await client.get(
        f"/assets/{btc_id}/history", params={"range": "1M"}, headers=bearer(user)
    )
    assert chart.status_code == 200 and len(chart.json()["candles"]) == 5
    intraday = await client.get(
        f"/assets/{btc_id}/history", params={"range": "1D"}, headers=bearer(user)
    )
    assert intraday.status_code == 503  # no stored intraday data


async def test_failed_jobs_are_recorded(fakes) -> None:
    async def broken(session) -> str:
        raise RuntimeError("boom")

    today = utcnow().date()
    assert await daily.run_once_per_day("broken", today, broken)
    async with SessionLocal() as session:
        run = await session.get(JobRun, ("broken", today))
        assert run.status == "failed" and run.detail == "boom" and run.finished_at


async def test_cut_off_runs_are_taken_over(fakes) -> None:
    today = utcnow().date()
    async with SessionLocal() as session:
        session.add(
            JobRun(name="x", day=today, status="running", started_at=utcnow() - timedelta(hours=2))
        )
        session.add(JobRun(name="y", day=today, status="running", started_at=utcnow()))
        await session.commit()

    async def ok(session) -> str:
        return "fine"

    assert await daily.run_once_per_day("x", today, ok)  # abandoned 2 h ago: rerun
    assert not await daily.run_once_per_day("y", today, ok)  # still genuinely running
