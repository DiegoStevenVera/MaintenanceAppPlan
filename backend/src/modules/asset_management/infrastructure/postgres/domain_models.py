from datetime import datetime
from uuid import UUID

from sqlalchemy import (
    Boolean,
    CheckConstraint,
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
from shared_kernel.persistence import CatalogRecordMixin, OperationalRecordMixin


class AssetTypeRecord(CatalogRecordMixin, Base):
    __tablename__ = "asset_types"

    name: Mapped[str] = mapped_column(String(160), nullable=False, unique=True)
    category: Mapped[str] = mapped_column(String(40), nullable=False)
    serial_number_policy: Mapped[str] = mapped_column(String(30), nullable=False)
    part_number_policy: Mapped[str] = mapped_column(String(30), nullable=False)
    part_number: Mapped[str | None] = mapped_column(String(120), index=True)
    supports_version: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    description: Mapped[str | None] = mapped_column(Text)


class EquipmentKindCategoryRecord(OperationalRecordMixin, Base):
    __tablename__ = "equipment_kind_categories"
    __table_args__ = (
        UniqueConstraint(
            "equipment_kind_id",
            "equipment_category_id",
            name="uq_equipment_kind_categories_pair",
        ),
    )

    equipment_kind_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("equipment_kinds.id"),
        nullable=False,
        index=True,
    )
    equipment_category_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("equipment_categories.id"),
        nullable=False,
        index=True,
    )


class SlotLocationRecord(CatalogRecordMixin, Base):
    __tablename__ = "slot_locations"
    __table_args__ = (
        CheckConstraint("level >= 1", name="ck_slot_locations_level"),
        UniqueConstraint(
            "equipment_kind_id",
            "parent_slot_location_id",
            "name",
            name="uq_slot_locations_kind_parent_name",
        ),
    )

    equipment_kind_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("equipment_kinds.id"),
        nullable=False,
        index=True,
    )
    slot_type_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("slot_types.id"),
        nullable=False,
        index=True,
    )
    parent_slot_location_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("slot_locations.id"),
        index=True,
    )
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    level: Mapped[int] = mapped_column(Integer, nullable=False)
    sequence: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    path: Mapped[str] = mapped_column(Text, nullable=False)
    is_leaf: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    accepts_asset: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)


class DocumentationResourceRecord(CatalogRecordMixin, Base):
    __tablename__ = "documentation_resources"

    name: Mapped[str] = mapped_column(String(240), nullable=False)
    file_reference: Mapped[str] = mapped_column(Text, nullable=False)
    tags: Mapped[list[str]] = mapped_column(JSONB, nullable=False, default=list)
    title: Mapped[str | None] = mapped_column(String(240))
    work_area_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("work_areas.id"),
        index=True,
    )


class SlotImageRecord(CatalogRecordMixin, Base):
    __tablename__ = "slot_images"

    equipment_kind_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("equipment_kinds.id"),
        nullable=False,
        index=True,
    )
    slot_location_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("slot_locations.id"),
        index=True,
    )
    documentation_resource_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("documentation_resources.id"),
        index=True,
    )
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    file_reference: Mapped[str] = mapped_column(Text, nullable=False)
    page_number: Mapped[int | None] = mapped_column(Integer)


class InventoryLocationRecord(CatalogRecordMixin, Base):
    __tablename__ = "inventory_locations"

    location_type_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("location_types.id"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(200), nullable=False, unique=True)
    related_asset_id: Mapped[str | None] = mapped_column(
        String(80),
        ForeignKey("assets.id"),
        index=True,
    )
    description: Mapped[str | None] = mapped_column(Text)


class AssetCompositionRuleRecord(OperationalRecordMixin, Base):
    __tablename__ = "asset_composition_rules"
    __table_args__ = (
        CheckConstraint("min_quantity >= 0", name="ck_asset_composition_rules_min"),
        CheckConstraint(
            "max_quantity IS NULL OR max_quantity >= min_quantity",
            name="ck_asset_composition_rules_max",
        ),
        UniqueConstraint(
            "subsystem_id",
            "parent_asset_type_id",
            "child_asset_type_id",
            name="uq_asset_composition_rules_scope",
        ),
    )

    subsystem_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("subsystems.id"),
        nullable=False,
        index=True,
    )
    parent_asset_type_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("asset_types.id"),
        nullable=False,
        index=True,
    )
    child_asset_type_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("asset_types.id"),
        nullable=False,
        index=True,
    )
    min_quantity: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    max_quantity: Mapped[int | None] = mapped_column(Integer)
    child_order_index: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    enforcement_mode: Mapped[str] = mapped_column(String(30), nullable=False, default="ADVISORY")


