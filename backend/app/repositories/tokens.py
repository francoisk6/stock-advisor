from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.time import utcnow
from app.db.models import EmailToken, RefreshToken


async def get_refresh_token(session: AsyncSession, token_hash: str) -> RefreshToken | None:
    result = await session.execute(
        select(RefreshToken).where(RefreshToken.token_hash == token_hash).with_for_update()
    )
    return result.scalar_one_or_none()


async def revoke_refresh_family(session: AsyncSession, family_id: str) -> None:
    await session.execute(
        update(RefreshToken)
        .where(RefreshToken.family_id == family_id, RefreshToken.revoked_at.is_(None))
        .values(revoked_at=utcnow())
    )


async def revoke_all_refresh_tokens(session: AsyncSession, user_id: int) -> None:
    await session.execute(
        update(RefreshToken)
        .where(RefreshToken.user_id == user_id, RefreshToken.revoked_at.is_(None))
        .values(revoked_at=utcnow())
    )


async def get_email_token(
    session: AsyncSession, token_hash: str, purpose: str
) -> EmailToken | None:
    result = await session.execute(
        select(EmailToken)
        .where(EmailToken.token_hash == token_hash, EmailToken.purpose == purpose)
        .with_for_update()
    )
    return result.scalar_one_or_none()


async def invalidate_email_tokens(session: AsyncSession, user_id: int, purpose: str) -> None:
    """Mark unused tokens of this purpose as used, so only the newest link works."""
    await session.execute(
        update(EmailToken)
        .where(
            EmailToken.user_id == user_id,
            EmailToken.purpose == purpose,
            EmailToken.used_at.is_(None),
        )
        .values(used_at=utcnow())
    )
