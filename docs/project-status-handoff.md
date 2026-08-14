# Project Status Handoff

**Last updated:** 2026-07-27
**Target continuation environment:** Company Mac
**Migration head:** `20260730_0010`
**Legacy import status:** Implemented, validated, and imported into local PostgreSQL

This is the operational handoff for continuing MaintenanceApp on the company Mac. It records the
current technical state, the exact database/bootstrap/import procedure, and the remaining backend
and frontend work. Project documentation and code use English. User-visible strings and imported
business data use Spanish.

## 1. Read This First

The project has three different persistence layers at the moment:

1. The normalized PostgreSQL domain schema is implemented.
2. The Excel-to-PostgreSQL importer is implemented and validated.
3. The iOS login uses a real authenticated session, while several operational mock actions still
   save a transitional `app_state_snapshots` JSON document.

Therefore, importing the Excel files does **not** automatically make all imported data appear in
the iOS app. The next development stage is to expose the normalized tables through domain APIs and
replace the frontend snapshot calls feature by feature.

Do not connect Swift directly to PostgreSQL. The required path is always:

```text
SwiftUI -> FastAPI domain endpoint -> SQLAlchemy repository -> PostgreSQL
```

Do not create tables manually with ad hoc SQL or `Base.metadata.create_all()`. Alembic is the
authoritative schema creation mechanism.

## 2. Critical Actions Before Moving To The Mac

The current Windows worktree contains modified and untracked implementation files. A pull on the
Mac will only receive committed and pushed files.

Before leaving the Windows laptop:

```powershell
git status
git add <reviewed project files>
git commit -m "Implement normalized schema and legacy Excel importer"
git push
```

Review the staged files before committing. Do not commit `.env`, virtual environments, generated
files, or secrets.

### Excel Files Are Not Tracked

The current `.gitignore` intentionally ignores:

```text
docs/OldVersionApp/Database/*
docs/OldVersionApp/Formats/*
```

These source files will **not** arrive through Git:

```text
docs/OldVersionApp/Database/WBS_V2.xlsx
docs/OldVersionApp/Database/BD_Storage.xlsx
```

Current approximate sizes are 1.2 MB and 1.7 MB. Transfer them securely to the company Mac and
place them at the exact paths above. Do not remove the ignore rule or commit company data unless
that has been explicitly approved.

Optionally record checksums before and after transfer:

```powershell
Get-FileHash docs\OldVersionApp\Database\WBS_V2.xlsx -Algorithm SHA256
Get-FileHash docs\OldVersionApp\Database\BD_Storage.xlsx -Algorithm SHA256
```

On macOS:

```bash
shasum -a 256 docs/OldVersionApp/Database/WBS_V2.xlsx
shasum -a 256 docs/OldVersionApp/Database/BD_Storage.xlsx
```

## 3. Current Implementation State

### Database

Alembic creates 73 application tables plus `alembic_version`.

Current migrations:

- `20260705_0001_initial_schema`
- `20260706_0002_app_state_snapshot`
- `20260724_0003_foundational_catalogs`
- `20260724_0004_complete_operational_schema`
- `20260724_0005_expand_legacy_record_mappings`
- `20260727_0006_standardize_maintenance_engineer_role`
- `20260727_0007_auth_refresh_sessions`

Role terminology is now consistent across active code and documentation:

- Internal/API/database role: `MAINTENANCE_ENGINEER`
- Swift role case: `maintenanceEngineer`
- User-visible label: `Ingeniero de Mantenimiento`
- Historical report field: `engineerName`

Migration `20260727_0006` updates existing `users` rows and the transitional JSON snapshot. The
legacy term remains only inside that migration's upgrade/downgrade conversion and in
`docs/raw-context.md`, which preserves original interview/source wording.

Main normalized groups:

- Organizational context and rollout stages
- Geographic hierarchy
- Asset types, large equipment, components, slots, assignments, movements, and replacements
- Preventive templates, scopes, steps, tests, planning, and schedules
- Common preventive/corrective maintenance lifecycle
- Logical reports and report versions
- Preventive and corrective report details
- Participants, signatures, comments, attachments, and generated files
- Track-circuit calibration reports and measurements
- Tools and certifications
- Import batches, row results, hashes, and source-to-target mappings

Consumables remain deferred by product decision.

### Legacy Importer

The portable importer is in:

```text
backend/src/legacy_import/
```

Supported commands:

```text
python -m legacy_import validate
python -m legacy_import import-wbs
python -m legacy_import import-storage
python -m legacy_import import-all
```

Important behavior:

- Uses deterministic target IDs.
- Uses source-row hashes for incremental runs.
- Uses PostgreSQL upserts instead of deleting destination tables.
- Supports one Excel row mapping to multiple normalized rows.
- Records committed batches and row-level results.
- `--dry-run` executes constraints and transformations and then rolls back.
- `--strict` rolls back the complete import when any source row fails.
- Consumable sheets are not imported.

The latest strict combined dry run validated:

