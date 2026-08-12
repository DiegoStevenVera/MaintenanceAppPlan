from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator

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
    business_anchor_asset_id: str | None = None
    affected_asset_id: str | None = None
    affected_asset_path: str
    subsystem: str
    severity: Severity
    notice_created_at: str
    response_at: str
    physical_location: str


class CorrectiveCreationContextDTO(BaseModel):
    business_anchor_asset_id: str
    site: str
    project: str
    stage: str | None = None
    system: str
    subsystem: str
    physical_location: str


class MaintenanceActivityAssetDTO(BaseModel):
    id: str
    name: str
    role: str


class MaintenanceReportVersionDTO(BaseModel):
    id: str
    report_kind: str
    report_number: int
    version_number: int
    document_status: str
    summary: str | None = None
    created_at: datetime
    finalized_at: datetime | None = None


class PreventiveTestResultDTO(BaseModel):
    id: str
    name: str
    selected_result: str
    numeric_value: str | None = None
    notes: str | None = None


class PreventiveStepResultDTO(BaseModel):
    id: str
    title: str
    manual_page: int | None = None
    is_completed: bool
    comment: str | None = None
    tests: list[PreventiveTestResultDTO] = Field(default_factory=list)


class PreventiveReportDTO(BaseModel):
    actual_date: str
    activity_started_at: datetime
    activity_ended_at: datetime | None = None
    final_result: str | None = None
    additional_comments: str | None = None
    steps: list[PreventiveStepResultDTO] = Field(default_factory=list)


class CalibrationReceiverDTO(BaseModel):
    sequence: int
    jumpers: str | None = None
    tca9: str | None = None
    rail_current: str | None = None


class CalibrationReportDTO(BaseModel):
    track_circuit_asset_id: str
    track_circuit_name: str
    frequency: str | None = None
    calibration_date: date
    location: str
    transmitter_jumpers: str | None = None
    receivers: list[CalibrationReceiverDTO] = Field(default_factory=list)


class ComponentReplacementDTO(BaseModel):
    parent_asset_id: str
    parent_asset_name: str | None = None
    removed_asset_id: str
    removed_asset_name: str | None = None
    removed_asset_path: str | None = None
    removed_part_number: str | None = None
    removed_serial_number: str | None = None
    removed_model: str | None = None
    removed_manufacturer: str | None = None
    installed_asset_id: str
    installed_asset_name: str | None = None
    installed_asset_path: str | None = None
    installed_part_number: str | None = None
    installed_serial_number: str | None = None
    installed_model: str | None = None
    installed_manufacturer: str | None = None
    source_description: str
    destination_description: str
    removed_condition: str | None = None
    installed_condition: str | None = None
    removed_notes: str | None = None
    installed_notes: str | None = None
    reason: str


class CorrectiveActivityDTO(BaseModel):
    id: str
    name: str
    description: str
    started_at: datetime
    ended_at: datetime | None = None
    replacement: ComponentReplacementDTO | None = None


class CorrectiveReportDTO(BaseModel):
    event_code: str | None = None
    sap_notification: str | None = None
    sap_event_name: str | None = None
    affected_asset_path: str | None = None
    notice_created_at: datetime | None = None
    response_at: datetime | None = None
    corrective_started_at: datetime | None = None
    corrective_ended_at: datetime | None = None
    symptom: str | None = None
    technical_description: str | None = None
    operational_impact: str | None = None
    failure_analysis_type: str | None = None
    functional_tests: str | None = None
    validation_result: str | None = None
    service_released: bool = False
    service_released_at: datetime | None = None
    validation_responsible: str | None = None
    technical_status: str | None = None
    conclusion: str | None = None
    additional_comments: str | None = None
    activities: list[CorrectiveActivityDTO] = Field(default_factory=list)


class MaintenanceActivityDTO(BaseModel):
    id: str
    activity_type: str
    status: MaintenanceStatus
    title: str
    internal_code: str
    project: str | None = None
    stage: str | None = None
    system: str | None = None
    subsystem: str
    site: str | None = None
    location_path: str | None = None
    scheduled_at: datetime | None = None
    planned_year: int | None = None
    planned_month: int | None = None
    actual_start_at: datetime | None = None
    actual_end_at: datetime | None = None
    assets: list[MaintenanceActivityAssetDTO] = Field(default_factory=list)
    report_version_count: int = 0
    event_id: str | None = None
    event_code: str | None = None
    severity: Severity | None = None


class MaintenanceActivityDetailDTO(MaintenanceActivityDTO):
    reports: list[MaintenanceReportVersionDTO] = Field(default_factory=list)
    preventive_report: PreventiveReportDTO | None = None
    corrective_report: CorrectiveReportDTO | None = None


