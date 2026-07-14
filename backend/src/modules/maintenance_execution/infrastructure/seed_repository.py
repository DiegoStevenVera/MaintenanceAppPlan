from datetime import datetime

from modules.maintenance_execution.interfaces.schemas import (
    CorrectiveEventDTO,
    CreateCorrectiveEventRequest,
    PreventiveScheduleDTO,
)
from shared_kernel.schemas import MaintenanceStatus, Severity, TimelineEntryDTO


class SeedMaintenanceRepository:
    def __init__(self) -> None:
        self._preventive_schedules = [
            PreventiveScheduleDTO(
                id="prv-001",
                name="Mantenimiento preventivo de software ATS - ECIN",
                template_name="Mantenimiento preventivo de software ATS",
                asset_ids=["asset-crk-1", "asset-crk-2"],
                asset_names=["CRK 1", "CRK 2"],
                subsystem="ATS",
                scheduled_at="2026-06-21T09:00:00-05:00",
                status=MaintenanceStatus.SCHEDULED,
                physical_location="Patio Santa Anita -> Sala tecnica ATS -> Gabinetes ATS",
                report_version_count=0,
            ),
            PreventiveScheduleDTO(
                id="prv-002",
                name="Inspeccion de gabinete Frontam - Colectora",
                template_name="Inspeccion de gabinete Frontam",
                asset_ids=["asset-frontam-colectora"],
                asset_names=["CUBICULO EQUIPADO DEL FRONTAM - COLECTORA"],
                subsystem="CBTC",
                scheduled_at="2026-06-21T10:30:00-05:00",
                status=MaintenanceStatus.IN_PROGRESS,
                physical_location="Estacion Colectora Industrial -> Sala tecnica -> Sala 2.21",
                report_version_count=1,
            ),
        ]
        self._corrective_events = [
            CorrectiveEventDTO(
                id="cor-001",
                code="COR-2026-001",
                sap_code="110010514",
                name="E22 Falla de servidor Frontam",
                affected_asset_id="asset-frontam-colectora",
                affected_asset_path=(
                    "CUBICULO EQUIPADO DEL FRONTAM - COLECTORA > "
                    "Gabinete / conjunto principal > Modulo interno"
                ),
                subsystem="CBTC",
                severity=Severity.HIGH,
                status=MaintenanceStatus.IN_PROGRESS,
                notice_created_at="2026-06-21T07:42:00-05:00",
                response_at="2026-06-21T08:05:00-05:00",
                physical_location="Estacion Colectora Industrial -> Sala tecnica -> Sala 2.21",
                report_version_count=1,
                timeline=[
                    TimelineEntryDTO(
                        id="tl-cor-001-created",
                        occurred_at=datetime.fromisoformat("2026-06-21T07:42:00-05:00"),
                        text="Evento creado por Diego Vera",
                    )
                ],
            )
        ]

    def list_preventive_schedules(
        self,
        status: MaintenanceStatus | None = None,
        subsystem: str | None = None,
    ) -> list[PreventiveScheduleDTO]:
        schedules = self._preventive_schedules
        if status:
            schedules = [schedule for schedule in schedules if schedule.status == status]
        if subsystem:
            schedules = [
                schedule
                for schedule in schedules
                if schedule.subsystem.casefold() == subsystem.casefold()
            ]
        return schedules

    def list_corrective_events(
        self,
        status: MaintenanceStatus | None = None,
        subsystem: str | None = None,
    ) -> list[CorrectiveEventDTO]:
        events = self._corrective_events
        if status:
            events = [event for event in events if event.status == status]
        if subsystem:
            events = [event for event in events if event.subsystem.casefold() == subsystem.casefold()]
        return events

    def get_corrective_event(self, event_id: str) -> CorrectiveEventDTO | None:
        return next((event for event in self._corrective_events if event.id == event_id), None)

    def create_corrective_event(self, payload: CreateCorrectiveEventRequest) -> CorrectiveEventDTO:
        next_number = len(self._corrective_events) + 1
        event = CorrectiveEventDTO(
            id=f"cor-{next_number:03d}",
            code=f"COR-2026-{next_number:03d}",
            sap_code=payload.sap_notification,
            name=payload.sap_event_name,
            affected_asset_path=payload.affected_asset_path,
            subsystem=payload.subsystem,
            severity=payload.severity,
            status=MaintenanceStatus.SCHEDULED,
            notice_created_at=payload.notice_created_at,
            response_at=payload.response_at,
            physical_location=payload.physical_location,
            report_version_count=0,
            timeline=[
                TimelineEntryDTO(
                    id=f"tl-cor-{next_number:03d}-created",
                    occurred_at=datetime.now().astimezone(),
                    text="Evento correctivo creado",
                )
            ],
        )
        self._corrective_events.insert(0, event)
        return event


maintenance_repository = SeedMaintenanceRepository()