| Workbook | Processed rows | Failed rows |
|---|---:|---:|
| `WBS_V2.xlsx` | 3,136 | 0 |
| `BD_Storage.xlsx` | 27,131 | 0 |

The run returned exit code `0` and rolled back. The Windows database still showed:

```text
data_import_batches = 0
legacy_record_mappings = 0
data_import_row_results = 0
```

No real Excel data has been committed yet.

### Backend

Implemented endpoints:

- `GET /health`
- `GET /health/db`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
- `GET /api/v1/auth/me`
- `POST /api/v1/auth/change-password`
- `GET /api/v1/app-state/current`
- `PUT /api/v1/app-state/current`
- `GET /api/v1/assets`
- `GET /api/v1/assets/{asset_id}`
- `GET /api/v1/assets/{asset_id}/tree`
- `GET /api/v1/assets/{asset_id}/history`
- `GET /api/v1/maintenance-activities`
- `GET /api/v1/maintenance-activities/{activity_id}`
- `GET /api/v1/maintenance-activities/{activity_id}/reports`
- `GET /api/v1/schedules`
- `GET /api/v1/corrective-events`
- `GET /api/v1/corrective-events/{event_id}`
- `POST /api/v1/corrective-events`

The normalized Equipment read slice is implemented. Asset list/search/filter, detail, component
tree with slot paths, and equipment-specific maintenance history read canonical normalized tables.

The normalized Maintenance read slice is also implemented. Preventive and corrective list/detail
queries read `maintenance_activities`, `maintenance_activity_assets`, `maintenance_reports`,
`report_versions`, and the normalized report detail/result tables. Server-side search, status,
subsystem, and date filters are available. Schedule and corrective-event endpoints still expose
transitional DTOs for compatibility. Lifecycle commands, report writes, comments, signatures,
attachments, stock reads, calibration, preventive/corrective PDF generation, download, and the
iOS viewer/Share Sheet are implemented. Broader inventory movements outside corrective component
replacement remain pending.

Authentication foundation is implemented:

- Passwords use Argon2. Existing `mock:<password>` values are upgraded to Argon2 after the first
  successful login.
- Signed access tokens expire after 15 minutes by default.
- Signed refresh tokens expire after 7 days, rotate on use, and have revocable digests in
  `auth_refresh_sessions`.
- `/auth/logout`, `/auth/change-password`, and an interactive administrator password-reset CLI are
  available.
- Domain endpoints require a Bearer access token.
- `BOSS` is read-only on the currently implemented write endpoints.
- Swift stores access and refresh tokens in Keychain and restores or renews the session at launch.
- In non-production environments, Administrators can open a real temporary session for another
  available role and restore their protected Administrator session.
- Login no longer depends on `app_state_snapshots`.

### iOS Frontend

Project:

```text
frontend/ios/MaintenanceAppMock.xcodeproj
```

The visual and interaction mock is substantially implemented for:

- Login and profile
- Dashboard
- Preventive lists, details with reusable comments, report form, signatures, and preview
- Corrective lists, creation, details with event-local comments, dynamic report form, signatures, and preview
- Equipment search/detail/history
- Stock screens
- Boss metrics/read-only behavior

Current persistence is being replaced one vertical slice at a time:

- Authentication and Equipment use normalized authenticated APIs.
- Stock uses the normalized authenticated `GET /api/v1/assets/stock` API.
- Access and refresh tokens are stored in Keychain and Bearer authentication is attached through
  `SessionStore.withValidAccessToken`.
- Equipment list, search, subsystem filter, detail, component tree, and historical maintenance no
  longer read from `MockMaintenanceStore`.
- Preventive and corrective list/detail screens use the authenticated normalized maintenance API.
- Preventive detail displays report versions, steps, and tests when the imported report contains
  them. Corrective detail displays event context, failure analysis, performed activities, validation,
  and conclusions when available.
- Remaining operational mock mutations still call `persistRemoteState()` and send the transitional
  snapshot until their respective domain APIs are implemented.

The class and several models still use `Mock` names. Renaming is lower priority than replacing the
snapshot data flow.

## 4. Company Mac Prerequisites

Install or confirm:

- Git
- Xcode and Xcode command-line tools
- Docker Desktop
- Python 3.12
- `make` (provided by Xcode command-line tools)

Checks:

```bash
git --version
xcodebuild -version
docker --version
docker compose version
python3.12 --version
make --version
```

Install Xcode command-line tools if necessary:

```bash
xcode-select --install
```

Open Docker Desktop and wait until its engine is running before using Docker Compose.

## 5. Get The Project On The Mac

Clone the repository or update an existing clone:

```bash
git clone <repository-url> MaintenanceApp
cd MaintenanceApp
```

For an existing clone:

```bash
git status
git pull --ff-only
```

Confirm that the migration and importer arrived:

```bash
test -f backend/migrations/versions/20260724_0005_expand_legacy_record_mappings.py
test -f backend/migrations/versions/20260727_0006_standardize_maintenance_engineer_role.py
test -f backend/src/legacy_import/cli.py
test -f docs/legacy-data-import.md
```