class MaintenanceDashboardDTO(BaseModel):
    preventive_today_count: int = 0
    active_corrective_count: int = 0
    pending_closure_count: int = 0
    preventive_today: list[MaintenanceActivityDTO] = Field(default_factory=list)
    active_correctives: list[MaintenanceActivityDTO] = Field(default_factory=list)
    pending_closure: list[MaintenanceActivityDTO] = Field(default_factory=list)


class ReopenMaintenanceRequest(BaseModel):
    reason: str = Field(min_length=3, max_length=500)

    @field_validator("reason")
    @classmethod
    def validate_reason(cls, value: str) -> str:
        normalized = value.strip()
        if len(normalized) < 3:
            raise ValueError("El motivo debe tener al menos 3 caracteres.")
        return normalized


class SignaturePointDTO(BaseModel):
    x: float
    y: float


class ReportParticipantWriteDTO(BaseModel):
    user_id: str
    selected: bool = True
    signature_strokes: list[list[SignaturePointDTO]] = Field(default_factory=list)
    signature_image_base64: str | None = None


class ReportEvidenceWriteDTO(BaseModel):
    client_id: str
    attachment_id: str | None = None
    original_file_name: str
    media_type: str
    title: str | None = None
    description: str | None = None
    captured_at: datetime
    content_base64: str | None = None
    preventive_step_id: str | None = None
    corrective_activity_client_id: str | None = None


class PreventiveTestWriteDTO(BaseModel):
    template_test_id: str
    name: str
    selected_result: str
    numeric_value: str | None = None
    notes: str | None = None


class PreventiveStepWriteDTO(BaseModel):
    template_step_id: str
    title: str
    manual_page: int | None = None
    sequence: int
    is_completed: bool = True
    comment: str | None = None
    tests: list[PreventiveTestWriteDTO] = Field(default_factory=list)


class PreventiveReportWriteDTO(BaseModel):
    activity_ended_at: datetime | None = None
    final_result: str | None = None
    additional_comments: str | None = None
    steps: list[PreventiveStepWriteDTO] = Field(default_factory=list)
    participants: list[ReportParticipantWriteDTO] = Field(default_factory=list)
    evidence: list[ReportEvidenceWriteDTO] = Field(default_factory=list)


class CalibrationReceiverWriteDTO(BaseModel):
    sequence: int = Field(ge=1)
    jumpers: str = ""
    tca9: str = ""
    rail_current: str = ""


class CalibrationReportWriteDTO(BaseModel):
    frequency: str = ""
    transmitter_jumpers: str = ""
    receivers: list[CalibrationReceiverWriteDTO] = Field(default_factory=list)


class ComponentReplacementWriteDTO(BaseModel):
    parent_asset_id: str
    removed_asset_id: str
    installed_asset_id: str
    removed_part_number: str | None = None
    removed_serial_number: str | None = None
    removed_model: str | None = None
    removed_manufacturer: str | None = None
    installed_part_number: str | None = None
    installed_serial_number: str | None = None
    installed_model: str | None = None
    installed_manufacturer: str | None = None
    source_description: str
    destination_description: str
    removed_condition: str | None = None
    installed_condition: str | None = None
    removed_notes: str | None = None
    installed_notes: str | None = None
    reason: str


class CorrectiveActivityWriteDTO(BaseModel):
    client_id: str
    action_type_code: str
    name: str
    description: str
    started_at: datetime
    ended_at: datetime | None = None
    replacement: ComponentReplacementWriteDTO | None = None


class CorrectiveReportWriteDTO(BaseModel):
    symptom: str | None = None
    technical_description: str | None = None
    operational_impact: str | None = None
    failure_analysis_type: str | None = None
    functional_tests: str | None = None
    validation_result: str | None = None
    service_released: bool = False
    service_released_at: datetime | None = None
    validation_responsible: str | None = None
    technical_status: str | None = None
    conclusion: str | None = None
    additional_comments: str | None = None
    corrective_ended_at: datetime | None = None
    stop_after_block_order: int | None = None
    activities: list[CorrectiveActivityWriteDTO] = Field(default_factory=list)
    participants: list[ReportParticipantWriteDTO] = Field(default_factory=list)
    evidence: list[ReportEvidenceWriteDTO] = Field(default_factory=list)


class ReportDraftWriteRequest(BaseModel):
    base_report_version_id: str | None = None
    enforce_base_version: bool = False
    preventive: PreventiveReportWriteDTO | None = None
    corrective: CorrectiveReportWriteDTO | None = None
    calibration: CalibrationReportWriteDTO | None = None


