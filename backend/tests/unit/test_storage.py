from pathlib import Path

from shared_kernel.storage import (
    portable_storage_reference,
    resolve_storage_reference,
    storage_key,
)


def test_storage_keys_are_relative_to_the_configured_root(tmp_path: Path) -> None:
    root = tmp_path / "storage"
    root.mkdir()
    artifact = root / "reports" / "report.pdf"
    artifact.parent.mkdir()
    artifact.write_bytes(b"pdf")

    assert storage_key(artifact, root) == "reports/report.pdf"
    assert resolve_storage_reference("reports/report.pdf", root) == artifact


def test_legacy_project_reference_can_be_read_and_normalized(tmp_path: Path) -> None:
    project_root = tmp_path / "project"
    storage_root = project_root / "backend" / "storage" / "attachments"
    storage_root.mkdir(parents=True)
    artifact = storage_root / "evidence.jpg"
    artifact.write_bytes(b"image")

    legacy_reference = "backend/storage/attachments/evidence.jpg"
    assert resolve_storage_reference(
        legacy_reference,
        storage_root,
        legacy_roots=(project_root,),
    ) == artifact
    assert portable_storage_reference(
        legacy_reference,
        storage_root,
        legacy_roots=(project_root,),
    ) == "evidence.jpg"


def test_external_reference_is_not_treated_as_local_file(tmp_path: Path) -> None:
    root = tmp_path / "storage"
    root.mkdir()

    assert resolve_storage_reference("https://example.com/image.jpg", root) is None
    assert portable_storage_reference("https://example.com/image.jpg", root) == (
        "https://example.com/image.jpg"
    )