Place the two manually transferred Excel files under
`docs/OldVersionApp/Database/` and verify:

```bash
test -f docs/OldVersionApp/Database/WBS_V2.xlsx
test -f docs/OldVersionApp/Database/BD_Storage.xlsx
```

## 6. Create The Python Environment

The backend `Makefile` contains the backend and Compose commands. It uses the
currently active Python environment by default; override it with `PYTHON=/path/to/python`
when needed.

From the backend directory:

```bash
cd backend
python3.12 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -e ".[dev]"
```

Verify:

```bash
python -c "import fastapi, sqlalchemy, asyncpg, alembic, openpyxl"
python -m pytest tests -q
```

Expected current test result:

```text
66 passed
```

A Starlette/httpx deprecation warning may still appear. It does not currently fail the suite.

## 7. Configure The Local Environment

From the backend directory:

```bash
cd backend
cp .env.example .env
```

Recommended local development values:

```dotenv
APP_NAME=MaintenanceApp API
ENVIRONMENT=local
API_V1_PREFIX=/api/v1
BACKEND_CORS_ORIGINS=http://localhost:3000,http://127.0.0.1:3000
REPOSITORY_BACKEND=postgres
POSTGRES_DB=maintenance_app
POSTGRES_USER=maintenance_user
POSTGRES_PASSWORD=<local-secret>
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
```

Environment files are selected from `backend/environments/<name>/.env`; they
are never committed. See `docs/environment-setup.md` for LOCAL, DEV and QA.

PostgreSQL applies its database/user/password environment values only when the Docker volume is
first initialized. Changing `.env` later does not change credentials inside an existing volume.

## 8. Create PostgreSQL And The Complete Schema

### Fresh Mac Database

Start PostgreSQL and FastAPI:

```bash
cd backend
make ENV=local build
make ENV=local status
```

Wait for `maintenance_postgres` to become healthy:

```bash
make ENV=local logs
```

Create the complete schema with Alembic:

```bash
make ENV=local migrate
make ENV=local current
docker compose --env-file environments/local/.env exec backend alembic check
```

Expected head:

```text
20260812_0011 (head)
```

Expected Alembic check:

```text
No new upgrade operations detected.
```

Verify directly:

```bash
docker compose --env-file environments/local/.env exec postgres \
  psql -U maintenance_user -d maintenance_app
```

Inside `psql`:

```sql
SELECT version_num FROM alembic_version;

SELECT count(*) AS public_tables
FROM pg_tables
WHERE schemaname = 'public';

\dt
\d assets
\d maintenance_activities
\d maintenance_reports
\d report_versions
\d legacy_record_mappings
```

Expected `public_tables` is 73: 72 application tables plus `alembic_version`.

Exit:

```text
\q
```

If custom PostgreSQL credentials are used, substitute them in every `psql` command.

### Recreating A Disposable Local Database

Only when the local Mac database is disposable:

```bash
cd backend
docker compose --env-file environments/local/.env down -v
make ENV=local build
make ENV=local migrate
```

`docker compose down -v` permanently deletes the local PostgreSQL volume. Never run it against data
that must be retained.

## 9. Legacy Migration Procedure

Do not run `app.seed` before the clean data-migration validation. Seed data is a compatibility
fixture for the old snapshot frontend, not production migration data.

Run all importer commands from `backend`.

### Step 1: Validate Excel Structure

```bash
cd backend

./.venv/bin/python -m legacy_import validate \
  --kind wbs \
  --file ../docs/OldVersionApp/Database/WBS_V2.xlsx

./.venv/bin/python -m legacy_import validate \
  --kind storage \
  --file ../docs/OldVersionApp/Database/BD_Storage.xlsx
```

Stop if either command fails. Exact duplicate source rows are counted and skipped; conflicting rows
with the same source key are rejected.

### Step 2: Mandatory Strict Dry Run

```bash
./.venv/bin/python -m legacy_import import-all \
  --wbs-file ../docs/OldVersionApp/Database/WBS_V2.xlsx \
  --storage-file ../docs/OldVersionApp/Database/BD_Storage.xlsx \
  --dry-run \
  --strict
```

Required result:

- Exit code `0`
- `"rolled_back": true`
- WBS failed rows: `0`
- Storage failed rows: `0`

If it fails, do not remove `--strict` and do not run the real import. Review `error_samples` and the
per-sheet counts.

### Step 3: Optional Backup

For a fresh empty database this backup is not essential, but it is good practice:

```bash
docker compose --env-file environments/local/.env exec -T postgres pg_dump \
  -U maintenance_user \
  -d maintenance_app \
  -Fc > maintenance_before_import.dump
```

The dump file contains database data and must be protected appropriately.

### Step 4: Commit The Initial Import

Run the same command without `--dry-run`:

```bash
./.venv/bin/python -m legacy_import import-all \
  --wbs-file ../docs/OldVersionApp/Database/WBS_V2.xlsx \
  --storage-file ../docs/OldVersionApp/Database/BD_Storage.xlsx \
  --strict
```

