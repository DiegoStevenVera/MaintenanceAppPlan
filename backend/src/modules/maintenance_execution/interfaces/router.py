from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session, uses_postgres
from modules.identity_access.interfaces.schemas import UserDTO
from modules.maintenance_execution.application.lifecycle import (
    InvalidMaintenanceTransitionError,
    MaintenanceLifecycleCommand,
    MaintenanceLifecyclePermissionError,
)
from modules.identity_access.interfaces.dependencies import get_current_user, require_roles
from modules.maintenance_execution.infrastructure.postgres.repository import (
    PostgresMaintenanceRepository,
)
from modules.maintenance_execution.infrastructure.postgres.report_writer import (
    PostgresReportWriter,
    ReportNotEditableError,
    ReportValidationError,
)
from modules.maintenance_execution.infrastructure.pdf_service import (
    CalibrationPDFService,
    CorrectivePDFService,
    PreventivePDFService,
)
from modules.maintenance_execution.infrastructure.seed_repository import maintenance_repository
from modules.maintenance_execution.interfaces.schemas import (
    CorrectiveEventDTO,
    CorrectiveTargetDTO,
    CorrectiveCreationContextDTO,
    CreateCorrectiveEventRequest,
    MaintenanceActivityDetailDTO,
    MaintenanceDashboardDTO,
    MaintenanceReportVersionDTO,
    MaintenanceReportVersionDetailDTO,
    GeneratedReportDTO,
    MaintenanceActivityDTO,
    MaintenanceCommentCreateRequest,
    MaintenanceCommentDTO,
    PreventiveGuideDTO,
    PreventiveScheduleDTO,
    ReportDraftWriteRequest,
    ReportEditorDTO,
    ReportWriteResultDTO,
    ReopenMaintenanceRequest,
)
from shared_kernel.schemas import MaintenanceStatus, Page, UserRole

router = APIRouter(tags=["maintenance"], dependencies=[Depends(get_current_user)])

operational_roles = require_roles(
    UserRole.MAINTENANCE_ENGINEER,
    UserRole.COORDINATOR,
    UserRole.ADMINISTRATOR,
)
comment_roles = require_roles(
    UserRole.MAINTENANCE_ENGINEER,
    UserRole.COORDINATOR,
    UserRole.BOSS,
    UserRole.ADMINISTRATOR,
)
closure_roles = require_roles(
    UserRole.COORDINATOR,
    UserRole.ADMINISTRATOR,
)


@router.get("/maintenance-activities", response_model=Page[MaintenanceActivityDTO])
async def list_maintenance_activities(
    activity_type: str | None = None,
    status: MaintenanceStatus | None = None,
    subsystem: str | None = None,
    q: str | None = None,
    date_from: datetime | None = None,
    date_to: datetime | None = None,
    planned_year: int | None = Query(default=None, ge=2000, le=2200),
    planned_month: int | None = Query(default=None, ge=1, le=12),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    session: AsyncSession = Depends(get_session),
) -> Page[MaintenanceActivityDTO]:
    if uses_postgres():
        items, total = await PostgresMaintenanceRepository(session).list_activities(
            activity_type=activity_type,
            status=status,
            subsystem=subsystem,
            q=q,
            date_from=date_from,
            date_to=date_to,
            planned_year=planned_year,
            planned_month=planned_month,
            limit=limit,
            offset=offset,
        )
        return Page(items=items, total=total, limit=limit, offset=offset)
    return Page(items=[], total=0, limit=limit, offset=offset)


@router.get("/maintenance-dashboard", response_model=MaintenanceDashboardDTO)
async def get_maintenance_dashboard(
    day_from: datetime,
    day_to: datetime,
    session: AsyncSession = Depends(get_session),
) -> MaintenanceDashboardDTO:
    if not uses_postgres():
        return MaintenanceDashboardDTO()
    if day_to <= day_from:
        raise HTTPException(status_code=422, detail="day_to must be after day_from")
    return await PostgresMaintenanceRepository(session).get_dashboard(
        day_from=day_from,
        day_to=day_to,
    )


@router.get(
    "/maintenance-activities/{activity_id}",
    response_model=MaintenanceActivityDetailDTO,
)
async def get_maintenance_activity(
    activity_id: str,
    session: AsyncSession = Depends(get_session),
) -> MaintenanceActivityDetailDTO:
    if not uses_postgres():
        raise HTTPException(status_code=404, detail="Maintenance activity not found")
    activity = await PostgresMaintenanceRepository(session).get_activity(activity_id)
    if activity is None:
        raise HTTPException(status_code=404, detail="Maintenance activity not found")
    return activity


