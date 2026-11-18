"""Share internal space structure across equipment of the same catalog type."""

from alembic import op

revision = "20261117_0034"
down_revision = "20261117_0033"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("""
    CREATE UNIQUE INDEX uq_equipment_slot_path ON slot_locations (equipment_asset_id, path)
    WHERE equipment_asset_id IS NOT NULL;
    """)
    op.execute("""
    CREATE FUNCTION sync_equipment_slot_structure(root_id text) RETURNS void
    LANGUAGE plpgsql AS $$
    DECLARE current_level integer;
    BEGIN
      PERFORM pg_advisory_xact_lock(20261117);
      FOR current_level IN 1..12 LOOP
        INSERT INTO slot_locations (
          id, equipment_asset_id, slot_type_id, name, parent_slot_location_id,
          level, path, is_leaf, accepts_asset, is_active, sequence
        )
        SELECT DISTINCT ON (target.id, source.path)
          gen_random_uuid(), target.id, source.slot_type_id, source.name, target_parent.id,
          source.level, source.path, source.is_leaf, source.accepts_asset, true, source.sequence
        FROM assets root
        JOIN assets source_owner ON source_owner.is_business_anchor
          AND source_owner.equipment_category_id IS NOT DISTINCT FROM root.equipment_category_id
          AND source_owner.asset_type = root.asset_type
          AND source_owner.category = root.category
          AND source_owner.subsystem = root.subsystem
        JOIN slot_locations source ON source.equipment_asset_id = source_owner.id
          AND source.is_active AND source.level = current_level
        JOIN assets target ON target.is_business_anchor
          AND target.equipment_category_id IS NOT DISTINCT FROM root.equipment_category_id
          AND target.asset_type = root.asset_type
          AND target.category = root.category
          AND target.subsystem = root.subsystem
        LEFT JOIN slot_locations source_parent ON source_parent.id = source.parent_slot_location_id
        LEFT JOIN slot_locations target_parent ON target_parent.equipment_asset_id = target.id
          AND target_parent.path = source_parent.path
        WHERE root.id = root_id AND root.is_business_anchor
          AND (source.parent_slot_location_id IS NULL OR target_parent.id IS NOT NULL)
        ORDER BY target.id, source.path, source.accepts_asset, source.id
        ON CONFLICT (equipment_asset_id, path) WHERE equipment_asset_id IS NOT NULL DO NOTHING;
      END LOOP;
      UPDATE slot_locations slot SET is_leaf = NOT EXISTS (
        SELECT 1 FROM slot_locations child WHERE child.parent_slot_location_id = slot.id
      ) WHERE slot.equipment_asset_id IS NOT NULL;
    END $$;
    """)
    op.execute("""
    DO $$ DECLARE owner_id text; BEGIN
      FOR owner_id IN SELECT DISTINCT equipment_asset_id FROM slot_locations
                      WHERE equipment_asset_id IS NOT NULL LOOP
        PERFORM sync_equipment_slot_structure(owner_id);
      END LOOP;
    END $$;
    """)


def downgrade() -> None:
    op.execute("DROP FUNCTION sync_equipment_slot_structure(text)")
    op.drop_index("uq_equipment_slot_path", table_name="slot_locations")
