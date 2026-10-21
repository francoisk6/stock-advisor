from fastapi import APIRouter

from app.api.deps import CurrentUser, SessionDep
from app.schemas.plans import PlanInfoOut, UsageItemOut, UsageOut
from app.services import plans as plans_service
from app.services.users import active_plan

router = APIRouter(prefix="/plans", tags=["plans"])


@router.get("", response_model=list[PlanInfoOut])
async def list_plans(session: SessionDep, _: CurrentUser) -> list[PlanInfoOut]:
    return [
        PlanInfoOut(
            code=p.code,
            name=p.name,
            price_monthly_usd=None if p.price_monthly_usd is None else float(p.price_monthly_usd),
            price_yearly_usd=None if p.price_yearly_usd is None else float(p.price_yearly_usd),
            for_sale=p.is_active,
            limits={key: p.limits.get(key) for key in plans_service.SHOWN_LIMITS},
        )
        for p in await plans_service.plans(session)
    ]


async def _usage(session: SessionDep, user: CurrentUser) -> UsageOut:
    plan = active_plan(user)
    items = await plans_service.usage(session, user)
    return UsageOut(
        plan=plan.code,
        plan_name=plan.name,
        items=[UsageItemOut(key=u.key, used=u.used, limit=u.limit) for u in items],
        pro_interest_at=user.profile.pro_interest_at if user.profile else None,
    )


@router.get("/usage", response_model=UsageOut)
async def my_usage(session: SessionDep, user: CurrentUser) -> UsageOut:
    return await _usage(session, user)


@router.post("/pro/interest", response_model=UsageOut)
async def pro_interest(session: SessionDep, user: CurrentUser) -> UsageOut:
    """ "Tell me when Pro is ready." Idempotent."""
    await plans_service.register_pro_interest(session, user)
    return await _usage(session, user)
