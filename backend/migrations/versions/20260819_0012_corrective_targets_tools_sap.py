"""add corrective affected assets, logical groups, and report tool snapshots

Revision ID: 20260819_0012
Revises: 20260812_0011
Create Date: 2026-08-19
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


revision: str = "20260819_0012"
down_revision: str | None = "20260812_0011"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "corrective_equipment_groups",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("code", sa.String(length=80), nullable=False, unique=True),
        sa.Column("name", sa.String(length=240), nullable=False),
        sa.Column(
            "subsystem_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("subsystems.id"),
            nullable=False,
        ),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_index(
        "ix_corrective_equipment_groups_subsystem_id",
        "corrective_equipment_groups",
        ["subsystem_id"],
    )
    op.create_table(
        "corrective_equipment_group_members",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "group_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("corrective_equipment_groups.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("asset_id", sa.String(length=80), sa.ForeignKey("assets.id"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.UniqueConstraint("group_id", "asset_id", name="uq_corrective_group_member"),
    )
    op.create_index(
        "ix_corrective_equipment_group_members_asset_id",
        "corrective_equipment_group_members",
        ["asset_id"],
    )
    op.add_column(
        "corrective_events",
        sa.Column(
            "corrective_equipment_group_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("corrective_equipment_groups.id"),
            nullable=True,
        ),
    )
    op.create_table(
        "corrective_event_affected_assets",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "corrective_event_id",
            sa.String(length=80),
            sa.ForeignKey("corrective_events.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("asset_id", sa.String(length=80), sa.ForeignKey("assets.id"), nullable=False),
        sa.Column("path_snapshot", sa.Text(), nullable=False),
        sa.Column("is_critical", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.UniqueConstraint("corrective_event_id", "asset_id", name="uq_corrective_event_affected_asset"),
    )
    op.create_index(
        "ix_corrective_event_affected_assets_asset_id",
        "corrective_event_affected_assets",
        ["asset_id"],
    )
    op.add_column(
        "report_tool_usages",
        sa.Column("tool_name_snapshot", sa.String(length=200), nullable=True),
    )
    op.add_column(
        "report_tool_usages",
        sa.Column("tool_serial_snapshot", sa.String(length=120), nullable=True),
    )
    op.add_column(
        "report_tool_usages",
        sa.Column("certification_number_snapshot", sa.String(length=160), nullable=True),
    )
    op.add_column(
        "report_tool_usages",
        sa.Column("certification_valid_until_snapshot", sa.Date(), nullable=True),
    )

    # Preserve every imported corrective as a one-asset event before new multi-select
    # creation becomes available.
    op.execute(
        """
        INSERT INTO corrective_event_affected_assets
            (id, corrective_event_id, asset_id, path_snapshot, is_critical, created_at, updated_at)
        SELECT gen_random_uuid(), id, affected_asset_id, affected_asset_path, false, now(), now()
        FROM corrective_events
        WHERE affected_asset_id IS NOT NULL
        ON CONFLICT (corrective_event_id, asset_id) DO NOTHING
        """
    )

    # Logical ATS groups are corrective roots, never physical assets. The member names
    # match both historic LIM-prefixed imports and the shorter operational naming.
    op.execute(
        """
        INSERT INTO corrective_equipment_groups (id, code, name, subsystem_id, is_active, created_at, updated_at)
        SELECT gen_random_uuid(), seed.code, seed.name, s.id, true, now(), now()
        FROM (VALUES
            ('ATS_PCON', 'SOFTWARE ATS PCON'),
            ('ATS_PCOE', 'SOFTWARE ATS PCOE')
        ) AS seed(code, name)
        JOIN subsystems s ON upper(s.name) = 'ATS'
        ON CONFLICT (code) DO NOTHING
        """
    )
    op.execute(
        """
        INSERT INTO corrective_equipment_group_members (id, group_id, asset_id, created_at, updated_at)
        SELECT gen_random_uuid(), g.id, a.id, now(), now()
        FROM corrective_equipment_groups g
        JOIN assets a ON (
            (g.code = 'ATS_PCON' AND upper(regexp_replace(a.name, '[^A-Za-z0-9]', '', 'g')) ~ '^(LIM)?(SYS|DBC|COM|CWS|OVW)00[1-9]$')
            OR
            (g.code = 'ATS_PCOE' AND upper(regexp_replace(a.name, '[^A-Za-z0-9]', '', 'g')) ~ '^(LIM)?(SYS|DBC|COM|CWS|OVW)10[1-9]$')
        )
        WHERE g.code IN ('ATS_PCON', 'ATS_PCOE')
        ON CONFLICT (group_id, asset_id) DO NOTHING
        """
    )


def downgrade() -> None:
    op.drop_column("report_tool_usages", "certification_valid_until_snapshot")
    op.drop_column("report_tool_usages", "certification_number_snapshot")
    op.drop_column("report_tool_usages", "tool_serial_snapshot")
    op.drop_column("report_tool_usages", "tool_name_snapshot")
    op.drop_index("ix_corrective_event_affected_assets_asset_id", table_name="corrective_event_affected_assets")
    op.drop_table("corrective_event_affected_assets")
    op.drop_column("corrective_events", "corrective_equipment_group_id")
    op.drop_index("ix_corrective_equipment_group_members_asset_id", table_name="corrective_equipment_group_members")
    op.drop_table("corrective_equipment_group_members")
    op.drop_index("ix_corrective_equipment_groups_subsystem_id", table_name="corrective_equipment_groups")
    op.drop_table("corrective_equipment_groups")
