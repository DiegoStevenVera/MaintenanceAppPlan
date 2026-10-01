from datetime import date, datetime, timedelta
from uuid import UUID
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import case, delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session, uses_postgres
from modules.identity_access.infrastructure.postgres.models import UserRecord
from modules.identity_access.interfaces.dependencies import get_current_user
from modules.identity_access.interfaces.schemas import UserDTO
from modules.organizational_context.infrastructure.postgres.models import WorkAreaRecord
from modules.workforce_scheduling.infrastructure.postgres.models import (
    EmployeeScheduleAuditRecord,
    EmployeeScheduleEntryRecord,
    ScheduleShiftTypeRecord,
    WorkAreaScheduleViewerRecord,
)
from modules.workforce_scheduling.interfaces.schemas import (
    CopyWeekRequest,
    ScheduleBulkUpdateRequest,
    ScheduleEntryDTO,
    ScheduleEntryUpdateRequest,
    ScheduleMemberDTO,
    ScheduleShiftTypeDTO,
    ScheduleWorkAreaDTO,
    WeeklyScheduleDTO,
)
from shared_kernel.schemas import UserRole

router = APIRouter(prefix="/schedules", tags=["schedules"])

LIMA_TIME_ZONE = ZoneInfo("America/Lima")
SCHEDULE_MEMBER_ROLES = (
    UserRole.MAINTENANCE_ENGINEER.value,
    UserRole.COORDINATOR.value,
    UserRole.ADMINISTRATOR.value,
)


