from collections import defaultdict
from datetime import UTC, datetime
from typing import Any
from uuid import UUID
from zoneinfo import ZoneInfo

from sqlalchemy import func, select

from legacy_import.context import SOURCE_SYSTEM, ImportContext, MappingTarget
from legacy_import.errors import RowImportError
from legacy_import.ids import stable_string_id, stable_uuid
from legacy_import.values import (
    boolean,
    combine_date_time,
    duration_hours,
    identifier,
    integer,
    normalize_key,
    optional_combine_date_time,
    parse_date,
    parse_datetime,
    required_text,
    text,
)
from legacy_import.wbs import WBS_SOURCE, wbs_string_id, wbs_uuid
from legacy_import.workbook import LegacyWorkbook, SourceRow

STORAGE_SOURCE = "BD_Storage"
LIMA_TIMEZONE = ZoneInfo("America/Lima")

STORAGE_SHEETS: dict[str, str] = {
    "tbl_WorkMaintenanceCorrective": "ID_WorkMaintenanceCorrective",
    "tbl_Scheduled_Activities": "ID_Scheduled_Activities",
    "Maintenance_Storage": "ID",
    "tbl_CorrectiveReports_Detail": "ID_CorrectiveReport",
    "tbl_CorrectiveActivities": "ID_CorrectiveActivities",
    "tbl_Workers_Activity": "ID_Workers_Activity",
    "Tools_Activity": "ID_Tool_Activity",
    "Tasks_activity": "ID_Tasks_activity",
    "tbl_Test_Result_Activity": "ID_Test_Result_Activity",
    "Images_Activity": "ID_Image",
    "tbl_Reports": "Id_Doc",
    "tbl_Calibration": "ID_Calibration",
    "tbl_ComponentMovement": "ID_ComponentMovement",
    "tbl_WorkOrderComponent": "ID_WorkOrderComponent",
    "tbl_InstalledComponent": "ID_InstalledComponent",
}


def storage_uuid(sheet: str, source_key: Any, target_table: str, role: str = "PRIMARY") -> UUID:
    return stable_uuid(
        STORAGE_SOURCE,
        sheet,
        identifier(source_key),
        target_table,
        role,
    )


def storage_string_id(
    sheet: str,
    source_key: Any,
    target_table: str,
    role: str = "PRIMARY",
) -> str:
    return str(storage_uuid(sheet, source_key, target_table, role))


