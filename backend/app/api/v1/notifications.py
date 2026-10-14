from typing import Annotated

from fastapi import APIRouter, Query

from app.api.deps import CurrentUser, SessionDep
from app.schemas.auth import MessageOut
from app.schemas.notifications import NotificationListOut, notification_out
from app.services import notifications as notifications_service

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("", response_model=NotificationListOut)
async def list_notifications(
    user: CurrentUser,
    session: SessionDep,
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
) -> NotificationListOut:
    items = await notifications_service.list_for_user(session, user.id, limit)
    return NotificationListOut(
        unread_count=await notifications_service.unread_count(session, user.id),
        items=[notification_out(n) for n in items],
    )


@router.post("/{notification_id}/read", response_model=MessageOut)
async def mark_read(notification_id: int, user: CurrentUser, session: SessionDep) -> MessageOut:
    await notifications_service.mark_read(session, user.id, notification_id)
    return MessageOut(message="Marked as read")


@router.post("/read-all", response_model=MessageOut)
async def mark_all_read(user: CurrentUser, session: SessionDep) -> MessageOut:
    await notifications_service.mark_read(session, user.id, None)
    return MessageOut(message="All marked as read")