class AssetCompositionPositionRecord(OperationalRecordMixin, Base):
    __tablename__ = "asset_composition_positions"
    __table_args__ = (
        UniqueConstraint(
            "composition_rule_id",
            "position",
            name="uq_asset_composition_positions_rule_position",
        ),
    )

    composition_rule_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("asset_composition_rules.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    position: Mapped[str] = mapped_column(String(200), nullable=False)
    sequence: Mapped[int] = mapped_column(Integer, nullable=False, default=0)


class AssetAssignmentRecord(OperationalRecordMixin, Base):
    __tablename__ = "asset_assignments"

    legacy_id: Mapped[int | None] = mapped_column(Integer, unique=True)
    asset_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("assets.id"),
        nullable=False,
        index=True,
    )
    parent_asset_id: Mapped[str | None] = mapped_column(
        String(80),
        ForeignKey("assets.id"),
        index=True,
    )
    slot_location_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("slot_locations.id"),
        index=True,
    )
    geographic_location_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("geographic_locations.id"),
        index=True,
    )
    position_snapshot: Mapped[str | None] = mapped_column(String(200))
    assigned_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    unassigned_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    reason: Mapped[str | None] = mapped_column(Text)
    source_report_version_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("report_versions.id"),
        index=True,
    )


class AssetClosureRecord(Base):
    __tablename__ = "asset_closure"
    __table_args__ = (
        CheckConstraint("depth >= 0", name="ck_asset_closure_depth"),
    )

    ancestor_asset_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("assets.id", ondelete="CASCADE"),
        primary_key=True,
    )
    descendant_asset_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("assets.id", ondelete="CASCADE"),
        primary_key=True,
    )
    depth: Mapped[int] = mapped_column(Integer, nullable=False)


class AssetMovementRecord(OperationalRecordMixin, Base):
    __tablename__ = "asset_movements"

    legacy_id: Mapped[int | None] = mapped_column(Integer, unique=True)
    asset_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("assets.id"),
        nullable=False,
        index=True,
    )
    movement_type_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("movement_types.id"),
        nullable=False,
        index=True,
    )
    from_inventory_location_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("inventory_locations.id"),
    )
    to_inventory_location_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("inventory_locations.id"),
    )
    from_slot_location_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("slot_locations.id"),
    )
    to_slot_location_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("slot_locations.id"),
    )
    from_status_id: Mapped[UUID | None] = mapped_column(Uuid, ForeignKey("asset_statuses.id"))
    to_status_id: Mapped[UUID | None] = mapped_column(Uuid, ForeignKey("asset_statuses.id"))
    moved_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    moved_by_user_id: Mapped[str | None] = mapped_column(String(80), ForeignKey("users.id"))
    maintenance_activity_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("maintenance_activities.id"),
        index=True,
    )
    corrective_activity_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("corrective_activities.id"),
        index=True,
    )
    notes: Mapped[str | None] = mapped_column(Text)
    movement_key: Mapped[str | None] = mapped_column(String(200), unique=True)


class AssetReplacementRecord(OperationalRecordMixin, Base):
    __tablename__ = "asset_replacements"

    legacy_id: Mapped[int | None] = mapped_column(Integer, unique=True)
    removed_asset_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("assets.id"),
        nullable=False,
        index=True,
    )
    installed_asset_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("assets.id"),
        nullable=False,
        index=True,
    )
    parent_asset_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("assets.id"),
        nullable=False,
        index=True,
    )
    slot_location_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("slot_locations.id"),
    )
    position_snapshot: Mapped[str] = mapped_column(String(200), nullable=False)
    source_description: Mapped[str] = mapped_column(Text, nullable=False)
    source_kind: Mapped[str] = mapped_column(
        String(40), nullable=False, default="WAREHOUSE"
    )
    donor_parent_asset_id: Mapped[str | None] = mapped_column(
        String(80), ForeignKey("assets.id"), index=True
    )
    destination_description: Mapped[str] = mapped_column(Text, nullable=False)
    replaced_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    responsible_user_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("users.id"),
        nullable=False,
    )
    maintenance_activity_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("maintenance_activities.id"),
        index=True,
    )
    report_version_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("report_versions.id"),
        index=True,
    )
    corrective_activity_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("corrective_activities.id"),
        index=True,
    )
    removed_condition: Mapped[str | None] = mapped_column(String(80))
    installed_condition: Mapped[str | None] = mapped_column(String(80))
    reason: Mapped[str] = mapped_column(Text, nullable=False)
