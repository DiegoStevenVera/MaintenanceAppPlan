from datetime import date
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session, uses_postgres
from modules.identity_access.interfaces.dependencies import require_roles
from modules.identity_access.interfaces.schemas import UserDTO
from modules.maintenance_execution.infrastructure.postgres.planning_repository import (
    PlanningNotFoundError,
    PlanningValidationError,
    PostgresPlanningRepository,
)
from modules.maintenance_execution.interfaces.planning_schemas import (
    AddPlanScopeRequest,
    AddPlanScopeResponse,
    AssignPlanMonthRequest,
    CancelOccurrenceRequest,
    CopyAnnualPlanRequest,
    CopyAnnualPlanResponse,
    CreateWeeklySessionRequest,
    CreateOccurrencesRequest,
    MoveOccurrenceRequest,
    PCONAnnualPlanDTO,
    PCONCatalogDTO,
    PCONPlanChangeDTO,
    PCONPlanPageDTO,
    PlanningHistoryItemDTO,
    ScheduleProposalRequest,
    SetAnnualPlanCountRequest,
    SetAnnualPlanCountResponse,
    WeeklyPlanningDetailDTO,
)
from shared_kernel.schemas import UserRole

router = APIRouter(
    prefix="/pcon",
    tags=["pcon"],
    dependencies=[Depends(require_roles(UserRole.ADMINISTRATOR))],
)
planning_editors = require_roles(UserRole.ADMINISTRATOR)


def _require_postgres() -> None:
    if not uses_postgres():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="PCON requiere el repositorio PostgreSQL",
        )


@router.get("/plan", response_model=PCONPlanPageDTO)
async def list_monthly_plan(
    year: int = Query(ge=2000, le=2200),
    month: int = Query(ge=1, le=12),
    subsystem: str | None = None,
    q: str | None = None,
    session: AsyncSession = Depends(get_session),
) -> PCONPlanPageDTO:
    _require_postgres()
    items = await PostgresPlanningRepository(session).list_plan(
        year=year,
        month=month,
        subsystem=subsystem,
        query=q,
    )
    return PCONPlanPageDTO(items=items, total=len(items))


@router.get("/annual-plan", response_model=PCONAnnualPlanDTO)
async def list_annual_plan(
    year: int = Query(ge=2000, le=2200),
    subsystem: str | None = None,
    q: str | None = None,
    session: AsyncSession = Depends(get_session),
) -> PCONAnnualPlanDTO:
    _require_postgres()
    return await PostgresPlanningRepository(session).list_annual_plan(
        year=year,
        subsystem=subsystem,
        query=q,
    )


@router.put("/annual-plan/count", response_model=SetAnnualPlanCountResponse)
async def set_annual_plan_count(
    payload: SetAnnualPlanCountRequest,
    current_user: UserDTO = Depends(planning_editors),
    session: AsyncSession = Depends(get_session),
) -> SetAnnualPlanCountResponse:
    _require_postgres()
    repository = PostgresPlanningRepository(session)
    try:
        previous, created, removed = await repository.set_annual_count(
            scope_id=payload.maintenance_template_scope_id,
            year=payload.year,
            month=payload.month,
            target_count=payload.count,
            user_id=current_user.id,
        )
        await session.commit()
        return SetAnnualPlanCountResponse(
            previous_count=previous,
            count=payload.count,
            created=created,
            removed=removed,
        )
    except PlanningNotFoundError as error:
        await session.rollback()
        raise HTTPException(status_code=404, detail=str(error)) from error
    except PlanningValidationError as error:
        await session.rollback()
        raise HTTPException(status_code=422, detail=str(error)) from error


@router.post("/annual-plan/copy", response_model=CopyAnnualPlanResponse)
async def copy_annual_plan(
    payload: CopyAnnualPlanRequest,
    current_user: UserDTO = Depends(planning_editors),
    session: AsyncSession = Depends(get_session),
) -> CopyAnnualPlanResponse:
    _require_postgres()
    repository = PostgresPlanningRepository(session)
    try:
        result = await repository.copy_annual_plan(
            source_year=payload.source_year,
            target_year=payload.target_year,
            user_id=current_user.id,
        )
        await session.commit()
        return result
    except PlanningNotFoundError as error:
        await session.rollback()
        raise HTTPException(status_code=404, detail=str(error)) from error
    except PlanningValidationError as error:
        await session.rollback()
        raise HTTPException(status_code=422, detail=str(error)) from error


@router.get("/catalog", response_model=PCONCatalogDTO)
async def get_pcon_catalog(
    session: AsyncSession = Depends(get_session),
) -> PCONCatalogDTO:
    _require_postgres()
    return await PostgresPlanningRepository(session).get_catalog()


