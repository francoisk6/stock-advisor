"""Price alerts: rules, limits and the periodic check that turns them into notifications.

Kinds:
- price_above / price_below: fire once when the price crosses `threshold`, then switch off.
- move_up / move_down: fire when today's move reaches `threshold` percent, at most once per
  UTC day; they stay on.
"""

from dataclasses import dataclass
from decimal import Decimal
from enum import Enum

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.errors import AppError, NotFoundError
from app.core.money import format_money, format_percent
from app.core.time import utcnow
from app.db.models import Alert, Asset, Notification, User
from app.market_data import service as market
from app.market_data.types import Quote
from app.services import email as email_service
from app.services import notifications as notifications_service
from app.services.plans import check_limit


class AlertKind(str, Enum):
    price_above = "price_above"
    price_below = "price_below"
    move_up = "move_up"
    move_down = "move_down"


ONE_SHOT = {AlertKind.price_above, AlertKind.price_below}
MAX_MOVE_PERCENT = Decimal("50")
LIMIT_MESSAGE = (
    "Your {plan} plan allows up to {limit} active alerts. Delete or pause one to add another."
)


def validate_threshold(kind: AlertKind, threshold: Decimal) -> None:
    if threshold <= 0:
        raise AppError("Please enter a number greater than zero.")
    if kind not in ONE_SHOT and threshold > MAX_MOVE_PERCENT:
        raise AppError("Daily moves above 50% are extremely rare; please choose a smaller one.")


async def _active_count(session: AsyncSession, user_id: int) -> int:
    result = await session.execute(
        select(func.count())
        .select_from(Alert)
        .where(Alert.user_id == user_id, Alert.is_active.is_(True))
    )
    return int(result.scalar_one())


async def list_for_user(
    session: AsyncSession, user: User, asset_id: int | None = None
) -> list[Alert]:
    stmt = select(Alert).where(Alert.user_id == user.id)
    if asset_id is not None:
        stmt = stmt.where(Alert.asset_id == asset_id)
    result = await session.execute(stmt.order_by(Alert.is_active.desc(), Alert.id.desc()))
    return list(result.scalars())


async def get_owned(session: AsyncSession, user: User, alert_id: int) -> Alert:
    alert = await session.get(Alert, alert_id)
    if alert is None or alert.user_id != user.id:
        raise NotFoundError("We couldn't find this alert.")
    return alert


async def create(
    session: AsyncSession,
    user: User,
    asset: Asset,
    kind: AlertKind,
    threshold: Decimal,
    notify_email: bool,
) -> Alert:
    validate_threshold(kind, threshold)
    check_limit(user, "alerts", await _active_count(session, user.id), LIMIT_MESSAGE)
    alert = Alert(
        user_id=user.id,
        asset_id=asset.id,
        asset=asset,
        kind=kind.value,
        threshold=threshold,
        notify_email=notify_email,
        is_active=True,
        trigger_count=0,
    )
    session.add(alert)
    await session.commit()
    await session.refresh(alert)
    return alert


async def update(
    session: AsyncSession,
    user: User,
    alert: Alert,
    *,
    threshold: Decimal | None,
    notify_email: bool | None,
    is_active: bool | None,
) -> Alert:
    if threshold is not None:
        validate_threshold(AlertKind(alert.kind), threshold)
        alert.threshold = threshold
    if notify_email is not None:
        alert.notify_email = notify_email
    if is_active is True and not alert.is_active:
        check_limit(user, "alerts", await _active_count(session, user.id), LIMIT_MESSAGE)
        alert.is_active = True
        alert.last_triggered_at = None  # re-armed: may fire again today
    elif is_active is False:
        alert.is_active = False
    await session.commit()
    await session.refresh(alert)
    return alert


async def delete(session: AsyncSession, alert: Alert) -> None:
    await session.delete(alert)
    await session.commit()


# --- checking -------------------------------------------------------------------------------


def is_triggered(alert: Alert, quote: Quote) -> bool:
    kind = AlertKind(alert.kind)
    threshold = float(alert.threshold)
    if kind == AlertKind.price_above:
        return quote.price >= threshold
    if kind == AlertKind.price_below:
        return quote.price <= threshold
    change = quote.change_percent
    if change is None:
        return False
    if alert.last_triggered_at is not None and alert.last_triggered_at.date() == utcnow().date():
        return False  # once per day
    return change >= threshold if kind == AlertKind.move_up else change <= -threshold


def describe(alert: Alert, quote: Quote) -> tuple[str, str]:
    """(title, body) in plain language."""
    asset = alert.asset
    currency = quote.currency or asset.currency
    price = format_money(quote.price, currency)
    today = (
        f" ({format_percent(quote.change_percent)} today)"
        if quote.change_percent is not None
        else ""
    )
    kind = AlertKind(alert.kind)
    if kind in ONE_SHOT:
        target = format_money(alert.threshold, currency)
        direction = "above" if kind == AlertKind.price_above else "below"
        title = f"{asset.symbol} is {direction} {target}"
        body = (
            f"{asset.name} is now {price}{today}. This alert is now switched off; "
            "you can turn it back on or create a new one in the app."
        )
    else:
        move = format_percent(quote.change_percent or 0)
        title = f"{asset.symbol} moved {move} today"
        body = (
            f"{asset.name} is at {price}, {move} today, passing your "
            f"{format_percent(alert.threshold, signed=False)} alert. "
            "We'll tell you again on another day if it happens again."
        )
    return title, body


@dataclass
class Fired:
    alert: Alert
    notification: Notification
    email: email_service.OutgoingEmail | None


async def check_alerts(session: AsyncSession) -> list[Fired]:
    """Evaluate every active alert against the latest prices (one batched call per source)."""
    result = await session.execute(select(Alert).where(Alert.is_active.is_(True)))
    alerts = list(result.scalars())
    if not alerts:
        return []
    assets = list({a.asset_id: a.asset for a in alerts}.values())
    quotes = await market.quotes_for(assets)

    fired: list[Fired] = []
    now = utcnow()
    for alert in alerts:
        quote = quotes.get(alert.asset_id)
        if quote is None or not is_triggered(alert, quote):
            continue
        title, body = describe(alert, quote)
        alert.last_triggered_at = now
        alert.trigger_count += 1
        if AlertKind(alert.kind) in ONE_SHOT:
            alert.is_active = False
        notification = notifications_service.build(
            alert.user_id,
            "alert",
            title,
            body,
            asset_id=alert.asset_id,
            alert_id=alert.id,
            data={
                "kind": alert.kind,
                "threshold": float(alert.threshold),
                "price": quote.price,
                "change_percent": quote.change_percent,
                "currency": quote.currency or alert.asset.currency,
            },
        )
        session.add(notification)
        fired.append(Fired(alert, notification, None))

    if not fired:
        return []
    await session.commit()

    user_ids = {f.alert.user_id for f in fired}
    users = {
        u.id: u
        for u in (await session.execute(select(User).where(User.id.in_(user_ids)))).scalars()
    }
    for f in fired:
        user = users.get(f.alert.user_id)
        # Email only confirmed addresses; the in-app notification is always created.
        if f.alert.notify_email and user is not None and user.email_verified and user.is_active:
            f.email = email_service.alert_email(
                user.email,
                user.full_name,
                f.notification.title,
                f.notification.body,
                f"{settings.frontend_url.rstrip('/')}/assets/{f.alert.asset_id}",
            )
    return fired
