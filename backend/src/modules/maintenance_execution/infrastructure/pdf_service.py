import base64
import hashlib
import mimetypes
from datetime import datetime, timezone
from pathlib import Path
from uuid import UUID
from zoneinfo import ZoneInfo

from jinja2 import Environment, FileSystemLoader, select_autoescape
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from modules.identity_access.infrastructure.postgres.models import UserRecord
from modules.maintenance_execution.infrastructure.postgres.report_models import (
    GeneratedReportRecord,
    MaintenanceActivityRecord,
    MaintenanceReportRecord,
    ReportSignatureRecord,
    ReportParticipantRecord,
    ReportVersionRecord,
)
from modules.maintenance_execution.infrastructure.postgres.models import (
    CorrectiveEventRecord,
)
from modules.maintenance_execution.infrastructure.postgres.report_writer import (
    PostgresReportWriter,
    ReportValidationError,
)
from modules.maintenance_execution.infrastructure.postgres.tool_models import (
    MaintenanceTemplateToolRecord,
    ReportToolUsageRecord,
)
from modules.maintenance_execution.infrastructure.postgres.template_models import (
    MaintenanceTemplatePersonnelRecord,
    MaintenanceTemplateRecord,
)
from modules.maintenance_execution.interfaces.schemas import (
    GeneratedReportDTO,
    MaintenanceReportVersionDetailDTO,
)
from shared_kernel.storage import resolve_storage_reference, storage_key


