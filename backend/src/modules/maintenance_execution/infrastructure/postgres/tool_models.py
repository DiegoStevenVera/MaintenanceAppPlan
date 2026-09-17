from datetime import date, datetime
from uuid import UUID

from sqlalchemy import (
    Boolean,
    Date,
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


class ToolRecord(CatalogRecordMixin, Base):
    __tablename__ = "tools"

    catalog_item_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("tool_catalog_items.id", ondelete="SET NULL"),
        index=True,
    )
    serial_number: Mapped[str] = mapped_column(String(120), nullable=False, unique=True)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    model: Mapped[str | None] = mapped_column(String(120))
    brand: Mapped[str | None] = mapped_column(String(120))
    series: Mapped[str | None] = mapped_column(String(120))
    part_number: Mapped[str | None] = mapped_column(String(120))
    tool_type: Mapped[str | None] = mapped_column(String(120))
    availability_status: Mapped[str] = mapped_column(String(40), nullable=False)
    current_location: Mapped[str | None] = mapped_column(Text)


class ToolCertificationRecord(OperationalRecordMixin, Base):
    __tablename__ = "tool_certifications"

    legacy_id: Mapped[int | None] = mapped_column(Integer, unique=True)
    tool_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("tools.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    calibration_company: Mapped[str] = mapped_column(String(200), nullable=False)
    certification_number: Mapped[str] = mapped_column(String(160), nullable=False)
    calibration_date: Mapped[date] = mapped_column(Date, nullable=False)
    validity_days: Mapped[int] = mapped_column(Integer, nullable=False)
    next_calibration_date: Mapped[date] = mapped_column(Date, nullable=False)
    certificate_file_reference: Mapped[str | None] = mapped_column(Text)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)


class MaintenanceTemplateToolRecord(CatalogRecordMixin, Base):
    __tablename__ = "maintenance_template_tools"
    __table_args__ = (
        UniqueConstraint(
            "maintenance_template_id",
            "tool_name",
            name="uq_maintenance_template_tools_name",
        ),
    )

    maintenance_template_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("maintenance_templates.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    tool_name: Mapped[str] = mapped_column(String(200), nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    estimated_hours: Mapped[int | None] = mapped_column(Integer)


class ToolCatalogItemRecord(CatalogRecordMixin, Base):
    __tablename__ = "tool_catalog_items"
    __table_args__ = (
        UniqueConstraint(
            "category",
            "name",
            name="uq_tool_catalog_item_category_name",
        ),
    )

    name: Mapped[str] = mapped_column(String(200), nullable=False)
    category: Mapped[str] = mapped_column(String(30), nullable=False)
    default_unit: Mapped[str] = mapped_column(
        String(40),
        nullable=False,
        default="unidad",
    )
    requires_identified_unit: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
    )


class OperationalChecklistRevisionRecord(OperationalRecordMixin, Base):
    __tablename__ = "maintenance_operational_checklist_revisions"
    __table_args__ = (
        UniqueConstraint(
            "maintenance_template_id",
            "revision_number",
            name="uq_operational_checklist_revision_template_number",
        ),
    )

    maintenance_template_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("maintenance_templates.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    revision_number: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="ACTIVE")
    notes: Mapped[str | None] = mapped_column(Text)
    created_by_user_id: Mapped[str | None] = mapped_column(String(80), ForeignKey("users.id"))


class OperationalChecklistItemRecord(OperationalRecordMixin, Base):
    __tablename__ = "maintenance_operational_checklist_items"
    __table_args__ = (
        UniqueConstraint(
            "checklist_revision_id",
            "sequence",
            name="uq_operational_checklist_item_revision_sequence",
        ),
    )

    checklist_revision_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey(
            "maintenance_operational_checklist_revisions.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )
    catalog_item_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("tool_catalog_items.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    category: Mapped[str] = mapped_column(String(30), nullable=False)
    item_name: Mapped[str] = mapped_column(String(200), nullable=False)
    default_quantity: Mapped[float | None] = mapped_column(Float)
    unit: Mapped[str] = mapped_column(String(40), nullable=False, default="unidad")
    is_required: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    sequence: Mapped[int] = mapped_column(Integer, nullable=False)
    notes: Mapped[str | None] = mapped_column(Text)


class ReportChecklistItemSnapshotRecord(OperationalRecordMixin, Base):
    __tablename__ = "report_checklist_item_snapshots"
    __table_args__ = (
        UniqueConstraint(
            "report_version_id",
            "checklist_type",
            "sequence",
            name="uq_report_checklist_snapshot_version_type_sequence",
        ),
    )

    report_version_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("report_versions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    checklist_type: Mapped[str] = mapped_column(String(20), nullable=False)
    source_manual_tool_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("maintenance_template_tools.id", ondelete="SET NULL"),
    )
    source_operational_item_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey(
            "maintenance_operational_checklist_items.id",
            ondelete="SET NULL",
        ),
    )
    item_name_snapshot: Mapped[str] = mapped_column(String(200), nullable=False)
    category_snapshot: Mapped[str | None] = mapped_column(String(30))
    recommended_quantity_snapshot: Mapped[float | None] = mapped_column(Float)
    actual_quantity: Mapped[float | None] = mapped_column(Float)
    unit_snapshot: Mapped[str | None] = mapped_column(String(40))
    is_checked: Mapped[bool | None] = mapped_column(Boolean)
    is_required_snapshot: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
    )
    sequence: Mapped[int] = mapped_column(Integer, nullable=False)
    notes: Mapped[str | None] = mapped_column(Text)


class ReportToolUsageRecord(OperationalRecordMixin, Base):
    __tablename__ = "report_tool_usages"
    __table_args__ = (
        UniqueConstraint(
            "report_version_id",
            "tool_id",
            name="uq_report_tool_usages_version_tool",
        ),
    )

    legacy_id: Mapped[int | None] = mapped_column(Integer, unique=True)
    report_version_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("report_versions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    operational_checklist_item_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey(
            "maintenance_operational_checklist_items.id",
            ondelete="SET NULL",
        ),
        index=True,
    )
    tool_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("tools.id"),
        nullable=False,
        index=True,
    )
    certification_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("tool_certifications.id"),
    )
    used_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    tool_name_snapshot: Mapped[str | None] = mapped_column(String(200))
    tool_serial_snapshot: Mapped[str | None] = mapped_column(String(120))
    certification_number_snapshot: Mapped[str | None] = mapped_column(String(160))
    certification_valid_until_snapshot: Mapped[date | None] = mapped_column(Date)
