from sqlalchemy import Select, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from modules.asset_management.infrastructure.postgres.catalog_models import ManufacturerRecord
from modules.asset_management.infrastructure.postgres.domain_models import (
    AssetClosureRecord,
    InventoryLocationRecord,
    SlotLocationRecord,
)
from modules.asset_management.infrastructure.postgres.models import (
    AssetHistoryRecord,
    AssetRecord,
)
from modules.asset_management.interfaces.schemas import (
    AssetDTO,
    AssetHistoryEntryDTO,
    AssetTreeNodeDTO,
    StockAssetDTO,
)
from modules.maintenance_execution.infrastructure.postgres.report_models import (
    CorrectiveReportDetailRecord,
    MaintenanceActivityAssetRecord,
    MaintenanceActivityRecord,
    MaintenanceReportRecord,
    PreventiveReportDetailRecord,
    ReportVersionRecord,
)


class PostgresAssetRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def list_assets(
        self,
        q: str | None = None,
        business_anchor: bool | None = None,
        subsystem: str | None = None,
        category: str | None = None,
        status: str | None = None,
        limit: int = 50,
        offset: int = 0,
    ) -> tuple[list[AssetDTO], int]:
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
        if subsystem:
            stmt = stmt.where(func.lower(AssetRecord.subsystem) == subsystem.casefold())
        if category:
            stmt = stmt.where(func.lower(AssetRecord.category) == category.casefold())
        if status:
            stmt = stmt.where(func.lower(AssetRecord.status) == status.casefold())

        total = await self._session.scalar(
            select(func.count()).select_from(stmt.order_by(None).subquery())
        )
        result = await self._session.scalars(stmt.limit(limit).offset(offset))
        return [self._to_asset_dto(record) for record in result.all()], total or 0

    async def get_asset(self, asset_id: str) -> AssetDTO | None:
        row = (
            await self._session.execute(
                select(AssetRecord, ManufacturerRecord.name)
                .outerjoin(
                    ManufacturerRecord,
                    ManufacturerRecord.id == AssetRecord.manufacturer_id,
                )
                .where(AssetRecord.id == asset_id)
            )
        ).one_or_none()
        if row is None:
            return None
        record, manufacturer = row
        component_count = await self._session.scalar(
            select(func.count())
            .select_from(AssetClosureRecord)
            .where(
                AssetClosureRecord.ancestor_asset_id == asset_id,
                AssetClosureRecord.depth > 0,
            )
        )
        return self._to_asset_dto(
            record,
            manufacturer=manufacturer,
            component_count=component_count or 0,
        )

    async def list_stock_assets(
        self,
        *,
        q: str | None = None,
        subsystem: str | None = None,
        inventory_location: str | None = None,
        limit: int = 200,
        offset: int = 0,
    ) -> tuple[list[StockAssetDTO], int]:
        stmt = (
            select(
                AssetRecord,
                InventoryLocationRecord.name.label("inventory_location"),
                ManufacturerRecord.name.label("manufacturer"),
            )
            .join(
                InventoryLocationRecord,
                InventoryLocationRecord.id == AssetRecord.current_inventory_location_id,
            )
            .outerjoin(
                ManufacturerRecord,
                ManufacturerRecord.id == AssetRecord.manufacturer_id,
            )
            .where(AssetRecord.current_inventory_location_id.is_not(None))
            .order_by(InventoryLocationRecord.name, AssetRecord.name)
        )
        if q:
            query = f"%{q.casefold()}%"
            stmt = stmt.where(
                or_(
                    func.lower(AssetRecord.name).like(query),
                    func.lower(AssetRecord.asset_type).like(query),
                    func.lower(func.coalesce(AssetRecord.serial_number, "")).like(query),
                    func.lower(func.coalesce(AssetRecord.internal_code, "")).like(query),
                    func.lower(func.coalesce(AssetRecord.part_number, "")).like(query),
                    func.lower(InventoryLocationRecord.name).like(query),
                )
            )
        if subsystem:
            stmt = stmt.where(func.lower(AssetRecord.subsystem) == subsystem.casefold())
        if inventory_location:
            stmt = stmt.where(
                func.lower(InventoryLocationRecord.name) == inventory_location.casefold()
            )

        total = await self._session.scalar(
            select(func.count()).select_from(stmt.order_by(None).subquery())
        )
        rows = (await self._session.execute(stmt.limit(limit).offset(offset))).all()
        return [
            StockAssetDTO(
                id=record.id,
                name=record.name,
                asset_type=record.asset_type,
                serial_number=record.serial_number,
                internal_code=record.internal_code,
                part_number=record.part_number,
                status=record.status,
                inventory_location=location,
                subsystem=record.subsystem,
                manufacturer=manufacturer,
                model=record.model,
            )
            for record, location, manufacturer in rows
        ], total or 0

    async def get_tree(self, asset_id: str) -> list[AssetTreeNodeDTO]:
        rows = (
            await self._session.execute(
                select(
                    AssetClosureRecord.depth,
                    AssetRecord,
                    SlotLocationRecord.path,
                    ManufacturerRecord.name,
                )
                .join(
                    AssetRecord,
                    AssetRecord.id == AssetClosureRecord.descendant_asset_id,
                )
                .outerjoin(
                    SlotLocationRecord,
                    SlotLocationRecord.id == AssetRecord.current_slot_location_id,
                )
                .outerjoin(
                    ManufacturerRecord,
                    ManufacturerRecord.id == AssetRecord.manufacturer_id,
                )
                .where(
                    AssetClosureRecord.ancestor_asset_id == asset_id,
                    AssetClosureRecord.depth > 0,
                )
                .order_by(
                    AssetClosureRecord.depth,
                    SlotLocationRecord.path,
                    AssetRecord.name,
                )
            )
        ).all()
        return [
            AssetTreeNodeDTO(
                id=record.id,
                name=record.name,
                category=record.category,
                asset_type=record.asset_type,
                status=record.status,
                serial_number=record.serial_number or record.serial_or_code or None,
                part_number=record.part_number,
                model=record.model,
                manufacturer=manufacturer,
                parent_id=record.parent_id,
                depth=depth,
                slot_path=slot_path,
                position=record.current_position,
            )
            for depth, record, slot_path, manufacturer in rows
        ]

    async def get_history(self, asset_id: str) -> list[AssetHistoryEntryDTO]:
        latest_versions = (
            select(
                ReportVersionRecord.maintenance_report_id.label("report_id"),
                func.max(ReportVersionRecord.version_number).label("version_number"),
            )
            .where(ReportVersionRecord.document_status == "FINALIZED")
            .group_by(ReportVersionRecord.maintenance_report_id)
            .subquery()
        )

        rows = (
            await self._session.execute(
                select(
                    MaintenanceActivityRecord,
                    MaintenanceReportRecord,
                    ReportVersionRecord,
                    PreventiveReportDetailRecord.final_result,
                    CorrectiveReportDetailRecord.technical_status,
                )
                .join(
                    MaintenanceActivityAssetRecord,
                    MaintenanceActivityAssetRecord.maintenance_activity_id
                    == MaintenanceActivityRecord.id,
                )
                .outerjoin(
                    MaintenanceReportRecord,
                    MaintenanceReportRecord.maintenance_activity_id
                    == MaintenanceActivityRecord.id,
                )
                .outerjoin(
                    latest_versions,
                    latest_versions.c.report_id == MaintenanceReportRecord.id,
                )
                .outerjoin(
                    ReportVersionRecord,
                    (
                        ReportVersionRecord.maintenance_report_id
                        == latest_versions.c.report_id
                    )
                    & (
                        ReportVersionRecord.version_number
                        == latest_versions.c.version_number
                    ),
                )
                .outerjoin(
                    PreventiveReportDetailRecord,
                    PreventiveReportDetailRecord.report_version_id == ReportVersionRecord.id,
                )
                .outerjoin(
                    CorrectiveReportDetailRecord,
                    CorrectiveReportDetailRecord.report_version_id == ReportVersionRecord.id,
                )
                .where(
                    MaintenanceActivityAssetRecord.asset_id == asset_id,
                    MaintenanceActivityRecord.status.in_(["COMPLETED", "CLOSED"]),
                )
                .order_by(
                    func.coalesce(
                        ReportVersionRecord.finalized_at,
                        MaintenanceActivityRecord.completed_at,
                        MaintenanceActivityRecord.actual_end_at,
                        MaintenanceActivityRecord.scheduled_start_at,
                        MaintenanceActivityRecord.created_at,
                    ).desc()
                )
            )
        ).all()

        normalized = [
            AssetHistoryEntryDTO(
                id=str(version.id if version is not None else activity.id),
                report_type=activity.activity_type.casefold(),
                report_id=str(
                    version.id
                    if version is not None
                    else report.id
                    if report is not None
                    else activity.id
                ),
                title=activity.title,
                performed_at=(
                    version.finalized_at
                    if version is not None and version.finalized_at is not None
                    else activity.completed_at
                    or activity.actual_end_at
                    or activity.scheduled_start_at
                    or activity.created_at
                ).isoformat(),
                result=preventive_result
                or corrective_status
                or "Sin resultado registrado",
                activity_id=str(activity.id),
                activity_status=activity.status,
                report_kind=report.report_kind if report is not None else None,
                version_number=version.version_number if version is not None else None,
            )
            for activity, report, version, preventive_result, corrective_status in rows
        ]
        if normalized:
            return normalized

        # Transitional development databases may still contain only the old history projection.
        result = await self._session.scalars(
            select(AssetHistoryRecord)
            .where(AssetHistoryRecord.asset_id == asset_id)
            .order_by(AssetHistoryRecord.performed_at.desc())
        )
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
    def _to_asset_dto(
        record: AssetRecord,
        *,
        manufacturer: str | None = None,
        component_count: int = 0,
    ) -> AssetDTO:
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
            business_label=record.business_label,
            manufacturer=manufacturer,
            model=record.model,
            software_version=record.software_version,
            current_position=record.current_position,
            component_count=component_count,
        )