class ReportWriteResultDTO(BaseModel):
    report_id: str
    version_id: str
    version_number: int
    document_status: str
    saved_at: datetime
    calibration_version_id: str | None = None


class ReportParticipantDTO(BaseModel):
    id: str
    user_id: str
    name: str
    role: str
    selected: bool
    signed_at: datetime | None = None
    signature_strokes: list[list[SignaturePointDTO]] = Field(default_factory=list)


class ReportEvidenceDTO(BaseModel):
    id: str
    original_file_name: str | None = None
    media_type: str | None = None
    title: str | None = None
    description: str | None = None
    captured_at: datetime
    content_path: str


class GeneratedReportDTO(BaseModel):
    id: str
    report_version_id: str
    file_name: str
    file_format: str
    file_size_bytes: int | None = None
    generated_at: datetime
    download_path: str


class MaintenanceReportVersionDetailDTO(BaseModel):
    id: str
    report_kind: str
    report_number: int
    version_number: int
    document_status: str
    summary: str | None = None
    created_at: datetime
    finalized_at: datetime | None = None
    activity: MaintenanceActivityDTO
    preventive_report: PreventiveReportDTO | None = None
    corrective_report: CorrectiveReportDTO | None = None
    calibration_report: CalibrationReportDTO | None = None
    participants: list[ReportParticipantDTO] = Field(default_factory=list)
    evidence: list[ReportEvidenceDTO] = Field(default_factory=list)
    generated_report: GeneratedReportDTO | None = None


class MaintenanceCommentCreateRequest(BaseModel):
    message: str = Field(min_length=1, max_length=2000)

    @field_validator("message")
    @classmethod
    def validate_message(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("El comentario no puede estar vacío.")
        return normalized


class MaintenanceCommentDTO(BaseModel):
    id: str
    scope: Literal["PREVENTIVE_KNOWLEDGE", "CORRECTIVE_EVENT"]
    author_user_id: str
    author_name: str
    author_role: str
    message: str
    created_at: datetime


class ReportEditorUserDTO(BaseModel):
    id: str
    name: str
    role: str


class ReportEditorActionTypeDTO(BaseModel):
    code: str
    name: str


class ReportEditorAssetDTO(BaseModel):
    id: str
    name: str
    path: str
    parent_id: str | None = None
    part_number: str | None = None
    serial_number: str | None = None
    model: str | None = None
    manufacturer: str | None = None
    status: str


class PreventiveTemplateTestDTO(BaseModel):
    id: str
    name: str
    result_options: list[str] = Field(default_factory=list)
    default_result: str = ""


class PreventiveTemplateStepDTO(BaseModel):
    id: str
    title: str
    manual_page: int | None = None
    sequence: int
    default_comment: str | None = None
    tests: list[PreventiveTemplateTestDTO] = Field(default_factory=list)


class PreventiveHistoryReportDTO(BaseModel):
    activity_id: str
    version_id: str
    title: str
    internal_code: str
    equipment_names: list[str] = Field(default_factory=list)
    performed_at: datetime
    final_result: str | None = None
    version_number: int
    document_status: str


class PreventiveGuideDTO(BaseModel):
    activity_id: str
    template_name: str | None = None
    template_steps: list[PreventiveTemplateStepDTO] = Field(default_factory=list)
    previous_reports: list[PreventiveHistoryReportDTO] = Field(default_factory=list)
    previous_reports_has_more: bool = False
    previous_reports_offset: int = Field(default=0, ge=0)


class ReportEditorDTO(BaseModel):
    activity_id: str
    activity_type: str
    status: MaintenanceStatus
    actual_date: date
    activity_started_at: datetime
    activity_ended_at: datetime | None = None
    report_version_id: str | None = None
    document_status: str | None = None
    preventive_draft: PreventiveReportWriteDTO | None = None
    corrective_draft: CorrectiveReportWriteDTO | None = None
    calibration_required: bool = False
    calibration_draft: CalibrationReportWriteDTO | None = None
    template_steps: list[PreventiveTemplateStepDTO] = Field(default_factory=list)
    available_participants: list[ReportEditorUserDTO] = Field(default_factory=list)
    action_types: list[ReportEditorActionTypeDTO] = Field(default_factory=list)
    equipment_assets: list[ReportEditorAssetDTO] = Field(default_factory=list)
    stock_assets: list[ReportEditorAssetDTO] = Field(default_factory=list)
    inventory_locations: list[str] = Field(default_factory=list)
    participants: list[ReportParticipantDTO] = Field(default_factory=list)
    evidence: list[ReportEvidenceDTO] = Field(default_factory=list)
    comments: list[MaintenanceCommentDTO] = Field(default_factory=list)
