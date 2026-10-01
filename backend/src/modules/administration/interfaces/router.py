from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session, uses_postgres
from modules.administration.interfaces.schemas import (
    AdministrationBootstrapDTO,
    ManagedUserDTO,
    ProjectDTO,
    ProjectWriteRequest,
    SiteOptionDTO,
    SiteWriteRequest,
    StageDTO,
    StageWriteRequest,
    SubsystemDTO,
    SubsystemWriteRequest,
    SystemDTO,
    SystemWriteRequest,
    UserWriteRequest,
    WorkAreaDTO,
    WorkAreaWriteRequest,
)
from modules.identity_access.application.security import hash_password
from modules.identity_access.infrastructure.postgres.models import (
    RefreshSessionRecord,
    UserRecord,
)
from modules.identity_access.interfaces.dependencies import require_roles
from modules.identity_access.interfaces.schemas import UserDTO
from modules.organizational_context.infrastructure.postgres.models import (
    ProjectRecord,
    SiteRecord,
    StageRecord,
    SubsystemRecord,
    SystemRecord,
    WorkAreaRecord,
)
from modules.workforce_scheduling.infrastructure.postgres.models import (
    WorkAreaScheduleViewerRecord,
)
from shared_kernel.schemas import UserRole


router = APIRouter(
    prefix="/administration",
    tags=["administration"],
    dependencies=[Depends(require_roles(UserRole.ADMINISTRATOR))],
)


def _require_postgres() -> None:
    if not uses_postgres():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="La administracion requiere PostgreSQL.",
        )


def _clean_optional(value: str | None) -> str | None:
    if value is None:
        return None
    normalized = value.strip()
    return normalized or None


async def _active_area(
    session: AsyncSession, area_id: UUID | None
) -> WorkAreaRecord | None:
    if area_id is None:
        return None
    area = await session.get(WorkAreaRecord, area_id)
    if area is None or not area.is_active:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT, "Area de trabajo no valida."
        )
    return area


async def _supervised_areas(
    session: AsyncSession, area_ids: list[UUID]
) -> list[WorkAreaRecord]:
    unique_ids = set(area_ids)
    if not unique_ids:
        return []
    areas = list(
        (
            await session.scalars(
                select(WorkAreaRecord).where(
                    WorkAreaRecord.id.in_(unique_ids),
                    WorkAreaRecord.is_active.is_(True),
                )
            )
        ).all()
    )
    if len(areas) != len(unique_ids):
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "Una de las areas supervisadas no existe o esta inactiva.",
        )
    return areas


async def _replace_supervised_areas(
    session: AsyncSession, user_id: str, area_ids: list[UUID]
) -> None:
    records = list(
        (
            await session.scalars(
                select(WorkAreaScheduleViewerRecord).where(
                    WorkAreaScheduleViewerRecord.user_id == user_id
                )
            )
        ).all()
    )
    records_by_area = {record.work_area_id: record for record in records}
    requested_area_ids = set(area_ids)
    for area_id, record in records_by_area.items():
        if area_id not in requested_area_ids:
            await session.delete(record)
    for area_id in requested_area_ids - records_by_area.keys():
        session.add(WorkAreaScheduleViewerRecord(user_id=user_id, work_area_id=area_id))


async def _user_dto(session: AsyncSession, user: UserRecord) -> ManagedUserDTO:
    area = (
        await session.get(WorkAreaRecord, user.work_area_id)
        if user.work_area_id
        else None
    )
    supervised_ids = list(
        await session.scalars(
            select(WorkAreaScheduleViewerRecord.work_area_id)
            .where(WorkAreaScheduleViewerRecord.user_id == user.id)
            .order_by(WorkAreaScheduleViewerRecord.work_area_id)
        )
    )
    return ManagedUserDTO(
        id=user.id,
        name=user.name,
        email=user.email,
        role=UserRole(user.role),
        job_title=user.job_title or user.role_label,
        work_area_id=user.work_area_id,
        work_area_name=area.name if area else None,
        supervised_work_area_ids=supervised_ids,
        appears_in_schedule=user.appears_in_schedule,
        is_active=user.is_active,
    )


