from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Asset, User, Watchlist, WatchlistItem
from app.services.plans import PRO_SOON, check_limit

DEFAULT_NAME = "My watchlist"


async def get_default(session: AsyncSession, user: User) -> Watchlist:
    """The user's watchlist, created on first use."""
    result = await session.execute(
        select(Watchlist).where(Watchlist.user_id == user.id).order_by(Watchlist.id).limit(1)
    )
    watchlist = result.scalar_one_or_none()
    if watchlist is None:
        watchlist = Watchlist(user_id=user.id, name=DEFAULT_NAME, items=[])
        session.add(watchlist)
        await session.commit()
    return watchlist


async def contains(session: AsyncSession, user: User, asset_id: int) -> bool:
    result = await session.execute(
        select(WatchlistItem.id)
        .join(Watchlist)
        .where(Watchlist.user_id == user.id, WatchlistItem.asset_id == asset_id)
    )
    return result.first() is not None


async def add(session: AsyncSession, user: User, asset: Asset) -> Watchlist:
    watchlist = await get_default(session, user)
    if any(item.asset_id == asset.id for item in watchlist.items):
        return watchlist  # already there: adding twice is not an error
    check_limit(
        user,
        "watchlist_assets",
        len(watchlist.items),
        "The {plan} plan allows up to {limit} assets in your watchlist. "
        "Remove one to add another. " + PRO_SOON,
    )
    position = max((i.position for i in watchlist.items), default=-1) + 1
    watchlist.items.append(WatchlistItem(asset_id=asset.id, asset=asset, position=position))
    await session.commit()
    return watchlist


async def remove(session: AsyncSession, user: User, asset_id: int) -> Watchlist:
    watchlist = await get_default(session, user)
    for item in list(watchlist.items):
        if item.asset_id == asset_id:
            watchlist.items.remove(item)
    await session.commit()
    return watchlist


async def watched_asset_ids(session: AsyncSession, user_id: int) -> list[int]:
    result = await session.execute(
        select(WatchlistItem.asset_id)
        .join(Watchlist)
        .where(Watchlist.user_id == user_id)
        .order_by(WatchlistItem.position)
    )
    return list(result.scalars())
