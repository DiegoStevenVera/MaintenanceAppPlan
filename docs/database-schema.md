# Database Schema

**Version:** 0.3  
**Migration head:** `20260724_0005`  
**Status:** Schema and legacy importer implemented; production import not executed

## 1. Language and Scope

Schema names, code, and technical documentation use English. User-visible values and imported
business data remain in Spanish.

The database currently contains 72 application tables plus `alembic_version`. The second schema
round adds 52 tables. Consumable inventory remains deferred by product decision.

The existing `assets`, `preventive_schedules`, `corrective_events`, `users`, and
`app_state_snapshots` structures remain compatible with the current Swift mock. New normalized
columns and tables will support the gradual replacement of the snapshot endpoint with domain APIs.

## 2. Main Table Groups

### Organizational Context

- `sites`, `projects`, `stages`, `systems`, `subsystems`, `work_areas`
- `geographic_locations`: recursive physical location tree, with levels N1 through N4.
- `asset_stage_assignments`, `location_stage_assignments`: time-bounded rollout-stage scope.

Stage is planning metadata. It does not restrict technician visibility within a project.

### Asset Catalog and Hierarchy

- `asset_types`: part-number/type-level definition and serial-number policy.
- `equipment_categories`, `equipment_kinds`, `equipment_kind_categories`
- `assets`: every large equipment, component, software item, card, rack, or cable that needs
  identity or history.
- `slot_types`, `slot_locations`, `slot_images`: reusable physical skeleton per
  `equipment_kind`.
- `asset_assignments`: temporal installation/position history.
- `asset_closure`: fast ancestor and descendant queries.
- `asset_composition_rules`, `asset_composition_positions`: advisory composition rules.
- `asset_statuses`, `inventory_locations`, `movement_types`, `asset_movements`
- `asset_replacements`: paired removal and installation during maintenance.
- `manufacturers`, `documentation_resources`

An `Equipo` is an `assets` row with `is_business_anchor = true`; it is not a separate table.

### Preventive Definitions and Planning

- `maintenance_templates`
- `maintenance_template_scopes`
- `maintenance_template_steps`
- `maintenance_template_tests`
- `maintenance_template_test_options`
- `maintenance_template_conclusions`
- `maintenance_template_personnel`
- `maintenance_template_tools`
- `maintenance_plan_entries`
- `preventive_schedules`: transitional schedule read model used by the current frontend.

### Maintenance Execution

- `maintenance_activities`: common preventive/corrective lifecycle.
- `maintenance_activity_assets`: one or many targets with explicit roles.
- `maintenance_activity_assignments`
- `maintenance_status_history`, `maintenance_reopen_records`
- `corrective_events`: transitional corrective read model linked to the common activity.
- `corrective_event_comments`
- `maintenance_knowledge_comments`: reusable preventive/template/equipment knowledge.

The four operational states remain `SCHEDULED`, `IN_PROGRESS`, `COMPLETED`, and `CLOSED`.

### Reports and Versions

- `maintenance_reports`: a logical report within an activity.
- `report_versions`: corrections/versions of the same logical report.
- `report_version_assets`: immutable asset-scope snapshots for each version.
- `preventive_report_details`, `preventive_step_results`, `preventive_test_results`
- `corrective_report_details`, `corrective_report_blocks`, `corrective_activities`
- `report_participants`, `report_signatures`
- `attachments`, `generated_reports`

The logical-report layer allows one preventive activity to own its main preventive report and,
when required, an additional calibration report. Corrective activities can own one report per
shift. `stop_after_block_order` controls PDF visibility and does not create a new lifecycle state.

### Track Circuit Calibration

- `calibration_report_details`: report-level track circuit metadata.
- `calibration_measurements`: ordered measurements linked to an asset and an `asset_role`.

One transmitter and one or many receivers are represented as separate measurement rows within the
same report version.

### Tools

- `tools`
- `tool_certifications`
- `report_tool_usages`

Consumables are not included in this migration.

### Incremental Import Control

- `data_import_batches`: one auditable execution per source file.
- `legacy_record_mappings`: stable source key, source row hash, and target identity.
- `data_import_row_results`: inserted, updated, unchanged, skipped, or failed result per row.

