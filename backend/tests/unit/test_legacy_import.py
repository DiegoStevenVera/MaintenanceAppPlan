from datetime import date

import pytest
from openpyxl import Workbook

from legacy_import.errors import WorkbookValidationError
from legacy_import.ids import stable_uuid
from legacy_import.values import duration_hours, parse_date
from legacy_import.workbook import LegacyWorkbook


def _save_workbook(tmp_path, rows):
    path = tmp_path / "legacy.xlsx"
    workbook = Workbook()
    worksheet = workbook.active
    worksheet.title = "Source"
    worksheet.append(["ID", "Name"])
    for row in rows:
        worksheet.append(row)
    workbook.save(path)
    return path


def test_legacy_value_parsers_support_power_apps_formats() -> None:
    assert duration_hours("02:30") == 2.5
    assert parse_date("Wed Aug 27 2025 19:00:00 GMT-0500 (Peru Standard Time)") == date(
        2025,
        8,
        27,
    )
    assert parse_date("06/16") == date(2016, 6, 1)


def test_stable_uuid_is_repeatable_and_context_sensitive() -> None:
    first = stable_uuid("WBS_V2", "tbl_Component", 1, "assets")
    assert first == stable_uuid("WBS_V2", "tbl_Component", 1, "assets")
    assert first != stable_uuid("WBS_V2", "tbl_Equipment", 1, "assets")


def test_workbook_skips_identical_duplicate_source_rows(tmp_path) -> None:
    path = _save_workbook(tmp_path, [(1, "Equipo"), (1, "Equipo")])

    workbook = LegacyWorkbook(path)
    rows = workbook.rows("Source", key_column="ID")

    assert [row.key for row in rows] == ["1"]
    assert workbook.duplicate_counts["Source"] == 1


def test_workbook_rejects_conflicting_duplicate_source_rows(tmp_path) -> None:
    path = _save_workbook(tmp_path, [(1, "Equipo A"), (1, "Equipo B")])

    workbook = LegacyWorkbook(path)

    with pytest.raises(WorkbookValidationError, match="conflicting rows"):
        workbook.rows("Source", key_column="ID")
