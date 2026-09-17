"""Use inventory classification as the only checklist grouping source."""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op


revision: str = "20260916_0024"
down_revision: str | Sequence[str] | None = "20260916_0023"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Category is a descriptive subtype (for example LLAVE or INSTRUMENTO).
    # Only classification controls the four operational checklist groups.
    op.execute(
        sa.text(
            """
            WITH desired AS (
                SELECT DISTINCT ON (
                    CASE
                        WHEN upper(trim(coalesce(classification, ''))) LIKE '%CONSUMIBLE%'
                            THEN 'CONSUMABLE'
                        WHEN upper(trim(coalesce(classification, ''))) LIKE '%LLAVE%'
                          OR upper(trim(coalesce(classification, ''))) LIKE '%ACCESO%'
                            THEN 'ACCESS_KEY'
                        WHEN upper(trim(coalesce(classification, ''))) LIKE '%EQUIPO%'
                            THEN 'EQUIPMENT'
                        ELSE 'MANUAL_TOOL'
                    END,
                    lower(trim(name))
                )
                    name,
                    CASE
                        WHEN upper(trim(coalesce(classification, ''))) LIKE '%CONSUMIBLE%'
                            THEN 'CONSUMABLE'
                        WHEN upper(trim(coalesce(classification, ''))) LIKE '%LLAVE%'
                          OR upper(trim(coalesce(classification, ''))) LIKE '%ACCESO%'
                            THEN 'ACCESS_KEY'
                        WHEN upper(trim(coalesce(classification, ''))) LIKE '%EQUIPO%'
                            THEN 'EQUIPMENT'
                        ELSE 'MANUAL_TOOL'
                    END AS catalog_category
                FROM tool_inventory_items
                WHERE trim(coalesce(name, '')) <> ''
                ORDER BY
                    CASE
                        WHEN upper(trim(coalesce(classification, ''))) LIKE '%CONSUMIBLE%'
                            THEN 'CONSUMABLE'
                        WHEN upper(trim(coalesce(classification, ''))) LIKE '%LLAVE%'
                          OR upper(trim(coalesce(classification, ''))) LIKE '%ACCESO%'
                            THEN 'ACCESS_KEY'
                        WHEN upper(trim(coalesce(classification, ''))) LIKE '%EQUIPO%'
                            THEN 'EQUIPMENT'
                        ELSE 'MANUAL_TOOL'
                    END,
                    lower(trim(name)),
                    source_row_number
            )
            INSERT INTO tool_catalog_items (
                id, name, category, default_unit, requires_identified_unit,
                legacy_id, is_active, created_at, updated_at
            )
            SELECT
                gen_random_uuid(), desired.name, desired.catalog_category,
                'unidad', desired.catalog_category = 'EQUIPMENT',
                NULL, TRUE, now(), now()
            FROM desired
            WHERE NOT EXISTS (
                SELECT 1
                FROM tool_catalog_items AS catalog
                WHERE catalog.category = desired.catalog_category
                  AND lower(trim(catalog.name)) = lower(trim(desired.name))
            )
            """
        )
    )

    # Correct the active checklist configuration. Completed report snapshots
    # and archived checklist revisions remain unchanged as historical records.
    op.execute(
        sa.text(
            """
            WITH inventory_classification AS (
                SELECT DISTINCT ON (lower(trim(name)))
                    lower(trim(name)) AS normalized_name,
                    CASE
                        WHEN upper(trim(coalesce(classification, ''))) LIKE '%CONSUMIBLE%'
                            THEN 'CONSUMABLE'
                        WHEN upper(trim(coalesce(classification, ''))) LIKE '%LLAVE%'
                          OR upper(trim(coalesce(classification, ''))) LIKE '%ACCESO%'
                            THEN 'ACCESS_KEY'
                        WHEN upper(trim(coalesce(classification, ''))) LIKE '%EQUIPO%'
                            THEN 'EQUIPMENT'
                        ELSE 'MANUAL_TOOL'
                    END AS catalog_category
                FROM tool_inventory_items
                WHERE trim(coalesce(name, '')) <> ''
                ORDER BY lower(trim(name)), source_row_number DESC
            ), catalog_target AS (
                SELECT DISTINCT ON (classification.normalized_name)
                    classification.normalized_name,
                    classification.catalog_category,
                    catalog.id AS catalog_id
                FROM inventory_classification AS classification
                JOIN tool_catalog_items AS catalog
                  ON catalog.category = classification.catalog_category
                 AND lower(trim(catalog.name)) = classification.normalized_name
                ORDER BY classification.normalized_name, catalog.created_at
            )
            UPDATE maintenance_operational_checklist_items AS checklist
            SET catalog_item_id = target.catalog_id,
                category = target.catalog_category,
                updated_at = now()
            FROM catalog_target AS target,
                 maintenance_operational_checklist_revisions AS revision
            WHERE lower(trim(checklist.item_name)) = target.normalized_name
              AND revision.id = checklist.checklist_revision_id
              AND revision.status = 'ACTIVE'
              AND (
                  checklist.catalog_item_id IS DISTINCT FROM target.catalog_id
                  OR checklist.category IS DISTINCT FROM target.catalog_category
              )
            """
        )
    )

    op.execute(
        sa.text(
            """
            WITH inventory_target AS (
                SELECT
                    inventory.id AS inventory_id,
                    catalog.id AS catalog_id
                FROM tool_inventory_items AS inventory
                JOIN tool_catalog_items AS catalog
                  ON catalog.category = CASE
                        WHEN upper(trim(coalesce(inventory.classification, ''))) LIKE '%CONSUMIBLE%'
                            THEN 'CONSUMABLE'
                        WHEN upper(trim(coalesce(inventory.classification, ''))) LIKE '%LLAVE%'
                          OR upper(trim(coalesce(inventory.classification, ''))) LIKE '%ACCESO%'
                            THEN 'ACCESS_KEY'
                        WHEN upper(trim(coalesce(inventory.classification, ''))) LIKE '%EQUIPO%'
                            THEN 'EQUIPMENT'
                        ELSE 'MANUAL_TOOL'
                    END
                 AND lower(trim(catalog.name)) = lower(trim(inventory.name))
            )
            UPDATE tool_inventory_items AS inventory
            SET catalog_item_id = target.catalog_id,
                updated_at = now()
            FROM inventory_target AS target
            WHERE inventory.id = target.inventory_id
              AND inventory.catalog_item_id IS DISTINCT FROM target.catalog_id
            """
        )
    )

    op.execute(
        sa.text(
            """
            UPDATE tool_catalog_items AS catalog
            SET is_active = FALSE,
                updated_at = now()
            WHERE catalog.is_active
              AND NOT EXISTS (
                  SELECT 1 FROM tool_inventory_items AS inventory
                  WHERE inventory.catalog_item_id = catalog.id
              )
              AND NOT EXISTS (
                  SELECT 1 FROM tools AS tool
                  WHERE tool.catalog_item_id = catalog.id AND tool.is_active
              )
              AND NOT EXISTS (
                  SELECT 1 FROM maintenance_operational_checklist_items AS checklist
                  WHERE checklist.catalog_item_id = catalog.id
              )
            """
        )
    )


def downgrade() -> None:
    # The previous grouping cannot be reconstructed reliably because it mixed
    # classification with the editable descriptive category.
    pass
