"""normalize tool catalog and seed the track-circuit operational checklist

Revision ID: 20260910_0017
Revises: 20260910_0016
Create Date: 2026-09-10
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


revision: str = "20260910_0017"
down_revision: str | Sequence[str] | None = "20260910_0016"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "tool_catalog_items",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("name", sa.String(length=200), nullable=False),
        sa.Column("category", sa.String(length=30), nullable=False),
        sa.Column("default_unit", sa.String(length=40), nullable=False),
        sa.Column("requires_identified_unit", sa.Boolean(), nullable=False),
        sa.Column("legacy_id", sa.Integer(), unique=True),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.CheckConstraint(
            "category IN ('ACCESS_KEY', 'MANUAL_TOOL', 'CONSUMABLE', 'EQUIPMENT')",
            name="ck_tool_catalog_item_category",
        ),
        sa.UniqueConstraint("category", "name", name="uq_tool_catalog_item_category_name"),
    )

    op.add_column(
        "tools",
        sa.Column("catalog_item_id", postgresql.UUID(as_uuid=True)),
    )
    op.create_foreign_key(
        "fk_tools_catalog_item_id",
        "tools",
        "tool_catalog_items",
        ["catalog_item_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index("ix_tools_catalog_item_id", "tools", ["catalog_item_id"])

    op.add_column(
        "maintenance_operational_checklist_items",
        sa.Column("catalog_item_id", postgresql.UUID(as_uuid=True)),
    )
    op.create_foreign_key(
        "fk_operational_checklist_item_catalog_item_id",
        "maintenance_operational_checklist_items",
        "tool_catalog_items",
        ["catalog_item_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_index(
        "ix_operational_checklist_item_catalog_item_id",
        "maintenance_operational_checklist_items",
        ["catalog_item_id"],
    )

    op.add_column(
        "report_tool_usages",
        sa.Column(
            "operational_checklist_item_id",
            postgresql.UUID(as_uuid=True),
        ),
    )
    op.create_foreign_key(
        "fk_report_tool_usage_operational_item_id",
        "report_tool_usages",
        "maintenance_operational_checklist_items",
        ["operational_checklist_item_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index(
        "ix_report_tool_usage_operational_item_id",
        "report_tool_usages",
        ["operational_checklist_item_id"],
    )

    # Normalize every existing generic checklist row into the shared catalog.
    op.execute("""
        INSERT INTO tool_catalog_items (
            id, name, category, default_unit, requires_identified_unit,
            legacy_id, is_active, created_at, updated_at
        )
        SELECT DISTINCT ON (item.category, item.item_name)
            gen_random_uuid(), item.item_name, item.category, item.unit,
            item.category = 'EQUIPMENT', NULL, true, now(), now()
        FROM maintenance_operational_checklist_items AS item
        ORDER BY item.category, item.item_name, item.created_at
        ON CONFLICT (category, name) DO NOTHING
    """)
    op.execute("""
        UPDATE maintenance_operational_checklist_items AS item
        SET catalog_item_id = catalog.id,
            updated_at = now()
        FROM tool_catalog_items AS catalog
        WHERE catalog.category = item.category
          AND catalog.name = item.item_name
    """)

    # Identified inventory rows are physical instances of a generic EQUIPMENT item.
    op.execute("""
        INSERT INTO tool_catalog_items (
            id, name, category, default_unit, requires_identified_unit,
            legacy_id, is_active, created_at, updated_at
        )
        SELECT DISTINCT ON (coalesce(nullif(trim(tool.tool_type), ''), tool.name))
            gen_random_uuid(),
            coalesce(nullif(trim(tool.tool_type), ''), tool.name),
            'EQUIPMENT', 'unidad', true, NULL, true, now(), now()
        FROM tools AS tool
        ORDER BY coalesce(nullif(trim(tool.tool_type), ''), tool.name), tool.created_at
        ON CONFLICT (category, name) DO NOTHING
    """)
    op.execute("""
        UPDATE tools AS tool
        SET catalog_item_id = catalog.id,
            updated_at = now()
        FROM tool_catalog_items AS catalog
        WHERE catalog.category = 'EQUIPMENT'
          AND catalog.name = coalesce(nullif(trim(tool.tool_type), ''), tool.name)
    """)

    # Generic catalog entries required by the initial track-circuit checklist.
    op.execute("""
        INSERT INTO tool_catalog_items (
            id, name, category, default_unit, requires_identified_unit,
            legacy_id, is_active, created_at, updated_at
        ) VALUES
            (gen_random_uuid(), 'Radio portátil', 'EQUIPMENT', 'unidad', true,
             NULL, true, now(), now()),
            (gen_random_uuid(), 'Llave de sala de señalización', 'ACCESS_KEY',
             'unidad', false, NULL, true, now(), now()),
            (gen_random_uuid(), 'Multímetro', 'EQUIPMENT', 'unidad', true,
             NULL, true, now(), now()),
            (gen_random_uuid(), 'Osciloscopio', 'EQUIPMENT', 'unidad', true,
             NULL, true, now(), now()),
            (gen_random_uuid(), 'Inflador', 'MANUAL_TOOL', 'unidad', false,
             NULL, true, now(), now()),
            (gen_random_uuid(), 'Paños multiuso', 'CONSUMABLE', 'unidad', false,
             NULL, true, now(), now()),
            (gen_random_uuid(), 'Escobilla', 'CONSUMABLE', 'unidad', false,
             NULL, true, now(), now())
        ON CONFLICT (category, name) DO NOTHING
    """)

    # Reuse the catalog entry even when an imported radio omitted the accent.
    op.execute("""
        UPDATE tools AS tool
        SET catalog_item_id = catalog.id,
            updated_at = now()
        FROM tool_catalog_items AS catalog
        WHERE catalog.category = 'EQUIPMENT'
          AND (
              (lower(tool.tool_type) = 'radio portatil' AND catalog.name = 'Radio portátil')
              OR (lower(tool.tool_type) = 'radio portátil' AND catalog.name = 'Radio portátil')
          )
    """)

    op.execute("""
        INSERT INTO maintenance_operational_checklist_revisions (
            id, maintenance_template_id, revision_number, status, notes,
            created_at, updated_at
        )
        SELECT
            gen_random_uuid(), template.id, 1, 'ACTIVE',
            'Lista operativa inicial para mantenimiento de circuito de via',
            now(), now()
        FROM maintenance_templates AS template
        WHERE lower(coalesce(template.activity_n3_summary, ''))
                  LIKE '%circuito de v%'
          AND NOT EXISTS (
              SELECT 1
              FROM maintenance_operational_checklist_revisions AS existing
              WHERE existing.maintenance_template_id = template.id
                AND existing.status = 'ACTIVE'
          )
    """)
    op.execute("""
        INSERT INTO maintenance_operational_checklist_items (
            id, checklist_revision_id, catalog_item_id, category, item_name,
            default_quantity, unit, is_required, sequence, notes,
            created_at, updated_at
        )
        SELECT
            gen_random_uuid(), revision.id, catalog.id, seed.category,
            seed.item_name, seed.default_quantity, catalog.default_unit,
            true, seed.sequence, seed.notes, now(), now()
        FROM maintenance_operational_checklist_revisions AS revision
        JOIN maintenance_templates AS template
          ON template.id = revision.maintenance_template_id
        CROSS JOIN (VALUES
            ('EQUIPMENT', 'Radio portátil', 1.0, 10, NULL),
            ('ACCESS_KEY', 'Llave de sala de señalización', 1.0, 20, NULL),
            ('EQUIPMENT', 'Multímetro', 1.0, 30, NULL),
            ('EQUIPMENT', 'Osciloscopio', 1.0, 40, NULL),
            ('MANUAL_TOOL', 'Inflador', 1.0, 50, NULL),
            ('CONSUMABLE', 'Paños multiuso', NULL, 60,
             'Cantidad pendiente de estandarizar'),
            ('CONSUMABLE', 'Escobilla', 1.0, 70, NULL)
        ) AS seed(category, item_name, default_quantity, sequence, notes)
        JOIN tool_catalog_items AS catalog
          ON catalog.category = seed.category AND catalog.name = seed.item_name
        WHERE revision.status = 'ACTIVE'
          AND lower(coalesce(template.activity_n3_summary, ''))
                  LIKE '%circuito de v%'
          AND NOT EXISTS (
              SELECT 1
              FROM maintenance_operational_checklist_items AS existing
              WHERE existing.checklist_revision_id = revision.id
                AND existing.catalog_item_id = catalog.id
          )
    """)

    op.alter_column(
        "maintenance_operational_checklist_items",
        "catalog_item_id",
        nullable=False,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_report_tool_usage_operational_item_id",
        table_name="report_tool_usages",
    )
    op.drop_constraint(
        "fk_report_tool_usage_operational_item_id",
        "report_tool_usages",
        type_="foreignkey",
    )
    op.drop_column("report_tool_usages", "operational_checklist_item_id")

    op.drop_index(
        "ix_operational_checklist_item_catalog_item_id",
        table_name="maintenance_operational_checklist_items",
    )
    op.drop_constraint(
        "fk_operational_checklist_item_catalog_item_id",
        "maintenance_operational_checklist_items",
        type_="foreignkey",
    )
    op.drop_column("maintenance_operational_checklist_items", "catalog_item_id")

    op.drop_index("ix_tools_catalog_item_id", table_name="tools")
    op.drop_constraint(
        "fk_tools_catalog_item_id",
        "tools",
        type_="foreignkey",
    )
    op.drop_column("tools", "catalog_item_id")
    op.drop_table("tool_catalog_items")
