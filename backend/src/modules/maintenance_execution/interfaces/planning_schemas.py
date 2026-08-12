from datetime import date, datetime
from enum import StrEnum
from uuid import UUID

from pydantic import BaseModel, Field, model_validator


class PlanningState(StrEnum):
    MONTH_ONLY = "MONTH_ONLY"
    PROPOSED = "PROPOSED"
    CONFIRMED = "CONFIRMED"
    RESCHEDULE_PENDING = "RESCHEDULE_PENDING"
    EXECUTED = "EXECUTED"


class PCONPlanItemDTO(BaseModel):
    plan_entry_id: UUID
    activity_id: UUID
    maintenance_template_scope_id: UUID
    maintenance_template_id: UUID
    title: str
    template_name: str
    maintenance_name: str
    frequency: str | None
    equipment_id: str | None
    equipment_name: str
    equipment_category: str
    location_name: str
    subsystem_code: str
    subsystem_name: str
    year: int
    month: int
    estimated_minutes: int | None
    required_workers: int | None
    activity_status: str
    scheduled_start_at: datetime | None
    scheduled_end_at: datetime | None
    proposed_start_at: datetime | None = None
    proposed_end_at: datetime | None = None
    planning_state: PlanningState


class PCONPlanPageDTO(BaseModel):
    items: list[PCONPlanItemDTO]
    total: int


class PCONAnnualMonthDTO(BaseModel):
    month: int = Field(ge=1, le=12)
    count: int
    month_only_count: int
    proposed_count: int
    confirmed_count: int
    executed_count: int
    occurrences: list[PCONPlanItemDTO]


class PCONAnnualRowDTO(BaseModel):
    id: UUID
    maintenance_template_scope_id: UUID
    maintenance_template_id: UUID
    subsystem_code: str
    subsystem_name: str
    equipment_category: str
    location_name: str
    equipment_id: str | None
    equipment_name: str
    maintenance_name: str
    frequency: str | None
    annual_count: int
    months: list[PCONAnnualMonthDTO]


class PCONAnnualPlanDTO(BaseModel):
    year: int
    status: str
    copied_from_year: int | None = None
    is_virtual: bool = False
    rows: list[PCONAnnualRowDTO]
    total_rows: int
    total_executions: int


class AssignPlanMonthRequest(BaseModel):
    plan_entry_ids: list[UUID] = Field(min_length=1)
    year: int = Field(ge=2000, le=2200)
    month: int = Field(ge=1, le=12)


class SetAnnualPlanCountRequest(BaseModel):
    maintenance_template_scope_id: UUID
    year: int = Field(ge=2000, le=2200)
    month: int = Field(ge=1, le=12)
    count: int = Field(ge=0, le=366)


class SetAnnualPlanCountResponse(BaseModel):
    previous_count: int
    count: int
    created: int
    removed: int


class CreateOccurrencesRequest(BaseModel):
    maintenance_template_scope_id: UUID
    year: int = Field(ge=2000, le=2200)
    month: int = Field(ge=1, le=12)
    quantity: int = Field(default=1, ge=1, le=366)
    reason: str | None = None


class MoveOccurrenceRequest(BaseModel):
    year: int = Field(ge=2000, le=2200)
    month: int = Field(ge=1, le=12)
    reason: str | None = None


class CancelOccurrenceRequest(BaseModel):
    reason: str = Field(min_length=3, max_length=500)


class CopyAnnualPlanRequest(BaseModel):
    source_year: int = Field(ge=2000, le=2200)
    target_year: int = Field(ge=2000, le=2200)
    mode: str = Field(default="FILL_EMPTY", pattern="^FILL_EMPTY$")


class CopyAnnualPlanResponse(BaseModel):
    source_year: int
    target_year: int
    scopes_added: int
    occurrences_created: int
    preserved_cells: int


class PCONCatalogAssetDTO(BaseModel):
    id: str
    name: str
    subsystem: str
    category: str
    location_name: str


class PCONCatalogTemplateDTO(BaseModel):
    id: UUID
    name: str
    subsystem_code: str
    frequency: str | None
    estimated_minutes: int | None
    required_workers: int | None


class PCONCatalogDTO(BaseModel):
    assets: list[PCONCatalogAssetDTO]
    templates: list[PCONCatalogTemplateDTO]


class AddPlanScopeRequest(BaseModel):
    year: int = Field(ge=2000, le=2200)
    asset_id: str = Field(min_length=1)
    maintenance_template_id: UUID
    month: int = Field(ge=1, le=12)
    quantity: int = Field(default=1, ge=1, le=366)
    reason: str | None = None


class AddPlanScopeResponse(BaseModel):
    maintenance_template_scope_id: UUID
    created_scope: bool
    created_membership: bool
    occurrences_created: int


class PCONPlanChangeDTO(BaseModel):
    id: UUID
    action: str
    year: int
    month: int | None
    equipment_name: str | None
    maintenance_name: str | None
    quantity_delta: int | None
    reason: str | None
    changed_by_name: str
    changed_at: datetime


class WeeklyPlanningSessionDTO(BaseModel):
    id: UUID
    week_start: date
    version: int
    status: str
    notes: str | None
    created_by_user_id: str
    confirmed_by_user_id: str | None
    confirmed_at: datetime | None
    proposal_count: int = 0


class CreateWeeklySessionRequest(BaseModel):
    notes: str | None = None


class ScheduleProposalRequest(BaseModel):
    proposed_start_at: datetime
    proposed_end_at: datetime
    reason: str | None = None

    @model_validator(mode="after")
    def validate_time_range(self) -> "ScheduleProposalRequest":
        if self.proposed_end_at <= self.proposed_start_at:
            raise ValueError("La hora fin debe ser posterior a la hora de inicio")
        return self


class ScheduleProposalDTO(BaseModel):
    id: UUID
    session_id: UUID
    activity_id: UUID
    activity_title: str
    equipment_name: str
    proposed_start_at: datetime
    proposed_end_at: datetime
    previous_start_at: datetime | None
    previous_end_at: datetime | None
    reason: str | None
    status: str


class WeeklyPlanningDetailDTO(BaseModel):
    session: WeeklyPlanningSessionDTO
    proposals: list[ScheduleProposalDTO]


class PlanningHistoryItemDTO(BaseModel):
    revision_id: UUID
    session_id: UUID
    week_start: date
    session_version: int
    activity_id: UUID
    activity_title: str
    equipment_name: str
    proposed_start_at: datetime
    proposed_end_at: datetime
    previous_start_at: datetime | None
    previous_end_at: datetime | None
    reason: str | None
    status: str
    confirmed_at: datetime | None
    confirmed_by_name: str | None
