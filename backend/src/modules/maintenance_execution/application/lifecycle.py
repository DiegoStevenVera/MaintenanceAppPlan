from enum import StrEnum

from shared_kernel.schemas import MaintenanceStatus, UserRole


class MaintenanceLifecycleCommand(StrEnum):
    START = "start"
    COMPLETE = "complete"
    CLOSE = "close"
    REOPEN = "reopen"


class MaintenanceLifecycleError(Exception):
    pass


class MaintenanceLifecyclePermissionError(MaintenanceLifecycleError):
    pass


class InvalidMaintenanceTransitionError(MaintenanceLifecycleError):
    pass


def resolve_lifecycle_transition(
    *,
    current_status: MaintenanceStatus,
    command: MaintenanceLifecycleCommand,
    role: UserRole,
) -> MaintenanceStatus:
    if role == UserRole.BOSS:
        raise MaintenanceLifecyclePermissionError(
            "El rol Jefe tiene acceso de solo lectura."
        )

    if command == MaintenanceLifecycleCommand.START:
        if current_status != MaintenanceStatus.SCHEDULED:
            raise InvalidMaintenanceTransitionError(
                "Solo se puede iniciar un mantenimiento programado."
            )
        return MaintenanceStatus.IN_PROGRESS

    if command == MaintenanceLifecycleCommand.COMPLETE:
        if current_status != MaintenanceStatus.IN_PROGRESS:
            raise InvalidMaintenanceTransitionError(
                "Solo se puede completar un mantenimiento en progreso."
            )
        return MaintenanceStatus.COMPLETED

    if command == MaintenanceLifecycleCommand.CLOSE:
        if role not in (UserRole.COORDINATOR, UserRole.ADMINISTRATOR):
            raise MaintenanceLifecyclePermissionError(
                "Solo un Coordinador o Administrador puede cerrar el mantenimiento."
            )
        if current_status != MaintenanceStatus.COMPLETED:
            raise InvalidMaintenanceTransitionError(
                "Solo se puede cerrar un mantenimiento completado."
            )
        return MaintenanceStatus.CLOSED

    if current_status == MaintenanceStatus.COMPLETED:
        return MaintenanceStatus.IN_PROGRESS
    if current_status == MaintenanceStatus.CLOSED:
        if role not in (UserRole.COORDINATOR, UserRole.ADMINISTRATOR):
            raise MaintenanceLifecyclePermissionError(
                "Solo un Coordinador o Administrador puede reabrir un mantenimiento cerrado."
            )
        return MaintenanceStatus.IN_PROGRESS
    raise InvalidMaintenanceTransitionError(
        "Solo se puede reabrir un mantenimiento completado o cerrado."
    )
