from datetime import date, datetime
from uuid import UUID

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    LargeBinary,
    String,
    Text,
    UniqueConstraint,
    Uuid,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base
from shared_kernel.persistence import OperationalRecordMixin


class MaintenanceActivityRecord(OperationalRecordMixin, Base):
    __tablename__ = "maintenance_activities"

    legacy_id: Mapped[int | None] = mapped_column(Integer, unique=True)
    activity_type: Mapped[str] = mapped_column(String(30), nullable=False, index=True)
    status: Mapped[str] = mapped_column(String(30), nullable=False, index=True)
    project_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("projects.id"),
        nullable=False,
        index=True,
    )
    primary_stage_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("stages.id"),
        index=True,
    )
    subsystem_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("subsystems.id"),
        nullable=False,
        index=True,
    )
    geographic_location_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("geographic_locations.id"),
        index=True,
    )
    maintenance_template_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("maintenance_templates.id"),
        index=True,
    )
    title: Mapped[str] = mapped_column(String(280), nullable=False, index=True)
    internal_code: Mapped[str] = mapped_column(String(100), nullable=False, unique=True)
    scheduled_start_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    scheduled_end_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    actual_start_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    actual_end_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    shift: Mapped[str | None] = mapped_column(String(80))
    sap_order: Mapped[str | None] = mapped_column(String(120))
    work_order: Mapped[str | None] = mapped_column(String(120))
    location_path_snapshot: Mapped[str | None] = mapped_column(Text)
    created_by_user_id: Mapped[str | None] = mapped_column(String(80), ForeignKey("users.id"))
    completed_by_user_id: Mapped[str | None] = mapped_column(String(80), ForeignKey("users.id"))
    closed_by_user_id: Mapped[str | None] = mapped_column(String(80), ForeignKey("users.id"))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    closed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class MaintenanceActivityAssetRecord(OperationalRecordMixin, Base):
    __tablename__ = "maintenance_activity_assets"
    __table_args__ = (
        UniqueConstraint(
            "maintenance_activity_id",
            "asset_id",
            "role",
            name="uq_maintenance_activity_assets_role",
        ),
    )

    maintenance_activity_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("maintenance_activities.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    asset_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("assets.id"),
        nullable=False,
        index=True,
    )
    role: Mapped[str] = mapped_column(String(40), nullable=False)
    include_descendants: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    notes: Mapped[str | None] = mapped_column(Text)


class CorrectiveEventAffectedAssetRecord(OperationalRecordMixin, Base):
    __tablename__ = "corrective_event_affected_assets"
    __table_args__ = (
        UniqueConstraint(
            "corrective_event_id",
            "asset_id",
            name="uq_corrective_event_affected_asset",
        ),
    )

    corrective_event_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("corrective_events.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    asset_id: Mapped[str] = mapped_column(String(80), ForeignKey("assets.id"), nullable=False, index=True)
    path_snapshot: Mapped[str] = mapped_column(Text, nullable=False)
    is_critical: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)


class MaintenanceActivityAssignmentRecord(OperationalRecordMixin, Base):
    __tablename__ = "maintenance_activity_assignments"
    __table_args__ = (
        UniqueConstraint(
            "maintenance_activity_id",
            "user_id",
            name="uq_maintenance_activity_assignments_user",
        ),
    )

    maintenance_activity_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("maintenance_activities.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("users.id"),
        nullable=False,
        index=True,
    )
    assignment_role: Mapped[str] = mapped_column(String(80), nullable=False)
    assigned_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    assigned_by_user_id: Mapped[str | None] = mapped_column(String(80), ForeignKey("users.id"))


class MaintenanceStatusHistoryRecord(OperationalRecordMixin, Base):
    __tablename__ = "maintenance_status_history"

    maintenance_activity_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("maintenance_activities.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    from_status: Mapped[str | None] = mapped_column(String(30))
    to_status: Mapped[str] = mapped_column(String(30), nullable=False)
    changed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    changed_by_user_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("users.id"),
        nullable=False,
    )
    reason: Mapped[str | None] = mapped_column(Text)


class MaintenanceReopenRecord(OperationalRecordMixin, Base):
    __tablename__ = "maintenance_reopen_records"

    maintenance_activity_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("maintenance_activities.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    reopened_by_user_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("users.id"),
        nullable=False,
    )
    reopened_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    previous_status: Mapped[str] = mapped_column(String(30), nullable=False)
    reason: Mapped[str] = mapped_column(Text, nullable=False)


