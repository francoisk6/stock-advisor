from dataclasses import dataclass

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.core.time import utcnow
from app.db.models import Alert, Holding, Plan, User
from app.services.users import active_plan


class PlanLimitReached(AppError):
    status_code = 403
    code = "plan_limit"


PRO_SOON = "Pro (coming soon) has no limit."

# Limits the app shows, in display order (keys of Plan.limits).
SHOWN_LIMITS = ("ai_messages_per_day", "watchlist_assets", "alerts", "portfolio_holdings")


def plan_limit(user: User, key: str) -> int | None:
    """The user's limit for `key` (None = unlimited)."""
    value = active_plan(user).limits.get(key)
    return None if value is None else int(value)


def check_limit(user: User, key: str, current: int, message: str) -> None:
    limit = plan_limit(user, key)
    if limit is not None and current >= limit:
        raise PlanLimitReached(message.format(limit=limit, plan=active_plan(user).name))


async def plans(session: AsyncSession) -> list[Plan]:
    result = await session.execute(select(Plan).where(Plan.code.in_(("free", "pro"))))
    return sorted(result.scalars(), key=lambda p: p.code != "free")


@dataclass
class Usage:
    key: str
    used: int
    limit: int | None  # None = unlimited


async def usage(session: AsyncSession, user: User) -> list[Usage]:
    """What the user has used of each limit the app shows."""
    from app.services import chat as chat_service  # chat imports plans indirectly
    from app.services import watchlist as watchlist_service

    async def count(model, *where) -> int:
        result = await session.execute(select(func.count()).select_from(model).where(*where))
        return int(result.scalar_one())

    watchlist = await watchlist_service.get_default(session, user)
    used = {
        "ai_messages_per_day": await chat_service.answers_today(session, user),
        "watchlist_assets": len(watchlist.items),
        "alerts": await count(Alert, Alert.user_id == user.id, Alert.is_active.is_(True)),
        "portfolio_holdings": await count(Holding, Holding.user_id == user.id),
    }
    return [Usage(key, used[key], plan_limit(user, key)) for key in SHOWN_LIMITS]


async def register_pro_interest(session: AsyncSession, user: User) -> None:
    if user.profile.pro_interest_at is None:
        user.profile.pro_interest_at = utcnow()
        await session.commit()
