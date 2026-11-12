from enum import StrEnum

from shared_kernel.schemas import UserRole


class AppModule(StrEnum):
    HOME = "HOME"
    PREVENTIVE = "PREVENTIVE"
    CORRECTIVE = "CORRECTIVE"
    PCON = "PCON"
    EQUIPMENT = "EQUIPMENT"
    SCHEDULE = "SCHEDULE"
    STOCK = "STOCK"
    TOOLS = "TOOLS"
    PROFILE = "PROFILE"
    ATS_LINE = "ATS_LINE"


class PermissionLevel(StrEnum):
    NONE = "NONE"
    READ = "READ"
    WRITE = "WRITE"


MODULE_LABELS: dict[AppModule, str] = {
    AppModule.HOME: "Inicio",
    AppModule.PREVENTIVE: "Preventivos",
    AppModule.CORRECTIVE: "Correctivos",
    AppModule.PCON: "PCON",
    AppModule.EQUIPMENT: "Equipos",
    AppModule.SCHEDULE: "Horario",
    AppModule.STOCK: "Stock",
    AppModule.TOOLS: "Herramientas",
    AppModule.PROFILE: "Perfil",
    AppModule.ATS_LINE: "Linea ATS",
}


def default_permissions(role: UserRole) -> dict[AppModule, PermissionLevel]:
    if role == UserRole.ADMINISTRATOR:
        return {module: PermissionLevel.WRITE for module in AppModule}

    visible = {
        AppModule.HOME,
        AppModule.PREVENTIVE,
        AppModule.CORRECTIVE,
        AppModule.EQUIPMENT,
        AppModule.SCHEDULE,
        AppModule.PROFILE,
        AppModule.ATS_LINE,
    }
    permissions = {module: PermissionLevel.NONE for module in AppModule}
    for module in visible:
        permissions[module] = PermissionLevel.READ

    if role == UserRole.MAINTENANCE_ENGINEER:
        permissions[AppModule.PREVENTIVE] = PermissionLevel.WRITE
        permissions[AppModule.CORRECTIVE] = PermissionLevel.WRITE
    elif role == UserRole.COORDINATOR:
        permissions[AppModule.PREVENTIVE] = PermissionLevel.WRITE
        permissions[AppModule.CORRECTIVE] = PermissionLevel.WRITE
        permissions[AppModule.SCHEDULE] = PermissionLevel.WRITE
    return permissions