def localized(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    if value.tzinfo is not None:
        return value
    return value.replace(tzinfo=LIMA_TIMEZONE)


class StorageImporter:
    def __init__(self, workbook: LegacyWorkbook, context: ImportContext) -> None:
        self.workbook = workbook
        self.context = context
        self.rows: dict[str, list[SourceRow]] = {
            sheet: workbook.rows(sheet, key_column=key)
            for sheet, key in STORAGE_SHEETS.items()
        }
        self.by_key: dict[str, dict[str, SourceRow]] = {
            sheet: {row.key: row for row in rows}
            for sheet, rows in self.rows.items()
        }
        self.corrective_detail_by_maintenance: dict[str, SourceRow] = {}
        for row in self.rows["tbl_CorrectiveReports_Detail"]:
            maintenance_key = text(row.values.get("FK_Maintenance_Storage"))
            if maintenance_key:
                self.corrective_detail_by_maintenance[maintenance_key] = row
        self.calibration_by_report: dict[str, list[SourceRow]] = defaultdict(list)
        for row in self.rows["tbl_Calibration"]:
            report_key = text(row.values.get("FK_Report"))
            if report_key:
                self.calibration_by_report[report_key].append(row)
        self.work_order_groups: dict[tuple[str, str, str], list[SourceRow]] = defaultdict(list)
        for row in self.rows["tbl_WorkOrderComponent"]:
            values = row.values
            group_key = (
                identifier(values.get("FK_Maintenance")),
                identifier(values.get("FK_CorrectiveActivities")),
                identifier(values.get("FK_Equipment")),
            )
            self.work_order_groups[group_key].append(row)
        self._template_step_cache: dict[
            tuple[UUID, str],
            UUID,
        ] | None = None
        self._asset_name_cache: list[tuple[str, str]] | None = None
        preventive_groups: dict[tuple[str, str], list[SourceRow]] = defaultdict(list)
        for maintenance_row in self.rows["Maintenance_Storage"]:
            if "correct" in normalize_key(
                maintenance_row.values.get("MaintenanceType")
            ):
                continue
            identity = self._preventive_activity_identity(maintenance_row)
            preventive_groups[identity].append(maintenance_row)
        self.preventive_version_numbers: dict[str, int] = {}
        for group_rows in preventive_groups.values():
            for version_number, maintenance_row in enumerate(
                sorted(group_rows, key=lambda item: item.row_number),
                start=1,
            ):
                self.preventive_version_numbers[maintenance_row.key] = version_number
        calibration_groups: dict[tuple[str, str], list[str]] = defaultdict(list)
        for report_source_key, calibration_rows in self.calibration_by_report.items():
            maintenance_key = required_text(
                calibration_rows[0].values.get("FK_Maintenance_Storage"),
                "FK_Maintenance_Storage",
            )
            maintenance_row = self.by_key["Maintenance_Storage"].get(maintenance_key)
            if maintenance_row is None:
                continue
            identity = self._preventive_activity_identity(maintenance_row)
            calibration_groups[identity].append(report_source_key)
        self.calibration_version_numbers: dict[str, int] = {}
        self.calibration_report_source_by_maintenance: dict[str, str] = {}
        for report_sources in calibration_groups.values():
            for version_number, report_source_key in enumerate(
                sorted(
                    set(report_sources),
                    key=lambda key: self.calibration_by_report[key][0].row_number,
                ),
                start=1,
            ):
                self.calibration_version_numbers[report_source_key] = version_number
                for calibration_row in self.calibration_by_report[report_source_key]:
                    maintenance_key = required_text(
                        calibration_row.values.get("FK_Maintenance_Storage"),
                        "FK_Maintenance_Storage",
                    )
                    self.calibration_report_source_by_maintenance[
                        maintenance_key
                    ] = report_source_key
        self.calibration_row_sequences = {
            calibration_row.key: sequence
            for calibration_rows in self.calibration_by_report.values()
            for sequence, calibration_row in enumerate(calibration_rows, start=1)
        }

    async def run(self, selected_table: str | None = None) -> None:
        steps = [
            ("tbl_WorkMaintenanceCorrective", self._import_corrective_work),
            ("tbl_Scheduled_Activities", self._import_schedule),
            ("Maintenance_Storage", self._import_maintenance),
            ("tbl_CorrectiveReports_Detail", self._import_corrective_detail),
            ("tbl_CorrectiveActivities", self._import_corrective_activity),
            ("tbl_Workers_Activity", self._import_participant),
            ("Tools_Activity", self._import_tool_usage),
            ("Tasks_activity", self._import_step_result),
            ("tbl_Test_Result_Activity", self._import_test_result),
            ("Images_Activity", self._import_attachment),
            ("tbl_Calibration", self._import_calibration),
            ("tbl_Reports", self._import_generated_report),
            ("tbl_ComponentMovement", self._import_asset_movement),
            ("tbl_WorkOrderComponent", self._import_replacement),
            ("tbl_InstalledComponent", self._import_installed_component),
        ]
        if selected_table and selected_table not in STORAGE_SHEETS:
            raise RowImportError(f"Unsupported BD_Storage table: {selected_table}")
        for sheet, handler in steps:
            if selected_table and sheet != selected_table:
                continue
            await self.context.process_rows(sheet, self.rows[sheet], handler)

    async def _import_corrective_work(self, row: SourceRow) -> list[MappingTarget]:
        values = row.values
        detail = next(
            (
                candidate
                for candidate in self.rows["tbl_CorrectiveReports_Detail"]
                if identifier(candidate.values.get("FK_WorkMaintenance")) == row.key
            ),
            None,
        )
        subsystem_name = (
            text(detail.values.get("2_SubsystemReal"))
            if detail
            else self._subsystem_from_type(values.get("TypeWork"))
        ) or "CBTC"
        subsystem_id = await self._catalog_id("subsystems", "name", subsystem_name)
        project_id = await self._first_id("projects")
        stage_id = await self._first_id("stages")
        activity_id = storage_uuid(row.sheet, row.key, "maintenance_activities")
        event_id = storage_string_id(row.sheet, row.key, "corrective_events")
        started_at = localized(combine_date_time(values.get("Date"), values.get("Hour")))
        is_finished = boolean(values.get("Is_Finished"))
        status = "COMPLETED" if is_finished else "IN_PROGRESS"
        title = required_text(values.get("Name"), "Name")

        await self.context.upsert(
            "maintenance_activities",
            {
                "id": activity_id,
                "legacy_id": None,
                "activity_type": "CORRECTIVE",
                "status": status,
                "project_id": project_id,
                "primary_stage_id": stage_id,
                "subsystem_id": subsystem_id,
                "geographic_location_id": None,
                "maintenance_template_id": None,
                "title": title,
                "internal_code": f"LEGACY-COR-{row.key}",
                "scheduled_start_at": None,
                "scheduled_end_at": None,
                "actual_start_at": started_at,
                "actual_end_at": started_at if is_finished else None,
                "shift": None,
                "sap_order": text(values.get("Code")),
                "work_order": None,
                "location_path_snapshot": None,
                "created_by_user_id": None,
                "completed_by_user_id": None,
                "closed_by_user_id": None,
                "completed_at": started_at if is_finished else None,
                "closed_at": None,
            },
        )
        event_values = {
            "id": event_id,
            "code": text(values.get("Code")) or f"COR-{row.key}",
            "sap_code": text(values.get("Code")) or "-",
            "name": title,
            "affected_asset_id": None,
            "affected_asset_path": "",
            "subsystem": subsystem_name,
            "severity": "MEDIUM",
            "status": status,
            "notice_created_at": started_at.isoformat() if started_at else "",
            "response_at": started_at.isoformat() if started_at else "",
            "physical_location": "",
            "report_version_count": 0,
            "timeline": [],
            "legacy_id": None,
            "maintenance_activity_id": activity_id,
            "primary_asset_id": None,
            "subsystem_id": subsystem_id,
            "created_by_user_id": None,
            "failure_description": None,
            "operational_impact": None,
        }
        await self.context.upsert("corrective_events", event_values)
        return [
            MappingTarget("maintenance_activities", str(activity_id)),
            MappingTarget("corrective_events", event_id, "EVENT"),
        ]

    async def _import_schedule(self, row: SourceRow) -> list[MappingTarget]:
        values = row.values
        scope_key = identifier(values.get("FK_Equipment_Activity_Area"))
        scope_id = wbs_uuid(
            "tbl_Equipment_Activity_Area",
            scope_key,
            "maintenance_template_scopes",
        )
        scopes = self.context.tables["maintenance_template_scopes"]
        scope = (
            await self.context.session.execute(
                select(
                    scopes.c.maintenance_template_id,
                    scopes.c.asset_id,
                    scopes.c.geographic_location_id,
                    scopes.c.display_name,
                ).where(scopes.c.id == scope_id)
            )
        ).mappings().first()
        if scope is None:
            raise RowImportError(
                f"Missing WBS template scope {scope_key}; import WBS_V2 first"
            )
        templates = self.context.tables["maintenance_templates"]
        template = (
            await self.context.session.execute(
                select(
                    templates.c.report_code,
                    templates.c.subsystem_id,
                    templates.c.activity_n3_summary,
                ).where(templates.c.id == scope["maintenance_template_id"])
            )
        ).mappings().one()
        subsystem = self.context.tables["subsystems"]
        subsystem_name = await self.context.session.scalar(
            select(subsystem.c.name).where(subsystem.c.id == template["subsystem_id"])
        )
        location_path = await self._location_path(scope["geographic_location_id"])
        asset_name = await self._asset_name(scope["asset_id"])
        project_id = await self._first_id("projects")
        stage_id = await self._first_id("stages")
        scheduled_at = localized(
            combine_date_time(values.get("Date_Activity_Scheduled"), None)
        )
        is_done = boolean(values.get("Is_Done"))
        status = "COMPLETED" if is_done else "SCHEDULED"
        activity_id = storage_uuid(row.sheet, row.key, "maintenance_activities")
        plan_id = storage_uuid(row.sheet, row.key, "maintenance_plan_entries")
        bridge_id = storage_string_id(row.sheet, row.key, "preventive_schedules")
        planned_hours = duration_hours(values.get("Total_hours"))

        await self.context.upsert(
            "maintenance_plan_entries",
            {
                "id": plan_id,
                "legacy_id": integer(row.key) if row.key.isdigit() else None,
                "maintenance_template_scope_id": scope_id,
                "year": integer(values.get("Year")) or (scheduled_at.year if scheduled_at else 0),
                "month": integer(values.get("Month")) or (scheduled_at.month if scheduled_at else 1),
                "item_number": self._item_number(values.get("Item")),
                "planned_hours": planned_hours,
                "required_workers": integer(values.get("Q_workers")),
                "source_reference": text(values.get("Item")),
            },
        )
        await self.context.upsert(
            "maintenance_activities",
            {
                "id": activity_id,
                "legacy_id": None,
                "activity_type": "PREVENTIVE",
                "status": status,
                "project_id": project_id,
                "primary_stage_id": stage_id,
                "subsystem_id": template["subsystem_id"],
                "geographic_location_id": scope["geographic_location_id"],
                "maintenance_template_id": scope["maintenance_template_id"],
                "title": scope["display_name"],
                "internal_code": f"LEGACY-PREV-{row.key}",
                "scheduled_start_at": scheduled_at,
                "scheduled_end_at": scheduled_at,
                "actual_start_at": localized(
                    combine_date_time(values.get("Date_Activity_Done"), None)
                ),
                "actual_end_at": None,
                "shift": text(values.get("Turn")),
                "sap_order": text(values.get("Order_SAP")),
                "work_order": text(values.get("OT")),
                "location_path_snapshot": location_path,
                "created_by_user_id": None,
                "completed_by_user_id": None,
                "closed_by_user_id": None,
                "completed_at": None,
                "closed_at": None,
            },
        )
        activity_asset_id = storage_uuid(
            row.sheet,
            row.key,
            "maintenance_activity_assets",
        )
        await self.context.upsert(
            "maintenance_activity_assets",
            {
                "id": activity_asset_id,
                "maintenance_activity_id": activity_id,
                "asset_id": scope["asset_id"],
                "role": "PRIMARY_TARGET",
                "include_descendants": True,
                "notes": None,
            },
        )
        await self.context.upsert(
            "preventive_schedules",
            {
                "id": bridge_id,
                "name": scope["display_name"],
                "template_name": template["activity_n3_summary"] or template["report_code"],
                "asset_ids": [scope["asset_id"]],
                "asset_names": [asset_name],
                "subsystem": subsystem_name,
                "scheduled_at": scheduled_at.isoformat() if scheduled_at else "",
                "status": status,
                "physical_location": location_path,
                "report_version_count": 1 if is_done else 0,
                "legacy_id": integer(row.key),
                "maintenance_activity_id": activity_id,
                "maintenance_template_id": scope["maintenance_template_id"],
                "maintenance_plan_entry_id": plan_id,
                "assigned_date": scheduled_at,
                "shift": text(values.get("Turn")),
                "sap_order": text(values.get("Order_SAP")),
                "work_order": text(values.get("OT")),
            },
        )
        return [
            MappingTarget("maintenance_plan_entries", str(plan_id), "PLAN"),
            MappingTarget("maintenance_activities", str(activity_id)),
            MappingTarget("maintenance_activity_assets", str(activity_asset_id), "ASSET"),
            MappingTarget("preventive_schedules", bridge_id, "SCHEDULE"),
        ]

    async def _import_maintenance(self, row: SourceRow) -> list[MappingTarget]:
        values = row.values
        maintenance_type = normalize_key(values.get("MaintenanceType"))
        if "correct" in maintenance_type:
            detail = self.corrective_detail_by_maintenance.get(row.key)
            if detail is None:
                raise RowImportError(
                    f"Corrective maintenance {row.key} has no detail record"
                )
            activity_id = storage_uuid(
                "tbl_WorkMaintenanceCorrective",
                detail.values.get("FK_WorkMaintenance"),
                "maintenance_activities",
            )
            return await self._update_corrective_activity_from_storage(
                row,
                activity_id,
            )

        activity_source_sheet, activity_source_key = (
            self._preventive_activity_identity(row)
        )
        activity_id = storage_uuid(
            activity_source_sheet,
            activity_source_key,
            "maintenance_activities",
        )
        return await self._import_preventive_report(row, activity_id)

    def _preventive_activity_identity(self, row: SourceRow) -> tuple[str, str]:
        scheduled_source = text(row.values.get("FK_Scheduled_Activities"))
        if (
            scheduled_source
            and scheduled_source in self.by_key["tbl_Scheduled_Activities"]
        ):
            return "tbl_Scheduled_Activities", scheduled_source
        return "Maintenance_Storage", row.key

    async def _import_preventive_report(
        self,
        row: SourceRow,
        activity_id: UUID,
    ) -> list[MappingTarget]:
        values = row.values
        activity = self.context.tables["maintenance_activities"]
        existing = (
            await self.context.session.execute(
                select(activity).where(activity.c.id == activity_id)
            )
        ).mappings().first()
        report_code = required_text(values.get("InformCode"), "InformCode")
        template_id = await self._template_id(report_code)
        subsystem_id = await self._catalog_id(
            "subsystems",
            "name",
            required_text(values.get("Subsystem"), "Subsystem"),
        )
        project_id = await self._catalog_id(
            "projects",
            "name",
            required_text(values.get("Proyect"), "Proyect"),
        )
        stage_id = await self._catalog_id(
            "stages",
            "name",
            required_text(values.get("Phase"), "Phase"),
        )
        system_id = await self._catalog_id(
            "systems",
            "name",
            required_text(values.get("System"), "System"),
        )
        location_id, location_path = await self._location_from_snapshot(values)
        started_at = localized(combine_date_time(values.get("Date"), values.get("HourInit")))
        ended_at = localized(combine_date_time(values.get("DateEnd"), values.get("HourEnd")))
        creator_id = await self._resolve_user(
            name=values.get("UserCreation"),
            email=values.get("EmailUserCreation"),
        )
        title = text(values.get("Activity")) or report_code

        activity_values = {
            "id": activity_id,
            "legacy_id": integer(row.key) if row.key.isdigit() else None,
            "activity_type": "PREVENTIVE",
            "status": "COMPLETED",
            "project_id": project_id,
            "primary_stage_id": stage_id,
            "subsystem_id": subsystem_id,
            "geographic_location_id": location_id,
            "maintenance_template_id": template_id,
            "title": title,
            "internal_code": (
                existing["internal_code"]
                if existing
                else f"LEGACY-PREV-EXEC-{row.key}"
            ),
            "scheduled_start_at": existing["scheduled_start_at"] if existing else started_at,
            "scheduled_end_at": existing["scheduled_end_at"] if existing else ended_at,
            "actual_start_at": started_at,
            "actual_end_at": ended_at,
            "shift": existing["shift"] if existing else None,
            "sap_order": existing["sap_order"] if existing else None,
            "work_order": text(values.get("Code")) or (
                existing["work_order"] if existing else None
            ),
            "location_path_snapshot": location_path,
            "created_by_user_id": creator_id,
            "completed_by_user_id": creator_id,
            "closed_by_user_id": None,
            "completed_at": ended_at,
            "closed_at": None,
        }
        await self.context.upsert("maintenance_activities", activity_values)

        activity_source_sheet, activity_source_key = (
            self._preventive_activity_identity(row)
        )
        report_id = storage_uuid(
            activity_source_sheet,
            activity_source_key,
            "maintenance_reports",
            "PREVENTIVE_MAIN",
        )
        version_id = storage_uuid(row.sheet, row.key, "report_versions")
        await self.context.upsert(
            "maintenance_reports",
            {
                "id": report_id,
                "legacy_id": None,
                "maintenance_activity_id": activity_id,
                "report_kind": "PREVENTIVE_MAIN",
                "report_number": 1,
                "shift_label": None,
                "status": "FINALIZED",
                "created_by_user_id": creator_id,
            },
        )
        await self.context.upsert(
            "report_versions",
            {
                "id": version_id,
                "legacy_id": None,
                "maintenance_report_id": report_id,
                "version_number": self.preventive_version_numbers[row.key],
                "document_status": "FINALIZED",
                "summary": "Versión importada desde Power Apps.",
                "stop_after_block_order": None,
                "source_version_id": None,
                "created_by_user_id": creator_id,
                "finalized_by_user_id": creator_id,
                "finalized_at": localized(parse_datetime(values.get("RealFinishedAt_Hour")))
                or ended_at,
                "data_snapshot": None,
            },
        )
        actual_date = parse_date(values.get("Date"))
        if actual_date is None or started_at is None:
            raise RowImportError("Preventive report requires execution date and start time")
        await self.context.upsert(
            "preventive_report_details",
            {
                "report_version_id": version_id,
                "site_id": await self._catalog_id(
                    "sites",
                    "name",
                    required_text(values.get("Site"), "Site"),
                ),
                "project_id": project_id,
                "stage_id": stage_id,
                "system_id": system_id,
                "subsystem_id": subsystem_id,
                "geographic_location_id": location_id,
                "location_path_snapshot": location_path,
                "actual_date": actual_date,
                "activity_started_at": started_at,
                "activity_ended_at": ended_at,
                "final_result": text(values.get("Conclusion")),
                "additional_comments": text(values.get("AditionalComments")),
            },
            conflict_columns=("report_version_id",),
        )
        targets = [
            MappingTarget("maintenance_activities", str(activity_id)),
            MappingTarget("maintenance_reports", str(report_id), "REPORT"),
            MappingTarget("report_versions", str(version_id), "VERSION"),
            MappingTarget(
                "preventive_report_details",
                str(version_id),
                "PREVENTIVE_DETAIL",
            ),
        ]
        scheduled_source = text(values.get("FK_Scheduled_Activities"))
        if (
            scheduled_source
            and scheduled_source in self.by_key["tbl_Scheduled_Activities"]
        ):
            schedule_id = storage_string_id(
                "tbl_Scheduled_Activities",
                scheduled_source,
                "preventive_schedules",
            )
            schedules = self.context.tables["preventive_schedules"]
            await self.context.session.execute(
                schedules.update()
                .where(schedules.c.id == schedule_id)
                .values(status="COMPLETED", report_version_count=1)
            )
        return targets

    async def _update_corrective_activity_from_storage(
        self,
        row: SourceRow,
        activity_id: UUID,
    ) -> list[MappingTarget]:
        values = row.values
        started_at = localized(combine_date_time(values.get("Date"), values.get("HourInit")))
        ended_at = localized(combine_date_time(values.get("DateEnd"), values.get("HourEnd")))
        creator_id = await self._resolve_user(
            name=values.get("UserCreation"),
            email=values.get("EmailUserCreation"),
        )
        activities = self.context.tables["maintenance_activities"]
        await self.context.session.execute(
            activities.update()
            .where(activities.c.id == activity_id)
            .values(
                status="COMPLETED",
                actual_start_at=started_at,
                actual_end_at=ended_at,
                completed_at=ended_at,
                completed_by_user_id=creator_id,
                created_by_user_id=creator_id,
            )
        )
        return [MappingTarget("maintenance_activities", str(activity_id))]

    async def _import_corrective_detail(self, row: SourceRow) -> list[MappingTarget]:
        values = row.values
        work_key = identifier(values.get("FK_WorkMaintenance"))
        activity_id = storage_uuid(
            "tbl_WorkMaintenanceCorrective",
            work_key,
            "maintenance_activities",
        )
        event_id = storage_string_id(
            "tbl_WorkMaintenanceCorrective",
            work_key,
            "corrective_events",
        )
        creator_id = await self._resolve_user(
            name=values.get("UserCreationReport"),
            email=values.get("EmailCreationReport"),
        )
        asset_id = wbs_string_id(
            "tbl_Equipment",
            values.get("2_FK_EquipmentReal") or values.get("1_FK_EquipmentReported"),
            "assets",
        )
        if values.get("2_SubsystemID") is not None:
            subsystem_id = wbs_uuid(
                "tbl_Subsystem",
                values.get("2_SubsystemID"),
                "subsystems",
            )
        else:
            subsystem_id = await self._catalog_id(
                "subsystems",
                "name",
                required_text(values.get("1_SubsystemSAP"), "1_SubsystemSAP"),
            )
        location_id = self._wbs_area_id(values.get("1_FK_AreaN4"))
        location_path = " / ".join(
            item
            for item in (
                text(values.get("1_AreaN1")),
                text(values.get("1_AreaN2")),
                text(values.get("1_AreaN3")),
                text(values.get("1_AreaN4")),
            )
            if item
        )
        notice_at = localized(
            combine_date_time(
                values.get("1_DateCreationNotification"),
                values.get("1_HourCreationNotification"),
            )
        )
        response_at = localized(
            optional_combine_date_time(
                values.get("8_ResponseDate"),
                values.get("8_ResponseHour"),
            )
        )
        corrective_started = localized(
            optional_combine_date_time(
                values.get("8_StartCorrectiveServiceDate"),
                values.get("8_StartCorrectiveServiceHour"),
            )
        )
        corrective_ended = localized(
            optional_combine_date_time(
                values.get("8_EndCorrectiveServiceDate"),
                values.get("8_EndCorrectiveServiceHour"),
            )
        )
        title = required_text(values.get("1_NameSAP"), "1_NameSAP")

        activities = self.context.tables["maintenance_activities"]
        await self.context.session.execute(
            activities.update()
            .where(activities.c.id == activity_id)
            .values(
                subsystem_id=subsystem_id,
                geographic_location_id=location_id,
                title=title,
                sap_order=text(values.get("1_CodeSAP")),
                location_path_snapshot=location_path,
                actual_start_at=corrective_started,
                actual_end_at=corrective_ended,
                completed_at=corrective_ended,
                created_by_user_id=creator_id,
                completed_by_user_id=creator_id,
            )
        )
        await self.context.upsert(
            "corrective_events",
            {
                "id": event_id,
                "code": f"COR-{work_key}",
                "sap_code": text(values.get("1_CodeSAP")) or "-",
                "name": title,
                "affected_asset_id": asset_id,
                "affected_asset_path": await self._asset_path(asset_id),
                "subsystem": (
                    text(values.get("2_SubsystemReal"))
                    or required_text(
                        values.get("1_SubsystemSAP"),
                        "1_SubsystemSAP",
                    )
                ),
                "severity": "HIGH"
                if boolean(values.get("2_IsCriticalElement"))
                else "MEDIUM",
                "status": "COMPLETED",
                "notice_created_at": notice_at.isoformat() if notice_at else "",
                "response_at": response_at.isoformat() if response_at else "",
                "physical_location": location_path,
                "report_version_count": integer(values.get("NumReport")) or 1,
                "timeline": [],
                "legacy_id": None,
                "maintenance_activity_id": activity_id,
                "primary_asset_id": asset_id,
                "subsystem_id": subsystem_id,
                "created_by_user_id": creator_id,
                "failure_description": text(values.get("3_RecordedSymptomSAP")),
                "operational_impact": text(values.get("3_OperationalImpact")),
            },
        )
        activity_asset_id = stable_uuid(
            STORAGE_SOURCE,
            "maintenance_activity_assets",
            activity_id,
            asset_id,
            "AFFECTED",
        )
        await self.context.upsert(
            "maintenance_activity_assets",
            {
                "id": activity_asset_id,
                "maintenance_activity_id": activity_id,
                "asset_id": asset_id,
                "role": "AFFECTED",
                "include_descendants": True,
                "notes": None,
            },
            conflict_columns=("maintenance_activity_id", "asset_id", "role"),
        )
        report_id = storage_uuid(row.sheet, row.key, "maintenance_reports")
        version_id = storage_uuid(row.sheet, row.key, "report_versions")
        report_number = integer(values.get("NumReport")) or 1
        await self.context.upsert(
            "maintenance_reports",
            {
                "id": report_id,
                "legacy_id": None,
                "maintenance_activity_id": activity_id,
                "report_kind": "CORRECTIVE",
                "report_number": report_number,
                "shift_label": f"Turno {report_number}",
                "status": "FINALIZED",
                "created_by_user_id": creator_id,
            },
        )
        await self.context.upsert(
            "report_versions",
            {
                "id": version_id,
                "legacy_id": None,
                "maintenance_report_id": report_id,
                "version_number": 1,
                "document_status": "FINALIZED",
                "summary": "Versión importada desde Power Apps.",
                "stop_after_block_order": integer(values.get("EndReportPoint")),
                "source_version_id": None,
                "created_by_user_id": creator_id,
                "finalized_by_user_id": creator_id,
                "finalized_at": localized(parse_datetime(values.get("RealFinishedDate")))
                or corrective_ended,
                "data_snapshot": None,
            },
        )
        await self.context.upsert(
            "corrective_report_details",
            {
                "report_version_id": version_id,
                "corrective_event_id": event_id,
                "symptom": text(values.get("3_RecordedSymptomSAP")),
                "technical_description": text(values.get("3_TechDescription")),
                "operational_impact": text(values.get("3_OperationalImpact")),
                "failure_analysis_type": text(values.get("4_FailureType")),
                "functional_tests": text(values.get("7_FunctionalTest")),
                "validation_result": text(values.get("7_ResultTest")),
                "service_released": boolean(values.get("7_ReleasedService")),
                "service_released_at": localized(
                    combine_date_time(
                        values.get("8_LiberationDate"),
                        values.get("8_LiberationHour"),
                    )
                ),
                "validation_responsible_snapshot": text(
                    values.get("7_ResponsibleValidation")
                ),
                "technical_status": text(values.get("9_Conclusion")),
                "conclusion": text(values.get("9_Conclusion")),
                "additional_comments": text(values.get("9_AditionalComments")),
                "response_at": response_at,
                "corrective_started_at": corrective_started,
                "corrective_ended_at": corrective_ended,
            },
            conflict_columns=("report_version_id",),
        )
        await self._upsert_corrective_blocks(row, version_id)
        return [
            MappingTarget("corrective_events", event_id, "EVENT"),
            MappingTarget("maintenance_reports", str(report_id), "REPORT"),
            MappingTarget("report_versions", str(version_id), "VERSION"),
            MappingTarget("corrective_report_details", str(version_id), "DETAIL"),
            MappingTarget("maintenance_activity_assets", str(activity_asset_id), "ASSET"),
        ]

    async def _upsert_corrective_blocks(
        self,
        row: SourceRow,
        version_id: UUID,
    ) -> None:
        values = row.values
        blocks = (
            ("SYMPTOM", "Síntoma registrado", values.get("3_RecordedSymptomSAP")),
            ("TECHNICAL_DESCRIPTION", "Descripción técnica", values.get("3_TechDescription")),
            ("FAILURE_ANALYSIS", "Análisis de falla", values.get("4_FailureType")),
            ("FUNCTIONAL_TESTS", "Pruebas funcionales", values.get("7_FunctionalTest")),
            ("CONCLUSION", "Conclusión", values.get("9_Conclusion")),
        )
        for sequence, (block_type, title, content) in enumerate(blocks, start=1):
            block_id = storage_uuid(
                row.sheet,
                row.key,
                "corrective_report_blocks",
                block_type,
            )
            await self.context.upsert(
                "corrective_report_blocks",
                {
                    "id": block_id,
                    "report_version_id": version_id,
                    "block_type": block_type,
                    "title": title,
                    "sequence": sequence,
                    "payload": {"contenido": text(content)},
                    "is_visible": text(content) is not None,
                },
            )

    async def _import_corrective_activity(self, row: SourceRow) -> list[MappingTarget]:
        values = row.values
        version_id = self._report_version_for_maintenance(
            values.get("FK_MaintenanceStorage")
        )
        sequence = integer(values.get("Order")) or 0
        record_id = stable_uuid(
            STORAGE_SOURCE,
            "corrective_activities",
            version_id,
            sequence,
        )
        await self.context.upsert(
            "corrective_activities",
            {
                "id": record_id,
                "legacy_id": None,
                "report_version_id": version_id,
                "maintenance_action_type_id": wbs_uuid(
                    "tbl_TypeActivity",
                    values.get("FK_TypeActivity"),
                    "maintenance_action_types",
                ),
                "name": required_text(values.get("NameActivity"), "NameActivity"),
                "description": required_text(values.get("Description"), "Description"),
                "notes": None,
                "started_at": localized(
                    combine_date_time(values.get("DateIni"), values.get("HourIni"))
                )
                or datetime.now(UTC),
                "ended_at": localized(
                    combine_date_time(values.get("DateEnd"), values.get("HourEnd"))
                ),
                "sequence": sequence,
            },
            conflict_columns=("report_version_id", "sequence"),
        )
        return [MappingTarget("corrective_activities", str(record_id))]

    async def _import_participant(self, row: SourceRow) -> list[MappingTarget]:
        values = row.values
        maintenance_key = values.get("FK_Maintenance_Storage")
        version_id = self._report_version_for_maintenance(maintenance_key)
        if not await self._report_version_exists(version_id):
            version_id = await self._ensure_orphan_report_version(maintenance_key)
        user_id = await self.context.mapped_target_id(
            source_table="tbl_Worker",
            source_key=identifier(values.get("FK_Worker")),
            target_table="users",
        )
        if user_id is None:
            user_id = wbs_string_id(
                "tbl_Worker",
                values.get("FK_Worker"),
                "users",
            )
        users = self.context.tables["users"]
        user = (
            await self.context.session.execute(
                select(users.c.role_label).where(users.c.id == user_id)
            )
        ).first()
        if user is None:
            raise RowImportError(
                f"Worker {values.get('FK_Worker')} was not imported from WBS"
            )
        record_id = storage_uuid(row.sheet, row.key, "report_participants")
        await self.context.upsert(
            "report_participants",
            {
                "id": record_id,
                "legacy_id": None,
                "report_version_id": version_id,
                "user_id": user_id,
                "role_snapshot": user.role_label,
                "selected": True,
            },
        )
        return [MappingTarget("report_participants", str(record_id))]

    async def _import_tool_usage(self, row: SourceRow) -> list[MappingTarget]:
        values = row.values
        version_id = self._report_version_for_maintenance(
            values.get("FK_Maintenance_Storage")
        )
        tool_id = wbs_uuid("tbl_Tool", values.get("FK_Tool"), "tools")
        certification_id = (
            wbs_uuid(
                "tbl_Certification",
                values.get("FK_Certification"),
                "tool_certifications",
            )
            if values.get("FK_Certification") is not None
            else None
        )
        record_id = storage_uuid(row.sheet, row.key, "report_tool_usages")
        await self.context.upsert(
            "report_tool_usages",
            {
                "id": record_id,
                "legacy_id": None,
                "report_version_id": version_id,
                "tool_id": tool_id,
                "certification_id": certification_id,
                "used_at": await self._version_created_at(version_id),
            },
        )
        return [MappingTarget("report_tool_usages", str(record_id))]

    async def _import_step_result(self, row: SourceRow) -> list[MappingTarget]:
        values = row.values
        maintenance_key = values.get("ID_Maintenance_Storage")
        version_id = self._report_version_for_maintenance(maintenance_key)
        template_id = await self._template_for_version(version_id)
        template_step_id = await self._template_step_id(
            template_id,
            values.get("Task"),
        )
        record_id = storage_uuid(row.sheet, row.key, "preventive_step_results")
        steps = self.context.tables["maintenance_template_steps"]
        template_step = (
            await self.context.session.execute(
                select(
                    steps.c.title,
                    steps.c.manual_page,
                    steps.c.sequence,
                ).where(steps.c.id == template_step_id)
            )
        ).mappings().one()
        await self.context.upsert(
            "preventive_step_results",
            {
                "id": record_id,
                "legacy_id": None,
                "report_version_id": version_id,
                "template_step_id": template_step_id,
                "is_completed": boolean(values.get("Check"), default=True),
                "comment": text(values.get("Comment")),
                "manual_page_snapshot": template_step["manual_page"],
                "sequence_snapshot": template_step["sequence"],
                "title_snapshot": template_step["title"],
            },
        )
        return [MappingTarget("preventive_step_results", str(record_id))]

    async def _import_test_result(self, row: SourceRow) -> list[MappingTarget]:
        values = row.values
        source_task_key = required_text(
            values.get("FK_Tasks_activity"),
            "FK_Tasks_activity",
        )
        step_result_id = storage_uuid(
            "Tasks_activity",
            source_task_key,
            "preventive_step_results",
        )
        step_results = self.context.tables["preventive_step_results"]
        if (
            await self.context.session.scalar(
                select(step_results.c.id).where(
                    step_results.c.id == step_result_id
                )
            )
            is None
        ):
            maintenance_key = source_task_key.rsplit("_", maxsplit=1)[0]
            version_id = self._report_version_for_maintenance(maintenance_key)
            if not await self._report_version_exists(version_id):
                version_id = await self._ensure_orphan_report_version(
                    maintenance_key
                )
            template_step_id = wbs_uuid(
                "tbl_Activity_Task",
                values.get("FK_Activity_Task"),
                "maintenance_template_steps",
            )
            template_steps = self.context.tables["maintenance_template_steps"]
            template_step = (
                await self.context.session.execute(
                    select(
                        template_steps.c.title,
                        template_steps.c.manual_page,
                        template_steps.c.sequence,
                    ).where(template_steps.c.id == template_step_id)
                )
            ).mappings().one()
            await self.context.upsert(
                "preventive_step_results",
                {
                    "id": step_result_id,
                    "legacy_id": None,
                    "report_version_id": version_id,
                    "template_step_id": template_step_id,
                    "is_completed": True,
                    "comment": (
                        "Paso histórico reconstruido porque la fila de tarea "
                        "no estaba en el Excel de origen."
                    ),
                    "manual_page_snapshot": template_step["manual_page"],
                    "sequence_snapshot": template_step["sequence"],
                    "title_snapshot": template_step["title"],
                },
            )
        template_test_id = wbs_uuid(
            "tbl_Test_Task",
            values.get("FK_Test_Task"),
            "maintenance_template_tests",
        )
        record_id = storage_uuid(row.sheet, row.key, "preventive_test_results")
        await self.context.upsert(
            "preventive_test_results",
            {
                "id": record_id,
                "legacy_id": None,
                "step_result_id": step_result_id,
                "template_test_id": template_test_id,
                "name_snapshot": required_text(values.get("Name_Test"), "Name_Test"),
                "selected_result": required_text(values.get("Result"), "Result"),
                "numeric_value": None,
                "notes": None,
            },
        )
        return [MappingTarget("preventive_test_results", str(record_id))]

    async def _import_attachment(self, row: SourceRow) -> list[MappingTarget]:
        values = row.values
        maintenance_key = values.get("ID_Activity")
        version_id = self._report_version_for_maintenance(maintenance_key)
        if not await self._report_version_exists(version_id):
            version_id = await self._ensure_orphan_report_version(maintenance_key)
        record_id = storage_uuid(row.sheet, row.key, "attachments")
        file_reference = text(values.get("Path_URL")) or text(values.get("Path_image"))
        if file_reference is None:
            raise RowImportError("Image row does not contain a file reference")
        await self.context.upsert(
            "attachments",
            {
                "id": record_id,
                "legacy_id": integer(row.key) if row.key.isdigit() else None,
                "report_version_id": version_id,
                "preventive_step_result_id": None,
                "corrective_activity_id": None,
                "attachment_type": "IMAGE",
                "file_reference": file_reference,
                "original_file_name": text(values.get("Name_image")),
                "media_type": None,
                "title": text(values.get("Title")),
                "description": None,
                "captured_at": await self._version_created_at(version_id),
                "uploaded_by_user_id": await self._version_creator(version_id),
                "checksum": None,
                "file_size_bytes": None,
            },
        )
        return [MappingTarget("attachments", str(record_id))]

    async def _import_generated_report(self, row: SourceRow) -> list[MappingTarget]:
        values = row.values
        report_type = normalize_key(values.get("Report_Type"))
        maintenance_key = required_text(
            values.get("FK_Maintenance_Storage"),
            "FK_Maintenance_Storage",
        )
        if "calib" in report_type or row.key in self.calibration_by_report:
            calibration_source_key = (
                self.calibration_report_source_by_maintenance.get(maintenance_key)
            )
            if calibration_source_key is None:
                raise RowImportError(
                    "Calibration file does not have calibration detail rows for "
                    f"maintenance {maintenance_key}"
                )
            version_id = storage_uuid(
                "tbl_Reports",
                calibration_source_key,
                "report_versions",
                "CALIBRATION",
            )
        else:
            version_id = self._report_version_for_maintenance(maintenance_key)
            if not await self._report_version_exists(version_id):
                version_id = await self._ensure_orphan_report_version(
                    maintenance_key
                )
        creator_id = await self._version_creator(version_id)
        record_id = storage_uuid(row.sheet, row.key, "generated_reports")
        await self.context.upsert(
            "generated_reports",
            {
                "id": record_id,
                "legacy_id": None,
                "report_version_id": version_id,
                "file_reference": text(values.get("URL_File"))
                or required_text(values.get("Path_File"), "Path_File"),
                "path": text(values.get("Path_File")),
                "file_name": text(values.get("Name_File")) or f"{row.key}.pdf",
                "file_format": text(values.get("Format")) or "pdf",
                "file_size_bytes": None,
                "generated_at": await self._version_created_at(version_id),
                "generated_by_user_id": creator_id,
                "checksum": None,
                "is_regenerated": False,
            },
        )
        return [MappingTarget("generated_reports", str(record_id))]

    async def _import_calibration(self, row: SourceRow) -> list[MappingTarget]:
        values = row.values
        report_source_key = required_text(values.get("FK_Report"), "FK_Report")
        maintenance_key = required_text(
            values.get("FK_Maintenance_Storage"),
            "FK_Maintenance_Storage",
        )
        main_version_id = self._report_version_for_maintenance(maintenance_key)
        main_reports = self.context.tables["report_versions"]
        main_version = (
            await self.context.session.execute(
                select(
                    main_reports.c.created_by_user_id,
                    main_reports.c.finalized_at,
                ).where(main_reports.c.id == main_version_id)
            )
        ).mappings().first()
        if main_version is None:
            raise RowImportError(
                f"Preventive report for calibration maintenance {maintenance_key} is missing"
            )
        activities = self.context.tables["maintenance_reports"]
        main_report = self.context.tables["report_versions"]
        activity_id = await self.context.session.scalar(
            select(activities.c.maintenance_activity_id)
            .join(
                main_report,
                main_report.c.maintenance_report_id == activities.c.id,
            )
            .where(main_report.c.id == main_version_id)
        )
        maintenance_row = self.by_key["Maintenance_Storage"].get(maintenance_key)
        if maintenance_row is None:
            raise RowImportError(
                f"Calibration maintenance does not exist: {maintenance_key}"
            )
        activity_source_sheet, activity_source_key = (
            self._preventive_activity_identity(maintenance_row)
        )
        report_id = storage_uuid(
            activity_source_sheet,
            activity_source_key,
            "maintenance_reports",
            "CALIBRATION",
        )
        version_id = storage_uuid(
            "tbl_Reports",
            report_source_key,
            "report_versions",
            "CALIBRATION",
        )
        creator_id = main_version["created_by_user_id"]
        await self.context.upsert(
            "maintenance_reports",
            {
                "id": report_id,
                "legacy_id": None,
                "maintenance_activity_id": activity_id,
                "report_kind": "CALIBRATION",
                "report_number": 1,
                "shift_label": None,
                "status": "FINALIZED",
                "created_by_user_id": creator_id,
            },
        )
        await self.context.upsert(
            "report_versions",
            {
                "id": version_id,
                "legacy_id": None,
                "maintenance_report_id": report_id,
                "version_number": self.calibration_version_numbers[
                    report_source_key
                ],
                "document_status": "FINALIZED",
                "summary": "Calibración importada desde Power Apps.",
                "stop_after_block_order": None,
                "source_version_id": None,
                "created_by_user_id": creator_id,
                "finalized_by_user_id": creator_id,
                "finalized_at": main_version["finalized_at"],
                "data_snapshot": None,
            },
        )
        track_asset_id = await self._find_asset(values.get("CDV"))
        calibration_date = parse_date(values.get("Date_Calibration"))
        if calibration_date is None:
            raise RowImportError("Calibration date is required")
        await self.context.upsert(
            "calibration_report_details",
            {
                "report_version_id": version_id,
                "legacy_id": None,
                "track_circuit_asset_id": track_asset_id,
                "frequency": text(values.get("Frequency")),
                "calibration_date": calibration_date,
                "location_snapshot": required_text(values.get("Location"), "Location"),
                "track_circuit_type": text(values.get("Type_CDV")),
                "track_circuit_number": text(values.get("Number_CDV")),
                "jumpers": None,
                "rail_current": None,
                "tca9": None,
            },
            conflict_columns=("report_version_id",),
        )
        measurement_targets: list[MappingTarget] = []
        measurements = (
            ("FREQUENCY", "Frecuencia", values.get("Frequency"), "Hz"),
            ("JUMPERS", "Jumpers", values.get("Jumpers"), None),
            ("RAIL_CURRENT", "Corriente de riel", values.get("Rail_Current"), "mA"),
            ("TCA9", "TCA9", values.get("TCA9"), None),
        )
        role = (text(values.get("Type_CDV")) or "Equipo").upper()
        sequence_base = self.calibration_row_sequences[row.key]
        for offset, (measurement_role, name, measured_value, unit) in enumerate(
            measurements
        ):
            measurement_id = storage_uuid(
                row.sheet,
                row.key,
                "calibration_measurements",
                measurement_role,
            )
            await self.context.upsert(
                "calibration_measurements",
                {
                    "id": measurement_id,
                    "report_version_id": version_id,
                    "asset_id": track_asset_id,
                    "asset_role": role,
                    "measurement_name": name,
                    "measured_value": text(measured_value, none_values=()),
                    "unit": unit,
                    "result": None,
                    "notes": None,
                    "sequence": sequence_base * 10 + offset,
                },
            )
            measurement_targets.append(
                MappingTarget(
                    "calibration_measurements",
                    str(measurement_id),
                    measurement_role,
                )
            )
        return [
            MappingTarget("maintenance_reports", str(report_id), "CALIBRATION_REPORT"),
            MappingTarget("report_versions", str(version_id), "CALIBRATION_VERSION"),
            MappingTarget(
                "calibration_report_details",
                str(version_id),
                "CALIBRATION_DETAIL",
            ),
            *measurement_targets,
        ]

    async def _import_asset_movement(self, row: SourceRow) -> list[MappingTarget]:
        values = row.values
        record_id = storage_uuid(row.sheet, row.key, "asset_movements")
        maintenance_activity_id = await self._activity_for_maintenance(
            values.get("FK_Maintenance")
        )
        corrective_activity_id = None
        if values.get("FK_CorrectiveActivities") is not None:
            corrective_activity_id = await self.context.mapped_target_id(
                source_table="tbl_CorrectiveActivities",
                source_key=identifier(values.get("FK_CorrectiveActivities")),
                target_table="corrective_activities",
            )
            if corrective_activity_id is None:
                raise RowImportError(
                    "Corrective activity was not imported: "
                    f"{values.get('FK_CorrectiveActivities')}"
                )
        await self.context.upsert(
            "asset_movements",
            {
                "id": record_id,
                "legacy_id": None,
                "asset_id": wbs_string_id(
                    "tbl_Component",
                    values.get("FK_Component"),
                    "assets",
                ),
                "movement_type_id": wbs_uuid(
                    "tbl_MovementType",
                    values.get("FK_MovementType"),
                    "movement_types",
                ),
                "from_inventory_location_id": self._optional_wbs_uuid(
                    "tbl_Location",
                    values.get("FK_FromLocation"),
                    "inventory_locations",
                ),
                "to_inventory_location_id": self._optional_wbs_uuid(
                    "tbl_Location",
                    values.get("FK_ToLocation"),
                    "inventory_locations",
                ),
                "from_slot_location_id": self._optional_wbs_uuid(
                    "tbl_SlotLocation",
                    values.get("FK_FromSlotLocation"),
                    "slot_locations",
                ),
                "to_slot_location_id": self._optional_wbs_uuid(
                    "tbl_SlotLocation",
                    values.get("FK_ToSlotLocation"),
                    "slot_locations",
                ),
                "from_status_id": None,
                "to_status_id": self._optional_wbs_uuid(
                    "tbl_ComponentStatus",
                    values.get("FK_StatusComponent"),
                    "asset_statuses",
                ),
                "moved_at": localized(parse_datetime(values.get("MovedAt")))
                or datetime.now(UTC),
                "moved_by_user_id": await self._activity_creator(
                    maintenance_activity_id
                ),
                "maintenance_activity_id": maintenance_activity_id,
                "corrective_activity_id": corrective_activity_id,
                "notes": text(values.get("Notes")),
                "movement_key": f"{row.key}:{text(values.get('MovementKey')) or '0'}",
            },
        )
        return [MappingTarget("asset_movements", str(record_id))]

    async def _import_replacement(self, row: SourceRow) -> list[MappingTarget]:
        values = row.values
        group_key = (
            identifier(values.get("FK_Maintenance")),
            identifier(values.get("FK_CorrectiveActivities")),
            identifier(values.get("FK_Equipment")),
        )
        group = self.work_order_groups[group_key]
        removed = next(
            (
                candidate
                for candidate in group
                if "retir" in normalize_key(candidate.values.get("MovementTypeName"))
            ),
            None,
        )
        installed = next(
            (
                candidate
                for candidate in group
                if "instal" in normalize_key(candidate.values.get("MovementTypeName"))
            ),
            None,
        )
        if removed is None or installed is None:
            raise RowImportError(
                "Replacement group must contain one removed and one installed component"
            )
        replacement_id = stable_uuid(
            STORAGE_SOURCE,
            "replacement",
            *group_key,
        )
        maintenance_activity_id = await self._activity_for_maintenance(group_key[0])
        report_version_id = self._report_version_for_maintenance(group_key[0])
        corrective_activity_id = await self.context.mapped_target_id(
            source_table="tbl_CorrectiveActivities",
            source_key=group_key[1],
            target_table="corrective_activities",
        )
        if corrective_activity_id is None:
            raise RowImportError(
                f"Corrective activity was not imported: {group_key[1]}"
            )
        parent_asset_id = wbs_string_id(
            "tbl_Equipment",
            values.get("FK_Equipment"),
            "assets",
        )
        removed_asset_id = wbs_string_id(
            "tbl_Component",
            removed.values.get("FK_Component"),
            "assets",
        )
        installed_asset_id = wbs_string_id(
            "tbl_Component",
            installed.values.get("FK_Component"),
            "assets",
        )
        movement = next(
            (
                candidate
                for candidate in self.rows["tbl_ComponentMovement"]
                if identifier(candidate.values.get("FK_Component"))
                == identifier(removed.values.get("FK_Component"))
                and identifier(candidate.values.get("FK_Maintenance")) == group_key[0]
            ),
            None,
        )
        slot_source = (
            movement.values.get("FK_FromSlotLocation") if movement else None
        )
        slot_id = self._optional_wbs_uuid(
            "tbl_SlotLocation",
            slot_source,
            "slot_locations",
        )
        position = await self._slot_name(slot_id) if slot_id else "Posición no registrada"
        replaced_at = localized(parse_datetime(values.get("DateAction"))) or datetime.now(
            UTC
        )
        await self.context.upsert(
            "asset_replacements",
            {
                "id": replacement_id,
                "legacy_id": None,
                "removed_asset_id": removed_asset_id,
                "installed_asset_id": installed_asset_id,
                "parent_asset_id": parent_asset_id,
                "slot_location_id": slot_id,
                "position_snapshot": position,
                "source_description": "Almacén de mantenimiento",
                "destination_description": "Almacén o reparación",
                "replaced_at": replaced_at,
                "responsible_user_id": await self._activity_creator(
                    maintenance_activity_id
                ),
                "maintenance_activity_id": maintenance_activity_id,
                "report_version_id": report_version_id,
                "corrective_activity_id": corrective_activity_id,
                "removed_condition": text(
                    removed.values.get("StatusComponentName")
                ),
                "installed_condition": text(
                    installed.values.get("StatusComponentName")
                ),
                "reason": text(values.get("Notes"))
                or "Reemplazo de componente registrado en Power Apps.",
            },
        )
        role = (
            "REMOVED_SOURCE"
            if row.key == removed.key
            else "INSTALLED_SOURCE"
        )
        return [MappingTarget("asset_replacements", str(replacement_id), role)]

    async def _import_installed_component(self, row: SourceRow) -> list[MappingTarget]:
        values = row.values
        record_id = storage_uuid(row.sheet, row.key, "asset_assignments")
        slot_id = self._optional_wbs_uuid(
            "tbl_SlotLocation",
            values.get("FK_SlotLocation"),
            "slot_locations",
        )
        await self.context.upsert(
            "asset_assignments",
            {
                "id": record_id,
                "legacy_id": None,
                "asset_id": wbs_string_id(
                    "tbl_Component",
                    values.get("FK_Component"),
                    "assets",
                ),
                "parent_asset_id": wbs_string_id(
                    "tbl_Equipment",
                    values.get("FK_Equipment"),
                    "assets",
                ),
                "slot_location_id": slot_id,
                "geographic_location_id": None,
                "position_snapshot": await self._slot_name(slot_id)
                if slot_id
                else None,
                "assigned_at": localized(parse_datetime(values.get("InstalledAt")))
                or datetime.now(UTC),
                "unassigned_at": localized(parse_datetime(values.get("RemovedAt"))),
                "reason": "Instalación importada desde Power Apps.",
                "source_report_version_id": self._report_version_for_maintenance(
                    values.get("FK_Maintenance")
                ),
            },
        )
        return [MappingTarget("asset_assignments", str(record_id))]

    def _report_version_for_maintenance(self, source_key: Any) -> UUID:
        key = identifier(source_key)
        detail = self.corrective_detail_by_maintenance.get(key)
        if detail is not None:
            return storage_uuid(
                "tbl_CorrectiveReports_Detail",
                detail.key,
                "report_versions",
            )
        return storage_uuid("Maintenance_Storage", key, "report_versions")

    async def _report_version_exists(self, version_id: UUID) -> bool:
        versions = self.context.tables["report_versions"]
        return (
            await self.context.session.scalar(
                select(versions.c.id).where(versions.c.id == version_id)
            )
            is not None
        )

    async def _ensure_orphan_report_version(self, source_key: Any) -> UUID:
        key = identifier(source_key)
        activity_id = storage_uuid(
            "Maintenance_Storage",
            key,
            "maintenance_activities",
        )
        report_id = storage_uuid(
            "Maintenance_Storage",
            key,
            "maintenance_reports",
            "ORPHAN",
        )
        version_id = self._report_version_for_maintenance(key)
        creator_id = await self._fallback_user()
        await self.context.upsert(
            "maintenance_activities",
            {
                "id": activity_id,
                "legacy_id": None,
                "activity_type": "CORRECTIVE",
                "status": "COMPLETED",
                "project_id": await self._first_id("projects"),
                "primary_stage_id": await self._first_id("stages"),
                "subsystem_id": await self._first_id("subsystems"),
                "geographic_location_id": None,
                "maintenance_template_id": None,
                "title": f"Registro histórico incompleto {key}",
                "internal_code": f"LEGACY-ORPHAN-{key}",
                "scheduled_start_at": None,
                "scheduled_end_at": None,
                "actual_start_at": None,
                "actual_end_at": None,
                "shift": None,
                "sap_order": None,
                "work_order": None,
                "location_path_snapshot": None,
                "created_by_user_id": creator_id,
                "completed_by_user_id": creator_id,
                "closed_by_user_id": None,
                "completed_at": None,
                "closed_at": None,
            },
        )
        await self.context.upsert(
            "maintenance_reports",
            {
                "id": report_id,
                "legacy_id": None,
                "maintenance_activity_id": activity_id,
                "report_kind": "CORRECTIVE",
                "report_number": 1,
                "shift_label": None,
                "status": "FINALIZED",
                "created_by_user_id": creator_id,
            },
        )
        await self.context.upsert(
            "report_versions",
            {
                "id": version_id,
                "legacy_id": None,
                "maintenance_report_id": report_id,
                "version_number": 1,
                "document_status": "FINALIZED",
                "summary": (
                    "Registro creado para conservar archivos históricos cuyo "
                    "mantenimiento de origen ya no está en el Excel."
                ),
                "stop_after_block_order": None,
                "source_version_id": None,
                "created_by_user_id": creator_id,
                "finalized_by_user_id": creator_id,
                "finalized_at": datetime.now(UTC),
                "data_snapshot": {
                    "legacy_import_warning": "ORPHAN_SOURCE_RECORD",
                    "source_maintenance_id": key,
                },
            },
        )
        return version_id

    async def _activity_for_maintenance(self, source_key: Any) -> UUID:
        key = identifier(source_key)
        maintenance = self.by_key["Maintenance_Storage"].get(key)
        if maintenance is None:
            raise RowImportError(f"Unknown maintenance record: {key}")
        detail = self.corrective_detail_by_maintenance.get(key)
        if detail is not None:
            return storage_uuid(
                "tbl_WorkMaintenanceCorrective",
                detail.values.get("FK_WorkMaintenance"),
                "maintenance_activities",
            )
        scheduled_source = maintenance.values.get("FK_Scheduled_Activities")
        if scheduled_source is not None:
            return storage_uuid(
                "tbl_Scheduled_Activities",
                scheduled_source,
                "maintenance_activities",
            )
        return storage_uuid("Maintenance_Storage", key, "maintenance_activities")

    async def _resolve_user(self, *, name: Any, email: Any) -> str:
        users = self.context.tables["users"]
        email_value = text(email)
        name_value = text(name)
        if email_value:
            existing = await self.context.session.scalar(
                select(users.c.id).where(
                    users.c.email == email_value.lower()
                )
            )
            if existing:
                return existing
        if name_value:
            result = await self.context.session.execute(
                select(users.c.id, users.c.name)
            )
            for user_id, candidate_name in result:
                if normalize_key(candidate_name) == normalize_key(name_value):
                    return user_id

        if not name_value and not email_value:
            return await self._fallback_user()
        synthetic_email = email_value.lower() if email_value else (
            f"legacy-{stable_string_id(name_value)[:12]}@invalid.local"
        )
        user_id = stable_string_id(
            STORAGE_SOURCE,
            "user",
            synthetic_email,
        )
        await self.context.upsert(
            "users",
            {
                "id": user_id,
                "name": name_value or synthetic_email,
                "email": synthetic_email,
                "role": "MAINTENANCE_ENGINEER",
                "role_label": "Ingeniero de Mantenimiento",
                "password_hash": "!legacy-import-disabled!",
                "legacy_id": None,
                "work_area_id": None,
                "is_active": True,
                "profile_image_ref": None,
                "default_avatar_key": "person.crop.circle.fill",
            },
        )
        return user_id

    async def _fallback_user(self) -> str:
        users = self.context.tables["users"]
        user_id = await self.context.session.scalar(
            select(users.c.id).order_by(users.c.id).limit(1)
        )
        if user_id is None:
            raise RowImportError("No user is available for imported report ownership")
        return user_id

    async def _catalog_id(self, table_name: str, column: str, value: str) -> UUID:
        table = self.context.tables[table_name]
        result = await self.context.session.execute(select(table.c.id, table.c[column]))
        normalized = normalize_key(value)
        for record_id, candidate in result:
            if normalize_key(candidate) == normalized:
                return record_id
        raise RowImportError(f"{table_name} does not contain {column}={value!r}")

    async def _first_id(self, table_name: str) -> UUID:
        table = self.context.tables[table_name]
        record_id = await self.context.session.scalar(
            select(table.c.id).order_by(table.c.id).limit(1)
        )
        if record_id is None:
            raise RowImportError(f"{table_name} is empty; import WBS_V2 first")
        return record_id

    async def _template_id(self, report_code: str) -> UUID:
        return await self._catalog_id(
            "maintenance_templates",
            "report_code",
            report_code,
        )

    async def _location_path(self, location_id: UUID | None) -> str:
        if location_id is None:
            return ""
        locations = self.context.tables["geographic_locations"]
        return (
            await self.context.session.scalar(
                select(locations.c.full_path).where(locations.c.id == location_id)
            )
        ) or ""

    async def _asset_name(self, asset_id: str) -> str:
        assets = self.context.tables["assets"]
        name = await self.context.session.scalar(
            select(assets.c.name).where(assets.c.id == asset_id)
        )
        if name is None:
            raise RowImportError(f"Asset does not exist: {asset_id}")
        return name

    async def _asset_path(self, asset_id: str) -> str:
        assets = self.context.tables["assets"]
        names: list[str] = []
        current_id: str | None = asset_id
        visited: set[str] = set()
        while current_id and current_id not in visited:
            visited.add(current_id)
            result = (
                await self.context.session.execute(
                    select(assets.c.name, assets.c.parent_id).where(
                        assets.c.id == current_id
                    )
                )
            ).first()
            if result is None:
                break
            names.append(result.name)
            current_id = result.parent_id
        return " / ".join(reversed(names))

    async def _location_from_snapshot(
        self,
        values: dict[str, Any],
    ) -> tuple[UUID, str]:
        parts = [
            item
            for item in (
                text(values.get("AreaN1")),
                text(values.get("AreaN2")),
                text(values.get("AreaN3")),
                text(values.get("AreaN4")),
            )
            if item
        ]
        path = " / ".join(parts)
        locations = self.context.tables["geographic_locations"]
        result = await self.context.session.execute(
            select(locations.c.id, locations.c.full_path)
        )
        normalized = normalize_key(path)
        for location_id, full_path in result:
            if normalize_key(full_path) == normalized:
                return location_id, full_path
        raise RowImportError(f"Unknown geographic location path: {path!r}")

    def _wbs_area_id(self, source_key: Any) -> UUID:
        return stable_uuid(
            WBS_SOURCE,
            "geographic_location",
            normalize_key(self._area_path_from_storage(source_key)),
        )

    def _area_path_from_storage(self, source_key: Any) -> str:
        key = identifier(source_key)
        detail = next(
            (
                row
                for row in self.rows["tbl_CorrectiveReports_Detail"]
                if identifier(row.values.get("1_FK_AreaN4")) == key
            ),
            None,
        )
        if detail is None:
            raise RowImportError(f"Unknown legacy area: {key}")
        return " / ".join(
            item
            for item in (
                text(detail.values.get("1_AreaN1")),
                text(detail.values.get("1_AreaN2")),
                text(detail.values.get("1_AreaN3")),
                text(detail.values.get("1_AreaN4")),
            )
            if item
        )

    async def _template_for_version(self, version_id: UUID) -> UUID:
        versions = self.context.tables["report_versions"]
        reports = self.context.tables["maintenance_reports"]
        activities = self.context.tables["maintenance_activities"]
        template_id = await self.context.session.scalar(
            select(activities.c.maintenance_template_id)
            .join(
                reports,
                reports.c.maintenance_activity_id == activities.c.id,
            )
            .join(
                versions,
                versions.c.maintenance_report_id == reports.c.id,
            )
            .where(versions.c.id == version_id)
        )
        if template_id is None:
            raise RowImportError(f"Report version {version_id} has no preventive template")
        return template_id

    async def _template_step_id(self, template_id: UUID, task_name: Any) -> UUID:
        if self._template_step_cache is None:
            steps = self.context.tables["maintenance_template_steps"]
            result = await self.context.session.execute(
                select(
                    steps.c.id,
                    steps.c.maintenance_template_id,
                    steps.c.title,
                )
            )
            self._template_step_cache = {
                (candidate_template_id, normalize_key(title)): step_id
                for step_id, candidate_template_id, title in result
            }
        key = (template_id, normalize_key(task_name))
        if key in self._template_step_cache:
            return self._template_step_cache[key]
        title = required_text(task_name, "Task")
        steps = self.context.tables["maintenance_template_steps"]
        next_sequence = (
            await self.context.session.scalar(
                select(func.max(steps.c.sequence)).where(
                    steps.c.maintenance_template_id == template_id
                )
            )
            or 0
        ) + 1
        step_id = stable_uuid(
            STORAGE_SOURCE,
            "historical_template_step",
            template_id,
            normalize_key(title),
        )
        await self.context.upsert(
            "maintenance_template_steps",
            {
                "id": step_id,
                "legacy_id": None,
                "is_active": True,
                "maintenance_template_id": template_id,
                "title": title,
                "default_comment": (
                    "Paso histórico recuperado desde un reporte de Power Apps."
                ),
                "manual_page": None,
                "sequence": next_sequence,
                "is_required": False,
            },
        )
        self._template_step_cache[key] = step_id
        return step_id

    async def _version_created_at(self, version_id: UUID) -> datetime:
        versions = self.context.tables["report_versions"]
        value = await self.context.session.scalar(
            select(versions.c.created_at).where(versions.c.id == version_id)
        )
        if value is None:
            raise RowImportError(f"Report version does not exist: {version_id}")
        return value

    async def _version_creator(self, version_id: UUID) -> str:
        versions = self.context.tables["report_versions"]
        value = await self.context.session.scalar(
            select(versions.c.created_by_user_id).where(versions.c.id == version_id)
        )
        if value is None:
            raise RowImportError(f"Report version does not exist: {version_id}")
        return value

    async def _activity_creator(self, activity_id: UUID) -> str:
        activities = self.context.tables["maintenance_activities"]
        value = await self.context.session.scalar(
            select(activities.c.created_by_user_id).where(activities.c.id == activity_id)
        )
        return value or await self._fallback_user()

    async def _find_asset(self, name: Any) -> str:
        requested = normalize_key(name)
        if self._asset_name_cache is None:
            assets = self.context.tables["assets"]
            result = await self.context.session.execute(
                select(assets.c.id, assets.c.name)
            )
            self._asset_name_cache = [
                (asset_id, normalize_key(asset_name))
                for asset_id, asset_name in result
            ]
        exact = [
            asset_id
            for asset_id, normalized_name in self._asset_name_cache
            if normalized_name == requested
        ]
        if len(exact) == 1:
            return exact[0]
        mapped_exact = await self._prefer_wbs_equipment(exact)
        if mapped_exact is not None:
            return mapped_exact
        contains = [
            asset_id
            for asset_id, normalized_name in self._asset_name_cache
            if requested and requested in normalized_name
        ]
        if len(contains) == 1:
            return contains[0]
        mapped_contains = await self._prefer_wbs_equipment(contains)
        if mapped_contains is not None:
            return mapped_contains
        raise RowImportError(
            f"Could not resolve a unique asset for calibration equipment {name!r}"
        )

    async def _prefer_wbs_equipment(self, candidates: list[str]) -> str | None:
        if not candidates:
            return None
        mappings = self.context.tables["legacy_record_mappings"]
        mapped_ids = set(
            await self.context.session.scalars(
                select(mappings.c.target_record_id).where(
                    mappings.c.source_system == SOURCE_SYSTEM,
                    mappings.c.source_table == "tbl_Equipment",
                    mappings.c.target_table == "assets",
                    mappings.c.target_record_id.in_(candidates),
                )
            )
        )
        return next(iter(mapped_ids)) if len(mapped_ids) == 1 else None

    async def _slot_name(self, slot_id: UUID) -> str:
        slots = self.context.tables["slot_locations"]
        value = await self.context.session.scalar(
            select(slots.c.name).where(slots.c.id == slot_id)
        )
        if value is None:
            raise RowImportError(f"Slot does not exist: {slot_id}")
        return value

    @staticmethod
    def _optional_wbs_uuid(
        sheet: str,
        source_key: Any,
        target_table: str,
    ) -> UUID | None:
        if source_key is None or text(source_key) is None:
            return None
        return wbs_uuid(sheet, source_key, target_table)

    @staticmethod
    def _subsystem_from_type(value: Any) -> str | None:
        normalized = normalize_key(value)
        for candidate in ("ATS", "CBTC", "IXL"):
            if candidate.casefold() in normalized:
                return candidate
        return None

    @staticmethod
    def _item_number(value: Any) -> int | None:
        raw = text(value)
        if raw is None:
            return None
        digits = "".join(character for character in raw if character.isdigit())
        return int(digits[-9:]) if digits else None
