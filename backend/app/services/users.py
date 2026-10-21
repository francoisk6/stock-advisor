from sqlalchemy.ext.asyncio import AsyncSession

from app.core.time import utcnow
from app.db.models import Plan, User, UserPlan, UserProfile
from app.repositories import users as users_repo
from app.schemas.profile import ProfileOut, ProfileUpdateIn
from app.schemas.user import PlanOut, UserOut


async def create_user(
    session: AsyncSession, *, email: str, full_name: str, password_hash: str | None
) -> User:
    """New user with an empty profile, subscribed to the Free plan. Caller commits."""
    free_plan = await users_repo.get_plan_by_code(session, "free")
    user = User(
        email=email.lower(),
        full_name=full_name.strip(),
        password_hash=password_hash,
        profile=UserProfile(asset_interests=[], region_interests=[]),
        oauth_accounts=[],
        plans=[UserPlan(plan=free_plan, status="active", started_at=utcnow())],
    )
    session.add(user)
    await session.flush()
    return user


def active_plan(user: User) -> Plan:
    now = utcnow()
    current = [
        up
        for up in user.plans
        if up.status == "active" and (up.ends_at is None or up.ends_at > now)
    ]
    # Latest active subscription wins (e.g. Pro started after Free); the newer row breaks a
    # tie within the same second (a tester granted Pro right after signing up).
    return max(current, key=lambda up: (up.started_at, up.id or 0)).plan


def to_user_out(user: User) -> UserOut:
    plan = active_plan(user)
    return UserOut(
        id=user.id,
        email=user.email,
        full_name=user.full_name,
        email_verified=user.email_verified,
        has_password=user.password_hash is not None,
        auth_providers=sorted({a.provider for a in user.oauth_accounts}),
        created_at=user.created_at,
        profile=ProfileOut.model_validate(user.profile),
        plan=PlanOut(code=plan.code, name=plan.name, limits=plan.limits),
    )


async def update_user(session: AsyncSession, user: User, *, full_name: str) -> User:
    user.full_name = full_name.strip()
    await session.commit()
    return user


async def update_profile(session: AsyncSession, user: User, data: ProfileUpdateIn) -> User:
    profile = user.profile
    profile.experience_level = data.experience_level.value
    profile.risk_profile = data.risk_profile.value
    profile.investment_horizon = data.investment_horizon.value
    # Deduplicate while keeping the user's order.
    profile.asset_interests = list(dict.fromkeys(a.value for a in data.asset_interests))
    profile.region_interests = list(dict.fromkeys(r.value for r in data.region_interests))
    profile.preferred_language = data.preferred_language
    profile.preferred_currency = data.preferred_currency
    if profile.onboarding_completed_at is None:
        profile.onboarding_completed_at = utcnow()
    await session.commit()
    return user


async def delete_user(session: AsyncSession, user: User) -> None:
    await session.delete(user)
    await session.commit()