@router.get(
    "/maintenance-activities/{activity_id}/reports",
    response_model=list[MaintenanceReportVersionDTO],
)
async def list_maintenance_activity_reports(
    activity_id: str,
    session: AsyncSession = Depends(get_session),
) -> list[MaintenanceReportVersionDTO]:
    if not uses_postgres():
        raise HTTPException(status_code=404, detail="Maintenance activity not found")
    repository = PostgresMaintenanceRepository(session)
    if await repository.get_activity(activity_id) is None:
        raise HTTPException(status_code=404, detail="Maintenance activity not found")
    return await repository.list_activity_reports(activity_id)


@router.get(
    "/report-versions/{version_id}",
    response_model=MaintenanceReportVersionDetailDTO,
)
async def get_report_version_detail(
    version_id: str,
    session: AsyncSession = Depends(get_session),
) -> MaintenanceReportVersionDetailDTO:
    if not uses_postgres():
        raise HTTPException(status_code=404, detail="Report version not found")
    detail = await PostgresReportWriter(session).get_version_detail(version_id)
    if detail is None:
        raise HTTPException(status_code=404, detail="Report version not found")
    return detail


@router.post(
    "/report-versions/{version_id}/generate-pdf",
    response_model=GeneratedReportDTO,
)
async def generate_report_pdf(
    version_id: str,
    current_user: UserDTO = Depends(operational_roles),
    session: AsyncSession = Depends(get_session),
) -> GeneratedReportDTO:
    if not uses_postgres():
        raise HTTPException(status_code=404, detail="Report version not found")
    try:
        detail = await PostgresReportWriter(session).get_version_detail(version_id)
        if detail is None:
            raise HTTPException(status_code=404, detail="Report version not found")
        if detail.report_kind == "CORRECTIVE":
            pdf_service = CorrectivePDFService(session)
        elif detail.report_kind == "CALIBRATION":
            pdf_service = CalibrationPDFService(session)
        else:
            pdf_service = PreventivePDFService(session)
        report = await pdf_service.generate(
            version_id=version_id,
            user_id=current_user.id,
        )
        await session.commit()
        return report
    except ReportValidationError as error:
        await session.rollback()
        raise HTTPException(status_code=422, detail=str(error)) from error
    except (OSError, ValueError) as error:
        await session.rollback()
        raise HTTPException(status_code=500, detail=f"No se pudo generar el PDF: {error}") from error


@router.get("/report-versions/{version_id}/pdf")
async def download_report_pdf(
    version_id: str,
    session: AsyncSession = Depends(get_session),
) -> FileResponse:
    if not uses_postgres():
        raise HTTPException(status_code=404, detail="PDF not found")
    result = await PreventivePDFService(session).file_path(version_id)
    if result is None:
        raise HTTPException(
            status_code=404,
            detail="Todavía no se ha generado el PDF para esta versión.",
        )
    path, file_name = result
    return FileResponse(path, media_type="application/pdf", filename=file_name)


@router.get(
    "/maintenance-activities/{activity_id}/report-editor",
    response_model=ReportEditorDTO,
)
async def get_report_editor(
    activity_id: str,
    session: AsyncSession = Depends(get_session),
) -> ReportEditorDTO:
    if not uses_postgres():
        raise HTTPException(status_code=404, detail="Maintenance activity not found")
    editor = await PostgresReportWriter(session).get_editor(activity_id)
    if editor is None:
        raise HTTPException(status_code=404, detail="Maintenance activity not found")
    return editor


@router.get(
    "/maintenance-activities/{activity_id}/preventive-guide",
    response_model=PreventiveGuideDTO,
)
async def get_preventive_guide(
    activity_id: str,
    previous_reports_limit: int = Query(default=10, ge=1, le=50),
    previous_reports_offset: int = Query(default=0, ge=0),
    session: AsyncSession = Depends(get_session),
) -> PreventiveGuideDTO:
    if not uses_postgres():
        raise HTTPException(status_code=404, detail="Preventive activity not found")
    guide = await PostgresReportWriter(session).get_preventive_guide(
        activity_id,
        previous_reports_limit=previous_reports_limit,
        previous_reports_offset=previous_reports_offset,
    )
    if guide is None:
        raise HTTPException(status_code=404, detail="Preventive activity not found")
    return guide