@router.get("/work-areas", response_model=list[ScheduleWorkAreaDTO])
async def list_schedule_work_areas(
    current_user: UserDTO = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[ScheduleWorkAreaDTO]:
    _require_postgres()
    user = await _current_user_record(session, current_user.id)
    areas = await _accessible_work_areas(session, user)
    return [
        ScheduleWorkAreaDTO(
            id=area.id,
            name=area.name,
            can_edit=_can_edit_area(user, area.id),
        )
        for area in areas
    ]


@router.get("/week", response_model=WeeklyScheduleDTO)
async def get_weekly_schedule(
    week_start: date = Query(),
    work_area_id: UUID | None = Query(default=None),
    current_user: UserDTO = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> WeeklyScheduleDTO:
    _require_postgres()
    _require_monday(week_start)
    user = await _current_user_record(session, current_user.id)
    area = await _resolve_accessible_area(session, user, work_area_id)
    return await _weekly_schedule(session, user, area, week_start)


@router.put(
    "/entries/{target_user_id}/{work_date}",
    response_model=WeeklyScheduleDTO,
)
async def update_schedule_entry(
    target_user_id: str,
    work_date: date,
    payload: ScheduleEntryUpdateRequest,
    current_user: UserDTO = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> WeeklyScheduleDTO:
    _require_postgres()
    actor = await _current_user_record(session, current_user.id)
    target = await _schedule_member(session, target_user_id)
    _require_edit_access(actor, target.work_area_id, work_date, payload.reason)

    shift = None
    if payload.shift_code is not None:
        shift = await session.scalar(
            select(ScheduleShiftTypeRecord).where(
                ScheduleShiftTypeRecord.code == payload.shift_code,
                ScheduleShiftTypeRecord.is_active.is_(True),
            )
        )
        if shift is None:
            raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "Turno no valido")

    week_start = work_date - timedelta(days=work_date.weekday())
    dates = _target_dates(work_date, payload.shift_code, payload.apply_scope)
    scope = "WEEK" if len(dates) > 1 else "DAY"
    for target_date in dates:
        _require_edit_access(actor, target.work_area_id, target_date, payload.reason)
        await _write_entry(
            session,
            actor=actor,
            target=target,
            work_date=target_date,
            shift_code=payload.shift_code,
            scope=scope,
            reason=payload.reason,
        )
    await session.commit()

    area = await session.get(WorkAreaRecord, target.work_area_id)
    if area is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Area de trabajo no encontrada")
    return await _weekly_schedule(session, actor, area, week_start)


@router.post("/copy-week", response_model=WeeklyScheduleDTO)
async def copy_schedule_week(
    payload: CopyWeekRequest,
    current_user: UserDTO = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> WeeklyScheduleDTO:
    _require_postgres()
    _require_monday(payload.source_week_start)
    _require_monday(payload.target_week_start)
    actor = await _current_user_record(session, current_user.id)
    area = await _resolve_accessible_area(session, actor, payload.work_area_id)
    _require_edit_access(actor, area.id, payload.target_week_start, payload.reason)

    target_end = payload.target_week_start + timedelta(days=6)
    if payload.overwrite:
        existing_targets = (
            await session.scalars(
                select(EmployeeScheduleEntryRecord).where(
                    EmployeeScheduleEntryRecord.work_area_id == area.id,
                    EmployeeScheduleEntryRecord.work_date.between(
                        payload.target_week_start, target_end
                    ),
                )
            )
        ).all()
        for record in existing_targets:
            session.add(
                EmployeeScheduleAuditRecord(
                    target_user_id=record.user_id,
                    work_area_id=area.id,
                    work_date=record.work_date,
                    previous_shift_code=record.shift_code,
                    new_shift_code=None,
                    change_scope="COPY_WEEK",
                    changed_by_user_id=actor.id,
                    reason=payload.reason,
                )
            )
        await session.execute(
            delete(EmployeeScheduleEntryRecord).where(
                EmployeeScheduleEntryRecord.work_area_id == area.id,
                EmployeeScheduleEntryRecord.work_date.between(
                    payload.target_week_start, target_end
                ),
            )
        )

    source_end = payload.source_week_start + timedelta(days=6)
    source_entries = (
        await session.scalars(
            select(EmployeeScheduleEntryRecord).where(
                EmployeeScheduleEntryRecord.work_area_id == area.id,
                EmployeeScheduleEntryRecord.work_date.between(
                    payload.source_week_start, source_end
                ),
            )
        )
    ).all()
    valid_member_ids = set(
        await session.scalars(
            select(UserRecord.id).where(
                UserRecord.work_area_id == area.id,
                UserRecord.is_active.is_(True),
                UserRecord.appears_in_schedule.is_(True),
                UserRecord.role.in_(SCHEDULE_MEMBER_ROLES),
            )
        )
    )
    for source in source_entries:
        if source.user_id not in valid_member_ids:
            continue
        target_date = payload.target_week_start + timedelta(
            days=(source.work_date - payload.source_week_start).days
        )
        if not payload.overwrite:
            already_exists = await session.scalar(
                select(EmployeeScheduleEntryRecord.id).where(
                    EmployeeScheduleEntryRecord.user_id == source.user_id,
                    EmployeeScheduleEntryRecord.work_date == target_date,
                )
            )
            if already_exists is not None:
                continue
        session.add(
            EmployeeScheduleEntryRecord(
                user_id=source.user_id,
                work_area_id=area.id,
                work_date=target_date,
                shift_code=source.shift_code,
                updated_by_user_id=actor.id,
            )
        )
        session.add(
            EmployeeScheduleAuditRecord(
                target_user_id=source.user_id,
                work_area_id=area.id,
                work_date=target_date,
                previous_shift_code=None,
                new_shift_code=source.shift_code,
                change_scope="COPY_WEEK",
                changed_by_user_id=actor.id,
                reason=payload.reason,
            )
        )
    await session.commit()
    return await _weekly_schedule(session, actor, area, payload.target_week_start)


@router.post("/entries/bulk", response_model=WeeklyScheduleDTO)
async def bulk_update_schedule_entries(
    payload: ScheduleBulkUpdateRequest,
    current_user: UserDTO = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> WeeklyScheduleDTO:
    _require_postgres()
    actor = await _current_user_record(session, current_user.id)
    area = await _resolve_accessible_area(session, actor, payload.work_area_id)
    if not _can_edit_area(actor, area.id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No puedes editar este horario")

    shift_codes = {change.shift_code for change in payload.changes if change.shift_code}
    valid_shift_codes = set(
        await session.scalars(
            select(ScheduleShiftTypeRecord.code).where(
                ScheduleShiftTypeRecord.code.in_(shift_codes),
                ScheduleShiftTypeRecord.is_active.is_(True),
            )
        )
    )
    if shift_codes != valid_shift_codes:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "Turno no valido")

    member_ids = {change.user_id for change in payload.changes}
    members = {
        member.id: member
        for member in (
            await session.scalars(
                select(UserRecord).where(
                    UserRecord.id.in_(member_ids),
                    UserRecord.work_area_id == area.id,
                    UserRecord.is_active.is_(True),
                    UserRecord.appears_in_schedule.is_(True),
                    UserRecord.role.in_(SCHEDULE_MEMBER_ROLES),
                )
            )
        ).all()
    }
    if member_ids != set(members):
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "Uno de los trabajadores no pertenece al area seleccionada",
        )

    expanded_changes: dict[tuple[str, date], str | None] = {}
    for change in payload.changes:
        _require_edit_access(actor, area.id, change.work_date)
        for target_date in _target_dates(change.work_date, change.shift_code, "DAY"):
            _require_edit_access(actor, area.id, target_date)
            expanded_changes[(change.user_id, target_date)] = change.shift_code

    for (member_id, target_date), shift_code in expanded_changes.items():
        await _write_entry(
            session,
            actor=actor,
            target=members[member_id],
            work_date=target_date,
            shift_code=shift_code,
            scope="DRAG_FILL",
            reason=None,
        )
    await session.commit()

    first_date = min(change.work_date for change in payload.changes)
    week_start = first_date - timedelta(days=first_date.weekday())
    return await _weekly_schedule(session, actor, area, week_start)


async def _weekly_schedule(
    session: AsyncSession,
    user: UserRecord,
    area: WorkAreaRecord,
    week_start: date,
) -> WeeklyScheduleDTO:
    week_end = week_start + timedelta(days=6)
    members = (
        await session.scalars(
            select(UserRecord)
            .where(
                UserRecord.work_area_id == area.id,
                UserRecord.is_active.is_(True),
                UserRecord.appears_in_schedule.is_(True),
                UserRecord.role.in_(SCHEDULE_MEMBER_ROLES),
            )
            .order_by(UserRecord.name, UserRecord.id)
        )
    ).all()
    shift_types = (
        await session.scalars(
            select(ScheduleShiftTypeRecord)
            .where(ScheduleShiftTypeRecord.is_active.is_(True))
            .order_by(
                case(
                    (ScheduleShiftTypeRecord.code == "12M", 1),
                    (ScheduleShiftTypeRecord.code == "12N", 2),
                    (ScheduleShiftTypeRecord.code == "COO", 3),
                    (ScheduleShiftTypeRecord.code == "CBTC", 4),
                    (ScheduleShiftTypeRecord.code == "DISPO", 5),
                    (ScheduleShiftTypeRecord.code == "FER", 6),
                    else_=99,
                )
            )
        )
    ).all()
    entries = (
        await session.scalars(
            select(EmployeeScheduleEntryRecord)
            .where(
                EmployeeScheduleEntryRecord.work_area_id == area.id,
                EmployeeScheduleEntryRecord.work_date.between(week_start, week_end),
            )
            .order_by(EmployeeScheduleEntryRecord.work_date, EmployeeScheduleEntryRecord.user_id)
        )
    ).all()
    can_edit = _can_edit_area(user, area.id)
    return WeeklyScheduleDTO(
        work_area=ScheduleWorkAreaDTO(id=area.id, name=area.name, can_edit=can_edit),
        week_start=week_start,
        week_end=week_end,
        can_edit=can_edit,
        members=[
            ScheduleMemberDTO(
                id=member.id,
                name=member.name,
                role=member.role,
                role_label=member.role_label,
            )
            for member in members
        ],
        shift_types=[
            ScheduleShiftTypeDTO(
                code=item.code,
                name=item.name,
                description=item.description,
                starts_at=item.starts_at,
                ends_at=item.ends_at,
                color_hex=item.color_hex,
                applies_to_full_week=item.applies_to_full_week,
            )
            for item in shift_types
        ],
        entries=[
            ScheduleEntryDTO(
                id=item.id,
                user_id=item.user_id,
                work_date=item.work_date,
                shift_code=item.shift_code,
                updated_at=item.updated_at,
            )
            for item in entries
        ],
    )


async def _accessible_work_areas(
    session: AsyncSession, user: UserRecord
) -> list[WorkAreaRecord]:
    if user.role == UserRole.ADMINISTRATOR.value:
        query = select(WorkAreaRecord).where(WorkAreaRecord.is_active.is_(True))
    elif user.role == UserRole.BOSS.value:
        assigned_ids = select(WorkAreaScheduleViewerRecord.work_area_id).where(
            WorkAreaScheduleViewerRecord.user_id == user.id
        )
        filters = [WorkAreaRecord.id.in_(assigned_ids)]
        if user.work_area_id is not None:
            filters.append(WorkAreaRecord.id == user.work_area_id)
        from sqlalchemy import or_

        query = select(WorkAreaRecord).where(
            WorkAreaRecord.is_active.is_(True), or_(*filters)
        )
    elif user.work_area_id is not None:
        query = select(WorkAreaRecord).where(
            WorkAreaRecord.id == user.work_area_id,
            WorkAreaRecord.is_active.is_(True),
        )
    else:
        return []
    if user.work_area_id is not None:
        query = query.order_by(
            case((WorkAreaRecord.id == user.work_area_id, 0), else_=1),
            WorkAreaRecord.name,
        )
    else:
        query = query.order_by(WorkAreaRecord.name)
    return list((await session.scalars(query)).all())


async def _resolve_accessible_area(
    session: AsyncSession,
    user: UserRecord,
    requested_area_id: UUID | None,
) -> WorkAreaRecord:
    areas = await _accessible_work_areas(session, user)
    if not areas:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No tienes un area de horario asignada")
    if requested_area_id is None:
        return areas[0]
    area = next((item for item in areas if item.id == requested_area_id), None)
    if area is None:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No puedes consultar esta area")
    return area


async def _current_user_record(session: AsyncSession, user_id: str) -> UserRecord:
    user = await session.get(UserRecord, user_id)
    if user is None or not user.is_active:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Usuario no disponible")
    return user


async def _schedule_member(session: AsyncSession, user_id: str) -> UserRecord:
    user = await session.get(UserRecord, user_id)
    if (
        user is None
        or not user.is_active
        or not user.appears_in_schedule
        or user.work_area_id is None
        or user.role not in SCHEDULE_MEMBER_ROLES
    ):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Trabajador no encontrado en el horario")
    return user


def _can_edit_area(user: UserRecord, work_area_id: UUID) -> bool:
    return user.role == UserRole.ADMINISTRATOR.value or (
        user.role == UserRole.COORDINATOR.value and user.work_area_id == work_area_id
    )


def _target_dates(work_date: date, shift_code: str | None, apply_scope: str) -> list[date]:
    week_start = work_date - timedelta(days=work_date.weekday())
    if shift_code == "COO":
        return [week_start + timedelta(days=offset) for offset in range(5)]
    if shift_code == "CBTC" or apply_scope == "WEEK":
        return [week_start + timedelta(days=offset) for offset in range(7)]
    return [work_date]


def _require_edit_access(
    user: UserRecord,
    work_area_id: UUID,
    work_date: date,
    reason: str | None = None,
) -> None:
    if not _can_edit_area(user, work_area_id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No puedes editar este horario")
    today = datetime.now(LIMA_TIME_ZONE).date()
    if work_date < today and user.role != UserRole.ADMINISTRATOR.value:
        raise HTTPException(
            status.HTTP_403_FORBIDDEN,
            "Los horarios pasados solo pueden ser editados por un administrador",
        )


async def _write_entry(
    session: AsyncSession,
    *,
    actor: UserRecord,
    target: UserRecord,
    work_date: date,
    shift_code: str | None,
    scope: str,
    reason: str | None,
) -> None:
    existing = await session.scalar(
        select(EmployeeScheduleEntryRecord)
        .where(
            EmployeeScheduleEntryRecord.user_id == target.id,
            EmployeeScheduleEntryRecord.work_date == work_date,
        )
        .with_for_update()
    )
    previous = existing.shift_code if existing else None
    if previous == shift_code:
        return
    if shift_code is None:
        if existing is not None:
            await session.delete(existing)
    elif existing is None:
        session.add(
            EmployeeScheduleEntryRecord(
                user_id=target.id,
                work_area_id=target.work_area_id,
                work_date=work_date,
                shift_code=shift_code,
                updated_by_user_id=actor.id,
            )
        )
    else:
        existing.shift_code = shift_code
        existing.work_area_id = target.work_area_id
        existing.updated_by_user_id = actor.id
    session.add(
        EmployeeScheduleAuditRecord(
            target_user_id=target.id,
            work_area_id=target.work_area_id,
            work_date=work_date,
            previous_shift_code=previous,
            new_shift_code=shift_code,
            change_scope=scope,
            changed_by_user_id=actor.id,
            reason=(reason or "").strip() or None,
        )
    )


def _require_monday(value: date) -> None:
    if value.weekday() != 0:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "La semana debe iniciar un lunes",
        )


def _require_postgres() -> None:
    if not uses_postgres():
        raise HTTPException(
            status.HTTP_501_NOT_IMPLEMENTED,
            "La gestion de horarios requiere PostgreSQL",
        )
