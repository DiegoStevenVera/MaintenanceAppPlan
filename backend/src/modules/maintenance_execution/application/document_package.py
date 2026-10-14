from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from modules.maintenance_execution.infrastructure.pdf_service import (
    CalibrationPDFService,
    PreventivePDFService,
)
from modules.maintenance_execution.infrastructure.postgres.report_models import (
    MaintenanceReportRecord,
    ReportVersionRecord,
)
from modules.maintenance_execution.infrastructure.postgres.report_writer import (
    PostgresReportWriter,
    ReportValidationError,
)
from modules.maintenance_execution.interfaces.schemas import (
    ReportDocumentPackageDTO,
    ReportDocumentPackageItemDTO,
)


class ReportDocumentPackageService:
    """Coordinates the finalized preventive and companion calibration documents."""

    _supported_kinds = {"PREVENTIVE", "PREVENTIVE_MAIN", "CALIBRATION"}

    def __init__(self, session: AsyncSession):
        self._session = session
        self._writer = PostgresReportWriter(session)

    async def get(self, activity_id: str) -> ReportDocumentPackageDTO:
        versions = await self._latest_versions(activity_id)
        if not versions:
            raise ReportValidationError(
                "El mantenimiento todavía no tiene un reporte preventivo."
            )

        documents: list[ReportDocumentPackageItemDTO] = []
        for report_kind, version in versions:
            detail = await self._writer.get_version_detail(str(version.id))
            if detail is None:
                raise ReportValidationError(
                    "No se pudo recuperar una versión del paquete documental."
                )
            documents.append(
                ReportDocumentPackageItemDTO(
                    version_id=str(version.id),
                    report_kind=report_kind,
                    display_name=(
                        "Reporte de calibración"
                        if report_kind == "CALIBRATION"
                        else "Reporte preventivo"
                    ),
                    document_status=version.document_status,
                    generated_report=detail.generated_report,
                )
            )
        return ReportDocumentPackageDTO(
            activity_id=activity_id,
            documents=documents,
        )

    async def generate(
        self,
        *,
        activity_id: str,
        user_id: str,
    ) -> ReportDocumentPackageDTO:
        package = await self.get(activity_id)
        unfinished = [
            item.display_name
            for item in package.documents
            if item.document_status != "FINALIZED"
        ]
        if unfinished:
            raise ReportValidationError(
                "Finaliza todos los documentos antes de generar el paquete: "
                + ", ".join(unfinished)
                + "."
            )

        for item in package.documents:
            if item.generated_report is not None:
                continue
            service = (
                CalibrationPDFService(self._session)
                if item.report_kind == "CALIBRATION"
                else PreventivePDFService(self._session)
            )
            await service.generate(version_id=item.version_id, user_id=user_id)

        return await self.get(activity_id)

    async def _latest_versions(
        self,
        activity_id: str,
    ) -> list[tuple[str, ReportVersionRecord]]:
        rows = (
            await self._session.execute(
                select(MaintenanceReportRecord, ReportVersionRecord)
                .join(
                    ReportVersionRecord,
                    ReportVersionRecord.maintenance_report_id
                    == MaintenanceReportRecord.id,
                )
                .where(
                    MaintenanceReportRecord.maintenance_activity_id == activity_id,
                    MaintenanceReportRecord.report_kind.in_(self._supported_kinds),
                )
                .order_by(
                    ReportVersionRecord.version_number.desc(),
                    ReportVersionRecord.created_at.desc(),
                )
            )
        ).all()
        latest: dict[str, ReportVersionRecord] = {}
        for report, version in rows:
            normalized_kind = (
                "PREVENTIVE"
                if report.report_kind in {"PREVENTIVE", "PREVENTIVE_MAIN"}
                else report.report_kind
            )
            latest.setdefault(normalized_kind, version)

        ordered: list[tuple[str, ReportVersionRecord]] = []
        if "PREVENTIVE" in latest:
            ordered.append(("PREVENTIVE", latest["PREVENTIVE"]))
        if "CALIBRATION" in latest:
            ordered.append(("CALIBRATION", latest["CALIBRATION"]))
        return ordered