@router.get("/bootstrap", response_model=AdministrationBootstrapDTO)
async def bootstrap(
    session: AsyncSession = Depends(get_session),
) -> AdministrationBootstrapDTO:
    _require_postgres()
    users = list(
        (await session.scalars(select(UserRecord).order_by(UserRecord.name))).all()
    )
    areas = list(
        (
            await session.scalars(select(WorkAreaRecord).order_by(WorkAreaRecord.name))
        ).all()
    )
    sites = list(
        (await session.scalars(select(SiteRecord).order_by(SiteRecord.name))).all()
    )
    projects = list(
        (
            await session.scalars(select(ProjectRecord).order_by(ProjectRecord.name))
        ).all()
    )
    stages = list(
        (await session.scalars(select(StageRecord).order_by(StageRecord.name))).all()
    )
    systems = list(
        (await session.scalars(select(SystemRecord).order_by(SystemRecord.name))).all()
    )
    subsystems = list(
        (
            await session.scalars(
                select(SubsystemRecord).order_by(SubsystemRecord.code)
            )
        ).all()
    )
    site_names = {item.id: item.name for item in sites}
    return AdministrationBootstrapDTO(
        users=[await _user_dto(session, item) for item in users],
        work_areas=[
            WorkAreaDTO(
                id=item.id,
                name=item.name,
                description=item.description,
                is_active=item.is_active,
            )
            for item in areas
        ],
        sites=[
            SiteOptionDTO(
                id=item.id,
                name=item.name,
                description=item.description,
                is_active=item.is_active,
            )
            for item in sites
        ],
        projects=[
            ProjectDTO(
                id=item.id,
                site_id=item.site_id,
                site_name=site_names.get(item.site_id, "Sede no disponible"),
                name=item.name,
                description=item.description,
                is_active=item.is_active,
            )
            for item in projects
        ],
        stages=[
            StageDTO(
                id=item.id,
                project_id=item.project_id,
                name=item.name,
                operational_status=item.operational_status,
                is_active=item.is_active,
            )
            for item in stages
        ],
        systems=[
            SystemDTO(
                id=item.id,
                project_id=item.project_id,
                name=item.name,
                description=item.description,
                is_active=item.is_active,
            )
            for item in systems
        ],
        subsystems=[
            SubsystemDTO(
                id=item.id,
                system_id=item.system_id,
                code=item.code,
                name=item.name,
                description=item.description,
                is_active=item.is_active,
            )
            for item in subsystems
        ],
    )


@router.post(
    "/users", response_model=ManagedUserDTO, status_code=status.HTTP_201_CREATED
)
async def create_user(
    payload: UserWriteRequest,
    session: AsyncSession = Depends(get_session),
) -> ManagedUserDTO:
    _require_postgres()
    if payload.password is None:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "La contrasena inicial es obligatoria.",
        )
    await _active_area(session, payload.work_area_id)
    if payload.appears_in_schedule and payload.work_area_id is None:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "Asigna un area para mostrar al usuario en Horarios.",
        )
    supervised_ids = (
        payload.supervised_work_area_ids if payload.role == UserRole.BOSS else []
    )
    await _supervised_areas(session, supervised_ids)
    if await session.scalar(
        select(UserRecord.id).where(func.lower(UserRecord.email) == payload.email)
    ):
        raise HTTPException(status.HTTP_409_CONFLICT, "El correo ya esta registrado.")
    user = UserRecord(
        id=f"user-{uuid4()}",
        name=payload.name,
        email=payload.email,
        role=payload.role.value,
        role_label=payload.job_title,
        job_title=payload.job_title,
        password_hash=hash_password(payload.password),
        work_area_id=payload.work_area_id,
        appears_in_schedule=payload.appears_in_schedule
        and payload.role != UserRole.BOSS,
        is_active=payload.is_active,
    )
    session.add(user)
    await session.flush()
    await _replace_supervised_areas(session, user.id, supervised_ids)
    await session.commit()
    return await _user_dto(session, user)


