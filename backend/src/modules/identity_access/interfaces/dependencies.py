from collections.abc import Callable

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session, uses_postgres
from modules.identity_access.application.security import InvalidTokenError, decode_token
from modules.identity_access.application.seed_users import SEED_USERS
from modules.identity_access.infrastructure.postgres.repository import PostgresUserRepository
from modules.identity_access.interfaces.schemas import UserDTO
from shared_kernel.schemas import UserRole

bearer_scheme = HTTPBearer(auto_error=False)


async def get_current_user(
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
    return user


def require_roles(*allowed_roles: UserRole) -> Callable[..., UserDTO]:
    async def dependency(user: UserDTO = Depends(get_current_user)) -> UserDTO:
        if user.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions",
            )
        return user

    return dependency


def _credentials_error() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired access token",
        headers={"WWW-Authenticate": "Bearer"},
    )