@router.post("/plan-scopes", response_model=AddPlanScopeResponse)
async def add_plan_scope(
    payload: AddPlanScopeRequest,
    current_user: UserDTO = Depends(planning_editors),
    session: AsyncSession = Depends(get_session),
) -> AddPlanScopeResponse:
    _require_postgres()
    repository = PostgresPlanningRepository(session)
    try:
        result = await repository.add_plan_scope(
            year=payload.year,
            asset_id=payload.asset_id,
            template_id=payload.maintenance_template_id,
            month=payload.month,
            quantity=payload.quantity,
            user_id=current_user.id,
            reason=payload.reason,
        )
        await session.commit()
        return result
    except PlanningNotFoundError as error:
        await session.rollback()
        raise HTTPException(status_code=404, detail=str(error)) from error
    except PlanningValidationError as error:
        await session.rollback()
        raise HTTPException(status_code=422, detail=str(error)) from error


@router.post("/occurrences")
async def create_occurrences(
    payload: CreateOccurrencesRequest,
    current_user: UserDTO = Depends(planning_editors),
    session: AsyncSession = Depends(get_session),
) -> dict[str, int]:
    _require_postgres()
    repository = PostgresPlanningRepository(session)
    try:
        created = await repository.create_occurrences(
            scope_id=payload.maintenance_template_scope_id,
            year=payload.year,
            month=payload.month,
            quantity=payload.quantity,
            user_id=current_user.id,
            reason=payload.reason,
        )
        await session.commit()
        return {"created": created}
    except PlanningNotFoundError as error:
        await session.rollback()
        raise HTTPException(status_code=404, detail=str(error)) from error
    except PlanningValidationError as error:
        await session.rollback()
        raise HTTPException(status_code=422, detail=str(error)) from error


@router.patch("/occurrences/{plan_entry_id}")
async def move_occurrence(
    plan_entry_id: UUID,
    payload: MoveOccurrenceRequest,
    current_user: UserDTO = Depends(planning_editors),
    session: AsyncSession = Depends(get_session),
) -> dict[str, bool]:
    _require_postgres()
    repository = PostgresPlanningRepository(session)
    try:
        await repository.move_occurrence(
            plan_entry_id=plan_entry_id,
            year=payload.year,
            month=payload.month,
            user_id=current_user.id,
            reason=payload.reason,
        )
        await session.commit()
        return {"updated": True}
    except PlanningNotFoundError as error:
        await session.rollback()
        raise HTTPException(status_code=404, detail=str(error)) from error
    except PlanningValidationError as error:
        await session.rollback()
        raise HTTPException(status_code=422, detail=str(error)) from error


@router.delete(
    "/occurrences/{plan_entry_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def remove_occurrence(
    plan_entry_id: UUID,
    current_user: UserDTO = Depends(planning_editors),
    session: AsyncSession = Depends(get_session),
) -> Response:
    _require_postgres()
    repository = PostgresPlanningRepository(session)
    try:
        await repository.remove_occurrence(
            plan_entry_id=plan_entry_id,
            user_id=current_user.id,
            reason="Eliminado del plan anual",
            allow_confirmed_future=False,
        )
        await session.commit()
        return Response(status_code=status.HTTP_204_NO_CONTENT)
    except PlanningNotFoundError as error:
        await session.rollback()
        raise HTTPException(status_code=404, detail=str(error)) from error
    except PlanningValidationError as error:
        await session.rollback()
        raise HTTPException(status_code=422, detail=str(error)) from error


@router.post("/occurrences/{plan_entry_id}/cancel")
async def cancel_occurrence(
    plan_entry_id: UUID,
    payload: CancelOccurrenceRequest,
    current_user: UserDTO = Depends(planning_editors),
    session: AsyncSession = Depends(get_session),
) -> dict[str, bool]:
    _require_postgres()
    repository = PostgresPlanningRepository(session)
    try:
        await repository.remove_occurrence(
            plan_entry_id=plan_entry_id,
            user_id=current_user.id,
            reason=payload.reason,
            allow_confirmed_future=True,
        )
        await session.commit()
        return {"cancelled": True}
    except PlanningNotFoundError as error:
        await session.rollback()
        raise HTTPException(status_code=404, detail=str(error)) from error
    except PlanningValidationError as error:
        await session.rollback()
        raise HTTPException(status_code=422, detail=str(error)) from error


@router.get("/change-history", response_model=list[PCONPlanChangeDTO])
async def get_plan_change_history(
    year: int = Query(ge=2000, le=2200),
    limit: int = Query(default=200, ge=1, le=500),
    session: AsyncSession = Depends(get_session),
) -> list[PCONPlanChangeDTO]:
    _require_postgres()
    return await PostgresPlanningRepository(session).list_plan_changes(
        year=year,
        limit=limit,
    )


