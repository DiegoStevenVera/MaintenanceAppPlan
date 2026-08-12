"""add PCON weekly planning sessions and schedule revisions

Revision ID: 20260730_0009
Revises: 20260729_0008
Create Date: 2026-07-30
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260730_0009"
down_revision: str | None = "20260729_0008"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "weekly_planning_sessions",
        sa.Column("week_start", sa.Date(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_by_user_id", sa.String(length=80), nullable=False),
        sa.Column("confirmed_by_user_id", sa.String(length=80), nullable=True),
        sa.Column("confirmed_at", sa.DateTime(timezone=True), nullable=True),
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
            "status IN ('DRAFT', 'CONFIRMED')",
            name="ck_weekly_planning_sessions_status",
        ),
        sa.ForeignKeyConstraint(["confirmed_by_user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["created_by_user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "week_start",
            "version",
            name="uq_weekly_planning_sessions_week_version",
        ),
    )
    op.create_index(
        op.f("ix_weekly_planning_sessions_status"),
        "weekly_planning_sessions",
        ["status"],
    )
    op.create_index(
        op.f("ix_weekly_planning_sessions_week_start"),
        "weekly_planning_sessions",
        ["week_start"],
    )
    op.create_table(
        "maintenance_schedule_revisions",
        sa.Column("weekly_planning_session_id", sa.Uuid(), nullable=False),
        sa.Column("maintenance_activity_id", sa.Uuid(), nullable=False),
        sa.Column("proposed_start_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("proposed_end_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("previous_start_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("previous_end_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("reason", sa.Text(), nullable=True),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("created_by_user_id", sa.String(length=80), nullable=False),
        sa.Column("confirmed_by_user_id", sa.String(length=80), nullable=True),
        sa.Column("confirmed_at", sa.DateTime(timezone=True), nullable=True),
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
            "status IN ('PROPOSED', 'CONFIRMED', 'SUPERSEDED')",
            name="ck_maintenance_schedule_revisions_status",
        ),
        sa.CheckConstraint(
            "proposed_end_at > proposed_start_at",
            name="ck_maintenance_schedule_revisions_time_range",
        ),
        sa.ForeignKeyConstraint(["confirmed_by_user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["created_by_user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(
            ["maintenance_activity_id"],
            ["maintenance_activities.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["weekly_planning_session_id"],
            ["weekly_planning_sessions.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "weekly_planning_session_id",
            "maintenance_activity_id",
            name="uq_maintenance_schedule_revisions_session_activity",
        ),
    )
    op.create_index(
        op.f("ix_maintenance_schedule_revisions_maintenance_activity_id"),
        "maintenance_schedule_revisions",
        ["maintenance_activity_id"],
    )
    op.create_index(
        op.f("ix_maintenance_schedule_revisions_status"),
        "maintenance_schedule_revisions",
        ["status"],
    )
    op.create_index(
        op.f("ix_maintenance_schedule_revisions_weekly_planning_session_id"),
        "maintenance_schedule_revisions",
        ["weekly_planning_session_id"],
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_maintenance_schedule_revisions_weekly_planning_session_id"),
        table_name="maintenance_schedule_revisions",
    )
    op.drop_index(
        op.f("ix_maintenance_schedule_revisions_status"),
        table_name="maintenance_schedule_revisions",
    )
    op.drop_index(
        op.f("ix_maintenance_schedule_revisions_maintenance_activity_id"),
        table_name="maintenance_schedule_revisions",
    )
    op.drop_table("maintenance_schedule_revisions")
    op.drop_index(
        op.f("ix_weekly_planning_sessions_week_start"),
        table_name="weekly_planning_sessions",
    )
    op.drop_index(
        op.f("ix_weekly_planning_sessions_status"),
        table_name="weekly_planning_sessions",
    )
    op.drop_table("weekly_planning_sessions")