@router.put("/users/{user_id}", response_model=ManagedUserDTO)
async def update_user(
    user_id: str,
    payload: UserWriteRequest,
    administrator: UserDTO = Depends(require_roles(UserRole.ADMINISTRATOR)),
    session: AsyncSession = Depends(get_session),
) -> ManagedUserDTO:
    _require_postgres()
    user = await session.get(UserRecord, user_id)
    if user is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Usuario no encontrado.")
    if user_id == administrator.id and not payload.is_active:
        raise HTTPException(
            status.HTTP_409_CONFLICT, "No puedes desactivar tu propio usuario."
        )
    await _active_area(session, payload.work_area_id)
    if payload.appears_in_schedule and payload.work_area_id is None:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "Asigna un area para mostrar al usuario en Horarios.",
        )
    supervised_ids = (
        payload.supervised_work_area_ids if payload.role == UserRole.BOSS else []
    )
    await _supervised_areas(session, supervised_ids)
    duplicate = await session.scalar(
        select(UserRecord.id).where(
            func.lower(UserRecord.email) == payload.email,
            UserRecord.id != user_id,
        )
    )
    if duplicate:
        raise HTTPException(status.HTTP_409_CONFLICT, "El correo ya esta registrado.")
    user.name = payload.name
    user.email = payload.email
    user.role = payload.role.value
    user.role_label = payload.job_title
    user.job_title = payload.job_title
    user.work_area_id = payload.work_area_id
    user.appears_in_schedule = (
        payload.appears_in_schedule and payload.role != UserRole.BOSS
    )
    user.is_active = payload.is_active
    if payload.password:
        user.password_hash = hash_password(payload.password)
    await _replace_supervised_areas(session, user.id, supervised_ids)
    if not payload.is_active or payload.password:
        refresh_sessions = list(
            (
                await session.scalars(
                    select(RefreshSessionRecord).where(
                        RefreshSessionRecord.user_id == user.id
                    )
                )
            ).all()
        )
        for refresh_session in refresh_sessions:
            await session.delete(refresh_session)
    await session.commit()
    return await _user_dto(session, user)


async def _catalog_conflict(session: AsyncSession, model, *criteria) -> None:
    if await session.scalar(select(model.id).where(*criteria)):
        raise HTTPException(
            status.HTTP_409_CONFLICT, "Ya existe un registro con ese nombre o codigo."
        )


async def _commit_catalog(session: AsyncSession, record) -> None:
    try:
        await session.commit()
        await session.refresh(record)
    except IntegrityError as error:
        await session.rollback()
        raise HTTPException(
            status.HTTP_409_CONFLICT, "El registro ya existe o esta en uso."
        ) from error


@router.post(
    "/sites", response_model=SiteOptionDTO, status_code=status.HTTP_201_CREATED
)
async def create_site(
    payload: SiteWriteRequest, session: AsyncSession = Depends(get_session)
) -> SiteOptionDTO:
    _require_postgres()
    name = payload.name.strip()
    await _catalog_conflict(
        session, SiteRecord, func.lower(SiteRecord.name) == name.casefold()
    )
    record = SiteRecord(
        name=name,
        description=_clean_optional(payload.description),
        is_active=payload.is_active,
    )
    session.add(record)
    await _commit_catalog(session, record)
    return SiteOptionDTO(
        id=record.id,
        name=record.name,
        description=record.description,
        is_active=record.is_active,
    )


