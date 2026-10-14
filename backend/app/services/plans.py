from app.core.errors import AppError
from app.db.models import User
from app.services.users import active_plan


class PlanLimitReached(AppError):
    status_code = 403


def plan_limit(user: User, key: str) -> int | None:
    """The user's limit for `key` (None = unlimited)."""
    value = active_plan(user).limits.get(key)
    return None if value is None else int(value)


def check_limit(user: User, key: str, current: int, message: str) -> None:
    limit = plan_limit(user, key)
    if limit is not None and current >= limit:
        raise PlanLimitReached(message.format(limit=limit, plan=active_plan(user).name))
