from fastapi import APIRouter

from app.api.deps import CurrentUser, SessionDep
from app.api.v1.assets import get_asset, with_quotes
from app.db.models import Watchlist
from app.market_data import service as market
from app.schemas.market import WatchlistOut
from app.services import watchlist as watchlist_service
from app.services.plans import plan_limit

router = APIRouter(prefix="/watchlist", tags=["watchlist"])


async def _out(watchlist: Watchlist, user: CurrentUser) -> WatchlistOut:
    assets = [item.asset for item in watchlist.items]
    return WatchlistOut(
        id=watchlist.id,
        name=watchlist.name,
        limit=plan_limit(user, "watchlist_assets"),
        items=with_quotes(assets, await market.quotes_for(assets)),
    )


@router.get("", response_model=WatchlistOut)
async def get_watchlist(user: CurrentUser, session: SessionDep) -> WatchlistOut:
    return await _out(await watchlist_service.get_default(session, user), user)


@router.put("/assets/{asset_id}", response_model=WatchlistOut)
async def add_to_watchlist(asset_id: int, user: CurrentUser, session: SessionDep) -> WatchlistOut:
    asset = await get_asset(session, asset_id)
    return await _out(await watchlist_service.add(session, user, asset), user)


@router.delete("/assets/{asset_id}", response_model=WatchlistOut)
async def remove_from_watchlist(
    asset_id: int, user: CurrentUser, session: SessionDep
) -> WatchlistOut:
    return await _out(await watchlist_service.remove(session, user, asset_id), user)