@router.put("/sites/{record_id}", response_model=SiteOptionDTO)
async def update_site(
    record_id: UUID,
    payload: SiteWriteRequest,
    session: AsyncSession = Depends(get_session),
) -> SiteOptionDTO:
    _require_postgres()
    record = await session.get(SiteRecord, record_id)
    if record is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Sede no encontrada.")
    if not payload.is_active and await session.scalar(
        select(ProjectRecord.id).where(
            ProjectRecord.site_id == record_id,
            ProjectRecord.is_active.is_(True),
        )
    ):
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "Desactiva primero los proyectos de la sede.",
        )
    await _catalog_conflict(
        session,
        SiteRecord,
        func.lower(SiteRecord.name) == payload.name.strip().casefold(),
        SiteRecord.id != record_id,
    )
    record.name = payload.name.strip()
    record.description = _clean_optional(payload.description)
    record.is_active = payload.is_active
    await _commit_catalog(session, record)
    return SiteOptionDTO(
        id=record.id,
        name=record.name,
        description=record.description,
        is_active=record.is_active,
    )


@router.post(
    "/work-areas", response_model=WorkAreaDTO, status_code=status.HTTP_201_CREATED
)
async def create_work_area(
    payload: WorkAreaWriteRequest, session: AsyncSession = Depends(get_session)
):
    _require_postgres()
    name = payload.name.strip()
    await _catalog_conflict(
        session, WorkAreaRecord, func.lower(WorkAreaRecord.name) == name.casefold()
    )
    record = WorkAreaRecord(
        name=name,
        description=_clean_optional(payload.description),
        is_active=payload.is_active,
    )
    session.add(record)
    await _commit_catalog(session, record)
    return WorkAreaDTO(
        id=record.id,
        name=record.name,
        description=record.description,
        is_active=record.is_active,
    )


@router.put("/work-areas/{record_id}", response_model=WorkAreaDTO)
async def update_work_area(
    record_id: UUID,
    payload: WorkAreaWriteRequest,
    session: AsyncSession = Depends(get_session),
):
    _require_postgres()
    record = await session.get(WorkAreaRecord, record_id)
    if record is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Area no encontrada.")
    if not payload.is_active:
        assigned = await session.scalar(
            select(UserRecord.id).where(
                UserRecord.work_area_id == record_id, UserRecord.is_active.is_(True)
            )
        )
        if assigned:
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                "No se puede desactivar un area con personal activo.",
            )
    await _catalog_conflict(
        session,
        WorkAreaRecord,
        func.lower(WorkAreaRecord.name) == payload.name.strip().casefold(),
        WorkAreaRecord.id != record_id,
    )
    record.name = payload.name.strip()
    record.description = _clean_optional(payload.description)
    record.is_active = payload.is_active
    await _commit_catalog(session, record)
    return WorkAreaDTO(
        id=record.id,
        name=record.name,
        description=record.description,
        is_active=record.is_active,
    )


@router.post(
    "/projects", response_model=ProjectDTO, status_code=status.HTTP_201_CREATED
)
async def create_project(
    payload: ProjectWriteRequest, session: AsyncSession = Depends(get_session)
):
    _require_postgres()
    site = await session.get(SiteRecord, payload.site_id)
    if site is None or not site.is_active:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "Sede no valida.")
    name = payload.name.strip()
    await _catalog_conflict(
        session,
        ProjectRecord,
        ProjectRecord.site_id == payload.site_id,
        func.lower(ProjectRecord.name) == name.casefold(),
    )
    record = ProjectRecord(
        site_id=payload.site_id,
        name=name,
        description=_clean_optional(payload.description),
        is_active=payload.is_active,
    )
    session.add(record)
    await _commit_catalog(session, record)
    return ProjectDTO(
        id=record.id,
        site_id=record.site_id,
        site_name=site.name,
        name=record.name,
        description=record.description,
        is_active=record.is_active,
    )