Required result:

- `"rolled_back": false`
- Failed rows: `0`
- Two committed import batches

### Step 5: Audit The Import

Open PostgreSQL:

```bash
cd backend
docker compose --env-file environments/local/.env exec postgres \
  psql -U maintenance_user -d maintenance_app
```

Audit SQL:

```sql
SELECT id, source_file_name, import_mode, status, total_rows,
       inserted_rows, updated_rows, unchanged_rows, failed_rows,
       started_at, completed_at
FROM data_import_batches
ORDER BY started_at;

SELECT source_table, operation, status, count(*)
FROM data_import_row_results
GROUP BY source_table, operation, status
ORDER BY source_table, operation, status;

SELECT source_table, count(*) AS mappings
FROM legacy_record_mappings
GROUP BY source_table
ORDER BY source_table;

SELECT count(*) FROM assets;
SELECT count(*) FROM maintenance_activities;
SELECT count(*) FROM maintenance_reports;
SELECT count(*) FROM report_versions;
SELECT count(*) FROM preventive_step_results;
SELECT count(*) FROM preventive_test_results;
SELECT count(*) FROM calibration_measurements;
SELECT count(*) FROM attachments;
```

Inspect important migrated business cases:

```sql
SELECT id, name, is_business_anchor, parent_id, serial_number,
       serial_number_status
FROM assets
WHERE name ILIKE '%Zone Controller%'
   OR name ILIKE '%Frontam%'
   OR name ILIKE '%CBDAC 1018%'
ORDER BY name;

SELECT ma.title, mr.report_kind, rv.version_number, rv.document_status
FROM maintenance_activities ma
JOIN maintenance_reports mr ON mr.maintenance_activity_id = ma.id
JOIN report_versions rv ON rv.maintenance_report_id = mr.id
ORDER BY ma.title, mr.report_kind, rv.version_number;
```

### Step 6: Verify Idempotency

Run another strict dry run after the committed import:

```bash
cd backend
./.venv/bin/python -m legacy_import import-all \
  --wbs-file ../docs/OldVersionApp/Database/WBS_V2.xlsx \
  --storage-file ../docs/OldVersionApp/Database/BD_Storage.xlsx \
  --dry-run \
  --strict
```

Unmodified source rows should be reported as `unchanged`, not inserted again.

## 10. Incremental Excel Refreshes

WBS is relatively stable. `BD_Storage.xlsx` changes regularly.

For a new `BD_Storage.xlsx` snapshot:

```bash
cd backend

./.venv/bin/python -m legacy_import import-storage \
  --file ../docs/OldVersionApp/Database/BD_Storage.xlsx \
  --all \
  --dry-run \
  --strict

./.venv/bin/python -m legacy_import import-storage \
  --file ../docs/OldVersionApp/Database/BD_Storage.xlsx \
  --all \
  --strict
```

The importer uses source keys and hashes:

- Existing unchanged rows remain `unchanged`.
- New source keys are inserted.
- Changed source keys update their normalized targets.
- Destination tables are not truncated.

Use `--force` only after importer transformation logic changes and every row must be recalculated.

For moving an already populated PostgreSQL database exactly as-is between machines or onto a
server, use `pg_dump`/`pg_restore`. Alembic moves schema versions; it is not a database data-copy
tool.

## 11. Run The Backend On The Mac

From the backend directory:

```bash
cd backend
REPOSITORY_BACKEND=postgres ./.venv/bin/uvicorn \
  app.main:app \
  --app-dir src \
  --reload \
  --host 0.0.0.0
```

Equivalent direct command:

```bash
cd backend
REPOSITORY_BACKEND=postgres ./.venv/bin/uvicorn \
  app.main:app \
  --app-dir src \
  --reload \
  --host 0.0.0.0
```

