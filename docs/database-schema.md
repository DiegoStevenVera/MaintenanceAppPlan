# Database Schema

**Version:** 0.5
**Migration head:** `20260730_0010`
**Status:** Normalized schema, legacy importer, PCON annual administration, and audit implemented; local import executed

## 1. Language and Scope

Schema names, code, and technical documentation use English. User-visible values and imported
business data remain in Spanish.

The database currently contains 73 application tables plus `alembic_version`. Consumable
inventory remains deferred by product decision.

The existing `assets`, `preventive_schedules`, `corrective_events`, `users`, and
`app_state_snapshots` structures remain compatible with the current Swift mock. New normalized
columns and tables will support the gradual replacement of the snapshot endpoint with domain APIs.

## 2. Main Table Groups

### Organizational Context

- `sites`, `projects`, `stages`, `systems`, `subsystems`, `work_areas`
- `geographic_locations`: recursive physical location tree, with levels N1 through N4.
- `asset_stage_assignments`, `location_stage_assignments`: time-bounded rollout-stage scope.

Stage is planning metadata. It does not restrict maintenance engineer visibility within a project.

### Identity and Access

- `users`: account identity, role, active state, profile metadata, and Argon2 password hash.
- `auth_refresh_sessions`: hashed refresh-token identity, expiration, rotation usage, and
  revocation state.

Access tokens are short-lived signed JWTs and are not persisted. Refresh tokens are also signed,
but their SHA-256 digest is stored so logout, password changes, and token rotation can revoke the
corresponding session without storing the bearer token itself.

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
During WBS import, nested component parentage is derived from occupied ancestor slots. For example,
a board installed under `/Cubículo/PCSG 1/...` has the PCSG component as its immediate asset parent,
while the PCSG component has the business anchor equipment as its parent.

### Preventive Definitions and Planning

- `maintenance_templates`
- `maintenance_template_scopes`
- `maintenance_template_steps`
- `maintenance_template_tests`
- `maintenance_template_test_options`
- `maintenance_template_conclusions`
- `maintenance_template_personnel`
- `maintenance_template_tools`
- `maintenance_plan_entries`: each row is one required monthly execution. The
  annual PCON cell quantity is derived by counting rows for the same year,
  month, template scope, and equipment maintenance. `planning_status` supports
  logical cancellation without losing traceability.
- `pcon_annual_plans`: persisted year header and optional copied-from year.
- `pcon_annual_plan_scopes`: explicit annual row membership, including rows
  whose twelve monthly quantities are zero.
- `pcon_plan_changes`: immutable audit of annual copies, row additions,
  quantity edits, moves, removals, and cancellations.
- `preventive_schedules`: transitional schedule read model used by the current frontend.
- `weekly_planning_sessions`: versioned Monday-Sunday PCON agreement blocks.
- `maintenance_schedule_revisions`: proposed, confirmed, and superseded exact
  date ranges for preventive activities. Proposals preserve previous times and
  the rescheduling reason.

PCON keeps annual quantity, monthly occurrence, and exact-date concerns
separate. Increasing a quantity creates individually schedulable plan entries;
reducing it can remove only untouched entries. Changing a proposal does
not update `maintenance_activities.scheduled_start_at` or
`scheduled_end_at`. Confirming a weekly session updates all of its activities
and the transitional `preventive_schedules` rows in one database transaction.
Weekly planning was introduced by `20260730_0009`; annual administration,
membership, logical cancellation, and audit were added by `20260730_0010`.

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
  Corrective rows store `report_year` and an annual `report_number`; the partial
  unique index `uq_corrective_reports_year_number` prevents two corrective
  reports from receiving the same `NNNN/YY` identifier.
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
same report version. New reports use `TRANSMITTER` and `RECEIVER_N` roles; imported
`TRANSMISOR` and `RECEPTOR` values remain readable for source traceability. A track-circuit
preventive finalization writes the main preventive version and its companion `CALIBRATION`
version in the same transaction. The companion copies the selected participants and signatures.
Historical imported calibration versions without their own participant rows fall back to the
matching main preventive version when read; imported source rows are not rewritten.

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

For the meaning and provenance of every normalized table, see
`docs/data-dictionary.md`. Reusable operational queries are in
`docs/sql-query-cookbook.sql`.

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

## 5. Migración 20260819_0012

La migración `20260819_0012_corrective_targets_tools_sap` agrega selección de
varios activos afectados y criticidad individual para correctivos, grupos lógicos
de equipos ATS y snapshots de herramientas usadas en reportes. Se aplica con
`alembic upgrade head` en cada entorno, antes de desplegar la app iOS que consume
estos campos.

La migración `20260819_0013_asset_groups_and_event_criticality` introduce
`asset_groups` y `asset_group_members` para que todos los preventivos usen un
alcance 1:N uniforme. Además separa los gabinetes físicos CRK/ERK de los grupos
históricos y establece `corrective_events.is_critical` como el único indicador
crítico del evento.

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