@router.put("/projects/{record_id}", response_model=ProjectDTO)
async def update_project(
    record_id: UUID,
    payload: ProjectWriteRequest,
    session: AsyncSession = Depends(get_session),
):
    _require_postgres()
    record = await session.get(ProjectRecord, record_id)
    site = await session.get(SiteRecord, payload.site_id)
    if record is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Proyecto no encontrado.")
    if site is None or not site.is_active:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "Sede no valida.")
    if not payload.is_active:
        child = await session.scalar(
            select(StageRecord.id).where(
                StageRecord.project_id == record_id, StageRecord.is_active.is_(True)
            )
        ) or await session.scalar(
            select(SystemRecord.id).where(
                SystemRecord.project_id == record_id, SystemRecord.is_active.is_(True)
            )
        )
        if child:
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                "Desactiva primero las etapas y sistemas del proyecto.",
            )
    await _catalog_conflict(
        session,
        ProjectRecord,
        ProjectRecord.site_id == payload.site_id,
        func.lower(ProjectRecord.name) == payload.name.strip().casefold(),
        ProjectRecord.id != record_id,
    )
    record.site_id = payload.site_id
    record.name = payload.name.strip()
    record.description = _clean_optional(payload.description)
    record.is_active = payload.is_active
    await _commit_catalog(session, record)
    return ProjectDTO(
        id=record.id,
        site_id=record.site_id,
        site_name=site.name,
        name=record.name,
        description=record.description,
        is_active=record.is_active,
    )


@router.post("/stages", response_model=StageDTO, status_code=status.HTTP_201_CREATED)
async def create_stage(
    payload: StageWriteRequest, session: AsyncSession = Depends(get_session)
):
    _require_postgres()
    parent = await session.get(ProjectRecord, payload.project_id)
    if parent is None or not parent.is_active:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT, "Proyecto no valido."
        )
    name = payload.name.strip()
    await _catalog_conflict(
        session,
        StageRecord,
        StageRecord.project_id == payload.project_id,
        func.lower(StageRecord.name) == name.casefold(),
    )
    record = StageRecord(
        project_id=payload.project_id,
        name=name,
        operational_status=_clean_optional(payload.operational_status),
        is_active=payload.is_active,
    )
    session.add(record)
    await _commit_catalog(session, record)
    return StageDTO(
        id=record.id,
        project_id=record.project_id,
        name=record.name,
        operational_status=record.operational_status,
        is_active=record.is_active,
    )


@router.put("/stages/{record_id}", response_model=StageDTO)
async def update_stage(
    record_id: UUID,
    payload: StageWriteRequest,
    session: AsyncSession = Depends(get_session),
):
    _require_postgres()
    record = await session.get(StageRecord, record_id)
    parent = await session.get(ProjectRecord, payload.project_id)
    if record is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Etapa no encontrada.")
    if parent is None or not parent.is_active:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT, "Proyecto no valido."
        )
    await _catalog_conflict(
        session,
        StageRecord,
        StageRecord.project_id == payload.project_id,
        func.lower(StageRecord.name) == payload.name.strip().casefold(),
        StageRecord.id != record_id,
    )
    record.project_id = payload.project_id
    record.name = payload.name.strip()
    record.operational_status = _clean_optional(payload.operational_status)
    record.is_active = payload.is_active
    await _commit_catalog(session, record)
    return StageDTO(
        id=record.id,
        project_id=record.project_id,
        name=record.name,
        operational_status=record.operational_status,
        is_active=record.is_active,
    )


@router.post("/systems", response_model=SystemDTO, status_code=status.HTTP_201_CREATED)
async def create_system(
    payload: SystemWriteRequest, session: AsyncSession = Depends(get_session)
):
    _require_postgres()
    parent = await session.get(ProjectRecord, payload.project_id)
    if parent is None or not parent.is_active:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT, "Proyecto no valido."
        )
    name = payload.name.strip()
    await _catalog_conflict(
        session,
        SystemRecord,
        SystemRecord.project_id == payload.project_id,
        func.lower(SystemRecord.name) == name.casefold(),
    )
    record = SystemRecord(
        project_id=payload.project_id,
        name=name,
        description=_clean_optional(payload.description),
        is_active=payload.is_active,
    )
    session.add(record)
    await _commit_catalog(session, record)
    return SystemDTO(
        id=record.id,
        project_id=record.project_id,
        name=record.name,
        description=record.description,
        is_active=record.is_active,
    )


