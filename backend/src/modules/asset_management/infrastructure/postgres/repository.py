from sqlalchemy import Select, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from modules.asset_management.infrastructure.postgres.models import (
    AssetHistoryRecord,
    AssetRecord,
)
from modules.asset_management.interfaces.schemas import AssetDTO, AssetHistoryEntryDTO


class PostgresAssetRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def list_assets(
        self,
        q: str | None = None,
        business_anchor: bool | None = None,
    ) -> list[AssetDTO]:
        stmt: Select[tuple[AssetRecord]] = select(AssetRecord).order_by(AssetRecord.name)
        if business_anchor is not None:
            stmt = stmt.where(AssetRecord.is_business_anchor.is_(business_anchor))
        if q:
            query = f"%{q.casefold()}%"
            stmt = stmt.where(
                or_(
                    func.lower(AssetRecord.name).like(query),
                    func.lower(AssetRecord.category).like(query),
                    func.lower(AssetRecord.asset_type).like(query),
                    func.lower(AssetRecord.serial_or_code).like(query),
                )
            )
        result = await self._session.scalars(stmt)
        return [self._to_asset_dto(record) for record in result.all()]

    async def get_asset(self, asset_id: str) -> AssetDTO | None:
        record = await self._session.get(AssetRecord, asset_id)
        if record is None:
            return None
        return self._to_asset_dto(record)

    async def get_history(self, asset_id: str) -> list[AssetHistoryEntryDTO]:
        stmt = (
            select(AssetHistoryRecord)
            .where(AssetHistoryRecord.asset_id == asset_id)
            .order_by(AssetHistoryRecord.performed_at.desc())
        )
        result = await self._session.scalars(stmt)
        return [
            AssetHistoryEntryDTO(
                id=record.id,
                report_type=record.report_type,
                report_id=record.report_id,
                title=record.title,
                performed_at=record.performed_at,
                result=record.result,
            )
            for record in result.all()
        ]

    @staticmethod
    def _to_asset_dto(record: AssetRecord) -> AssetDTO:
        return AssetDTO(
            id=record.id,
            name=record.name,
            category=record.category,
            asset_type=record.asset_type,
            subsystem=record.subsystem,
            serial_or_code=record.serial_or_code,
            part_number=record.part_number,
            status=record.status,
            physical_location=record.physical_location,
            is_business_anchor=record.is_business_anchor,
            parent_id=record.parent_id,
            children=record.children,
        )
