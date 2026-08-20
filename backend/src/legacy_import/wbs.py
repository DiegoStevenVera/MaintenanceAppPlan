import re
from collections import Counter
from collections.abc import Mapping
from datetime import UTC, date, datetime
from typing import Any
from uuid import UUID

from sqlalchemy import delete
from sqlalchemy import text as sql_text

from legacy_import.context import ImportContext, MappingTarget
from legacy_import.errors import RowImportError
from legacy_import.ids import stable_uuid
from legacy_import.values import (
    boolean,
    duration_hours,
    identifier,
    integer,
    normalize_key,
    optional_integer,
    parse_date,
    parse_datetime,
    required_text,
    text,
)
from legacy_import.workbook import LegacyWorkbook, SourceRow

WBS_SOURCE = "WBS_V2"

WBS_SHEETS: dict[str, str] = {
    "tbl_Proyect": "ID_Proyect",
    "tbl_Work_Area": "ID_Work_Area",
    "tbl_Subsystem": "ID_Subsystem",
    "tbl_Stage": "ID_Stage",
    "tbl_Equipment_Category": "ID_Equipment_Category",
    "tbl_EquipmentKind": "ID_EquipmentKind",
    "tbl_TypeSlot": "ID_TypeSlot",
    "tbl_ComponentStatus": "ID_ComponentStatus",
    "tbl_MovementType": "ID_MovementType",
    "tbl_LocationType": "ID_LocationType",
    "tbl_Manufacturer": "ID_Manufacturer",
    "tbl_TypeActivity": "ID_TypeActivity",
    "tbl_Area": "ID_Area",
    "tbl_ComponentType": "ID_ComponentType",
    "tbl_Equipment": "ID_Equipment",
    "tbl_Location": "ID_Location",
    "tbl_SlotLocation": "ID_SlotLocation",
    "tbl_Component": "ID_Component",
    "tbl_Documentation": "ID_Documentation",
    "tbl_SlotImage": "ID_SlotImage",
    "tbl_Activity": "ID_Activity",
    "tbl_Activity_Task": "ID_Activity_Task",
    "tbl_Test_Task": "ID_Test_Task",
    "tbl_Test_Result": "ID_Test_Result",
    "tbl_Conclusion": "ID_Conclusion",
    "tbl_Personal_Activity": "ID_Personal_Activity",
    "tbl_Tools_Activity": "ID_Tool_Activity",
    "tbl_Equipment_Activity_Area": "ID_Equipment_Activity_Area",
    "tbl_Worker": "ID_Worker",
    "tbl_Tool": "ID_Tool",
    "tbl_Certification": "ID_Certification",
}


def wbs_uuid(sheet: str, source_key: Any, target_table: str) -> UUID:
    return stable_uuid(WBS_SOURCE, sheet, identifier(source_key), target_table)


def wbs_string_id(sheet: str, source_key: Any, target_table: str) -> str:
    return str(wbs_uuid(sheet, source_key, target_table))


def technical_code(value: Any) -> str:
    normalized = normalize_key(value).upper()
    return re.sub(r"[^A-Z0-9]+", "_", normalized).strip("_") or "UNSPECIFIED"


def nearest_ancestor_component(
    component: SourceRow,
    *,
    slots_by_key: Mapping[str, SourceRow],
    components_by_location_and_slot: Mapping[tuple[str, str], SourceRow],
) -> SourceRow | None:
    location_source = component.values.get("FK_CurrentLocation")
    slot_source = component.values.get("FK_SlotLocation")
    if location_source is None or slot_source is None:
        return None

    location_key = identifier(location_source)
    current_slot_key = identifier(slot_source)
    visited: set[str] = set()

    while current_slot_key not in visited:
        visited.add(current_slot_key)
        current_slot = slots_by_key.get(current_slot_key)
        if current_slot is None:
            raise RowImportError(
                f"Component {component.key} references missing slot {current_slot_key}"
            )

        parent_slot_source = current_slot.values.get("FK_FatherSlotLocation")
        if parent_slot_source is None:
            return None

        parent_slot_key = identifier(parent_slot_source)
        parent_component = components_by_location_and_slot.get(
            (location_key, parent_slot_key)
        )
        if parent_component is not None:
            return parent_component
        current_slot_key = parent_slot_key

    raise RowImportError(
        f"Slot hierarchy cycle detected while resolving component {component.key}"
    )