@router.put("/systems/{record_id}", response_model=SystemDTO)
async def update_system(
    record_id: UUID,
    payload: SystemWriteRequest,
    session: AsyncSession = Depends(get_session),
):
    _require_postgres()
    record = await session.get(SystemRecord, record_id)
    parent = await session.get(ProjectRecord, payload.project_id)
    if record is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Sistema no encontrado.")
    if parent is None or not parent.is_active:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT, "Proyecto no valido."
        )
    if not payload.is_active and await session.scalar(
        select(SubsystemRecord.id).where(
            SubsystemRecord.system_id == record_id, SubsystemRecord.is_active.is_(True)
        )
    ):
        raise HTTPException(
            status.HTTP_409_CONFLICT, "Desactiva primero los subsistemas."
        )
    await _catalog_conflict(
        session,
        SystemRecord,
        SystemRecord.project_id == payload.project_id,
        func.lower(SystemRecord.name) == payload.name.strip().casefold(),
        SystemRecord.id != record_id,
    )
    record.project_id = payload.project_id
    record.name = payload.name.strip()
    record.description = _clean_optional(payload.description)
    record.is_active = payload.is_active
    await _commit_catalog(session, record)
    return SystemDTO(
        id=record.id,
        project_id=record.project_id,
        name=record.name,
        description=record.description,
        is_active=record.is_active,
    )


@router.post(
    "/subsystems", response_model=SubsystemDTO, status_code=status.HTTP_201_CREATED
)
async def create_subsystem(
    payload: SubsystemWriteRequest, session: AsyncSession = Depends(get_session)
):
    _require_postgres()
    parent = await session.get(SystemRecord, payload.system_id)
    if parent is None or not parent.is_active:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "Sistema no valido.")
    name = payload.name.strip()
    await _catalog_conflict(
        session,
        SubsystemRecord,
        SubsystemRecord.system_id == payload.system_id,
        (func.lower(SubsystemRecord.name) == name.casefold())
        | (SubsystemRecord.code == payload.code),
    )
    record = SubsystemRecord(
        system_id=payload.system_id,
        code=payload.code,
        name=name,
        description=_clean_optional(payload.description),
        is_active=payload.is_active,
    )
    session.add(record)
    await _commit_catalog(session, record)
    return SubsystemDTO(
        id=record.id,
        system_id=record.system_id,
        code=record.code,
        name=record.name,
        description=record.description,
        is_active=record.is_active,
    )


@router.put("/subsystems/{record_id}", response_model=SubsystemDTO)
async def update_subsystem(
    record_id: UUID,
    payload: SubsystemWriteRequest,
    session: AsyncSession = Depends(get_session),
):
    _require_postgres()
    record = await session.get(SubsystemRecord, record_id)
    parent = await session.get(SystemRecord, payload.system_id)
    if record is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Subsistema no encontrado.")
    if parent is None or not parent.is_active:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "Sistema no valido.")
    await _catalog_conflict(
        session,
        SubsystemRecord,
        SubsystemRecord.system_id == payload.system_id,
        (func.lower(SubsystemRecord.name) == payload.name.strip().casefold())
        | (SubsystemRecord.code == payload.code),
        SubsystemRecord.id != record_id,
    )
    record.system_id = payload.system_id
    record.code = payload.code
    record.name = payload.name.strip()
    record.description = _clean_optional(payload.description)
    record.is_active = payload.is_active
    await _commit_catalog(session, record)
    return SubsystemDTO(
        id=record.id,
        system_id=record.system_id,
        code=record.code,
        name=record.name,
        description=record.description,
        is_active=record.is_active,
    )
