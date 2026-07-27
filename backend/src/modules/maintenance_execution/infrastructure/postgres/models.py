from datetime import datetime
from uuid import UUID

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text, Uuid
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class PreventiveScheduleRecord(Base):
    __tablename__ = "preventive_schedules"

    id: Mapped[str] = mapped_column(String(80), primary_key=True)
    name: Mapped[str] = mapped_column(String(240), nullable=False, index=True)
    template_name: Mapped[str] = mapped_column(String(240), nullable=False)
    asset_ids: Mapped[list[str]] = mapped_column(JSONB, nullable=False, default=list)
    asset_names: Mapped[list[str]] = mapped_column(JSONB, nullable=False, default=list)
    subsystem: Mapped[str] = mapped_column(String(40), nullable=False, index=True)
    scheduled_at: Mapped[str] = mapped_column(String(80), nullable=False)
    status: Mapped[str] = mapped_column(String(40), nullable=False, index=True)
    physical_location: Mapped[str] = mapped_column(Text, nullable=False)
    report_version_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    legacy_id: Mapped[int | None] = mapped_column(Integer, unique=True)
    maintenance_activity_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("maintenance_activities.id"),
        unique=True,
        index=True,
    )
    maintenance_template_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("maintenance_templates.id"),
        index=True,
    )
    maintenance_plan_entry_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("maintenance_plan_entries.id"),
        index=True,
    )
    assigned_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    shift: Mapped[str | None] = mapped_column(String(80))
    sap_order: Mapped[str | None] = mapped_column(String(120))
    work_order: Mapped[str | None] = mapped_column(String(120))


class CorrectiveEventRecord(Base):
    __tablename__ = "corrective_events"

    id: Mapped[str] = mapped_column(String(80), primary_key=True)
    code: Mapped[str] = mapped_column(String(80), nullable=False)
    sap_code: Mapped[str] = mapped_column(String(120), nullable=False)
    name: Mapped[str] = mapped_column(String(240), nullable=False, index=True)
    affected_asset_id: Mapped[str | None] = mapped_column(String(80))
    affected_asset_path: Mapped[str] = mapped_column(Text, nullable=False)
    subsystem: Mapped[str] = mapped_column(String(40), nullable=False, index=True)
    severity: Mapped[str] = mapped_column(String(40), nullable=False)
    status: Mapped[str] = mapped_column(String(40), nullable=False, index=True)
    notice_created_at: Mapped[str] = mapped_column(String(80), nullable=False)
    response_at: Mapped[str] = mapped_column(String(80), nullable=False)
    physical_location: Mapped[str] = mapped_column(Text, nullable=False)
    report_version_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    timeline: Mapped[list[dict[str, str]]] = mapped_column(JSONB, nullable=False, default=list)
    legacy_id: Mapped[int | None] = mapped_column(Integer, unique=True)
    maintenance_activity_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("maintenance_activities.id"),
        unique=True,
        index=True,
    )
    primary_asset_id: Mapped[str | None] = mapped_column(
        String(80),
        ForeignKey("assets.id"),
        index=True,
    )
    subsystem_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("subsystems.id"),
        index=True,
    )
    created_by_user_id: Mapped[str | None] = mapped_column(
        String(80),
        ForeignKey("users.id"),
    )
    failure_description: Mapped[str | None] = mapped_column(Text)
    operational_impact: Mapped[str | None] = mapped_column(Text)