class PreventivePDFService:
    """Builds the canonical preventive report and stores it as a version artifact."""

    template_dir = Path(__file__).with_name("pdf_templates")

    def __init__(self, session: AsyncSession):
        self._session = session
        self._writer = PostgresReportWriter(session)
        self._templates = Environment(
            loader=FileSystemLoader(self.template_dir),
            autoescape=select_autoescape(["html", "xml"]),
        )

    async def generate(
        self,
        *,
        version_id: str,
        user_id: str,
    ) -> GeneratedReportDTO:
        try:
            from weasyprint import HTML
        except (ImportError, OSError) as error:
            raise ReportValidationError(
                "El motor de PDF no está disponible. Instala las dependencias nativas de WeasyPrint."
            ) from error

        detail = await self._writer.get_version_detail(version_id)
        if detail is None:
            raise ReportValidationError("La versión del reporte no existe.")
        if detail.document_status != "FINALIZED":
            raise ReportValidationError(
                "Solo se puede generar el PDF de una versión finalizada."
            )
        if detail.report_kind not in {"PREVENTIVE", "PREVENTIVE_MAIN"} or detail.preventive_report is None:
            raise ReportValidationError(
                "La generación disponible en esta versión corresponde a reportes preventivos."
            )

        activity = await self._session.get(MaintenanceActivityRecord, detail.activity.id)
        version = await self._session.get(ReportVersionRecord, version_id)
        if activity is None or version is None:
            raise ReportValidationError("No se encontró el contexto del reporte preventivo.")

        tools = []
        personnel = []
        maintenance_template = None
        if activity.maintenance_template_id is not None:
            maintenance_template = await self._session.get(
                MaintenanceTemplateRecord,
                activity.maintenance_template_id,
            )
            tools = list(
                (
                    await self._session.scalars(
                        select(MaintenanceTemplateToolRecord)
                        .where(
                            MaintenanceTemplateToolRecord.maintenance_template_id
                            == activity.maintenance_template_id
                        )
                        .order_by(MaintenanceTemplateToolRecord.tool_name)
                    )
                ).all()
            )
            personnel = list(
                (
                    await self._session.scalars(
                        select(MaintenanceTemplatePersonnelRecord)
                        .where(
                            MaintenanceTemplatePersonnelRecord.maintenance_template_id
                            == activity.maintenance_template_id
                        )
                        .order_by(MaintenanceTemplatePersonnelRecord.personnel_role)
                    )
                ).all()
            )

        used_tools = list(
            (
                await self._session.scalars(
                    select(ReportToolUsageRecord)
                    .where(ReportToolUsageRecord.report_version_id == version.id)
                    .order_by(ReportToolUsageRecord.tool_name_snapshot)
                )
            ).all()
        )
        if used_tools:
            tools = [
                {
                    "tool_name": tool.tool_name_snapshot or "Herramienta sin nombre",
                    "estimated_hours": None,
                }
                for tool in used_tools
            ]

        photos = await self._photos(detail)
        signatures = await self._signatures(version.id)
        report_code = settings.preventive_report_format_code
        activity_duration = self._duration(
            detail.preventive_report.activity_started_at,
            detail.preventive_report.activity_ended_at,
        )
        context = {
            "report_code": report_code,
            "report_title": detail.activity.title,
            "report_number": detail.activity.internal_code,
            "revision": settings.preventive_report_revision,
            "generated_at": self._format_datetime(datetime.now(timezone.utc)),
            "activity_date": self._format_date(detail.preventive_report.actual_date),
            "activity_time": self._time_range(
                detail.preventive_report.activity_started_at,
                detail.preventive_report.activity_ended_at,
            ),
            "activity_duration": activity_duration,
            "activity": detail.activity,
            "report": detail.preventive_report,
            "participants": [participant for participant in detail.participants if participant.selected],
            "tools": tools,
            "personnel": personnel,
            "maintenance_template": maintenance_template,
            "photos": photos,
            "signatures": signatures,
            "logo_data_uri": self._data_uri(settings.resolved_report_logo),
        }
        template = self._templates.get_template("preventive_report.html")
        rendered_html = template.render(**context)
        pdf_bytes = HTML(
            string=rendered_html,
            base_url=str(self.template_dir),
        ).write_pdf()

        safe_code = self._safe_filename(detail.activity.internal_code)
        file_name = f"{report_code}_{safe_code}_V{detail.version_number}.pdf"
        return await self._persist_pdf(
            version=version,
            file_name=file_name,
            pdf_bytes=pdf_bytes,
            user_id=user_id,
        )

    async def _persist_pdf(
        self,
        *,
        version: ReportVersionRecord,
        file_name: str,
        pdf_bytes: bytes,
        user_id: str,
    ) -> GeneratedReportDTO:
        report_root = settings.resolved_report_root
        report_root.mkdir(parents=True, exist_ok=True)
        output_path = report_root / file_name
        output_path.write_bytes(pdf_bytes)
        stored_path = storage_key(output_path, report_root)

        previous = await self._session.scalar(
            select(GeneratedReportRecord)
            .where(GeneratedReportRecord.report_version_id == version.id)
            .order_by(GeneratedReportRecord.generated_at.desc())
        )
        now = datetime.now(timezone.utc)
        generated = GeneratedReportRecord(
            report_version_id=version.id,
            file_reference=stored_path,
            path=stored_path,
            file_name=file_name,
            file_format="pdf",
            file_size_bytes=len(pdf_bytes),
            generated_at=now,
            generated_by_user_id=user_id,
            checksum=hashlib.sha256(pdf_bytes).hexdigest(),
            is_regenerated=previous is not None,
        )
        self._session.add(generated)
        await self._session.flush()
        return self._dto(generated)

    async def file_path(self, version_id: str) -> tuple[Path, str] | None:
        generated = await self._session.scalar(
            select(GeneratedReportRecord)
            .where(GeneratedReportRecord.report_version_id == version_id)
            .order_by(GeneratedReportRecord.generated_at.desc())
        )
        if generated is None:
            return None
        root = settings.resolved_report_root.resolve()
        candidate = resolve_storage_reference(
            generated.path or generated.file_reference,
            root,
        )
        if candidate is None:
            return None
        return candidate, generated.file_name

    @staticmethod
    def _dto(record: GeneratedReportRecord) -> GeneratedReportDTO:
        return GeneratedReportDTO(
            id=str(record.id),
            report_version_id=str(record.report_version_id),
            file_name=record.file_name,
            file_format=record.file_format,
            file_size_bytes=record.file_size_bytes,
            generated_at=record.generated_at,
            download_path=f"/api/v1/report-versions/{record.report_version_id}/pdf",
        )

    async def _photos(self, detail: MaintenanceReportVersionDetailDTO) -> list[dict[str, str]]:
        photos = []
        for evidence in detail.evidence:
            if not evidence.media_type or not evidence.media_type.startswith("image/"):
                continue
            path = await self._writer.attachment_path(evidence.id)
            if path is None:
                continue
            photos.append(
                {
                    "title": evidence.title or evidence.original_file_name or "Evidencia",
                    "description": evidence.description or "",
                    "data_uri": self._data_uri(path, evidence.media_type),
                }
            )
        return photos

    async def _signatures(self, version_id: UUID) -> list[dict[str, str]]:
        rows = (
            await self._session.execute(
                select(ReportParticipantRecord, ReportSignatureRecord)
                .outerjoin(
                    ReportSignatureRecord,
                    ReportSignatureRecord.report_participant_id == ReportParticipantRecord.id,
                )
                .where(ReportParticipantRecord.report_version_id == version_id)
                .order_by(ReportParticipantRecord.created_at)
            )
        ).all()
        return [
            {
                "participant_id": str(participant.id),
                "name": str(participant.user_id),
                "data_uri": self._signature_data_uri(signature.strokes if signature else []),
            }
            for participant, signature in rows
            if participant.selected and signature is not None
        ]

    @staticmethod
    def _data_uri(path: Path, media_type: str | None = None) -> str:
        if not path.is_file():
            return ""
        resolved_type = media_type or mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        encoded = base64.b64encode(path.read_bytes()).decode("ascii")
        return f"data:{resolved_type};base64,{encoded}"

    @staticmethod
    def _signature_data_uri(strokes: list | None) -> str:
        raw_strokes: list[list[tuple[float, float]]] = []
        for stroke in strokes or []:
            if not stroke:
                continue
            points: list[tuple[float, float]] = []
            for point in stroke:
                if isinstance(point, dict):
                    x, y = point.get("x", 0), point.get("y", 0)
                else:
                    x, y = point["x"], point["y"]
                points.append((float(x), float(y)))
            if points:
                raw_strokes.append(points)

        all_points = [point for stroke in raw_strokes for point in stroke]
        paths: list[str] = []
        if all_points:
            min_x = min(point[0] for point in all_points)
            max_x = max(point[0] for point in all_points)
            min_y = min(point[1] for point in all_points)
            max_y = max(point[1] for point in all_points)
            width = max(max_x - min_x, 1)
            height = max(max_y - min_y, 1)
            padding = 8
            scale = min((260 - 2 * padding) / width, (90 - 2 * padding) / height)
            offset_x = (260 - width * scale) / 2 - min_x * scale
            offset_y = (90 - height * scale) / 2 - min_y * scale
            for stroke in raw_strokes:
                points = " ".join(
                    f"{x * scale + offset_x:.2f},{y * scale + offset_y:.2f}"
                    for x, y in stroke
                )
                paths.append(f'<polyline points="{points}"/>')
        svg = (
            '<svg xmlns="http://www.w3.org/2000/svg" width="260" height="90" '
            'viewBox="0 0 260 90"><g fill="none" stroke="#151515" '
            'stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">'
            + "".join(paths)
            + "</g></svg>"
        )
        return "data:image/svg+xml;base64," + base64.b64encode(svg.encode()).decode("ascii")

    @staticmethod
    def _format_datetime(value: datetime | None) -> str:
        if value is None:
            return "No registrado"
        # Docker images use UTC by default. Reports are operational documents for
        # Lima, therefore their printed date/time must not depend on host settings.
        if value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        return value.astimezone(ZoneInfo("America/Lima")).strftime("%d/%m/%Y %H:%M")

    @staticmethod
    def _time_range(start: datetime | None, end: datetime | None) -> str:
        if start is None:
            return "No registrada"
        local_start = start.astimezone(ZoneInfo("America/Lima"))
        if end is None:
            return local_start.strftime("%H:%M")
        local_end = end.astimezone(ZoneInfo("America/Lima"))
        return f"{local_start.strftime('%H:%M')} - {local_end.strftime('%H:%M')}"

    @staticmethod
    def _duration(start: datetime | None, end: datetime | None) -> str:
        if start is None or end is None:
            return "-"
        total_minutes = max(0, int((end - start).total_seconds() // 60))
        hours, minutes = divmod(total_minutes, 60)
        return f"{hours}:{minutes:02d}"

    @staticmethod
    def _format_date(value: object) -> str:
        if hasattr(value, "strftime"):
            return value.strftime("%d/%m/%Y")
        try:
            return datetime.fromisoformat(str(value)).strftime("%d/%m/%Y")
        except ValueError:
            return str(value)

    @staticmethod
    def _safe_filename(value: str) -> str:
        normalized = "".join(character if character.isalnum() or character in "-_" else "_" for character in value)
        return normalized.strip("_") or "mantenimiento"


class CorrectivePDFService(PreventivePDFService):
    """Builds the corrective report following ML2-STS-FOR-041-ES."""

    async def generate(
        self,
        *,
        version_id: str,
        user_id: str,
    ) -> GeneratedReportDTO:
        try:
            from weasyprint import HTML
        except (ImportError, OSError) as error:
            raise ReportValidationError(
                "El motor de PDF no está disponible. Instala las dependencias nativas de WeasyPrint."
            ) from error

        detail = await self._writer.get_version_detail(version_id)
        if detail is None:
            raise ReportValidationError("La versión del reporte no existe.")
        if detail.document_status != "FINALIZED":
            raise ReportValidationError(
                "Solo se puede generar el PDF de una versión finalizada."
            )
        if detail.report_kind != "CORRECTIVE" or detail.corrective_report is None:
            raise ReportValidationError(
                "La versión seleccionada no corresponde a un reporte correctivo."
            )

        version = await self._session.get(ReportVersionRecord, version_id)
        if version is None:
            raise ReportValidationError("No se encontró la versión del reporte correctivo.")
        creator = await self._session.get(UserRecord, version.created_by_user_id)
        report = detail.corrective_report
        generated_at = datetime.now(ZoneInfo("America/Lima"))
        maintenance_report = await self._session.get(
            MaintenanceReportRecord,
            version.maintenance_report_id,
        )
        number_year = (
            maintenance_report.report_year
            if maintenance_report and maintenance_report.report_year
            else generated_at.year
        )
        report_code = settings.corrective_report_format_code
        photos = await self._photos(detail)
        signatures = await self._signatures(version.id)
        event = await self._session.get(CorrectiveEventRecord, detail.activity.event_id)
        context = {
            "report_code": report_code,
            "revision": settings.corrective_report_revision,
            "report_number": (
                f"{detail.report_number:04d}/{number_year % 100:02d}"
            ),
            "report_date": generated_at.strftime("%d/%m/%Y"),
            "generated_at": self._format_datetime(generated_at),
            "activity": detail.activity,
            "report": report,
            "participants": [
                participant
                for participant in detail.participants
                if participant.selected
            ],
            "signatures": signatures,
            "photos": photos,
            "creator_name": creator.name if creator else version.created_by_user_id,
            "critical_element": "Sí" if event is not None and event.is_critical else "No",
            "logo_data_uri": self._data_uri(settings.resolved_report_logo),
            "format_datetime": self._format_datetime,
        }
        template = self._templates.get_template("corrective_report.html")
        rendered_html = template.render(**context)
        pdf_bytes = HTML(
            string=rendered_html,
            base_url=str(self.template_dir),
        ).write_pdf()

        safe_code = self._safe_filename(
            report.sap_notification or detail.activity.internal_code
        )
        file_name = (
            f"{report_code}_{safe_code}_V{detail.version_number}.pdf"
        )
        return await self._persist_pdf(
            version=version,
            file_name=file_name,
            pdf_bytes=pdf_bytes,
            user_id=user_id,
        )


class CalibrationPDFService(PreventivePDFService):
    """Builds the track-circuit calibration sheet as an independent artifact."""

    async def generate(
        self,
        *,
        version_id: str,
        user_id: str,
    ) -> GeneratedReportDTO:
        try:
            from weasyprint import HTML
        except (ImportError, OSError) as error:
            raise ReportValidationError(
                "El motor de PDF no está disponible. Instala las dependencias nativas de WeasyPrint."
            ) from error

        detail = await self._writer.get_version_detail(version_id)
        if detail is None:
            raise ReportValidationError("La versión del reporte no existe.")
        if detail.document_status != "FINALIZED":
            raise ReportValidationError(
                "Solo se puede generar el PDF de una versión finalizada."
            )
        if detail.report_kind != "CALIBRATION" or detail.calibration_report is None:
            raise ReportValidationError(
                "La versión seleccionada no corresponde a una calibración."
            )

        version = await self._session.get(ReportVersionRecord, version_id)
        if version is None:
            raise ReportValidationError(
                "No se encontró la versión del reporte de calibración."
            )
        maintenance_report = await self._session.get(
            MaintenanceReportRecord,
            version.maintenance_report_id,
        )
        if maintenance_report is None:
            raise ReportValidationError(
                "No se encontró el reporte asociado a la calibración."
            )
        participant_version_id = await self._writer.participant_version_id(
            maintenance_report,
            version,
        )
        signatures = await self._signatures(participant_version_id)
        context = {
            "activity": detail.activity,
            "report": detail.calibration_report,
            "participants": detail.participants,
            "signatures": signatures,
        }
        rendered_html = self._templates.get_template(
            "calibration_report.html"
        ).render(**context)
        pdf_bytes = HTML(
            string=rendered_html,
            base_url=str(self.template_dir),
        ).write_pdf()

        safe_asset = self._safe_filename(
            detail.calibration_report.track_circuit_name
        )
        file_name = (
            f"{settings.calibration_report_file_prefix}_"
            f"{safe_asset}_V{detail.version_number}.pdf"
        )
        return await self._persist_pdf(
            version=version,
            file_name=file_name,
            pdf_bytes=pdf_bytes,
            user_id=user_id,
        )
