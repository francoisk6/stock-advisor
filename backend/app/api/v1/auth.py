from fastapi import APIRouter, BackgroundTasks, Request, status

from app.api.deps import ClientDep, CurrentUser, SessionDep
from app.core.config import settings
from app.core.errors import AuthError
from app.core.rate_limit import client_ip, enforce
from app.schemas.auth import (
    AuthOut,
    ForgotPasswordIn,
    GoogleLoginIn,
    LoginIn,
    MessageOut,
    RefreshIn,
    RegisterIn,
    ResetPasswordIn,
    TokenIn,
)
from app.services import auth as auth_service
from app.services.email import send_email
from app.services.google_auth import GoogleAuthError, verify_google_id_token
from app.services.users import to_user_out

router = APIRouter(prefix="/auth", tags=["auth"])

MINUTE = 60
HOUR = 60 * MINUTE


def auth_response(result: auth_service.AuthResult, background: BackgroundTasks) -> AuthOut:
    for email in result.emails:
        background.add_task(send_email, email)
    return AuthOut(
        access_token=result.access_token,
        refresh_token=result.refresh_token,
        expires_in=settings.access_token_minutes * 60,
        user=to_user_out(result.user),
    )


@router.post("/register", response_model=AuthOut, status_code=status.HTTP_201_CREATED)
async def register(
    data: RegisterIn,
    request: Request,
    session: SessionDep,
    client: ClientDep,
    background: BackgroundTasks,
) -> AuthOut:
    enforce(f"register:ip:{client_ip(request)}", limit=10, window_seconds=HOUR)
    result = await auth_service.register(
        session,
        email=data.email,
        password=data.password,
        full_name=data.full_name,
        client=client,
    )
    return auth_response(result, background)


@router.post("/login", response_model=AuthOut)
async def login(
    data: LoginIn,
    request: Request,
    session: SessionDep,
    client: ClientDep,
    background: BackgroundTasks,
) -> AuthOut:
    enforce(f"login:ip:{client_ip(request)}", limit=30, window_seconds=15 * MINUTE)
    enforce(f"login:email:{data.email.lower()}", limit=10, window_seconds=15 * MINUTE)
    result = await auth_service.login(
        session, email=data.email, password=data.password, client=client
    )
    return auth_response(result, background)


@router.post("/google", response_model=AuthOut)
async def login_with_google(
    data: GoogleLoginIn,
    request: Request,
    session: SessionDep,
    client: ClientDep,
    background: BackgroundTasks,
) -> AuthOut:
    enforce(f"google:ip:{client_ip(request)}", limit=30, window_seconds=15 * MINUTE)
    try:
        identity = await verify_google_id_token(data.id_token)
    except GoogleAuthError as exc:
        raise AuthError(str(exc)) from exc
    result = await auth_service.login_with_google(session, identity, client)
    return auth_response(result, background)


@router.post("/refresh", response_model=AuthOut)
async def refresh(
    data: RefreshIn, session: SessionDep, client: ClientDep, background: BackgroundTasks
) -> AuthOut:
    result = await auth_service.refresh(session, data.refresh_token, client)
    return auth_response(result, background)


@router.post("/logout", response_model=MessageOut)
async def logout(data: RefreshIn, session: SessionDep) -> MessageOut:
    await auth_service.logout(session, data.refresh_token)
    return MessageOut(message="Signed out")


@router.post("/verify-email", response_model=MessageOut)
async def verify_email(data: TokenIn, request: Request, session: SessionDep) -> MessageOut:
    enforce(f"verify:ip:{client_ip(request)}", limit=30, window_seconds=15 * MINUTE)
    await auth_service.verify_email(session, data.token)
    return MessageOut(message="Your email is confirmed.")


@router.post("/resend-verification", response_model=MessageOut)
async def resend_verification(
    user: CurrentUser, session: SessionDep, background: BackgroundTasks
) -> MessageOut:
    enforce(f"resend:user:{user.id}", limit=3, window_seconds=HOUR)
    email = await auth_service.resend_verification(session, user)
    if email is None:
        return MessageOut(message="Your email is already confirmed.")
    background.add_task(send_email, email)
    return MessageOut(message="We sent you a new confirmation email.")


@router.post("/forgot-password", response_model=MessageOut, status_code=status.HTTP_202_ACCEPTED)
async def forgot_password(
    data: ForgotPasswordIn, request: Request, session: SessionDep, background: BackgroundTasks
) -> MessageOut:
    enforce(f"forgot:ip:{client_ip(request)}", limit=10, window_seconds=HOUR)
    enforce(f"forgot:email:{data.email.lower()}", limit=3, window_seconds=HOUR)
    email = await auth_service.request_password_reset(session, data.email)
    if email is not None:
        background.add_task(send_email, email)
    # Same answer whether or not the account exists.
    return MessageOut(
        message="If an account exists for this email, we sent a link to reset your password."
    )


@router.post("/reset-password", response_model=MessageOut)
async def reset_password(
    data: ResetPasswordIn, request: Request, session: SessionDep
) -> MessageOut:
    enforce(f"reset:ip:{client_ip(request)}", limit=10, window_seconds=15 * MINUTE)
    await auth_service.reset_password(session, data.token, data.new_password)
    return MessageOut(message="Your password was changed. You can now sign in.")
