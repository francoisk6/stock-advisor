"""Portfolio tracker: holdings the user enters by hand, valued at live prices.

Values are shown in the user's chosen currency (profile `preferred_currency`), converted at
today's exchange rates (so gains don't separate price and currency effects; the app says so).
The risk overview is a few plain rules, returned as codes + numbers so the app can word them.
"""

from dataclasses import dataclass, field
from datetime import date
from decimal import ROUND_HALF_UP, Decimal
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError, NotFoundError
from app.db.models import Asset, Holding, User
from app.market_data import service as market
from app.services.plans import PRO_SOON, check_limit

CENT = Decimal("0.01")
UNIT = Decimal("0.00000001")

# Risk rule thresholds (percent of the portfolio's value).
CONCENTRATION = 40
CRYPTO_SHARE = 20
FOREIGN_SHARE = 50
FEW_HOLDINGS = 5


class PortfolioError(AppError):
    pass


def _major(currency: str) -> str:
    return market.MINOR_UNITS.get(currency, (currency, 1))[0]


@dataclass
class HoldingValue:
    holding: Holding
    currency: str  # the asset's own currency
    price: Decimal | None  # latest, in `currency`
    change_percent: float | None  # today
    rate: Decimal | None  # display currency per unit of `currency`
    previous_close: Decimal | None = None

    def _display(self, amount: Decimal | None) -> Decimal | None:
        if amount is None or self.rate is None:
            return None
        return (amount * self.rate).quantize(CENT, rounding=ROUND_HALF_UP)

    @property
    def value(self) -> Decimal | None:
        return None if self.price is None else self._display(self.holding.quantity * self.price)

    @property
    def cost(self) -> Decimal | None:
        return self._display(self.holding.quantity * self.holding.average_price)

    @property
    def gain(self) -> Decimal | None:
        value, cost = self.value, self.cost
        return None if value is None or cost is None else value - cost

    @property
    def day_change(self) -> Decimal | None:
        if self.price is None or self.previous_close is None:
            return None
        return self._display(self.holding.quantity * (self.price - self.previous_close))


@dataclass
class Risk:
    # concentration | crypto_share | foreign_currency | few_holdings | one_region | spread
    code: str
    level: str  # caution | good
    params: dict[str, Any] = field(default_factory=dict)


@dataclass
class Portfolio:
    currency: str
    holdings: list[HoldingValue]
    by_type: dict[str, Decimal]
    by_region: dict[str, Decimal]
    by_currency: dict[str, Decimal]
    risks: list[Risk]

    @property
    def total_value(self) -> Decimal:
        return sum((h.value or Decimal(0) for h in self.holdings), Decimal(0))

    @property
    def total_cost(self) -> Decimal:
        return sum((h.cost or Decimal(0) for h in self.holdings if h.value), Decimal(0))

    @property
    def gain(self) -> Decimal:
        return self.total_value - self.total_cost

    @property
    def day_change(self) -> Decimal:
        return sum((h.day_change or Decimal(0) for h in self.holdings), Decimal(0))

    @property
    def prices_complete(self) -> bool:
        return all(h.value is not None for h in self.holdings)

    def share(self, value: Decimal | None) -> float | None:
        total = self.total_value
        return None if value is None or not total else float(value / total * 100)


async def display_rates(currencies: set[str], display: str) -> dict[str, Decimal | None]:
    """Display-currency units per unit of each currency (via US dollars)."""
    display_usd = await market.usd_per_unit(display)
    rates: dict[str, Decimal | None] = {}
    for currency in currencies:
        usd = await market.usd_per_unit(currency)
        rates[currency] = None if usd is None or not display_usd else usd / display_usd
    return rates


def _risks(p: Portfolio) -> list[Risk]:
    valued = [h for h in p.holdings if h.value]
    if not valued:
        return []
    risks: list[Risk] = []
    top = max(valued, key=lambda h: h.value)
    top_share = p.share(top.value) or 0
    if top_share >= CONCENTRATION and len(valued) > 1:
        risks.append(
            Risk(
                "concentration",
                "caution",
                {
                    "symbol": top.holding.asset.symbol,
                    "percent": round(top_share, 1),
                    # If it fell 30%, the whole portfolio would fall this much.
                    "drop_if_30": round(top_share * 0.3, 1),
                },
            )
        )
    crypto = p.share(p.by_type.get("crypto"))
    if crypto is not None and crypto >= CRYPTO_SHARE:
        risks.append(Risk("crypto_share", "caution", {"percent": round(crypto, 1)}))
    foreign = sum(v for c, v in p.by_currency.items() if c != p.currency)
    foreign_share = p.share(foreign) if foreign else None
    if foreign_share is not None and foreign_share >= FOREIGN_SHARE:
        risks.append(
            Risk(
                "foreign_currency",
                "caution",
                {"percent": round(foreign_share, 1), "currency": p.currency},
            )
        )
    if len(valued) < FEW_HOLDINGS:
        risks.append(Risk("few_holdings", "caution", {"count": len(valued)}))
    if len(p.by_region) == 1 and len(valued) >= 3:
        risks.append(Risk("one_region", "caution", {"region": next(iter(p.by_region))}))
    if not risks:
        risks.append(
            Risk("spread", "good", {"count": len(valued), "top_percent": round(top_share, 1)})
        )
    return risks


