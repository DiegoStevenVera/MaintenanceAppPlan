from datetime import datetime
from decimal import Decimal
from uuid import UUID

from sqlalchemy import DateTime, ForeignKey, Index, Numeric, String, Text, UniqueConstraint, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base
from shared_kernel.persistence import OperationalRecordMixin


class ToolInventoryItemRecord(OperationalRecordMixin, Base):
    """One physical or quantity-based row from the warehouse inventory source."""

    __tablename__ = "tool_inventory_items"
    __table_args__ = (
        UniqueConstraint("source_file", "source_row_number", name="uq_tool_inventory_item_source_row"),
        Index("ix_tool_inventory_items_label", "label"),
        Index("ix_tool_inventory_items_code", "tool_code"),
        Index("ix_tool_inventory_items_status", "status"),
        Index("ix_tool_inventory_items_location", "inventory_location_id"),
    )

    source_file: Mapped[str] = mapped_column(String(255), nullable=False)
    source_row_number: Mapped[int] = mapped_column(nullable=False)
    catalog_item_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("tool_catalog_items.id", ondelete="SET NULL"),
        index=True,
    )
    tool_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("tools.id", ondelete="SET NULL"),
    )
    model_code: Mapped[str | None] = mapped_column(String(160))
    tool_code: Mapped[str | None] = mapped_column(String(160))
    label: Mapped[str | None] = mapped_column(String(80))
    quantity: Mapped[Decimal] = mapped_column(Numeric(18, 3), nullable=False, default=0)
    name: Mapped[str] = mapped_column(String(240), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    cabinet: Mapped[str | None] = mapped_column(String(200))
    cabinet_detail: Mapped[str | None] = mapped_column(String(200))
    company: Mapped[str | None] = mapped_column(String(200))
    classification: Mapped[str | None] = mapped_column(String(100))
    category: Mapped[str | None] = mapped_column(String(120))
    inventory_location_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("inventory_locations.id", ondelete="SET NULL"),
        index=True,
    )
    location_text: Mapped[str | None] = mapped_column(String(200))
    status: Mapped[str | None] = mapped_column(String(60))
    observations: Mapped[str | None] = mapped_column(Text)
    imported_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class ToolInventoryItemImageRecord(OperationalRecordMixin, Base):
    __tablename__ = "tool_inventory_item_images"
    __table_args__ = (
        UniqueConstraint(
            "inventory_item_id",
            "file_name",
            name="uq_tool_inventory_item_image_name",
        ),
    )

    inventory_item_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("tool_inventory_items.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    file_name: Mapped[str] = mapped_column(String(255), nullable=False)
    file_reference: Mapped[str] = mapped_column(Text, nullable=False)
    media_type: Mapped[str] = mapped_column(String(100), nullable=False)
    byte_size: Mapped[int] = mapped_column(nullable=False)
    checksum: Mapped[str] = mapped_column(String(64), nullable=False)
