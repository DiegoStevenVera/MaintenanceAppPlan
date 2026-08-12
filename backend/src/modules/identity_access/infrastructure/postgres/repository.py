from datetime import UTC, datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from modules.identity_access.application.security import hash_password, verify_password
from modules.identity_access.infrastructure.postgres.models import RefreshSessionRecord, UserRecord
from modules.identity_access.interfaces.schemas import UserDTO
from shared_kernel.schemas import UserRole


class PostgresUserRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_email(self, email: str) -> UserDTO | None:
        record = await self.get_record_by_email(email)
        if record is None:
            return None
        return self._to_user_dto(record)

    async def get_by_id(self, user_id: str) -> UserDTO | None:
        record = await self._session.scalar(
            select(UserRecord).where(
                UserRecord.id == user_id,
                UserRecord.is_active.is_(True),
            )
        )
        if record is None:
            return None
        return self._to_user_dto(record)

    async def get_first_active_by_role(self, role: UserRole) -> UserDTO | None:
        record = await self._session.scalar(
            select(UserRecord)
            .where(
                UserRecord.role == role.value,
                UserRecord.is_active.is_(True),
            )
            .order_by(UserRecord.name, UserRecord.id)
            .limit(1)
        )
        return self._to_user_dto(record) if record is not None else None

    async def authenticate(self, email: str, password: str) -> UserDTO | None:
        record = await self.get_record_by_email(email)
        if record is None or not record.is_active:
            return None

        valid, replacement_hash = verify_password(record.password_hash, password)
        if not valid:
            return None
        if replacement_hash is not None:
            record.password_hash = replacement_hash
        return self._to_user_dto(record)

    async def verify_current_password(self, user_id: str, password: str) -> bool:
        record = await self._session.get(UserRecord, user_id)
        if record is None or not record.is_active:
            return False
        valid, replacement_hash = verify_password(record.password_hash, password)
        if replacement_hash is not None:
            record.password_hash = replacement_hash
        return valid

    async def change_password(self, user_id: str, password: str) -> None:
        record = await self._session.get(UserRecord, user_id)
        if record is None:
            raise LookupError(user_id)
        record.password_hash = hash_password(password)

    async def get_record_by_email(self, email: str) -> UserRecord | None:
        stmt = select(UserRecord).where(
            func.lower(UserRecord.email) == email.strip().casefold()
        )
        return await self._session.scalar(stmt)

    async def create_refresh_session(
        self,
        *,
        session_id: str,
        user_id: str,
        token_hash: str,
        expires_at: datetime,
    ) -> None:
        self._session.add(
            RefreshSessionRecord(
                id=session_id,
                user_id=user_id,
                token_hash=token_hash,
                expires_at=expires_at,
            )
        )

    async def get_active_refresh_session(
        self,
        *,
        session_id: str,
        token_hash: str,
    ) -> RefreshSessionRecord | None:
        stmt = select(RefreshSessionRecord).where(
            RefreshSessionRecord.id == session_id,
            RefreshSessionRecord.token_hash == token_hash,
            RefreshSessionRecord.revoked_at.is_(None),
            RefreshSessionRecord.expires_at > datetime.now(UTC),
        ).with_for_update()
        return await self._session.scalar(stmt)

    async def rotate_refresh_session(
        self,
        record: RefreshSessionRecord,
        *,
        token_hash: str,
        expires_at: datetime,
    ) -> None:
        record.token_hash = token_hash
        record.expires_at = expires_at
        record.last_used_at = datetime.now(UTC)

    async def revoke_refresh_session(self, session_id: str) -> None:
        record = await self._session.get(RefreshSessionRecord, session_id)
        if record is not None and record.revoked_at is None:
            record.revoked_at = datetime.now(UTC)

    async def revoke_all_refresh_sessions(self, user_id: str) -> None:
        records = (
            await self._session.scalars(
                select(RefreshSessionRecord).where(
                    RefreshSessionRecord.user_id == user_id,
                    RefreshSessionRecord.revoked_at.is_(None),
                )
            )
        ).all()
        now = datetime.now(UTC)
        for record in records:
            record.revoked_at = now

    @staticmethod
    def _to_user_dto(record: UserRecord) -> UserDTO:
        return UserDTO(
            id=record.id,
            name=record.name,
            email=record.email,
            role=UserRole(record.role),
            role_label=record.role_label,
        )
