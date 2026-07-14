"""initial schema

Revision ID: 20260705_0001
Revises:
Create Date: 2026-07-05
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "20260705_0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "assets",
        sa.Column("id", sa.String(length=80), nullable=False),
        sa.Column("name", sa.String(length=240), nullable=False),
        sa.Column("category", sa.String(length=120), nullable=False),
        sa.Column("asset_type", sa.String(length=120), nullable=False),
        sa.Column("subsystem", sa.String(length=40), nullable=False),
        sa.Column("serial_or_code", sa.String(length=120), nullable=False),
        sa.Column("part_number", sa.String(length=120), nullable=True),
        sa.Column("status", sa.String(length=80), nullable=False),
        sa.Column("physical_location", sa.Text(), nullable=False),
        sa.Column("is_business_anchor", sa.Boolean(), nullable=False),
        sa.Column("parent_id", sa.String(length=80), nullable=True),
        sa.Column("children", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.ForeignKeyConstraint(["parent_id"], ["assets.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_assets_name"), "assets", ["name"], unique=False)
    op.create_index(op.f("ix_assets_subsystem"), "assets", ["subsystem"], unique=False)

    op.create_table(
        "asset_history",
        sa.Column("id", sa.String(length=80), nullable=False),
        sa.Column("asset_id", sa.String(length=80), nullable=False),
        sa.Column("report_type", sa.String(length=40), nullable=False),
        sa.Column("report_id", sa.String(length=120), nullable=False),
        sa.Column("title", sa.String(length=240), nullable=False),
        sa.Column("performed_at", sa.String(length=80), nullable=False),
        sa.Column("result", sa.String(length=120), nullable=False),
        sa.ForeignKeyConstraint(["asset_id"], ["assets.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_asset_history_asset_id"), "asset_history", ["asset_id"], unique=False)

    op.create_table(
        "corrective_events",
        sa.Column("id", sa.String(length=80), nullable=False),
        sa.Column("code", sa.String(length=80), nullable=False),
        sa.Column("sap_code", sa.String(length=120), nullable=False),
        sa.Column("name", sa.String(length=240), nullable=False),
        sa.Column("affected_asset_id", sa.String(length=80), nullable=True),
        sa.Column("affected_asset_path", sa.Text(), nullable=False),
        sa.Column("subsystem", sa.String(length=40), nullable=False),
        sa.Column("severity", sa.String(length=40), nullable=False),
        sa.Column("status", sa.String(length=40), nullable=False),
        sa.Column("notice_created_at", sa.String(length=80), nullable=False),
        sa.Column("response_at", sa.String(length=80), nullable=False),
        sa.Column("physical_location", sa.Text(), nullable=False),
        sa.Column("report_version_count", sa.Integer(), nullable=False),
        sa.Column("timeline", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_corrective_events_name"), "corrective_events", ["name"], unique=False)
    op.create_index(
        op.f("ix_corrective_events_status"), "corrective_events", ["status"], unique=False
    )
    op.create_index(
        op.f("ix_corrective_events_subsystem"), "corrective_events", ["subsystem"], unique=False
    )

    op.create_table(
        "preventive_schedules",
        sa.Column("id", sa.String(length=80), nullable=False),
        sa.Column("name", sa.String(length=240), nullable=False),
        sa.Column("template_name", sa.String(length=240), nullable=False),
        sa.Column("asset_ids", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("asset_names", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("subsystem", sa.String(length=40), nullable=False),
        sa.Column("scheduled_at", sa.String(length=80), nullable=False),
        sa.Column("status", sa.String(length=40), nullable=False),
        sa.Column("physical_location", sa.Text(), nullable=False),
        sa.Column("report_version_count", sa.Integer(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_preventive_schedules_name"), "preventive_schedules", ["name"], unique=False
    )
    op.create_index(
        op.f("ix_preventive_schedules_status"), "preventive_schedules", ["status"], unique=False
    )
    op.create_index(
        op.f("ix_preventive_schedules_subsystem"),
        "preventive_schedules",
        ["subsystem"],
        unique=False,
    )

    op.create_table(
        "users",
        sa.Column("id", sa.String(length=80), nullable=False),
        sa.Column("name", sa.String(length=160), nullable=False),
        sa.Column("email", sa.String(length=160), nullable=False),
        sa.Column("role", sa.String(length=40), nullable=False),
        sa.Column("role_label", sa.String(length=80), nullable=False),
        sa.Column("password_hash", sa.String(length=240), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_users_email"), "users", ["email"], unique=True)


def downgrade() -> None:
    op.drop_index(op.f("ix_users_email"), table_name="users")
    op.drop_table("users")
    op.drop_index(op.f("ix_preventive_schedules_subsystem"), table_name="preventive_schedules")
    op.drop_index(op.f("ix_preventive_schedules_status"), table_name="preventive_schedules")
    op.drop_index(op.f("ix_preventive_schedules_name"), table_name="preventive_schedules")
    op.drop_table("preventive_schedules")
    op.drop_index(op.f("ix_corrective_events_subsystem"), table_name="corrective_events")
    op.drop_index(op.f("ix_corrective_events_status"), table_name="corrective_events")
    op.drop_index(op.f("ix_corrective_events_name"), table_name="corrective_events")
    op.drop_table("corrective_events")
    op.drop_index(op.f("ix_asset_history_asset_id"), table_name="asset_history")
    op.drop_table("asset_history")
    op.drop_index(op.f("ix_assets_subsystem"), table_name="assets")
    op.drop_index(op.f("ix_assets_name"), table_name="assets")
    op.drop_table("assets")
