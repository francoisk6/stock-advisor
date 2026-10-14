"""Import every model module here so Alembic autogenerate sees it on Base.metadata."""

from app.db.models.alert import Alert, Notification
from app.db.models.asset import Asset
from app.db.models.plan import Plan, UserPlan
from app.db.models.profile import UserProfile
from app.db.models.token import EmailToken, RefreshToken
from app.db.models.user import OAuthAccount, User
from app.db.models.watchlist import Watchlist, WatchlistItem

__all__ = [
    "Alert",
    "Asset",
    "EmailToken",
    "Notification",
    "OAuthAccount",
    "Plan",
    "RefreshToken",
    "User",
    "UserPlan",
    "UserProfile",
    "Watchlist",
    "WatchlistItem",
]
