import base64
import binascii
import hashlib
import unicodedata
from datetime import datetime, timezone
from pathlib import Path
from uuid import UUID
from zoneinfo import ZoneInfo

from sqlalchemy import delete, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import PROJECT_ROOT, settings
from modules.asset_management.infrastructure.postgres.catalog_models import (
    AssetStatusRecord,
    ManufacturerRecord,
)
from modules.asset_management.infrastructure.postgres.domain_models import (
    AssetAssignmentRecord,
    AssetClosureRecord,
    AssetReplacementRecord,
    InventoryLocationRecord,
)
from modules.asset_management.infrastructure.postgres.models import AssetRecord
from modules.identity_access.infrastructure.postgres.models import UserRecord
from modules.maintenance_execution.infrastructure.postgres.catalog_models import (
    MaintenanceActionTypeRecord,
)
from modules.maintenance_execution.infrastructure.postgres.models import (
    CorrectiveEventRecord,
)
from modules.maintenance_execution.infrastructure.postgres.report_models import (
    AttachmentRecord,
    CalibrationMeasurementRecord,
    CalibrationReportDetailRecord,
    CorrectiveActivityRecord,
    CorrectiveEventCommentRecord,
    CorrectiveReportBlockRecord,
    CorrectiveReportDetailRecord,
    GeneratedReportRecord,
    MaintenanceActivityAssetRecord,
    MaintenanceActivityRecord,
    MaintenanceKnowledgeCommentRecord,
    MaintenanceReportRecord,
    PreventiveReportDetailRecord,
    PreventiveStepResultRecord,
    PreventiveTestResultRecord,
    ReportParticipantRecord,
    ReportSignatureRecord,
    ReportVersionAssetRecord,
    ReportVersionRecord,
)
from modules.maintenance_execution.infrastructure.postgres.template_models import (
    MaintenanceTemplateRecord,
    MaintenanceTemplateStepRecord,
    MaintenanceTemplateTestOptionRecord,
    MaintenanceTemplateTestRecord,
)
from modules.maintenance_execution.interfaces.schemas import (
    CalibrationReportWriteDTO,
    CorrectiveReportWriteDTO,
    MaintenanceCommentDTO,
    PreventiveReportWriteDTO,
    PreventiveGuideDTO,
    PreventiveHistoryReportDTO,
    PreventiveTemplateStepDTO,
    PreventiveTemplateTestDTO,
    ReportDraftWriteRequest,
    ReportEditorAssetDTO,
    ReportEditorActionTypeDTO,
    ReportEditorDTO,
    ReportEditorUserDTO,
    ReportEvidenceDTO,
    ReportEvidenceWriteDTO,
    ReportParticipantDTO,
    ReportParticipantWriteDTO,
    ReportWriteResultDTO,
    GeneratedReportDTO,
    MaintenanceReportVersionDetailDTO,
    SignaturePointDTO,
)
from modules.organizational_context.infrastructure.postgres.models import (
    ProjectRecord,
    SubsystemRecord,
)
from shared_kernel.schemas import MaintenanceStatus

SIGNALING_MAINTENANCE_WORK_AREA_ID = UUID(
    "006a0fb0-8fae-5ec6-88cb-4231d96d172a"
)


class ReportWriteError(Exception):
    pass


class ReportValidationError(ReportWriteError):
    pass


class ReportNotEditableError(ReportWriteError):
    pass


