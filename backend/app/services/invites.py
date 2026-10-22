"""Closed beta: while INVITE_ONLY is on, only invited emails can create an account (by password
or Google). Existing accounts always sign in. Managed with `python -m app.admin invite …`."""

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.errors import AppError
from app.core.time import utcnow
from app.db.models import Invite

INVITE_ONLY_MESSAGE = (
    "Universal Stock Advisor is in a closed beta for now, so new accounts need an invite. "
    "If you already have an account, sign in."
)


class InviteRequired(AppError):
    status_code = 403
    code = "invite_only"


def _clean(email: str) -> str:
    return email.strip().lower()


async def check_and_use(session: AsyncSession, email: str) -> None:
    """Raise InviteRequired unless the beta is open or this email is invited (then mark the
    invite as used; the caller commits with the new account)."""
    if not settings.invite_only:
        return
    invite = (
        await session.execute(select(Invite).where(Invite.email == _clean(email)))
    ).scalar_one_or_none()
    if invite is None:
        raise InviteRequired(INVITE_ONLY_MESSAGE)
    invite.used_at = invite.used_at or utcnow()


async def add(session: AsyncSession, email: str, note: str | None = None) -> Invite:
    email = _clean(email)
    invite = (
        await session.execute(select(Invite).where(Invite.email == email))
    ).scalar_one_or_none()
    if invite is None:
        invite = Invite(email=email, note=note, created_at=utcnow())
        session.add(invite)
    elif note:
        invite.note = note
    await session.commit()
    return invite


async def remove(session: AsyncSession, email: str) -> bool:
    result = await session.execute(delete(Invite).where(Invite.email == _clean(email)))
    await session.commit()
    return bool(result.rowcount)


async def all_invites(session: AsyncSession) -> list[Invite]:
    return list((await session.execute(select(Invite).order_by(Invite.created_at))).scalars())
