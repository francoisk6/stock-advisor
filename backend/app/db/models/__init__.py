"""Import every model module here so Alembic autogenerate sees it on Base.metadata."""

from app.db.models.alert import Alert, Notification
from app.db.models.asset import Asset
from app.db.models.chat import ChatConversation, ChatMessageRow
from app.db.models.daily import JobRun, PriceBarDaily
from app.db.models.digest import Digest
from app.db.models.insight import AssetInsight
from app.db.models.lesson import LessonProgress
from app.db.models.news import NewsArticle, NewsArticleAsset
from app.db.models.plan import Plan, UserPlan
from app.db.models.portfolio import Holding
from app.db.models.practice import PracticeAccount, PracticeOrder, PracticePosition
from app.db.models.profile import UserProfile
from app.db.models.token import EmailToken, RefreshToken
from app.db.models.user import OAuthAccount, User
from app.db.models.watchlist import Watchlist, WatchlistItem

__all__ = [
    "Alert",
    "Asset",
    "AssetInsight",
    "ChatConversation",
    "ChatMessageRow",
    "Digest",
    "EmailToken",
    "Holding",
    "JobRun",
    "LessonProgress",
    "NewsArticle",
    "NewsArticleAsset",
    "Notification",
    "OAuthAccount",
    "Plan",
    "PracticeAccount",
    "PracticeOrder",
    "PracticePosition",
    "PriceBarDaily",
    "RefreshToken",
    "User",
    "UserPlan",
    "UserProfile",
    "Watchlist",
    "WatchlistItem",
]