async def summary(session: AsyncSession, user: User) -> Portfolio:
    display = user.profile.preferred_currency if user.profile else "USD"
    result = await session.execute(select(Holding).where(Holding.user_id == user.id))
    holdings = list(result.scalars())
    quotes = await market.quotes_for([h.asset for h in holdings]) if holdings else {}
    currencies = {
        (quotes[h.asset_id].currency if quotes.get(h.asset_id) else None)
        or h.asset.currency
        or "USD"
        for h in holdings
    }
    rates = await display_rates(currencies, display)
    values = []
    for h in holdings:
        quote = quotes.get(h.asset_id)
        currency = (quote.currency if quote else None) or h.asset.currency or "USD"
        values.append(
            HoldingValue(
                h,
                currency,
                Decimal(str(quote.price)) if quote else None,
                quote.change_percent if quote else None,
                rates.get(currency),
                Decimal(str(quote.previous_close)) if quote and quote.previous_close else None,
            )
        )
    values.sort(key=lambda v: v.value or Decimal(0), reverse=True)

    def group(key) -> dict[str, Decimal]:
        out: dict[str, Decimal] = {}
        for v in values:
            if v.value:
                out[key(v)] = out.get(key(v), Decimal(0)) + v.value
        return dict(sorted(out.items(), key=lambda kv: kv[1], reverse=True))

    portfolio = Portfolio(
        display,
        values,
        group(lambda v: v.holding.asset.asset_type),
        group(lambda v: v.holding.asset.region),
        group(lambda v: _major(v.currency)),
        [],
    )
    portfolio.risks = _risks(portfolio)
    return portfolio


# --- editing ------------------------------------------------------------------------------


def _check(asset: Asset, quantity: Decimal, average_price: Decimal) -> None:
    if asset.asset_type == "index":
        raise PortfolioError(
            f"An index like {asset.name} is a score, not something you can own. "
            "Add the fund (ETF) that follows it instead."
        )
    if quantity <= 0:
        raise PortfolioError("The number of units must be more than zero.")
    if average_price < 0:
        raise PortfolioError("The price paid can't be negative.")


async def get_owned(session: AsyncSession, user: User, holding_id: int) -> Holding:
    holding = await session.get(Holding, holding_id)
    if holding is None or holding.user_id != user.id:
        raise NotFoundError("That holding doesn't exist.")
    return holding


async def add(
    session: AsyncSession,
    user: User,
    asset: Asset,
    quantity: Decimal,
    average_price: Decimal,
    bought_on: date | None = None,
    note: str | None = None,
) -> Holding:
    """Add a holding. Adding an asset already held means buying more: units add up and the
    average price becomes the weighted average."""
    quantity = quantity.quantize(UNIT)
    _check(asset, quantity, average_price)
    existing = (
        await session.execute(
            select(Holding).where(Holding.user_id == user.id, Holding.asset_id == asset.id)
        )
    ).scalar_one_or_none()
    if existing is not None:
        total = existing.quantity + quantity
        existing.average_price = (
            (existing.quantity * existing.average_price + quantity * average_price) / total
        ).quantize(UNIT)
        existing.quantity = total
        existing.bought_on = existing.bought_on or bought_on
        holding = existing
    else:
        count = await session.scalar(
            select(func.count()).select_from(Holding).where(Holding.user_id == user.id)
        )
        check_limit(
            user,
            "portfolio_holdings",
            count or 0,
            "The {plan} plan can track up to {limit} holdings. " + PRO_SOON,
        )
        holding = Holding(
            user_id=user.id,
            asset_id=asset.id,
            quantity=quantity,
            average_price=average_price,
            bought_on=bought_on,
            note=note,
        )
        holding.asset = asset
        session.add(holding)
    await session.commit()
    return holding


async def update(
    session: AsyncSession,
    user: User,
    holding_id: int,
    quantity: Decimal,
    average_price: Decimal,
    bought_on: date | None,
    note: str | None,
) -> Holding:
    holding = await get_owned(session, user, holding_id)
    quantity = quantity.quantize(UNIT)
    _check(holding.asset, quantity, average_price)
    holding.quantity = quantity
    holding.average_price = average_price
    holding.bought_on = bought_on
    holding.note = note
    await session.commit()
    return holding


async def delete(session: AsyncSession, user: User, holding_id: int) -> None:
    holding = await get_owned(session, user, holding_id)
    await session.delete(holding)
    await session.commit()


async def set_currency(session: AsyncSession, user: User, currency: str) -> None:
    currency = currency.upper()
    if currency in market.MINOR_UNITS or await market.usd_per_unit(currency) is None:
        raise PortfolioError(f"We can't show values in {currency} right now.")
    user.profile.preferred_currency = currency
    await session.commit()
