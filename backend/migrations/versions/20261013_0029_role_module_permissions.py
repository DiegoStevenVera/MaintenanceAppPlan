"""Configurable role permissions by application module.

Revision ID: 20261013_0029
Revises: 20260925_0028
"""

import sqlalchemy as sa
from alembic import op


revision = "20261013_0029"
down_revision = "20260925_0028"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "role_module_permissions",
        sa.Column("role", sa.String(length=40), nullable=False),
        sa.Column("module", sa.String(length=40), nullable=False),
        sa.Column("permission_level", sa.String(length=16), nullable=False),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.CheckConstraint(
            "permission_level IN ('NONE', 'READ', 'WRITE')",
            name="ck_role_module_permission_level",
        ),
        sa.PrimaryKeyConstraint("role", "module"),
    )


def downgrade() -> None:
    op.drop_table("role_module_permissions")
