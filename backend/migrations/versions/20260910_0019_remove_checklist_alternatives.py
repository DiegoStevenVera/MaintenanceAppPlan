"""remove checklist alternative selection rules

Revision ID: 20260910_0019
Revises: 20260910_0018
Create Date: 2026-09-10
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op


revision: str = "20260910_0019"
down_revision: str | Sequence[str] | None = "20260910_0018"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute("""
        UPDATE maintenance_operational_checklist_items AS item
        SET notes = NULL,
            updated_at = now()
        FROM maintenance_operational_checklist_revisions AS revision,
             maintenance_templates AS template
        WHERE revision.id = item.checklist_revision_id
          AND template.id = revision.maintenance_template_id
          AND lower(coalesce(template.activity_n3_summary, ''))
                  LIKE '%conmutaci%n mantenimiento completo%'
          AND item.item_name IN ('Inflador', 'Soplador')
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


def downgrade() -> None:
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
        UPDATE maintenance_operational_checklist_items AS item
        SET alternative_group = 'AIR_CLEANING_DEVICE',
            notes = 'Seleccionar Inflador o Soplador',
            updated_at = now()
        FROM maintenance_operational_checklist_revisions AS revision,
             maintenance_templates AS template
        WHERE revision.id = item.checklist_revision_id
          AND template.id = revision.maintenance_template_id
          AND lower(coalesce(template.activity_n3_summary, ''))
                  LIKE '%conmutaci%n mantenimiento completo%'
          AND item.item_name IN ('Inflador', 'Soplador')
    """)
