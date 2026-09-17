"""Reset operational checklists to the physical inventory source.

Operational checklist revisions are configuration, not report history. Report
snapshots and tool usages keep their own names and are protected by SET NULL
foreign keys, so removing the old configuration does not alter completed reports.
"""

from alembic import op
import sqlalchemy as sa


revision = "20260915_0022"
down_revision = "20260915_0021"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # The initial checklist entries were test data. Remove their lines first so
    # the revision cascade and historical SET NULL references can run cleanly.
    op.execute(sa.text("DELETE FROM maintenance_operational_checklist_items"))
    op.execute(sa.text("DELETE FROM maintenance_operational_checklist_revisions"))

    # Manual tools, consumables and access keys are now sourced exclusively from
    # tool_inventory_items. Keep catalog rows for history, but make stale test
    # definitions invisible and unavailable for new checklists.
    op.execute(
        sa.text(
            """
            UPDATE tool_catalog_items AS catalog
            SET is_active = FALSE,
                updated_at = now()
            WHERE catalog.category IN ('MANUAL_TOOL', 'CONSUMABLE', 'ACCESS_KEY')
              AND NOT EXISTS (
                  SELECT 1
                  FROM tool_inventory_items AS inventory
                  WHERE inventory.catalog_item_id = catalog.id
              )
            """
        )
    )


def downgrade() -> None:
    # Previous checklist definitions and their exact contents are not recoverable
    # without a data backup. The migration is intentionally forward-only.
    pass
