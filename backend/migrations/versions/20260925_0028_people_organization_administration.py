"""People and organization administration fields.

Revision ID: 20260925_0028
Revises: 20260925_0027
"""

import sqlalchemy as sa
from alembic import op


revision = "20260925_0028"
down_revision = "20260925_0027"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column("users", "role_label", type_=sa.String(length=120))
    op.add_column(
        "users",
        sa.Column("job_title", sa.String(length=120), nullable=False, server_default=""),
    )
    op.add_column(
        "users",
        sa.Column(
            "appears_in_schedule",
            sa.Boolean(),
            nullable=False,
            server_default=sa.true(),
        ),
    )
    op.execute("UPDATE users SET job_title = role_label WHERE job_title = ''")


def downgrade() -> None:
    op.drop_column("users", "appears_in_schedule")
    op.drop_column("users", "job_title")
    op.alter_column("users", "role_label", type_=sa.String(length=80))
