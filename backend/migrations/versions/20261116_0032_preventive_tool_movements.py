"""Identify tool movements created by the preventive lifecycle."""

import sqlalchemy as sa
from alembic import op

revision = "20261116_0032"
down_revision = "20261116_0031"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "tool_inventory_movements", sa.Column("automatic_activity_id", sa.Uuid(), nullable=True),
    )
    op.create_foreign_key(
        "fk_tool_movement_automatic_activity", "tool_inventory_movements", "maintenance_activities",
        ["automatic_activity_id"], ["id"],
    )
    op.create_index(
        "ix_tool_inventory_movements_automatic_activity_id",
        "tool_inventory_movements", ["automatic_activity_id"],
    )


def downgrade() -> None:
    op.execute(sa.text("""DO $$ BEGIN
        IF EXISTS (SELECT 1 FROM tool_inventory_movements WHERE automatic_activity_id IS NOT NULL) THEN
            RAISE EXCEPTION 'Cannot downgrade with automatic preventive movements';
        END IF;
    END $$"""))
    op.drop_index(
        "ix_tool_inventory_movements_automatic_activity_id", table_name="tool_inventory_movements",
    )
    op.drop_constraint(
        "fk_tool_movement_automatic_activity", "tool_inventory_movements", type_="foreignkey",
    )
    op.drop_column("tool_inventory_movements", "automatic_activity_id")
