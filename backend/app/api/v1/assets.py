from typing import Annotated

from fastapi import APIRouter, Query

from app.api.deps import CurrentUser, SessionDep
from app.core.errors import NotFoundError
from app.core.rate_limit import enforce
from app.db.models import Asset
from app.market_data import service
from app.market_data.types import AssetType, Quote, Range
from app.repositories import assets as assets_repo
from app.schemas.market import (
    AssetDetailOut,
    AssetOut,
    AssetWithQuoteOut,
    CandleOut,
    HistoryOut,
    QuoteOut,
    StatOut,
)
from app.services import watchlist as watchlist_service

router = APIRouter(prefix="/assets", tags=["assets"])


def quote_out(quote: Quote | None) -> QuoteOut | None:
    if quote is None:
        return None
    return QuoteOut(
        price=quote.price,
        change=quote.change,
        change_percent=quote.change_percent,
        previous_close=quote.previous_close,
        currency=quote.currency,
        as_of=quote.as_of,
        market_open=quote.market_open,
    )


def with_quotes(assets: list[Asset], quotes: dict[int, Quote | None]) -> list[AssetWithQuoteOut]:
    return [
        AssetWithQuoteOut(
            **AssetOut.model_validate(a).model_dump(), quote=quote_out(quotes.get(a.id))
        )
        for a in assets
    ]


async def get_asset(session: SessionDep, asset_id: int) -> Asset:
    asset = await assets_repo.get(session, asset_id)
    if asset is None:
        raise NotFoundError("We couldn't find this asset.")
    return asset


@router.get("/search", response_model=list[AssetOut])
async def search_assets(
    user: CurrentUser,
    session: SessionDep,
    q: Annotated[str, Query(min_length=1, max_length=50)],
) -> list[Asset]:
    enforce(f"search:user:{user.id}", limit=60, window_seconds=60)
    return await service.search(session, q)


@router.get("/popular", response_model=list[AssetWithQuoteOut])
async def popular_assets(
    user: CurrentUser,
    session: SessionDep,
    type: AssetType | None = None,  # noqa: A002 - public query parameter name
) -> list[AssetWithQuoteOut]:
    assets = await service.popular_for(session, user.profile, type)
    return with_quotes(assets, await service.quotes_for(assets))


@router.get("/{asset_id}", response_model=AssetDetailOut)
async def asset_detail(asset_id: int, user: CurrentUser, session: SessionDep) -> AssetDetailOut:
    asset = await get_asset(session, asset_id)
    details = await service.details_for(session, asset)
    return AssetDetailOut(
        **AssetOut.model_validate(asset).model_dump(),
        quote=quote_out(details.quote),
        in_watchlist=await watchlist_service.contains(session, user, asset.id),
        stats=[StatOut(key=s.key, value=s.value, unit=s.unit) for s in details.stats],
        description=details.description,
        ranges=[r.value for r in service.ranges_for(asset)],
        data_source=service.SOURCE_NAMES.get(asset.provider, asset.provider),
    )


@router.get("/{asset_id}/history", response_model=HistoryOut)
async def asset_history(
    asset_id: int,
    user: CurrentUser,
    session: SessionDep,
    range: Range = Range.m1,  # noqa: A002 - public query parameter name
) -> HistoryOut:
    asset = await get_asset(session, asset_id)
    candles = await service.history_for(asset, range)
    return HistoryOut(
        range=range.value,
        currency=asset.currency,
        candles=[
            CandleOut(t=c.time, o=c.open, h=c.high, l=c.low, c=c.close, v=c.volume) for c in candles
        ],
    )
