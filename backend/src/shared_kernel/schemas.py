from datetime import datetime
from enum import StrEnum
from typing import Generic, TypeVar

from pydantic import BaseModel, Field


class UserRole(StrEnum):
    TECHNICIAN = "TECHNICIAN"
    COORDINATOR = "COORDINATOR"
    BOSS = "BOSS"
    ADMINISTRATOR = "ADMINISTRATOR"


class MaintenanceStatus(StrEnum):
    SCHEDULED = "SCHEDULED"
    IN_PROGRESS = "IN_PROGRESS"
    COMPLETED = "COMPLETED"
    CLOSED = "CLOSED"


class Severity(StrEnum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"


T = TypeVar("T")


class Page(BaseModel, Generic[T]):
    items: list[T]
    total: int
    limit: int = Field(default=50, ge=1)
    offset: int = Field(default=0, ge=0)


class TimelineEntryDTO(BaseModel):
    id: str
    occurred_at: datetime
    text: str
