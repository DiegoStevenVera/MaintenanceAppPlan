# Project Status Handoff

**Last updated:** 2026-07-26
**Target continuation environment:** Company Mac
**Migration head:** `20260724_0005`
**Legacy import status:** Implemented and dry-run validated; no legacy rows committed yet

This is the operational handoff for continuing MaintenanceApp on the company Mac. It records the
current technical state, the exact database/bootstrap/import procedure, and the remaining backend
and frontend work. Project documentation and code use English. User-visible strings and imported
business data use Spanish.

## 1. Read This First

The project has three different persistence layers at the moment:

1. The normalized PostgreSQL domain schema is implemented.
2. The Excel-to-PostgreSQL importer is implemented and validated.
3. The iOS app still loads and saves a transitional `app_state_snapshots` JSON document.

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

Alembic creates 72 application tables plus `alembic_version`.

Current migrations:

- `20260705_0001_initial_schema`
- `20260706_0002_app_state_snapshot`
- `20260724_0003_foundational_catalogs`
- `20260724_0004_complete_operational_schema`
- `20260724_0005_expand_legacy_record_mappings`

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
- `GET /api/v1/auth/me`
- `GET /api/v1/app-state/current`
- `PUT /api/v1/app-state/current`
- `GET /api/v1/assets`
- `GET /api/v1/assets/{asset_id}`
- `GET /api/v1/assets/{asset_id}/history`
- `GET /api/v1/schedules`
- `GET /api/v1/corrective-events`
- `GET /api/v1/corrective-events/{event_id}`
- `POST /api/v1/corrective-events`

The asset, schedule, and corrective endpoints still expose transitional DTOs. Full report,
workflow, comments, signatures, stock, calibration, and planning APIs do not exist yet.

Authentication is development-only:

- Password verification compares `password_hash` with `mock:<password>`.
- Tokens are mock tokens, not production JWT validation.
- WBS-imported users have disabled legacy password values.
- Backend role authorization is not yet enforced consistently.

### iOS Frontend

Project:

```text
frontend/ios/MaintenanceAppMock.xcodeproj
```

The visual and interaction mock is substantially implemented for:

- Login and profile
- Dashboard
- Preventive lists, details, report form, comments, signatures, and preview
- Corrective lists, creation, details, dynamic report form, signatures, and preview
- Equipment search/detail/history
- Stock screens
- Boss metrics/read-only behavior

Current persistence is still coarse:

- Login calls the backend.
- Login then calls `GET /api/v1/app-state/current`.
- Most store mutations call `persistRemoteState()`.
- `persistRemoteState()` sends the entire app state to `PUT /api/v1/app-state/current`.
- The returned access token is not persisted or attached as a Bearer token by `APIClient`.

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

The root `Makefile` expects the virtual environment at `<project-root>/app_mant`.

From the project root:

```bash
python3.12 -m venv app_mant
source app_mant/bin/activate
python -m pip install --upgrade pip
python -m pip install -e "./backend[dev]"
```

Verify:

```bash
python -c "import fastapi, sqlalchemy, asyncpg, alembic, openpyxl"
python -m pytest backend/tests -q
```

Expected current test result:

```text
19 passed
```

A Starlette/httpx deprecation warning may still appear. It does not currently fail the suite.

## 7. Configure The Local Environment

From the project root:

```bash
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

The root `.env` is used by Docker Compose and is also read by the backend. Never commit it.

PostgreSQL applies its database/user/password environment values only when the Docker volume is
first initialized. Changing `.env` later does not change credentials inside an existing volume.

## 8. Create PostgreSQL And The Complete Schema

### Fresh Mac Database

Start PostgreSQL:

```bash
docker compose up -d postgres
docker compose ps
```

Wait for `maintenance_postgres` to become healthy:

```bash
docker compose logs postgres
```

Create the complete schema with Alembic:

```bash
cd backend
../app_mant/bin/alembic upgrade head
../app_mant/bin/alembic current
../app_mant/bin/alembic check
cd ..
```

Expected head:

```text
20260724_0005 (head)
```

Expected Alembic check:

```text
No new upgrade operations detected.
```

Verify directly:

```bash
docker compose exec postgres psql -U maintenance_user -d maintenance_app
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
docker compose down -v
docker compose up -d postgres
cd backend
../app_mant/bin/alembic upgrade head
cd ..
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

