from datetime import date, datetime
from uuid import UUID

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base
from shared_kernel.persistence import OperationalRecordMixin


class WeeklyPlanningSessionRecord(OperationalRecordMixin, Base):
    __tablename__ = "weekly_planning_sessions"
    __table_args__ = (
        UniqueConstraint(
            "week_start",
            "version",
            name="uq_weekly_planning_sessions_week_version",
        ),
        CheckConstraint(
            "status IN ('DRAFT', 'CONFIRMED')",
            name="ck_weekly_planning_sessions_status",
        ),
    )

    week_start: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="DRAFT", index=True)
    notes: Mapped[str | None] = mapped_column(Text)
    created_by_user_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("users.id"),
        nullable=False,
    )
    confirmed_by_user_id: Mapped[str | None] = mapped_column(
        String(80),
        ForeignKey("users.id"),
    )
    confirmed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class MaintenanceScheduleRevisionRecord(OperationalRecordMixin, Base):
    __tablename__ = "maintenance_schedule_revisions"
    __table_args__ = (
        UniqueConstraint(
            "weekly_planning_session_id",
            "maintenance_activity_id",
            name="uq_maintenance_schedule_revisions_session_activity",
        ),
        CheckConstraint(
            "status IN ('PROPOSED', 'CONFIRMED', 'SUPERSEDED')",
            name="ck_maintenance_schedule_revisions_status",
        ),
        CheckConstraint(
            "proposed_end_at > proposed_start_at",
            name="ck_maintenance_schedule_revisions_time_range",
        ),
    )

    weekly_planning_session_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("weekly_planning_sessions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    maintenance_activity_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("maintenance_activities.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    proposed_start_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    proposed_end_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    previous_start_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    previous_end_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    reason: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="PROPOSED",
        index=True,
    )
    created_by_user_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("users.id"),
        nullable=False,
    )
    confirmed_by_user_id: Mapped[str | None] = mapped_column(
        String(80),
        ForeignKey("users.id"),
    )
    confirmed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class PCONAnnualPlanRecord(OperationalRecordMixin, Base):
    __tablename__ = "pcon_annual_plans"
    __table_args__ = (
        UniqueConstraint("year", name="uq_pcon_annual_plans_year"),
        CheckConstraint(
            "status IN ('DRAFT', 'ACTIVE', 'CLOSED')",
            name="ck_pcon_annual_plans_status",
        ),
    )

    year: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="DRAFT")
    copied_from_year: Mapped[int | None] = mapped_column(Integer)
    created_by_user_id: Mapped[str | None] = mapped_column(
        String(80),
        ForeignKey("users.id"),
    )


class PCONAnnualPlanScopeRecord(OperationalRecordMixin, Base):
    __tablename__ = "pcon_annual_plan_scopes"
    __table_args__ = (
        UniqueConstraint(
            "annual_plan_id",
            "maintenance_template_scope_id",
            name="uq_pcon_annual_plan_scopes_membership",
        ),
    )

    annual_plan_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("pcon_annual_plans.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    maintenance_template_scope_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("maintenance_template_scopes.id"),
        nullable=False,
        index=True,
    )
    is_active: Mapped[bool] = mapped_column(nullable=False, default=True)
    created_by_user_id: Mapped[str | None] = mapped_column(
        String(80),
        ForeignKey("users.id"),
    )


class PCONPlanChangeRecord(OperationalRecordMixin, Base):
    __tablename__ = "pcon_plan_changes"

    action: Mapped[str] = mapped_column(String(40), nullable=False, index=True)
    year: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    month: Mapped[int | None] = mapped_column(Integer)
    maintenance_template_scope_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("maintenance_template_scopes.id"),
        index=True,
    )
    maintenance_plan_entry_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("maintenance_plan_entries.id"),
        index=True,
    )
    quantity_delta: Mapped[int | None] = mapped_column(Integer)
    reason: Mapped[str | None] = mapped_column(Text)
    changed_by_user_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("users.id"),
        nullable=False,
    )
    details: Mapped[dict | None] = mapped_column(JSONB)
