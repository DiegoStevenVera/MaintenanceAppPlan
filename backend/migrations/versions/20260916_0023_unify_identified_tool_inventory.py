"""Expose identified electronic tools through the physical inventory master."""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


revision: str = "20260916_0023"
down_revision: str | Sequence[str] | None = "20260915_0022"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "tool_inventory_items",
        sa.Column(
            "tool_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("tools.id", ondelete="SET NULL"),
        ),
    )
    op.create_index(
        "uq_tool_inventory_items_tool_id",
        "tool_inventory_items",
        ["tool_id"],
        unique=True,
        postgresql_where=sa.text("tool_id IS NOT NULL"),
    )

    # Reuse inventory rows that already identify the same electronic unit.
    op.execute(
        sa.text(
            """
            WITH matches AS (
                SELECT DISTINCT ON (tool.id)
                    inventory.id AS inventory_id,
                    tool.id AS tool_id
                FROM tools AS tool
                JOIN tool_inventory_items AS inventory
                  ON inventory.catalog_item_id = tool.catalog_item_id
                 AND upper(trim(coalesce(inventory.tool_code, inventory.label, '')))
                     = upper(trim(tool.serial_number))
                WHERE tool.is_active
                  AND inventory.tool_id IS NULL
                ORDER BY tool.id, inventory.source_row_number
            )
            UPDATE tool_inventory_items AS inventory
            SET tool_id = tool.id,
                quantity = 1,
                classification = 'EQUIPO',
                updated_at = now()
            FROM tools AS tool, matches
            WHERE inventory.id = matches.inventory_id
              AND tool.id = matches.tool_id
            """
        )
    )

    op.execute(
        sa.text(
            """
            INSERT INTO tool_inventory (
                id, catalog_item_id, tool_id, location, available, unavailable
            )
            SELECT
                md5(tool.id::text || '-stock')::uuid,
                tool.catalog_item_id,
                tool.id,
                coalesce(nullif(tool.current_location, ''), 'Sin ubicación'),
                CASE
                    WHEN upper(tool.availability_status) IN ('AVAILABLE', 'DISPONIBLE', 'IN_STOCK')
                        THEN 1 ELSE 0
                END,
                CASE
                    WHEN upper(tool.availability_status) IN ('AVAILABLE', 'DISPONIBLE', 'IN_STOCK')
                        THEN 0 ELSE 1
                END
            FROM tools AS tool
            WHERE tool.is_active
              AND tool.catalog_item_id IS NOT NULL
              AND NOT EXISTS (
                  SELECT 1 FROM tool_inventory AS inventory
                  WHERE inventory.tool_id = tool.id
              )
            """
        )
    )

    # Every identified unit must also be visible in the unified inventory tab.
    op.execute(
        sa.text(
            """
            INSERT INTO tool_inventory_items (
                id, source_file, source_row_number, catalog_item_id, tool_id,
                model_code, tool_code, label, quantity, name, description,
                company, classification, category, location_text, status,
                observations, imported_at, created_at, updated_at
            )
            SELECT
                md5(tool.id::text || '-inventory-item')::uuid,
                'IDENTIFIED_TOOLS',
                row_number() OVER (ORDER BY tool.id),
                tool.catalog_item_id,
                tool.id,
                tool.model,
                tool.serial_number,
                tool.serial_number,
                1,
                tool.name,
                concat_ws(' · ', nullif(tool.brand, ''), nullif(tool.model, '')),
                tool.brand,
                'EQUIPO',
                coalesce(nullif(tool.tool_type, ''), 'INSTRUMENTO'),
                tool.current_location,
                CASE
                    WHEN upper(tool.availability_status) IN ('AVAILABLE', 'DISPONIBLE', 'IN_STOCK')
                        THEN 'DISPONIBLE'
                    WHEN upper(tool.availability_status) IN ('DAMAGED', 'AVERIADO')
                        THEN 'AVERIADO'
                    ELSE 'SIN STOCK'
                END,
                'Unidad identificada migrada desde tools',
                now(), now(), now()
            FROM tools AS tool
            WHERE tool.is_active
              AND tool.catalog_item_id IS NOT NULL
              AND NOT EXISTS (
                  SELECT 1
                  FROM tool_inventory_items AS inventory
                  WHERE inventory.tool_id = tool.id
              )
            """
        )
    )

    op.execute(
        sa.text(
            """
            UPDATE tool_catalog_items AS catalog
            SET category = 'EQUIPMENT',
                requires_identified_unit = TRUE,
                is_active = TRUE,
                updated_at = now()
            WHERE EXISTS (
                SELECT 1 FROM tools AS tool
                WHERE tool.catalog_item_id = catalog.id AND tool.is_active
            )
            """
        )
    )


def downgrade() -> None:
    op.execute(
        sa.text(
            "DELETE FROM tool_inventory_items WHERE source_file = 'IDENTIFIED_TOOLS'"
        )
    )
    op.execute(
        sa.text(
            """
            DELETE FROM tool_inventory AS inventory
            USING tools AS tool
            WHERE inventory.tool_id = tool.id
              AND inventory.id = md5(tool.id::text || '-stock')::uuid
              AND NOT EXISTS (
                  SELECT 1 FROM tool_inventory_movements AS movement
                  WHERE movement.inventory_id = inventory.id
              )
            """
        )
    )
    op.drop_index("uq_tool_inventory_items_tool_id", table_name="tool_inventory_items")
    op.drop_column("tool_inventory_items", "tool_id")
