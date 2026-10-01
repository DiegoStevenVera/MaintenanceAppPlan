from datetime import date, timedelta
from uuid import uuid4

from app.database import Base
from modules.identity_access.infrastructure.postgres.models import UserRecord
from modules.workforce_scheduling.interfaces.router import (
    _can_edit_area,
    _require_edit_access,
    _target_dates,
)
from shared_kernel.schemas import UserRole


def user(role: UserRole, work_area_id=None) -> UserRecord:
    return UserRecord(
        id=f"user-{role.value.lower()}",
        name=role.value,
        email=f"{role.value.lower()}@example.com",
        role=role.value,
        role_label=role.value,
        password_hash="unused",
        work_area_id=work_area_id,
    )


def test_schedule_tables_are_registered() -> None:
    assert {
        "schedule_shift_types",
        "work_area_schedule_viewers",
        "employee_schedule_entries",
        "employee_schedule_audit_events",
    } <= set(Base.metadata.tables)


def test_coordinator_edits_only_own_area() -> None:
    own_area = uuid4()
    coordinator = user(UserRole.COORDINATOR, own_area)

    assert _can_edit_area(coordinator, own_area)
    assert not _can_edit_area(coordinator, uuid4())


def test_administrator_can_edit_any_area() -> None:
    administrator = user(UserRole.ADMINISTRATOR, uuid4())

    assert _can_edit_area(administrator, uuid4())


def test_coordinator_can_edit_past_schedule_in_own_area() -> None:
    area_id = uuid4()
    coordinator = user(UserRole.COORDINATOR, area_id)

    _require_edit_access(
        coordinator,
        area_id,
        date.today() - timedelta(days=1),
        reason=None,
    )


def test_administrator_can_edit_past_schedule_without_confirmation() -> None:
    area_id = uuid4()
    administrator = user(UserRole.ADMINISTRATOR, area_id)
    past_date = date.today() - timedelta(days=30)

    _require_edit_access(administrator, area_id, past_date)


def test_boss_never_edits_schedule() -> None:
    area_id = uuid4()
    boss = user(UserRole.BOSS, area_id)

    assert not _can_edit_area(boss, area_id)


def test_coordinator_shift_applies_monday_to_friday() -> None:
    wednesday = date(2026, 9, 23)

    assert _target_dates(wednesday, "COO", "DAY") == [
        date(2026, 9, 21),
        date(2026, 9, 22),
        date(2026, 9, 23),
        date(2026, 9, 24),
        date(2026, 9, 25),
    ]


def test_cbtc_shift_still_applies_to_the_full_week() -> None:
    wednesday = date(2026, 9, 23)

    assert _target_dates(wednesday, "CBTC", "DAY") == [
        date(2026, 9, 21) + timedelta(days=offset) for offset in range(7)
    ]
