"""Create the warehouse inventory master and image references."""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


revision: str = "20260915_0021"
down_revision: str | Sequence[str] | None = "20260915_0020"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "tool_inventory_items",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("source_file", sa.String(255), nullable=False),
        sa.Column("source_row_number", sa.Integer(), nullable=False),
        sa.Column(
            "catalog_item_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("tool_catalog_items.id", ondelete="SET NULL"),
        ),
        sa.Column("model_code", sa.String(160)),
        sa.Column("tool_code", sa.String(160)),
        sa.Column("label", sa.String(80)),
        sa.Column("quantity", sa.Numeric(18, 3), nullable=False, server_default="0"),
        sa.Column("name", sa.String(240), nullable=False),
        sa.Column("description", sa.Text()),
        sa.Column("cabinet", sa.String(200)),
        sa.Column("cabinet_detail", sa.String(200)),
        sa.Column("company", sa.String(200)),
        sa.Column("classification", sa.String(100)),
        sa.Column("category", sa.String(120)),
        sa.Column(
            "inventory_location_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("inventory_locations.id", ondelete="SET NULL"),
        ),
        sa.Column("location_text", sa.String(200)),
        sa.Column("status", sa.String(60)),
        sa.Column("observations", sa.Text()),
        sa.Column("imported_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("source_file", "source_row_number", name="uq_tool_inventory_item_source_row"),
    )
    op.create_index("ix_tool_inventory_items_label", "tool_inventory_items", ["label"])
    op.create_index("ix_tool_inventory_items_code", "tool_inventory_items", ["tool_code"])
    op.create_index("ix_tool_inventory_items_status", "tool_inventory_items", ["status"])
    op.create_index("ix_tool_inventory_items_location", "tool_inventory_items", ["inventory_location_id"])
    op.create_index("ix_tool_inventory_items_catalog_item_id", "tool_inventory_items", ["catalog_item_id"])

    op.create_table(
        "tool_inventory_item_images",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "inventory_item_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("tool_inventory_items.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("file_name", sa.String(255), nullable=False),
        sa.Column("file_reference", sa.Text(), nullable=False),
        sa.Column("media_type", sa.String(100), nullable=False),
        sa.Column("byte_size", sa.Integer(), nullable=False),
        sa.Column("checksum", sa.String(64), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("inventory_item_id", "file_name", name="uq_tool_inventory_item_image_name"),
    )
    op.create_index(
        "ix_tool_inventory_item_images_inventory_item_id",
        "tool_inventory_item_images",
        ["inventory_item_id"],
    )


def downgrade() -> None:
    op.drop_table("tool_inventory_item_images")
    op.drop_index("ix_tool_inventory_items_catalog_item_id", table_name="tool_inventory_items")
    op.drop_index("ix_tool_inventory_items_location", table_name="tool_inventory_items")
    op.drop_index("ix_tool_inventory_items_status", table_name="tool_inventory_items")
    op.drop_index("ix_tool_inventory_items_code", table_name="tool_inventory_items")
    op.drop_index("ix_tool_inventory_items_label", table_name="tool_inventory_items")
    op.drop_table("tool_inventory_items")
