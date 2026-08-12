from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session
from modules.identity_access.interfaces.dependencies import get_current_user, require_roles
from modules.app_state.infrastructure.postgres.repository import PostgresAppStateRepository
from shared_kernel.schemas import UserRole

router = APIRouter(
    prefix="/app-state",
    tags=["app-state"],
    dependencies=[Depends(get_current_user)],
)


@router.get("/current")
async def get_current_app_state(session: AsyncSession = Depends(get_session)) -> dict:
    payload = await PostgresAppStateRepository(session).get_current()
    if payload is None:
        raise HTTPException(status_code=404, detail="App state has not been seeded")
    return payload


@router.put("/current")
async def replace_current_app_state(
    payload: dict,
    _current_user=Depends(
        require_roles(
            UserRole.MAINTENANCE_ENGINEER,
            UserRole.COORDINATOR,
            UserRole.ADMINISTRATOR,
        )
    ),
    session: AsyncSession = Depends(get_session),
) -> dict[str, str]:
    await PostgresAppStateRepository(session).upsert_current(payload)
    await session.commit()
    return {"status": "ok"}
