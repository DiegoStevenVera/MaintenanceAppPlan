"""normalize preventive asset groups and corrective criticality

Revision ID: 20260819_0013
Revises: 20260819_0012
Create Date: 2026-08-19
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


revision: str = "20260819_0013"
down_revision: str | None = "20260819_0012"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "asset_groups",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("code", sa.String(160), nullable=False),
        sa.Column("name", sa.String(240), nullable=False),
        sa.Column("subsystem_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("subsystems.id")),
        sa.Column("geographic_location_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("geographic_locations.id")),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.UniqueConstraint("code", name="uq_asset_groups_code"),
    )
    op.create_index("ix_asset_groups_name", "asset_groups", ["name"])
    op.create_index("ix_asset_groups_subsystem_id", "asset_groups", ["subsystem_id"])
    op.create_table(
        "asset_group_members",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("asset_group_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("asset_groups.id", ondelete="CASCADE"), nullable=False),
        sa.Column("asset_id", sa.String(80), sa.ForeignKey("assets.id"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.UniqueConstraint("asset_group_id", "asset_id", name="uq_asset_group_member"),
    )
    op.create_index("ix_asset_group_members_asset_group_id", "asset_group_members", ["asset_group_id"])
    op.create_index("ix_asset_group_members_asset_id", "asset_group_members", ["asset_id"])
    op.add_column("maintenance_template_scopes", sa.Column("asset_group_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("asset_groups.id")))
    op.create_index("ix_maintenance_template_scopes_asset_group_id", "maintenance_template_scopes", ["asset_group_id"])
    op.add_column("corrective_events", sa.Column("is_critical", sa.Boolean(), nullable=False, server_default=sa.false()))

    # Every preventive scope uses the same group-to-asset model, including 1:1 scopes.
    op.execute("""
        INSERT INTO asset_groups (id, code, name, subsystem_id, geographic_location_id, is_active, created_at, updated_at)
        SELECT gen_random_uuid(), 'LEGACY-ASSET-' || a.id, a.name, a.subsystem_id,
               mts.geographic_location_id, true, now(), now()
        FROM maintenance_template_scopes mts
        JOIN assets a ON a.id = mts.asset_id
        GROUP BY a.id, a.name, a.subsystem_id, mts.geographic_location_id
        ON CONFLICT (code) DO NOTHING
    """)
    op.execute("""
        UPDATE maintenance_template_scopes mts
        SET asset_group_id = ag.id
        FROM asset_groups ag
        WHERE ag.code = 'LEGACY-ASSET-' || mts.asset_id
    """)
    op.execute("""
        INSERT INTO asset_group_members (id, asset_group_id, asset_id, created_at, updated_at)
        SELECT gen_random_uuid(), ag.id, mts.asset_id, now(), now()
        FROM maintenance_template_scopes mts
        JOIN asset_groups ag ON ag.id = mts.asset_group_id
        WHERE mts.asset_id IS NOT NULL
        ON CONFLICT (asset_group_id, asset_id) DO NOTHING
    """)

    # Split legacy cabinet group rows into physical cabinet assets using the already
    # captured physical location of their children. The old rows remain only for
    # historical traceability and cease to be selectable assets.
    op.execute("""
        INSERT INTO assets (
            id, name, category, asset_type, subsystem, serial_or_code, status,
            physical_location, is_business_anchor, parent_id, children, asset_type_id,
            equipment_category_id, equipment_kind_id, subsystem_id, manufacturer_id,
            status_id, current_geographic_location_id, current_inventory_location_id,
            current_slot_location_id, internal_code, serial_number, serial_number_status,
            model, manufacture_date, software_version, current_position, business_label,
            registration_method, is_mobile, created_at, updated_at
        )
        SELECT v.id, v.name, legacy.category, legacy.asset_type, legacy.subsystem,
               v.name, legacy.status, legacy.physical_location, true, NULL, '[]'::jsonb,
               legacy.asset_type_id, legacy.equipment_category_id, legacy.equipment_kind_id,
               legacy.subsystem_id, legacy.manufacturer_id, legacy.status_id,
               legacy.current_geographic_location_id, NULL, NULL, NULL, NULL,
               'NOT_CAPTURED', NULL, NULL, NULL, NULL, 'Equipo', 'MIGRATED', false, now(), now()
        FROM (VALUES
            ('physical-crk-1', 'CRK 1', 'CRK 1 - 2'),
            ('physical-crk-2', 'CRK 2', 'CRK 1 - 2'),
            ('physical-erk-1', 'ERK 1', 'ERK 1 - 2'),
            ('physical-erk-2', 'ERK 2', 'ERK 1 - 2')
        ) AS v(id, name, legacy_name)
        JOIN assets legacy ON legacy.name = v.legacy_name
        ON CONFLICT (id) DO NOTHING
    """)
    op.execute("""
        UPDATE assets child SET parent_id = mapping.new_parent_id, updated_at = now()
        FROM (
            SELECT child.id,
                   CASE child.physical_location
                       WHEN 'CRK 1' THEN 'physical-crk-1'
                       WHEN 'CRK 2' THEN 'physical-crk-2'
                       WHEN 'ERK 1' THEN 'physical-erk-1'
                       WHEN 'ERK 2' THEN 'physical-erk-2'
                   END AS new_parent_id
            FROM assets child
            JOIN assets legacy ON legacy.id = child.parent_id
            WHERE legacy.name IN ('CRK 1 - 2', 'ERK 1 - 2')
              AND child.physical_location IN ('CRK 1', 'CRK 2', 'ERK 1', 'ERK 2')
        ) mapping
        WHERE child.id = mapping.id AND mapping.new_parent_id IS NOT NULL
    """)
    op.execute("DELETE FROM asset_closure")
    op.execute("""
        WITH RECURSIVE hierarchy AS (
            SELECT id AS ancestor_asset_id, id AS descendant_asset_id, 0 AS depth
            FROM assets
            UNION ALL
            SELECT hierarchy.ancestor_asset_id, child.id, hierarchy.depth + 1
            FROM hierarchy
            JOIN assets child ON child.parent_id = hierarchy.descendant_asset_id
        )
        INSERT INTO asset_closure (ancestor_asset_id, descendant_asset_id, depth)
        SELECT ancestor_asset_id, descendant_asset_id, MIN(depth)
        FROM hierarchy
        GROUP BY ancestor_asset_id, descendant_asset_id
    """)
    op.execute("""
        UPDATE assets parent
        SET children = COALESCE(
            (SELECT jsonb_agg(child.name ORDER BY child.name)
             FROM assets child WHERE child.parent_id = parent.id),
            '[]'::jsonb
        )
    """)
    op.execute("""
        DELETE FROM asset_group_members gm
        USING asset_groups ag
        WHERE gm.asset_group_id = ag.id
          AND ag.name IN ('CRK 1 - 2', 'ERK 1 - 2')
    """)
    op.execute("""
        INSERT INTO asset_group_members (id, asset_group_id, asset_id, created_at, updated_at)
        SELECT gen_random_uuid(), ag.id, item.asset_id, now(), now()
        FROM asset_groups ag
        JOIN (VALUES
            ('CRK 1 - 2', 'physical-crk-1'), ('CRK 1 - 2', 'physical-crk-2'),
            ('ERK 1 - 2', 'physical-erk-1'), ('ERK 1 - 2', 'physical-erk-2')
        ) AS item(group_name, asset_id) ON item.group_name = ag.name
        ON CONFLICT (asset_group_id, asset_id) DO NOTHING
    """)

    # ATS software scopes become logical groups of their individual physical servers.
    op.execute("""
        DELETE FROM asset_group_members gm
        USING asset_groups ag
        WHERE gm.asset_group_id = ag.id
          AND ag.name IN (
              'SYS001, SYS002, DBC001, COM001, COM002, CWS001, CWS002, CWS003, CWS004, CWS005, OVW001, OVW002',
              'SYS101, SYS102, DBC101, COM101, COM102, CWS101, CWS102, CWS103, CWS104, CWS105, OVW101, OVW102'
          )
    """)
    op.execute("""
        INSERT INTO asset_group_members (id, asset_group_id, asset_id, created_at, updated_at)
        SELECT gen_random_uuid(), ag.id, a.id, now(), now()
        FROM asset_groups ag
        JOIN assets a ON (
            (ag.name LIKE 'SYS001,%' AND upper(regexp_replace(a.name, '[^A-Za-z0-9]', '', 'g')) ~ '^(LIM)?(SYS|DBC|COM|CWS|OVW)00[1-9]$')
            OR
            (ag.name LIKE 'SYS101,%' AND upper(regexp_replace(a.name, '[^A-Za-z0-9]', '', 'g')) ~ '^(LIM)?(SYS|DBC|COM|CWS|OVW)10[1-9]$')
        )
        ON CONFLICT (asset_group_id, asset_id) DO NOTHING
    """)
    op.execute("""
        UPDATE assets
        SET is_business_anchor = false, business_label = 'Grupo preventivo legado', updated_at = now()
        WHERE name IN (
            'CRK 1 - 2', 'ERK 1 - 2',
            'SYS001, SYS002, DBC001, COM001, COM002, CWS001, CWS002, CWS003, CWS004, CWS005, OVW001, OVW002',
            'SYS101, SYS102, DBC101, COM101, COM102, CWS101, CWS102, CWS103, CWS104, CWS105, OVW101, OVW102'
        )
    """)
    op.execute("""
        UPDATE corrective_events ce
        SET is_critical = EXISTS (
            SELECT 1 FROM corrective_event_affected_assets cea
            WHERE cea.corrective_event_id = ce.id AND cea.is_critical
        )
    """)


def downgrade() -> None:
    op.drop_column("corrective_events", "is_critical")
    op.drop_index("ix_maintenance_template_scopes_asset_group_id", table_name="maintenance_template_scopes")
    op.drop_column("maintenance_template_scopes", "asset_group_id")
    op.drop_index("ix_asset_group_members_asset_id", table_name="asset_group_members")
    op.drop_index("ix_asset_group_members_asset_group_id", table_name="asset_group_members")
    op.drop_table("asset_group_members")
    op.drop_index("ix_asset_groups_subsystem_id", table_name="asset_groups")
    op.drop_index("ix_asset_groups_name", table_name="asset_groups")
    op.drop_table("asset_groups")