../app_mant/bin/python -m legacy_import validate \
  --kind wbs \
  --file ../docs/OldVersionApp/Database/WBS_V2.xlsx

../app_mant/bin/python -m legacy_import validate \
  --kind storage \
  --file ../docs/OldVersionApp/Database/BD_Storage.xlsx
```

Stop if either command fails. Exact duplicate source rows are counted and skipped; conflicting rows
with the same source key are rejected.

### Step 2: Mandatory Strict Dry Run

```bash
../app_mant/bin/python -m legacy_import import-all \
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
docker compose exec -T postgres pg_dump \
  -U maintenance_user \
  -d maintenance_app \
  -Fc > maintenance_before_import.dump
```

The dump file contains database data and must be protected appropriately.

### Step 4: Commit The Initial Import

Run the same command without `--dry-run`:

```bash
../app_mant/bin/python -m legacy_import import-all \
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
cd ..
docker compose exec postgres psql -U maintenance_user -d maintenance_app
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
../app_mant/bin/python -m legacy_import import-all \
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

../app_mant/bin/python -m legacy_import import-storage \
  --file ../docs/OldVersionApp/Database/BD_Storage.xlsx \
  --all \
  --dry-run \
  --strict

../app_mant/bin/python -m legacy_import import-storage \
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

From the project root:

```bash
make backend-dev-postgres
```

Equivalent direct command:

