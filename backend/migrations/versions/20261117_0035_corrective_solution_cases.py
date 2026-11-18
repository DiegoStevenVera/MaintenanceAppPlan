"""Rebuildable corrective knowledge projection, independent of report writes."""

from alembic import op

revision = "20261117_0035"
down_revision = "20261117_0034"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("""CREATE TABLE corrective_solution_cases (
        event_id varchar(80) PRIMARY KEY REFERENCES corrective_events(id) ON DELETE CASCADE,
        fingerprint varchar(64) NOT NULL,
        payload jsonb NOT NULL,
        refreshed_at timestamptz NOT NULL DEFAULT now()
    )""")


def downgrade() -> None:
    op.drop_table("corrective_solution_cases")