class PostgresReportWriter:
    def __init__(self, session: AsyncSession):
        self._session = session

    async def get_version_detail(
        self,
        version_id: str,
    ) -> MaintenanceReportVersionDetailDTO | None:
        """Return the immutable, read-only view used by report preview/PDF generation."""
        row = (
            await self._session.execute(
                select(MaintenanceReportRecord, ReportVersionRecord)
                .join(
                    ReportVersionRecord,
                    ReportVersionRecord.maintenance_report_id == MaintenanceReportRecord.id,
                )
                .where(ReportVersionRecord.id == version_id)
            )
        ).one_or_none()
        if row is None:
            return None

        report, version = row
        from modules.maintenance_execution.infrastructure.postgres.repository import (
            PostgresMaintenanceRepository,
        )

        repository = PostgresMaintenanceRepository(self._session)
        activity = await repository.get_activity(str(report.maintenance_activity_id))
        if activity is None:
            return None

        generated = await self._session.scalar(
            select(GeneratedReportRecord)
            .where(GeneratedReportRecord.report_version_id == version.id)
            .order_by(GeneratedReportRecord.generated_at.desc())
        )
        generated_dto = None
        generated_path = None
        report_root = settings.resolved_report_root.resolve()
        if generated is not None:
            generated_path = Path(generated.path or generated.file_reference)
            if not generated_path.is_absolute():
                generated_path = PROJECT_ROOT / generated_path
            generated_path = generated_path.resolve()
        if (
            generated is not None
            and generated_path is not None
            and report_root in generated_path.parents
            and generated_path.is_file()
        ):
            generated_dto = GeneratedReportDTO(
                id=str(generated.id),
                report_version_id=str(generated.report_version_id),
                file_name=generated.file_name,
                file_format=generated.file_format,
                file_size_bytes=generated.file_size_bytes,
                generated_at=generated.generated_at,
                download_path=f"/api/v1/report-versions/{version.id}/pdf",
            )

        participant_version_id = await self.participant_version_id(report, version)
        return MaintenanceReportVersionDetailDTO(
            id=str(version.id),
            report_kind=report.report_kind,
            report_number=report.report_number,
            version_number=version.version_number,
            document_status=version.document_status,
            summary=version.summary,
            created_at=version.created_at,
            finalized_at=version.finalized_at,
            activity=activity,
            preventive_report=(
                await repository._get_preventive_report(str(version.id))
                if report.report_kind in {"PREVENTIVE", "PREVENTIVE_MAIN"}
                else None
            ),
            corrective_report=(
                await repository._get_corrective_report(str(version.id))
                if report.report_kind == "CORRECTIVE"
                else None
            ),
            calibration_report=(
                await repository._get_calibration_report(str(version.id))
                if report.report_kind == "CALIBRATION"
                else None
            ),
            participants=await self._participants(
                participant_version_id,
                selected_only=True,
            ),
            evidence=await self._evidence(version.id),
            generated_report=generated_dto,
        )

    async def participant_version_id(
        self,
        report: MaintenanceReportRecord,
        version: ReportVersionRecord,
    ) -> UUID:
        """Resolve the participant source for imported companion calibrations."""
        has_participants = await self._session.scalar(
            select(ReportParticipantRecord.id)
            .where(ReportParticipantRecord.report_version_id == version.id)
            .limit(1)
        )
        if report.report_kind != "CALIBRATION" or has_participants is not None:
            return version.id

        main_version = await self._session.scalar(
            select(ReportVersionRecord)
            .join(
                MaintenanceReportRecord,
                MaintenanceReportRecord.id
                == ReportVersionRecord.maintenance_report_id,
            )
            .where(
                MaintenanceReportRecord.maintenance_activity_id
                == report.maintenance_activity_id,
                MaintenanceReportRecord.report_kind.in_(
                    {"PREVENTIVE", "PREVENTIVE_MAIN"}
                ),
            )
            .order_by(
                (
                    ReportVersionRecord.version_number
                    == version.version_number
                ).desc(),
                ReportVersionRecord.version_number.desc(),
            )
            .limit(1)
        )
        return main_version.id if main_version is not None else version.id

    async def get_editor(self, activity_id: str) -> ReportEditorDTO | None:
        activity = await self._session.get(MaintenanceActivityRecord, activity_id)
        if activity is None:
            return None

        version = await self._latest_version(
            activity.id,
            report_kinds=self._main_report_kinds(activity),
        )
        calibration_version = await self._latest_version(
            activity.id,
            report_kinds={"CALIBRATION"},
        )
        preventive_draft = None
        corrective_draft = None
        calibration_draft = None
        if version and version.data_snapshot:
            if activity.activity_type == "PREVENTIVE":
                preventive_draft = PreventiveReportWriteDTO.model_validate(
                    version.data_snapshot
                )
            else:
                corrective_draft = CorrectiveReportWriteDTO.model_validate(
                    version.data_snapshot
                )
        if calibration_version and calibration_version.data_snapshot:
            calibration_draft = CalibrationReportWriteDTO.model_validate(
                calibration_version.data_snapshot
            )
        track_circuit_asset = await self._track_circuit_asset(activity)
        participants = await self._participants(version.id) if version else []
        evidence = await self._evidence(version.id) if version else []
        comments = await self.list_comments(activity)
        return ReportEditorDTO(
            activity_id=str(activity.id),
            activity_type=activity.activity_type,
            status=MaintenanceStatus(activity.status),
            actual_date=(activity.actual_start_at or datetime.now(timezone.utc)).date(),
            activity_started_at=activity.actual_start_at or datetime.now(timezone.utc),
            activity_ended_at=activity.actual_end_at,
            report_version_id=str(version.id) if version else None,
            document_status=version.document_status if version else None,
            preventive_draft=preventive_draft,
            corrective_draft=corrective_draft,
            calibration_required=track_circuit_asset is not None,
            calibration_draft=calibration_draft,
            template_steps=await self._template_steps(activity),
            available_participants=await self._available_participants(),
            action_types=[
                ReportEditorActionTypeDTO(code=record.code, name=record.name)
                for record in (
                    await self._session.scalars(
                        select(MaintenanceActionTypeRecord)
                        .where(MaintenanceActionTypeRecord.is_active.is_(True))
                        .order_by(MaintenanceActionTypeRecord.name)
                    )
                ).all()
            ],
            equipment_assets=await self._equipment_assets(activity),
            stock_assets=await self._stock_assets(),
            inventory_locations=list(
                (
                    await self._session.scalars(
                        select(InventoryLocationRecord.name).order_by(
                            InventoryLocationRecord.name
                        )
                    )
                ).all()
            ),
            participants=participants,
            evidence=evidence,
            comments=comments,
        )

    async def get_preventive_guide(
        self,
        activity_id: str,
        previous_reports_limit: int = 10,
        previous_reports_offset: int = 0,
    ) -> PreventiveGuideDTO | None:
        activity = await self._session.get(MaintenanceActivityRecord, activity_id)
        if activity is None or activity.activity_type != "PREVENTIVE":
            return None

        template_name = None
        if activity.maintenance_template_id is not None:
            template = await self._session.get(
                MaintenanceTemplateRecord,
                activity.maintenance_template_id,
            )
            if template is not None:
                template_name = (
                    template.activity_n3_summary
                    or template.activity_n2
                    or template.activity_n1
                    or template.report_code
                )

        previous_reports, previous_reports_has_more = await self._previous_preventive_reports(
            activity,
            limit=previous_reports_limit,
            offset=previous_reports_offset,
        )

        return PreventiveGuideDTO(
            activity_id=str(activity.id),
            template_name=template_name,
            template_steps=await self._template_steps(activity),
            previous_reports=previous_reports,
            previous_reports_has_more=previous_reports_has_more,
            previous_reports_offset=previous_reports_offset,
        )

    async def save(
        self,
        *,
        activity_id: str,
        payload: ReportDraftWriteRequest,
        user_id: str,
        finalize: bool,
    ) -> ReportWriteResultDTO:
        activity = await self._session.get(
            MaintenanceActivityRecord,
            activity_id,
            with_for_update=True,
        )
        if activity is None:
            raise ReportValidationError("El mantenimiento no existe.")
        if activity.status != MaintenanceStatus.IN_PROGRESS.value:
            raise ReportNotEditableError(
                "Los reportes solo se pueden editar mientras el mantenimiento está en progreso."
            )

        current_version = await self._latest_version(
            activity.id,
            report_kinds=self._main_report_kinds(activity),
        )
        self._validate_base_version(payload, current_version)
        report_payload = self._payload_for_activity(activity, payload)
        track_circuit_asset = await self._track_circuit_asset(activity)
        if payload.calibration is not None and track_circuit_asset is None:
            raise ReportValidationError(
                "La calibración solo está disponible para mantenimientos de circuito de vía."
            )
        if finalize:
            self._validate_final(report_payload)
            if track_circuit_asset is not None:
                if payload.calibration is None:
                    raise ReportValidationError(
                        "El reporte de calibración es obligatorio para este circuito de vía."
                    )
                self._validate_calibration(payload.calibration)

        report, version = await self._draft_version(activity, user_id)
        evidence_version_ids = [version.id]
        if version.source_version_id is not None:
            evidence_version_ids.append(version.source_version_id)
        existing_evidence = {
            str(record.id): record
            for record in (
                await self._session.scalars(
                    select(AttachmentRecord).where(
                        AttachmentRecord.report_version_id.in_(
                            evidence_version_ids
                        )
                    )
                )
            ).all()
        }
        await self._clear_version_children(version.id)
        version.data_snapshot = report_payload.model_dump(mode="json")
        version.summary = self._summary(report_payload)
        version.stop_after_block_order = getattr(
            report_payload,
            "stop_after_block_order",
            None,
        )

        await self._snapshot_assets(activity, version)
        if isinstance(report_payload, PreventiveReportWriteDTO):
            activity_ended_at = report_payload.activity_ended_at
            await self._save_preventive(activity, version, report_payload)
        else:
            activity_ended_at = report_payload.corrective_ended_at
            await self._save_corrective(activity, version, report_payload)

        await self._save_participants(version, report_payload.participants)
        await self._save_evidence(
            version,
            report_payload.evidence,
            user_id,
            existing_evidence,
        )
        calibration_version = None
        if payload.calibration is not None and track_circuit_asset is not None:
            calibration_version = await self._save_calibration_companion(
                activity=activity,
                track_circuit_asset=track_circuit_asset,
                payload=payload.calibration,
                participants=report_payload.participants,
                user_id=user_id,
                finalize=finalize,
            )

        now = datetime.now(timezone.utc)
        if finalize:
            version.document_status = "FINALIZED"
            version.finalized_by_user_id = user_id
            version.finalized_at = now
            report.status = "FINALIZED"
            activity.actual_end_at = activity_ended_at or now
        else:
            version.document_status = "DRAFT"
            version.finalized_by_user_id = None
            version.finalized_at = None
            report.status = "DRAFT"

        await self._session.flush()
        return ReportWriteResultDTO(
            report_id=str(report.id),
            version_id=str(version.id),
            version_number=version.version_number,
            document_status=version.document_status,
            saved_at=now,
            calibration_version_id=(
                str(calibration_version.id) if calibration_version else None
            ),
        )

    async def list_comments(
        self,
        activity: MaintenanceActivityRecord,
    ) -> list[MaintenanceCommentDTO]:
        if activity.activity_type == "PREVENTIVE":
            equipment_ids = (
                await self._session.scalars(
                    select(MaintenanceActivityAssetRecord.asset_id).where(
                        MaintenanceActivityAssetRecord.maintenance_activity_id
                        == activity.id
                    )
                )
            ).all()
            scopes = []
            if activity.maintenance_template_id is not None:
                scopes.append(
                    MaintenanceKnowledgeCommentRecord.maintenance_template_id
                    == activity.maintenance_template_id
                )
            if equipment_ids:
                scopes.append(
                    MaintenanceKnowledgeCommentRecord.equipment_asset_id.in_(
                        equipment_ids
                    )
                )
            if not scopes:
                return []
            stmt = (
                select(MaintenanceKnowledgeCommentRecord, UserRecord)
                .join(
                    UserRecord,
                    UserRecord.id
                    == MaintenanceKnowledgeCommentRecord.author_user_id,
                )
                .where(or_(*scopes))
                .order_by(MaintenanceKnowledgeCommentRecord.created_at)
            )
            rows = (await self._session.execute(stmt)).all()
            return [
                self._comment_dto(record, user, "PREVENTIVE_KNOWLEDGE")
                for record, user in rows
            ]

        event = await self._event_for_activity(activity.id)
        if event is None:
            return []
        rows = (
            await self._session.execute(
                select(CorrectiveEventCommentRecord, UserRecord)
                .join(
                    UserRecord,
                    UserRecord.id == CorrectiveEventCommentRecord.author_user_id,
                )
                .where(CorrectiveEventCommentRecord.corrective_event_id == event.id)
                .order_by(CorrectiveEventCommentRecord.created_at)
            )
        ).all()
        return [
            self._comment_dto(record, user, "CORRECTIVE_EVENT")
            for record, user in rows
        ]

    async def add_comment(
        self,
        *,
        activity_id: str,
        user_id: str,
        message: str,
    ) -> MaintenanceCommentDTO:
        activity = await self._session.get(MaintenanceActivityRecord, activity_id)
        user = await self._session.get(UserRecord, user_id)
        if activity is None or user is None:
            raise ReportValidationError("No se encontró el mantenimiento o usuario.")

        if activity.activity_type == "PREVENTIVE":
            equipment_id = await self._session.scalar(
                select(MaintenanceActivityAssetRecord.asset_id)
                .where(
                    MaintenanceActivityAssetRecord.maintenance_activity_id
                    == activity.id
                )
                .limit(1)
            )
            if activity.maintenance_template_id is None and equipment_id is None:
                raise ReportValidationError(
                    "El preventivo no tiene plantilla ni equipo para definir el alcance del comentario."
                )
            record = MaintenanceKnowledgeCommentRecord(
                scope_type=(
                    "TEMPLATE_EQUIPMENT"
                    if activity.maintenance_template_id and equipment_id
                    else "TEMPLATE"
                    if activity.maintenance_template_id
                    else "EQUIPMENT"
                ),
                maintenance_template_id=activity.maintenance_template_id,
                equipment_asset_id=equipment_id,
                author_user_id=user_id,
                message=message,
            )
            scope = "PREVENTIVE_KNOWLEDGE"
        else:
            event = await self._event_for_activity(activity.id)
            if event is None:
                raise ReportValidationError(
                    "El mantenimiento correctivo no tiene un evento relacionado."
                )
            record = CorrectiveEventCommentRecord(
                corrective_event_id=event.id,
                author_user_id=user_id,
                message=message,
            )
            scope = "CORRECTIVE_EVENT"

        self._session.add(record)
        await self._session.flush()
        return self._comment_dto(record, user, scope)

    async def attachment_path(self, attachment_id: str) -> Path | None:
        attachment = await self._session.get(AttachmentRecord, attachment_id)
        if attachment is None:
            return None
        path = Path(attachment.file_reference).resolve()
        root = settings.resolved_attachment_root.resolve()
        if root not in path.parents or not path.is_file():
            return None
        return path

    @staticmethod
    def _validate_base_version(
        payload: ReportDraftWriteRequest,
        current_version: ReportVersionRecord | None,
    ) -> None:
        if not payload.enforce_base_version:
            return
        current_id = str(current_version.id) if current_version else None
        if payload.base_report_version_id != current_id:
            raise ReportNotEditableError(
                "El reporte cambió en el servidor mientras este borrador estaba offline. "
                "Ábrelo nuevamente para revisar ambas versiones antes de sincronizar."
            )

    @staticmethod
    def _payload_for_activity(
        activity: MaintenanceActivityRecord,
        payload: ReportDraftWriteRequest,
    ) -> PreventiveReportWriteDTO | CorrectiveReportWriteDTO:
        if activity.activity_type == "PREVENTIVE" and payload.preventive is not None:
            return payload.preventive
        if activity.activity_type == "CORRECTIVE" and payload.corrective is not None:
            return payload.corrective
        raise ReportValidationError(
            "El contenido del reporte no corresponde al tipo de mantenimiento."
        )

    @staticmethod
    def _validate_final(
        payload: PreventiveReportWriteDTO | CorrectiveReportWriteDTO,
    ) -> None:
        signed = [
            participant
            for participant in payload.participants
            if participant.selected
            and (
                participant.signature_strokes
                or participant.signature_image_base64
            )
        ]
        if not signed:
            raise ReportValidationError(
                "Se necesita al menos un participante seleccionado con firma."
            )
        if isinstance(payload, PreventiveReportWriteDTO):
            if not payload.final_result:
                raise ReportValidationError(
                    "El estado final del equipo es obligatorio."
                )
            if not payload.steps:
                raise ReportValidationError(
                    "El reporte preventivo debe contener pasos."
                )
        else:
            if not payload.symptom or not payload.technical_status:
                raise ReportValidationError(
                    "El síntoma y el estado técnico son obligatorios."
                )
            if not payload.activities:
                raise ReportValidationError(
                    "El reporte correctivo debe contener al menos una actividad."
                )
            for activity in payload.activities:
                if activity.replacement and (
                    not activity.replacement.removed_asset_id
                    or not activity.replacement.installed_asset_id
                ):
                    raise ReportValidationError(
                        "El cambio de componente requiere activo retirado y repuesto."
                    )

    @staticmethod
    def _validate_calibration(payload: CalibrationReportWriteDTO) -> None:
        if not payload.frequency.strip():
            raise ReportValidationError(
                "La frecuencia del circuito de vía es obligatoria."
            )
        if not payload.transmitter_jumpers.strip():
            raise ReportValidationError(
                "Los jumpers del transmisor son obligatorios."
            )
        if not payload.receivers:
            raise ReportValidationError(
                "La calibración requiere al menos un receptor."
            )
        for receiver in payload.receivers:
            if not all(
                (
                    receiver.jumpers.strip(),
                    receiver.tca9.strip(),
                    receiver.rail_current.strip(),
                )
            ):
                raise ReportValidationError(
                    f"Completa jumpers, TCA9 y corriente de riel del receptor {receiver.sequence}."
                )

    async def _draft_version(
        self,
        activity: MaintenanceActivityRecord,
        user_id: str,
        report_kind: str | None = None,
    ) -> tuple[MaintenanceReportRecord, ReportVersionRecord]:
        report_kinds = (
            {report_kind}
            if report_kind is not None
            else self._main_report_kinds(activity)
        )
        report = await self._session.scalar(
            select(MaintenanceReportRecord)
            .where(
                MaintenanceReportRecord.maintenance_activity_id == activity.id,
                MaintenanceReportRecord.report_kind.in_(report_kinds),
            )
            .order_by(MaintenanceReportRecord.report_number.desc())
            .limit(1)
        )
        if report is None:
            report_year = None
            report_number = 1
            effective_report_kind = report_kind or activity.activity_type
            if effective_report_kind == "CORRECTIVE":
                reference_at = (
                    activity.actual_start_at
                    or activity.scheduled_start_at
                    or datetime.now(timezone.utc)
                )
                report_year = reference_at.astimezone(
                    ZoneInfo("America/Lima")
                ).year
                await self._session.execute(
                    select(func.pg_advisory_xact_lock(2_026_000 + report_year))
                )
                latest_number = await self._session.scalar(
                    select(func.max(MaintenanceReportRecord.report_number)).where(
                        MaintenanceReportRecord.report_kind == "CORRECTIVE",
                        MaintenanceReportRecord.report_year == report_year,
                    )
                )
                report_number = (latest_number or 0) + 1
            report = MaintenanceReportRecord(
                maintenance_activity_id=activity.id,
                report_kind=effective_report_kind,
                report_year=report_year,
                report_number=report_number,
                shift_label=activity.shift,
                status="DRAFT",
                created_by_user_id=user_id,
            )
            self._session.add(report)
            await self._session.flush()

        version = await self._session.scalar(
            select(ReportVersionRecord)
            .where(
                ReportVersionRecord.maintenance_report_id == report.id,
                ReportVersionRecord.document_status == "DRAFT",
            )
            .order_by(ReportVersionRecord.version_number.desc())
            .limit(1)
        )
        if version is not None:
            return report, version

        latest = await self._session.scalar(
            select(ReportVersionRecord)
            .where(ReportVersionRecord.maintenance_report_id == report.id)
            .order_by(ReportVersionRecord.version_number.desc())
            .limit(1)
        )
        version = ReportVersionRecord(
            maintenance_report_id=report.id,
            version_number=(latest.version_number + 1) if latest else 1,
            document_status="DRAFT",
            source_version_id=latest.id if latest else None,
            created_by_user_id=user_id,
        )
        self._session.add(version)
        await self._session.flush()
        return report, version

    async def _clear_version_children(self, version_id: UUID) -> None:
        step_ids = (
            await self._session.scalars(
                select(PreventiveStepResultRecord.id).where(
                    PreventiveStepResultRecord.report_version_id == version_id
                )
            )
        ).all()
        participant_ids = (
            await self._session.scalars(
                select(ReportParticipantRecord.id).where(
                    ReportParticipantRecord.report_version_id == version_id
                )
            )
        ).all()
        if step_ids:
            await self._session.execute(
                delete(PreventiveTestResultRecord).where(
                    PreventiveTestResultRecord.step_result_id.in_(step_ids)
                )
            )
        if participant_ids:
            await self._session.execute(
                delete(ReportSignatureRecord).where(
                    ReportSignatureRecord.report_participant_id.in_(participant_ids)
                )
            )
        for model in (
            AttachmentRecord,
            CalibrationMeasurementRecord,
            CorrectiveReportBlockRecord,
            CorrectiveActivityRecord,
            PreventiveStepResultRecord,
            ReportParticipantRecord,
            ReportVersionAssetRecord,
        ):
            await self._session.execute(
                delete(model).where(model.report_version_id == version_id)
            )
        await self._session.execute(
            delete(PreventiveReportDetailRecord).where(
                PreventiveReportDetailRecord.report_version_id == version_id
            )
        )
        await self._session.execute(
            delete(CorrectiveReportDetailRecord).where(
                CorrectiveReportDetailRecord.report_version_id == version_id
            )
        )
        await self._session.execute(
            delete(CalibrationReportDetailRecord).where(
                CalibrationReportDetailRecord.report_version_id == version_id
            )
        )

    async def _save_preventive(
        self,
        activity: MaintenanceActivityRecord,
        version: ReportVersionRecord,
        payload: PreventiveReportWriteDTO,
    ) -> None:
        project = await self._session.get(ProjectRecord, activity.project_id)
        subsystem = await self._session.get(SubsystemRecord, activity.subsystem_id)
        if (
            project is None
            or project.site_id is None
            or activity.primary_stage_id is None
            or subsystem is None
            or subsystem.system_id is None
        ):
            raise ReportValidationError(
                "El mantenimiento no tiene sede, etapa, sistema o subsistema completos."
            )
        started_at = activity.actual_start_at or datetime.now(timezone.utc)
        self._session.add(
            PreventiveReportDetailRecord(
                report_version_id=version.id,
                site_id=project.site_id,
                project_id=activity.project_id,
                stage_id=activity.primary_stage_id,
                system_id=subsystem.system_id,
                subsystem_id=activity.subsystem_id,
                geographic_location_id=activity.geographic_location_id,
                location_path_snapshot=activity.location_path_snapshot
                or "Ubicación no registrada",
                actual_date=started_at.date(),
                activity_started_at=started_at,
                activity_ended_at=payload.activity_ended_at,
                final_result=payload.final_result,
                additional_comments=payload.additional_comments,
            )
        )
        for step in payload.steps:
            step_record = PreventiveStepResultRecord(
                report_version_id=version.id,
                template_step_id=UUID(step.template_step_id),
                is_completed=step.is_completed,
                comment=step.comment,
                manual_page_snapshot=step.manual_page,
                sequence_snapshot=step.sequence,
                title_snapshot=step.title,
            )
            self._session.add(step_record)
            await self._session.flush()
            for test in step.tests:
                self._session.add(
                    PreventiveTestResultRecord(
                        step_result_id=step_record.id,
                        template_test_id=UUID(test.template_test_id),
                        name_snapshot=test.name,
                        selected_result=test.selected_result,
                        numeric_value=test.numeric_value,
                        notes=test.notes,
                    )
                )

    async def _save_calibration_companion(
        self,
        *,
        activity: MaintenanceActivityRecord,
        track_circuit_asset: AssetRecord,
        payload: CalibrationReportWriteDTO,
        participants: list[ReportParticipantWriteDTO],
        user_id: str,
        finalize: bool,
    ) -> ReportVersionRecord:
        report, version = await self._draft_version(
            activity,
            user_id,
            report_kind="CALIBRATION",
        )
        await self._clear_version_children(version.id)
        version.data_snapshot = payload.model_dump(mode="json")
        version.summary = f"Calibración de {track_circuit_asset.name}"
        await self._snapshot_assets(activity, version)

        calibration_at = activity.actual_start_at or datetime.now(timezone.utc)
        self._session.add(
            CalibrationReportDetailRecord(
                report_version_id=version.id,
                legacy_id=None,
                track_circuit_asset_id=track_circuit_asset.id,
                frequency=payload.frequency.strip() or None,
                calibration_date=calibration_at.astimezone(
                    ZoneInfo("America/Lima")
                ).date(),
                location_snapshot=activity.location_path_snapshot
                or "Ubicación no registrada",
                track_circuit_type=track_circuit_asset.asset_type,
                track_circuit_number=track_circuit_asset.name,
                jumpers=payload.transmitter_jumpers.strip() or None,
                rail_current=None,
                tca9=None,
            )
        )
        self._session.add(
            CalibrationMeasurementRecord(
                report_version_id=version.id,
                asset_id=track_circuit_asset.id,
                asset_role="TRANSMITTER",
                measurement_name="Jumpers",
                measured_value=payload.transmitter_jumpers.strip() or None,
                unit=None,
                result=None,
                notes=None,
                sequence=10,
            )
        )
        for receiver in payload.receivers:
            role = f"RECEIVER_{receiver.sequence}"
            for offset, (name, value, unit) in enumerate(
                (
                    ("Jumpers", receiver.jumpers, None),
                    ("TCA9", receiver.tca9, None),
                    ("Corriente de riel", receiver.rail_current, "mA"),
                ),
                start=1,
            ):
                self._session.add(
                    CalibrationMeasurementRecord(
                        report_version_id=version.id,
                        asset_id=track_circuit_asset.id,
                        asset_role=role,
                        measurement_name=name,
                        measured_value=value.strip() or None,
                        unit=unit,
                        result=None,
                        notes=None,
                        sequence=receiver.sequence * 10 + offset,
                    )
                )
        await self._save_participants(version, participants)

        now = datetime.now(timezone.utc)
        if finalize:
            version.document_status = "FINALIZED"
            version.finalized_by_user_id = user_id
            version.finalized_at = now
            report.status = "FINALIZED"
        else:
            version.document_status = "DRAFT"
            version.finalized_by_user_id = None
            version.finalized_at = None
            report.status = "DRAFT"
        await self._session.flush()
        return version

    async def _save_corrective(
        self,
        activity: MaintenanceActivityRecord,
        version: ReportVersionRecord,
        payload: CorrectiveReportWriteDTO,
    ) -> None:
        event = await self._event_for_activity(activity.id)
        if event is None:
            raise ReportValidationError(
                "El mantenimiento correctivo no tiene un evento relacionado."
            )
        self._session.add(
            CorrectiveReportDetailRecord(
                report_version_id=version.id,
                corrective_event_id=event.id,
                symptom=payload.symptom,
                technical_description=payload.technical_description,
                operational_impact=payload.operational_impact,
                failure_analysis_type=payload.failure_analysis_type,
                functional_tests=payload.functional_tests,
                validation_result=payload.validation_result,
                service_released=payload.service_released,
                service_released_at=payload.service_released_at,
                validation_responsible_snapshot=payload.validation_responsible,
                technical_status=payload.technical_status,
                conclusion=payload.conclusion,
                additional_comments=payload.additional_comments,
                response_at=self._parse_datetime(event.response_at),
                corrective_started_at=activity.actual_start_at,
                corrective_ended_at=payload.corrective_ended_at,
            )
        )
        for sequence, item in enumerate(payload.activities, start=1):
            action_type = await self._session.scalar(
                select(MaintenanceActionTypeRecord).where(
                    MaintenanceActionTypeRecord.code == item.action_type_code
                )
            )
            if action_type is None:
                raise ReportValidationError(
                    f"Tipo de actividad desconocido: {item.action_type_code}."
                )
            activity_record = CorrectiveActivityRecord(
                report_version_id=version.id,
                maintenance_action_type_id=action_type.id,
                name=item.name,
                description=item.description,
                notes=None,
                started_at=item.started_at,
                ended_at=item.ended_at,
                sequence=sequence,
            )
            self._session.add(activity_record)
            await self._session.flush()
            if item.replacement:
                parent_snapshot = await self._replacement_asset_snapshot(
                    item.replacement.parent_asset_id
                )
                removed_snapshot = await self._replacement_asset_snapshot(
                    item.replacement.removed_asset_id,
                    part_number=item.replacement.removed_part_number,
                    serial_number=item.replacement.removed_serial_number,
                    model=item.replacement.removed_model,
                    manufacturer=item.replacement.removed_manufacturer,
                )
                installed_snapshot = await self._replacement_asset_snapshot(
                    item.replacement.installed_asset_id,
                    part_number=item.replacement.installed_part_number,
                    serial_number=item.replacement.installed_serial_number,
                    model=item.replacement.installed_model,
                    manufacturer=item.replacement.installed_manufacturer,
                )
                self._session.add(
                    CorrectiveReportBlockRecord(
                        report_version_id=version.id,
                        block_type="COMPONENT_REPLACEMENT",
                        title="Cambio de componente",
                        sequence=sequence,
                        payload={
                            "client_id": item.client_id,
                            "corrective_activity_id": str(activity_record.id),
                            **item.replacement.model_dump(mode="json"),
                            "parent_asset_snapshot": parent_snapshot,
                            "removed_asset_snapshot": removed_snapshot,
                            "installed_asset_snapshot": installed_snapshot,
                        },
                        is_visible=True,
                    )
                )

    async def _replacement_asset_snapshot(
        self,
        asset_id: str,
        *,
        part_number: str | None = None,
        serial_number: str | None = None,
        model: str | None = None,
        manufacturer: str | None = None,
    ) -> dict:
        asset = await self._session.get(AssetRecord, asset_id)
        if asset is None:
            return {"name": asset_id}
        manufacturer_record = (
            await self._session.get(ManufacturerRecord, asset.manufacturer_id)
            if asset.manufacturer_id
            else None
        )
        return {
            "name": asset.name,
            "path": asset.current_position or asset.physical_location,
            "part_number": part_number or asset.part_number,
            "serial_number": serial_number or asset.serial_number,
            "model": model or asset.model,
            "manufacturer": (
                manufacturer
                or (manufacturer_record.name if manufacturer_record else None)
            ),
        }

    async def _save_participants(
        self,
        version: ReportVersionRecord,
        participants: list[ReportParticipantWriteDTO],
    ) -> None:
        for item in participants:
            user = await self._session.get(UserRecord, item.user_id)
            if (
                user is None
                or not user.is_active
                or user.work_area_id != SIGNALING_MAINTENANCE_WORK_AREA_ID
            ):
                raise ReportValidationError(
                    f"Participante no válido: {item.user_id}."
                )
            participant = ReportParticipantRecord(
                report_version_id=version.id,
                user_id=user.id,
                role_snapshot=user.role_label,
                selected=item.selected,
            )
            self._session.add(participant)
            await self._session.flush()
            if item.signature_strokes or item.signature_image_base64:
                image_data = (
                    self._decode_base64(
                        item.signature_image_base64,
                        maximum_bytes=2_000_000,
                    )
                    if item.signature_image_base64
                    else None
                )
                checksum_source = image_data or repr(
                    item.model_dump(mode="json")["signature_strokes"]
                ).encode()
                self._session.add(
                    ReportSignatureRecord(
                        report_participant_id=participant.id,
                        signed_at=datetime.now(timezone.utc),
                        strokes=[
                            [point.model_dump() for point in stroke]
                            for stroke in item.signature_strokes
                        ],
                        image_data=image_data,
                        checksum=hashlib.sha256(checksum_source).hexdigest(),
                    )
                )

    async def apply_finalized_component_replacements(
        self,
        *,
        activity_id: str,
        user_id: str,
    ) -> None:
        version = await self._session.scalar(
            select(ReportVersionRecord)
            .join(
                MaintenanceReportRecord,
                MaintenanceReportRecord.id
                == ReportVersionRecord.maintenance_report_id,
            )
            .where(
                MaintenanceReportRecord.maintenance_activity_id == activity_id,
                MaintenanceReportRecord.report_kind == "CORRECTIVE",
                ReportVersionRecord.document_status == "FINALIZED",
            )
            .order_by(
                ReportVersionRecord.version_number.desc(),
                ReportVersionRecord.created_at.desc(),
            )
            .limit(1)
        )
        if version is None:
            return
        activity = await self._session.get(MaintenanceActivityRecord, activity_id)
        if activity is None:
            raise ReportValidationError("No se encontró la actividad correctiva.")
        payload = CorrectiveReportWriteDTO.model_validate(version.data_snapshot)
        await self._apply_component_replacements(
            activity=activity,
            version=version,
            payload=payload,
            user_id=user_id,
        )

    async def _apply_component_replacements(
        self,
        *,
        activity: MaintenanceActivityRecord,
        version: ReportVersionRecord,
        payload: CorrectiveReportWriteDTO,
        user_id: str,
    ) -> None:
        replacement_items = [
            (sequence, item, item.replacement)
            for sequence, item in enumerate(payload.activities, start=1)
            if item.replacement is not None
        ]
        if not replacement_items:
            return

        for sequence, item, replacement in replacement_items:
            assert replacement is not None
            removed = await self._session.get(
                AssetRecord,
                replacement.removed_asset_id,
                with_for_update=True,
            )
            installed = await self._session.get(
                AssetRecord,
                replacement.installed_asset_id,
                with_for_update=True,
            )
            parent = await self._session.get(
                AssetRecord,
                replacement.parent_asset_id,
                with_for_update=True,
            )
            if removed is None or installed is None or parent is None:
                raise ReportValidationError(
                    "No se encontró el activo padre, retirado o de reposición."
                )
            await self._fill_missing_asset_metadata(
                removed,
                part_number=replacement.removed_part_number,
                serial_number=replacement.removed_serial_number,
                model=replacement.removed_model,
                manufacturer=replacement.removed_manufacturer,
            )
            await self._fill_missing_asset_metadata(
                installed,
                part_number=replacement.installed_part_number,
                serial_number=replacement.installed_serial_number,
                model=replacement.installed_model,
                manufacturer=replacement.installed_manufacturer,
            )
            already_applied = await self._session.scalar(
                select(AssetReplacementRecord.id)
                .where(
                    AssetReplacementRecord.maintenance_activity_id == activity.id,
                    AssetReplacementRecord.removed_asset_id == removed.id,
                    AssetReplacementRecord.installed_asset_id == installed.id,
                )
                .limit(1)
            )
            if already_applied is not None:
                continue
            if removed.id == installed.id:
                raise ReportValidationError(
                    "El componente retirado y el instalado deben ser distintos."
                )
            active_removed_assignment = await self._active_assignment(removed.id)
            if (
                active_removed_assignment is None
                or active_removed_assignment.parent_asset_id != parent.id
            ):
                raise ReportValidationError(
                    f"{removed.name} ya no está instalado en {parent.name}."
                )
            if await self._session.scalar(
                select(AssetClosureRecord.descendant_asset_id).where(
                    AssetClosureRecord.ancestor_asset_id == removed.id,
                    AssetClosureRecord.depth > 0,
                ).limit(1)
            ):
                raise ReportValidationError(
                    "El componente retirado contiene activos hijos y no puede reemplazarse como una unidad."
                )
            active_installed_assignment = await self._active_assignment(installed.id)
            if (
                installed.status != "EN STOCK"
                or (
                    active_installed_assignment is not None
                    and active_installed_assignment.parent_asset_id is not None
                )
            ):
                raise ReportValidationError(
                    f"{installed.name} ya no está disponible en stock."
                )
            source_location = (
                await self._session.get(
                    InventoryLocationRecord,
                    installed.current_inventory_location_id,
                )
                if installed.current_inventory_location_id
                else None
            )
            if (
                source_location is not None
                and source_location.name.casefold()
                != replacement.source_description.casefold()
            ):
                raise ReportValidationError(
                    f"{installed.name} ya no está en {replacement.source_description}."
                )

            destination = await self._session.scalar(
                select(InventoryLocationRecord).where(
                    func.lower(InventoryLocationRecord.name)
                    == replacement.destination_description.casefold()
                )
            )
            removed_status_code = (
                "INOPERATIVO"
                if (replacement.removed_condition or "").casefold()
                == "inoperativo"
                else "EN_STOCK"
            )
            removed_status = await self._session.scalar(
                select(AssetStatusRecord).where(
                    AssetStatusRecord.code == removed_status_code
                )
            )
            installed_status = await self._session.scalar(
                select(AssetStatusRecord).where(
                    AssetStatusRecord.code == "OPERATIVO"
                )
            )
            now = item.ended_at or datetime.now(timezone.utc)
            active_removed_assignment.unassigned_at = now
            if active_installed_assignment is not None:
                active_installed_assignment.unassigned_at = now

            corrective_activity = await self._session.scalar(
                select(CorrectiveActivityRecord)
                .where(
                    CorrectiveActivityRecord.report_version_id == version.id,
                    CorrectiveActivityRecord.sequence == sequence,
                )
                .limit(1)
            )
            if corrective_activity is None:
                raise ReportValidationError(
                    "No se encontró la actividad correctiva del reemplazo."
                )

            removed.parent_id = None
            removed.current_slot_location_id = None
            removed.current_inventory_location_id = (
                destination.id if destination else None
            )
            removed.current_position = replacement.destination_description
            removed.status = removed_status.name if removed_status else removed_status_code
            removed.status_id = removed_status.id if removed_status else None

            installed.parent_id = parent.id
            installed.current_slot_location_id = active_removed_assignment.slot_location_id
            installed.current_geographic_location_id = (
                active_removed_assignment.geographic_location_id
            )
            installed.current_inventory_location_id = None
            installed.current_position = active_removed_assignment.position_snapshot
            installed.status = (
                installed_status.name if installed_status else "OPERATIVO"
            )
            installed.status_id = (
                installed_status.id if installed_status else installed.status_id
            )
            parent.children = [
                installed.id if child_id == removed.id else child_id
                for child_id in (parent.children or [])
            ]
            if installed.id not in parent.children:
                parent.children.append(installed.id)

            self._session.add(
                AssetAssignmentRecord(
                    asset_id=removed.id,
                    parent_asset_id=None,
                    slot_location_id=None,
                    geographic_location_id=None,
                    position_snapshot=replacement.destination_description,
                    assigned_at=now,
                    reason="Retiro por cambio de componente",
                    source_report_version_id=version.id,
                )
            )
            self._session.add(
                AssetAssignmentRecord(
                    asset_id=installed.id,
                    parent_asset_id=parent.id,
                    slot_location_id=active_removed_assignment.slot_location_id,
                    geographic_location_id=active_removed_assignment.geographic_location_id,
                    position_snapshot=active_removed_assignment.position_snapshot,
                    assigned_at=now,
                    reason="Instalación por cambio de componente",
                    source_report_version_id=version.id,
                )
            )
            self._session.add(
                AssetReplacementRecord(
                    removed_asset_id=removed.id,
                    installed_asset_id=installed.id,
                    parent_asset_id=parent.id,
                    slot_location_id=active_removed_assignment.slot_location_id,
                    position_snapshot=active_removed_assignment.position_snapshot
                    or removed.current_position
                    or removed.name,
                    source_description=replacement.source_description,
                    destination_description=replacement.destination_description,
                    replaced_at=now,
                    responsible_user_id=user_id,
                    maintenance_activity_id=activity.id,
                    report_version_id=version.id,
                    corrective_activity_id=corrective_activity.id,
                    removed_condition=replacement.removed_condition,
                    installed_condition=replacement.installed_condition,
                    reason=replacement.reason,
                )
            )
            await self._replace_closure_links(
                removed_id=removed.id,
                installed_id=installed.id,
                parent_id=parent.id,
            )

    async def _fill_missing_asset_metadata(
        self,
        asset: AssetRecord,
        *,
        part_number: str | None,
        serial_number: str | None,
        model: str | None,
        manufacturer: str | None,
    ) -> None:
        if not asset.part_number and part_number and part_number.strip():
            asset.part_number = part_number.strip()
        if not asset.serial_number and serial_number and serial_number.strip():
            normalized_serial = serial_number.strip()
            duplicate = await self._session.scalar(
                select(AssetRecord.id)
                .where(
                    AssetRecord.serial_number == normalized_serial,
                    AssetRecord.id != asset.id,
                )
                .limit(1)
            )
            if duplicate is not None:
                raise ReportValidationError(
                    f"El serial {normalized_serial} ya pertenece a otro asset."
                )
            asset.serial_number = normalized_serial
            asset.serial_number_status = "REGISTERED"
        if not asset.model and model and model.strip():
            asset.model = model.strip()
        if (
            asset.manufacturer_id is None
            and manufacturer
            and manufacturer.strip()
        ):
            normalized_manufacturer = manufacturer.strip()
            manufacturer_record = await self._session.scalar(
                select(ManufacturerRecord)
                .where(
                    func.lower(ManufacturerRecord.name)
                    == normalized_manufacturer.casefold()
                )
                .limit(1)
            )
            if manufacturer_record is None:
                manufacturer_record = ManufacturerRecord(
                    name=normalized_manufacturer,
                    description="Registrado durante mantenimiento correctivo",
                    is_active=True,
                )
                self._session.add(manufacturer_record)
                await self._session.flush()
            asset.manufacturer_id = manufacturer_record.id

    async def _active_assignment(
        self,
        asset_id: str,
    ) -> AssetAssignmentRecord | None:
        return await self._session.scalar(
            select(AssetAssignmentRecord)
            .where(
                AssetAssignmentRecord.asset_id == asset_id,
                AssetAssignmentRecord.unassigned_at.is_(None),
            )
            .order_by(AssetAssignmentRecord.assigned_at.desc())
            .limit(1)
            .with_for_update()
        )

    async def _replace_closure_links(
        self,
        *,
        removed_id: str,
        installed_id: str,
        parent_id: str,
    ) -> None:
        ancestors = (
            await self._session.execute(
                select(
                    AssetClosureRecord.ancestor_asset_id,
                    AssetClosureRecord.depth,
                ).where(
                    AssetClosureRecord.descendant_asset_id == parent_id
                )
            )
        ).all()
        await self._session.execute(
            delete(AssetClosureRecord).where(
                AssetClosureRecord.descendant_asset_id.in_(
                    [removed_id, installed_id]
                )
            )
        )
        self._session.add_all(
            [
                AssetClosureRecord(
                    ancestor_asset_id=removed_id,
                    descendant_asset_id=removed_id,
                    depth=0,
                ),
                AssetClosureRecord(
                    ancestor_asset_id=installed_id,
                    descendant_asset_id=installed_id,
                    depth=0,
                ),
                *[
                    AssetClosureRecord(
                        ancestor_asset_id=ancestor_id,
                        descendant_asset_id=installed_id,
                        depth=depth + 1,
                    )
                    for ancestor_id, depth in ancestors
                ],
            ]
        )

    async def _save_evidence(
        self,
        version: ReportVersionRecord,
        evidence: list[ReportEvidenceWriteDTO],
        user_id: str,
        existing_evidence: dict[str, AttachmentRecord],
    ) -> None:
        root = settings.resolved_attachment_root
        root.mkdir(parents=True, exist_ok=True)
        corrective_blocks = (
            await self._session.scalars(
                select(CorrectiveReportBlockRecord).where(
                    CorrectiveReportBlockRecord.report_version_id == version.id
                )
            )
        ).all()
        corrective_activity_by_client = {
            block.payload.get("client_id"): UUID(
                block.payload["corrective_activity_id"]
            )
            for block in corrective_blocks
            if block.payload.get("client_id")
            and block.payload.get("corrective_activity_id")
        }
        for item in evidence:
            preventive_step_result_id = None
            if item.preventive_step_id:
                preventive_step_result_id = await self._session.scalar(
                    select(PreventiveStepResultRecord.id).where(
                        PreventiveStepResultRecord.report_version_id == version.id,
                        PreventiveStepResultRecord.template_step_id
                        == UUID(item.preventive_step_id),
                    )
                )
            corrective_activity_id = (
                corrective_activity_by_client.get(
                    item.corrective_activity_client_id
                )
                if item.corrective_activity_client_id
                else None
            )
            existing = (
                existing_evidence.get(item.attachment_id)
                if item.attachment_id
                else None
            )
            if existing is not None and item.content_base64 is None:
                self._session.add(
                    AttachmentRecord(
                        report_version_id=version.id,
                        preventive_step_result_id=preventive_step_result_id,
                        corrective_activity_id=corrective_activity_id,
                        attachment_type=existing.attachment_type,
                        file_reference=existing.file_reference,
                        original_file_name=existing.original_file_name,
                        media_type=existing.media_type,
                        title=item.title or existing.title,
                        description=item.description or existing.description,
                        captured_at=existing.captured_at,
                        uploaded_by_user_id=existing.uploaded_by_user_id,
                        checksum=existing.checksum,
                        file_size_bytes=existing.file_size_bytes,
                    )
                )
                continue
            if item.content_base64 is None:
                raise ReportValidationError(
                    f"La evidencia {item.original_file_name} no contiene archivo."
                )
            content = self._decode_base64(
                item.content_base64,
                maximum_bytes=settings.attachment_max_bytes,
            )
            suffix = Path(item.original_file_name).suffix.lower()[:12]
            checksum = hashlib.sha256(content).hexdigest()
            target = root / f"{version.id}-{item.client_id}-{checksum[:12]}{suffix}"
            target.write_bytes(content)
            self._session.add(
                AttachmentRecord(
                    report_version_id=version.id,
                    preventive_step_result_id=preventive_step_result_id,
                    corrective_activity_id=corrective_activity_id,
                    attachment_type=(
                        "IMAGE" if item.media_type.startswith("image/") else "DOCUMENT"
                    ),
                    file_reference=str(target),
                    original_file_name=Path(item.original_file_name).name,
                    media_type=item.media_type,
                    title=item.title,
                    description=item.description,
                    captured_at=item.captured_at,
                    uploaded_by_user_id=user_id,
                    checksum=checksum,
                    file_size_bytes=len(content),
                )
            )

    async def _snapshot_assets(
        self,
        activity: MaintenanceActivityRecord,
        version: ReportVersionRecord,
    ) -> None:
        rows = (
            await self._session.execute(
                select(MaintenanceActivityAssetRecord, AssetRecord)
                .join(
                    AssetRecord,
                    AssetRecord.id == MaintenanceActivityAssetRecord.asset_id,
                )
                .where(
                    MaintenanceActivityAssetRecord.maintenance_activity_id
                    == activity.id
                )
            )
        ).all()
        for link, asset in rows:
            self._session.add(
                ReportVersionAssetRecord(
                    report_version_id=version.id,
                    asset_id=asset.id,
                    role=link.role,
                    snapshot_name=asset.name,
                    snapshot_internal_code=asset.internal_code
                    or asset.serial_or_code
                    or asset.id,
                    snapshot_path=activity.location_path_snapshot,
                    snapshot_part_number=asset.part_number,
                    snapshot_serial_number=asset.serial_number,
                )
            )

    async def _latest_version(
        self,
        activity_id: UUID,
        *,
        report_kinds: set[str],
    ) -> ReportVersionRecord | None:
        return await self._session.scalar(
            select(ReportVersionRecord)
            .join(
                MaintenanceReportRecord,
                MaintenanceReportRecord.id
                == ReportVersionRecord.maintenance_report_id,
            )
            .where(
                MaintenanceReportRecord.maintenance_activity_id == activity_id,
                MaintenanceReportRecord.report_kind.in_(report_kinds),
            )
            .order_by(
                (ReportVersionRecord.document_status == "DRAFT").desc(),
                ReportVersionRecord.version_number.desc(),
            )
            .limit(1)
        )

    @staticmethod
    def _main_report_kinds(
        activity: MaintenanceActivityRecord,
    ) -> set[str]:
        if activity.activity_type == "PREVENTIVE":
            return {"PREVENTIVE", "PREVENTIVE_MAIN"}
        return {activity.activity_type}

    async def _track_circuit_asset(
        self,
        activity: MaintenanceActivityRecord,
    ) -> AssetRecord | None:
        if activity.activity_type != "PREVENTIVE":
            return None
        assets = (
            await self._session.scalars(
                select(AssetRecord)
                .join(
                    MaintenanceActivityAssetRecord,
                    MaintenanceActivityAssetRecord.asset_id == AssetRecord.id,
                )
                .where(
                    MaintenanceActivityAssetRecord.maintenance_activity_id
                    == activity.id
                )
                .order_by(AssetRecord.name)
            )
        ).all()

        def normalized(value: str | None) -> str:
            return "".join(
                character
                for character in unicodedata.normalize("NFKD", value or "")
                if not unicodedata.combining(character)
            ).casefold()

        for asset in assets:
            searchable = " ".join(
                normalized(value)
                for value in (
                    asset.name,
                    asset.category,
                    asset.asset_type,
                    activity.title,
                )
            )
            if "circuito de via" in searchable or "cbdac" in searchable:
                return asset
        return None

    async def _template_steps(
        self,
        activity: MaintenanceActivityRecord,
    ) -> list[PreventiveTemplateStepDTO]:
        if (
            activity.activity_type != "PREVENTIVE"
            or activity.maintenance_template_id is None
        ):
            return []
        steps = (
            await self._session.scalars(
                select(MaintenanceTemplateStepRecord)
                .where(
                    MaintenanceTemplateStepRecord.maintenance_template_id
                    == activity.maintenance_template_id
                )
                .order_by(MaintenanceTemplateStepRecord.sequence)
            )
        ).all()
        tests = (
            await self._session.scalars(
                select(MaintenanceTemplateTestRecord)
                .where(
                    MaintenanceTemplateTestRecord.maintenance_template_id
                    == activity.maintenance_template_id
                )
                .order_by(MaintenanceTemplateTestRecord.sequence)
            )
        ).all()
        options = (
            await self._session.scalars(
                select(MaintenanceTemplateTestOptionRecord)
                .where(
                    MaintenanceTemplateTestOptionRecord.template_test_id.in_(
                        [test.id for test in tests]
                    )
                )
                .order_by(MaintenanceTemplateTestOptionRecord.sequence)
            )
        ).all() if tests else []
        tests_by_step: dict[UUID, list[PreventiveTemplateTestDTO]] = {}
        options_by_test: dict[UUID, list] = {}
        for option in options:
            options_by_test.setdefault(option.template_test_id, []).append(option)
        for test in tests:
            test_options = options_by_test.get(test.id, [])
            values = [option.value for option in test_options]
            default = next(
                (option.value for option in test_options if option.is_default),
                values[0] if values else "",
            )
            tests_by_step.setdefault(test.template_step_id, []).append(
                PreventiveTemplateTestDTO(
                    id=str(test.id),
                    name=test.name,
                    result_options=values,
                    default_result=default,
                )
            )
        return [
            PreventiveTemplateStepDTO(
                id=str(step.id),
                title=step.title,
                manual_page=step.manual_page,
                sequence=step.sequence,
                default_comment=step.default_comment,
                tests=tests_by_step.get(step.id, []),
            )
            for step in steps
        ]

    async def _previous_preventive_reports(
        self,
        activity: MaintenanceActivityRecord,
        *,
        limit: int,
        offset: int,
    ) -> tuple[list[PreventiveHistoryReportDTO], bool]:
        if activity.maintenance_template_id is None:
            return [], False

        linked_assets = (
            await self._session.execute(
                select(
                    MaintenanceActivityAssetRecord.asset_id,
                    AssetRecord.name,
                    AssetRecord.is_business_anchor,
                )
                .join(
                    AssetRecord,
                    AssetRecord.id == MaintenanceActivityAssetRecord.asset_id,
                )
                .where(
                    MaintenanceActivityAssetRecord.maintenance_activity_id
                    == activity.id
                )
            )
        ).all()
        anchor_ids = [asset_id for asset_id, _, is_anchor in linked_assets if is_anchor]
        if not anchor_ids:
            return [], False

        previous_activities = (
            await self._session.scalars(
                select(MaintenanceActivityRecord)
                .where(
                    MaintenanceActivityRecord.id != activity.id,
                    MaintenanceActivityRecord.activity_type == "PREVENTIVE",
                    MaintenanceActivityRecord.maintenance_template_id
                    == activity.maintenance_template_id,
                    MaintenanceActivityRecord.status.in_(["COMPLETED", "CLOSED"]),
                    select(MaintenanceActivityAssetRecord.id)
                    .where(
                        MaintenanceActivityAssetRecord.maintenance_activity_id
                        == MaintenanceActivityRecord.id,
                        MaintenanceActivityAssetRecord.asset_id.in_(anchor_ids),
                    )
                    .exists(),
                    select(MaintenanceReportRecord.id)
                    .where(
                        MaintenanceReportRecord.maintenance_activity_id
                        == MaintenanceActivityRecord.id,
                        MaintenanceReportRecord.report_kind.in_(
                            ["PREVENTIVE", "PREVENTIVE_MAIN"]
                        ),
                        select(ReportVersionRecord.id)
                        .where(
                            ReportVersionRecord.maintenance_report_id
                            == MaintenanceReportRecord.id,
                            ReportVersionRecord.document_status == "FINALIZED",
                        )
                        .exists(),
                    )
                    .exists(),
                )
                .order_by(
                    func.coalesce(
                        MaintenanceActivityRecord.completed_at,
                        MaintenanceActivityRecord.actual_end_at,
                        MaintenanceActivityRecord.scheduled_start_at,
                        MaintenanceActivityRecord.created_at,
                    ).desc()
                )
                .limit(limit + 1)
                .offset(offset)
            )
        ).all()
        if not previous_activities:
            return [], False

        has_more = len(previous_activities) > limit
        previous_activities = previous_activities[:limit]

        previous_by_id = {record.id: record for record in previous_activities}
        version_rows = (
            await self._session.execute(
                select(
                    MaintenanceReportRecord,
                    ReportVersionRecord,
                    PreventiveReportDetailRecord.final_result,
                )
                .join(
                    ReportVersionRecord,
                    ReportVersionRecord.maintenance_report_id
                    == MaintenanceReportRecord.id,
                )
                .outerjoin(
                    PreventiveReportDetailRecord,
                    PreventiveReportDetailRecord.report_version_id
                    == ReportVersionRecord.id,
                )
                .where(
                    MaintenanceReportRecord.maintenance_activity_id.in_(
                        previous_by_id
                    ),
                    MaintenanceReportRecord.report_kind.in_(
                        ["PREVENTIVE", "PREVENTIVE_MAIN"]
                    ),
                    ReportVersionRecord.document_status == "FINALIZED",
                )
                .order_by(
                    MaintenanceReportRecord.maintenance_activity_id,
                    ReportVersionRecord.finalized_at.desc().nullslast(),
                    ReportVersionRecord.version_number.desc(),
                )
            )
        ).all()

        latest_by_activity: dict[
            UUID,
            tuple[MaintenanceReportRecord, ReportVersionRecord, str | None],
        ] = {}
        for report, version, final_result in version_rows:
            latest_by_activity.setdefault(
                report.maintenance_activity_id,
                (report, version, final_result),
            )
        if not latest_by_activity:
            return [], has_more

        equipment_rows = (
            await self._session.execute(
                select(
                    MaintenanceActivityAssetRecord.maintenance_activity_id,
                    AssetRecord.name,
                )
                .join(
                    AssetRecord,
                    AssetRecord.id == MaintenanceActivityAssetRecord.asset_id,
                )
                .where(
                    MaintenanceActivityAssetRecord.maintenance_activity_id.in_(
                        latest_by_activity
                    ),
                    AssetRecord.is_business_anchor.is_(True),
                )
                .order_by(AssetRecord.name)
            )
        ).all()
        equipment_by_activity: dict[UUID, list[str]] = {}
        for previous_activity_id, equipment_name in equipment_rows:
            names = equipment_by_activity.setdefault(previous_activity_id, [])
            if equipment_name not in names:
                names.append(equipment_name)

        history: list[PreventiveHistoryReportDTO] = []
        for previous_activity in previous_activities:
            latest = latest_by_activity.get(previous_activity.id)
            if latest is None:
                continue
            _, version, final_result = latest
            performed_at = (
                version.finalized_at
                or previous_activity.completed_at
                or previous_activity.actual_end_at
                or previous_activity.scheduled_start_at
                or previous_activity.created_at
            )
            history.append(
                PreventiveHistoryReportDTO(
                    activity_id=str(previous_activity.id),
                    version_id=str(version.id),
                    title=previous_activity.title,
                    internal_code=previous_activity.internal_code,
                    equipment_names=equipment_by_activity.get(
                        previous_activity.id,
                        [],
                    ),
                    performed_at=performed_at,
                    final_result=final_result,
                    version_number=version.version_number,
                    document_status=version.document_status,
                )
            )
        return history, has_more

    async def _available_participants(self) -> list[ReportEditorUserDTO]:
        users = (
            await self._session.scalars(
                select(UserRecord)
                .where(
                    UserRecord.is_active.is_(True),
                    UserRecord.work_area_id
                    == SIGNALING_MAINTENANCE_WORK_AREA_ID,
                    UserRecord.role.in_(
                        ["MAINTENANCE_ENGINEER", "COORDINATOR", "ADMINISTRATOR"]
                    ),
                )
                .order_by(UserRecord.name)
            )
        ).all()
        return [
            ReportEditorUserDTO(id=user.id, name=user.name, role=user.role_label)
            for user in users
        ]

    async def _equipment_assets(
        self,
        activity: MaintenanceActivityRecord,
    ) -> list[ReportEditorAssetDTO]:
        root_ids = (
            await self._session.scalars(
                select(MaintenanceActivityAssetRecord.asset_id).where(
                    MaintenanceActivityAssetRecord.maintenance_activity_id
                    == activity.id
                )
            )
        ).all()
        if not root_ids:
            return []
        assets = (
            await self._session.scalars(
                select(AssetRecord)
                .distinct()
                .join(
                    AssetClosureRecord,
                    AssetClosureRecord.descendant_asset_id == AssetRecord.id,
                )
                .where(AssetClosureRecord.ancestor_asset_id.in_(root_ids))
                .order_by(AssetRecord.name)
            )
        ).all()
        return [await self._asset_dto(asset) for asset in assets]

    async def _stock_assets(self) -> list[ReportEditorAssetDTO]:
        assets = (
            await self._session.scalars(
                select(AssetRecord)
                .where(AssetRecord.status == "EN STOCK")
                .order_by(AssetRecord.name)
                .limit(500)
            )
        ).all()
        return [await self._asset_dto(asset) for asset in assets]

    async def _asset_dto(self, asset: AssetRecord) -> ReportEditorAssetDTO:
        manufacturer = (
            await self._session.get(ManufacturerRecord, asset.manufacturer_id)
            if asset.manufacturer_id
            else None
        )
        inventory_location = (
            await self._session.get(
                InventoryLocationRecord,
                asset.current_inventory_location_id,
            )
            if asset.current_inventory_location_id
            else None
        )
        return ReportEditorAssetDTO(
            id=asset.id,
            name=asset.name,
            path=(
                inventory_location.name
                if inventory_location
                else asset.current_position or asset.name
            ),
            parent_id=asset.parent_id,
            part_number=asset.part_number,
            serial_number=asset.serial_number,
            model=asset.model,
            manufacturer=manufacturer.name if manufacturer else None,
            status=asset.status,
        )

    async def _participants(
        self,
        version_id: UUID,
        *,
        selected_only: bool = False,
    ) -> list[ReportParticipantDTO]:
        statement = (
            select(
                ReportParticipantRecord,
                UserRecord,
                ReportSignatureRecord,
            )
            .join(
                UserRecord,
                UserRecord.id == ReportParticipantRecord.user_id,
            )
            .outerjoin(
                ReportSignatureRecord,
                ReportSignatureRecord.report_participant_id
                == ReportParticipantRecord.id,
            )
            .where(ReportParticipantRecord.report_version_id == version_id)
            .order_by(UserRecord.name)
        )
        if selected_only:
            statement = statement.where(
                ReportParticipantRecord.selected.is_(True)
            )
        rows = (
            await self._session.execute(
                statement
            )
        ).all()
        return [
            ReportParticipantDTO(
                id=str(participant.id),
                user_id=user.id,
                name=user.name,
                role=participant.role_snapshot,
                selected=participant.selected,
                signed_at=signature.signed_at if signature else None,
                signature_strokes=[
                    [SignaturePointDTO(**point) for point in stroke]
                    for stroke in (signature.strokes or [])
                ]
                if signature
                else [],
            )
            for participant, user, signature in rows
        ]

    async def _evidence(self, version_id: UUID) -> list[ReportEvidenceDTO]:
        records = (
            await self._session.scalars(
                select(AttachmentRecord)
                .where(AttachmentRecord.report_version_id == version_id)
                .order_by(AttachmentRecord.captured_at)
            )
        ).all()
        return [
            ReportEvidenceDTO(
                id=str(record.id),
                original_file_name=record.original_file_name,
                media_type=record.media_type,
                title=record.title,
                description=record.description,
                captured_at=record.captured_at,
                content_path=f"/api/v1/attachments/{record.id}/content",
            )
            for record in records
        ]

    async def _event_for_activity(
        self,
        activity_id: UUID,
    ) -> CorrectiveEventRecord | None:
        return await self._session.scalar(
            select(CorrectiveEventRecord).where(
                CorrectiveEventRecord.maintenance_activity_id == activity_id
            )
        )

    @staticmethod
    def _summary(
        payload: PreventiveReportWriteDTO | CorrectiveReportWriteDTO,
    ) -> str:
        if isinstance(payload, PreventiveReportWriteDTO):
            return payload.final_result or "Borrador preventivo"
        return payload.technical_status or payload.symptom or "Borrador correctivo"

    @staticmethod
    def _decode_base64(value: str, *, maximum_bytes: int) -> bytes:
        try:
            content = base64.b64decode(value, validate=True)
        except (ValueError, binascii.Error) as error:
            raise ReportValidationError(
                "Una firma o evidencia contiene Base64 inválido."
            ) from error
        if len(content) > maximum_bytes:
            raise ReportValidationError(
                f"El archivo supera el máximo permitido de {maximum_bytes} bytes."
            )
        return content

    @staticmethod
    def _parse_datetime(value: str | datetime | None) -> datetime | None:
        if value is None or isinstance(value, datetime):
            return value
        try:
            return datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return None

    @staticmethod
    def _comment_dto(record, user: UserRecord, scope: str) -> MaintenanceCommentDTO:
        return MaintenanceCommentDTO(
            id=str(record.id),
            scope=scope,
            author_user_id=user.id,
            author_name=user.name,
            author_role=user.role_label,
            message=record.message,
            created_at=record.created_at,
        )
