from typing import Any

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.time import utcnow
from app.db.models import Notification


def build(
    user_id: int,
    kind: str,
    title: str,
    body: str,
    *,
    asset_id: int | None = None,
    alert_id: int | None = None,
    data: dict[str, Any] | None = None,
) -> Notification:
    return Notification(
        user_id=user_id,
        kind=kind,
        title=title[:200],
        body=body[:1000],
        asset_id=asset_id,
        alert_id=alert_id,
        data=data or {},
        created_at=utcnow(),
    )


async def list_for_user(session: AsyncSession, user_id: int, limit: int = 50) -> list[Notification]:
    result = await session.execute(
        select(Notification)
        .where(Notification.user_id == user_id)
        .order_by(Notification.created_at.desc(), Notification.id.desc())
        .limit(limit)
    )
    return list(result.scalars())


async def unread_count(session: AsyncSession, user_id: int) -> int:
    result = await session.execute(
        select(func.count())
        .select_from(Notification)
        .where(Notification.user_id == user_id, Notification.read_at.is_(None))
    )
    return int(result.scalar_one())


async def mark_read(session: AsyncSession, user_id: int, notification_id: int | None) -> None:
    """Mark one notification (or all, when id is None) as read."""
    stmt = update(Notification).where(
        Notification.user_id == user_id, Notification.read_at.is_(None)
    )
    if notification_id is not None:
        stmt = stmt.where(Notification.id == notification_id)
    await session.execute(stmt.values(read_at=utcnow()))
    await session.commit()
