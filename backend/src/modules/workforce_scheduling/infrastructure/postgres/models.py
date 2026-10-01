from datetime import date, datetime, time
from uuid import UUID

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    ForeignKey,
    String,
    Text,
    Time,
    UniqueConstraint,
    Uuid,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base
from shared_kernel.persistence import OperationalRecordMixin


class ScheduleShiftTypeRecord(Base):
    __tablename__ = "schedule_shift_types"

    code: Mapped[str] = mapped_column(String(20), primary_key=True)
    name: Mapped[str] = mapped_column(String(80), nullable=False)
    description: Mapped[str] = mapped_column(String(240), nullable=False)
    starts_at: Mapped[time | None] = mapped_column(Time)
    ends_at: Mapped[time | None] = mapped_column(Time)
    color_hex: Mapped[str] = mapped_column(String(7), nullable=False)
    applies_to_full_week: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True, server_default="true"
    )


class WorkAreaScheduleViewerRecord(Base):
    __tablename__ = "work_area_schedule_viewers"

    user_id: Mapped[str] = mapped_column(
        String(80), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    work_area_id: Mapped[UUID] = mapped_column(
        Uuid, ForeignKey("work_areas.id", ondelete="CASCADE"), primary_key=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class EmployeeScheduleEntryRecord(OperationalRecordMixin, Base):
    __tablename__ = "employee_schedule_entries"
    __table_args__ = (
        UniqueConstraint("user_id", "work_date", name="uq_employee_schedule_user_date"),
    )

    user_id: Mapped[str] = mapped_column(
        String(80), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    work_area_id: Mapped[UUID] = mapped_column(
        Uuid, ForeignKey("work_areas.id", ondelete="CASCADE"), nullable=False, index=True
    )
    work_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    shift_code: Mapped[str] = mapped_column(
        String(20), ForeignKey("schedule_shift_types.code"), nullable=False
    )
    updated_by_user_id: Mapped[str] = mapped_column(
        String(80), ForeignKey("users.id"), nullable=False
    )


class EmployeeScheduleAuditRecord(OperationalRecordMixin, Base):
    __tablename__ = "employee_schedule_audit_events"

    target_user_id: Mapped[str] = mapped_column(
        String(80), ForeignKey("users.id"), nullable=False, index=True
    )
    work_area_id: Mapped[UUID] = mapped_column(
        Uuid, ForeignKey("work_areas.id"), nullable=False, index=True
    )
    work_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    previous_shift_code: Mapped[str | None] = mapped_column(String(20))
    new_shift_code: Mapped[str | None] = mapped_column(String(20))
    change_scope: Mapped[str] = mapped_column(String(20), nullable=False)
    changed_by_user_id: Mapped[str] = mapped_column(
        String(80), ForeignKey("users.id"), nullable=False, index=True
    )
    reason: Mapped[str | None] = mapped_column(Text)
