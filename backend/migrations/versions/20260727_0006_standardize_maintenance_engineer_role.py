"""standardize the maintenance engineer role

Revision ID: 20260727_0006
Revises: 20260724_0005
Create Date: 2026-07-27
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260727_0006"
down_revision: str | None = "20260724_0005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute(
        sa.text(
            """
            UPDATE users
            SET role = 'MAINTENANCE_ENGINEER',
                role_label = 'Ingeniero de Mantenimiento'
            WHERE role = 'TECHNICIAN'
               OR role_label IN (
                   'Tecnico mantenedor',
                   'Técnico mantenedor',
                   'Tecnico Mantenedor',
                   'Técnico Mantenedor'
               )
            """
        )
    )
    op.execute(
        sa.text(
            """
            UPDATE app_state_snapshots
            SET payload = replace(
                replace(
                    payload::text,
                    '"technician"',
                    '"maintenanceEngineer"'
                ),
                '"technicianName"',
                '"engineerName"'
            )::jsonb
            WHERE payload::text LIKE '%"technician"%'
               OR payload::text LIKE '%"technicianName"%'
            """
        )
    )


def downgrade() -> None:
    op.execute(
        sa.text(
            """
            UPDATE users
            SET role = 'TECHNICIAN'
            WHERE role = 'MAINTENANCE_ENGINEER'
            """
        )
    )
    op.execute(
        sa.text(
            """
            UPDATE app_state_snapshots
            SET payload = replace(
                replace(
                    payload::text,
                    '"maintenanceEngineer"',
                    '"technician"'
                ),
                '"engineerName"',
                '"technicianName"'
            )::jsonb
            WHERE payload::text LIKE '%"maintenanceEngineer"%'
               OR payload::text LIKE '%"engineerName"%'
            """
        )
    )
