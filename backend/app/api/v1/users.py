from fastapi import APIRouter, BackgroundTasks, status
from pydantic import BaseModel, Field

from app.api.deps import ClientDep, CurrentUser, SessionDep
from app.api.v1.auth import auth_response
from app.core.errors import AppError
from app.core.rate_limit import enforce
from app.schemas.auth import AuthOut, ChangePasswordIn
from app.schemas.profile import ProfileUpdateIn
from app.schemas.user import UserOut, UserUpdateIn
from app.services import auth as auth_service
from app.services import users as users_service

router = APIRouter(prefix="/users", tags=["users"])


class DeleteAccountIn(BaseModel):
    password: str | None = Field(default=None, max_length=128)


@router.get("/me", response_model=UserOut)
async def get_me(user: CurrentUser) -> UserOut:
    return users_service.to_user_out(user)


@router.patch("/me", response_model=UserOut)
async def update_me(data: UserUpdateIn, user: CurrentUser, session: SessionDep) -> UserOut:
    await users_service.update_user(session, user, full_name=data.full_name)
    return users_service.to_user_out(user)


@router.put("/me/profile", response_model=UserOut)
async def update_my_profile(
    data: ProfileUpdateIn, user: CurrentUser, session: SessionDep
) -> UserOut:
    await users_service.update_profile(session, user, data)
    return users_service.to_user_out(user)


@router.post("/me/password", response_model=AuthOut)
async def change_my_password(
    data: ChangePasswordIn,
    user: CurrentUser,
    session: SessionDep,
    client: ClientDep,
    background: BackgroundTasks,
) -> AuthOut:
    enforce(f"change-password:user:{user.id}", limit=10, window_seconds=3600)
    result = await auth_service.change_password(
        session,
        user,
        current_password=data.current_password,
        new_password=data.new_password,
        client=client,
    )
    return auth_response(result, background)


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_me(data: DeleteAccountIn, user: CurrentUser, session: SessionDep) -> None:
    """Permanently deletes the account and all its data (required by app store policies)."""
    enforce(f"delete:user:{user.id}", limit=10, window_seconds=3600)
    if not auth_service.verify_password_for(user, data.password):
        raise AppError("Your password is incorrect.")
    await users_service.delete_user(session, user)