Check:

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/health/db
open http://127.0.0.1:8000/docs
```

An imported user with `mock:123456` can log in once and is upgraded automatically to Argon2.
Users still marked `!legacy-import-disabled!` must receive a temporary password through
`cd backend && make user-set-password EMAIL=<email>` or `cd backend && make user-bootstrap-disabled`. The iOS login does not
require an `app_state_snapshots` compatibility payload.

If the old mock UI must be demonstrated temporarily, use `app.seed` only in a separate disposable
development database.

## 12. Required Backend Work

The schema is broad enough for V1. The main backend gap is now application behavior and API
coverage, not more bulk table creation.

### P0: Authentication And Authorization

Completed foundation:

- Argon2 password storage and legacy temporary-hash upgrade.
- Controlled interactive password bootstrap/reset.
- Signed access and rotating refresh tokens.
- Refresh-session revocation on logout and password change.
- Current-user resolution and role dependencies in FastAPI.
- `BOSS` read-only enforcement for the existing writes.
- Keychain-backed Swift session restoration.

Remaining workflow-specific authorization:

- Attach the current user identity to every future domain write.
- Apply project scope once project membership is added to the authenticated context.

Completed lifecycle authorization:

- Maintenance Engineer, Coordinator, and Administrator can start and complete maintenance.
- Every role except Boss can reopen `COMPLETED`.
- Only Coordinator and Administrator can close, or reopen `CLOSED`.
- Every lifecycle write records the authenticated user.

### P0: Normalized Read APIs

Implement DTOs, repositories, services, routers, pagination, and filtering for:

- Dashboard counts and Boss metrics
- Stock and component replacement queries
- Preventive activities and schedule details
- Corrective activity/event details
- Logical reports and version history
- Preventive report steps and test results
- Corrective dynamic blocks and performed activities
- Participants, signatures, comments, attachments, and generated reports
- Calibration reports and transmitter/receiver measurements
- Tools and certifications

Completed:

- Asset/equipment list with search, pagination, and subsystem/category/status filters
- Equipment detail from normalized assets, types, manufacturer, assignment, and location tables
- Component hierarchy and slot paths from `asset_closure`, `asset_assignments`, and `slot_locations`
- Equipment-specific completed/closed maintenance history and latest finalized report version
- Swift Equipment list/detail/tree/history using the authenticated API session
- Normalized maintenance activity list/detail/reports API and authenticated Swift preventive/corrective read screens
- Preventive detail guide endpoint and Swift UI separation: template steps/tests are instructional,
  current activity versions contain its execution data, and previous reports match the same
  template plus business-anchor equipment before opening immutable version detail/PDF.

Suggested first vertical slice:

```text
GET /api/v1/maintenance-activities
GET /api/v1/maintenance-activities/{id}
GET /api/v1/maintenance-activities/{id}/reports
GET /api/v1/report-versions/{id}
```

This first maintenance read slice and its lifecycle command extension are complete. The next slice
is normalized report editing and versioning.

### P1: Lifecycle Commands

Prefer explicit commands over arbitrary status updates:

```text
POST /api/v1/maintenance-activities/{id}/start
POST /api/v1/maintenance-activities/{id}/complete
POST /api/v1/maintenance-activities/{id}/close
POST /api/v1/maintenance-activities/{id}/reopen
```

Every transition should:

- Validate the current state.
- Validate the caller's role.
- Update timestamps and responsible user IDs.
- Insert `maintenance_status_history`.
- Insert `maintenance_reopen_records` when applicable.

Implemented:

- Explicit start, complete, close, and reopen endpoints.
- State-machine and role validation with `409` for an invalid transition and `403` for a forbidden
  role.
- Normalized activity timestamp/user updates and preventive/corrective bridge synchronization.
- Append-only status history and reopen reason records.
- Swift action panels driven by current state and authenticated role, with confirmation,
  progress/error states, and dashboard/list refresh.

### P1: Report Editing And Versioning

Implemented transactional endpoints for:

- Creating/updating preventive drafts and step/test results.
- Creating/updating corrective reports and performed activities.
- Dynamic `Cambio de componente` blocks with equipment and stock assets from PostgreSQL.
- Atomic assignment, hierarchy, status, closure, and replacement records on finalization.
- Participant selection and drawn signature strokes.
- Evidence file storage with normalized metadata and checksum.
- Finalizing an immutable version and creating a new draft after reopening.

Do not overwrite finalized report versions. Create a new `report_versions` row for corrections.

### P1: Comments And Attachments

Completed:

- Preventive knowledge comments are reusable by template and/or large equipment.
- Corrective comments belong to one corrective event.
- Signature strokes are stored with explicit participant/user ownership.
- Read-only report version detail and PDF generation expose only participants selected for that
  saved version; unselected rows remain available only to the editable draft.
- The normalized Corrective tab restores the `+` flow for Maintenance Engineer, Coordinator, and
  Administrator. Creation resolves context from PostgreSQL and atomically persists the event,
  MaintenanceActivity, business-anchor/affected asset links, and initial status history.
- Evidence bytes use configurable file storage; PostgreSQL stores metadata and checksum.
- Preventive evidence supports native multi-image gallery selection. A new report version reuses
  immutable files from its source version while creating attachment rows owned by the new version.
- Preventive test results use the option catalog configured for each template test.
- Local attachment and generated-report references are portable keys relative to their configured
  storage roots. `20260812_0011` migrated existing local references and preserves imported external
  URLs. The Docker Compose stack now includes both PostgreSQL and FastAPI, with `backend/storage`
  mounted as persistent host storage for evidence and generated PDFs.

Remaining:

- Preserve a local draft and retry when connectivity returns.

### P2: PDF And Share Sheet

- [x] Generate the canonical preventive PDF from the report-version screen using the official `ML2-STS-FOR-040-ES` code, the Hitachi logo, normalized report data, signatures, and later evidence pages.
- [x] Generate the canonical corrective PDF using `ML2-STS-FOR-041-ES`.
- [x] Persist preventive artifacts in `generated_reports` and expose version detail/download endpoints.
- [x] Let iOS open the returned file with PDFKit and present it through Share Sheet.
- [x] Restrict preventive PDF generation to `FINALIZED` versions in both iOS and the backend.
- [x] Lay out preventive photographic evidence four images per PDF page.
- Calibration reports must remain separate logical reports under the same maintenance activity.

### P2: Planning, Administration, And Metrics

- Coordinator schedule/planning endpoints
- Monthly worker schedule support
- Boss metrics and report drill-down
- Administrator user/catalog/import management
- Import batch monitoring endpoint
- Documentation resources
- Deferred consumable inventory

### Backend Quality Work

- Add PostgreSQL integration tests for repositories and workflow transactions.
- Test authorization for all four roles.
- Add importer tests against a clean temporary PostgreSQL database.
- Add API contract tests matching Swift DTOs.
- Resolve the existing full-repository Ruff findings in routers/import ordering.
- Replace the deprecated Starlette/httpx test integration when practical.
- Add structured logs, request IDs, error envelopes, and audit events.

## 13. Required Frontend Migration

Do not rewrite the visual mock first. Keep the current SwiftUI screens and replace their data source
incrementally.

### Step 1: Networking Foundation

- Completed: persist access and refresh tokens securely in Keychain.
- Completed: restore the session, call `/auth/me`, and rotate refresh tokens when required.
- Completed: add Bearer-token support to the shared `APIClient`.
- Add `PATCH`, `DELETE`, multipart upload, and file download support to `APIClient`.
- Centralize API base URL configuration.
- Add typed API error handling and retry states.
- Confirm local-network permission and App Transport Security settings for a physical iPad.

### Step 2: Split The Store By Domain

`MockMaintenanceStore` may remain temporarily as a facade, but move network/data logic into:

- `SessionStore`
- `AssetService` / `AssetStore`
- `MaintenanceService` / `MaintenanceStore`
- `ReportService` / `ReportStore`
- `CommentService`
- `AttachmentService`

Avoid a large rename-only refactor before behavior is migrated.

### Step 3: Replace Snapshot Reads

Recommended order:

1. Assets/equipment search, detail, hierarchy, and history
2. Preventive and corrective lists
3. Preventive and corrective detail screens
4. Report versions and generated files
5. Dashboard and Boss metrics
6. Stock, tools, planning, and administration

After each slice, remove only the corresponding fields from `RemoteAppState`.

### Step 4: Replace Snapshot Writes

Replace every `persistRemoteState()` call with the relevant command endpoint:

- Start/complete/close/reopen maintenance
- Create a corrective event
- Save/finalize preventive report
- Save/finalize corrective report
- Add comments
- Save participants/signatures
- Upload attachments

Use optimistic UI only with rollback/error feedback. Do not silently ignore failed writes with
`try?`.

### Step 5: Remove The Snapshot Bridge

Delete or disable:

- `GET /api/v1/app-state/current`
- `PUT /api/v1/app-state/current`
- `AppStateService`
- `remoteState()`
- `persistRemoteState()`
- Seed-only full-state factories

Do this only after all screens have domain-backed reads and writes.

### Step 6: iPad Verification

Simulator:

```bash
xcodebuild \
  -project frontend/ios/MaintenanceAppMock.xcodeproj \
  -scheme MaintenanceAppMock \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath tmp/DerivedData \
  build
