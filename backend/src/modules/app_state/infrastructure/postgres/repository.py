from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from modules.app_state.infrastructure.postgres.models import AppStateSnapshotRecord


class PostgresAppStateRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_current(self) -> dict | None:
        record = await self._session.scalar(
            select(AppStateSnapshotRecord).where(AppStateSnapshotRecord.id == "current")
        )
        if record is None:
            return None
        return record.payload

    async def upsert_current(self, payload: dict) -> None:
        await self._session.merge(AppStateSnapshotRecord(id="current", payload=payload))
