from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from modules.identity_access.infrastructure.postgres.models import UserRecord
from modules.identity_access.interfaces.schemas import UserDTO
from shared_kernel.schemas import UserRole


class PostgresUserRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_email(self, email: str) -> UserDTO | None:
        stmt = select(UserRecord).where(func.lower(UserRecord.email) == email.strip().casefold())
        record = await self._session.scalar(stmt)
        if record is None:
            return None
        return self._to_user_dto(record)

    async def get_first_user(self) -> UserDTO | None:
        record = await self._session.scalar(select(UserRecord).order_by(UserRecord.email).limit(1))
        if record is None:
            return None
        return self._to_user_dto(record)

    async def verify_password(self, email: str, password: str) -> bool:
        stmt = select(UserRecord.password_hash).where(
            func.lower(UserRecord.email) == email.strip().casefold()
        )
        password_hash = await self._session.scalar(stmt)
        return password_hash == f"mock:{password}"

    @staticmethod
    def _to_user_dto(record: UserRecord) -> UserDTO:
        return UserDTO(
            id=record.id,
            name=record.name,
            email=record.email,
            role=UserRole(record.role),
            role_label=record.role_label,
        )