The importer reads source rows directly, validates them before transformation, and stores batch,
row-result, and source-to-target audit records. It does not require persistent staging tables.
One source row may map to several targets through `mapping_role`.

## 3. Legacy Workbook Mapping

### `WBS_V2.xlsx`

| Legacy sheet | Primary target |
|---|---|
| `tbl_Documentation` | `documentation_resources` |
| `tbl_Work_Area` | `work_areas` |
| `tbl_Subsystem` | `subsystems` |
| `tbl_Activity` | `maintenance_templates` |
| `tbl_Proyect` | organizational catalog tables |
| `tbl_Area` | `geographic_locations` |
| `tbl_Stage` | `stages` |
| `tbl_Equipment_Category` | `equipment_categories` |
| `tbl_EquipmentKind` | `equipment_kinds` |
| `tbl_Equipment` | `assets`, `asset_stage_assignments` |
| `tbl_Equipment_Activity_Area` | `maintenance_template_scopes` |
| `tbl_SlotImage` | `slot_images` |
| `tbl_ComponentType` | `asset_types` |
| `tbl_Component` | `assets`, optionally `asset_assignments` |
| `tbl_ComponentStatus` | `asset_statuses` |
| `tbl_SlotLocation` | `slot_locations` |
| `tbl_TypeSlot` | `slot_types` |
| `tbl_TypeActivity` | `maintenance_action_types` |
| `tbl_MovementType` | `movement_types` |
| `tbl_Location` | `inventory_locations` |
| `tbl_LocationType` | `location_types` |
| `tbl_Manufacturer` | `manufacturers` |
| `tbl_Conclusion` | `maintenance_template_conclusions` |
| `tbl_Activity_Task` | `maintenance_template_steps` |
| `tbl_Personal_Activity` | `maintenance_template_personnel` |
| `tbl_Tools_Activity` | `maintenance_template_tools` |
| `tbl_Test_Task` | `maintenance_template_tests` |
| `tbl_Test_Result` | `maintenance_template_test_options` |
| `tbl_Worker` | `users` |
| `tbl_Tool` | `tools` |
| `tbl_Certification` | `tool_certifications` |
| Consumable sheets | Deferred |

### `BD_Storage.xlsx`

| Legacy sheet | Primary target |
|---|---|
| `Maintenance_Storage` | `maintenance_activities`, logical reports, version details |
| `tbl_Scheduled_Activities` | `maintenance_plan_entries`, activities, schedule bridge |
| `tbl_WorkMaintenanceCorrective` | corrective `maintenance_activities` |
| `tbl_Reports` | `generated_reports` |
| `tbl_CorrectiveReports_Detail` | corrective reports, versions, and details |
| `tbl_CorrectiveActivities` | `corrective_activities` |
| `tbl_Workers_Activity` | activity assignments and report participants |
| `Tools_Activity` | `report_tool_usages` |
| `Tasks_activity` | `preventive_step_results` |
| `tbl_Test_Result_Activity` | `preventive_test_results` |
| `Images_Activity` | `attachments` |
| `tbl_Calibration` | calibration report details and measurements |
| `tbl_WorkOrderComponent` | `asset_replacements` |
| `tbl_ComponentMovement` | `asset_movements` |
| `tbl_InstalledComponent` | `asset_assignments` |
| Consumable sheets | Deferred |

Some source rows may map to more than one normalized target. The importer will keep this
traceable through `legacy_record_mappings` and row-level results.

See `docs/legacy-data-import.md` for validation, dry-run, initial import, incremental refresh, and
audit commands.

## 4. Windows Commands

From `backend`:

```powershell
.\app_mant\Scripts\alembic.exe current
.\app_mant\Scripts\alembic.exe upgrade head
.\app_mant\Scripts\alembic.exe check
.\app_mant\Scripts\pytest.exe -q
```

Open PostgreSQL:

```powershell
docker exec -it maintenance_postgres psql -U root_mantto -d maintenance_db
```

Useful `psql` commands:

```text
\dt
\d assets
\d slot_locations
\d maintenance_activities
\d maintenance_reports
\d report_versions
\d calibration_measurements
\d data_import_batches
```

List tables with SQL:

```sql
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
```

Check the migration head:

```sql
SELECT version_num FROM alembic_version;
```
