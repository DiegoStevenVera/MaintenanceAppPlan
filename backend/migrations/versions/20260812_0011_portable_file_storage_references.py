"""normalize generated file references for container-friendly storage

Revision ID: 20260812_0011
Revises: 20260730_0010
Create Date: 2026-08-12
"""

from collections.abc import Sequence

from alembic import op


revision: str = "20260812_0011"
down_revision: str | None = "20260730_0010"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Keep imported external URLs untouched. Only local project/storage paths
    # are converted to keys relative to their configured storage root.
    op.execute(
        """
        UPDATE attachments
        SET file_reference = regexp_replace(
            file_reference,
            '^(.*/)?backend/storage/attachments/',
            ''
        )
        WHERE file_reference ~ '^(.*/)?backend/storage/attachments/'
          AND file_reference !~ '^[[:alpha:]][[:alnum:]+.-]*://'
        """
    )
    op.execute(
        """
        UPDATE generated_reports
        SET
            file_reference = regexp_replace(
                file_reference,
                '^(.*/)?backend/storage/reports/',
                ''
            ),
            path = CASE
                WHEN path IS NULL THEN NULL
                ELSE regexp_replace(
                    path,
                    '^(.*/)?backend/storage/reports/',
                    ''
                )
            END
        WHERE file_reference ~ '^(.*/)?backend/storage/reports/'
           OR path ~ '^(.*/)?backend/storage/reports/'
        """
    )


def downgrade() -> None:
    # The old absolute/project-relative representation is not portable and
    # cannot be reconstructed safely for every deployment.
    pass
