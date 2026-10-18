"""Practice account (paper trading): $10,000 of virtual US dollars, real prices.

Rules, kept simple for beginners: market orders only, no fees, no short selling, no leverage.
Non-USD assets are converted at the live exchange rate. Orders placed while the asset's
market is closed wait and fill at the first price after it opens (`fill_pending`, run by the
background loop; a closed market is re-checked every CLOSED_RECHECK, so fills land within a few
minutes of the open). Money is Decimal throughout; cash is rounded to cents.
"""

from dataclasses import dataclass
from datetime import datetime, timedelta
from decimal import ROUND_DOWN, ROUND_HALF_UP, Decimal
from enum import Enum

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError, NotFoundError
from app.core.money import format_money
from app.core.time import utcnow
from app.db.models import Asset, Notification, User
from app.db.models.practice import PracticeAccount, PracticeOrder, PracticePosition
from app.market_data import service as market
from app.market_data.types import ProviderError
from app.services import notifications as notifications_service

STARTING_CASH = Decimal("10000.00")
MIN_ORDER_USD = Decimal("1.00")
CENT = Decimal("0.01")
UNIT = Decimal("0.00000001")  # smallest quantity (crypto-sized fractions)
TRADABLE = {"stock", "etf", "fund", "crypto", "commodity", "forex"}
# While a market is closed, ask about it again only this often (each check is a Yahoo call).
CLOSED_RECHECK = timedelta(minutes=5)
# "Open" with a price older than this is treated as closed (Yahoo said gold futures were open
# on a Sunday with Friday's price; also covers lunch breaks on Asian exchanges).
STALE_OPEN = timedelta(hours=2)
closed_until: dict[int, datetime] = {}  # asset id -> next check


class Side(str, Enum):
    buy = "buy"
    sell = "sell"


class OrderStatus(str, Enum):
    pending = "pending"
    filled = "filled"
    cancelled = "cancelled"
    rejected = "rejected"
    undone = "undone"


class PracticeError(AppError):
    pass


@dataclass
class PriceCheck:
    """What an order would fill at right now."""

    price: Decimal  # in `currency`
    currency: str
    usd_rate: Decimal  # US dollars per unit of `currency`
    market_open: bool
    as_of: datetime

    @property
    def usd_price(self) -> Decimal:
        return self.price * self.usd_rate


def _cents(value: Decimal) -> Decimal:
    return value.quantize(CENT, rounding=ROUND_HALF_UP)


def _units(value: Decimal) -> Decimal:
    return value.quantize(UNIT, rounding=ROUND_DOWN)


def _check_tradable(asset: Asset) -> None:
    if asset.asset_type == "index":
        raise PracticeError(
            f"An index like {asset.name} is a score, not something you can buy. "
            "Funds (ETFs) that follow it can be bought instead."
        )
    if asset.asset_type not in TRADABLE:
        raise PracticeError(f"{asset.name} can't be traded in the practice account.")


async def price_check(session: AsyncSession, asset: Asset) -> PriceCheck:
    """Latest price, its dollar value and whether the market is open (crypto: always)."""
    _check_tradable(asset)
    if asset.asset_type == "crypto":
        quote = (await market.quotes_for([asset])).get(asset.id)
        is_open = True
    else:
        # Details carry the exchange's market state (holidays included); batch quotes don't.
        quote = (await market.details_for(session, asset)).quote
        # Unknown state (rare; source degraded) counts as open if the price is fresh.
        is_open = (
            quote is not None
            and quote.market_open is not False
            and utcnow() - quote.as_of < STALE_OPEN
        )
    if quote is None:
        raise market.MarketDataUnavailable(market.UNAVAILABLE)
    currency = quote.currency or asset.currency or "USD"
    rate = await market.usd_per_unit(currency)
    if rate is None:
        raise market.MarketDataUnavailable(
            f"We can't convert {currency} to US dollars right now. Please try again in a minute."
        )
    return PriceCheck(Decimal(str(quote.price)), currency, rate, is_open, quote.as_of)


# --- account ------------------------------------------------------------------------------


