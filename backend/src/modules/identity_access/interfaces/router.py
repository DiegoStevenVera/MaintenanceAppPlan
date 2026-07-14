from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session, uses_postgres
from modules.identity_access.infrastructure.postgres.repository import PostgresUserRepository
from modules.identity_access.interfaces.schemas import LoginRequest, TokenPairDTO, UserDTO
from shared_kernel.schemas import UserRole

router = APIRouter(prefix="/auth", tags=["auth"])

SEED_USERS = [
    UserDTO(
        id="user-diego",
        name="Diego Vera",
        email="diego@maintenance.local",
        role=UserRole.TECHNICIAN,
        role_label="Ingeniero de Mantenimiento",
    ),
    UserDTO(
        id="user-joab",
        name="Joab Apaza",
        email="joab@maintenance.local",
        role=UserRole.TECHNICIAN,
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


@router.post("/login", response_model=TokenPairDTO)
async def login(
    payload: LoginRequest,
    session: AsyncSession = Depends(get_session),
) -> TokenPairDTO:
    if uses_postgres():
        repository = PostgresUserRepository(session)
        user = await repository.get_by_email(payload.email)
        if user is None or not await repository.verify_password(payload.email, payload.password):
            raise HTTPException(status_code=401, detail="Invalid email or password")
        return TokenPairDTO(
            access_token=f"mock-access-token-{user.id}",
            refresh_token=f"mock-refresh-token-{user.id}",
            user=user,
        )

    user = next(
        (item for item in SEED_USERS if item.email.lower() == payload.email.strip().lower()),
        None,
    )
    if user is None or payload.password != "123456":
        raise HTTPException(status_code=401, detail="Invalid email or password")

    return TokenPairDTO(
        access_token=f"mock-access-token-{user.id}",
        refresh_token=f"mock-refresh-token-{user.id}",
        user=user,
    )


@router.get("/me", response_model=UserDTO)
async def get_current_user(session: AsyncSession = Depends(get_session)) -> UserDTO:
    if uses_postgres():
        user = await PostgresUserRepository(session).get_first_user()
        if user is None:
            raise HTTPException(status_code=404, detail="User not found")
        return user
    return SEED_USERS[0]