async def _write_report(
    *,
    activity_id: str,
    payload: ReportDraftWriteRequest,
    current_user: UserDTO,
    session: AsyncSession,
    finalize: bool,
) -> ReportWriteResultDTO:
    if not uses_postgres():
        raise HTTPException(status_code=404, detail="Maintenance activity not found")
    try:
        result = await PostgresReportWriter(session).save(
            activity_id=activity_id,
            payload=payload,
            user_id=current_user.id,
            finalize=finalize,
        )
        await session.commit()
        return result
    except ReportNotEditableError as error:
        await session.rollback()
        raise HTTPException(status_code=409, detail=str(error)) from error
    except (ReportValidationError, ValueError) as error:
        await session.rollback()
        raise HTTPException(status_code=422, detail=str(error)) from error


@router.put(
    "/maintenance-activities/{activity_id}/report-draft",
    response_model=ReportWriteResultDTO,
)
async def save_report_draft(
    activity_id: str,
    payload: ReportDraftWriteRequest,
    current_user: UserDTO = Depends(operational_roles),
    session: AsyncSession = Depends(get_session),
) -> ReportWriteResultDTO:
    return await _write_report(
        activity_id=activity_id,
        payload=payload,
        current_user=current_user,
        session=session,
        finalize=False,
    )


@router.post(
    "/maintenance-activities/{activity_id}/report-finalize",
    response_model=ReportWriteResultDTO,
)
async def finalize_report(
    activity_id: str,
    payload: ReportDraftWriteRequest,
    current_user: UserDTO = Depends(operational_roles),
    session: AsyncSession = Depends(get_session),
) -> ReportWriteResultDTO:
    return await _write_report(
        activity_id=activity_id,
        payload=payload,
        current_user=current_user,
        session=session,
        finalize=True,
    )


@router.get(
    "/maintenance-activities/{activity_id}/comments",
    response_model=list[MaintenanceCommentDTO],
)
async def list_maintenance_comments(
    activity_id: str,
    session: AsyncSession = Depends(get_session),
) -> list[MaintenanceCommentDTO]:
    writer = PostgresReportWriter(session)
    editor = await writer.get_editor(activity_id)
    if editor is None:
        raise HTTPException(status_code=404, detail="Maintenance activity not found")
    return editor.comments


@router.post(
    "/maintenance-activities/{activity_id}/comments",
    response_model=MaintenanceCommentDTO,
)
async def add_maintenance_comment(
    activity_id: str,
    payload: MaintenanceCommentCreateRequest,
    current_user: UserDTO = Depends(comment_roles),
    session: AsyncSession = Depends(get_session),
) -> MaintenanceCommentDTO:
    try:
        comment = await PostgresReportWriter(session).add_comment(
            activity_id=activity_id,
            user_id=current_user.id,
            message=payload.message,
        )
        await session.commit()
        return comment
    except ReportValidationError as error:
        await session.rollback()
        raise HTTPException(status_code=422, detail=str(error)) from error


@router.get("/attachments/{attachment_id}/content")
async def get_attachment_content(
    attachment_id: str,
    session: AsyncSession = Depends(get_session),
) -> FileResponse:
    path = await PostgresReportWriter(session).attachment_path(attachment_id)
    if path is None:
        raise HTTPException(status_code=404, detail="Attachment not found")
    return FileResponse(path)


async def _transition_maintenance_activity(
    *,
    activity_id: str,
    command: MaintenanceLifecycleCommand,
    current_user: UserDTO,
    session: AsyncSession,
    reason: str | None = None,
) -> MaintenanceActivityDetailDTO:
    if not uses_postgres():
        raise HTTPException(status_code=404, detail="Maintenance activity not found")
    repository = PostgresMaintenanceRepository(session)
    try:
        if command == MaintenanceLifecycleCommand.COMPLETE:
            await PostgresReportWriter(session).ensure_finalized_report(
                activity_id=activity_id
            )
        found = await repository.transition_activity(
            activity_id=activity_id,
            command=command,
            user_id=current_user.id,
            user_role=current_user.role,
            reason=reason,
        )
        if found and command == MaintenanceLifecycleCommand.COMPLETE:
            await PostgresReportWriter(
                session
            ).apply_finalized_component_replacements(
                activity_id=activity_id,
                user_id=current_user.id,
            )
        if found and command in {
            MaintenanceLifecycleCommand.CLOSE,
            MaintenanceLifecycleCommand.REOPEN,
        }:
            await PostgresReportWriter(session).record_lifecycle_audit_event(
                activity_id=activity_id,
                event_type=(
                    "MAINTENANCE_CLOSED"
                    if command == MaintenanceLifecycleCommand.CLOSE
                    else "MAINTENANCE_REOPENED"
                ),
                actor_user_id=current_user.id,
                reason=reason,
            )
    except MaintenanceLifecyclePermissionError as error:
        await session.rollback()
        raise HTTPException(status_code=403, detail=str(error)) from error
    except InvalidMaintenanceTransitionError as error:
        await session.rollback()
        raise HTTPException(status_code=409, detail=str(error)) from error
    except ReportValidationError as error:
        await session.rollback()
        raise HTTPException(status_code=422, detail=str(error)) from error
    if not found:
        await session.rollback()
        raise HTTPException(status_code=404, detail="Maintenance activity not found")

    await session.commit()
    detail = await repository.get_activity(activity_id)
    if detail is None:
        raise HTTPException(status_code=404, detail="Maintenance activity not found")
    return detail


