"""expand legacy record mappings

Revision ID: 20260724_0005
Revises: 20260724_0004
Create Date: 2026-07-24
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260724_0005"
down_revision: str | None = "20260724_0004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "legacy_record_mappings",
        sa.Column(
            "mapping_role",
            sa.String(length=100),
            server_default="PRIMARY",
            nullable=False,
        ),
    )
    op.drop_constraint(
        "uq_legacy_record_mappings_source_key",
        "legacy_record_mappings",
        type_="unique",
    )
    op.drop_constraint(
        "uq_legacy_record_mappings_target_source",
        "legacy_record_mappings",
        type_="unique",
    )
    op.create_unique_constraint(
        "uq_legacy_record_mappings_source_target_role",
        "legacy_record_mappings",
        [
            "source_system",
            "source_table",
            "source_primary_key",
            "target_table",
            "mapping_role",
        ],
    )
    op.create_index(
        "ix_legacy_record_mappings_source_key",
        "legacy_record_mappings",
        ["source_system", "source_table", "source_primary_key"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_legacy_record_mappings_source_key",
        table_name="legacy_record_mappings",
    )
    op.drop_constraint(
        "uq_legacy_record_mappings_source_target_role",
        "legacy_record_mappings",
        type_="unique",
    )

    duplicates = sa.text(
        """
        SELECT 1
        FROM legacy_record_mappings
        GROUP BY source_system, source_table, source_primary_key
        HAVING COUNT(*) > 1
        LIMIT 1
        """
    )
    connection = op.get_bind()
    if connection.execute(duplicates).scalar() is not None:
        raise RuntimeError(
            "Cannot downgrade: source records already map to multiple normalized targets."
        )

    op.create_unique_constraint(
        "uq_legacy_record_mappings_target_source",
        "legacy_record_mappings",
        ["target_table", "target_record_id", "source_system"],
    )
    op.create_unique_constraint(
        "uq_legacy_record_mappings_source_key",
        "legacy_record_mappings",
        ["source_system", "source_table", "source_primary_key"],
    )
    op.drop_column("legacy_record_mappings", "mapping_role")
