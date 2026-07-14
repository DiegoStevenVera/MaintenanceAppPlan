from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session, uses_postgres
from modules.maintenance_execution.infrastructure.postgres.repository import (
    PostgresMaintenanceRepository,
)
from modules.maintenance_execution.infrastructure.seed_repository import maintenance_repository
from modules.maintenance_execution.interfaces.schemas import (
    CorrectiveEventDTO,
    CreateCorrectiveEventRequest,
    PreventiveScheduleDTO,
)
from shared_kernel.schemas import MaintenanceStatus, Page

router = APIRouter(tags=["maintenance"])


@router.get("/schedules", response_model=Page[PreventiveScheduleDTO])
async def list_preventive_schedules(
    status: MaintenanceStatus | None = None,
    subsystem: str | None = None,
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    session: AsyncSession = Depends(get_session),
) -> Page[PreventiveScheduleDTO]:
    if uses_postgres():
        schedules = await PostgresMaintenanceRepository(session).list_preventive_schedules(
            status=status,
            subsystem=subsystem,
        )
    else:
        schedules = maintenance_repository.list_preventive_schedules(
            status=status,
            subsystem=subsystem,
        )
    return Page(items=schedules[offset : offset + limit], total=len(schedules), limit=limit, offset=offset)


@router.get("/corrective-events", response_model=Page[CorrectiveEventDTO])
async def list_corrective_events(
    status: MaintenanceStatus | None = None,
    subsystem: str | None = None,
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    session: AsyncSession = Depends(get_session),
) -> Page[CorrectiveEventDTO]:
    if uses_postgres():
        events = await PostgresMaintenanceRepository(session).list_corrective_events(
            status=status,
            subsystem=subsystem,
        )
    else:
        events = maintenance_repository.list_corrective_events(status=status, subsystem=subsystem)
    return Page(items=events[offset : offset + limit], total=len(events), limit=limit, offset=offset)


@router.get("/corrective-events/{event_id}", response_model=CorrectiveEventDTO)
async def get_corrective_event(
    event_id: str,
    session: AsyncSession = Depends(get_session),
) -> CorrectiveEventDTO:
    if uses_postgres():
        event = await PostgresMaintenanceRepository(session).get_corrective_event(event_id)
    else:
        event = maintenance_repository.get_corrective_event(event_id)
    if event is None:
        raise HTTPException(status_code=404, detail="Corrective event not found")
    return event


@router.post("/corrective-events", response_model=CorrectiveEventDTO, status_code=201)
async def create_corrective_event(
    payload: CreateCorrectiveEventRequest,
    session: AsyncSession = Depends(get_session),
) -> CorrectiveEventDTO:
    if uses_postgres():
        return await PostgresMaintenanceRepository(session).create_corrective_event(payload)
    return maintenance_repository.create_corrective_event(payload)