```

Backend URL in Simulator:

```text
http://127.0.0.1:8000
```

For a physical iPad, run FastAPI with `--host 0.0.0.0` and use:

```text
http://<mac-lan-ip>:8000
```

Find the Mac Wi-Fi address:

```bash
ipconfig getifaddr en0
```

The Mac and iPad must be on a network that allows peer communication. Company network, firewall,
MDM, and ATS policies may block local HTTP; verify before treating an app error as a backend bug.

## 14. Remaining Product Features

Feature status should not be overstated. UI mock coverage does not mean backend persistence exists.

Highest-priority missing production features:

- Broader asset/component stock operations outside the implemented corrective replacement workflow
- Boss metrics and read-only drill-down
- Coordinator planning and worker schedules
- Administrator management
- Backup/restore, secrets, TLS, logs, and deployment design
- Consumables in a later version

The implemented production slice now includes:

- Offline preventive and corrective report drafts with local persistence, autosave,
  automatic/manual retry, cached form context, and optimistic conflict detection.
  Report finalization remains online-only.
- Day and week filters only use an explicit `Date_Activity_Scheduled`.
- Month filters include exact dates in the selected month and rows that only
  have the selected `Year`/`Month`.
- `Date_Activity_Done` remains the execution date.
- The iOS client retrieves all API pages instead of stopping at 100 records.
- Four imported orphan report placeholders remain auditable in PostgreSQL but
  are hidden from operational corrective lists.
- Home uses the normalized maintenance dashboard endpoint. Imported historical
  `COMPLETED` rows without a v1 `completed_at` transition are not counted as
  pending coordinator closure.
- Home receives complete preventive-today, active-corrective, and
  pending-closure collections. Its metric cards behave as mutually exclusive,
  toggleable filters, while the unfiltered state shows preventive and corrective
  operational sections together.
- Corrective logical reports use a concurrency-safe annual sequence stored as
  `report_year` plus `report_number` and displayed as `NNNN/YY`. Existing data
  was backfilled deterministically by effective maintenance date.
- Preventive PDF rendering now follows the approved compact Excel/PDF structure
  with four photographic evidences per page. Corrective PDF metadata uses the
  generation date, configurable FOR code, and annual report number.

## 15. Recommended Work Order

1. Keep PostgreSQL and FastAPI running with the imported data.
2. Validate lifecycle permissions and transitions from the iPad with Engineer, Coordinator, and
   Boss accounts.
3. Validate offline draft recovery and conflict handling on Simulator and physical iPad.
4. Add automated PDF visual-regression fixtures for the approved preventive,
   corrective, and calibration formats.
5. Continue planning, administration, and deployment slices.

Do not start by rewriting all Swift models or adding more schema tables. The shortest reliable path
is one complete backend-to-iPad vertical slice at a time.

## 16. Verification Baseline

Latest completed checks:

- Alembic code head and local database: `20260812_0011`
- Authentication and normalized Equipment PostgreSQL smoke checks: passed
- Backend tests: 57 passed
- Preventive guide PostgreSQL smoke: passed against migrated data, including template steps and
  complete finalized history filtered by exact template/business-anchor equipment
- Maintenance lifecycle policy, API contract, and transactional PostgreSQL smoke checks: passed
- Preventive draft/finalization PostgreSQL smoke: passed with steps, tests, signature, and evidence
- Preventive evidence-version PostgreSQL smoke: passed by reusing three immutable V4 attachments
  in a transactional V5 draft, then rolling the transaction back.
- Preventive PDF evidence-layout smoke: passed; five synthetic images produced two evidence pages
  after the report body.
- Corrective replacement PostgreSQL smoke: passed with assignment/hierarchy update and rollback verification
- Corrective replacement timing smoke: finalizing transactional V3 kept replacement count at 2/2;
  completing the KVM corrective reached COMPLETED with the same 2/2 count and rolled back.
- Corrective report participant catalogs are restricted to 10 active users in Signaling Maintenance
  work area `006a0fb0-8fae-5ec6-88cb-4231d96d172a`.
- Containerized backend smoke: PostgreSQL and FastAPI Compose services healthy; `/health` and
  `/health/db` passed; the official report logo and a migrated relative PDF reference resolved
  inside `/app/storage`.
- Preventive and corrective forms share the collapsed `No seleccionados (N)` participant UI.
- Corrective report version detail now includes immutable replacement snapshots; iOS report-version rows
  open the normalized read-only detail instead of the legacy mock preview.
- Corrective evidence supports selecting up to 20 gallery images in one operation.
- Corrective PDF smoke: passed with the `ML2-STS-FOR-041-ES` HTML/WeasyPrint template, Letter page
  size, sections 1-9, selected participants, and a six-image photographic grid. The latest validated
  preventive and corrective artifacts were persisted with matching generated-report metadata.
- Corrective annual numbering smoke: 2026 contains 31 unique numbers from 1 through 31; generated
  metadata rendered `0031/26` with the current generation date.
- Home dashboard PostgreSQL smoke: collection lengths match their counters for preventive today,
  active correctives, and pending closure.
- Preventive PDF fidelity smoke: generated A4 output matches the approved compact table structure;
  six evidences produced one four-image page and one two-image page.
- Track-circuit calibration vertical slice: completed. Eligible preventive editors capture
  frequency, transmitter jumpers, and 1-4 numbered receivers; save/finalize persists an independent
  `CALIBRATION` version with participants and signatures. The normalized read-only viewer, dedicated
  Letter HTML/WeasyPrint template, persisted PDF endpoint, PDFKit viewer, and iOS Share Sheet use
  the shared report-version contract.
- Equipment history rows now open the shared immutable report-version/PDF screen;
  entries without a finalized version fall back to maintenance detail.
- The Stock tab now reads PostgreSQL through `GET /api/v1/assets/stock`; the
  current database contains 926 assets across 17 inventory locations.
- Non-production Administrator role preview uses real backend-issued user
  sessions. Available roles are derived from active users, and the original
  Administrator session is protected in Keychain for restoration.
- Legacy mock UI cleanup remains staged: the old corrective mock screen is no
  longer navigable, while shared models and `MockMaintenanceStore` still supply
  app-level user/appearance state and must be extracted before deletion.
- Calibration PostgreSQL/PDF smoke: CBDAC 2407 reconstructed its imported transmitter/receiver
  measurements and rendered a one-page Letter PDF. Imported companion versions without participant
  rows read participants from the matching main preventive version without rewriting source data.
- PostgreSQL maintenance read smoke checks: passed (1,810 preventive activities; completed report detail with steps/tests)
- Importer-specific Ruff checks: passed
- iOS Simulator build: passed after connecting lifecycle actions, normalized report forms, and
  preventive guide/history navigation, controlled test-result pickers, and multi-image evidence
- Python compilation: passed
- Strict WBS dry run: 3,136 processed, 0 failed
- Strict storage dry run: 27,131 processed, 0 failed
- Combined import transaction: rolled back as requested
- Import audit tables after dry run: empty

The full repository Ruff command still reports existing issues outside the importer, mainly FastAPI
`Depends` rule findings and import ordering. Treat this as cleanup work, not as an importer failure.

### PCON Native Planning Slice

- Migration `20260730_0009` adds `weekly_planning_sessions` and
  `maintenance_schedule_revisions`.
- Migration `20260730_0010` adds annual plan headers and memberships, logical
  occurrence cancellation, and immutable PCON administrative audit records.
- PostgreSQL now exposes `/api/v1/pcon` annual quantity matrix, monthly
  occurrences, weekly draft/proposal, atomic confirmation, safe quantity
  adjustment, monthly reassignment, and planning-history endpoints.
- A monthly number is the count of individually schedulable
  `maintenance_plan_entries`. For example, a daily ATS maintenance naturally
  produces 28, 30, or 31 occurrences; it is not stored as an isolated scalar.
- Weekly confirmation updates all proposed preventive activity dates in one
  transaction. Any invalid activity, out-of-week range, missing rescheduling
  reason, or same-equipment overlap rolls back the complete block.
- Coordinator and Administrator can edit/confirm. Maintenance Engineer and
  Boss are read-only at both API and SwiftUI layers.
- The iOS application contains a PCON tab with an Excel-analogous annual matrix.
  It uses the hierarchy `subsystem -> category -> location -> equipment ->
  maintenance`, displays all twelve monthly quantities, provides occurrence
  detail/editing per cell, weekly proposal editing, atomic block confirmation,
  and toolbar history.
- A year without persisted data now displays the latest prior plan's 228
  maintenance rows with zero quantities. Coordinator and Administrator can
  explicitly copy the prior year, add an equipment-maintenance row, adjust
  quantities, move untouched occurrences, and remove/cancel occurrences under
  traceability rules.
- Monthly leaf numbers are colored directly by planning state and accompanied
  by a legend; the former state dots were removed to prevent overlap.
- Alembic was upgraded locally to `20260730_0010`.
- PostgreSQL smoke test completed draft, proposal, and confirmation, then
  rolled the transaction back; no production-like imported activity was
  modified.
- Annual repository smoke validation returned 228 maintenance rows and 1,757
  execution occurrences for 2026. A quantity increase was flushed and rolled
  back successfully without modifying imported data.
- A transactional 2027 smoke test validated virtual baseline materialization,
  occurrence creation, month movement, logical removal, and audit creation,
  then rolled back all test data.
- PCON-focused Ruff checks and the iOS Simulator build succeeded. The prior
  complete backend suite baseline remains 63 tests; local API-contract tests
  currently depend on the configured PostgreSQL seed credentials.

## 17. Key Files

Documentation:

- `docs/product-spec.md`
- `docs/domain-model.md`
- `docs/architecture.md`
- `docs/ui-spec.md`
- `docs/ipad-navigation-map.md`
- `docs/database-schema.md`
- `docs/legacy-data-import.md`
- `docs/data-dictionary.md`
- `docs/sql-query-cookbook.sql`
- `docs/OldVersionApp/README.md`

Backend:

- `backend/src/app/main.py`
- `backend/src/app/config.py`
- `backend/src/app/database.py`
- `backend/src/app/models.py`
- `backend/src/legacy_import/`
- `backend/src/modules/asset_management/`
- `backend/src/modules/maintenance_execution/`
- `backend/src/modules/organizational_context/`
- `backend/migrations/versions/`

Frontend:

- `frontend/ios/MaintenanceAppMock.xcodeproj`
- `frontend/ios/MaintenanceAppMock/MockData/MockMaintenanceStore.swift`
- `frontend/ios/MaintenanceAppMock/Networking/APIClient.swift`
- `frontend/ios/MaintenanceAppMock/Networking/AuthService.swift`
- `frontend/ios/MaintenanceAppMock/Networking/AppStateService.swift`
- `frontend/ios/MaintenanceAppMock/Views/`

## 18. Rules For The Next Assistant

- Read this file, `docs/legacy-data-import.md`, and `docs/database-schema.md` first.
- Do not revert the dirty worktree or user changes.
- Confirm the actual Git status before editing.
- Keep documentation, code, and code comments in English.
- Keep user-visible and imported business values in Spanish.
- Use `Boss` in English documentation and `Jefe` in Spanish UI data.
- Treat large equipment as `assets.is_business_anchor = true`.
- Stage is rollout/planning metadata, not a maintenance engineer visibility restriction.
- Keep physical location separate from the asset/component tree.
- Do not implement consumables yet.
- Do not use `app.seed` as production migration data.
- Do not bypass `--strict` after an import validation failure.
- Do not connect the iOS app directly to PostgreSQL.
- Preserve imported source traceability and report version history.