class MaintenanceReportRecord(OperationalRecordMixin, Base):
    __tablename__ = "maintenance_reports"
    __table_args__ = (
        UniqueConstraint(
            "maintenance_activity_id",
            "report_kind",
            "report_number",
            name="uq_maintenance_reports_activity_kind_number",
        ),
        Index(
            "uq_corrective_reports_year_number",
            "report_year",
            "report_number",
            unique=True,
            postgresql_where=text(
                "report_kind = 'CORRECTIVE' AND report_year IS NOT NULL"
            ),
        ),
    )

    legacy_id: Mapped[int | None] = mapped_column(Integer, unique=True)
    maintenance_activity_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("maintenance_activities.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    report_kind: Mapped[str] = mapped_column(String(40), nullable=False, index=True)
    report_year: Mapped[int | None] = mapped_column(Integer, index=True)
    report_number: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    shift_label: Mapped[str | None] = mapped_column(String(80))
    status: Mapped[str] = mapped_column(String(30), nullable=False)
    created_by_user_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("users.id"),
        nullable=False,
    )


class ReportVersionRecord(OperationalRecordMixin, Base):
    __tablename__ = "report_versions"
    __table_args__ = (
        CheckConstraint("version_number >= 1", name="ck_report_versions_number"),
        UniqueConstraint(
            "maintenance_report_id",
            "version_number",
            name="uq_report_versions_report_number",
        ),
    )

    legacy_id: Mapped[int | None] = mapped_column(Integer, unique=True)
    maintenance_report_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("maintenance_reports.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    version_number: Mapped[int] = mapped_column(Integer, nullable=False)
    document_status: Mapped[str] = mapped_column(String(30), nullable=False, index=True)
    summary: Mapped[str | None] = mapped_column(Text)
    stop_after_block_order: Mapped[int | None] = mapped_column(Integer)
    source_version_id: Mapped[UUID | None] = mapped_column(Uuid, ForeignKey("report_versions.id"))
    created_by_user_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("users.id"),
        nullable=False,
    )
    finalized_by_user_id: Mapped[str | None] = mapped_column(String(80), ForeignKey("users.id"))
    finalized_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    data_snapshot: Mapped[dict | None] = mapped_column(JSONB)


class ReportVersionAssetRecord(OperationalRecordMixin, Base):
    __tablename__ = "report_version_assets"
    __table_args__ = (
        UniqueConstraint(
            "report_version_id",
            "asset_id",
            "role",
            name="uq_report_version_assets_role",
        ),
    )

    report_version_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("report_versions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    asset_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("assets.id"),
        nullable=False,
        index=True,
    )
    role: Mapped[str] = mapped_column(String(40), nullable=False)
    snapshot_name: Mapped[str] = mapped_column(String(240), nullable=False)
    snapshot_internal_code: Mapped[str] = mapped_column(String(120), nullable=False)
    snapshot_path: Mapped[str | None] = mapped_column(Text)
    snapshot_part_number: Mapped[str | None] = mapped_column(String(120))
    snapshot_serial_number: Mapped[str | None] = mapped_column(String(120))


class ReportParticipantRecord(OperationalRecordMixin, Base):
    __tablename__ = "report_participants"
    __table_args__ = (
        UniqueConstraint(
            "report_version_id",
            "user_id",
            name="uq_report_participants_version_user",
        ),
    )

    legacy_id: Mapped[int | None] = mapped_column(Integer, unique=True)
    report_version_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("report_versions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("users.id"),
        nullable=False,
        index=True,
    )
    role_snapshot: Mapped[str] = mapped_column(String(100), nullable=False)
    selected: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)


class ReportSignatureRecord(OperationalRecordMixin, Base):
    __tablename__ = "report_signatures"
    __table_args__ = (
        UniqueConstraint("report_participant_id", name="uq_report_signatures_participant"),
    )

    report_participant_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("report_participants.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    signed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    strokes: Mapped[list | None] = mapped_column(JSONB)
    image_data: Mapped[bytes | None] = mapped_column(LargeBinary)
    file_reference: Mapped[str | None] = mapped_column(Text)
    checksum: Mapped[str | None] = mapped_column(String(64))


class PreventiveReportDetailRecord(Base):
    __tablename__ = "preventive_report_details"

    report_version_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("report_versions.id", ondelete="CASCADE"),
        primary_key=True,
    )
    site_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("sites.id"), nullable=False)
    project_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("projects.id"), nullable=False)
    stage_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("stages.id"), nullable=False)
    system_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("systems.id"), nullable=False)
    subsystem_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("subsystems.id"), nullable=False)
    geographic_location_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("geographic_locations.id"),
    )
    location_path_snapshot: Mapped[str] = mapped_column(Text, nullable=False)
    actual_date: Mapped[date] = mapped_column(Date, nullable=False)
    activity_started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    activity_ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    final_result: Mapped[str | None] = mapped_column(String(80))
    additional_comments: Mapped[str | None] = mapped_column(Text)


