from datetime import date
from uuid import UUID

from sqlalchemy import Date, ForeignKey, String, Text, UniqueConstraint, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base
from shared_kernel.persistence import CatalogRecordMixin


class SiteRecord(CatalogRecordMixin, Base):
    __tablename__ = "sites"

    name: Mapped[str] = mapped_column(String(160), nullable=False, unique=True)
    description: Mapped[str | None] = mapped_column(Text)


class ProjectRecord(CatalogRecordMixin, Base):
    __tablename__ = "projects"
    __table_args__ = (UniqueConstraint("site_id", "name", name="uq_projects_site_name"),)

    site_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("sites.id"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)


class StageRecord(CatalogRecordMixin, Base):
    __tablename__ = "stages"
    __table_args__ = (UniqueConstraint("project_id", "name", name="uq_stages_project_name"),)

    project_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("projects.id"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    planned_start_date: Mapped[date | None] = mapped_column(Date)
    planned_end_date: Mapped[date | None] = mapped_column(Date)
    operational_status: Mapped[str | None] = mapped_column(String(40))


class SystemRecord(CatalogRecordMixin, Base):
    __tablename__ = "systems"
    __table_args__ = (UniqueConstraint("project_id", "name", name="uq_systems_project_name"),)

    project_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("projects.id"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)


class SubsystemRecord(CatalogRecordMixin, Base):
    __tablename__ = "subsystems"
    __table_args__ = (
        UniqueConstraint("system_id", "code", name="uq_subsystems_system_code"),
        UniqueConstraint("system_id", "name", name="uq_subsystems_system_name"),
    )

    system_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("systems.id"),
        nullable=False,
        index=True,
    )
    code: Mapped[str] = mapped_column(String(40), nullable=False)
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)


class WorkAreaRecord(CatalogRecordMixin, Base):
    __tablename__ = "work_areas"

    name: Mapped[str] = mapped_column(String(160), nullable=False, unique=True)
    description: Mapped[str | None] = mapped_column(Text)
