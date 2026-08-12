"""add annual corrective report numbering

Revision ID: 20260729_0008
Revises: 20260727_0007
Create Date: 2026-07-29
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260729_0008"
down_revision: str | None = "20260727_0007"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "maintenance_reports",
        sa.Column("report_year", sa.Integer(), nullable=True),
    )
    op.create_index(
        op.f("ix_maintenance_reports_report_year"),
        "maintenance_reports",
        ["report_year"],
        unique=False,
    )
    # Move legacy per-activity numbers to a collision-free temporary range before
    # assigning the definitive annual sequence.
    op.execute(
        """
        WITH temporary_numbers AS (
            SELECT
                id,
                -ROW_NUMBER() OVER (ORDER BY id) AS temporary_number
            FROM maintenance_reports
            WHERE report_kind = 'CORRECTIVE'
        )
        UPDATE maintenance_reports mr
        SET report_number = temporary_numbers.temporary_number
        FROM temporary_numbers
        WHERE mr.id = temporary_numbers.id
        """
    )
    op.execute(
        """
        WITH ranked AS (
            SELECT
                mr.id,
                EXTRACT(
                    YEAR FROM COALESCE(
                        ma.actual_start_at,
                        ma.scheduled_start_at,
                        mr.created_at
                    )
                )::integer AS report_year,
                ROW_NUMBER() OVER (
                    PARTITION BY EXTRACT(
                        YEAR FROM COALESCE(
                            ma.actual_start_at,
                            ma.scheduled_start_at,
                            mr.created_at
                        )
                    )
                    ORDER BY
                        COALESCE(
                            ma.actual_start_at,
                            ma.scheduled_start_at,
                            mr.created_at
                        ),
                        mr.created_at,
                        mr.id
                ) AS annual_number
            FROM maintenance_reports mr
            JOIN maintenance_activities ma
              ON ma.id = mr.maintenance_activity_id
            WHERE mr.report_kind = 'CORRECTIVE'
        )
        UPDATE maintenance_reports mr
        SET
            report_year = ranked.report_year,
            report_number = ranked.annual_number
        FROM ranked
        WHERE mr.id = ranked.id
        """
    )
    op.create_index(
        "uq_corrective_reports_year_number",
        "maintenance_reports",
        ["report_year", "report_number"],
        unique=True,
        postgresql_where=sa.text(
            "report_kind = 'CORRECTIVE' AND report_year IS NOT NULL"
        ),
    )


def downgrade() -> None:
    op.drop_index(
        "uq_corrective_reports_year_number",
        table_name="maintenance_reports",
    )
    op.drop_index(
        op.f("ix_maintenance_reports_report_year"),
        table_name="maintenance_reports",
    )
    op.drop_column("maintenance_reports", "report_year")
