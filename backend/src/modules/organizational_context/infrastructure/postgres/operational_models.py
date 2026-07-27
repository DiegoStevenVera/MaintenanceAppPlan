from datetime import date
from uuid import UUID

from sqlalchemy import (
    CheckConstraint,
    Date,
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


class GeographicLocationRecord(CatalogRecordMixin, Base):
    __tablename__ = "geographic_locations"
    __table_args__ = (
        CheckConstraint("level BETWEEN 1 AND 4", name="ck_geographic_locations_level"),
        UniqueConstraint(
            "parent_location_id",
            "name",
            name="uq_geographic_locations_parent_name",
        ),
    )

    name: Mapped[str] = mapped_column(String(200), nullable=False, index=True)
    location_type_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("location_types.id"),
        index=True,
    )
    parent_location_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("geographic_locations.id"),
        index=True,
    )
    level: Mapped[int] = mapped_column(Integer, nullable=False)
    full_path: Mapped[str] = mapped_column(Text, nullable=False)


class AssetStageAssignmentRecord(OperationalRecordMixin, Base):
    __tablename__ = "asset_stage_assignments"
    __table_args__ = (
        UniqueConstraint(
            "asset_id",
            "stage_id",
            "valid_from",
            name="uq_asset_stage_assignments_period",
        ),
    )

    legacy_id: Mapped[int | None] = mapped_column(Integer, unique=True)
    asset_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("assets.id"),
        nullable=False,
        index=True,
    )
    stage_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("stages.id"),
        nullable=False,
        index=True,
    )
    role: Mapped[str] = mapped_column(String(40), nullable=False)
    valid_from: Mapped[date] = mapped_column(Date, nullable=False)
    valid_to: Mapped[date | None] = mapped_column(Date)


class LocationStageAssignmentRecord(OperationalRecordMixin, Base):
    __tablename__ = "location_stage_assignments"
    __table_args__ = (
        UniqueConstraint(
            "location_id",
            "stage_id",
            "valid_from",
            name="uq_location_stage_assignments_period",
        ),
    )

    legacy_id: Mapped[int | None] = mapped_column(Integer, unique=True)
    location_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("geographic_locations.id"),
        nullable=False,
        index=True,
    )
    stage_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("stages.id"),
        nullable=False,
        index=True,
    )
    role: Mapped[str] = mapped_column(String(40), nullable=False)
    valid_from: Mapped[date] = mapped_column(Date, nullable=False)
    valid_to: Mapped[date | None] = mapped_column(Date)
