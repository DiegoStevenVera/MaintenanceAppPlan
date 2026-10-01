"""Workforce schedules, area viewers and audit trail.

Revision ID: 20260925_0027
Revises: 20260918_0026
"""

from datetime import time

import sqlalchemy as sa
from alembic import op


revision = "20260925_0027"
down_revision = "20260918_0026"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "schedule_shift_types",
        sa.Column("code", sa.String(length=20), nullable=False),
        sa.Column("name", sa.String(length=80), nullable=False),
        sa.Column("description", sa.String(length=240), nullable=False),
        sa.Column("starts_at", sa.Time(), nullable=True),
        sa.Column("ends_at", sa.Time(), nullable=True),
        sa.Column("color_hex", sa.String(length=7), nullable=False),
        sa.Column("applies_to_full_week", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.PrimaryKeyConstraint("code"),
    )
    op.bulk_insert(
        sa.table(
            "schedule_shift_types",
            sa.column("code", sa.String),
            sa.column("name", sa.String),
            sa.column("description", sa.String),
            sa.column("starts_at", sa.Time),
            sa.column("ends_at", sa.Time),
            sa.column("color_hex", sa.String),
            sa.column("applies_to_full_week", sa.Boolean),
            sa.column("is_active", sa.Boolean),
        ),
        [
            {"code": "12M", "name": "Turno dia", "description": "Turno de 08:00 a 20:00", "starts_at": time(8), "ends_at": time(20), "color_hex": "#F7D94C", "applies_to_full_week": False, "is_active": True},
            {"code": "12N", "name": "Turno noche", "description": "Turno de 20:00 a 08:00 del dia siguiente", "starts_at": time(20), "ends_at": time(8), "color_hex": "#78C7F2", "applies_to_full_week": False, "is_active": True},
            {"code": "COO", "name": "Coordinador", "description": "Jornada de coordinacion", "starts_at": None, "ends_at": None, "color_hex": "#F39AA0", "applies_to_full_week": False, "is_active": True},
            {"code": "CBTC", "name": "Otra area", "description": "Asignacion semanal al area CBTC", "starts_at": None, "ends_at": None, "color_hex": "#D49AF2", "applies_to_full_week": True, "is_active": True},
            {"code": "DISPO", "name": "Disponibilidad", "description": "Disponibilidad en dia de descanso", "starts_at": None, "ends_at": None, "color_hex": "#8DDEB2", "applies_to_full_week": False, "is_active": True},
            {"code": "FER", "name": "Feriado", "description": "Descanso compensatorio por feriado", "starts_at": None, "ends_at": None, "color_hex": "#F3A58E", "applies_to_full_week": False, "is_active": True},
        ],
    )
    op.create_table(
        "work_area_schedule_viewers",
        sa.Column("user_id", sa.String(length=80), nullable=False),
        sa.Column("work_area_id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["work_area_id"], ["work_areas.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("user_id", "work_area_id"),
    )
    op.create_table(
        "employee_schedule_entries",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.String(length=80), nullable=False),
        sa.Column("work_area_id", sa.Uuid(), nullable=False),
        sa.Column("work_date", sa.Date(), nullable=False),
        sa.Column("shift_code", sa.String(length=20), nullable=False),
        sa.Column("updated_by_user_id", sa.String(length=80), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["shift_code"], ["schedule_shift_types.code"]),
        sa.ForeignKeyConstraint(["updated_by_user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["work_area_id"], ["work_areas.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "work_date", name="uq_employee_schedule_user_date"),
    )
    op.create_index("ix_employee_schedule_entries_user_id", "employee_schedule_entries", ["user_id"])
    op.create_index("ix_employee_schedule_entries_work_area_id", "employee_schedule_entries", ["work_area_id"])
    op.create_index("ix_employee_schedule_entries_work_date", "employee_schedule_entries", ["work_date"])
    op.create_table(
        "employee_schedule_audit_events",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("target_user_id", sa.String(length=80), nullable=False),
        sa.Column("work_area_id", sa.Uuid(), nullable=False),
        sa.Column("work_date", sa.Date(), nullable=False),
        sa.Column("previous_shift_code", sa.String(length=20), nullable=True),
        sa.Column("new_shift_code", sa.String(length=20), nullable=True),
        sa.Column("change_scope", sa.String(length=20), nullable=False),
        sa.Column("changed_by_user_id", sa.String(length=80), nullable=False),
        sa.Column("reason", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["changed_by_user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["target_user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["work_area_id"], ["work_areas.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_employee_schedule_audit_events_target_user_id", "employee_schedule_audit_events", ["target_user_id"])
    op.create_index("ix_employee_schedule_audit_events_work_area_id", "employee_schedule_audit_events", ["work_area_id"])
    op.create_index("ix_employee_schedule_audit_events_work_date", "employee_schedule_audit_events", ["work_date"])
    op.create_index("ix_employee_schedule_audit_events_changed_by_user_id", "employee_schedule_audit_events", ["changed_by_user_id"])

    # A boss assigned to an area can immediately consult it. Additional areas
    # can be granted later through this relation without changing membership.
    op.execute(
        """
        INSERT INTO work_area_schedule_viewers (user_id, work_area_id)
        SELECT id, work_area_id FROM users
        WHERE role = 'BOSS' AND work_area_id IS NOT NULL
        ON CONFLICT DO NOTHING
        """
    )


def downgrade() -> None:
    op.drop_table("employee_schedule_audit_events")
    op.drop_table("employee_schedule_entries")
    op.drop_table("work_area_schedule_viewers")
    op.drop_table("schedule_shift_types")
