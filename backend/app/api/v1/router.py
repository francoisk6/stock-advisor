from fastapi import APIRouter

from app.api.v1 import (
    alerts,
    assets,
    auth,
    chat,
    digest,
    health,
    learn,
    live,
    notifications,
    users,
    watchlist,
)

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(assets.router)
api_router.include_router(watchlist.router)
api_router.include_router(alerts.router)
api_router.include_router(notifications.router)
api_router.include_router(chat.router)
api_router.include_router(digest.router)
api_router.include_router(learn.router)
api_router.include_router(live.router)