class PreventiveStepResultRecord(OperationalRecordMixin, Base):
    __tablename__ = "preventive_step_results"
    __table_args__ = (
        UniqueConstraint(
            "report_version_id",
            "template_step_id",
            name="uq_preventive_step_results_version_step",
        ),
    )

    legacy_id: Mapped[int | None] = mapped_column(Integer, unique=True)
    report_version_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("report_versions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    template_step_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("maintenance_template_steps.id"),
        nullable=False,
        index=True,
    )
    is_completed: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    comment: Mapped[str | None] = mapped_column(Text)
    manual_page_snapshot: Mapped[int | None] = mapped_column(Integer)
    sequence_snapshot: Mapped[int] = mapped_column(Integer, nullable=False)
    title_snapshot: Mapped[str] = mapped_column(Text, nullable=False)


class PreventiveTestResultRecord(OperationalRecordMixin, Base):
    __tablename__ = "preventive_test_results"
    __table_args__ = (
        UniqueConstraint(
            "step_result_id",
            "template_test_id",
            name="uq_preventive_test_results_step_test",
        ),
    )

    legacy_id: Mapped[int | None] = mapped_column(Integer, unique=True)
    step_result_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("preventive_step_results.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    template_test_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("maintenance_template_tests.id"),
        nullable=False,
        index=True,
    )
    name_snapshot: Mapped[str] = mapped_column(String(240), nullable=False)
    selected_result: Mapped[str] = mapped_column(String(240), nullable=False)
    numeric_value: Mapped[str | None] = mapped_column(String(80))
    notes: Mapped[str | None] = mapped_column(Text)


class CorrectiveReportDetailRecord(Base):
    __tablename__ = "corrective_report_details"

    report_version_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("report_versions.id", ondelete="CASCADE"),
        primary_key=True,
    )
    corrective_event_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("corrective_events.id"),
        nullable=False,
        index=True,
    )
    symptom: Mapped[str | None] = mapped_column(Text)
    technical_description: Mapped[str | None] = mapped_column(Text)
    operational_impact: Mapped[str | None] = mapped_column(Text)
    failure_analysis_type: Mapped[str | None] = mapped_column(String(100))
    functional_tests: Mapped[str | None] = mapped_column(Text)
    validation_result: Mapped[str | None] = mapped_column(String(100))
    service_released: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    service_released_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    validation_responsible_snapshot: Mapped[str | None] = mapped_column(String(200))
    technical_status: Mapped[str | None] = mapped_column(String(100))
    conclusion: Mapped[str | None] = mapped_column(Text)
    additional_comments: Mapped[str | None] = mapped_column(Text)
    response_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    corrective_started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    corrective_ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class CorrectiveReportBlockRecord(OperationalRecordMixin, Base):
    __tablename__ = "corrective_report_blocks"
    __table_args__ = (
        UniqueConstraint(
            "report_version_id",
            "sequence",
            name="uq_corrective_report_blocks_sequence",
        ),
    )

    report_version_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("report_versions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    block_type: Mapped[str] = mapped_column(String(60), nullable=False)
    title: Mapped[str] = mapped_column(String(240), nullable=False)
    sequence: Mapped[int] = mapped_column(Integer, nullable=False)
    payload: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict)
    is_visible: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)


class CorrectiveActivityRecord(OperationalRecordMixin, Base):
    __tablename__ = "corrective_activities"
    __table_args__ = (
        UniqueConstraint(
            "report_version_id",
            "sequence",
            name="uq_corrective_activities_version_sequence",
        ),
    )

    legacy_id: Mapped[int | None] = mapped_column(Integer, unique=True)
    report_version_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("report_versions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    maintenance_action_type_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("maintenance_action_types.id"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(240), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    notes: Mapped[str | None] = mapped_column(Text)
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    sequence: Mapped[int] = mapped_column(Integer, nullable=False)


class MaintenanceKnowledgeCommentRecord(OperationalRecordMixin, Base):
    __tablename__ = "maintenance_knowledge_comments"

    scope_type: Mapped[str] = mapped_column(String(40), nullable=False, index=True)
    maintenance_template_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("maintenance_templates.id"),
        index=True,
    )
    equipment_asset_id: Mapped[str | None] = mapped_column(
        String(80),
        ForeignKey("assets.id"),
        index=True,
    )
    author_user_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("users.id"),
        nullable=False,
    )
    message: Mapped[str] = mapped_column(Text, nullable=False)


