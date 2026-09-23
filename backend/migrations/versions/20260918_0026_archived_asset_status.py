"""Add the archived equipment status to the controlled catalog.

Revision ID: 20260918_0026
Revises: 20260918_0025
"""

from alembic import op


revision = "20260918_0026"
down_revision = "20260918_0025"
branch_labels = None
depends_on = None

STATUS_ID = "7e4d8218-78d8-5f78-b864-958d90974835"


def upgrade() -> None:
    op.execute(
        f"""
        INSERT INTO asset_statuses (id, code, name, description, is_active)
        VALUES ('{STATUS_ID}', 'DADO_DE_BAJA', 'DADO DE BAJA',
                'Equipo retirado del servicio sin eliminar su historial.', true)
        ON CONFLICT (code) DO UPDATE
        SET name = EXCLUDED.name, description = EXCLUDED.description, is_active = true
        """
    )
    op.execute(
        f"""
        UPDATE assets
        SET status_id = '{STATUS_ID}'
        WHERE status = 'DADO DE BAJA'
        """
    )


def downgrade() -> None:
    op.execute(
        f"UPDATE assets SET status_id = NULL WHERE status_id = '{STATUS_ID}'"
    )
    op.execute(f"DELETE FROM asset_statuses WHERE id = '{STATUS_ID}'")
