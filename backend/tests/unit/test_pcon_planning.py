from datetime import date, datetime, timedelta, timezone

import pytest

from modules.maintenance_execution.infrastructure.postgres.planning_repository import (
    PlanningValidationError,
    PostgresPlanningRepository,
)


def test_week_start_is_always_normalized_to_monday() -> None:
    assert PostgresPlanningRepository.normalize_week_start(date(2026, 7, 29)) == date(
        2026, 7, 27
    )


def test_proposal_must_be_completely_inside_selected_week() -> None:
    start = datetime(2026, 7, 29, 14, tzinfo=timezone.utc)
    PostgresPlanningRepository.validate_within_week(
        date(2026, 7, 27),
        start,
        start + timedelta(hours=2),
    )

    with pytest.raises(PlanningValidationError, match="dentro de la semana"):
        PostgresPlanningRepository.validate_within_week(
            date(2026, 7, 27),
            datetime(2026, 8, 3, 14, tzinfo=timezone.utc),
            datetime(2026, 8, 3, 16, tzinfo=timezone.utc),
        )


def test_proposal_rejects_an_invalid_time_range() -> None:
    start = datetime(2026, 7, 29, 14, tzinfo=timezone.utc)
    with pytest.raises(PlanningValidationError, match="hora fin"):
        PostgresPlanningRepository.validate_within_week(
            date(2026, 7, 27),
            start,
            start,
        )