async def get_account(session: AsyncSession, user: User, *, lock: bool = False) -> PracticeAccount:
    """The user's account, opened with the starting cash on first use."""
    query = select(PracticeAccount).where(PracticeAccount.user_id == user.id)
    if lock:
        query = query.with_for_update()
    account = (await session.execute(query)).scalar_one_or_none()
    if account is None:
        account = PracticeAccount(
            user_id=user.id,
            starting_cash=STARTING_CASH,
            cash=STARTING_CASH,
            started_at=utcnow(),
            positions=[],  # loaded, so later access doesn't lazy-load (async)
        )
        session.add(account)
        await session.flush()
    return account


async def _pending(session: AsyncSession, account: PracticeAccount) -> list[PracticeOrder]:
    result = await session.execute(
        select(PracticeOrder).where(
            PracticeOrder.account_id == account.id,
            PracticeOrder.status == OrderStatus.pending.value,
        )
    )
    return list(result.scalars())


def reserved_cash(pending: list[PracticeOrder], *, excluding: int | None = None) -> Decimal:
    return sum(
        (o.reserved_usd for o in pending if o.side == Side.buy.value and o.id != excluding),
        Decimal(0),
    )


def _position(account: PracticeAccount, asset_id: int) -> PracticePosition | None:
    return next((p for p in account.positions if p.asset_id == asset_id), None)


async def cash_and_holding(
    session: AsyncSession, user: User, asset_id: int
) -> tuple[Decimal, Decimal]:
    """(cash available for buying, units of the asset held) — for the order preview."""
    account = await get_account(session, user)
    pending = await _pending(session, account)
    await session.commit()  # keep a newly opened account
    position = _position(account, asset_id)
    return account.cash - reserved_cash(pending), position.quantity if position else Decimal(0)


async def reset(session: AsyncSession, user: User) -> PracticeAccount:
    """Start over: positions and history are cleared, cash goes back to the start."""
    account = await get_account(session, user, lock=True)
    await session.execute(delete(PracticeOrder).where(PracticeOrder.account_id == account.id))
    account.positions.clear()
    account.cash = account.starting_cash
    account.started_at = utcnow()
    await session.commit()
    return account


@dataclass
class PositionValue:
    position: PracticePosition
    price: Decimal | None  # latest, in `currency`
    currency: str
    usd_rate: Decimal | None
    as_of: datetime | None
    change_percent: float | None  # today

    @property
    def value_usd(self) -> Decimal | None:
        if self.price is None or self.usd_rate is None:
            return None
        return _cents(self.position.quantity * self.price * self.usd_rate)

    @property
    def gain_usd(self) -> Decimal | None:
        value = self.value_usd
        return None if value is None else value - self.position.cost_usd

    @property
    def average_price(self) -> Decimal:
        """Average price paid per unit, in the asset's own currency."""
        return self.position.cost_local / self.position.quantity


@dataclass
class Summary:
    account: PracticeAccount
    positions: list[PositionValue]
    pending: list[PracticeOrder]
    realized_usd: Decimal  # gains/losses locked in by selling, since the (re)start

    @property
    def reserved_usd(self) -> Decimal:
        return reserved_cash(self.pending)

    @property
    def available_cash(self) -> Decimal:
        return self.account.cash - self.reserved_usd

    @property
    def prices_complete(self) -> bool:
        return all(p.value_usd is not None for p in self.positions)

    @property
    def positions_value(self) -> Decimal:
        # A position without a price counts at what it cost (flagged by prices_complete).
        return sum(
            (
                p.value_usd if p.value_usd is not None else p.position.cost_usd
                for p in self.positions
            ),
            Decimal(0),
        )

    @property
    def total_value(self) -> Decimal:
        return self.account.cash + self.positions_value

    @property
    def gain_usd(self) -> Decimal:
        return self.total_value - self.account.starting_cash


