from datetime import date, datetime
from uuid import UUID

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
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
