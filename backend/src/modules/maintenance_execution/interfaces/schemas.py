from pydantic import BaseModel

from shared_kernel.schemas import MaintenanceStatus, Severity, TimelineEntryDTO


class PreventiveScheduleDTO(BaseModel):
    id: str
    name: str
    template_name: str
    asset_ids: list[str]
    asset_names: list[str]
    subsystem: str
    scheduled_at: str
    status: MaintenanceStatus
    physical_location: str
    report_version_count: int


class CorrectiveEventDTO(BaseModel):
    id: str
    code: str
    sap_code: str
    name: str
    affected_asset_id: str | None = None
    affected_asset_path: str
    subsystem: str
    severity: Severity
    status: MaintenanceStatus
    notice_created_at: str
    response_at: str
    physical_location: str
    report_version_count: int
    timeline: list[TimelineEntryDTO] = []


class CreateCorrectiveEventRequest(BaseModel):
    sap_event_name: str
    sap_notification: str
    affected_asset_path: str
    subsystem: str
    severity: Severity
    notice_created_at: str
    response_at: str
    physical_location: str