async def summary(session: AsyncSession, user: User) -> Summary:
    account = await get_account(session, user)
    await session.commit()  # keep a newly opened account
    assets = [p.asset for p in account.positions]
    quotes = await market.quotes_for(assets) if assets else {}
    rates: dict[str, Decimal | None] = {}
    values = []
    for position in account.positions:
        quote = quotes.get(position.asset_id)
        currency = (quote.currency if quote else None) or position.asset.currency or "USD"
        if currency not in rates:
            rates[currency] = await market.usd_per_unit(currency)
        values.append(
            PositionValue(
                position,
                Decimal(str(quote.price)) if quote else None,
                currency,
                rates[currency],
                quote.as_of if quote else None,
                quote.change_percent if quote else None,
            )
        )
    values.sort(key=lambda v: v.value_usd or v.position.cost_usd, reverse=True)
    realized = await session.scalar(
        select(
            func.coalesce(func.sum(PracticeOrder.total_usd - PracticeOrder.cost_usd_removed), 0)
        ).where(
            PracticeOrder.account_id == account.id,
            PracticeOrder.side == Side.sell.value,
            PracticeOrder.status == OrderStatus.filled.value,
        )
    )
    return Summary(account, values, await _pending(session, account), Decimal(realized))


# --- orders -------------------------------------------------------------------------------


def _describe_amount(quantity: Decimal | None, amount_usd: Decimal | None, symbol: str) -> str:
    if amount_usd is not None:
        return f"{format_money(amount_usd, 'USD')} of {symbol}"
    return f"{_plain(quantity or Decimal(0))} {symbol}"


def _plain(quantity: Decimal) -> str:
    """0.12500000 -> '0.125', 3.00000000 -> '3'."""
    text = f"{quantity.normalize():f}"
    return text


async def place_order(
    session: AsyncSession,
    user: User,
    asset: Asset,
    side: Side,
    *,
    quantity: Decimal | None = None,
    amount_usd: Decimal | None = None,
    source: str = "app",
) -> PracticeOrder:
    """Buy or sell now if the market is open, otherwise queue until it opens."""
    if (quantity is None) == (amount_usd is None):
        raise PracticeError("Say how many units, or how many dollars' worth.")
    if quantity is not None:
        quantity = _units(quantity)
        if quantity <= 0:
            raise PracticeError("The number of units must be more than zero.")
    if amount_usd is not None:
        amount_usd = _cents(amount_usd)
        if amount_usd < MIN_ORDER_USD:
            raise PracticeError(f"The smallest order is {format_money(MIN_ORDER_USD, 'USD')}.")

    check = await price_check(session, asset)
    account = await get_account(session, user, lock=True)
    pending = await _pending(session, account)
    estimate = _cents(amount_usd if amount_usd is not None else quantity * check.usd_price)

    if side == Side.buy:
        available = account.cash - reserved_cash(pending)
        if estimate > available:
            raise PracticeError(
                f"That costs about {format_money(estimate, 'USD')}, but you have "
                f"{format_money(available, 'USD')} of practice cash available."
            )
    else:
        position = _position(account, asset.id)
        held = position.quantity if position else Decimal(0)
        for o in pending:
            if o.side == Side.sell.value and o.asset_id == asset.id:
                held -= o.quantity if o.quantity is not None else o.amount_usd / check.usd_price
        wanted = quantity if quantity is not None else amount_usd / check.usd_price
        if held <= 0:
            raise PracticeError(f"You don't have any {asset.symbol} in your practice account.")
        # A dollar amount just over what's held (prices move) means "sell it all".
        slack = held / 100 if amount_usd is not None else UNIT
        if wanted > held + slack:
            raise PracticeError(
                f"You have {_plain(_units(held))} {asset.symbol} to sell "
                f"(worth about {format_money(_cents(held * check.usd_price), 'USD')})."
            )

    order = PracticeOrder(
        account_id=account.id,
        asset_id=asset.id,
        side=side.value,
        quantity=quantity,
        amount_usd=amount_usd,
        status=OrderStatus.pending.value,
        source=source,
        reserved_usd=estimate if side == Side.buy else Decimal(0),
        created_at=utcnow(),
    )
    order.asset = asset
    session.add(order)
    await session.flush()
    if check.market_open:
        _fill(account, order, check, pending)
    await session.commit()
    return order


