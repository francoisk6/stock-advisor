import uuid
from dataclasses import dataclass, field
from datetime import timedelta
from urllib.parse import urlencode

from sqlalchemy.ext.asyncio import AsyncSession

from app.core import security
from app.core.config import settings
from app.core.errors import AuthError, ConflictError
from app.core.time import utcnow
from app.db.models import EmailToken, OAuthAccount, RefreshToken, User
from app.repositories import tokens as tokens_repo
from app.repositories import users as users_repo
from app.services import email as email_service
from app.services.google_auth import GoogleIdentity
from app.services.users import create_user

VERIFY_EMAIL = "verify_email"
RESET_PASSWORD = "reset_password"

# A refresh token reused within this window (e.g. two tabs refreshing at once) is rejected
# without treating it as theft.
REFRESH_REUSE_GRACE = timedelta(seconds=10)

INVALID_CREDENTIALS = "Invalid email or password"
SESSION_EXPIRED = "Your session has expired. Please sign in again."

# Verified against when the email is unknown, so response time doesn't reveal which emails exist.
_DUMMY_HASH = security.hash_password("timing-equalizer-not-a-real-password-1")


@dataclass
class ClientInfo:
    user_agent: str | None = None
    ip_address: str | None = None


@dataclass
class AuthResult:
    user: User
    access_token: str
    refresh_token: str
    emails: list[email_service.OutgoingEmail] = field(default_factory=list)


def _frontend_link(path: str, token: str) -> str:
    return f"{settings.frontend_url.rstrip('/')}{path}?{urlencode({'token': token})}"


async def _issue_tokens(
    session: AsyncSession, user: User, client: ClientInfo, family_id: str | None = None
) -> tuple[str, str]:
    raw_refresh = security.generate_opaque_token()
    session.add(
        RefreshToken(
            user_id=user.id,
            token_hash=security.hash_token(raw_refresh),
            family_id=family_id or str(uuid.uuid4()),
            expires_at=utcnow() + timedelta(days=settings.refresh_token_days),
            user_agent=(client.user_agent or "")[:255] or None,
            ip_address=client.ip_address,
        )
    )
    return security.create_access_token(user.id), raw_refresh


async def _create_email_token(
    session: AsyncSession, user: User, purpose: str, lifetime: timedelta
) -> str:
    await tokens_repo.invalidate_email_tokens(session, user.id, purpose)
    raw = security.generate_opaque_token()
    session.add(
        EmailToken(
            user_id=user.id,
            purpose=purpose,
            token_hash=security.hash_token(raw),
            expires_at=utcnow() + lifetime,
        )
    )
    return raw


async def _verification_email(session: AsyncSession, user: User) -> email_service.OutgoingEmail:
    raw = await _create_email_token(
        session, user, VERIFY_EMAIL, timedelta(hours=settings.email_verify_token_hours)
    )
    return email_service.verification_email(
        user.email, user.full_name, _frontend_link("/verify-email", raw)
    )


async def _finish_login(session: AsyncSession, user: User, client: ClientInfo) -> AuthResult:
    user.last_login_at = utcnow()
    access, refresh = await _issue_tokens(session, user, client)
    await session.commit()
    await session.refresh(user)
    return AuthResult(user=user, access_token=access, refresh_token=refresh)


async def register(
    session: AsyncSession, *, email: str, password: str, full_name: str, client: ClientInfo
) -> AuthResult:
    if await users_repo.get_by_email(session, email):
        raise ConflictError("An account with this email already exists. Try signing in.")
    user = await create_user(
        session,
        email=email,
        full_name=full_name,
        password_hash=security.hash_password(password),
    )
    verification = await _verification_email(session, user)
    result = await _finish_login(session, user, client)
    result.emails.append(verification)
    return result


async def login(
    session: AsyncSession, *, email: str, password: str, client: ClientInfo
) -> AuthResult:
    user = await users_repo.get_by_email(session, email)
    if user is None:
        security.verify_password(password, _DUMMY_HASH)
        raise AuthError(INVALID_CREDENTIALS)
    if not security.verify_password(password, user.password_hash) or not user.is_active:
        raise AuthError(INVALID_CREDENTIALS)
    return await _finish_login(session, user, client)


async def login_with_google(
    session: AsyncSession, identity: GoogleIdentity, client: ClientInfo
) -> AuthResult:
    user = await users_repo.get_by_oauth(session, "google", identity.subject)
    if user is None:
        if not identity.email_verified:
            raise AuthError("Your Google email address is not verified.")
        user = await users_repo.get_by_email(session, identity.email)
        if user is None:
            user = await create_user(
                session, email=identity.email, full_name=identity.name, password_hash=None
            )
        elif not user.email_verified:
            # Someone registered this email with a password but never proved they own it.
            # Google just proved ownership, so drop that password and its sessions
            # (prevents account pre-hijacking). The owner can set a password later.
            user.password_hash = None
            await tokens_repo.revoke_all_refresh_tokens(session, user.id)
        user.oauth_accounts.append(
            OAuthAccount(provider="google", provider_user_id=identity.subject, email=identity.email)
        )
        if user.email_verified_at is None:
            user.email_verified_at = utcnow()
        if not user.full_name and identity.name:
            user.full_name = identity.name[:100]
    if not user.is_active:
        raise AuthError("This account is disabled.")
    return await _finish_login(session, user, client)


