from collections.abc import Callable

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session, uses_postgres
from modules.identity_access.application.permissions import (
    AppModule,
    PermissionLevel,
    default_permissions,
)
from modules.identity_access.application.security import InvalidTokenError, decode_token
from modules.identity_access.application.seed_users import SEED_USERS
from modules.identity_access.infrastructure.postgres.models import RoleModulePermissionRecord
from modules.identity_access.infrastructure.postgres.repository import PostgresUserRepository
from modules.identity_access.interfaces.schemas import UserDTO
from shared_kernel.schemas import UserRole

bearer_scheme = HTTPBearer(auto_error=False)


async def get_current_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    session: AsyncSession = Depends(get_session),
) -> UserDTO:
    if credentials is None or credentials.scheme.casefold() != "bearer":
        raise _credentials_error()

    try:
        claims = decode_token(credentials.credentials, expected_type="access")
    except InvalidTokenError as error:
        raise _credentials_error() from error

    if uses_postgres():
        user = await PostgresUserRepository(session).get_by_id(claims.subject)
    else:
        user = next((item for item in SEED_USERS if item.id == claims.subject), None)

    if user is None or user.role.value != claims.role:
        raise _credentials_error()
    module = _module_for_path(request.url.path)
    if module is not None:
        required = (
            PermissionLevel.READ
            if request.method in {"GET", "HEAD", "OPTIONS"}
            else PermissionLevel.WRITE
        )
        granted = await _permission_for(session, user.role, module)
        if _permission_rank(granted) < _permission_rank(required):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient module permissions",
            )
    return user


def require_roles(*allowed_roles: UserRole) -> Callable[..., UserDTO]:
    async def dependency(
        request: Request,
        user: UserDTO = Depends(get_current_user),
    ) -> UserDTO:
        if user.role not in allowed_roles:
            # Module permissions may grant access beyond the legacy fixed-role lists.
            # Administration and authentication have no module mapping and stay role-only.
            if _module_for_path(request.url.path) is None:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Insufficient permissions",
                )
        return user

    return dependency


async def _permission_for(
    session: AsyncSession,
    role: UserRole,
    module: AppModule,
) -> PermissionLevel:
    if role == UserRole.ADMINISTRATOR:
        return PermissionLevel.WRITE
    if uses_postgres():
        value = await session.scalar(
            select(RoleModulePermissionRecord.permission_level).where(
                RoleModulePermissionRecord.role == role.value,
                RoleModulePermissionRecord.module == module.value,
            )
        )
        if value:
            try:
                return PermissionLevel(value)
            except ValueError:
                pass
    return default_permissions(role)[module]


def _module_for_path(path: str) -> AppModule | None:
    mappings = (
        ("/ats-line", AppModule.ATS_LINE),
        ("/pcon", AppModule.PCON),
        ("/assets/stock", AppModule.STOCK),
        ("/assets", AppModule.EQUIPMENT),
        ("/schedules", AppModule.SCHEDULE),
        ("/tool-admin", AppModule.TOOLS),
        ("/preventive-templates", AppModule.PREVENTIVE),
        ("/corrective-events", AppModule.CORRECTIVE),
        ("/corrective-solutions", AppModule.CORRECTIVE),
    )
    for fragment, module in mappings:
        if fragment in path:
            return module
    return None


def _permission_rank(level: PermissionLevel) -> int:
    return {
        PermissionLevel.NONE: 0,
        PermissionLevel.READ: 1,
        PermissionLevel.WRITE: 2,
    }[level]


def _credentials_error() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired access token",
        headers={"WWW-Authenticate": "Bearer"},
    )
