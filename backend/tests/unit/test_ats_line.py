from pathlib import Path

import pytest

from modules.ats_line.infrastructure.repository import ATSLineRepository


DATA_PATH = Path(__file__).resolve().parents[2] / "data" / "ats_line" / "dc_sys_source.sqlite3"


@pytest.fixture(scope="module")
def repository() -> ATSLineRepository:
    return ATSLineRepository(DATA_PATH)


def test_line_snapshot_contains_operational_layers(repository: ATSLineRepository) -> None:
    line = repository.line_payload()

    assert len(line["segments"]) == 65
    assert len(line["tags"]) == 164
    assert len(line["signals"]) == 66
    assert len(line["stopping_points"]) == 35
    assert len(line["calibration_links"]) == 12
    assert line["mode"] == "portable"


def test_line_object_includes_original_source_fields(repository: ATSLineRepository) -> None:
    detail = repository.object_detail("S_022401")

    assert detail["items"][0]["source_sheet"] == "Seg"
    assert detail["items"][0]["source_fields"]


def test_distance_reproduces_known_baseline(repository: ATSLineRepository) -> None:
    result = repository.distance_between("S_022401", 50, "S_028024", 20)

    assert result["possible"] is True
    assert result["distance"] == pytest.approx(429.97, abs=0.01)
    assert result["traversed"]
