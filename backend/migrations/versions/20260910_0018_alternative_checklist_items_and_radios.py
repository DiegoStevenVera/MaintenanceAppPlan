"""model checklist alternatives and register portable radios

Revision ID: 20260910_0018
Revises: 20260910_0017
Create Date: 2026-09-10
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op


revision: str = "20260910_0018"
down_revision: str | Sequence[str] | None = "20260910_0017"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "maintenance_operational_checklist_items",
        sa.Column("alternative_group", sa.String(length=80)),
    )
    op.create_index(
        "ix_operational_checklist_item_alternative_group",
        "maintenance_operational_checklist_items",
        ["checklist_revision_id", "alternative_group"],
    )

    op.execute("""
        INSERT INTO tool_catalog_items (
            id, name, category, default_unit, requires_identified_unit,
            legacy_id, is_active, created_at, updated_at
        ) VALUES (
            gen_random_uuid(), 'Soplador', 'MANUAL_TOOL', 'unidad', false,
            NULL, true, now(), now()
        )
        ON CONFLICT (category, name) DO UPDATE SET
            is_active = true,
            updated_at = now()
    """)

    # Replace the incorrectly modeled combined item with two exclusive options.
    op.execute("""
        UPDATE maintenance_operational_checklist_items AS item
        SET item_name = 'Inflador',
            catalog_item_id = catalog.id,
            alternative_group = 'AIR_CLEANING_DEVICE',
            notes = 'Seleccionar Inflador o Soplador',
            updated_at = now()
        FROM maintenance_operational_checklist_revisions AS revision,
             maintenance_templates AS template,
             tool_catalog_items AS catalog
        WHERE revision.id = item.checklist_revision_id
          AND template.id = revision.maintenance_template_id
          AND catalog.category = 'MANUAL_TOOL'
          AND catalog.name = 'Inflador'
          AND lower(coalesce(template.activity_n3_summary, ''))
                  LIKE '%conmutaci%n mantenimiento completo%'
          AND item.item_name = 'Inflador o soplador'
    """)
    op.execute("""
        INSERT INTO maintenance_operational_checklist_items (
            id, checklist_revision_id, catalog_item_id, category, item_name,
            default_quantity, unit, is_required, sequence, notes,
            alternative_group, created_at, updated_at
        )
        SELECT
            gen_random_uuid(), revision.id, catalog.id, 'MANUAL_TOOL',
            'Soplador', 1, 'unidad', true, 160,
            'Seleccionar Inflador o Soplador', 'AIR_CLEANING_DEVICE',
            now(), now()
        FROM maintenance_operational_checklist_revisions AS revision
        JOIN maintenance_templates AS template
          ON template.id = revision.maintenance_template_id
        JOIN tool_catalog_items AS catalog
          ON catalog.category = 'MANUAL_TOOL' AND catalog.name = 'Soplador'
        WHERE lower(coalesce(template.activity_n3_summary, ''))
                  LIKE '%conmutaci%n mantenimiento completo%'
          AND NOT EXISTS (
              SELECT 1
              FROM maintenance_operational_checklist_items AS existing
              WHERE existing.checklist_revision_id = revision.id
                AND existing.catalog_item_id = catalog.id
          )
    """)
    op.execute("""
        DELETE FROM tool_catalog_items AS catalog
        WHERE catalog.category = 'MANUAL_TOOL'
          AND catalog.name = 'Inflador o soplador'
          AND NOT EXISTS (
              SELECT 1
              FROM maintenance_operational_checklist_items AS item
              WHERE item.catalog_item_id = catalog.id
          )
          AND NOT EXISTS (
              SELECT 1 FROM tools AS tool WHERE tool.catalog_item_id = catalog.id
          )
    """)

    op.execute("""
        INSERT INTO tools (
            id, catalog_item_id, serial_number, name, tool_type,
            availability_status, current_location, legacy_id, is_active,
            created_at, updated_at
        )
        SELECT
            gen_random_uuid(), catalog.id, radio.serial_number,
            'Radio portátil', 'Radio portátil', 'AVAILABLE',
            NULL, NULL, true, now(), now()
        FROM tool_catalog_items AS catalog
        CROSS JOIN (VALUES ('22565'), ('22566'), ('22567')) AS radio(serial_number)
        WHERE catalog.category = 'EQUIPMENT'
          AND catalog.name = 'Radio portátil'
        ON CONFLICT (serial_number) DO UPDATE SET
            catalog_item_id = EXCLUDED.catalog_item_id,
            name = EXCLUDED.name,
            tool_type = EXCLUDED.tool_type,
            is_active = true,
            updated_at = now()
    """)


def downgrade() -> None:
    op.execute("""
        DELETE FROM maintenance_operational_checklist_items AS item
        USING maintenance_operational_checklist_revisions AS revision,
              maintenance_templates AS template
        WHERE revision.id = item.checklist_revision_id
          AND template.id = revision.maintenance_template_id
          AND lower(coalesce(template.activity_n3_summary, ''))
                  LIKE '%conmutaci%n mantenimiento completo%'
          AND item.item_name = 'Soplador'
          AND item.alternative_group = 'AIR_CLEANING_DEVICE'
    """)
    op.execute("""
        INSERT INTO tool_catalog_items (
            id, name, category, default_unit, requires_identified_unit,
            legacy_id, is_active, created_at, updated_at
        ) VALUES (
            gen_random_uuid(), 'Inflador o soplador', 'MANUAL_TOOL',
            'unidad', false, NULL, true, now(), now()
        )
        ON CONFLICT (category, name) DO NOTHING
    """)
    op.execute("""
        UPDATE maintenance_operational_checklist_items AS item
        SET item_name = 'Inflador o soplador',
            catalog_item_id = catalog.id,
            notes = NULL,
            alternative_group = NULL,
            updated_at = now()
        FROM maintenance_operational_checklist_revisions AS revision,
             maintenance_templates AS template,
             tool_catalog_items AS catalog
        WHERE revision.id = item.checklist_revision_id
          AND template.id = revision.maintenance_template_id
          AND catalog.category = 'MANUAL_TOOL'
          AND catalog.name = 'Inflador o soplador'
          AND lower(coalesce(template.activity_n3_summary, ''))
                  LIKE '%conmutaci%n mantenimiento completo%'
          AND item.item_name = 'Inflador'
          AND item.alternative_group = 'AIR_CLEANING_DEVICE'
    """)
    op.drop_index(
        "ix_operational_checklist_item_alternative_group",
        table_name="maintenance_operational_checklist_items",
    )
    op.drop_column(
        "maintenance_operational_checklist_items",
        "alternative_group",
    )
