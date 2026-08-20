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
    func,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class AssetRecord(Base):
    __tablename__ = "assets"
    __table_args__ = (
        UniqueConstraint("serial_number", name="uq_assets_serial_number"),
    )

    id: Mapped[str] = mapped_column(String(80), primary_key=True)
    name: Mapped[str] = mapped_column(String(240), nullable=False, index=True)
    category: Mapped[str] = mapped_column(String(120), nullable=False)
    asset_type: Mapped[str] = mapped_column(String(120), nullable=False)
    subsystem: Mapped[str] = mapped_column(String(40), nullable=False, index=True)
    serial_or_code: Mapped[str] = mapped_column(String(120), nullable=False)
    part_number: Mapped[str | None] = mapped_column(String(120))
    status: Mapped[str] = mapped_column(String(80), nullable=False)
    physical_location: Mapped[str] = mapped_column(Text, nullable=False)
    is_business_anchor: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    parent_id: Mapped[str | None] = mapped_column(ForeignKey("assets.id"))
    children: Mapped[list[str]] = mapped_column(JSONB, nullable=False, default=list)
    legacy_id: Mapped[int | None] = mapped_column(Integer, unique=True)
    asset_type_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("asset_types.id"),
        index=True,
    )
    equipment_category_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("equipment_categories.id"),
        index=True,
    )
    equipment_kind_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("equipment_kinds.id"),
        index=True,
    )
    subsystem_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("subsystems.id"),
        index=True,
    )
    manufacturer_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("manufacturers.id"),
        index=True,
    )
    status_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("asset_statuses.id"),
        index=True,
    )
    current_geographic_location_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("geographic_locations.id"),
        index=True,
    )
    current_inventory_location_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey(
            "inventory_locations.id",
            use_alter=True,
            name="fk_assets_current_inventory_location_id",
        ),
        index=True,
    )
    current_slot_location_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("slot_locations.id"),
        index=True,
    )
    internal_code: Mapped[str | None] = mapped_column(String(120), unique=True)
    serial_number: Mapped[str | None] = mapped_column(String(120), index=True)
    serial_number_status: Mapped[str | None] = mapped_column(String(30))
    model: Mapped[str | None] = mapped_column(String(120))
    manufacture_date: Mapped[date | None] = mapped_column(Date)
    software_version: Mapped[str | None] = mapped_column(String(120))
    current_position: Mapped[str | None] = mapped_column(String(200))
    business_label: Mapped[str | None] = mapped_column(String(100))
    registration_method: Mapped[str | None] = mapped_column(String(30))
    is_mobile: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )


class AssetGroupRecord(Base):
    """Operational grouping for preventive maintenance; never a physical asset."""

    __tablename__ = "asset_groups"
    __table_args__ = (UniqueConstraint("code", name="uq_asset_groups_code"),)

    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True)
    code: Mapped[str] = mapped_column(String(160), nullable=False)
    name: Mapped[str] = mapped_column(String(240), nullable=False, index=True)
    subsystem_id: Mapped[UUID | None] = mapped_column(Uuid, ForeignKey("subsystems.id"), index=True)
    geographic_location_id: Mapped[UUID | None] = mapped_column(Uuid, ForeignKey("geographic_locations.id"), index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now())


class AssetGroupMemberRecord(Base):
    __tablename__ = "asset_group_members"
    __table_args__ = (UniqueConstraint("asset_group_id", "asset_id", name="uq_asset_group_member"),)

    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True)
    asset_group_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("asset_groups.id", ondelete="CASCADE"), nullable=False, index=True)
    asset_id: Mapped[str] = mapped_column(String(80), ForeignKey("assets.id"), nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now())


class AssetHistoryRecord(Base):
    __tablename__ = "asset_history"

    id: Mapped[str] = mapped_column(String(80), primary_key=True)
    asset_id: Mapped[str] = mapped_column(ForeignKey("assets.id"), nullable=False, index=True)
    report_type: Mapped[str] = mapped_column(String(40), nullable=False)
    report_id: Mapped[str] = mapped_column(String(120), nullable=False)
    title: Mapped[str] = mapped_column(String(240), nullable=False)
    performed_at: Mapped[str] = mapped_column(String(80), nullable=False)
    result: Mapped[str] = mapped_column(String(120), nullable=False)