async def refresh(session: AsyncSession, raw_token: str, client: ClientInfo) -> AuthResult:
    now = utcnow()
    stored = await tokens_repo.get_refresh_token(session, security.hash_token(raw_token))
    if stored is None:
        raise AuthError(SESSION_EXPIRED)
    if stored.revoked_at is not None:
        if now - stored.revoked_at > REFRESH_REUSE_GRACE:
            # Old token replayed: assume it leaked and end every session in this family.
            await tokens_repo.revoke_refresh_family(session, stored.family_id)
            await session.commit()
        raise AuthError(SESSION_EXPIRED)
    if stored.expires_at <= now:
        raise AuthError(SESSION_EXPIRED)
    user = await users_repo.get_by_id(session, stored.user_id)
    if user is None or not user.is_active:
        raise AuthError(SESSION_EXPIRED)

    stored.revoked_at = now
    access, new_refresh = await _issue_tokens(session, user, client, family_id=stored.family_id)
    await session.commit()
    await session.refresh(user)
    return AuthResult(user=user, access_token=access, refresh_token=new_refresh)


async def logout(session: AsyncSession, raw_token: str) -> None:
    stored = await tokens_repo.get_refresh_token(session, security.hash_token(raw_token))
    if stored is not None and stored.revoked_at is None:
        stored.revoked_at = utcnow()
    await session.commit()


async def resend_verification(
    session: AsyncSession, user: User
) -> email_service.OutgoingEmail | None:
    if user.email_verified:
        return None
    email = await _verification_email(session, user)
    await session.commit()
    return email


async def verify_email(session: AsyncSession, raw_token: str) -> None:
    stored = await tokens_repo.get_email_token(
        session, security.hash_token(raw_token), VERIFY_EMAIL
    )
    now = utcnow()
    user = await users_repo.get_by_id(session, stored.user_id) if stored else None
    if stored is not None and stored.used_at is not None and user and user.email_verified:
        return  # link clicked twice: already confirmed
    if stored is None or stored.used_at is not None or stored.expires_at <= now:
        raise AuthError(
            "This confirmation link is invalid or has expired. "
            "Request a new one from your profile.",
            status_code=400,
        )
    stored.used_at = now
    if user is not None and user.email_verified_at is None:
        user.email_verified_at = now
    await session.commit()


async def request_password_reset(
    session: AsyncSession, email: str
) -> email_service.OutgoingEmail | None:
    """Returns the email to send, or None for unknown/disabled accounts (caller hides which)."""
    user = await users_repo.get_by_email(session, email)
    if user is None or not user.is_active:
        return None
    raw = await _create_email_token(
        session, user, RESET_PASSWORD, timedelta(minutes=settings.password_reset_token_minutes)
    )
    await session.commit()
    return email_service.password_reset_email(
        user.email, user.full_name, _frontend_link("/reset-password", raw)
    )


async def reset_password(session: AsyncSession, raw_token: str, new_password: str) -> None:
    stored = await tokens_repo.get_email_token(
        session, security.hash_token(raw_token), RESET_PASSWORD
    )
    now = utcnow()
    if stored is None or stored.used_at is not None or stored.expires_at <= now:
        raise AuthError(
            "This reset link is invalid or has expired. Please request a new one.",
            status_code=400,
        )
    user = await users_repo.get_by_id(session, stored.user_id)
    if user is None or not user.is_active:
        raise AuthError("This reset link is invalid or has expired.", status_code=400)
    stored.used_at = now
    user.password_hash = security.hash_password(new_password)
    # Receiving the email proves ownership of the address.
    if user.email_verified_at is None:
        user.email_verified_at = now
    await tokens_repo.revoke_all_refresh_tokens(session, user.id)
    await session.commit()


async def change_password(
    session: AsyncSession,
    user: User,
    *,
    current_password: str | None,
    new_password: str,
    client: ClientInfo,
) -> AuthResult:
    """Sets a new password, signs out every other session, and returns fresh tokens."""
    if user.password_hash is not None and not security.verify_password(
        current_password or "", user.password_hash
    ):
        raise AuthError("Your current password is incorrect.", status_code=400)
    user.password_hash = security.hash_password(new_password)
    await tokens_repo.revoke_all_refresh_tokens(session, user.id)
    return await _finish_login(session, user, client)


def verify_password_for(user: User, password: str | None) -> bool:
    """Re-authentication check for sensitive actions. Google-only accounts have no password."""
    if user.password_hash is None:
        return True
    return security.verify_password(password or "", user.password_hash)
