"""Operations helpers for scripts (health check, backups):

    .venv/bin/python -m app.ops alert "Subject" "What happened"

Sends to OPS_ALERT_EMAIL through the app's own email settings; prints instead if unset.
"""

import asyncio
import html
import sys

from app.core.config import settings
from app.services.email import OutgoingEmail, send_email


async def alert(subject: str, body: str) -> None:
    if not settings.ops_alert_email:
        print(f"[ops alert, no OPS_ALERT_EMAIL] {subject}: {body}")
        return
    await send_email(
        OutgoingEmail(
            to=settings.ops_alert_email,
            subject=f"[Universal Stock Advisor] {subject}",
            text=body,
            html=f"<p>{html.escape(body)}</p>",
        )
    )


if __name__ == "__main__":
    if len(sys.argv) != 4 or sys.argv[1] != "alert":
        sys.exit('Usage: python -m app.ops alert "Subject" "Body"')
    asyncio.run(alert(sys.argv[2], sys.argv[3]))
