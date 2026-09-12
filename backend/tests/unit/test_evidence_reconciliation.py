import asyncio
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock
from uuid import uuid4

from modules.maintenance_execution.infrastructure.postgres.report_models import AttachmentRecord
from modules.maintenance_execution.infrastructure.postgres.report_writer import PostgresReportWriter
from modules.maintenance_execution.interfaces.schemas import ReportEvidenceWriteDTO


def photo():
    version_id = uuid4()
    item = ReportEvidenceWriteDTO(
        client_id=str(uuid4()), attachment_id=str(uuid4()),
        original_file_name="evidencia-1.jpg", media_type="image/jpeg",
        captured_at=datetime(2026, 9, 10, 15, tzinfo=timezone.utc),
    )
    record = AttachmentRecord(
        id=uuid4(), report_version_id=version_id,
        original_file_name=item.original_file_name, media_type=item.media_type,
        captured_at=item.captured_at, attachment_type="IMAGE",
        file_reference="photo.jpg", checksum="checksum", file_size_bytes=3,
    )
    return item, record


def test_recovers_stale_attachment_reference_with_exact_photo_metadata():
    item, record = photo()
    assert PostgresReportWriter._resolve_existing_evidence(item, {str(record.id): record}) is record


def test_does_not_guess_ambiguous_or_missing_photo():
    item, record = photo()
    assert PostgresReportWriter._resolve_existing_evidence(item, {}) is None
    assert PostgresReportWriter._resolve_existing_evidence(item, {"a": record, "b": record}) is None
    item.captured_at = datetime(2026, 9, 11, tzinfo=timezone.utc)
    assert PostgresReportWriter._resolve_existing_evidence(item, {str(record.id): record}) is None


def test_repeated_draft_save_keeps_attachment_id_and_updates_snapshot_reference(tmp_path, monkeypatch):
    from modules.maintenance_execution.infrastructure.postgres import report_writer

    monkeypatch.setattr(report_writer, "settings", SimpleNamespace(resolved_attachment_root=tmp_path))
    item, record = photo()
    session = Mock()
    session.scalars = AsyncMock(return_value=SimpleNamespace(all=lambda: []))
    writer = PostgresReportWriter.__new__(PostgresReportWriter)
    writer._session = session
    version = SimpleNamespace(id=record.report_version_id)
    for _ in range(3):
        asyncio.run(writer._save_evidence(version, [item], "user", {str(record.id): record}))
        replacement = session.add.call_args.args[0]
        assert replacement.id == record.id
        assert item.attachment_id == str(record.id)
        assert replacement.file_reference == record.file_reference
        record = replacement


def test_new_version_does_not_reuse_source_attachment_primary_key(tmp_path, monkeypatch):
    from modules.maintenance_execution.infrastructure.postgres import report_writer

    monkeypatch.setattr(report_writer, "settings", SimpleNamespace(resolved_attachment_root=tmp_path))
    item, record = photo()
    session = Mock()
    session.scalars = AsyncMock(return_value=SimpleNamespace(all=lambda: []))
    writer = PostgresReportWriter.__new__(PostgresReportWriter)
    writer._session = session
    asyncio.run(writer._save_evidence(SimpleNamespace(id=uuid4()), [item], "user", {str(record.id): record}))
    assert session.add.call_args.args[0].id != record.id
