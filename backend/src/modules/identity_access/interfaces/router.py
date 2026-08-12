from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_session, uses_postgres
from modules.identity_access.application.security import (
    InvalidTokenError,
    create_access_token,
    create_refresh_token,
    decode_token,
    new_session_id,
    token_digest,
)
from modules.identity_access.application.seed_users import SEED_USERS
from modules.identity_access.infrastructure.postgres.repository import PostgresUserRepository
from modules.identity_access.interfaces.dependencies import get_current_user, require_roles
from modules.identity_access.interfaces.schemas import (
    ChangePasswordRequest,
    ImpersonateRoleRequest,
    LoginRequest,
    LogoutRequest,
    RefreshTokenRequest,
    RolePreviewOptionDTO,
    TokenPairDTO,
    UserDTO,
)
from shared_kernel.schemas import UserRole

router = APIRouter(prefix="/auth", tags=["auth"])

# Seed mode exists only for isolated tests. PostgreSQL persists the equivalent sessions.
_seed_refresh_sessions: dict[str, tuple[str, str, datetime]] = {}


@router.post("/login", response_model=TokenPairDTO)
async def login(
    payload: LoginRequest,
    session: AsyncSession = Depends(get_session),
) -> TokenPairDTO:
    if uses_postgres():
        repository = PostgresUserRepository(session)
        user = await repository.authenticate(payload.email, payload.password)
        if user is None:
            raise _invalid_credentials()
        tokens = await _issue_token_pair(user, repository=repository)
        await session.commit()
        return tokens

    user = next(
        (item for item in SEED_USERS if item.email.casefold() == payload.email.strip().casefold()),
        None,
    )
    if user is None or payload.password != "123456":
        raise _invalid_credentials()
    return await _issue_token_pair(user)


@router.post("/refresh", response_model=TokenPairDTO)
async def refresh_tokens(
    payload: RefreshTokenRequest,
    session: AsyncSession = Depends(get_session),
) -> TokenPairDTO:
    try:
        claims = decode_token(payload.refresh_token, expected_type="refresh")
    except InvalidTokenError as error:
        raise _invalid_refresh_token() from error
    if claims.session_id is None:
        raise _invalid_refresh_token()

    if uses_postgres():
        repository = PostgresUserRepository(session)
        refresh_session = await repository.get_active_refresh_session(
            session_id=claims.session_id,
            token_hash=token_digest(payload.refresh_token),
        )
        user = await repository.get_by_id(claims.subject)
        if (
            refresh_session is None
            or refresh_session.user_id != claims.subject
            or user is None
            or user.role.value != claims.role
        ):
            raise _invalid_refresh_token()
        tokens = await _issue_token_pair(
            user,
            repository=repository,
            session_id=claims.session_id,
            existing_session=refresh_session,
        )
        await session.commit()
        return tokens

    stored = _seed_refresh_sessions.get(claims.session_id)
    user = next((item for item in SEED_USERS if item.id == claims.subject), None)
    if (
        stored is None
        or stored[0] != claims.subject
        or stored[1] != token_digest(payload.refresh_token)
        or stored[2] <= datetime.now(UTC)
        or user is None
    ):
        raise _invalid_refresh_token()
    return await _issue_token_pair(user, session_id=claims.session_id)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(
    payload: LogoutRequest,
    session: AsyncSession = Depends(get_session),
) -> Response:
    try:
        claims = decode_token(payload.refresh_token, expected_type="refresh")
    except InvalidTokenError:
        return Response(status_code=status.HTTP_204_NO_CONTENT)

    if claims.session_id is not None:
        if uses_postgres():
            await PostgresUserRepository(session).revoke_refresh_session(claims.session_id)
            await session.commit()
        else:
            _seed_refresh_sessions.pop(claims.session_id, None)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/me", response_model=UserDTO)
async def get_me(current_user: UserDTO = Depends(get_current_user)) -> UserDTO:
    return current_user


@router.get("/impersonation-roles", response_model=list[RolePreviewOptionDTO])
async def list_impersonation_roles(
    _: UserDTO = Depends(require_roles(UserRole.ADMINISTRATOR)),
    session: AsyncSession = Depends(get_session),
) -> list[RolePreviewOptionDTO]:
    _require_non_production_role_preview()
    roles = (
        UserRole.MAINTENANCE_ENGINEER,
        UserRole.COORDINATOR,
        UserRole.BOSS,
    )
    if uses_postgres():
        repository = PostgresUserRepository(session)
        users = [await repository.get_first_active_by_role(role) for role in roles]
    else:
        users = [
            next((item for item in SEED_USERS if item.role == role), None)
            for role in roles
        ]
    return [
        RolePreviewOptionDTO(
            role=user.role,
            role_label=user.role_label,
            user_name=user.name,
        )
        for user in users
        if user is not None
    ]


@router.post("/impersonate-role", response_model=TokenPairDTO)
async def impersonate_role(
    payload: ImpersonateRoleRequest,
    _: UserDTO = Depends(require_roles(UserRole.ADMINISTRATOR)),
    session: AsyncSession = Depends(get_session),
) -> TokenPairDTO:
    _require_non_production_role_preview()

    if uses_postgres():
        repository = PostgresUserRepository(session)
        user = await repository.get_first_active_by_role(payload.role)
        if user is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No active user exists for the selected role",
            )
        tokens = await _issue_token_pair(user, repository=repository)
        await session.commit()
        return tokens

    user = next((item for item in SEED_USERS if item.role == payload.role), None)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No active user exists for the selected role",
        )
    return await _issue_token_pair(user)


def _require_non_production_role_preview() -> None:
    if settings.environment.casefold() in {"production", "prod"}:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Role preview is disabled in production",
        )


@router.post("/change-password", status_code=status.HTTP_204_NO_CONTENT)
async def change_password(
    payload: ChangePasswordRequest,
    current_user: UserDTO = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> Response:
    if len(payload.new_password) < 8:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="New password must contain at least 8 characters",
        )
    if not uses_postgres():
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail="Password changes require PostgreSQL",
        )

    repository = PostgresUserRepository(session)
    if not await repository.verify_current_password(current_user.id, payload.current_password):
        raise _invalid_credentials()
    await repository.change_password(current_user.id, payload.new_password)
    await repository.revoke_all_refresh_sessions(current_user.id)
    await session.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


async def _issue_token_pair(
    user: UserDTO,
    *,
    repository: PostgresUserRepository | None = None,
    session_id: str | None = None,
    existing_session=None,
) -> TokenPairDTO:
    current_session_id = session_id or new_session_id()
    access_token, _ = create_access_token(user)
    refresh_token, refresh_expires_at = create_refresh_token(user, current_session_id)
    refresh_hash = token_digest(refresh_token)

    if repository is not None:
        if existing_session is None:
            await repository.create_refresh_session(
                session_id=current_session_id,
                user_id=user.id,
                token_hash=refresh_hash,
                expires_at=refresh_expires_at,
            )
        else:
            await repository.rotate_refresh_session(
                existing_session,
                token_hash=refresh_hash,
                expires_at=refresh_expires_at,
            )
    else:
        _seed_refresh_sessions[current_session_id] = (
            user.id,
            refresh_hash,
            refresh_expires_at,
        )

    return TokenPairDTO(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.access_token_expire_minutes * 60,
        user=user,
    )


def _invalid_credentials() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid email or password",
        headers={"WWW-Authenticate": "Bearer"},
    )


def _invalid_refresh_token() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired refresh token",
        headers={"WWW-Authenticate": "Bearer"},
    )