class WBSImporter:
    def __init__(self, workbook: LegacyWorkbook, context: ImportContext) -> None:
        self.workbook = workbook
        self.context = context
        self.rows: dict[str, list[SourceRow]] = {
            sheet: workbook.rows(sheet, key_column=key)
            for sheet, key in WBS_SHEETS.items()
        }
        self.by_key: dict[str, dict[str, SourceRow]] = {
            sheet: {row.key: row for row in rows}
            for sheet, rows in self.rows.items()
        }
        self.activity_by_report_code = {
            normalize_key(row.values.get("Report_Code")): row
            for row in self.rows["tbl_Activity"]
            if text(row.values.get("Report_Code"))
        }
        self.project_rows_by_subsystem = {
            identifier(row.values["FK_Subsystem"]): row
            for row in self.rows["tbl_Proyect"]
            if row.values.get("FK_Subsystem") is not None
        }
        self.location_rows_by_id = self.by_key["tbl_Location"]
        serial_counts = Counter(
            text(row.values.get("SerialNumber"))
            for row in self.rows["tbl_Component"]
            if text(row.values.get("SerialNumber"))
        )
        self.duplicate_component_serials = {
            serial for serial, count in serial_counts.items() if count > 1
        }
        self.components_by_location_and_slot: dict[tuple[str, str], SourceRow] = {}
        for component in self.rows["tbl_Component"]:
            location_source = component.values.get("FK_CurrentLocation")
            slot_source = component.values.get("FK_SlotLocation")
            if location_source is None or slot_source is None:
                continue
            occupancy_key = (
                identifier(location_source),
                identifier(slot_source),
            )
            previous = self.components_by_location_and_slot.get(occupancy_key)
            if previous is not None:
                raise RowImportError(
                    "Components "
                    f"{previous.key} and {component.key} occupy the same "
                    f"location/slot {occupancy_key}"
                )
            self.components_by_location_and_slot[occupancy_key] = component
        self.component_rows_in_hierarchy_order = sorted(
            self.rows["tbl_Component"],
            key=self._component_hierarchy_sort_key,
        )

    async def run(self, selected_table: str | None = None) -> None:
        steps = [
            ("tbl_Proyect", self._import_project_context),
            ("tbl_Work_Area", self._import_work_area),
            ("tbl_Subsystem", self._import_subsystem),
            ("tbl_Stage", self._import_stage),
            ("tbl_Equipment_Category", self._import_equipment_category),
            ("tbl_EquipmentKind", self._import_equipment_kind),
            ("tbl_TypeSlot", self._import_slot_type),
            ("tbl_ComponentStatus", self._import_asset_status),
            ("tbl_MovementType", self._import_movement_type),
            ("tbl_LocationType", self._import_location_type),
            ("tbl_Manufacturer", self._import_manufacturer),
            ("tbl_TypeActivity", self._import_action_type),
            ("tbl_Area", self._import_area),
            ("tbl_ComponentType", self._import_component_type),
            ("tbl_Equipment", self._import_equipment),
            ("tbl_Location", self._import_inventory_location),
            ("tbl_SlotLocation", self._import_slot_location),
            ("tbl_Component", self._import_component),
            ("tbl_Documentation", self._import_documentation),
            ("tbl_SlotImage", self._import_slot_image),
            ("tbl_Activity", self._import_template),
            ("tbl_Activity_Task", self._import_template_step),
            ("tbl_Test_Task", self._import_template_test),
            ("tbl_Test_Result", self._import_test_option),
            ("tbl_Conclusion", self._import_conclusion),
            ("tbl_Personal_Activity", self._import_personnel),
            ("tbl_Tools_Activity", self._import_template_tool),
            ("tbl_Equipment_Activity_Area", self._import_template_scope),
            ("tbl_Worker", self._import_worker),
            ("tbl_Tool", self._import_tool),
            ("tbl_Certification", self._import_certification),
        ]
        if selected_table and selected_table not in WBS_SHEETS:
            raise RowImportError(f"Unsupported WBS table: {selected_table}")

        for sheet, handler in steps:
            if selected_table and sheet != selected_table:
                continue
            source_rows = (
                self.component_rows_in_hierarchy_order
                if sheet == "tbl_Component"
                else self.rows[sheet]
            )
            await self.context.process_rows(sheet, source_rows, handler)

        if selected_table is None:
            # A complete import may contain legacy rows that describe a maintenance
            # group (for example, "CRK 1 - 2") as if it were an asset. Keep those
            # rows for traceability, but normalize the operational model so groups
            # live in asset_groups and correctives only select physical assets.
            await self._normalize_legacy_asset_groups()
            await self._rebuild_asset_closure()
        elif selected_table in {"tbl_Equipment", "tbl_Component"}:
            await self._rebuild_asset_closure()

    async def _import_project_context(self, row: SourceRow) -> list[MappingTarget]:
        values = row.values
        site_name = required_text(values.get("Site"), "Site")
        project_name = required_text(values.get("Proyect"), "Proyect")
        stage_name = required_text(values.get("Phase"), "Phase")
        system_name = required_text(values.get("System"), "System")
        subsystem_name = required_text(values.get("Subsystem"), "Subsystem")
        subsystem_key = identifier(values.get("FK_Subsystem"))
        stage_key = identifier(values.get("FK_Stage"))

        site_id = stable_uuid(WBS_SOURCE, "site", normalize_key(site_name))
        project_id = stable_uuid(WBS_SOURCE, "project", site_id, normalize_key(project_name))
        stage_id = wbs_uuid("tbl_Stage", stage_key, "stages")
        system_id = stable_uuid(WBS_SOURCE, "system", project_id, normalize_key(system_name))
        subsystem_id = wbs_uuid("tbl_Subsystem", subsystem_key, "subsystems")

        await self.context.upsert(
            "sites",
            {
                "id": site_id,
                "legacy_id": None,
                "is_active": True,
                "name": site_name,
                "description": None,
            },
        )
        await self.context.upsert(
            "projects",
            {
                "id": project_id,
                "legacy_id": None,
                "is_active": True,
                "site_id": site_id,
                "name": project_name,
                "description": None,
            },
        )
        await self.context.upsert(
            "stages",
            {
                "id": stage_id,
                "legacy_id": integer(stage_key),
                "is_active": True,
                "project_id": project_id,
                "name": stage_name,
                "planned_start_date": None,
                "planned_end_date": None,
                "operational_status": "ACTIVE",
            },
        )
        await self.context.upsert(
            "systems",
            {
                "id": system_id,
                "legacy_id": None,
                "is_active": True,
                "project_id": project_id,
                "name": system_name,
                "description": None,
            },
        )
        await self.context.upsert(
            "subsystems",
            {
                "id": subsystem_id,
                "legacy_id": integer(subsystem_key),
                "is_active": True,
                "system_id": system_id,
                "code": subsystem_name,
                "name": subsystem_name,
                "description": None,
            },
        )
        return [
            MappingTarget("sites", str(site_id), "SITE"),
            MappingTarget("projects", str(project_id), "PROJECT"),
            MappingTarget("stages", str(stage_id), "STAGE"),
            MappingTarget("systems", str(system_id), "SYSTEM"),
            MappingTarget("subsystems", str(subsystem_id), "SUBSYSTEM"),
        ]

    async def _import_work_area(self, row: SourceRow) -> list[MappingTarget]:
        record_id = wbs_uuid(row.sheet, row.key, "work_areas")
        await self.context.upsert(
            "work_areas",
            {
                "id": record_id,
                "legacy_id": integer(row.key),
                "is_active": True,
                "name": required_text(row.values.get("Name"), "Name"),
                "description": None,
            },
        )
        return [MappingTarget("work_areas", str(record_id))]

    async def _import_subsystem(self, row: SourceRow) -> list[MappingTarget]:
        project_row = self.project_rows_by_subsystem.get(row.key)
        if project_row is None:
            raise RowImportError(f"Subsystem {row.key} is not linked by tbl_Proyect")
        project_values = project_row.values
        project_id = self._project_id(project_values)
        system_id = self._system_id(project_values)
        record_id = wbs_uuid(row.sheet, row.key, "subsystems")
        name = required_text(row.values.get("Subsystem"), "Subsystem")
        await self.context.upsert(
            "subsystems",
            {
                "id": record_id,
                "legacy_id": integer(row.key),
                "is_active": True,
                "system_id": system_id,
                "code": name,
                "name": name,
                "description": None,
            },
        )
        return [
            MappingTarget("subsystems", str(record_id)),
            MappingTarget("systems", str(system_id), "PARENT_SYSTEM"),
            MappingTarget("projects", str(project_id), "PARENT_PROJECT"),
        ]

    async def _import_stage(self, row: SourceRow) -> list[MappingTarget]:
        project_row = next(
            (
                candidate
                for candidate in self.rows["tbl_Proyect"]
                if identifier(candidate.values.get("FK_Stage")) == row.key
            ),
            None,
        )
        if project_row is None:
            raise RowImportError(f"Stage {row.key} is not linked by tbl_Proyect")
        record_id = wbs_uuid(row.sheet, row.key, "stages")
        await self.context.upsert(
            "stages",
            {
                "id": record_id,
                "legacy_id": integer(row.key),
                "is_active": True,
                "project_id": self._project_id(project_row.values),
                "name": required_text(project_row.values.get("Phase"), "Phase"),
                "planned_start_date": None,
                "planned_end_date": None,
                "operational_status": "ACTIVE",
            },
        )
        return [MappingTarget("stages", str(record_id))]

    async def _import_equipment_category(self, row: SourceRow) -> list[MappingTarget]:
        record_id = wbs_uuid(row.sheet, row.key, "equipment_categories")
        subsystem_id = wbs_uuid(
            "tbl_Subsystem",
            row.values.get("FK_Subsystem"),
            "subsystems",
        )
        await self.context.upsert(
            "equipment_categories",
            {
                "id": record_id,
                "legacy_id": integer(row.key),
                "is_active": True,
                "subsystem_id": subsystem_id,
                "name_n1": required_text(row.values.get("EquipmentN1"), "EquipmentN1"),
                "name_n2": required_text(row.values.get("EquipmentN2"), "EquipmentN2"),
                "description": None,
            },
        )
        return [MappingTarget("equipment_categories", str(record_id))]

    async def _import_equipment_kind(self, row: SourceRow) -> list[MappingTarget]:
        record_id = wbs_uuid(row.sheet, row.key, "equipment_kinds")
        await self.context.upsert(
            "equipment_kinds",
            {
                "id": record_id,
                "legacy_id": integer(row.key),
                "is_active": True,
                "name": required_text(row.values.get("Description"), "Description"),
                "description": None,
            },
        )
        return [MappingTarget("equipment_kinds", str(record_id))]

    async def _import_named_catalog(
        self,
        row: SourceRow,
        *,
        table_name: str,
        name_column: str,
        with_code: bool,
    ) -> list[MappingTarget]:
        record_id = wbs_uuid(row.sheet, row.key, table_name)
        name = required_text(row.values.get(name_column), name_column)
        values: dict[str, Any] = {
            "id": record_id,
            "legacy_id": integer(row.key),
            "is_active": True,
            "name": name,
            "description": None,
        }
        if with_code:
            values["code"] = technical_code(name)
        await self.context.upsert(table_name, values)
        return [MappingTarget(table_name, str(record_id))]

    async def _import_slot_type(self, row: SourceRow) -> list[MappingTarget]:
        return await self._import_named_catalog(
            row,
            table_name="slot_types",
            name_column="Name",
            with_code=False,
        )

    async def _import_asset_status(self, row: SourceRow) -> list[MappingTarget]:
        return await self._import_named_catalog(
            row,
            table_name="asset_statuses",
            name_column="Name",
            with_code=True,
        )

    async def _import_movement_type(self, row: SourceRow) -> list[MappingTarget]:
        return await self._import_named_catalog(
            row,
            table_name="movement_types",
            name_column="Name",
            with_code=True,
        )

    async def _import_location_type(self, row: SourceRow) -> list[MappingTarget]:
        return await self._import_named_catalog(
            row,
            table_name="location_types",
            name_column="Name",
            with_code=True,
        )

    async def _import_manufacturer(self, row: SourceRow) -> list[MappingTarget]:
        return await self._import_named_catalog(
            row,
            table_name="manufacturers",
            name_column="Name",
            with_code=False,
        )

    async def _import_action_type(self, row: SourceRow) -> list[MappingTarget]:
        return await self._import_named_catalog(
            row,
            table_name="maintenance_action_types",
            name_column="Name",
            with_code=True,
        )

    async def _import_area(self, row: SourceRow) -> list[MappingTarget]:
        path_parts = [
            value
            for column in ("AreaN1", "AreaN2", "AreaN3", "AreaN4")
            if (value := text(row.values.get(column)))
        ]
        if not path_parts:
            raise RowImportError("Area row has no hierarchy values")

        parent_id: UUID | None = None
        targets: list[MappingTarget] = []
        for level, name in enumerate(path_parts, start=1):
            full_path = " / ".join(path_parts[:level])
            location_id = stable_uuid(
                WBS_SOURCE,
                "geographic_location",
                normalize_key(full_path),
            )
            await self.context.upsert(
                "geographic_locations",
                {
                    "id": location_id,
                    "legacy_id": integer(row.key) if level == len(path_parts) else None,
                    "is_active": True,
                    "name": name,
                    "location_type_id": None,
                    "parent_location_id": parent_id,
                    "level": level,
                    "full_path": full_path,
                },
            )
            targets.append(
                MappingTarget(
                    "geographic_locations",
                    str(location_id),
                    f"LEVEL_{level}",
                )
            )
            parent_id = location_id
        return targets

    async def _import_component_type(self, row: SourceRow) -> list[MappingTarget]:
        record_id = wbs_uuid(row.sheet, row.key, "asset_types")
        is_serialized = boolean(row.values.get("IsSerialized"))
        await self.context.upsert(
            "asset_types",
            {
                "id": record_id,
                "legacy_id": integer(row.key),
                "is_active": True,
                "name": required_text(row.values.get("Name"), "Name"),
                "category": "COMPONENT",
                "serial_number_policy": "OPTIONAL" if is_serialized else "NOT_APPLICABLE",
                "part_number_policy": "OPTIONAL",
                "part_number": text(row.values.get("PartNumber")),
                "supports_version": False,
                "description": text(row.values.get("Description")),
            },
        )
        return [MappingTarget("asset_types", str(record_id))]

    async def _import_equipment(self, row: SourceRow) -> list[MappingTarget]:
        values = row.values
        asset_id = wbs_string_id(row.sheet, row.key, "assets")
        category_id = wbs_uuid(
            "tbl_Equipment_Category",
            values.get("FK_Equipment_Category"),
            "equipment_categories",
        )
        category_row = self._source_row(
            "tbl_Equipment_Category",
            values.get("FK_Equipment_Category"),
        )
        asset_type_id = stable_uuid(WBS_SOURCE, "equipment_asset_type", category_id)
        asset_type_name = (
            f"{required_text(category_row.values.get('EquipmentN1'), 'EquipmentN1')} - "
            f"{required_text(category_row.values.get('EquipmentN2'), 'EquipmentN2')}"
        )
        subsystem_id = wbs_uuid(
            "tbl_Subsystem",
            category_row.values.get("FK_Subsystem"),
            "subsystems",
        )
        area_source = values.get("FK_Area")
        area_id, area_path = (
            self._area_target(area_source)
            if area_source is not None
            else (None, None)
        )
        internal_code = f"EQ-{int(row.key):04d}"
        name = required_text(values.get("EquipmentN3"), "EquipmentN3")

        await self.context.upsert(
            "asset_types",
            {
                "id": asset_type_id,
                "legacy_id": None,
                "is_active": True,
                "name": asset_type_name,
                "category": "LARGE_EQUIPMENT",
                "serial_number_policy": "OPTIONAL",
                "part_number_policy": "OPTIONAL",
                "part_number": None,
                "supports_version": normalize_key(values.get("EquipmentN1")) == "software",
                "description": None,
            },
        )
        await self.context.upsert(
            "assets",
            {
                "id": asset_id,
                "name": name,
                "category": required_text(values.get("EquipmentN1"), "EquipmentN1"),
                "asset_type": asset_type_name,
                "subsystem": required_text(values.get("Subsystem"), "Subsystem"),
                "serial_or_code": internal_code,
                "part_number": None,
                "status": "OPERATIVO",
                "physical_location": area_path or "Ubicación variable",
                "is_business_anchor": True,
                "parent_id": None,
                "children": [],
                # Legacy IDs overlap between equipment and components.
                "legacy_id": None,
                "asset_type_id": asset_type_id,
                "equipment_category_id": category_id,
                "equipment_kind_id": wbs_uuid(
                    "tbl_EquipmentKind",
                    values.get("FK_EquipmentKind"),
                    "equipment_kinds",
                ),
                "subsystem_id": subsystem_id,
                "manufacturer_id": wbs_uuid(
                    "tbl_Manufacturer",
                    values.get("FK_Manufacturer"),
                    "manufacturers",
                ),
                "status_id": wbs_uuid("tbl_ComponentStatus", 1, "asset_statuses"),
                "current_geographic_location_id": area_id,
                "current_inventory_location_id": None,
                "current_slot_location_id": None,
                "internal_code": internal_code,
                "serial_number": None,
                "serial_number_status": "NOT_CAPTURED",
                "model": None,
                "manufacture_date": None,
                "software_version": None,
                "current_position": None,
                "business_label": "Equipo",
                "registration_method": "PRE_REGISTERED",
                "is_mobile": normalize_key(values.get("EquipmentN2")) == "tren",
            },
        )
        assignment_id = stable_uuid(WBS_SOURCE, row.sheet, row.key, "asset_stage_assignments")
        await self.context.upsert(
            "asset_stage_assignments",
            {
                "id": assignment_id,
                "legacy_id": None,
                "asset_id": asset_id,
                "stage_id": wbs_uuid("tbl_Stage", values.get("FK_Stage"), "stages"),
                "role": "INITIAL_SCOPE",
                "valid_from": date(2025, 1, 1),
                "valid_to": None,
            },
        )
        return [
            MappingTarget("assets", asset_id),
            MappingTarget("asset_types", str(asset_type_id), "ASSET_TYPE"),
            MappingTarget("asset_stage_assignments", str(assignment_id), "STAGE"),
        ]

    async def _import_inventory_location(self, row: SourceRow) -> list[MappingTarget]:
        values = row.values
        record_id = wbs_uuid(row.sheet, row.key, "inventory_locations")
        related_asset_id = None
        if values.get("FK_Equipment") is not None:
            related_asset_id = wbs_string_id(
                "tbl_Equipment",
                values.get("FK_Equipment"),
                "assets",
            )
        await self.context.upsert(
            "inventory_locations",
            {
                "id": record_id,
                "legacy_id": integer(row.key),
                "is_active": True,
                "location_type_id": wbs_uuid(
                    "tbl_LocationType",
                    values.get("FK_LocationType"),
                    "location_types",
                ),
                "name": required_text(values.get("Name"), "Name"),
                "related_asset_id": related_asset_id,
                "description": None,
            },
        )
        return [MappingTarget("inventory_locations", str(record_id))]

    async def _import_slot_location(self, row: SourceRow) -> list[MappingTarget]:
        values = row.values
        record_id = wbs_uuid(row.sheet, row.key, "slot_locations")
        parent_source = values.get("FK_FatherSlotLocation")
        parent_id = (
            wbs_uuid(row.sheet, parent_source, "slot_locations")
            if parent_source is not None
            else None
        )
        await self.context.upsert(
            "slot_locations",
            {
                "id": record_id,
                "legacy_id": integer(row.key),
                "is_active": True,
                "equipment_kind_id": wbs_uuid(
                    "tbl_EquipmentKind",
                    values.get("FK_EquipmentKind"),
                    "equipment_kinds",
                ),
                "slot_type_id": wbs_uuid(
                    "tbl_TypeSlot",
                    values.get("FK_TypeSlot"),
                    "slot_types",
                ),
                "parent_slot_location_id": parent_id,
                "name": required_text(values.get("NameSlotLocation"), "NameSlotLocation"),
                "level": integer(values.get("Level")) or 1,
                "sequence": integer(values.get("Seq")) or 0,
                "path": required_text(values.get("Path"), "Path"),
                "is_leaf": boolean(values.get("Is_LeafLevel")),
                "accepts_asset": boolean(values.get("IsInstallPointComponent")),
            },
        )
        return [MappingTarget("slot_locations", str(record_id))]

    async def _import_component(self, row: SourceRow) -> list[MappingTarget]:
        values = row.values
        location_row = self._source_row("tbl_Location", values.get("FK_CurrentLocation"))
        location_id = wbs_uuid(
            "tbl_Location",
            values.get("FK_CurrentLocation"),
            "inventory_locations",
        )
        parent_equipment_key = location_row.values.get("FK_Equipment")
        equipment_asset_id = (
            wbs_string_id("tbl_Equipment", parent_equipment_key, "assets")
            if parent_equipment_key is not None
            else None
        )
        parent_component = nearest_ancestor_component(
            row,
            slots_by_key=self.by_key["tbl_SlotLocation"],
            components_by_location_and_slot=self.components_by_location_and_slot,
        )
        parent_asset_id = (
            wbs_string_id("tbl_Component", parent_component.key, "assets")
            if parent_component is not None
            else equipment_asset_id
        )
        component_type_source = values.get("FK_ComponentType")
        if component_type_source is not None:
            component_type_row = self._source_row(
                "tbl_ComponentType",
                component_type_source,
            )
            component_type_id = wbs_uuid(
                "tbl_ComponentType",
                component_type_source,
                "asset_types",
            )
            component_subsystem_source = component_type_row.values.get("FK_Subsystem")
            type_name = required_text(
                component_type_row.values.get("Name"),
                "Component type",
            )
            part_number = text(component_type_row.values.get("PartNumber"))
            inventory_code = text(
                component_type_row.values.get("INVENTORY_CODE_ETIQUETADO")
            )
            is_serialized = boolean(component_type_row.values.get("IsSerialized"))
        else:
            parent_equipment = self._source_row(
                "tbl_Equipment",
                parent_equipment_key,
            )
            parent_category = self._source_row(
                "tbl_Equipment_Category",
                parent_equipment.values.get("FK_Equipment_Category"),
            )
            component_subsystem_source = parent_category.values.get("FK_Subsystem")
            type_name = "Componente no tipificado"
            part_number = None
            inventory_code = None
            is_serialized = True
            component_type_id = stable_uuid(
                WBS_SOURCE,
                "unclassified_component_type",
            )
            await self.context.upsert(
                "asset_types",
                {
                    "id": component_type_id,
                    "legacy_id": None,
                    "is_active": True,
                    "name": type_name,
                    "category": "COMPONENT",
                    "serial_number_policy": "OPTIONAL",
                    "part_number_policy": "OPTIONAL",
                    "part_number": None,
                    "supports_version": False,
                    "description": (
                        "Tipo temporal para componentes cuyo part number "
                        "aún no ha sido identificado."
                    ),
                },
            )
        slot_source = values.get("FK_SlotLocation")
        slot_id = (
            wbs_uuid("tbl_SlotLocation", slot_source, "slot_locations")
            if slot_source is not None
            else None
        )
        slot_name = None
        if slot_source is not None:
            slot_name = text(
                self._source_row("tbl_SlotLocation", slot_source).values.get(
                    "NameSlotLocation"
                )
            )
        serial_number = text(values.get("SerialNumber"))
        stored_serial_number = (
            None
            if serial_number in self.duplicate_component_serials
            else serial_number
        )
        if serial_number in self.duplicate_component_serials:
            serial_status = "REQUIRES_VERIFICATION"
        elif serial_number:
            serial_status = "KNOWN"
        else:
            serial_status = "NOT_CAPTURED" if is_serialized else "NOT_APPLICABLE"
        internal_code = f"{inventory_code or 'COMP'}-{int(row.key):04d}"
        status_row = self._source_row("tbl_ComponentStatus", values.get("FK_Status"))
        status_name = required_text(status_row.values.get("Name"), "Component status")
        subsystem_id = wbs_uuid(
            "tbl_Subsystem",
            component_subsystem_source,
            "subsystems",
        )
        subsystem_row = self._source_row(
            "tbl_Subsystem",
            component_subsystem_source,
        )
        asset_id = wbs_string_id(row.sheet, row.key, "assets")
        location_name = required_text(location_row.values.get("Name"), "Location")
        manufacturer_id = await self._manufacturer_id_for_name(values.get("Manufacturer"))

        await self.context.upsert(
            "assets",
            {
                "id": asset_id,
                "name": required_text(values.get("Name"), "Name"),
                "category": "Componente",
                "asset_type": type_name,
                "subsystem": required_text(
                    subsystem_row.values.get("Subsystem"),
                    "Subsystem",
                ),
                "serial_or_code": serial_number or internal_code,
                "part_number": part_number,
                "status": status_name,
                "physical_location": location_name,
                "is_business_anchor": False,
                "parent_id": parent_asset_id,
                "children": [],
                "legacy_id": integer(row.key),
                "asset_type_id": component_type_id,
                "equipment_category_id": None,
                "equipment_kind_id": None,
                "subsystem_id": subsystem_id,
                "manufacturer_id": manufacturer_id,
                "status_id": wbs_uuid(
                    "tbl_ComponentStatus",
                    values.get("FK_Status"),
                    "asset_statuses",
                ),
                "current_geographic_location_id": None,
                "current_inventory_location_id": location_id,
                "current_slot_location_id": slot_id,
                "internal_code": internal_code,
                "serial_number": stored_serial_number,
                "serial_number_status": serial_status,
                "model": text(values.get("Model")),
                "manufacture_date": parse_date(values.get("ManufactureDate")),
                "software_version": None,
                "current_position": slot_name,
                "business_label": None,
                "registration_method": "PRE_REGISTERED",
                "is_mobile": False,
            },
        )
        targets = [MappingTarget("assets", asset_id)]
        if parent_asset_id:
            assignment_id = wbs_uuid(row.sheet, row.key, "asset_assignments")
            assigned_at = parse_datetime(values.get("LastMovementAt")) or datetime.now(
                UTC
            )
            await self.context.upsert(
                "asset_assignments",
                {
                    "id": assignment_id,
                    "legacy_id": None,
                    "asset_id": asset_id,
                    "parent_asset_id": parent_asset_id,
                    "slot_location_id": slot_id,
                    "geographic_location_id": None,
                    "position_snapshot": slot_name,
                    "assigned_at": assigned_at,
                    "unassigned_at": None,
                    "reason": "Importación inicial desde Power Apps; fecha histórica no disponible.",
                    "source_report_version_id": None,
                },
            )
            targets.append(
                MappingTarget("asset_assignments", str(assignment_id), "INSTALLATION")
            )
        return targets

    async def _import_documentation(self, row: SourceRow) -> list[MappingTarget]:
        record_id = wbs_uuid(row.sheet, row.key, "documentation_resources")
        tags = [
            item.strip()
            for item in (text(row.values.get("Tags")) or "").split(";")
            if item.strip()
        ]
        work_area_id = None
        if row.values.get("FK_Area_Documentation") is not None:
            work_area_id = wbs_uuid(
                "tbl_Work_Area",
                row.values.get("FK_Area_Documentation"),
                "work_areas",
            )
        await self.context.upsert(
            "documentation_resources",
            {
                "id": record_id,
                "legacy_id": integer(row.key),
                "is_active": True,
                "name": required_text(
                    row.values.get("Documentation_name"),
                    "Documentation_name",
                ),
                "file_reference": required_text(
                    row.values.get("Documentation_Link"),
                    "Documentation_Link",
                ),
                "tags": tags,
                "title": text(row.values.get("Title")),
                "work_area_id": work_area_id,
            },
        )
        return [MappingTarget("documentation_resources", str(record_id))]

    async def _import_slot_image(self, row: SourceRow) -> list[MappingTarget]:
        values = row.values
        record_id = wbs_uuid(row.sheet, row.key, "slot_images")
        await self.context.upsert(
            "slot_images",
            {
                "id": record_id,
                "legacy_id": integer(row.key),
                "is_active": True,
                "equipment_kind_id": wbs_uuid(
                    "tbl_EquipmentKind",
                    values.get("FK_EquipmentKind"),
                    "equipment_kinds",
                ),
                "slot_location_id": (
                    wbs_uuid(
                        "tbl_SlotLocation",
                        values.get("FK_SlotLocation"),
                        "slot_locations",
                    )
                    if values.get("FK_SlotLocation") is not None
                    else None
                ),
                "documentation_resource_id": (
                    wbs_uuid(
                        "tbl_Documentation",
                        values.get("FK_Documentation"),
                        "documentation_resources",
                    )
                    if values.get("FK_Documentation") is not None
                    else None
                ),
                "name": required_text(values.get("Name"), "Name"),
                "file_reference": required_text(values.get("Url"), "Url"),
                "page_number": integer(values.get("Page")),
            },
        )
        return [MappingTarget("slot_images", str(record_id))]

    async def _import_template(self, row: SourceRow) -> list[MappingTarget]:
        values = row.values
        record_id = wbs_uuid(row.sheet, row.key, "maintenance_templates")
        await self.context.upsert(
            "maintenance_templates",
            {
                "id": record_id,
                "legacy_id": integer(row.key),
                "is_active": True,
                "report_code": required_text(values.get("Report_Code"), "Report_Code"),
                "subsystem_id": wbs_uuid(
                    "tbl_Subsystem",
                    values.get("FK_Subsystem"),
                    "subsystems",
                ),
                "activity_n1": required_text(values.get("ActivityN1"), "ActivityN1"),
                "activity_n2": text(values.get("ActivityN2")),
                "activity_n3_summary": text(values.get("ActivityN3_Resume")),
                "activity_n3_detail": text(values.get("ActivityN3_Detail")),
                "activity_n4": text(values.get("ActivityN4")),
                "manual_reference": text(values.get("Manual_Ref")),
                "manual_file_reference": text(values.get("Manual_Ref_Link")),
                "manual_start_page": integer(values.get("PagManual_Ini")),
                "manual_end_page": integer(values.get("PagManual_End")),
                "frequency": text(values.get("Frequency")),
                "estimated_minutes": None,
                "required_personnel": None,
            },
        )
        return [MappingTarget("maintenance_templates", str(record_id))]

    async def _import_template_step(self, row: SourceRow) -> list[MappingTarget]:
        activity = self._activity_for_report_code(row.values.get("Report_Code"))
        record_id = wbs_uuid(row.sheet, row.key, "maintenance_template_steps")
        task = required_text(row.values.get("Task"), "Task")
        await self.context.upsert(
            "maintenance_template_steps",
            {
                "id": record_id,
                "legacy_id": integer(row.key),
                "is_active": True,
                "maintenance_template_id": wbs_uuid(
                    "tbl_Activity",
                    activity.key,
                    "maintenance_templates",
                ),
                "title": task,
                "default_comment": text(row.values.get("Comment")),
                "manual_page": integer(row.values.get("Page_Task")),
                "sequence": integer(row.key) or 0,
                "is_required": True,
            },
        )
        return [MappingTarget("maintenance_template_steps", str(record_id))]

    async def _import_template_test(self, row: SourceRow) -> list[MappingTarget]:
        values = row.values
        record_id = wbs_uuid(row.sheet, row.key, "maintenance_template_tests")
        await self.context.upsert(
            "maintenance_template_tests",
            {
                "id": record_id,
                "legacy_id": integer(row.key),
                "is_active": True,
                "maintenance_template_id": wbs_uuid(
                    "tbl_Activity",
                    values.get("FK_Activity"),
                    "maintenance_templates",
                ),
                "template_step_id": wbs_uuid(
                    "tbl_Activity_Task",
                    values.get("FK_Activity_Task"),
                    "maintenance_template_steps",
                ),
                "name": required_text(values.get("NameTest"), "NameTest"),
                "result_type": required_text(values.get("TypeResult"), "TypeResult"),
                "threshold_min": text(values.get("Threshold_Min_Test")),
                "threshold_max": text(values.get("Threshold_Max_Test")),
                "prefix": text(values.get("Prefix")),
                "unit": text(values.get("Unit")),
                "sequence": integer(values.get("TestNum_Task")) or 0,
            },
        )
        return [MappingTarget("maintenance_template_tests", str(record_id))]

    async def _import_test_option(self, row: SourceRow) -> list[MappingTarget]:
        record_id = wbs_uuid(row.sheet, row.key, "maintenance_template_test_options")
        await self.context.upsert(
            "maintenance_template_test_options",
            {
                "id": record_id,
                "legacy_id": integer(row.key),
                "is_active": True,
                "template_test_id": wbs_uuid(
                    "tbl_Test_Task",
                    row.values.get("FK_Test_Task"),
                    "maintenance_template_tests",
                ),
                "value": required_text(row.values.get("Result"), "Result"),
                "sequence": integer(row.key) or 0,
                "is_default": boolean(row.values.get("Result_Default")),
            },
        )
        return [MappingTarget("maintenance_template_test_options", str(record_id))]

    async def _import_conclusion(self, row: SourceRow) -> list[MappingTarget]:
        record_id = wbs_uuid(row.sheet, row.key, "maintenance_template_conclusions")
        await self.context.upsert(
            "maintenance_template_conclusions",
            {
                "id": record_id,
                "legacy_id": integer(row.key),
                "is_active": True,
                "maintenance_template_id": wbs_uuid(
                    "tbl_Activity",
                    row.values.get("FK_Activity"),
                    "maintenance_templates",
                ),
                "summary": required_text(
                    row.values.get("Conclusion_resume"),
                    "Conclusion_resume",
                ),
                "description": text(row.values.get("Conclusion_description")),
            },
        )
        return [MappingTarget("maintenance_template_conclusions", str(record_id))]

    async def _import_personnel(self, row: SourceRow) -> list[MappingTarget]:
        activity = self._activity_for_report_code(row.values.get("Report_Code"))
        personnel_role = required_text(row.values.get("Personal"), "Personal")
        template_id = wbs_uuid(
            "tbl_Activity",
            activity.key,
            "maintenance_templates",
        )
        record_id = stable_uuid(
            WBS_SOURCE,
            "maintenance_template_personnel",
            template_id,
            normalize_key(personnel_role),
        )
        await self.context.upsert(
            "maintenance_template_personnel",
            {
                "id": record_id,
                "legacy_id": integer(row.key),
                "is_active": True,
                "maintenance_template_id": template_id,
                "personnel_role": personnel_role,
                "quantity": integer(row.values.get("N_persons")) or 1,
                "estimated_hours": duration_hours(row.values.get("Hours")),
            },
            conflict_columns=("maintenance_template_id", "personnel_role"),
        )
        return [MappingTarget("maintenance_template_personnel", str(record_id))]

    async def _import_template_tool(self, row: SourceRow) -> list[MappingTarget]:
        activity = self._activity_for_report_code(row.values.get("Report_Code"))
        record_id = wbs_uuid(row.sheet, row.key, "maintenance_template_tools")
        await self.context.upsert(
            "maintenance_template_tools",
            {
                "id": record_id,
                "legacy_id": integer(row.key),
                "is_active": True,
                "maintenance_template_id": wbs_uuid(
                    "tbl_Activity",
                    activity.key,
                    "maintenance_templates",
                ),
                "tool_name": required_text(row.values.get("Name_Serie"), "Name_Serie"),
                "quantity": optional_integer(row.values.get("Q_tools")) or 1,
                "estimated_hours": duration_hours(row.values.get("Hours")),
            },
        )
        return [MappingTarget("maintenance_template_tools", str(record_id))]

    async def _import_template_scope(self, row: SourceRow) -> list[MappingTarget]:
        values = row.values
        record_id = wbs_uuid(row.sheet, row.key, "maintenance_template_scopes")
        equipment_key = values.get("ID_Equipment")
        asset_id = wbs_string_id("tbl_Equipment", equipment_key, "assets")
        group_id = wbs_uuid("tbl_Equipment", equipment_key, "asset_groups")
        equipment = self._source_row("tbl_Equipment", equipment_key)
        equipment_category = self._source_row(
            "tbl_Equipment_Category",
            equipment.values.get("FK_Equipment_Category"),
        )
        area_id, _ = self._area_target(values.get("ID_Area"))
        await self.context.upsert(
            "asset_groups",
            {
                "id": group_id,
                "code": f"WBS-EQUIPMENT-{identifier(equipment_key)}",
                "name": required_text(equipment.values.get("EquipmentN3"), "EquipmentN3"),
                "subsystem_id": wbs_uuid(
                    "tbl_Subsystem",
                    equipment_category.values.get("FK_Subsystem"),
                    "subsystems",
                ),
                "geographic_location_id": area_id,
                "is_active": True,
            },
        )
        await self.context.upsert(
            "asset_group_members",
            {
                "id": wbs_uuid(row.sheet, row.key, "asset_group_members"),
                "asset_group_id": group_id,
                "asset_id": asset_id,
            },
            conflict_columns=("asset_group_id", "asset_id"),
        )
        await self.context.upsert(
            "maintenance_template_scopes",
            {
                "id": record_id,
                "legacy_id": integer(row.key),
                "maintenance_template_id": wbs_uuid(
                    "tbl_Activity",
                    values.get("ID_Activity"),
                    "maintenance_templates",
                ),
                "asset_id": asset_id,
                "asset_group_id": group_id,
                "equipment_category_id": None,
                "geographic_location_id": area_id,
                "display_name": required_text(
                    values.get("Name_Activity_Equipment"),
                    "Name_Activity_Equipment",
                ),
                "notes": text(values.get("Notes")),
            },
        )
        return [
            MappingTarget("asset_groups", str(group_id), "ASSET_GROUP"),
            MappingTarget("maintenance_template_scopes", str(record_id)),
        ]

    async def _import_worker(self, row: SourceRow) -> list[MappingTarget]:
        values = row.values
        email = required_text(values.get("Email"), "Email").lower()
        existing_id = await self.context.scalar_id("users", column="email", value=email)
        record_id = existing_id or wbs_string_id(row.sheet, row.key, "users")
        role, role_label = self._worker_role(values)
        await self.context.upsert(
            "users",
            {
                "id": record_id,
                "name": required_text(values.get("Name"), "Name"),
                "email": email,
                "role": role,
                "role_label": role_label,
                "password_hash": "!legacy-import-disabled!",
                "legacy_id": integer(row.key),
                "work_area_id": (
                    wbs_uuid(
                        "tbl_Work_Area",
                        values.get("Area"),
                        "work_areas",
                    )
                    if values.get("Area") is not None
                    else None
                ),
                "is_active": boolean(values.get("Active"), default=True),
                "profile_image_ref": None,
                "default_avatar_key": "person.crop.circle.fill",
            },
        )
        return [MappingTarget("users", str(record_id))]

    async def _import_tool(self, row: SourceRow) -> list[MappingTarget]:
        values = row.values
        record_id = wbs_uuid(row.sheet, row.key, "tools")
        serial = required_text(values.get("Serie"), "Serie")
        await self.context.upsert(
            "tools",
            {
                "id": record_id,
                "legacy_id": integer(row.key),
                "is_active": True,
                "serial_number": serial,
                "name": text(values.get("Name_short")) or required_text(
                    values.get("Description"),
                    "Description",
                ),
                "model": text(values.get("Model")),
                "brand": text(values.get("Brand")),
                "series": serial,
                "part_number": None,
                "tool_type": text(values.get("Name_short")),
                "availability_status": "AVAILABLE",
                "current_location": None,
            },
        )
        return [MappingTarget("tools", str(record_id))]

    async def _import_certification(self, row: SourceRow) -> list[MappingTarget]:
        values = row.values
        record_id = wbs_uuid(row.sheet, row.key, "tool_certifications")
        calibration_date = parse_date(values.get("Calibration_Date"))
        next_date = parse_date(values.get("Next_Calibration"))
        if calibration_date is None or next_date is None:
            raise RowImportError("Certification dates are required")
        await self.context.upsert(
            "tool_certifications",
            {
                "id": record_id,
                "legacy_id": integer(row.key),
                "tool_id": wbs_uuid("tbl_Tool", values.get("FK_Tool"), "tools"),
                "calibration_company": required_text(
                    values.get("Calibration_Company"),
                    "Calibration_Company",
                ),
                "certification_number": required_text(
                    values.get("Certification_Number"),
                    "Certification_Number",
                ),
                "calibration_date": calibration_date,
                "validity_days": integer(values.get("Certificate_Validity")) or 0,
                "next_calibration_date": next_date,
                "certificate_file_reference": text(values.get("Path")),
                "is_active": boolean(values.get("Active"), default=True),
            },
        )
        return [MappingTarget("tool_certifications", str(record_id))]

    async def _rebuild_asset_closure(self) -> None:
        closure = self.context.tables["asset_closure"]
        await self.context.session.execute(delete(closure))
        await self.context.session.execute(
            sql_text(
                """
                WITH RECURSIVE hierarchy AS (
                    SELECT id AS ancestor_asset_id, id AS descendant_asset_id, 0 AS depth
                    FROM assets
                    UNION ALL
                    SELECT
                        hierarchy.ancestor_asset_id,
                        child.id AS descendant_asset_id,
                        hierarchy.depth + 1
                    FROM hierarchy
                    JOIN assets AS child
                      ON child.parent_id = hierarchy.descendant_asset_id
                )
                INSERT INTO asset_closure (
                    ancestor_asset_id,
                    descendant_asset_id,
                    depth
                )
                SELECT ancestor_asset_id, descendant_asset_id, MIN(depth)
                FROM hierarchy
                GROUP BY ancestor_asset_id, descendant_asset_id
                """
            )
        )
        await self.context.session.execute(
            sql_text(
                """
                UPDATE assets AS parent
                SET children = COALESCE(
                    (
                        SELECT jsonb_agg(child.name ORDER BY child.name)
                        FROM assets AS child
                        WHERE child.parent_id = parent.id
                    ),
                    '[]'::jsonb
                )
                """
            )
        )

    async def _normalize_legacy_asset_groups(self) -> None:
        """Convert known legacy aggregate equipment rows into physical assets/groups.

        The WBS source predates the distinction between an asset and a preventive
        scope, so this runs after all rows are available. It is idempotent and is
        intentionally also represented in migration 0013 for already-imported DBs.
        """
        statements = (
            """
            INSERT INTO assets (
                id, name, category, asset_type, subsystem, serial_or_code, status,
                physical_location, is_business_anchor, parent_id, children, asset_type_id,
                equipment_category_id, equipment_kind_id, subsystem_id, manufacturer_id,
                status_id, current_geographic_location_id, current_inventory_location_id,
                current_slot_location_id, internal_code, serial_number, serial_number_status,
                model, manufacture_date, software_version, current_position, business_label,
                registration_method, is_mobile, created_at, updated_at
            )
            SELECT v.id, v.name, legacy.category, legacy.asset_type, legacy.subsystem,
                   v.name, legacy.status, legacy.physical_location, true, NULL, '[]'::jsonb,
                   legacy.asset_type_id, legacy.equipment_category_id, legacy.equipment_kind_id,
                   legacy.subsystem_id, legacy.manufacturer_id, legacy.status_id,
                   legacy.current_geographic_location_id, NULL, NULL, NULL, NULL,
                   'NOT_CAPTURED', NULL, NULL, NULL, NULL, 'Equipo', 'MIGRATED', false,
                   now(), now()
            FROM (VALUES
                ('physical-crk-1', 'CRK 1', 'CRK 1 - 2'),
                ('physical-crk-2', 'CRK 2', 'CRK 1 - 2'),
                ('physical-erk-1', 'ERK 1', 'ERK 1 - 2'),
                ('physical-erk-2', 'ERK 2', 'ERK 1 - 2')
            ) AS v(id, name, legacy_name)
            JOIN assets legacy ON legacy.name = v.legacy_name
            ON CONFLICT (id) DO NOTHING
            """,
            """
            UPDATE assets child SET parent_id = mapping.new_parent_id, updated_at = now()
            FROM (
                SELECT child.id,
                       CASE child.physical_location
                           WHEN 'CRK 1' THEN 'physical-crk-1'
                           WHEN 'CRK 2' THEN 'physical-crk-2'
                           WHEN 'ERK 1' THEN 'physical-erk-1'
                           WHEN 'ERK 2' THEN 'physical-erk-2'
                       END AS new_parent_id
                FROM assets child
                JOIN assets legacy ON legacy.id = child.parent_id
                WHERE legacy.name IN ('CRK 1 - 2', 'ERK 1 - 2')
                  AND child.physical_location IN ('CRK 1', 'CRK 2', 'ERK 1', 'ERK 2')
            ) mapping
            WHERE child.id = mapping.id AND mapping.new_parent_id IS NOT NULL
            """,
            """
            DELETE FROM asset_group_members gm
            USING asset_groups ag
            WHERE gm.asset_group_id = ag.id
              AND ag.name IN ('CRK 1 - 2', 'ERK 1 - 2')
            """,
            """
            INSERT INTO asset_group_members (id, asset_group_id, asset_id, created_at, updated_at)
            SELECT gen_random_uuid(), ag.id, item.asset_id, now(), now()
            FROM asset_groups ag
            JOIN (VALUES
                ('CRK 1 - 2', 'physical-crk-1'), ('CRK 1 - 2', 'physical-crk-2'),
                ('ERK 1 - 2', 'physical-erk-1'), ('ERK 1 - 2', 'physical-erk-2')
            ) AS item(group_name, asset_id) ON item.group_name = ag.name
            ON CONFLICT (asset_group_id, asset_id) DO NOTHING
            """,
            """
            DELETE FROM asset_group_members gm
            USING asset_groups ag
            WHERE gm.asset_group_id = ag.id
              AND ag.name IN (
                  'SYS001, SYS002, DBC001, COM001, COM002, CWS001, CWS002, CWS003, CWS004, CWS005, OVW001, OVW002',
                  'SYS101, SYS102, DBC101, COM101, COM102, CWS101, CWS102, CWS103, CWS104, CWS105, OVW101, OVW102'
              )
            """,
            """
            INSERT INTO asset_group_members (id, asset_group_id, asset_id, created_at, updated_at)
            SELECT gen_random_uuid(), ag.id, a.id, now(), now()
            FROM asset_groups ag
            JOIN assets a ON (
                (ag.name LIKE 'SYS001,%' AND upper(regexp_replace(a.name, '[^A-Za-z0-9]', '', 'g')) ~ '^(LIM)?(SYS|DBC|COM|CWS|OVW)00[1-9]$')
                OR
                (ag.name LIKE 'SYS101,%' AND upper(regexp_replace(a.name, '[^A-Za-z0-9]', '', 'g')) ~ '^(LIM)?(SYS|DBC|COM|CWS|OVW)10[1-9]$')
            )
            ON CONFLICT (asset_group_id, asset_id) DO NOTHING
            """,
            """
            UPDATE assets
            SET is_business_anchor = false, business_label = 'Grupo preventivo legado', updated_at = now()
            WHERE name IN (
                'CRK 1 - 2', 'ERK 1 - 2',
                'SYS001, SYS002, DBC001, COM001, COM002, CWS001, CWS002, CWS003, CWS004, CWS005, OVW001, OVW002',
                'SYS101, SYS102, DBC101, COM101, COM102, CWS101, CWS102, CWS103, CWS104, CWS105, OVW101, OVW102'
            )
            """,
        )
        for statement in statements:
            await self.context.session.execute(sql_text(statement))

    def _component_hierarchy_sort_key(self, row: SourceRow) -> tuple[int, int]:
        slot_source = row.values.get("FK_SlotLocation")
        if slot_source is None:
            return (10_000, row.row_number)
        slot = self.by_key["tbl_SlotLocation"].get(identifier(slot_source))
        if slot is None:
            return (10_000, row.row_number)
        return (integer(slot.values.get("Level")) or 10_000, row.row_number)

    def _source_row(self, sheet: str, source_key: Any) -> SourceRow:
        key = identifier(source_key)
        try:
            return self.by_key[sheet][key]
        except KeyError as error:
            raise RowImportError(f"{sheet} does not contain key {key}") from error

    def _activity_for_report_code(self, value: Any) -> SourceRow:
        key = normalize_key(value)
        try:
            return self.activity_by_report_code[key]
        except KeyError as error:
            raise RowImportError(f"Unknown Report_Code: {value!r}") from error

    def _area_target(self, source_key: Any) -> tuple[UUID, str]:
        area = self._source_row("tbl_Area", source_key)
        parts = [
            value
            for column in ("AreaN1", "AreaN2", "AreaN3", "AreaN4")
            if (value := text(area.values.get(column)))
        ]
        full_path = " / ".join(parts)
        return (
            stable_uuid(WBS_SOURCE, "geographic_location", normalize_key(full_path)),
            full_path,
        )

    def _project_id(self, values: dict[str, Any]) -> UUID:
        site_id = stable_uuid(
            WBS_SOURCE,
            "site",
            normalize_key(values.get("Site")),
        )
        return stable_uuid(
            WBS_SOURCE,
            "project",
            site_id,
            normalize_key(values.get("Proyect")),
        )

    def _system_id(self, values: dict[str, Any]) -> UUID:
        return stable_uuid(
            WBS_SOURCE,
            "system",
            self._project_id(values),
            normalize_key(values.get("System")),
        )

    async def _manufacturer_id_for_name(self, value: Any) -> UUID | None:
        name = text(value)
        if name is None:
            return None
        for source_row in self.rows["tbl_Manufacturer"]:
            if normalize_key(source_row.values.get("Name")) == normalize_key(name):
                return wbs_uuid("tbl_Manufacturer", source_row.key, "manufacturers")
        manufacturer_id = stable_uuid(WBS_SOURCE, "manufacturer", normalize_key(name))
        await self.context.upsert(
            "manufacturers",
            {
                "id": manufacturer_id,
                "legacy_id": None,
                "is_active": True,
                "name": name,
                "description": "Fabricante incorporado desde tbl_Component.",
            },
        )
        return manufacturer_id

    @staticmethod
    def _worker_role(values: dict[str, Any]) -> tuple[str, str]:
        role = normalize_key(values.get("Role"))
        if role == "administrator":
            return "ADMINISTRATOR", "Administrador"
        if role == "boss":
            return "BOSS", "Jefe"
        if boolean(values.get("Coordinator")):
            return "COORDINATOR", "Coordinador"
        return "MAINTENANCE_ENGINEER", "Ingeniero de Mantenimiento"
