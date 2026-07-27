from datetime import datetime
from uuid import UUID

from sqlalchemy import (
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base
from shared_kernel.persistence import OperationalRecordMixin


class DataImportBatchRecord(OperationalRecordMixin, Base):
    __tablename__ = "data_import_batches"

    project_id: Mapped[UUID | None] = mapped_column(Uuid, ForeignKey("projects.id"), index=True)
    stage_id: Mapped[UUID | None] = mapped_column(Uuid, ForeignKey("stages.id"), index=True)
    source_system: Mapped[str] = mapped_column(String(100), nullable=False)
    source_file_name: Mapped[str] = mapped_column(String(240), nullable=False)
    source_file_checksum: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    import_mode: Mapped[str] = mapped_column(String(30), nullable=False)
    status: Mapped[str] = mapped_column(String(30), nullable=False, index=True)
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    imported_by_user_id: Mapped[str | None] = mapped_column(String(80), ForeignKey("users.id"))
    total_rows: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    inserted_rows: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    updated_rows: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    unchanged_rows: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    failed_rows: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    summary: Mapped[dict | None] = mapped_column(JSONB)


class LegacyRecordMappingRecord(OperationalRecordMixin, Base):
    __tablename__ = "legacy_record_mappings"
    __table_args__ = (
        UniqueConstraint(
            "source_system",
            "source_table",
            "source_primary_key",
            "target_table",
            "mapping_role",
            name="uq_legacy_record_mappings_source_target_role",
        ),
        Index(
            "ix_legacy_record_mappings_source_key",
            "source_system",
            "source_table",
            "source_primary_key",
        ),
    )

    source_system: Mapped[str] = mapped_column(String(100), nullable=False)
    source_table: Mapped[str] = mapped_column(String(160), nullable=False)
    source_primary_key: Mapped[str] = mapped_column(String(240), nullable=False)
    source_row_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    target_table: Mapped[str] = mapped_column(String(160), nullable=False)
    target_record_id: Mapped[str] = mapped_column(String(80), nullable=False)
    mapping_role: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        default="PRIMARY",
        server_default="PRIMARY",
    )
    first_import_batch_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("data_import_batches.id"),
        nullable=False,
    )
    last_import_batch_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("data_import_batches.id"),
        nullable=False,
    )
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class DataImportRowResultRecord(OperationalRecordMixin, Base):
    __tablename__ = "data_import_row_results"
    __table_args__ = (
        UniqueConstraint(
            "import_batch_id",
            "source_table",
            "source_primary_key",
            name="uq_data_import_row_results_batch_source",
        ),
    )

    import_batch_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("data_import_batches.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    source_table: Mapped[str] = mapped_column(String(160), nullable=False)
    source_primary_key: Mapped[str] = mapped_column(String(240), nullable=False)
    source_row_hash: Mapped[str | None] = mapped_column(String(64))
    operation: Mapped[str] = mapped_column(String(30), nullable=False)
    status: Mapped[str] = mapped_column(String(30), nullable=False)
    target_table: Mapped[str | None] = mapped_column(String(160))
    target_record_id: Mapped[str | None] = mapped_column(String(80))
    error_code: Mapped[str | None] = mapped_column(String(100))
    error_message: Mapped[str | None] = mapped_column(Text)
    source_payload: Mapped[dict | None] = mapped_column(JSONB)
