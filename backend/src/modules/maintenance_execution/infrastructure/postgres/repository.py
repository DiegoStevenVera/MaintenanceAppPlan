from datetime import datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from modules.maintenance_execution.infrastructure.postgres.models import (
    CorrectiveEventRecord,
    PreventiveScheduleRecord,
)
from modules.maintenance_execution.interfaces.schemas import (
    CorrectiveEventDTO,
    CreateCorrectiveEventRequest,
    PreventiveScheduleDTO,
)
from shared_kernel.schemas import MaintenanceStatus, Severity, TimelineEntryDTO


class PostgresMaintenanceRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def list_preventive_schedules(
        self,
        status: MaintenanceStatus | None = None,
        subsystem: str | None = None,
    ) -> list[PreventiveScheduleDTO]:
        stmt = select(PreventiveScheduleRecord).order_by(PreventiveScheduleRecord.scheduled_at)
        if status:
            stmt = stmt.where(PreventiveScheduleRecord.status == status.value)
        if subsystem:
            stmt = stmt.where(func.lower(PreventiveScheduleRecord.subsystem) == subsystem.casefold())
        result = await self._session.scalars(stmt)
        return [self._to_preventive_dto(record) for record in result.all()]

    async def list_corrective_events(
        self,
        status: MaintenanceStatus | None = None,
        subsystem: str | None = None,
    ) -> list[CorrectiveEventDTO]:
        stmt = select(CorrectiveEventRecord).order_by(CorrectiveEventRecord.notice_created_at.desc())
        if status:
            stmt = stmt.where(CorrectiveEventRecord.status == status.value)
        if subsystem:
            stmt = stmt.where(func.lower(CorrectiveEventRecord.subsystem) == subsystem.casefold())
        result = await self._session.scalars(stmt)
        return [self._to_corrective_dto(record) for record in result.all()]

    async def get_corrective_event(self, event_id: str) -> CorrectiveEventDTO | None:
        record = await self._session.get(CorrectiveEventRecord, event_id)
        if record is None:
            return None
        return self._to_corrective_dto(record)

    async def create_corrective_event(
        self,
        payload: CreateCorrectiveEventRequest,
    ) -> CorrectiveEventDTO:
        total_events = await self._session.scalar(select(func.count(CorrectiveEventRecord.id)))
        next_number = int(total_events or 0) + 1
        now = datetime.now().astimezone()
        record = CorrectiveEventRecord(
            id=f"cor-{next_number:03d}",
            code=f"COR-2026-{next_number:03d}",
            sap_code=payload.sap_notification,
            name=payload.sap_event_name,
            affected_asset_id=None,
            affected_asset_path=payload.affected_asset_path,
            subsystem=payload.subsystem,
            severity=payload.severity.value,
            status=MaintenanceStatus.SCHEDULED.value,
            notice_created_at=payload.notice_created_at,
            response_at=payload.response_at,
            physical_location=payload.physical_location,
            report_version_count=0,
            timeline=[
                {
                    "id": f"tl-cor-{next_number:03d}-created",
                    "occurred_at": now.isoformat(),
                    "text": "Evento correctivo creado",
                }
            ],
        )
        self._session.add(record)
        await self._session.commit()
        await self._session.refresh(record)
        return self._to_corrective_dto(record)

    @staticmethod
    def _to_preventive_dto(record: PreventiveScheduleRecord) -> PreventiveScheduleDTO:
        return PreventiveScheduleDTO(
            id=record.id,
            name=record.name,
            template_name=record.template_name,
            asset_ids=record.asset_ids,
            asset_names=record.asset_names,
            subsystem=record.subsystem,
            scheduled_at=record.scheduled_at,
            status=MaintenanceStatus(record.status),
            physical_location=record.physical_location,
            report_version_count=record.report_version_count,
        )

    @staticmethod
    def _to_corrective_dto(record: CorrectiveEventRecord) -> CorrectiveEventDTO:
        return CorrectiveEventDTO(
            id=record.id,
            code=record.code,
            sap_code=record.sap_code,
            name=record.name,
            affected_asset_id=record.affected_asset_id,
            affected_asset_path=record.affected_asset_path,
            subsystem=record.subsystem,
            severity=Severity(record.severity),
            status=MaintenanceStatus(record.status),
            notice_created_at=record.notice_created_at,
            response_at=record.response_at,
            physical_location=record.physical_location,
            report_version_count=record.report_version_count,
            timeline=[
                TimelineEntryDTO(
                    id=item["id"],
                    occurred_at=datetime.fromisoformat(item["occurred_at"]),
                    text=item["text"],
                )
                for item in record.timeline
            ],
        )
