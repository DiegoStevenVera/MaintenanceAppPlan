"""Add ATS line module permissions.

Revision ID: 20261112_0030
Revises: 20261013_0029
"""

from alembic import op
import sqlalchemy as sa


revision = "20261112_0030"
down_revision = "20261013_0029"
branch_labels = None
depends_on = None


def upgrade() -> None:
    permissions = sa.table(
        "role_module_permissions",
        sa.column("role", sa.String),
        sa.column("module", sa.String),
        sa.column("permission_level", sa.String),
    )
    op.bulk_insert(
        permissions,
        [
            {"role": "MAINTENANCE_ENGINEER", "module": "ATS_LINE", "permission_level": "READ"},
            {"role": "COORDINATOR", "module": "ATS_LINE", "permission_level": "READ"},
            {"role": "BOSS", "module": "ATS_LINE", "permission_level": "READ"},
            {"role": "ADMINISTRATOR", "module": "ATS_LINE", "permission_level": "WRITE"},
        ],
    )


def downgrade() -> None:
    op.execute(
        "DELETE FROM role_module_permissions WHERE module = 'ATS_LINE'"
    )
