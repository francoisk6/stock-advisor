from datetime import datetime
from typing import Any

from pydantic import BaseModel

from app.db.models import Notification


class NotificationOut(BaseModel):
    id: int
    kind: str
    title: str
    body: str
    asset_id: int | None
    alert_id: int | None
    data: dict[str, Any]
    read: bool
    created_at: datetime


class NotificationListOut(BaseModel):
    unread_count: int
    items: list[NotificationOut]


def notification_out(n: Notification) -> NotificationOut:
    return NotificationOut(
        id=n.id,
        kind=n.kind,
        title=n.title,
        body=n.body,
        asset_id=n.asset_id,
        alert_id=n.alert_id,
        data=n.data or {},
        read=n.read_at is not None,
        created_at=n.created_at,
    )
