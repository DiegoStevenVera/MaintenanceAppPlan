import pytest

from modules.maintenance_execution.application.lifecycle import (
    InvalidMaintenanceTransitionError,
    MaintenanceLifecycleCommand,
    MaintenanceLifecyclePermissionError,
    resolve_lifecycle_transition,
)
from shared_kernel.schemas import MaintenanceStatus, UserRole


@pytest.mark.parametrize(
    ("current_status", "command", "role", "expected"),
    [
        (
            MaintenanceStatus.SCHEDULED,
            MaintenanceLifecycleCommand.START,
            UserRole.MAINTENANCE_ENGINEER,
            MaintenanceStatus.IN_PROGRESS,
        ),
        (
            MaintenanceStatus.IN_PROGRESS,
            MaintenanceLifecycleCommand.COMPLETE,
            UserRole.MAINTENANCE_ENGINEER,
            MaintenanceStatus.COMPLETED,
        ),
        (
            MaintenanceStatus.COMPLETED,
            MaintenanceLifecycleCommand.CLOSE,
            UserRole.COORDINATOR,
            MaintenanceStatus.CLOSED,
        ),
        (
            MaintenanceStatus.COMPLETED,
            MaintenanceLifecycleCommand.REOPEN,
            UserRole.MAINTENANCE_ENGINEER,
            MaintenanceStatus.IN_PROGRESS,
        ),
        (
            MaintenanceStatus.CLOSED,
            MaintenanceLifecycleCommand.REOPEN,
            UserRole.ADMINISTRATOR,
            MaintenanceStatus.IN_PROGRESS,
        ),
    ],
)
def test_valid_lifecycle_transitions(
    current_status: MaintenanceStatus,
    command: MaintenanceLifecycleCommand,
    role: UserRole,
    expected: MaintenanceStatus,
) -> None:
    assert (
        resolve_lifecycle_transition(
            current_status=current_status,
            command=command,
            role=role,
        )
        == expected
    )


def test_boss_is_read_only_for_lifecycle_commands() -> None:
    with pytest.raises(MaintenanceLifecyclePermissionError):
        resolve_lifecycle_transition(
            current_status=MaintenanceStatus.SCHEDULED,
            command=MaintenanceLifecycleCommand.START,
            role=UserRole.BOSS,
        )


def test_engineer_cannot_close_or_reopen_closed_maintenance() -> None:
    with pytest.raises(MaintenanceLifecyclePermissionError):
        resolve_lifecycle_transition(
            current_status=MaintenanceStatus.COMPLETED,
            command=MaintenanceLifecycleCommand.CLOSE,
            role=UserRole.MAINTENANCE_ENGINEER,
        )

    with pytest.raises(MaintenanceLifecyclePermissionError):
        resolve_lifecycle_transition(
            current_status=MaintenanceStatus.CLOSED,
            command=MaintenanceLifecycleCommand.REOPEN,
            role=UserRole.MAINTENANCE_ENGINEER,
        )


def test_invalid_source_state_is_rejected() -> None:
    with pytest.raises(InvalidMaintenanceTransitionError):
        resolve_lifecycle_transition(
            current_status=MaintenanceStatus.COMPLETED,
            command=MaintenanceLifecycleCommand.START,
            role=UserRole.COORDINATOR,
        )