class CorrectiveEventCommentRecord(OperationalRecordMixin, Base):
    __tablename__ = "corrective_event_comments"

    corrective_event_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("corrective_events.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    author_user_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("users.id"),
        nullable=False,
    )
    message: Mapped[str] = mapped_column(Text, nullable=False)


class CalibrationReportDetailRecord(Base):
    __tablename__ = "calibration_report_details"

    report_version_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("report_versions.id", ondelete="CASCADE"),
        primary_key=True,
    )
    legacy_id: Mapped[int | None] = mapped_column(Integer, unique=True)
    track_circuit_asset_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("assets.id"),
        nullable=False,
        index=True,
    )
    frequency: Mapped[str | None] = mapped_column(String(100))
    calibration_date: Mapped[date] = mapped_column(Date, nullable=False)
    location_snapshot: Mapped[str] = mapped_column(Text, nullable=False)
    track_circuit_type: Mapped[str | None] = mapped_column(String(100))
    track_circuit_number: Mapped[str | None] = mapped_column(String(100))
    jumpers: Mapped[str | None] = mapped_column(String(200))
    rail_current: Mapped[str | None] = mapped_column(String(100))
    tca9: Mapped[str | None] = mapped_column(String(100))


class CalibrationMeasurementRecord(OperationalRecordMixin, Base):
    __tablename__ = "calibration_measurements"
    __table_args__ = (
        UniqueConstraint(
            "report_version_id",
            "asset_id",
            "measurement_name",
            "sequence",
            name="uq_calibration_measurements_asset_name_sequence",
        ),
    )

    report_version_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("report_versions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    asset_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("assets.id"),
        nullable=False,
        index=True,
    )
    asset_role: Mapped[str] = mapped_column(String(30), nullable=False)
    measurement_name: Mapped[str] = mapped_column(String(200), nullable=False)
    measured_value: Mapped[str | None] = mapped_column(String(120))
    unit: Mapped[str | None] = mapped_column(String(40))
    result: Mapped[str | None] = mapped_column(String(120))
    notes: Mapped[str | None] = mapped_column(Text)
    sequence: Mapped[int] = mapped_column(Integer, nullable=False, default=0)


class AttachmentRecord(OperationalRecordMixin, Base):
    __tablename__ = "attachments"

    legacy_id: Mapped[int | None] = mapped_column(Integer, unique=True)
    report_version_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("report_versions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    preventive_step_result_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("preventive_step_results.id"),
        index=True,
    )
    corrective_activity_id: Mapped[UUID | None] = mapped_column(
        Uuid,
        ForeignKey("corrective_activities.id"),
        index=True,
    )
    attachment_type: Mapped[str] = mapped_column(String(30), nullable=False)
    file_reference: Mapped[str] = mapped_column(Text, nullable=False)
    original_file_name: Mapped[str | None] = mapped_column(String(240))
    media_type: Mapped[str | None] = mapped_column(String(120))
    title: Mapped[str | None] = mapped_column(String(240))
    description: Mapped[str | None] = mapped_column(Text)
    captured_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    uploaded_by_user_id: Mapped[str | None] = mapped_column(String(80), ForeignKey("users.id"))
    checksum: Mapped[str | None] = mapped_column(String(64))
    file_size_bytes: Mapped[int | None] = mapped_column(Integer)


class GeneratedReportRecord(OperationalRecordMixin, Base):
    __tablename__ = "generated_reports"

    legacy_id: Mapped[int | None] = mapped_column(Integer, unique=True)
    report_version_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("report_versions.id"),
        nullable=False,
        index=True,
    )
    file_reference: Mapped[str] = mapped_column(Text, nullable=False)
    path: Mapped[str | None] = mapped_column(Text)
    file_name: Mapped[str] = mapped_column(String(240), nullable=False)
    file_format: Mapped[str] = mapped_column(String(20), nullable=False, default="pdf")
    file_size_bytes: Mapped[int | None] = mapped_column(Integer)
    generated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    generated_by_user_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("users.id"),
        nullable=False,
    )
    checksum: Mapped[str | None] = mapped_column(String(64))
    is_regenerated: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
