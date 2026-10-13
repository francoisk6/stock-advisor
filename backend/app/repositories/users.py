from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import OAuthAccount, Plan, User


async def get_by_id(session: AsyncSession, user_id: int) -> User | None:
    return await session.get(User, user_id)


async def get_by_email(session: AsyncSession, email: str) -> User | None:
    result = await session.execute(select(User).where(User.email == email.lower()))
    return result.scalar_one_or_none()


async def get_by_oauth(session: AsyncSession, provider: str, provider_user_id: str) -> User | None:
    result = await session.execute(
        select(User)
        .join(OAuthAccount)
        .where(OAuthAccount.provider == provider, OAuthAccount.provider_user_id == provider_user_id)
    )
    return result.scalar_one_or_none()


async def get_plan_by_code(session: AsyncSession, code: str) -> Plan:
    result = await session.execute(select(Plan).where(Plan.code == code))
    return result.scalar_one()
