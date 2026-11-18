from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import FileResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session, uses_postgres
from modules.identity_access.interfaces.dependencies import get_current_user
from modules.maintenance_execution.infrastructure.postgres.report_models import AttachmentRecord, MaintenanceReportRecord, ReportVersionRecord
from modules.maintenance_execution.infrastructure.postgres.report_writer import PostgresReportWriter
from modules.maintenance_execution.infrastructure.postgres.solution_cases import SolutionCaseRepository

router = APIRouter(prefix="/corrective-solutions", tags=["corrective-solutions"], dependencies=[Depends(get_current_user)])


@router.get("/search")
async def search_solutions(
    q: str = Query(default="", max_length=1000), subsystem: str | None = None,
    asset_id: str | None = None, similar_to: str | None = None,
    include_provisional: bool = True, limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0), session: AsyncSession = Depends(get_session),
):
    if not uses_postgres():
        return {"items": [], "total": 0, "limit": limit, "offset": offset, "query": q,
            "engine": "textual_contextual", "context_only": not q.strip(), "updated_at": "",
            "subsystems": [], "assets": []}
    try:
        return await SolutionCaseRepository(session).search(query=q, subsystem=subsystem, asset_id=asset_id,
            similar_to=similar_to, include_provisional=include_provisional, limit=limit, offset=offset)
    except ValueError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error


@router.get("/bundle")
async def solution_bundle(
    subsystem: str | None = None, asset_id: str | None = None,
    revision: str | None = Query(default=None, max_length=64),
    limit: int = Query(default=50, ge=1, le=100), offset: int = Query(default=0, ge=0),
    session: AsyncSession = Depends(get_session),
):
    if not subsystem and not asset_id:
        raise HTTPException(status_code=422, detail="Selecciona un equipo o subsistema para descargar antecedentes.")
    if not uses_postgres():
        raise HTTPException(status_code=501, detail="La descarga requiere PostgreSQL.")
    try:
        return await SolutionCaseRepository(session).search(subsystem=subsystem, asset_id=asset_id,
            limit=limit, offset=offset, bundle=True, revision=revision)
    except ValueError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error


@router.get("/cases/{event_id}")
async def solution_case(event_id: str, session: AsyncSession = Depends(get_session)):
    if uses_postgres():
        case = next((c for c in await SolutionCaseRepository(session).all_cases()
                     if c["id"] == event_id or c["activity_id"] == event_id), None)
        if case:
            return case
    raise HTTPException(status_code=404, detail="Antecedente no encontrado.")


@router.get("/evidence/{attachment_id}")
async def solution_evidence(attachment_id: UUID, session: AsyncSession = Depends(get_session)):
    if not uses_postgres():
        raise HTTPException(status_code=404, detail="Evidencia no encontrada.")
    allowed = await session.scalar(select(AttachmentRecord.id)
        .join(ReportVersionRecord, ReportVersionRecord.id == AttachmentRecord.report_version_id)
        .join(MaintenanceReportRecord, MaintenanceReportRecord.id == ReportVersionRecord.maintenance_report_id)
        .where(AttachmentRecord.id == attachment_id, MaintenanceReportRecord.report_kind == "CORRECTIVE"))
    path = await PostgresReportWriter(session).attachment_path(str(attachment_id)) if allowed else None
    if path is None:
        raise HTTPException(status_code=404, detail="Evidencia no encontrada.")
    return FileResponse(path)
