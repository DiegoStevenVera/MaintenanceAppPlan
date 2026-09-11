"""add manual and operational preventive checklist snapshots

Revision ID: 20260910_0016
Revises: 20260828_0015
Create Date: 2026-09-10
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


revision: str = "20260910_0016"
down_revision: str | Sequence[str] | None = "20260828_0015"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "maintenance_operational_checklist_revisions",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "maintenance_template_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("maintenance_templates.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("revision_number", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("notes", sa.Text()),
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
        sa.UniqueConstraint(
            "maintenance_template_id",
            "revision_number",
            name="uq_operational_checklist_revision_template_number",
        ),
    )
    op.create_index(
        "ix_operational_checklist_revision_template_id",
        "maintenance_operational_checklist_revisions",
        ["maintenance_template_id"],
    )
    op.create_index(
        "uq_operational_checklist_active_template",
        "maintenance_operational_checklist_revisions",
        ["maintenance_template_id"],
        unique=True,
        postgresql_where=sa.text("status = 'ACTIVE'"),
    )

    op.create_table(
        "maintenance_operational_checklist_items",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "checklist_revision_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey(
                "maintenance_operational_checklist_revisions.id",
                ondelete="CASCADE",
            ),
            nullable=False,
        ),
        sa.Column("category", sa.String(length=30), nullable=False),
        sa.Column("item_name", sa.String(length=200), nullable=False),
        sa.Column("default_quantity", sa.Float()),
        sa.Column("unit", sa.String(length=40), nullable=False),
        sa.Column("is_required", sa.Boolean(), nullable=False),
        sa.Column("sequence", sa.Integer(), nullable=False),
        sa.Column("notes", sa.Text()),
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
            name="ck_operational_checklist_item_category",
        ),
        sa.UniqueConstraint(
            "checklist_revision_id",
            "sequence",
            name="uq_operational_checklist_item_revision_sequence",
        ),
    )
    op.create_index(
        "ix_operational_checklist_item_revision_id",
        "maintenance_operational_checklist_items",
        ["checklist_revision_id"],
    )

    op.create_table(
        "report_checklist_item_snapshots",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "report_version_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("report_versions.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("checklist_type", sa.String(length=20), nullable=False),
        sa.Column(
            "source_manual_tool_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("maintenance_template_tools.id", ondelete="SET NULL"),
        ),
        sa.Column(
            "source_operational_item_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey(
                "maintenance_operational_checklist_items.id",
                ondelete="SET NULL",
            ),
        ),
        sa.Column("item_name_snapshot", sa.String(length=200), nullable=False),
        sa.Column("category_snapshot", sa.String(length=30)),
        sa.Column("recommended_quantity_snapshot", sa.Float()),
        sa.Column("actual_quantity", sa.Float()),
        sa.Column("unit_snapshot", sa.String(length=40)),
        sa.Column("is_checked", sa.Boolean()),
        sa.Column("is_required_snapshot", sa.Boolean(), nullable=False),
        sa.Column("sequence", sa.Integer(), nullable=False),
        sa.Column("notes", sa.Text()),
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
            "checklist_type IN ('MANUAL', 'OPERATIONAL')",
            name="ck_report_checklist_snapshot_type",
        ),
        sa.UniqueConstraint(
            "report_version_id",
            "checklist_type",
            "sequence",
            name="uq_report_checklist_snapshot_version_type_sequence",
        ),
    )
    op.create_index(
        "ix_report_checklist_snapshot_version_id",
        "report_checklist_item_snapshots",
        ["report_version_id"],
    )

    # Normalize the two manual rows for complete switch-machine maintenance.
    op.execute("""
        UPDATE maintenance_template_tools AS tool
        SET tool_name = CASE
            WHEN lower(tool.tool_name) LIKE '%consumible%'
                THEN 'Kit de limpieza (5.1)'
            ELSE 'Kit de herramientas comunes (5.1)'
        END,
        quantity = 1,
        updated_at = now()
        FROM maintenance_templates AS template
        WHERE tool.maintenance_template_id = template.id
          AND lower(coalesce(template.activity_n3_summary, ''))
              LIKE '%conmutaci%n mantenimiento completo%'
          AND (
              lower(tool.tool_name) LIKE '%consumible%'
              OR lower(tool.tool_name) LIKE '%manual%cap. 5.1%'
          )
          AND NOT EXISTS (
              SELECT 1
              FROM maintenance_template_tools AS existing
              WHERE existing.maintenance_template_id = tool.maintenance_template_id
                AND existing.id <> tool.id
                AND existing.tool_name = CASE
                    WHEN lower(tool.tool_name) LIKE '%consumible%'
                        THEN 'Kit de limpieza (5.1)'
                    ELSE 'Kit de herramientas comunes (5.1)'
                END
          )
    """)
    op.execute("""
        UPDATE maintenance_template_tools AS tool
        SET is_active = false,
            updated_at = now()
        FROM maintenance_templates AS template
        WHERE tool.maintenance_template_id = template.id
          AND lower(coalesce(template.activity_n3_summary, ''))
              LIKE '%conmutaci%n mantenimiento completo%'
          AND (
              lower(tool.tool_name) LIKE '%consumible%'
              OR lower(tool.tool_name) LIKE '%manual%cap. 5.1%'
          )
          AND EXISTS (
              SELECT 1
              FROM maintenance_template_tools AS existing
              WHERE existing.maintenance_template_id = tool.maintenance_template_id
                AND existing.id <> tool.id
                AND existing.is_active = true
                AND existing.tool_name IN (
                    'Kit de limpieza (5.1)',
                    'Kit de herramientas comunes (5.1)'
                )
          )
    """)

    # Initial operational list. Other maintenance templates intentionally remain
    # empty until their field checklist has been agreed by the maintenance area.
    op.execute("""
        INSERT INTO maintenance_operational_checklist_revisions (
            id, maintenance_template_id, revision_number, status, notes,
            created_at, updated_at
        )
        SELECT
            gen_random_uuid(), template.id, 1, 'ACTIVE',
            'Lista operativa inicial validada para mantenimiento completo de cambiavías',
            now(), now()
        FROM maintenance_templates AS template
        WHERE lower(coalesce(template.activity_n3_summary, ''))
              LIKE '%conmutaci%n mantenimiento completo%'
    """)
    op.execute("""
        INSERT INTO maintenance_operational_checklist_items (
            id, checklist_revision_id, category, item_name, default_quantity,
            unit, is_required, sequence, notes, created_at, updated_at
        )
        SELECT
            gen_random_uuid(), revision.id, item.category, item.item_name,
            item.default_quantity, item.unit, true, item.sequence, item.notes,
            now(), now()
        FROM maintenance_operational_checklist_revisions AS revision
        JOIN maintenance_templates AS template
          ON template.id = revision.maintenance_template_id
        CROSS JOIN (VALUES
            ('MANUAL_TOOL', 'Galga de 1 mm', 1.0, 'unidad', 10, NULL),
            ('MANUAL_TOOL', 'Galga de 2 mm', 1.0, 'unidad', 20, NULL),
            ('MANUAL_TOOL', 'Galga de 4 mm', 1.0, 'unidad', 30, NULL),
            ('MANUAL_TOOL', 'Llave mixta N.° 41', 1.0, 'unidad', 40, NULL),
            ('MANUAL_TOOL', 'Llave mixta N.° 39', 1.0, 'unidad', 50, NULL),
            ('MANUAL_TOOL', 'Llave mixta N.° 19', 1.0, 'unidad', 60, NULL),
            ('MANUAL_TOOL', 'Llave dado N.° 13', 1.0, 'unidad', 70, NULL),
            ('MANUAL_TOOL', 'Desarmador plano mediano', 1.0, 'unidad', 80, NULL),
            ('MANUAL_TOOL', 'Desarmador estrella mediano', 1.0, 'unidad', 90, NULL),
            ('MANUAL_TOOL', 'Perillero', 1.0, 'unidad', 100, NULL),
            ('MANUAL_TOOL', 'Alicate universal', 2.0, 'unidad', 110, NULL),
            ('MANUAL_TOOL', 'Alicate de punta', 1.0, 'unidad', 120, NULL),
            ('MANUAL_TOOL', 'Martillo de goma', 1.0, 'unidad', 130, NULL),
            ('MANUAL_TOOL', 'Martillo de metal', 1.0, 'unidad', 140, NULL),
            ('MANUAL_TOOL', 'Inflador o soplador', 1.0, 'unidad', 150, NULL),
            ('CONSUMABLE', 'Paños multiuso', NULL, 'unidad', 200,
             'Cantidad pendiente de estandarizar'),
            ('CONSUMABLE', 'Escobilla', 2.0, 'unidad', 210,
             'Se requiere una como mínimo'),
            ('ACCESS_KEY', 'Llave de candados de cambiavías', 1.0, 'unidad', 300, NULL),
            ('EQUIPMENT', 'Radio portátil', 2.0, 'unidad', 400, NULL)
        ) AS item(category, item_name, default_quantity, unit, sequence, notes)
        WHERE revision.status = 'ACTIVE'
          AND revision.revision_number = 1
          AND lower(coalesce(template.activity_n3_summary, ''))
              LIKE '%conmutaci%n mantenimiento completo%'
    """)


def downgrade() -> None:
    op.drop_table("report_checklist_item_snapshots")
    op.drop_table("maintenance_operational_checklist_items")
    op.drop_table("maintenance_operational_checklist_revisions")