def _fill(
    account: PracticeAccount,
    order: PracticeOrder,
    check: PriceCheck,
    pending: list[PracticeOrder],
) -> None:
    """Fill at the checked price, or reject with a plain reason. Caller commits."""
    if order.quantity is not None:
        quantity = order.quantity
    else:
        quantity = _units(order.amount_usd / check.usd_price)
    position = _position(account, order.asset_id)
    symbol = order.asset.symbol

    def reject(reason: str) -> None:
        order.status = OrderStatus.rejected.value
        order.note = reason
        order.reserved_usd = Decimal(0)

    if quantity <= 0:
        return reject("The amount is too small to buy even a fraction of one unit.")
    if order.side == Side.sell.value:
        held = position.quantity if position else Decimal(0)
        if quantity > held:
            if quantity - held > UNIT * 100 and order.quantity is not None:
                return reject(f"You no longer have {_plain(quantity)} {symbol} to sell.")
            quantity = held  # dollar amounts can round past what's left: sell it all
        if quantity <= 0:
            return reject(f"You no longer have any {symbol} to sell.")

    local = quantity * check.price
    total = _cents(local * check.usd_rate)
    if order.side == Side.buy.value:
        available = account.cash - reserved_cash(pending, excluding=order.id)
        if total > available:
            return reject(
                f"At the fill price it would cost {format_money(total, 'USD')}, more than the "
                f"{format_money(available, 'USD')} of practice cash available."
            )
        account.cash -= total
        if position is None:
            position = PracticePosition(
                asset_id=order.asset_id,
                quantity=Decimal(0),
                cost_usd=Decimal(0),
                cost_local=Decimal(0),
            )
            account.positions.append(position)
        position.quantity += quantity
        position.cost_usd += total
        position.cost_local += local
    else:
        assert position is not None
        share = quantity / position.quantity
        removed_usd = position.cost_usd if share == 1 else _cents(position.cost_usd * share)
        removed_local = position.cost_local if share == 1 else position.cost_local * share
        order.cost_usd_removed = removed_usd
        order.cost_local_removed = removed_local
        account.cash += total
        position.quantity -= quantity
        position.cost_usd -= removed_usd
        position.cost_local -= removed_local
        if position.quantity <= 0:
            account.positions.remove(position)

    order.status = OrderStatus.filled.value
    order.filled_at = utcnow()
    order.filled_quantity = quantity
    order.price = check.price
    order.currency = check.currency
    order.fx_rate = check.usd_rate
    order.total_usd = total
    order.reserved_usd = Decimal(0)


async def get_order(session: AsyncSession, user: User, order_id: int) -> PracticeOrder:
    account = await get_account(session, user)
    order = await session.get(PracticeOrder, order_id)
    if order is None or order.account_id != account.id:
        raise NotFoundError("That practice order doesn't exist.")
    return order


async def cancel(session: AsyncSession, user: User, order_id: int) -> PracticeOrder:
    order = await get_order(session, user, order_id)
    if order.status != OrderStatus.pending.value:
        raise PracticeError("Only orders that are still waiting can be cancelled.")
    order.status = OrderStatus.cancelled.value
    order.reserved_usd = Decimal(0)
    await session.commit()
    return order


