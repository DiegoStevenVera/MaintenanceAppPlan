from uuid import UUID

from sqlalchemy import ForeignKey, String, Text, UniqueConstraint, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base
from shared_kernel.persistence import CatalogRecordMixin


class EquipmentCategoryRecord(CatalogRecordMixin, Base):
    __tablename__ = "equipment_categories"
    __table_args__ = (
        UniqueConstraint(
            "subsystem_id",
            "name_n1",
            "name_n2",
            name="uq_equipment_categories_scope_names",
        ),
    )

    subsystem_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("subsystems.id"),
        nullable=False,
        index=True,
    )
    name_n1: Mapped[str] = mapped_column(String(160), nullable=False)
    name_n2: Mapped[str] = mapped_column(String(160), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)


class EquipmentKindRecord(CatalogRecordMixin, Base):
    __tablename__ = "equipment_kinds"

    name: Mapped[str] = mapped_column(String(160), nullable=False, unique=True)
    description: Mapped[str | None] = mapped_column(Text)


class SlotTypeRecord(CatalogRecordMixin, Base):
    __tablename__ = "slot_types"

    name: Mapped[str] = mapped_column(String(120), nullable=False, unique=True)
    description: Mapped[str | None] = mapped_column(Text)


class AssetStatusRecord(CatalogRecordMixin, Base):
    __tablename__ = "asset_statuses"

    code: Mapped[str] = mapped_column(String(60), nullable=False, unique=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False, unique=True)
    description: Mapped[str | None] = mapped_column(Text)


class MovementTypeRecord(CatalogRecordMixin, Base):
    __tablename__ = "movement_types"

    code: Mapped[str] = mapped_column(String(60), nullable=False, unique=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False, unique=True)
    description: Mapped[str | None] = mapped_column(Text)


class LocationTypeRecord(CatalogRecordMixin, Base):
    __tablename__ = "location_types"

    code: Mapped[str] = mapped_column(String(60), nullable=False, unique=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False, unique=True)
    description: Mapped[str | None] = mapped_column(Text)


class ManufacturerRecord(CatalogRecordMixin, Base):
    __tablename__ = "manufacturers"

    name: Mapped[str] = mapped_column(String(160), nullable=False, unique=True)
    description: Mapped[str | None] = mapped_column(Text)
