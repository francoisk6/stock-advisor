from typing import Annotated

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.db.session import get_session

router = APIRouter(prefix="/health", tags=["health"])


class HealthOut(BaseModel):
    status: str
    app: str
    environment: str


class DbHealthOut(BaseModel):
    status: str
    database: str


@router.get("", response_model=HealthOut)
async def health() -> HealthOut:
    return HealthOut(status="ok", app=settings.app_name, environment=settings.environment)


@router.get("/db", response_model=DbHealthOut)
async def health_db(session: Annotated[AsyncSession, Depends(get_session)]) -> DbHealthOut:
    await session.execute(text("SELECT 1"))
    return DbHealthOut(status="ok", database=settings.db_name)
