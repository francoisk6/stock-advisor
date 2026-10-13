from typing import Annotated

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AuthError
from app.core.rate_limit import client_ip
from app.core.security import decode_access_token
from app.db.models import User
from app.db.session import get_session
from app.repositories import users as users_repo
from app.services.auth import ClientInfo

SessionDep = Annotated[AsyncSession, Depends(get_session)]

_bearer = HTTPBearer(auto_error=False)


async def get_current_user(
    session: SessionDep,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
) -> User:
    if credentials is None:
        raise AuthError("Not signed in")
    user_id = decode_access_token(credentials.credentials)
    user = await users_repo.get_by_id(session, user_id) if user_id is not None else None
    if user is None or not user.is_active:
        raise AuthError("Your session has expired. Please sign in again.")
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]


def get_client_info(request: Request) -> ClientInfo:
    return ClientInfo(user_agent=request.headers.get("user-agent"), ip_address=client_ip(request))


ClientDep = Annotated[ClientInfo, Depends(get_client_info)]
