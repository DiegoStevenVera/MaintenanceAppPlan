class LegacyImportError(Exception):
    """Base exception for an expected legacy import failure."""


class WorkbookValidationError(LegacyImportError):
    """Raised when a workbook does not match the expected source contract."""


class RowImportError(LegacyImportError):
    """Raised when one source row cannot be mapped safely."""