@router.post(
    "/maintenance-activities/{activity_id}/start",
    response_model=MaintenanceActivityDetailDTO,
)
async def start_maintenance_activity(
    activity_id: str,
    current_user: UserDTO = Depends(operational_roles),
    session: AsyncSession = Depends(get_session),
) -> MaintenanceActivityDetailDTO:
    return await _transition_maintenance_activity(
        activity_id=activity_id,
        command=MaintenanceLifecycleCommand.START,
        current_user=current_user,
        session=session,
    )


@router.post(
    "/maintenance-activities/{activity_id}/complete",
    response_model=MaintenanceActivityDetailDTO,
)
async def complete_maintenance_activity(
    activity_id: str,
    current_user: UserDTO = Depends(operational_roles),
    session: AsyncSession = Depends(get_session),
) -> MaintenanceActivityDetailDTO:
    return await _transition_maintenance_activity(
        activity_id=activity_id,
        command=MaintenanceLifecycleCommand.COMPLETE,
        current_user=current_user,
        session=session,
    )


@router.post(
    "/maintenance-activities/{activity_id}/close",
    response_model=MaintenanceActivityDetailDTO,
)
async def close_maintenance_activity(
    activity_id: str,
    current_user: UserDTO = Depends(closure_roles),
    session: AsyncSession = Depends(get_session),
) -> MaintenanceActivityDetailDTO:
    return await _transition_maintenance_activity(
        activity_id=activity_id,
        command=MaintenanceLifecycleCommand.CLOSE,
        current_user=current_user,
        session=session,
    )


@router.post(
    "/maintenance-activities/{activity_id}/reopen",
    response_model=MaintenanceActivityDetailDTO,
)
async def reopen_maintenance_activity(
    activity_id: str,
    payload: ReopenMaintenanceRequest,
    current_user: UserDTO = Depends(operational_roles),
    session: AsyncSession = Depends(get_session),
) -> MaintenanceActivityDetailDTO:
    return await _transition_maintenance_activity(
        activity_id=activity_id,
        command=MaintenanceLifecycleCommand.REOPEN,
        current_user=current_user,
        session=session,
        reason=payload.reason,
    )


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


@router.get(
    "/corrective-events/creation-context",
    response_model=CorrectiveCreationContextDTO,
)
async def get_corrective_creation_context(
    business_anchor_asset_id: str,
    session: AsyncSession = Depends(get_session),
) -> CorrectiveCreationContextDTO:
    if not uses_postgres():
        raise HTTPException(
            status_code=404,
            detail="Corrective creation context not found",
        )
    context = await PostgresMaintenanceRepository(
        session
    ).get_corrective_creation_context(business_anchor_asset_id)
    if context is None:
        raise HTTPException(
            status_code=404,
            detail="Corrective creation context not found",
        )
    return context


@router.get("/corrective-targets", response_model=list[CorrectiveTargetDTO])
async def list_corrective_targets(
    subsystem: str | None = None,
    session: AsyncSession = Depends(get_session),
) -> list[CorrectiveTargetDTO]:
    if not uses_postgres():
        return []
    return await PostgresMaintenanceRepository(session).list_corrective_targets(subsystem)


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
    current_user: UserDTO = Depends(
        require_roles(
            UserRole.MAINTENANCE_ENGINEER,
            UserRole.COORDINATOR,
            UserRole.ADMINISTRATOR,
        )
    ),
    session: AsyncSession = Depends(get_session),
) -> CorrectiveEventDTO:
    if uses_postgres():
        try:
            event = await PostgresMaintenanceRepository(
                session
            ).create_corrective_event(
                payload,
                user_id=current_user.id,
            )
            await session.commit()
            return event
        except ValueError as error:
            await session.rollback()
            raise HTTPException(status_code=422, detail=str(error)) from error
    return maintenance_repository.create_corrective_event(payload)
