from modules.identity_access.interfaces.schemas import UserDTO
from shared_kernel.schemas import UserRole

SEED_USERS = [
    UserDTO(
        id="user-diego",
        name="Diego Vera",
        email="diego@maintenance.local",
        role=UserRole.MAINTENANCE_ENGINEER,
        role_label="Ingeniero de Mantenimiento",
    ),
    UserDTO(
        id="user-joab",
        name="Joab Apaza",
        email="joab@maintenance.local",
        role=UserRole.MAINTENANCE_ENGINEER,
        role_label="Ingeniero de Mantenimiento",
    ),
    UserDTO(
        id="user-fredy",
        name="Fredy Navarrete",
        email="fredy@maintenance.local",
        role=UserRole.COORDINATOR,
        role_label="Coordinador",
    ),
    UserDTO(
        id="user-jefe",
        name="Jefe de mantenimiento",
        email="jefe@maintenance.local",
        role=UserRole.BOSS,
        role_label="Jefe",
    ),
    UserDTO(
        id="user-admin",
        name="Administrador",
        email="admin@maintenance.local",
        role=UserRole.ADMINISTRATOR,
        role_label="Administrador",
    ),
]
