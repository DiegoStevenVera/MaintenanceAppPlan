"""Link quantity-based tool balances to individual inventory rows."""

import sqlalchemy as sa
from alembic import op

revision = "20261116_0031"
down_revision = "20261112_0030"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("tool_inventory", sa.Column("inventory_item_id", sa.Uuid(), nullable=True))
    op.create_foreign_key(
        "fk_tool_inventory_item", "tool_inventory", "tool_inventory_items",
        ["inventory_item_id"], ["id"],
    )
    op.create_unique_constraint(
        "uq_tool_inventory_item", "tool_inventory", ["inventory_item_id"]
    )
    op.drop_index("uq_tool_inventory_bulk_location", table_name="tool_inventory")
    op.create_index(
        "uq_tool_inventory_bulk_location", "tool_inventory", ["catalog_item_id", "location"],
        unique=True, postgresql_where=sa.text("tool_id IS NULL AND inventory_item_id IS NULL"),
    )


def downgrade() -> None:
    op.execute(sa.text("""DO $$ BEGIN
        IF EXISTS (SELECT 1 FROM tool_inventory WHERE inventory_item_id IS NOT NULL) THEN
            RAISE EXCEPTION 'Cannot downgrade after inventory rows have recorded movements';
        END IF;
    END $$"""))
    op.drop_index("uq_tool_inventory_bulk_location", table_name="tool_inventory")
    op.create_index(
        "uq_tool_inventory_bulk_location", "tool_inventory", ["catalog_item_id", "location"],
        unique=True, postgresql_where=sa.text("tool_id IS NULL"),
    )
    op.drop_constraint("uq_tool_inventory_item", "tool_inventory", type_="unique")
    op.drop_constraint("fk_tool_inventory_item", "tool_inventory", type_="foreignkey")
    op.drop_column("tool_inventory", "inventory_item_id")
