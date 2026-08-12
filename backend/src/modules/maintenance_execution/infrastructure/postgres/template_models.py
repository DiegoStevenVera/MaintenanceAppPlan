from datetime import datetime
from uuid import UUID

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base
from shared_kernel.persistence import CatalogRecordMixin, OperationalRecordMixin


class MaintenanceTemplateRecord(CatalogRecordMixin, Base):
    __tablename__ = "maintenance_templates"

    report_code: Mapped[str] = mapped_column(String(80), nullable=False, unique=True)
    subsystem_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("subsystems.id"),
        nullable=False,
        index=True,
    )
    activity_n1: Mapped[str] = mapped_column(String(200), nullable=False)
    activity_n2: Mapped[str | None] = mapped_column(String(200))
    activity_n3_summary: Mapped[str | None] = mapped_column(String(240))
    activity_n3_detail: Mapped[str | None] = mapped_column(Text)
    activity_n4: Mapped[str | None] = mapped_column(String(240))
    manual_reference: Mapped[str | None] = mapped_column(String(200))
    manual_file_reference: Mapped[str | None] = mapped_column(Text)
    manual_start_page: Mapped[int | None] = mapped_column(Integer)
    manual_end_page: Mapped[int | None] = mapped_column(Integer)
    frequency: Mapped[str | None] = mapped_column(String(100))
    estimated_minutes: Mapped[int | None] = mapped_column(Integer)
    required_personnel: Mapped[int | None] = mapped_column(Integer)


class MaintenanceTemplateStepRecord(CatalogRecordMixin, Base):
    __tablename__ = "maintenance_template_steps"
    __table_args__ = (
        UniqueConstraint(
            "maintenance_template_id",
            "sequence",
            name="uq_maintenance_template_steps_sequence",
        ),
    )

    maintenance_template_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("maintenance_templates.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    title: Mapped[str] = mapped_column(Text, nullable=False)
    default_comment: Mapped[str | None] = mapped_column(Text)
    manual_page: Mapped[int | None] = mapped_column(Integer)
    sequence: Mapped[int] = mapped_column(Integer, nullable=False)
    is_required: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)


class MaintenanceTemplateTestRecord(CatalogRecordMixin, Base):
    __tablename__ = "maintenance_template_tests"
    __table_args__ = (
        UniqueConstraint(
            "template_step_id",
            "sequence",
            name="uq_maintenance_template_tests_sequence",
        ),
    )

    maintenance_template_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("maintenance_templates.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    template_step_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("maintenance_template_steps.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(240), nullable=False)
    result_type: Mapped[str] = mapped_column(String(40), nullable=False)
    threshold_min: Mapped[str | None] = mapped_column(String(80))
    threshold_max: Mapped[str | None] = mapped_column(String(80))
    prefix: Mapped[str | None] = mapped_column(String(40))
    unit: Mapped[str | None] = mapped_column(String(40))
    sequence: Mapped[int] = mapped_column(Integer, nullable=False)


class MaintenanceTemplateTestOptionRecord(CatalogRecordMixin, Base):
    __tablename__ = "maintenance_template_test_options"
    __table_args__ = (
        UniqueConstraint(
            "template_test_id",
            "value",
            name="uq_maintenance_template_test_options_value",
        ),
    )

    template_test_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("maintenance_template_tests.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    value: Mapped[str] = mapped_column(String(200), nullable=False)
    sequence: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    is_default: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)


class MaintenanceTemplateConclusionRecord(CatalogRecordMixin, Base):
    __tablename__ = "maintenance_template_conclusions"
    __table_args__ = (
        UniqueConstraint(
            "maintenance_template_id",
            "summary",
            name="uq_maintenance_template_conclusions_summary",
        ),
    )

    maintenance_template_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("maintenance_templates.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    summary: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)


class MaintenanceTemplatePersonnelRecord(CatalogRecordMixin, Base):
    __tablename__ = "maintenance_template_personnel"
    __table_args__ = (
        UniqueConstraint(
            "maintenance_template_id",
            "personnel_role",
            name="uq_maintenance_template_personnel_role",
        ),
    )

    maintenance_template_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("maintenance_templates.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    personnel_role: Mapped[str] = mapped_column(String(120), nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, nullable=False)
    estimated_hours: Mapped[float | None] = mapped_column(Float)


class MaintenanceTemplateScopeRecord(OperationalRecordMixin, Base):
    __tablename__ = "maintenance_template_scopes"
    __table_args__ = (
        UniqueConstraint(
            "maintenance_template_id",
            "asset_id",
            "geographic_location_id",
            name="uq_maintenance_template_scopes_target",
        ),
    )

    legacy_id: Mapped[int | None] = mapped_column(Integer, unique=True)
    maintenance_template_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("maintenance_templates.id"),
        nullable=False,
        index=True,
    )
    asset_id: Mapped[str | None] = mapped_column(
        String(80),
        ForeignKey("assets.id"),
        index=True,
    )
    equipment_category_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("equipment_categories.id"),
        index=True,
    )
    geographic_location_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("geographic_locations.id"),
        index=True,
    )
    display_name: Mapped[str] = mapped_column(String(240), nullable=False)
    notes: Mapped[str | None] = mapped_column(Text)


class MaintenancePlanEntryRecord(OperationalRecordMixin, Base):
    __tablename__ = "maintenance_plan_entries"
    __table_args__ = (
        CheckConstraint("month BETWEEN 1 AND 12", name="ck_maintenance_plan_entries_month"),
    )

    legacy_id: Mapped[int | None] = mapped_column(Integer, unique=True)
    maintenance_template_scope_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("maintenance_template_scopes.id"),
        nullable=False,
        index=True,
    )
    year: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    month: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    item_number: Mapped[int | None] = mapped_column(Integer)
    planned_hours: Mapped[float | None] = mapped_column(Float)
    required_workers: Mapped[int | None] = mapped_column(Integer)
    source_reference: Mapped[str | None] = mapped_column(String(160))
    planning_status: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="PLANNED",
        index=True,
    )
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    cancelled_by_user_id: Mapped[str | None] = mapped_column(
        String(80),
        ForeignKey("users.id"),
    )
    cancellation_reason: Mapped[str | None] = mapped_column(Text)
