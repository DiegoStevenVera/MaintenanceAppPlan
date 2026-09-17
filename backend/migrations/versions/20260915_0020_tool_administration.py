"""Tool inventory, movements and checklist publication audit."""

from alembic import op
import sqlalchemy as sa

revision = "20260915_0020"
down_revision = "20260910_0019"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        "maintenance_operational_checklist_revisions",
        sa.Column("created_by_user_id", sa.String(80), sa.ForeignKey("users.id")),
    )
    op.create_table(
        "tool_inventory",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "catalog_item_id", sa.Uuid(), sa.ForeignKey("tool_catalog_items.id"), nullable=False
        ),
        sa.Column("tool_id", sa.Uuid(), sa.ForeignKey("tools.id"), unique=True),
        sa.Column("location", sa.String(200), nullable=False),
        sa.Column("available", sa.Numeric(18, 3), nullable=False, server_default="0"),
        sa.Column("unavailable", sa.Numeric(18, 3), nullable=False, server_default="0"),
        sa.CheckConstraint(
            "available >= 0 AND unavailable >= 0", name="ck_tool_inventory_nonnegative"
        ),
    )
    op.create_index(
        "uq_tool_inventory_bulk_location",
        "tool_inventory",
        ["catalog_item_id", "location"],
        unique=True,
        postgresql_where=sa.text("tool_id IS NULL"),
    )
    op.create_table(
        "tool_inventory_movements",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "inventory_id",
            sa.Uuid(),
            sa.ForeignKey("tool_inventory.id"),
            nullable=False,
            index=True,
        ),
        sa.Column("kind", sa.String(30), nullable=False),
        sa.Column("quantity", sa.Numeric(18, 3), nullable=False),
        sa.Column("issue_id", sa.Uuid(), sa.ForeignKey("tool_inventory_movements.id"), index=True),
        sa.Column("responsible_user_id", sa.String(80), sa.ForeignKey("users.id")),
        sa.Column("actor_user_id", sa.String(80), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("activity_ids", sa.JSON(), nullable=False),
        sa.Column("notes", sa.Text()),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.CheckConstraint("quantity > 0", name="ck_tool_movement_positive"),
        sa.CheckConstraint(
            "kind IN ('RECEIPT','ISSUE','RETURN','CONSUMED','DAMAGED','LOST','ADJUST_ADD','ADJUST_REMOVE')",
            name="ck_tool_movement_kind",
        ),
    )
    # Keep existing identified equipment available to reports. Opening balances
    # preserve the imported status; no fictional receipts or owners are created.
    op.execute("""INSERT INTO tool_inventory (id,catalog_item_id,tool_id,location,available,unavailable)
        SELECT id,catalog_item_id,id,coalesce(nullif(current_location,''),'Sin ubicación'),
        CASE WHEN upper(availability_status) IN ('AVAILABLE','DISPONIBLE','IN_STOCK') THEN 1 ELSE 0 END,
        CASE WHEN upper(availability_status) IN ('AVAILABLE','DISPONIBLE','IN_STOCK') THEN 0 ELSE 1 END
        FROM tools WHERE catalog_item_id IS NOT NULL AND is_active""")


def downgrade():
    op.drop_table("tool_inventory_movements")
    op.drop_table("tool_inventory")
    op.drop_column("maintenance_operational_checklist_revisions", "created_by_user_id")
