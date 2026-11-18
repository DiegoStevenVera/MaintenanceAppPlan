"""Add equipment-specific internal slots without modifying imported slots."""

import sqlalchemy as sa
from alembic import op

revision = "20261117_0033"
down_revision = "20261116_0032"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("slot_locations", sa.Column("equipment_asset_id", sa.String(80)))
    op.create_foreign_key(
        "fk_slot_locations_equipment_asset", "slot_locations", "assets",
        ["equipment_asset_id"], ["id"],
    )
    op.create_index("ix_slot_locations_equipment_asset_id", "slot_locations", ["equipment_asset_id"])
    op.alter_column("slot_locations", "equipment_kind_id", nullable=True)
    op.create_check_constraint(
        "ck_slot_locations_scope", "slot_locations",
        "equipment_kind_id IS NOT NULL OR equipment_asset_id IS NOT NULL",
    )


def downgrade() -> None:
    op.execute(sa.text("""DO $$ BEGIN
        IF EXISTS (SELECT 1 FROM slot_locations WHERE equipment_asset_id IS NOT NULL) THEN
            RAISE EXCEPTION 'Cannot downgrade while equipment-specific slots exist';
        END IF;
    END $$"""))
    op.drop_constraint("ck_slot_locations_scope", "slot_locations", type_="check")
    op.alter_column("slot_locations", "equipment_kind_id", nullable=False)
    op.drop_index("ix_slot_locations_equipment_asset_id", table_name="slot_locations")
    op.drop_constraint("fk_slot_locations_equipment_asset", "slot_locations", type_="foreignkey")
    op.drop_column("slot_locations", "equipment_asset_id")
