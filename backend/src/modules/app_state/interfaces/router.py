from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session
from modules.app_state.infrastructure.postgres.repository import PostgresAppStateRepository

router = APIRouter(prefix="/app-state", tags=["app-state"])


@router.get("/current")
async def get_current_app_state(session: AsyncSession = Depends(get_session)) -> dict:
    payload = await PostgresAppStateRepository(session).get_current()
    if payload is None:
        raise HTTPException(status_code=404, detail="App state has not been seeded")
    return payload


@router.put("/current")
async def replace_current_app_state(
    payload: dict,
    session: AsyncSession = Depends(get_session),
) -> dict[str, str]:
    await PostgresAppStateRepository(session).upsert_current(payload)
    await session.commit()
    return {"status": "ok"}
