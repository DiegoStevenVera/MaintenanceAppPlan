from datetime import datetime
from decimal import Decimal
from uuid import UUID, uuid4

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    JSON,
    Numeric,
    String,
    Text,
    Uuid,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base


class ToolInventoryRecord(Base):
    __tablename__ = "tool_inventory"
    __table_args__ = (
        CheckConstraint(
            "available >= 0 AND unavailable >= 0", name="ck_tool_inventory_nonnegative"
        ),
        Index(
            "uq_tool_inventory_bulk_location",
            "catalog_item_id",
            "location",
            unique=True,
            postgresql_where=text("tool_id IS NULL"),
        ),
    )
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    catalog_item_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("tool_catalog_items.id"))
    tool_id: Mapped[UUID | None] = mapped_column(Uuid, ForeignKey("tools.id"), unique=True)
    location: Mapped[str] = mapped_column(String(200))
    available: Mapped[Decimal] = mapped_column(Numeric(18, 3), default=0)
    unavailable: Mapped[Decimal] = mapped_column(Numeric(18, 3), default=0)


class ToolMovementRecord(Base):
    __tablename__ = "tool_inventory_movements"
    __table_args__ = (
        CheckConstraint("quantity > 0", name="ck_tool_movement_positive"),
        CheckConstraint(
            "kind IN ('RECEIPT','ISSUE','RETURN','CONSUMED','DAMAGED','LOST','ADJUST_ADD','ADJUST_REMOVE')",
            name="ck_tool_movement_kind",
        ),
    )
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True)
    inventory_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("tool_inventory.id"), index=True)
    kind: Mapped[str] = mapped_column(String(30))
    quantity: Mapped[Decimal] = mapped_column(Numeric(18, 3))
    issue_id: Mapped[UUID | None] = mapped_column(
        Uuid, ForeignKey("tool_inventory_movements.id"), index=True
    )
    responsible_user_id: Mapped[str | None] = mapped_column(String(80), ForeignKey("users.id"))
    actor_user_id: Mapped[str] = mapped_column(String(80), ForeignKey("users.id"))
    activity_ids: Mapped[list[str]] = mapped_column(JSON, default=list)
    notes: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