```bash
cd backend
REPOSITORY_BACKEND=postgres ../app_mant/bin/uvicorn \
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

Important: a clean imported database does not have a usable production authentication flow or an
`app_state_snapshots` compatibility payload. The current iOS login/bootstrap may therefore fail
even though the normalized migration succeeded. Do not solve this by treating `app.seed` as
production data.

If the old mock UI must be demonstrated temporarily, use `app.seed` only in a separate disposable
development database.

## 12. Required Backend Work

The schema is broad enough for V1. The main backend gap is now application behavior and API
coverage, not more bulk table creation.

### P0: Authentication And Authorization

- Replace mock password comparison with a supported password hash.
- Add a controlled user/password bootstrap or invitation process.
- Decide how imported WBS users become login-capable.
- Issue and validate real access/refresh tokens.
- Attach current-user identity to writes.
- Enforce roles in FastAPI:
  - `MAINTENANCE_ENGINEER`
  - `COORDINATOR`
  - `BOSS`
  - `ADMINISTRATOR`
- Keep `BOSS` read-only.
- Allow only Coordinator/Administrator to close maintenance.
- Enforce reopen rules for `COMPLETED` and `CLOSED`.

### P0: Normalized Read APIs

Implement DTOs, repositories, services, routers, pagination, and filtering for:

- Dashboard counts and Boss metrics
- Assets/equipment tree, slot hierarchy, components, stock, and maintenance history
- Preventive activities and schedule details
- Corrective activity/event details
- Logical reports and version history
- Preventive report steps and test results
- Corrective dynamic blocks and performed activities
- Participants, signatures, comments, attachments, and generated reports
- Calibration reports and transmitter/receiver measurements
- Tools and certifications

Suggested first vertical slice:

```text
GET /api/v1/maintenance-activities
GET /api/v1/maintenance-activities/{id}
GET /api/v1/maintenance-activities/{id}/reports
GET /api/v1/report-versions/{id}
```

This provides enough normalized data to replace preventive and corrective list/detail reads.

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

### P1: Report Editing And Versioning

Implement transactional endpoints for:

- Creating/updating a preventive draft
- Saving step and test results
- Creating/updating a corrective report
- Dynamic `Cambio de componente` blocks
- Component movements and paired replacements
- Participant selection and signatures
- Finalizing a version
- Reopening/editing after lifecycle authorization

Do not overwrite finalized report versions. Create a new `report_versions` row for corrections.

### P1: Comments And Attachments

- Preventive knowledge comments can be reusable by template and/or large equipment.
- Corrective comments belong to one corrective event.
- Store signature strokes or rendered signature files with explicit ownership.
- Add attachment upload/download metadata and file storage abstraction.
- Preserve basic draft retry when connectivity returns.

### P2: PDF And Share Sheet

- Generate canonical preventive and corrective PDFs.
- Include raw/simple PDFs first if necessary.
- Persist `generated_reports`.
- Expose a download endpoint.
- Let iOS present the returned file through Share Sheet.
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

- Persist the access and refresh tokens securely in Keychain.
- Add `Authorization: Bearer <token>` to authenticated requests.
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

- Real authentication, authorization, and user provisioning
- Fully database-backed lifecycle transitions
- Preventive report editing/versioning
- Corrective dynamic report editing/versioning
- Coordinator review, close, and reopen flows
- Participant signatures
- Preventive reusable comments and corrective event comments
- Attachment storage
- PDF generation and Share Sheet files
- Asset/component stock queries and replacement workflows
- Calibration report API
- Boss metrics and read-only drill-down
- Coordinator planning and worker schedules
- Administrator management
- Basic offline draft queue and retry
- Backup/restore, secrets, TLS, logs, and deployment design
- Consumables in a later version

## 15. Recommended Work Order Tomorrow

1. Confirm Windows changes were committed and pushed.
2. Pull/clone on the Mac.
3. Transfer the ignored Excel files securely.
4. Install prerequisites and create the root `app_mant` environment.
5. Run the 19 backend tests.
6. Create `.env` and start PostgreSQL.
7. Run Alembic through `20260724_0005`.
8. Validate both Excel workbooks.
9. Run the strict combined dry run.
10. Run the real combined import only after zero failures.
11. Run SQL audit queries and the idempotency dry run.
12. Start FastAPI and inspect `/docs`.
13. Begin P0 authentication/user bootstrap design.
14. Implement the normalized maintenance read vertical slice.
15. Connect the iOS list/detail screens to those endpoints.

Do not start by rewriting all Swift models or adding more schema tables. The shortest reliable path
is one complete backend-to-iPad vertical slice at a time.

## 16. Verification Baseline

Latest completed checks on Windows:

- Alembic current: `20260724_0005 (head)`
- Alembic check: no new upgrade operations
- Backend tests: 19 passed
- Importer-specific Ruff checks: passed
- Python compilation: passed
- Strict WBS dry run: 3,136 processed, 0 failed
- Strict storage dry run: 27,131 processed, 0 failed
- Combined import transaction: rolled back as requested
- Import audit tables after dry run: empty

The full repository Ruff command still reports existing issues outside the importer, mainly FastAPI
`Depends` rule findings and import ordering. Treat this as cleanup work, not as an importer failure.

## 17. Key Files

Documentation:

- `docs/product-spec.md`
- `docs/domain-model.md`
- `docs/architecture.md`
- `docs/ui-spec.md`
- `docs/ipad-navigation-map.md`
- `docs/database-schema.md`
- `docs/legacy-data-import.md`
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
- Stage is rollout/planning metadata, not a technician visibility restriction.
- Keep physical location separate from the asset/component tree.
- Do not implement consumables yet.
- Do not use `app.seed` as production migration data.
- Do not bypass `--strict` after an import validation failure.
- Do not connect the iOS app directly to PostgreSQL.
- Preserve imported source traceability and report version history.
