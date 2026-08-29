"""add internal report audit events

Revision ID: 20260828_0014
Revises: 20260819_0013
Create Date: 2026-08-28
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


revision: str = "20260828_0014"
down_revision: str | None = "20260819_0013"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "report_audit_events",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "maintenance_activity_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("maintenance_activities.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "report_version_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("report_versions.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("event_type", sa.String(length=50), nullable=False),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "actor_user_id",
            sa.String(length=80),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column("details", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
    )
    op.create_index(
        "ix_report_audit_events_maintenance_activity_id",
        "report_audit_events",
        ["maintenance_activity_id"],
    )
    op.create_index(
        "ix_report_audit_events_report_version_id",
        "report_audit_events",
        ["report_version_id"],
    )
    op.create_index(
        "ix_report_audit_events_event_type",
        "report_audit_events",
        ["event_type"],
    )
    op.create_index(
        "ix_report_audit_events_actor_user_id",
        "report_audit_events",
        ["actor_user_id"],
    )
    op.create_index(
        "ix_report_audit_events_activity_occurred_at",
        "report_audit_events",
        ["maintenance_activity_id", "occurred_at"],
    )
    op.create_index(
        "ix_report_audit_events_version_occurred_at",
        "report_audit_events",
        ["report_version_id", "occurred_at"],
    )


def downgrade() -> None:
    op.drop_table("report_audit_events")
