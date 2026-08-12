"""add PCON annual administration and audit

Revision ID: 20260730_0010
Revises: 20260730_0009
Create Date: 2026-07-30
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "20260730_0010"
down_revision: str | None = "20260730_0009"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "maintenance_plan_entries",
        sa.Column(
            "planning_status",
            sa.String(length=20),
            server_default="PLANNED",
            nullable=False,
        ),
    )
    op.add_column(
        "maintenance_plan_entries",
        sa.Column("cancelled_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "maintenance_plan_entries",
        sa.Column("cancelled_by_user_id", sa.String(length=80), nullable=True),
    )
    op.add_column(
        "maintenance_plan_entries",
        sa.Column("cancellation_reason", sa.Text(), nullable=True),
    )
    op.create_foreign_key(
        "fk_maintenance_plan_entries_cancelled_by_user_id",
        "maintenance_plan_entries",
        "users",
        ["cancelled_by_user_id"],
        ["id"],
    )
    op.create_index(
        op.f("ix_maintenance_plan_entries_planning_status"),
        "maintenance_plan_entries",
        ["planning_status"],
    )

    op.create_table(
        "pcon_annual_plans",
        sa.Column("year", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("copied_from_year", sa.Integer(), nullable=True),
        sa.Column("created_by_user_id", sa.String(length=80), nullable=True),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "status IN ('DRAFT', 'ACTIVE', 'CLOSED')",
            name="ck_pcon_annual_plans_status",
        ),
        sa.ForeignKeyConstraint(["created_by_user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("year", name="uq_pcon_annual_plans_year"),
    )
    op.create_index(
        op.f("ix_pcon_annual_plans_year"),
        "pcon_annual_plans",
        ["year"],
    )

    op.create_table(
        "pcon_annual_plan_scopes",
        sa.Column("annual_plan_id", sa.Uuid(), nullable=False),
        sa.Column("maintenance_template_scope_id", sa.Uuid(), nullable=False),
        sa.Column(
            "is_active",
            sa.Boolean(),
            server_default=sa.text("true"),
            nullable=False,
        ),
        sa.Column("created_by_user_id", sa.String(length=80), nullable=True),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["annual_plan_id"],
            ["pcon_annual_plans.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(["created_by_user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(
            ["maintenance_template_scope_id"],
            ["maintenance_template_scopes.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "annual_plan_id",
            "maintenance_template_scope_id",
            name="uq_pcon_annual_plan_scopes_membership",
        ),
    )
    op.create_index(
        op.f("ix_pcon_annual_plan_scopes_annual_plan_id"),
        "pcon_annual_plan_scopes",
        ["annual_plan_id"],
    )
    op.create_index(
        op.f("ix_pcon_annual_plan_scopes_maintenance_template_scope_id"),
        "pcon_annual_plan_scopes",
        ["maintenance_template_scope_id"],
    )

    op.create_table(
        "pcon_plan_changes",
        sa.Column("action", sa.String(length=40), nullable=False),
        sa.Column("year", sa.Integer(), nullable=False),
        sa.Column("month", sa.Integer(), nullable=True),
        sa.Column("maintenance_template_scope_id", sa.Uuid(), nullable=True),
        sa.Column("maintenance_plan_entry_id", sa.Uuid(), nullable=True),
        sa.Column("quantity_delta", sa.Integer(), nullable=True),
        sa.Column("reason", sa.Text(), nullable=True),
        sa.Column("changed_by_user_id", sa.String(length=80), nullable=False),
        sa.Column("details", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["changed_by_user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(
            ["maintenance_plan_entry_id"],
            ["maintenance_plan_entries.id"],
        ),
        sa.ForeignKeyConstraint(
            ["maintenance_template_scope_id"],
            ["maintenance_template_scopes.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_pcon_plan_changes_action"),
        "pcon_plan_changes",
        ["action"],
    )
    op.create_index(
        op.f("ix_pcon_plan_changes_year"),
        "pcon_plan_changes",
        ["year"],
    )
    op.create_index(
        op.f("ix_pcon_plan_changes_maintenance_template_scope_id"),
        "pcon_plan_changes",
        ["maintenance_template_scope_id"],
    )
    op.create_index(
        op.f("ix_pcon_plan_changes_maintenance_plan_entry_id"),
        "pcon_plan_changes",
        ["maintenance_plan_entry_id"],
    )

    op.execute(
        """
        INSERT INTO pcon_annual_plans (
            id, year, status, copied_from_year, created_by_user_id,
            created_at, updated_at
        )
        SELECT
            gen_random_uuid(),
            years.year,
            CASE
                WHEN years.year < EXTRACT(YEAR FROM CURRENT_DATE)::int THEN 'CLOSED'
                WHEN years.year = EXTRACT(YEAR FROM CURRENT_DATE)::int THEN 'ACTIVE'
                ELSE 'DRAFT'
            END,
            NULL,
            NULL,
            now(),
            now()
        FROM (
            SELECT DISTINCT year
            FROM maintenance_plan_entries
        ) AS years
        """
    )
    op.execute(
        """
        INSERT INTO pcon_annual_plan_scopes (
            id, annual_plan_id, maintenance_template_scope_id,
            is_active, created_by_user_id, created_at, updated_at
        )
        SELECT
            gen_random_uuid(),
            plans.id,
            entries.maintenance_template_scope_id,
            true,
            NULL,
            now(),
            now()
        FROM pcon_annual_plans plans
        JOIN (
            SELECT DISTINCT year, maintenance_template_scope_id
            FROM maintenance_plan_entries
        ) entries ON entries.year = plans.year
        """
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_pcon_plan_changes_maintenance_plan_entry_id"),
        table_name="pcon_plan_changes",
    )
    op.drop_index(
        op.f("ix_pcon_plan_changes_maintenance_template_scope_id"),
        table_name="pcon_plan_changes",
    )
    op.drop_index(op.f("ix_pcon_plan_changes_year"), table_name="pcon_plan_changes")
    op.drop_index(op.f("ix_pcon_plan_changes_action"), table_name="pcon_plan_changes")
    op.drop_table("pcon_plan_changes")
    op.drop_index(
        op.f("ix_pcon_annual_plan_scopes_maintenance_template_scope_id"),
        table_name="pcon_annual_plan_scopes",
    )
    op.drop_index(
        op.f("ix_pcon_annual_plan_scopes_annual_plan_id"),
        table_name="pcon_annual_plan_scopes",
    )
    op.drop_table("pcon_annual_plan_scopes")
    op.drop_index(op.f("ix_pcon_annual_plans_year"), table_name="pcon_annual_plans")
    op.drop_table("pcon_annual_plans")
    op.drop_index(
        op.f("ix_maintenance_plan_entries_planning_status"),
        table_name="maintenance_plan_entries",
    )
    op.drop_constraint(
        "fk_maintenance_plan_entries_cancelled_by_user_id",
        "maintenance_plan_entries",
        type_="foreignkey",
    )
    op.drop_column("maintenance_plan_entries", "cancellation_reason")
    op.drop_column("maintenance_plan_entries", "cancelled_by_user_id")
    op.drop_column("maintenance_plan_entries", "cancelled_at")
    op.drop_column("maintenance_plan_entries", "planning_status")
