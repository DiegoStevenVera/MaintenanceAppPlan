"""Portable, filesystem-backed storage references.

Database rows store keys relative to a configured storage root. The resolver
keeps a small compatibility window for records created before this contract,
when absolute or project-relative paths were persisted.
"""

from pathlib import Path
from urllib.parse import urlparse


def storage_key(path: Path, root: Path) -> str:
    """Return a portable POSIX key relative to ``root``."""

    resolved_root = root.resolve()
    resolved_path = path.resolve()
    try:
        return resolved_path.relative_to(resolved_root).as_posix()
    except ValueError as error:
        raise ValueError(f"Storage path is outside its configured root: {path}") from error


def resolve_storage_reference(
    reference: str | None,
    root: Path,
    *,
    legacy_roots: tuple[Path, ...] = (),
) -> Path | None:
    """Resolve a local storage key without allowing path traversal."""

    if not reference:
        return None

    value = reference.strip()
    parsed = urlparse(value)
    if parsed.scheme or value.startswith("//"):
        return None

    resolved_root = root.resolve()
    candidates: list[Path] = []
    reference_path = Path(value)
    if reference_path.is_absolute():
        candidates.append(reference_path)
    else:
        candidates.append(root / reference_path)
        candidates.extend(legacy_root / reference_path for legacy_root in legacy_roots)

    for candidate in candidates:
        resolved_candidate = candidate.resolve()
        if resolved_root not in resolved_candidate.parents:
            continue
        if resolved_candidate.is_file():
            return resolved_candidate
    return None


def portable_storage_reference(
    reference: str | None,
    root: Path,
    *,
    legacy_roots: tuple[Path, ...] = (),
) -> str | None:
    """Convert a resolvable legacy reference into the current storage key."""

    resolved = resolve_storage_reference(reference, root, legacy_roots=legacy_roots)
    if resolved is None:
        return reference
    return storage_key(resolved, root)
