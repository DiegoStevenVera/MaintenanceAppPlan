"""move report format codes and revisions to the database

Revision ID: 20260828_0015
Revises: 20260828_0014
Create Date: 2026-08-28
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


revision: str = "20260828_0015"
down_revision: str | Sequence[str] | None = "20260828_0014"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "report_formats",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("report_kind", sa.String(length=40), nullable=False),
        sa.Column("format_code", sa.String(length=80), nullable=False),
        sa.Column("revision", sa.String(length=20), nullable=False),
        sa.Column("template_name", sa.String(length=160), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False, server_default="ACTIVE"),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.UniqueConstraint(
            "report_kind", "format_code", "revision",
            name="uq_report_formats_kind_code_revision",
        ),
    )
    op.create_index("ix_report_formats_report_kind", "report_formats", ["report_kind"])
    op.create_index(
        "uq_report_formats_active_kind",
        "report_formats",
        ["report_kind"],
        unique=True,
        postgresql_where=sa.text("status = 'ACTIVE'"),
    )
    op.add_column(
        "report_versions",
        sa.Column("report_format_id", postgresql.UUID(as_uuid=True), nullable=True),
    )
    op.create_foreign_key(
        "fk_report_versions_report_format_id",
        "report_versions",
        "report_formats",
        ["report_format_id"],
        ["id"],
    )
    op.create_index(
        "ix_report_versions_report_format_id",
        "report_versions",
        ["report_format_id"],
    )
    op.add_column("report_versions", sa.Column("format_code_snapshot", sa.String(length=80)))
    op.add_column("report_versions", sa.Column("format_revision_snapshot", sa.String(length=20)))
    op.add_column("report_versions", sa.Column("format_template_snapshot", sa.String(length=160)))
    op.add_column(
        "asset_replacements",
        sa.Column("source_kind", sa.String(length=40), nullable=False, server_default="WAREHOUSE"),
    )
    op.add_column(
        "asset_replacements",
        sa.Column("donor_parent_asset_id", sa.String(length=80), nullable=True),
    )
    op.create_foreign_key(
        "fk_asset_replacements_donor_parent_asset_id",
        "asset_replacements",
        "assets",
        ["donor_parent_asset_id"],
        ["id"],
    )
    op.create_index(
        "ix_asset_replacements_donor_parent_asset_id",
        "asset_replacements",
        ["donor_parent_asset_id"],
    )

    # These revisions are the approved initial state for the updated templates.
    op.execute("""
        INSERT INTO report_formats (
            id, report_kind, format_code, revision, template_name, status,
            notes, created_at, updated_at
        ) VALUES
            (gen_random_uuid(), 'PREVENTIVE', 'ML2-STS-FOR-040-ES', '1',
             'preventive_report.html', 'ACTIVE', 'Revisión inicial gestionada en base de datos', now(), now()),
            (gen_random_uuid(), 'CORRECTIVE', 'ML2-STS-FOR-041-ES', '2',
             'corrective_report.html', 'ACTIVE', 'Revisión inicial gestionada en base de datos', now(), now())
    """)
    op.execute("""
        UPDATE report_versions rv
        SET report_format_id = rf.id,
            format_code_snapshot = rf.format_code,
            format_revision_snapshot = rf.revision,
            format_template_snapshot = rf.template_name
        FROM maintenance_reports mr
        JOIN report_formats rf
          ON rf.report_kind = CASE
              WHEN mr.report_kind IN ('PREVENTIVE', 'PREVENTIVE_MAIN') THEN 'PREVENTIVE'
              WHEN mr.report_kind = 'CORRECTIVE' THEN 'CORRECTIVE'
          END
         AND rf.status = 'ACTIVE'
        WHERE rv.maintenance_report_id = mr.id
          AND mr.report_kind IN ('PREVENTIVE', 'PREVENTIVE_MAIN', 'CORRECTIVE')
    """)


def downgrade() -> None:
    op.drop_index("ix_asset_replacements_donor_parent_asset_id", table_name="asset_replacements")
    op.drop_constraint(
        "fk_asset_replacements_donor_parent_asset_id",
        "asset_replacements",
        type_="foreignkey",
    )
    op.drop_column("asset_replacements", "donor_parent_asset_id")
    op.drop_column("asset_replacements", "source_kind")
    op.drop_column("report_versions", "format_template_snapshot")
    op.drop_column("report_versions", "format_revision_snapshot")
    op.drop_column("report_versions", "format_code_snapshot")
    op.drop_index("ix_report_versions_report_format_id", table_name="report_versions")
    op.drop_constraint(
        "fk_report_versions_report_format_id",
        "report_versions",
        type_="foreignkey",
    )
    op.drop_column("report_versions", "report_format_id")
    op.drop_table("report_formats")
