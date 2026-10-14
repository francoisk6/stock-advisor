"""Background loops inside the API process (single worker): alert checks and live prices."""

import asyncio
import logging
from collections.abc import Awaitable, Callable

from app.core.config import settings
from app.db.session import SessionLocal
from app.realtime.hub import hub
from app.schemas.notifications import notification_out
from app.services import alerts as alerts_service
from app.services import notifications as notifications_service
from app.services.email import send_email

logger = logging.getLogger(__name__)


async def run_alert_check() -> int:
    """Check alerts once; deliver in-app (live) and by email. Returns how many fired."""
    async with SessionLocal() as session:
        fired = await alerts_service.check_alerts(session)
        for f in fired:
            unread = await notifications_service.unread_count(session, f.alert.user_id)
            await hub.notify_user(
                f.alert.user_id,
                {
                    "type": "notification",
                    "notification": notification_out(f.notification).model_dump(mode="json"),
                    "unread_count": unread,
                },
            )
    for f in fired:
        if f.email is not None:
            await send_email(f.email)
    if fired:
        logger.info("Alerts fired: %d", len(fired))
    return len(fired)


async def run_live_prices() -> None:
    if hub.connection_count:
        await hub.push_quotes()


async def _loop(name: str, seconds: int, job: Callable[[], Awaitable[object]]) -> None:
    while True:
        try:
            await job()
        except asyncio.CancelledError:
            raise
        except Exception:
            logger.exception("Background job %s failed", name)
        await asyncio.sleep(seconds)


def start() -> list[asyncio.Task]:
    if not settings.background_jobs:
        return []
    return [
        asyncio.create_task(_loop("alerts", settings.alert_check_seconds, run_alert_check)),
        asyncio.create_task(_loop("live-prices", settings.live_price_seconds, run_live_prices)),
    ]


async def stop(tasks: list[asyncio.Task]) -> None:
    for task in tasks:
        task.cancel()
    await asyncio.gather(*tasks, return_exceptions=True)
