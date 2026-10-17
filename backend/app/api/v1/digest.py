from datetime import date, datetime

from fastapi import APIRouter
from pydantic import BaseModel

from app.ai import background
from app.ai import digest as digest_service
from app.api.deps import CurrentUser, SessionDep
from app.core.errors import AppError
from app.core.rate_limit import enforce
from app.db.models import User

router = APIRouter(prefix="/digest", tags=["digest"])


class DigestOut(BaseModel):
    status: str  # ready | writing | failed
    day: date | None = None
    content: str | None = None
    created_at: datetime | None = None
    detail: str | None = None


def _key(user: User) -> str:
    return f"digest:{user.id}"


async def _status(session: SessionDep, user: User) -> DigestOut | None:
    if background.is_running(_key(user)):
        return DigestOut(status="writing")
    if (detail := background.error(_key(user))) is not None:
        return DigestOut(status="failed", detail=detail)
    digest = await digest_service.today_for(session, user)
    if digest is None:
        return None
    return DigestOut(
        status="ready", day=digest.day, content=digest.content, created_at=digest.created_at
    )


@router.get("/today", response_model=DigestOut | None)
async def get_today(user: CurrentUser, session: SessionDep) -> DigestOut | None:
    """Today's brief (ready), "writing" while it's being written, or null."""
    return await _status(session, user)


@router.post("/today", response_model=DigestOut)
async def make_today(user: CurrentUser, session: SessionDep) -> DigestOut:
    """Starts writing today's brief (about a minute here); poll GET until it's ready."""
    enforce(f"digest:user:{user.id}", limit=5, window_seconds=3600)
    status = await _status(session, user)
    if status is not None and status.status in ("ready", "writing"):
        return status
    if not await digest_service.brief_assets(session, user):
        raise AppError("Add a few assets to your watchlist first, then we can write your brief.")
    user_id = user.id
    background.start(_key(user), lambda: digest_service.write_for(user_id))
    return DigestOut(status="writing")
