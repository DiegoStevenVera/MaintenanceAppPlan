from datetime import datetime, timezone
from uuid import uuid4

from sqlalchemy import DateTime, and_, cast, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from modules.asset_management.infrastructure.postgres.catalog_models import (
    ManufacturerRecord,
)
from modules.asset_management.infrastructure.postgres.models import AssetRecord
from modules.asset_management.infrastructure.postgres.domain_models import (
    AssetClosureRecord,
)
from modules.maintenance_execution.application.lifecycle import (
    MaintenanceLifecycleCommand,
    resolve_lifecycle_transition,
)
from modules.maintenance_execution.infrastructure.postgres.models import (
    CorrectiveEventRecord,
    PreventiveScheduleRecord,
)
from modules.maintenance_execution.infrastructure.postgres.report_models import (
    CalibrationMeasurementRecord,
    CalibrationReportDetailRecord,
    CorrectiveActivityRecord,
    CorrectiveReportBlockRecord,
    CorrectiveReportDetailRecord,
    MaintenanceActivityAssetRecord,
    MaintenanceActivityRecord,
    MaintenanceReopenRecord,
    MaintenanceReportRecord,
    MaintenanceStatusHistoryRecord,
    PreventiveReportDetailRecord,
    PreventiveStepResultRecord,
    PreventiveTestResultRecord,
    ReportVersionRecord,
)
from modules.maintenance_execution.infrastructure.postgres.template_models import (
    MaintenancePlanEntryRecord,
)
from modules.maintenance_execution.interfaces.schemas import (
    CalibrationReceiverDTO,
    CalibrationReportDTO,
    CorrectiveEventDTO,
    CorrectiveCreationContextDTO,
    CorrectiveActivityDTO,
    ComponentReplacementDTO,
    CorrectiveReportDTO,
    CreateCorrectiveEventRequest,
    MaintenanceActivityAssetDTO,
    MaintenanceActivityDTO,
    MaintenanceActivityDetailDTO,
    MaintenanceDashboardDTO,
    MaintenanceReportVersionDTO,
    PreventiveReportDTO,
    PreventiveStepResultDTO,
    PreventiveTestResultDTO,
    PreventiveScheduleDTO,
)
from modules.organizational_context.infrastructure.postgres.models import (
    ProjectRecord,
    SiteRecord,
    StageRecord,
    SubsystemRecord,
    SystemRecord,
)
from shared_kernel.schemas import MaintenanceStatus, Severity, TimelineEntryDTO, UserRole


class PostgresMaintenanceRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    def _activity_statement(self):
        activity = MaintenanceActivityRecord
        planned_year = (
            select(MaintenancePlanEntryRecord.year)
            .select_from(PreventiveScheduleRecord)
            .join(
                MaintenancePlanEntryRecord,
                MaintenancePlanEntryRecord.id
                == PreventiveScheduleRecord.maintenance_plan_entry_id,
            )
            .where(
                PreventiveScheduleRecord.maintenance_activity_id == activity.id,
                MaintenancePlanEntryRecord.planning_status == "PLANNED",
            )
            .correlate(activity)
            .limit(1)
            .scalar_subquery()
        )
        planned_month = (
            select(MaintenancePlanEntryRecord.month)
            .select_from(PreventiveScheduleRecord)
            .join(
                MaintenancePlanEntryRecord,
                MaintenancePlanEntryRecord.id
                == PreventiveScheduleRecord.maintenance_plan_entry_id,
            )
            .where(
                PreventiveScheduleRecord.maintenance_activity_id == activity.id,
                MaintenancePlanEntryRecord.planning_status == "PLANNED",
            )
            .correlate(activity)
            .limit(1)
            .scalar_subquery()
        )
        asset_ids = (
            select(func.array_agg(AssetRecord.id))
            .select_from(MaintenanceActivityAssetRecord)
            .join(AssetRecord, AssetRecord.id == MaintenanceActivityAssetRecord.asset_id)
            .where(MaintenanceActivityAssetRecord.maintenance_activity_id == activity.id)
            .correlate(activity)
            .scalar_subquery()
        )
        asset_names = (
            select(func.array_agg(AssetRecord.name))
            .select_from(MaintenanceActivityAssetRecord)
            .join(AssetRecord, AssetRecord.id == MaintenanceActivityAssetRecord.asset_id)
            .where(MaintenanceActivityAssetRecord.maintenance_activity_id == activity.id)
            .correlate(activity)
            .scalar_subquery()
        )
        report_count = (
            select(func.count(ReportVersionRecord.id))
            .select_from(MaintenanceReportRecord)
            .join(
                ReportVersionRecord,
                ReportVersionRecord.maintenance_report_id == MaintenanceReportRecord.id,
            )
            .where(MaintenanceReportRecord.maintenance_activity_id == activity.id)
            .correlate(activity)
            .scalar_subquery()
        )
        cancelled_plan_exists = (
            select(PreventiveScheduleRecord.id)
            .join(
                MaintenancePlanEntryRecord,
                MaintenancePlanEntryRecord.id
                == PreventiveScheduleRecord.maintenance_plan_entry_id,
            )
            .where(
                PreventiveScheduleRecord.maintenance_activity_id == activity.id,
                MaintenancePlanEntryRecord.planning_status == "CANCELLED",
            )
            .correlate(activity)
            .exists()
        )
        return select(
            activity,
            ProjectRecord.name.label("project_name"),
            StageRecord.name.label("stage_name"),
            SystemRecord.name.label("system_name"),
            SubsystemRecord.name.label("subsystem_name"),
            SiteRecord.name.label("site_name"),
            CorrectiveEventRecord.id.label("event_id"),
            CorrectiveEventRecord.code.label("event_code"),
            CorrectiveEventRecord.severity.label("event_severity"),
            asset_ids.label("asset_ids"),
            asset_names.label("asset_names"),
            report_count.label("report_count"),
            planned_year.label("planned_year"),
            planned_month.label("planned_month"),
        ).select_from(activity).join(
            ProjectRecord,
            ProjectRecord.id == activity.project_id,
        ).outerjoin(
            SiteRecord,
            SiteRecord.id == ProjectRecord.site_id,
        ).outerjoin(
            StageRecord,
            StageRecord.id == activity.primary_stage_id,
        ).join(
            SubsystemRecord,
            SubsystemRecord.id == activity.subsystem_id,
        ).outerjoin(
            SystemRecord,
            SystemRecord.id == SubsystemRecord.system_id,
        ).outerjoin(
            CorrectiveEventRecord,
            CorrectiveEventRecord.maintenance_activity_id == activity.id,
        ).where(~cancelled_plan_exists)

    @staticmethod
    def _to_activity_dto(row) -> MaintenanceActivityDTO:
        (
            activity,
            project_name,
            stage_name,
            system_name,
            subsystem_name,
            site_name,
            event_id,
            event_code,
            event_severity,
            asset_ids,
            asset_names,
            report_count,
            planned_year,
            planned_month,
        ) = row
        ids = asset_ids or []
        names = asset_names or []
        assets = [
            MaintenanceActivityAssetDTO(
                id=str(asset_id),
                name=name,
                role="AFFECTED",
            )
            for asset_id, name in zip(ids, names, strict=False)
        ]
        return MaintenanceActivityDTO(
            id=str(activity.id),
            activity_type=activity.activity_type,
            status=MaintenanceStatus(activity.status),
            title=activity.title,
            internal_code=activity.internal_code,
            project=project_name,
            stage=stage_name,
            system=system_name,
            subsystem=subsystem_name,
            site=site_name,
            location_path=activity.location_path_snapshot,
            scheduled_at=activity.scheduled_start_at,
            planned_year=planned_year,
            planned_month=planned_month,
            actual_start_at=activity.actual_start_at,
            actual_end_at=activity.actual_end_at,
            assets=assets,
            report_version_count=report_count or 0,
            event_id=str(event_id) if event_id else None,
            event_code=event_code,
            severity=Severity(event_severity) if event_severity else None,
        )

    async def list_activities(
        self,
        *,
        activity_type: str | None = None,
        status: MaintenanceStatus | None = None,
        subsystem: str | None = None,
        q: str | None = None,
        date_from: datetime | None = None,
        date_to: datetime | None = None,
        planned_year: int | None = None,
        planned_month: int | None = None,
        limit: int = 50,
        offset: int = 0,
    ) -> tuple[list[MaintenanceActivityDTO], int]:
        stmt = self._activity_statement()
        activity = MaintenanceActivityRecord
        if activity_type:
            stmt = stmt.where(activity.activity_type == activity_type.upper())
        if status:
            stmt = stmt.where(activity.status == status.value)
        if subsystem:
            stmt = stmt.where(func.lower(SubsystemRecord.name) == subsystem.casefold())
        if q:
            query = f"%{q.casefold()}%"
            matching_asset = (
                select(MaintenanceActivityAssetRecord.id)
                .join(AssetRecord, AssetRecord.id == MaintenanceActivityAssetRecord.asset_id)
                .where(
                    MaintenanceActivityAssetRecord.maintenance_activity_id == activity.id,
                    func.lower(AssetRecord.name).like(query),
                )
                .correlate(activity)
                .exists()
            )
            stmt = stmt.where(
                or_(
                    func.lower(activity.title).like(query),
                    func.lower(activity.internal_code).like(query),
                    func.lower(CorrectiveEventRecord.code).like(query),
                    func.lower(CorrectiveEventRecord.sap_code).like(query),
                    matching_asset,
                )
            )
        stmt = stmt.where(~activity.internal_code.like("LEGACY-ORPHAN-%"))

        normalized_type = activity_type.upper() if activity_type else None
        if normalized_type == "PREVENTIVE":
            date_expression = activity.scheduled_start_at
            date_conditions = []
            if date_from:
                date_conditions.append(activity.scheduled_start_at >= date_from)
            if date_to:
                date_conditions.append(activity.scheduled_start_at < date_to)
            exact_date_match = and_(*date_conditions) if date_conditions else None

            if planned_year is not None and planned_month is not None:
                plan_month_match = (
                    select(PreventiveScheduleRecord.id)
                    .join(
                        MaintenancePlanEntryRecord,
                        MaintenancePlanEntryRecord.id
                        == PreventiveScheduleRecord.maintenance_plan_entry_id,
                    )
                    .where(
                        PreventiveScheduleRecord.maintenance_activity_id == activity.id,
                        MaintenancePlanEntryRecord.year == planned_year,
                        MaintenancePlanEntryRecord.month == planned_month,
                        MaintenancePlanEntryRecord.planning_status == "PLANNED",
                    )
                    .correlate(activity)
                    .exists()
                )
                unscheduled_month_match = and_(
                    activity.scheduled_start_at.is_(None),
                    plan_month_match,
                )
                if exact_date_match is not None:
                    stmt = stmt.where(or_(exact_date_match, unscheduled_month_match))
                else:
                    stmt = stmt.where(unscheduled_month_match)
            elif exact_date_match is not None:
                stmt = stmt.where(exact_date_match)
        elif normalized_type == "CORRECTIVE":
            notice_date = cast(
                func.nullif(CorrectiveEventRecord.notice_created_at, ""),
                DateTime(timezone=True),
            )
            date_expression = notice_date
            if date_from:
                stmt = stmt.where(notice_date >= date_from)
            if date_to:
                stmt = stmt.where(notice_date < date_to)
        else:
            date_expression = func.coalesce(
                activity.scheduled_start_at,
                activity.actual_start_at,
                activity.created_at,
            )
            if date_from:
                stmt = stmt.where(date_expression >= date_from)
            if date_to:
                stmt = stmt.where(date_expression < date_to)

        total = await self._session.scalar(
            select(func.count()).select_from(stmt.order_by(None).subquery())
        )
        rows = (
            await self._session.execute(
                stmt.order_by(date_expression.desc().nullslast(), activity.title)
                .limit(limit)
                .offset(offset)
            )
        ).all()
        return [self._to_activity_dto(row) for row in rows], total or 0

    async def get_dashboard(
        self,
        *,
        day_from: datetime,
        day_to: datetime,
    ) -> MaintenanceDashboardDTO:
        activity = MaintenanceActivityRecord
        visible_activity = ~activity.internal_code.like("LEGACY-ORPHAN-%")

        preventive_today_count = await self._session.scalar(
            select(func.count(activity.id)).where(
                visible_activity,
                activity.activity_type == "PREVENTIVE",
                activity.scheduled_start_at >= day_from,
                activity.scheduled_start_at < day_to,
            )
        )
        active_corrective_count = await self._session.scalar(
            select(func.count(activity.id)).where(
                visible_activity,
                activity.activity_type == "CORRECTIVE",
                activity.status.in_(("SCHEDULED", "IN_PROGRESS")),
            )
        )
        completed_in_v1 = (
            select(MaintenanceStatusHistoryRecord.id)
            .where(
                MaintenanceStatusHistoryRecord.maintenance_activity_id == activity.id,
                MaintenanceStatusHistoryRecord.to_status == MaintenanceStatus.COMPLETED.value,
            )
            .correlate(activity)
            .exists()
        )
        pending_closure_count = await self._session.scalar(
            select(func.count(activity.id)).where(
                visible_activity,
                activity.status == "COMPLETED",
                activity.completed_at.is_not(None),
                completed_in_v1,
            )
        )
        today_rows = (
            await self._session.execute(
                self._activity_statement()
                .where(
                    visible_activity,
                    activity.activity_type == "PREVENTIVE",
                    activity.scheduled_start_at >= day_from,
                    activity.scheduled_start_at < day_to,
                )
                .order_by(activity.scheduled_start_at, activity.title)
            )
        ).all()
        active_corrective_rows = (
            await self._session.execute(
                self._activity_statement()
                .where(
                    visible_activity,
                    activity.activity_type == "CORRECTIVE",
                    activity.status.in_(("SCHEDULED", "IN_PROGRESS")),
                )
                .order_by(
                    activity.status.desc(),
                    activity.scheduled_start_at.nullslast(),
                    activity.created_at.desc(),
                )
            )
        ).all()
        pending_closure_rows = (
            await self._session.execute(
                self._activity_statement()
                .where(
                    visible_activity,
                    activity.status == "COMPLETED",
                    activity.completed_at.is_not(None),
                    completed_in_v1,
                )
                .order_by(activity.completed_at.desc(), activity.title)
            )
        ).all()
        return MaintenanceDashboardDTO(
            preventive_today_count=preventive_today_count or 0,
            active_corrective_count=active_corrective_count or 0,
            pending_closure_count=pending_closure_count or 0,
            preventive_today=[self._to_activity_dto(row) for row in today_rows],
            active_correctives=[
                self._to_activity_dto(row) for row in active_corrective_rows
            ],
            pending_closure=[
                self._to_activity_dto(row) for row in pending_closure_rows
            ],
        )

    async def transition_activity(
        self,
        *,
        activity_id: str,
        command: MaintenanceLifecycleCommand,
        user_id: str,
        user_role: UserRole,
        reason: str | None = None,
    ) -> bool:
        activity = await self._session.scalar(
            select(MaintenanceActivityRecord)
            .where(MaintenanceActivityRecord.id == activity_id)
            .with_for_update()
        )
        if activity is None:
            return False

        previous_status = MaintenanceStatus(activity.status)
        next_status = resolve_lifecycle_transition(
            current_status=previous_status,
            command=command,
            role=user_role,
        )
        changed_at = datetime.now(timezone.utc)

        activity.status = next_status.value
        if command == MaintenanceLifecycleCommand.START:
            activity.actual_start_at = changed_at
        elif command == MaintenanceLifecycleCommand.COMPLETE:
            activity.actual_end_at = changed_at
            activity.completed_at = changed_at
            activity.completed_by_user_id = user_id
        elif command == MaintenanceLifecycleCommand.CLOSE:
            activity.closed_at = changed_at
            activity.closed_by_user_id = user_id
        else:
            activity.actual_end_at = None
            activity.completed_at = None
            activity.completed_by_user_id = None
            activity.closed_at = None
            activity.closed_by_user_id = None
            self._session.add(
                MaintenanceReopenRecord(
                    maintenance_activity_id=activity.id,
                    reopened_by_user_id=user_id,
                    reopened_at=changed_at,
                    previous_status=previous_status.value,
                    reason=reason or "",
                )
            )

        self._session.add(
            MaintenanceStatusHistoryRecord(
                maintenance_activity_id=activity.id,
                from_status=previous_status.value,
                to_status=next_status.value,
                changed_at=changed_at,
                changed_by_user_id=user_id,
                reason=reason,
            )
        )
        await self._session.execute(
            PreventiveScheduleRecord.__table__.update()
            .where(PreventiveScheduleRecord.maintenance_activity_id == activity.id)
            .values(status=next_status.value)
        )
        await self._session.execute(
            CorrectiveEventRecord.__table__.update()
            .where(CorrectiveEventRecord.maintenance_activity_id == activity.id)
            .values(status=next_status.value)
        )
        await self._session.flush()
        return True

    async def get_activity(self, activity_id: str) -> MaintenanceActivityDetailDTO | None:
        row = (
            await self._session.execute(
                self._activity_statement().where(
                    MaintenanceActivityRecord.id == activity_id
                )
            )
        ).one_or_none()
        if row is None:
            return None

        base = self._to_activity_dto(row)
        assets = (
            await self._session.execute(
                select(
                    MaintenanceActivityAssetRecord.role,
                    AssetRecord.id,
                    AssetRecord.name,
                )
                .join(AssetRecord, AssetRecord.id == MaintenanceActivityAssetRecord.asset_id)
                .where(
                    MaintenanceActivityAssetRecord.maintenance_activity_id == activity_id
                )
                .order_by(AssetRecord.name)
            )
        ).all()
        base.assets = [
            MaintenanceActivityAssetDTO(id=asset_id, name=name, role=role)
            for role, asset_id, name in assets
        ]

        reports = await self.list_activity_reports(activity_id)
        detail = MaintenanceActivityDetailDTO(
            **base.model_dump(),
            reports=reports,
        )
        main_reports = [
            report
            for report in reports
            if report.report_kind != "CALIBRATION"
        ]
        latest = max(
            main_reports,
            key=lambda item: (
                item.document_status == "FINALIZED",
                item.version_number,
            ),
            default=None,
        )
        if latest is None:
            return detail

        if latest.report_kind in {"PREVENTIVE", "PREVENTIVE_MAIN"}:
            detail.preventive_report = await self._get_preventive_report(latest.id)
        elif latest.report_kind == "CORRECTIVE":
            detail.corrective_report = await self._get_corrective_report(latest.id)
        return detail

    async def list_activity_reports(self, activity_id: str) -> list[MaintenanceReportVersionDTO]:
        rows = (
            await self._session.execute(
                select(MaintenanceReportRecord, ReportVersionRecord)
                .join(
                    ReportVersionRecord,
                    ReportVersionRecord.maintenance_report_id == MaintenanceReportRecord.id,
                )
                .where(MaintenanceReportRecord.maintenance_activity_id == activity_id)
                .order_by(ReportVersionRecord.created_at.desc())
            )
        ).all()
        return [
            MaintenanceReportVersionDTO(
                id=str(version.id),
                report_kind=report.report_kind,
                report_number=report.report_number,
                version_number=version.version_number,
                document_status=version.document_status,
                summary=version.summary,
                created_at=version.created_at,
                finalized_at=version.finalized_at,
            )
            for report, version in rows
        ]

    async def _get_preventive_report(self, version_id: str) -> PreventiveReportDTO | None:
        detail = await self._session.get(PreventiveReportDetailRecord, version_id)
        if detail is None:
            return None
        step_rows = (
            await self._session.scalars(
                select(PreventiveStepResultRecord)
                .where(PreventiveStepResultRecord.report_version_id == version_id)
                .order_by(PreventiveStepResultRecord.sequence_snapshot)
            )
        ).all()
        step_ids = [step.id for step in step_rows]
        test_rows = []
        if step_ids:
            test_rows = (
                await self._session.scalars(
                    select(PreventiveTestResultRecord)
                    .where(PreventiveTestResultRecord.step_result_id.in_(step_ids))
                    .order_by(PreventiveTestResultRecord.created_at)
                )
            ).all()
        tests_by_step: dict[object, list[PreventiveTestResultDTO]] = {}
        for test in test_rows:
            tests_by_step.setdefault(test.step_result_id, []).append(
                PreventiveTestResultDTO(
                    id=str(test.id),
                    name=test.name_snapshot,
                    selected_result=test.selected_result,
                    numeric_value=test.numeric_value,
                    notes=test.notes,
                )
            )
        return PreventiveReportDTO(
            actual_date=detail.actual_date.isoformat(),
            activity_started_at=detail.activity_started_at,
            activity_ended_at=detail.activity_ended_at,
            final_result=detail.final_result,
            additional_comments=detail.additional_comments,
            steps=[
                PreventiveStepResultDTO(
                    id=str(step.id),
                    title=step.title_snapshot,
                    manual_page=step.manual_page_snapshot,
                    is_completed=step.is_completed,
                    comment=step.comment,
                    tests=tests_by_step.get(step.id, []),
                )
                for step in step_rows
            ],
        )

    async def _get_calibration_report(
        self,
        version_id: str,
    ) -> CalibrationReportDTO | None:
        row = (
            await self._session.execute(
                select(CalibrationReportDetailRecord, AssetRecord)
                .join(
                    AssetRecord,
                    AssetRecord.id
                    == CalibrationReportDetailRecord.track_circuit_asset_id,
                )
                .where(
                    CalibrationReportDetailRecord.report_version_id == version_id
                )
            )
        ).one_or_none()
        if row is None:
            return None
        detail, asset = row
        measurements = (
            await self._session.scalars(
                select(CalibrationMeasurementRecord)
                .where(
                    CalibrationMeasurementRecord.report_version_id == version_id
                )
                .order_by(CalibrationMeasurementRecord.sequence)
            )
        ).all()

        def value_for(
            rows: list[CalibrationMeasurementRecord],
            name: str,
        ) -> str | None:
            normalized_name = name.casefold()
            return next(
                (
                    record.measured_value
                    for record in rows
                    if normalized_name in record.measurement_name.casefold()
                ),
                None,
            )

        transmitter_rows = [
            record
            for record in measurements
            if record.asset_role.casefold() in {"transmisor", "transmitter"}
        ]
        receiver_groups: dict[str, list[CalibrationMeasurementRecord]] = {}
        for record in measurements:
            role = record.asset_role.casefold()
            if role in {"transmisor", "transmitter"}:
                continue
            receiver_groups.setdefault(record.asset_role, []).append(record)

        receivers = []
        for index, rows in enumerate(receiver_groups.values(), start=1):
            receivers.append(
                CalibrationReceiverDTO(
                    sequence=index,
                    jumpers=value_for(rows, "jumper"),
                    tca9=value_for(rows, "tca9"),
                    rail_current=value_for(rows, "corriente"),
                )
            )
        if not receivers and (
            detail.track_circuit_type or ""
        ).casefold() in {"receptor", "receiver"}:
            receivers.append(
                CalibrationReceiverDTO(
                    sequence=int(detail.track_circuit_number or 1),
                    jumpers=detail.jumpers,
                    tca9=detail.tca9,
                    rail_current=detail.rail_current,
                )
            )

        return CalibrationReportDTO(
            track_circuit_asset_id=asset.id,
            track_circuit_name=asset.name,
            frequency=detail.frequency or value_for(measurements, "frecuencia"),
            calibration_date=detail.calibration_date,
            location=detail.location_snapshot,
            transmitter_jumpers=detail.jumpers
            or value_for(transmitter_rows, "jumper"),
            receivers=receivers,
        )

    async def _get_corrective_report(self, version_id: str) -> CorrectiveReportDTO | None:
        detail = await self._session.get(CorrectiveReportDetailRecord, version_id)
        if detail is None:
            return None
        event = await self._session.get(CorrectiveEventRecord, detail.corrective_event_id)
        activity_rows = (
            await self._session.scalars(
                select(CorrectiveActivityRecord)
                .where(CorrectiveActivityRecord.report_version_id == version_id)
                .order_by(CorrectiveActivityRecord.sequence)
            )
        ).all()
        replacement_blocks = (
            await self._session.scalars(
                select(CorrectiveReportBlockRecord)
                .where(
                    CorrectiveReportBlockRecord.report_version_id == version_id,
                    CorrectiveReportBlockRecord.block_type == "COMPONENT_REPLACEMENT",
                )
                .order_by(CorrectiveReportBlockRecord.sequence)
            )
        ).all()
        replacements_by_activity = {
            block.payload.get("corrective_activity_id"): await self._replacement_dto(
                block.payload
            )
            for block in replacement_blocks
            if block.payload.get("corrective_activity_id")
        }
        return CorrectiveReportDTO(
            event_code=event.code if event else None,
            sap_notification=event.sap_code if event else None,
            sap_event_name=event.name if event else None,
            affected_asset_path=event.affected_asset_path if event else None,
            notice_created_at=(
                self._parse_optional_datetime(event.notice_created_at)
                if event
                else None
            ),
            response_at=detail.response_at,
            corrective_started_at=detail.corrective_started_at,
            corrective_ended_at=detail.corrective_ended_at,
            symptom=detail.symptom,
            technical_description=detail.technical_description,
            operational_impact=detail.operational_impact,
            failure_analysis_type=detail.failure_analysis_type,
            functional_tests=detail.functional_tests,
            validation_result=detail.validation_result,
            service_released=detail.service_released,
            service_released_at=detail.service_released_at,
            validation_responsible=detail.validation_responsible_snapshot,
            technical_status=detail.technical_status,
            conclusion=detail.conclusion,
            additional_comments=detail.additional_comments,
            activities=[
                CorrectiveActivityDTO(
                    id=str(activity.id),
                    name=activity.name,
                    description=activity.description,
                    started_at=activity.started_at,
                    ended_at=activity.ended_at,
                    replacement=replacements_by_activity.get(str(activity.id)),
                )
                for activity in activity_rows
            ],
        )

    async def _replacement_dto(
        self,
        payload: dict,
    ) -> ComponentReplacementDTO:
        parent = await self._asset_snapshot(
            payload.get("parent_asset_id"),
            payload.get("parent_asset_snapshot"),
        )
        removed = await self._asset_snapshot(
            payload.get("removed_asset_id"),
            payload.get("removed_asset_snapshot"),
        )
        installed = await self._asset_snapshot(
            payload.get("installed_asset_id"),
            payload.get("installed_asset_snapshot"),
        )
        return ComponentReplacementDTO(
            parent_asset_id=payload["parent_asset_id"],
            parent_asset_name=parent.get("name"),
            removed_asset_id=payload["removed_asset_id"],
            removed_asset_name=removed.get("name"),
            removed_asset_path=removed.get("path"),
            removed_part_number=removed.get("part_number"),
            removed_serial_number=removed.get("serial_number"),
            removed_model=removed.get("model"),
            removed_manufacturer=removed.get("manufacturer"),
            installed_asset_id=payload["installed_asset_id"],
            installed_asset_name=installed.get("name"),
            installed_asset_path=installed.get("path"),
            installed_part_number=installed.get("part_number"),
            installed_serial_number=installed.get("serial_number"),
            installed_model=installed.get("model"),
            installed_manufacturer=installed.get("manufacturer"),
            source_description=payload.get("source_description", ""),
            destination_description=payload.get("destination_description", ""),
            removed_condition=payload.get("removed_condition"),
            installed_condition=payload.get("installed_condition"),
            removed_notes=payload.get("removed_notes"),
            installed_notes=payload.get("installed_notes"),
            reason=payload.get("reason", ""),
        )

    async def _asset_snapshot(
        self,
        asset_id: str | None,
        stored_snapshot: dict | None,
    ) -> dict:
        if not asset_id:
            return stored_snapshot or {}
        asset = await self._session.get(AssetRecord, asset_id)
        if stored_snapshot:
            snapshot = dict(stored_snapshot)
            if (
                asset is not None
                and not asset.serial_number
                and snapshot.get("serial_number")
                in {asset.internal_code, asset.serial_or_code}
            ):
                snapshot["serial_number"] = None
            if (
                asset is not None
                and not asset.model
                and snapshot.get("model") == asset.asset_type
            ):
                snapshot["model"] = None
            return snapshot
        if asset is None:
            return {"name": asset_id}
        manufacturer = (
            await self._session.get(ManufacturerRecord, asset.manufacturer_id)
            if asset.manufacturer_id
            else None
        )
        return {
            "name": asset.name,
            "path": asset.current_position or asset.physical_location,
            "part_number": asset.part_number,
            "serial_number": asset.serial_number,
            "model": asset.model,
            "manufacturer": manufacturer.name if manufacturer else None,
        }

    @staticmethod
    def _parse_optional_datetime(value: str | None) -> datetime | None:
        if not value:
            return None
        try:
            return datetime.fromisoformat(value)
        except ValueError:
            return None

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
        *,
        user_id: str,
    ) -> CorrectiveEventDTO:
        if payload.business_anchor_asset_id is None or payload.affected_asset_id is None:
            raise ValueError(
                "El equipo grande y el asset afectado son obligatorios."
            )

        context = await self._corrective_creation_records(
            payload.business_anchor_asset_id
        )
        if context is None:
            raise ValueError("El equipo grande seleccionado no es válido.")
        anchor, subsystem, system, project, site, stage = context

        affected_asset = await self._session.get(
            AssetRecord,
            payload.affected_asset_id,
        )
        if affected_asset is None:
            raise ValueError("El asset afectado seleccionado no existe.")
        belongs_to_anchor = affected_asset.id == anchor.id or await self._session.scalar(
            select(AssetClosureRecord.ancestor_asset_id).where(
                AssetClosureRecord.ancestor_asset_id == anchor.id,
                AssetClosureRecord.descendant_asset_id == affected_asset.id,
            )
        )
        if not belongs_to_anchor:
            raise ValueError(
                "El asset afectado no pertenece al equipo grande seleccionado."
            )

        now = datetime.now(timezone.utc)
        identifier = uuid4().hex[:10].upper()
        event_id = f"cor-{uuid4()}"
        event_code = f"COR-{now.year}-{identifier}"
        activity = MaintenanceActivityRecord(
            activity_type="CORRECTIVE",
            status=MaintenanceStatus.SCHEDULED.value,
            project_id=project.id,
            primary_stage_id=stage.id if stage is not None else None,
            subsystem_id=subsystem.id,
            geographic_location_id=anchor.current_geographic_location_id,
            title=payload.sap_event_name.strip(),
            internal_code=event_code,
            location_path_snapshot=anchor.physical_location,
            created_by_user_id=user_id,
        )
        self._session.add(activity)
        await self._session.flush()

        record = CorrectiveEventRecord(
            id=event_id,
            code=event_code,
            sap_code=payload.sap_notification,
            name=payload.sap_event_name,
            affected_asset_id=affected_asset.id,
            affected_asset_path=payload.affected_asset_path,
            subsystem=subsystem.name,
            severity=payload.severity.value,
            status=MaintenanceStatus.SCHEDULED.value,
            notice_created_at=payload.notice_created_at,
            response_at=payload.response_at,
            physical_location=anchor.physical_location,
            report_version_count=0,
            timeline=[
                {
                    "id": f"tl-{event_id}-created",
                    "occurred_at": now.isoformat(),
                    "text": "Evento correctivo creado",
                }
            ],
            maintenance_activity_id=activity.id,
            primary_asset_id=anchor.id,
            subsystem_id=subsystem.id,
            created_by_user_id=user_id,
        )
        self._session.add(record)
        self._session.add(
            MaintenanceActivityAssetRecord(
                maintenance_activity_id=activity.id,
                asset_id=anchor.id,
                role="EQUIPMENT",
                include_descendants=True,
            )
        )
        if affected_asset.id != anchor.id:
            self._session.add(
                MaintenanceActivityAssetRecord(
                    maintenance_activity_id=activity.id,
                    asset_id=affected_asset.id,
                    role="AFFECTED",
                    include_descendants=False,
                )
            )
        self._session.add(
            MaintenanceStatusHistoryRecord(
                maintenance_activity_id=activity.id,
                from_status=None,
                to_status=MaintenanceStatus.SCHEDULED.value,
                changed_at=now,
                changed_by_user_id=user_id,
                reason="Evento correctivo creado",
            )
        )
        await self._session.flush()
        await self._session.refresh(record)
        return self._to_corrective_dto(record)

    async def get_corrective_creation_context(
        self,
        business_anchor_asset_id: str,
    ) -> CorrectiveCreationContextDTO | None:
        context = await self._corrective_creation_records(
            business_anchor_asset_id
        )
        if context is None:
            return None
        anchor, subsystem, system, project, site, stage = context
        return CorrectiveCreationContextDTO(
            business_anchor_asset_id=anchor.id,
            site=site.name,
            project=project.name,
            stage=stage.name if stage is not None else None,
            system=system.name,
            subsystem=subsystem.name,
            physical_location=anchor.physical_location,
        )

    async def _corrective_creation_records(
        self,
        business_anchor_asset_id: str,
    ):
        anchor = await self._session.get(AssetRecord, business_anchor_asset_id)
        if anchor is None or not anchor.is_business_anchor:
            return None
        subsystem = (
            await self._session.get(SubsystemRecord, anchor.subsystem_id)
            if anchor.subsystem_id is not None
            else await self._session.scalar(
                select(SubsystemRecord)
                .where(func.lower(SubsystemRecord.name) == anchor.subsystem.casefold())
                .limit(1)
            )
        )
        if subsystem is None:
            return None
        system = await self._session.get(SystemRecord, subsystem.system_id)
        if system is None:
            return None
        project = await self._session.get(ProjectRecord, system.project_id)
        if project is None:
            return None
        site = await self._session.get(SiteRecord, project.site_id)
        if site is None:
            return None
        stage = await self._session.scalar(
            select(StageRecord)
            .where(
                StageRecord.project_id == project.id,
                StageRecord.is_active.is_(True),
            )
            .order_by(
                (func.lower(StageRecord.name) == "etapa 1a").desc(),
                StageRecord.name,
            )
            .limit(1)
        )
        return anchor, subsystem, system, project, site, stage

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
