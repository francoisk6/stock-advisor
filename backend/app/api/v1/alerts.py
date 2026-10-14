from fastapi import APIRouter, status

from app.api.deps import CurrentUser, SessionDep
from app.api.v1.assets import get_asset
from app.db.models import Alert
from app.schemas.alerts import AlertCreateIn, AlertOut, AlertUpdateIn
from app.schemas.market import AssetOut
from app.services import alerts as alerts_service

router = APIRouter(prefix="/alerts", tags=["alerts"])


def _out(alert: Alert) -> AlertOut:
    return AlertOut(
        id=alert.id,
        asset=AssetOut.model_validate(alert.asset),
        kind=alerts_service.AlertKind(alert.kind),
        threshold=float(alert.threshold),
        notify_email=alert.notify_email,
        is_active=alert.is_active,
        last_triggered_at=alert.last_triggered_at,
        trigger_count=alert.trigger_count,
        created_at=alert.created_at,
    )


@router.get("", response_model=list[AlertOut])
async def list_alerts(
    user: CurrentUser, session: SessionDep, asset_id: int | None = None
) -> list[AlertOut]:
    return [_out(a) for a in await alerts_service.list_for_user(session, user, asset_id)]


@router.post("", response_model=AlertOut, status_code=status.HTTP_201_CREATED)
async def create_alert(data: AlertCreateIn, user: CurrentUser, session: SessionDep) -> AlertOut:
    asset = await get_asset(session, data.asset_id)
    alert = await alerts_service.create(
        session, user, asset, data.kind, data.threshold, data.notify_email
    )
    return _out(alert)


@router.patch("/{alert_id}", response_model=AlertOut)
async def update_alert(
    alert_id: int, data: AlertUpdateIn, user: CurrentUser, session: SessionDep
) -> AlertOut:
    alert = await alerts_service.get_owned(session, user, alert_id)
    alert = await alerts_service.update(
        session,
        user,
        alert,
        threshold=data.threshold,
        notify_email=data.notify_email,
        is_active=data.is_active,
    )
    return _out(alert)


@router.delete("/{alert_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_alert(alert_id: int, user: CurrentUser, session: SessionDep) -> None:
    await alerts_service.delete(session, await alerts_service.get_owned(session, user, alert_id))
