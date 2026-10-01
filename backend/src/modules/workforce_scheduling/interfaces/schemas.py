from datetime import date, datetime, time
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field, field_validator


class ScheduleShiftTypeDTO(BaseModel):
    code: str
    name: str
    description: str
    starts_at: time | None
    ends_at: time | None
    color_hex: str
    applies_to_full_week: bool


class ScheduleWorkAreaDTO(BaseModel):
    id: UUID
    name: str
    can_edit: bool


class ScheduleMemberDTO(BaseModel):
    id: str
    name: str
    role: str
    role_label: str


class ScheduleEntryDTO(BaseModel):
    id: UUID
    user_id: str
    work_date: date
    shift_code: str
    updated_at: datetime


class WeeklyScheduleDTO(BaseModel):
    work_area: ScheduleWorkAreaDTO
    week_start: date
    week_end: date
    can_edit: bool
    members: list[ScheduleMemberDTO]
    shift_types: list[ScheduleShiftTypeDTO]
    entries: list[ScheduleEntryDTO]


class ScheduleEntryUpdateRequest(BaseModel):
    shift_code: str | None = Field(default=None, max_length=20)
    apply_scope: Literal["DAY", "WEEK"] = "DAY"
    reason: str | None = Field(default=None, max_length=500)

    @field_validator("shift_code")
    @classmethod
    def normalize_shift_code(cls, value: str | None) -> str | None:
        normalized = value.strip().upper() if value else None
        return normalized or None


class ScheduleBulkChangeRequest(BaseModel):
    user_id: str = Field(min_length=1, max_length=80)
    work_date: date
    shift_code: str | None = Field(default=None, max_length=20)

    @field_validator("shift_code")
    @classmethod
    def normalize_shift_code(cls, value: str | None) -> str | None:
        normalized = value.strip().upper() if value else None
        return normalized or None


class ScheduleBulkUpdateRequest(BaseModel):
    work_area_id: UUID
    changes: list[ScheduleBulkChangeRequest] = Field(min_length=1, max_length=500)


class CopyWeekRequest(BaseModel):
    work_area_id: UUID
    source_week_start: date
    target_week_start: date
    overwrite: bool = True
    reason: str | None = Field(default=None, max_length=500)
