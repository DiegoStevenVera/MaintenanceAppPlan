"""foundational catalogs

Revision ID: 20260724_0003
Revises: 20260706_0002
Create Date: 2026-07-24
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260724_0003"
down_revision: str | None = "20260706_0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _catalog_columns() -> list[sa.Column]:
    return [
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("legacy_id", sa.Integer(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    ]


def _catalog_constraints(table_name: str) -> list[sa.Constraint]:
    return [
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("legacy_id", name=f"uq_{table_name}_legacy_id"),
    ]


def upgrade() -> None:
    op.create_table(
        "sites",
        *_catalog_columns(),
        sa.Column("name", sa.String(length=160), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        *_catalog_constraints("sites"),
        sa.UniqueConstraint("name", name="uq_sites_name"),
    )

    op.create_table(
        "projects",
        *_catalog_columns(),
        sa.Column("site_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(length=200), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.ForeignKeyConstraint(["site_id"], ["sites.id"]),
        *_catalog_constraints("projects"),
        sa.UniqueConstraint("site_id", "name", name="uq_projects_site_name"),
    )
    op.create_index(op.f("ix_projects_site_id"), "projects", ["site_id"], unique=False)

    op.create_table(
        "stages",
        *_catalog_columns(),
        sa.Column("project_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(length=160), nullable=False),
        sa.Column("planned_start_date", sa.Date(), nullable=True),
        sa.Column("planned_end_date", sa.Date(), nullable=True),
        sa.Column("operational_status", sa.String(length=40), nullable=True),
        sa.ForeignKeyConstraint(["project_id"], ["projects.id"]),
        *_catalog_constraints("stages"),
        sa.UniqueConstraint("project_id", "name", name="uq_stages_project_name"),
    )
    op.create_index(op.f("ix_stages_project_id"), "stages", ["project_id"], unique=False)

    op.create_table(
        "systems",
        *_catalog_columns(),
        sa.Column("project_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(length=160), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.ForeignKeyConstraint(["project_id"], ["projects.id"]),
        *_catalog_constraints("systems"),
        sa.UniqueConstraint("project_id", "name", name="uq_systems_project_name"),
    )
    op.create_index(op.f("ix_systems_project_id"), "systems", ["project_id"], unique=False)

    op.create_table(
        "subsystems",
        *_catalog_columns(),
        sa.Column("system_id", sa.Uuid(), nullable=False),
        sa.Column("code", sa.String(length=40), nullable=False),
        sa.Column("name", sa.String(length=160), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.ForeignKeyConstraint(["system_id"], ["systems.id"]),
        *_catalog_constraints("subsystems"),
        sa.UniqueConstraint("system_id", "code", name="uq_subsystems_system_code"),
        sa.UniqueConstraint("system_id", "name", name="uq_subsystems_system_name"),
    )
    op.create_index(op.f("ix_subsystems_system_id"), "subsystems", ["system_id"], unique=False)

    op.create_table(
        "work_areas",
        *_catalog_columns(),
        sa.Column("name", sa.String(length=160), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        *_catalog_constraints("work_areas"),
        sa.UniqueConstraint("name", name="uq_work_areas_name"),
    )

    op.create_table(
        "equipment_kinds",
        *_catalog_columns(),
        sa.Column("name", sa.String(length=160), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        *_catalog_constraints("equipment_kinds"),
        sa.UniqueConstraint("name", name="uq_equipment_kinds_name"),
    )

    op.create_table(
        "slot_types",
        *_catalog_columns(),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        *_catalog_constraints("slot_types"),
        sa.UniqueConstraint("name", name="uq_slot_types_name"),
    )

    op.create_table(
        "asset_statuses",
        *_catalog_columns(),
        sa.Column("code", sa.String(length=60), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        *_catalog_constraints("asset_statuses"),
        sa.UniqueConstraint("code", name="uq_asset_statuses_code"),
        sa.UniqueConstraint("name", name="uq_asset_statuses_name"),
    )

    op.create_table(
        "movement_types",
        *_catalog_columns(),
        sa.Column("code", sa.String(length=60), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        *_catalog_constraints("movement_types"),
        sa.UniqueConstraint("code", name="uq_movement_types_code"),
        sa.UniqueConstraint("name", name="uq_movement_types_name"),
    )

    op.create_table(
        "location_types",
        *_catalog_columns(),
        sa.Column("code", sa.String(length=60), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        *_catalog_constraints("location_types"),
        sa.UniqueConstraint("code", name="uq_location_types_code"),
        sa.UniqueConstraint("name", name="uq_location_types_name"),
    )

    op.create_table(
        "manufacturers",
        *_catalog_columns(),
        sa.Column("name", sa.String(length=160), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        *_catalog_constraints("manufacturers"),
        sa.UniqueConstraint("name", name="uq_manufacturers_name"),
    )

    op.create_table(
        "maintenance_action_types",
        *_catalog_columns(),
        sa.Column("code", sa.String(length=60), nullable=False),
        sa.Column("name", sa.String(length=160), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        *_catalog_constraints("maintenance_action_types"),
        sa.UniqueConstraint("code", name="uq_maintenance_action_types_code"),
        sa.UniqueConstraint("name", name="uq_maintenance_action_types_name"),
    )

    op.create_table(
        "equipment_categories",
        *_catalog_columns(),
        sa.Column("subsystem_id", sa.Uuid(), nullable=False),
        sa.Column("name_n1", sa.String(length=160), nullable=False),
        sa.Column("name_n2", sa.String(length=160), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.ForeignKeyConstraint(["subsystem_id"], ["subsystems.id"]),
        *_catalog_constraints("equipment_categories"),
        sa.UniqueConstraint(
            "subsystem_id",
            "name_n1",
            "name_n2",
            name="uq_equipment_categories_scope_names",
        ),
    )
    op.create_index(
        op.f("ix_equipment_categories_subsystem_id"),
        "equipment_categories",
        ["subsystem_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_equipment_categories_subsystem_id"),
        table_name="equipment_categories",
    )
    op.drop_table("equipment_categories")
    op.drop_table("maintenance_action_types")
    op.drop_table("manufacturers")
    op.drop_table("location_types")
    op.drop_table("movement_types")
    op.drop_table("asset_statuses")
    op.drop_table("slot_types")
    op.drop_table("equipment_kinds")
    op.drop_table("work_areas")
    op.drop_index(op.f("ix_subsystems_system_id"), table_name="subsystems")
    op.drop_table("subsystems")
    op.drop_index(op.f("ix_systems_project_id"), table_name="systems")
    op.drop_table("systems")
    op.drop_index(op.f("ix_stages_project_id"), table_name="stages")
    op.drop_table("stages")
    op.drop_index(op.f("ix_projects_site_id"), table_name="projects")
    op.drop_table("projects")
    op.drop_table("sites")
