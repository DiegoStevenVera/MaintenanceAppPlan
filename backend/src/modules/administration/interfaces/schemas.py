from uuid import UUID

from pydantic import BaseModel, Field, field_validator

from shared_kernel.schemas import UserRole


class SiteOptionDTO(BaseModel):
    id: UUID
    name: str
    description: str | None = None
    is_active: bool


class WorkAreaDTO(BaseModel):
    id: UUID
    name: str
    description: str | None = None
    is_active: bool


class ProjectDTO(BaseModel):
    id: UUID
    site_id: UUID
    site_name: str
    name: str
    description: str | None = None
    is_active: bool


class StageDTO(BaseModel):
    id: UUID
    project_id: UUID
    name: str
    operational_status: str | None = None
    is_active: bool


class SystemDTO(BaseModel):
    id: UUID
    project_id: UUID
    name: str
    description: str | None = None
    is_active: bool


class SubsystemDTO(BaseModel):
    id: UUID
    system_id: UUID
    code: str
    name: str
    description: str | None = None
    is_active: bool


class ManagedUserDTO(BaseModel):
    id: str
    name: str
    email: str
    role: UserRole
    job_title: str
    work_area_id: UUID | None = None
    work_area_name: str | None = None
    supervised_work_area_ids: list[UUID] = Field(default_factory=list)
    appears_in_schedule: bool
    is_active: bool


class AdministrationBootstrapDTO(BaseModel):
    users: list[ManagedUserDTO]
    work_areas: list[WorkAreaDTO]
    sites: list[SiteOptionDTO]
    projects: list[ProjectDTO]
    stages: list[StageDTO]
    systems: list[SystemDTO]
    subsystems: list[SubsystemDTO]


class UserWriteRequest(BaseModel):
    name: str = Field(min_length=2, max_length=160)
    email: str = Field(min_length=5, max_length=160)
    role: UserRole
    job_title: str = Field(min_length=2, max_length=120)
    work_area_id: UUID | None = None
    supervised_work_area_ids: list[UUID] = Field(default_factory=list)
    appears_in_schedule: bool = True
    is_active: bool = True
    password: str | None = Field(default=None, min_length=8, max_length=128)

    @field_validator("name", "email", "job_title")
    @classmethod
    def strip_required(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("El valor no puede estar vacio")
        return normalized

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: str) -> str:
        normalized = value.casefold()
        if (
            "@" not in normalized
            or normalized.startswith("@")
            or normalized.endswith("@")
        ):
            raise ValueError("El correo no es valido")
        return normalized


class WorkAreaWriteRequest(BaseModel):
    name: str = Field(min_length=2, max_length=160)
    description: str | None = Field(default=None, max_length=1000)
    is_active: bool = True


class SiteWriteRequest(BaseModel):
    name: str = Field(min_length=2, max_length=160)
    description: str | None = Field(default=None, max_length=1000)
    is_active: bool = True


class ProjectWriteRequest(BaseModel):
    site_id: UUID
    name: str = Field(min_length=2, max_length=200)
    description: str | None = Field(default=None, max_length=1000)
    is_active: bool = True


class StageWriteRequest(BaseModel):
    project_id: UUID
    name: str = Field(min_length=2, max_length=160)
    operational_status: str | None = Field(default=None, max_length=40)
    is_active: bool = True


class SystemWriteRequest(BaseModel):
    project_id: UUID
    name: str = Field(min_length=2, max_length=160)
    description: str | None = Field(default=None, max_length=1000)
    is_active: bool = True


class SubsystemWriteRequest(BaseModel):
    system_id: UUID
    code: str = Field(min_length=1, max_length=40)
    name: str = Field(min_length=2, max_length=160)
    description: str | None = Field(default=None, max_length=1000)
    is_active: bool = True

    @field_validator("code")
    @classmethod
    def normalize_code(cls, value: str) -> str:
        return value.strip().upper()