@router.put("/plan/month")
async def assign_month(
    payload: AssignPlanMonthRequest,
    _: UserDTO = Depends(planning_editors),
    session: AsyncSession = Depends(get_session),
) -> dict[str, int]:
    _require_postgres()
    repository = PostgresPlanningRepository(session)
    try:
        updated = await repository.assign_month(
            plan_entry_ids=payload.plan_entry_ids,
            year=payload.year,
            month=payload.month,
        )
        await session.commit()
        return {"updated": updated}
    except (PlanningValidationError, PlanningNotFoundError) as error:
        await session.rollback()
        raise HTTPException(status_code=422, detail=str(error)) from error


@router.post("/weeks/{week_start}/sessions", response_model=WeeklyPlanningDetailDTO)
async def create_or_resume_week(
    week_start: date,
    payload: CreateWeeklySessionRequest,
    current_user: UserDTO = Depends(planning_editors),
    session: AsyncSession = Depends(get_session),
) -> WeeklyPlanningDetailDTO:
    _require_postgres()
    repository = PostgresPlanningRepository(session)
    detail = await repository.get_or_create_draft(
        week_start=week_start,
        user_id=current_user.id,
        notes=payload.notes,
    )
    await session.commit()
    return detail


@router.get("/weeks/{week_start}/current", response_model=WeeklyPlanningDetailDTO)
async def get_current_week(
    week_start: date,
    session: AsyncSession = Depends(get_session),
) -> WeeklyPlanningDetailDTO:
    _require_postgres()
    try:
        return await PostgresPlanningRepository(session).get_current_week(week_start)
    except PlanningNotFoundError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error


@router.get("/sessions/{session_id}", response_model=WeeklyPlanningDetailDTO)
async def get_week_session(
    session_id: UUID,
    session: AsyncSession = Depends(get_session),
) -> WeeklyPlanningDetailDTO:
    _require_postgres()
    try:
        return await PostgresPlanningRepository(session).get_session_detail(session_id)
    except PlanningNotFoundError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error


@router.put(
    "/sessions/{session_id}/proposals/{activity_id}",
    response_model=WeeklyPlanningDetailDTO,
)
async def upsert_proposal(
    session_id: UUID,
    activity_id: UUID,
    payload: ScheduleProposalRequest,
    current_user: UserDTO = Depends(planning_editors),
    session: AsyncSession = Depends(get_session),
) -> WeeklyPlanningDetailDTO:
    _require_postgres()
    repository = PostgresPlanningRepository(session)
    try:
        detail = await repository.upsert_proposal(
            session_id=session_id,
            activity_id=activity_id,
            payload=payload,
            user_id=current_user.id,
        )
        await session.commit()
        return detail
    except PlanningNotFoundError as error:
        await session.rollback()
        raise HTTPException(status_code=404, detail=str(error)) from error
    except PlanningValidationError as error:
        await session.rollback()
        raise HTTPException(status_code=422, detail=str(error)) from error


@router.delete(
    "/sessions/{session_id}/proposals/{activity_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_proposal(
    session_id: UUID,
    activity_id: UUID,
    _: UserDTO = Depends(planning_editors),
    session: AsyncSession = Depends(get_session),
) -> Response:
    _require_postgres()
    repository = PostgresPlanningRepository(session)
    try:
        await repository.delete_proposal(
            session_id=session_id,
            activity_id=activity_id,
        )
        await session.commit()
        return Response(status_code=status.HTTP_204_NO_CONTENT)
    except PlanningNotFoundError as error:
        await session.rollback()
        raise HTTPException(status_code=404, detail=str(error)) from error
    except PlanningValidationError as error:
        await session.rollback()
        raise HTTPException(status_code=422, detail=str(error)) from error


@router.post(
    "/sessions/{session_id}/confirm",
    response_model=WeeklyPlanningDetailDTO,
)
async def confirm_week(
    session_id: UUID,
    current_user: UserDTO = Depends(planning_editors),
    session: AsyncSession = Depends(get_session),
) -> WeeklyPlanningDetailDTO:
    _require_postgres()
    repository = PostgresPlanningRepository(session)
    try:
        detail = await repository.confirm_week(
            session_id=session_id,
            user_id=current_user.id,
        )
        await session.commit()
        return detail
    except PlanningNotFoundError as error:
        await session.rollback()
        raise HTTPException(status_code=404, detail=str(error)) from error
    except PlanningValidationError as error:
        await session.rollback()
        raise HTTPException(status_code=422, detail=str(error)) from error


@router.get("/history", response_model=list[PlanningHistoryItemDTO])
async def list_planning_history(
    limit: int = Query(default=100, ge=1, le=500),
    session: AsyncSession = Depends(get_session),
) -> list[PlanningHistoryItemDTO]:
    _require_postgres()
    return await PostgresPlanningRepository(session).list_history(limit)
