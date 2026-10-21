"""Portfolio tracker endpoints (holdings entered by hand). Rules in app/services/portfolio.py."""

from decimal import Decimal

from fastapi import APIRouter, Response

from app.api.deps import CurrentUser, SessionDep
from app.api.v1.assets import get_asset
from app.schemas.market import AssetOut
from app.schemas.portfolio import (
    CurrencyIn,
    HoldingCreateIn,
    HoldingIn,
    HoldingOut,
    PortfolioOut,
    RiskOut,
    SliceOut,
)
from app.services import portfolio as portfolio_service

router = APIRouter(prefix="/portfolio", tags=["portfolio"])


def _f(value: Decimal | None) -> float | None:
    return None if value is None else float(value)


def portfolio_out(p: portfolio_service.Portfolio) -> PortfolioOut:
    def slices(groups: dict[str, Decimal]) -> list[SliceOut]:
        return [SliceOut(key=k, value=float(v), percent=p.share(v) or 0) for k, v in groups.items()]

    holdings = [
        HoldingOut(
            id=v.holding.id,
            asset=AssetOut.model_validate(v.holding.asset),
            quantity=float(v.holding.quantity),
            average_price=float(v.holding.average_price),
            currency=v.currency,
            bought_on=v.holding.bought_on,
            note=v.holding.note,
            price=_f(v.price),
            change_percent=v.change_percent,
            value=_f(v.value),
            cost=_f(v.cost),
            gain=_f(v.gain),
            gain_percent=float(v.gain / v.cost * 100) if v.gain is not None and v.cost else None,
            share_percent=p.share(v.value),
        )
        for v in p.holdings
    ]
    cost = p.total_cost
    return PortfolioOut(
        currency=p.currency,
        total_value=float(p.total_value),
        total_cost=float(cost),
        gain=float(p.gain),
        gain_percent=float(p.gain / cost * 100) if cost else None,
        day_change=float(p.day_change),
        prices_complete=p.prices_complete,
        holdings=holdings,
        by_type=slices(p.by_type),
        by_region=slices(p.by_region),
        by_currency=slices(p.by_currency),
        risks=[RiskOut(code=r.code, level=r.level, params=r.params) for r in p.risks],
    )


async def _summary(session: SessionDep, user: CurrentUser) -> PortfolioOut:
    return portfolio_out(await portfolio_service.summary(session, user))


@router.get("", response_model=PortfolioOut)
async def get_portfolio(session: SessionDep, user: CurrentUser) -> PortfolioOut:
    return await _summary(session, user)


@router.post("/holdings", response_model=PortfolioOut, status_code=201)
async def add_holding(
    body: HoldingCreateIn, session: SessionDep, user: CurrentUser
) -> PortfolioOut:
    asset = await get_asset(session, body.asset_id)
    await portfolio_service.add(
        session, user, asset, body.quantity, body.average_price, body.bought_on, body.note
    )
    return await _summary(session, user)


@router.put("/holdings/{holding_id}", response_model=PortfolioOut)
async def update_holding(
    holding_id: int, body: HoldingIn, session: SessionDep, user: CurrentUser
) -> PortfolioOut:
    await portfolio_service.update(
        session, user, holding_id, body.quantity, body.average_price, body.bought_on, body.note
    )
    return await _summary(session, user)


@router.delete("/holdings/{holding_id}", status_code=204)
async def delete_holding(holding_id: int, session: SessionDep, user: CurrentUser) -> Response:
    await portfolio_service.delete(session, user, holding_id)
    return Response(status_code=204)


@router.put("/currency", response_model=PortfolioOut)
async def set_currency(body: CurrencyIn, session: SessionDep, user: CurrentUser) -> PortfolioOut:
    await portfolio_service.set_currency(session, user, body.currency)
    return await _summary(session, user)