async def undo(session: AsyncSession, user: User, order_id: int) -> PracticeOrder:
    """Take an order back as if it never happened (the copilot's undo card).

    Only the latest filled order of an asset can be undone, so positions stay consistent.
    """
    order = await get_order(session, user, order_id)
    if order.status == OrderStatus.pending.value:
        return await cancel(session, user, order_id)
    if order.status != OrderStatus.filled.value:
        raise PracticeError("This order wasn't carried out, so there is nothing to undo.")
    account = await get_account(session, user, lock=True)
    later = await session.scalar(
        select(func.count())
        .select_from(PracticeOrder)
        .where(
            PracticeOrder.account_id == account.id,
            PracticeOrder.asset_id == order.asset_id,
            PracticeOrder.status == OrderStatus.filled.value,
            PracticeOrder.id > order.id,
        )
    )
    if later:
        raise PracticeError(
            f"You traded {order.asset.symbol} again after this order, so it can't be undone."
        )
    quantity = order.filled_quantity
    position = _position(account, order.asset_id)
    if order.side == Side.buy.value:
        if position is None or position.quantity < quantity:
            raise PracticeError("Those units are no longer in your practice account.")
        position.quantity -= quantity
        position.cost_usd -= order.total_usd
        position.cost_local -= quantity * order.price
        if position.quantity <= 0:
            account.positions.remove(position)
        account.cash += order.total_usd
    else:
        if account.cash - reserved_cash(await _pending(session, account)) < order.total_usd:
            raise PracticeError("The cash from this sale has already been used.")
        account.cash -= order.total_usd
        if position is None:
            position = PracticePosition(
                asset_id=order.asset_id,
                quantity=Decimal(0),
                cost_usd=Decimal(0),
                cost_local=Decimal(0),
            )
            account.positions.append(position)
        position.quantity += quantity
        position.cost_usd += order.cost_usd_removed
        position.cost_local += order.cost_local_removed
    order.status = OrderStatus.undone.value
    await session.commit()
    return order


async def history(session: AsyncSession, user: User, limit: int = 50) -> list[PracticeOrder]:
    account = await get_account(session, user)
    result = await session.execute(
        select(PracticeOrder)
        .where(PracticeOrder.account_id == account.id)
        .order_by(PracticeOrder.id.desc())
        .limit(limit)
    )
    return list(result.scalars())


# --- pending orders (background) -----------------------------------------------------------


@dataclass
class Filled:
    order: PracticeOrder
    notification: Notification


def describe_fill(order: PracticeOrder) -> tuple[str, str]:
    """(title, body) for a pending order that just filled or was rejected."""
    symbol = order.asset.symbol
    if order.status == OrderStatus.rejected.value:
        what = _describe_amount(order.quantity, order.amount_usd, symbol)
        return (
            f"Practice order not carried out: {order.side} {what}",
            order.note or "",
        )
    verb = "Bought" if order.side == Side.buy.value else "Sold"
    price = format_money(order.price, order.currency)
    return (
        f"{verb} {_plain(order.filled_quantity)} {symbol} (practice)",
        f"Your practice order filled when the market opened, at {price} "
        f"({format_money(order.total_usd, 'USD')} in total).",
    )


async def fill_pending(session: AsyncSession) -> list[Filled]:
    """Fill waiting orders whose market is now open (oldest first). One price check per asset."""
    result = await session.execute(
        select(PracticeOrder)
        .where(PracticeOrder.status == OrderStatus.pending.value)
        .order_by(PracticeOrder.id)
    )
    orders = list(result.scalars())
    checks: dict[int, PriceCheck | None] = {}
    done: list[Filled] = []
    now = utcnow()
    for order in orders:
        if order.asset_id not in checks:
            if closed_until.get(order.asset_id, now) > now:
                checks[order.asset_id] = None
                continue
            try:
                checks[order.asset_id] = await price_check(session, order.asset)
            except (AppError, ProviderError):
                checks[order.asset_id] = None  # try again on the next run
            check = checks[order.asset_id]
            if check is not None and not check.market_open:
                closed_until[order.asset_id] = now + CLOSED_RECHECK
            else:
                closed_until.pop(order.asset_id, None)
        check = checks[order.asset_id]
        if check is None or not check.market_open:
            continue
        account = await session.get(
            PracticeAccount, order.account_id, with_for_update=True, populate_existing=True
        )
        await session.refresh(order)
        if order.status != OrderStatus.pending.value:  # cancelled meanwhile
            continue
        _fill(account, order, check, await _pending(session, account))
        title, body = describe_fill(order)
        notification = notifications_service.build(
            account.user_id,
            "practice",
            title,
            body,
            asset_id=order.asset_id,
            data={"order_id": order.id, "status": order.status},
        )
        session.add(notification)
        await session.commit()
        done.append(Filled(order, notification))
    return done
