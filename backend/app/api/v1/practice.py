"""Practice account (paper trading) endpoints. Rules live in app/services/practice.py."""

from decimal import Decimal

from fastapi import APIRouter, Query

from app.api.deps import CurrentUser, SessionDep
from app.core.errors import NotFoundError
from app.db.models import Asset
from app.db.models.practice import PracticeOrder
from app.schemas.market import AssetOut
from app.schemas.practice import AccountOut, OrderIn, OrderOut, PositionOut, PracticeQuoteOut
from app.services import practice

router = APIRouter(prefix="/practice", tags=["practice"])


def order_out(order: PracticeOrder) -> OrderOut:
    def f(value: Decimal | None) -> float | None:
        return None if value is None else float(value)

    gain = (
        order.total_usd - order.cost_usd_removed
        if order.total_usd is not None and order.cost_usd_removed is not None
        else None
    )
    return OrderOut(
        id=order.id,
        asset=AssetOut.model_validate(order.asset),
        side=order.side,
        quantity=f(order.quantity),
        amount_usd=f(order.amount_usd),
        status=order.status,
        source=order.source,
        created_at=order.created_at,
        filled_at=order.filled_at,
        filled_quantity=f(order.filled_quantity),
        price=f(order.price),
        currency=order.currency,
        fx_rate=f(order.fx_rate),
        total_usd=f(order.total_usd),
        gain_usd=f(gain),
        reserved_usd=float(order.reserved_usd),
        note=order.note,
    )


def account_out(summary: practice.Summary) -> AccountOut:
    total = summary.total_value
    start = summary.account.starting_cash
    positions = []
    for v in summary.positions:
        value, gain, cost = v.value_usd, v.gain_usd, v.position.cost_usd
        positions.append(
            PositionOut(
                asset=AssetOut.model_validate(v.position.asset),
                quantity=float(v.position.quantity),
                average_price=float(v.average_price),
                currency=v.currency,
                price=None if v.price is None else float(v.price),
                change_percent=v.change_percent,
                usd_rate=None if v.usd_rate is None else float(v.usd_rate),
                as_of=v.as_of,
                cost_usd=float(cost),
                value_usd=None if value is None else float(value),
                gain_usd=None if gain is None else float(gain),
                gain_percent=None if gain is None or not cost else float(gain / cost * 100),
                share_percent=None if value is None or not total else float(value / total * 100),
            )
        )
    return AccountOut(
        starting_cash=float(start),
        cash=float(summary.account.cash),
        reserved_usd=float(summary.reserved_usd),
        available_cash=float(summary.available_cash),
        positions_value=float(summary.positions_value),
        total_value=float(total),
        gain_usd=float(summary.gain_usd),
        gain_percent=float(summary.gain_usd / start * 100) if start else 0.0,
        realized_usd=float(summary.realized_usd),
        started_at=summary.account.started_at,
        prices_complete=summary.prices_complete,
        positions=positions,
        pending=[order_out(o) for o in summary.pending],
    )


async def _asset(session: SessionDep, asset_id: int) -> Asset:
    asset = await session.get(Asset, asset_id)
    if asset is None or not asset.is_active:
        raise NotFoundError("We couldn't find that asset.")
    return asset


@router.get("", response_model=AccountOut)
async def get_account(session: SessionDep, user: CurrentUser) -> AccountOut:
    return account_out(await practice.summary(session, user))


@router.post("/reset", response_model=AccountOut)
async def reset_account(session: SessionDep, user: CurrentUser) -> AccountOut:
    await practice.reset(session, user)
    return account_out(await practice.summary(session, user))


@router.get("/quote/{asset_id}", response_model=PracticeQuoteOut)
async def quote(asset_id: int, session: SessionDep, user: CurrentUser) -> PracticeQuoteOut:
    asset = await _asset(session, asset_id)
    check = await practice.price_check(session, asset)
    available, held = await practice.cash_and_holding(session, user, asset.id)
    return PracticeQuoteOut(
        asset_id=asset.id,
        price=float(check.price),
        currency=check.currency,
        usd_rate=float(check.usd_rate),
        usd_price=float(check.usd_price),
        market_open=check.market_open,
        as_of=check.as_of,
        held_quantity=float(held),
        available_cash=float(available),
    )


@router.post("/orders", response_model=OrderOut, status_code=201)
async def place_order(body: OrderIn, session: SessionDep, user: CurrentUser) -> OrderOut:
    asset = await _asset(session, body.asset_id)
    order = await practice.place_order(
        session, user, asset, body.side, quantity=body.quantity, amount_usd=body.amount_usd
    )
    return order_out(order)


@router.get("/orders", response_model=list[OrderOut])
async def list_orders(
    session: SessionDep, user: CurrentUser, limit: int = Query(50, ge=1, le=200)
) -> list[OrderOut]:
    return [order_out(o) for o in await practice.history(session, user, limit)]


@router.delete("/orders/{order_id}", response_model=OrderOut)
async def cancel_order(order_id: int, session: SessionDep, user: CurrentUser) -> OrderOut:
    return order_out(await practice.cancel(session, user, order_id))


@router.post("/orders/{order_id}/undo", response_model=OrderOut)
async def undo_order(order_id: int, session: SessionDep, user: CurrentUser) -> OrderOut:
    return order_out(await practice.undo(session, user, order_id))
