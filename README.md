# Maintenance App

Maintenance App is a local-first maintenance management system designed primarily for iPad. It
combines preventive and corrective maintenance execution, PCON planning, equipment and stock
administration, report generation, evidence capture, tools, organizational administration, and
role-based access in one application.

The repository contains the SwiftUI client, the FastAPI API, the normalized PostgreSQL schema,
the legacy Excel importer, PDF templates, automated tests, and the product and engineering
documentation.

## Current Status

The project is an integrated DEV/QA application rather than the original visual mock. The iOS app
uses authenticated, versioned APIs backed by PostgreSQL for its main operational flows.

Implemented end-to-end capabilities include:

- Authenticated sessions with access/refresh token rotation and Keychain storage.
- Role and module permissions (`NONE`, `READ`, and `WRITE`).
- Preventive and corrective maintenance lists, details, lifecycle actions, comments, and reports.
- Preventive, corrective, and track-circuit calibration report versions.
- Evidence capture from camera or photo library, editable evidence titles, and protected local
  draft storage.
- Preventive, corrective, and calibration PDF generation and preview.
- Combined preventive + calibration document packages for CBDAC maintenance, including a single
  email flow with both PDFs attached.
- Equipment, component hierarchy, images, maintenance history, and administrator CRUD.
- Stock list, detail, status legend, images, creation, and administrator editing.
- Native ATS line viewer with searchable infrastructure objects, operational layers, scope/track
  filters, object inspection, calibration routes, and network-distance measurement.
- PCON annual, monthly, and weekly planning.
- Tool catalog, tool inventory, assignments/movements, images, and preventive checklist templates.
- User, permission, work-area, site, project, stage, system, and subsystem administration.
- Team scheduling APIs and UI implementation. The `Horario` tab is currently disabled in
  `MainTabView` while the product decision about retaining that module is pending.
- Legacy Excel validation/import into the normalized PostgreSQL model.

User-visible labels, statuses, seed data, and report content are in Spanish. Technical identifiers,
code, and engineering documentation are in English.

## Application Modules

### Inicio

- Operational dashboard backed by `GET /api/v1/maintenance-dashboard`.
- Current preventive and corrective indicators.
- Refresh after maintenance lifecycle or offline draft reconciliation.

### Preventivos

- Search and server-side date/status/subsystem filters.
- Maintenance detail with lifecycle timeline: Programado, En progreso, Completado, Cerrado.
- Segmented detail navigation for general data, checklist, steps, comments, versions, and previous
  reports.
- Preventive report form with general data, manual/operational checklist, maintenance steps,
  evidence, participants, signatures, and conclusions.
- Immutable finalized versions and later correction through a new draft version.
- Calibration report support for track-circuit/CBDAC maintenance.
- PDF generation, PDFKit preview, document selection when more than one report exists, and email
  composition through the native iOS mail interface.

### Correctivos

- Corrective event list, detail, creation flow, and normalized report editor.
- Equipment/asset selection, event data, severity, SAP data, tools, and confirmation.
- Segmented report flows for event data, failure description, failure analysis, performed
  activities, tests/validation, conclusions/comments, event comments, and report versions.
- Component replacement against equipment hierarchy and stock. The inventory change is committed
  atomically only when the report version is finalized.
- Corrective PDF generation and preview.

### PCON

- Annual maintenance plan with scope counts and year-to-year copy support.
- Monthly calendar with month-only, tentative, confirmed, completed, and conflict color states.
- Assignment of month-only activities to a specific day, with activity search and subsystem,
  category, and location filters.
- Day confirmation and tentative-date management.
- Weekly planning with 24-hour scheduling, filters, indicators, conflict handling, pending monthly
  activities, and pagination.
- Planning sessions and change history.

### Equipos

- Responsive list for iPad portrait and landscape.
- Search plus category, subsystem, and status filters.
- Equipment detail, images, component/slot tree, and maintenance history.
- Administrator-only create, edit, archive/delete, and image management.
- Master-data dropdowns for subsystem, category, type, status, and cascading geographic levels.

### Stock

- Responsive inventory list, filters, pagination, images, and status legend.
- Detail screen aligned with the Equipment UX.
- Administrator-only stock item creation and editing.
- Controlled category, subsystem, status, and inventory-location catalogs.
- `En Stock` is represented with the positive/green status style.

### Linea

- Single native SwiftUI workspace based on the operational data previously explored in LineV2.
- Interactive `Canvas` map with pan, zoom, fit-to-line, track scope, and selectable layers.
- Search and catalog for segments, signals, tags, switches, platforms, stops, and calibration links.
- Inspector with normalized context plus the original source fields for technical traceability.
- Point-to-point network distance calculation using segment connectivity.
- Read access controlled through the `ATS_LINE` module permission; administrators receive write
  permission for future extensions.
- Portable SQLite source bundled with this backend and exposed only through authenticated APIs;
  the tablet app has no runtime dependency on the LineV2 project.

### Herramientas

- Tool catalog and inventory administration.
- Identified inventory items, classifications, storage locations, people, movements, and images.
- Preventive template and checklist administration.

### Administracion

This tab is visible only to administrators.

- Create, edit, activate, or deactivate users.
- Assign role, job title, `work_area_id`, supervised areas, and schedule visibility.
- Configure module permission level by role.
- Manage work areas, sites, projects, stages, systems, and subsystems and their relationships.
- Access operational configuration such as preventive templates.

### Perfil

- Current authenticated user and role information.
- Password change.
- Logout with refresh-session revocation and local Keychain cleanup.
- Non-production role preview for administrators.

## Roles And Permissions

Supported roles:

- `MAINTENANCE_ENGINEER` - Ingeniero de Mantenimiento.
- `COORDINATOR` - Coordinador.
- `BOSS` - Jefe.
- `ADMINISTRATOR` - Administrador.

Module visibility and editing are resolved from database permissions. Each module can be assigned
`NONE`, `READ`, or `WRITE` per role. Administrators retain full access and exclusive access to the
administration tab. Operational lifecycle endpoints also validate the maintenance state and role;
UI visibility is not treated as the security boundary.

## Architecture

```text
SwiftUI iOS/iPadOS app
        |
        | HTTPS / JSON + Bearer access token
        v
FastAPI /api/v1
        |
        | async SQLAlchemy repositories
        v
PostgreSQL 16

Binary evidence -----------------> filesystem attachment storage
Generated PDFs ------------------> filesystem report storage
ATS line source -----------------> bundled read-only portable SQLite
Offline report drafts -----------> iOS Application Support + file protection
Session tokens ------------------> iOS Keychain
```

The backend is organized by domain module:

- `identity_access`: login, refresh, logout, password changes, role preview, and permissions.
- `administration`: people and organizational master-data administration.
- `asset_management`: equipment, components, stock, images, and history.
- `maintenance_execution`: preventive/corrective execution, reports, PDF packages, PCON, tools,
  and checklist templates.
- `workforce_scheduling`: work areas, weekly shifts, bulk edits, and week copy.
- `ats_line`: authenticated graph, source-object inspection, and network-distance endpoints backed
  by a project-owned portable dataset.
- `organizational_context`: normalized organizational and operational entities.
- `app_state`: transitional compatibility state retained for remaining legacy paths.

Alembic is the only authoritative mechanism for schema creation and upgrades. Swift never connects
directly to PostgreSQL.

## Technology Stack

### iOS client

- Swift 5 and SwiftUI.
- Xcode project with the shared `MaintenanceApp` scheme.
- iOS/iPadOS deployment target 26.0; iPad is the primary form factor.
- Foundation and `URLSession` for API access.
- Security framework for Keychain token storage.
- Network framework (`NWPathMonitor`) for connectivity and offline retry.
- PhotosUI, Photos, UIKit, and the system camera/photo picker for evidence and asset images.
- PDFKit for native PDF preview.
- MessageUI for email composition and PDF attachments.
- CoreGraphics for signature/evidence data handling.
- SwiftUI `Canvas` and native gestures for the ATS line graph; no embedded web view is used.
- No external iOS package dependency is currently required.

### Backend and data

- Python 3.12.
- FastAPI and Uvicorn.
- Pydantic and pydantic-settings.
- SQLAlchemy 2 async with asyncpg.
- PostgreSQL 16.
- Alembic migrations.
- Argon2 password hashing and PyJWT authentication.
- Jinja2 + WeasyPrint for preventive, corrective, and calibration PDFs.
- OpenPyXL for legacy Excel import.
- Filesystem-backed evidence and generated-report storage with portable relative keys.

### Development and quality

- Docker and Docker Compose for isolated LOCAL, DEV, and QA stacks.
- Make for common environment, database, migration, health, and test commands.
- Pytest and HTTPX for unit, integration, and API contract tests.
- Ruff for Python linting.
- Git for source control.
- Xcode Simulator and physical iPad deployment for UI validation.

## Repository Structure

```text
MaintenanceAppPlan/
  ai/                         AI collaboration and workflow notes
  backend/
    assets/                   PDF assets such as the report logo
    migrations/               Alembic schema history
    src/app/                  FastAPI bootstrap and configuration
    src/modules/              Domain modules and API routers
    src/legacy_import/        Excel-to-PostgreSQL importer
    tests/                    Unit, integration, and end-to-end tests
    Dockerfile
    docker-compose.yml
    Makefile
    pyproject.toml
  docs/                       Product, UX, architecture, schema, and QA documentation
  frontend/
    ios/
      MaintenanceAppMock/     SwiftUI application source
      MaintenanceAppMock.xcodeproj/
  scripts/                    Local validation and helper scripts
```

## Local Environments

The backend supports `local`, `dev`, and `qa`. Private configuration lives outside Git at:

```text
backend/environments/<environment>/.env
```

Use the versioned `.env.example` beside each private file as the starting point. Each environment
has its own backend port, PostgreSQL port/volume, and storage directory.

Required authentication settings include:

```env
JWT_SECRET_KEY=replace-with-at-least-32-random-characters
JWT_ISSUER=maintenance-app
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=7
```

Generate a local signing key with:

```bash
openssl rand -hex 32
```

## Run The Backend With Docker

```bash
cd backend
make ENV=local build
make ENV=local migrate
make ENV=local current
make ENV=local health
```

Daily startup normally requires only:

```bash
cd backend
make ENV=local up
```

Useful commands:

```bash
make ENV=local status
make ENV=local logs
make ENV=local down
```

`make down` preserves the PostgreSQL volume. Do not use `docker compose down -v` unless the local
database is intentionally disposable.

API documentation is available while the backend is running:

- `http://127.0.0.1:8000/docs`
- `http://127.0.0.1:8000/health`
- `http://127.0.0.1:8000/health/db`

## Run The Backend Without The API Container

This mode is useful while editing Python code:

```bash
cd backend
python3.12 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -e ".[dev]"
make ENV=local db-up
make ENV=local db-migrate
make ENV=local dev-postgres
```

The Docker image already contains the Cairo/Pango libraries required by WeasyPrint. A native macOS
backend uses the Homebrew paths assembled by `make dev-postgres`.

## Run The iOS App

1. Start the selected backend environment and apply migrations.
2. Open `frontend/ios/MaintenanceAppMock.xcodeproj` in Xcode.
3. Select the shared `MaintenanceApp` scheme.
4. Select an iPad simulator or a signed physical iPad destination. Do not select `My Mac`.
5. Confirm the API URL and environment label in
   `frontend/ios/MaintenanceAppMock/Config/Environment.xcconfig`.
6. Build and run with code signing enabled.

Code signing must remain enabled for login builds. A build produced with
`CODE_SIGNING_ALLOWED=NO` lacks the application identifier needed by Keychain and can return
`errSecMissingEntitlement` (`-34018`) after otherwise valid credentials are accepted.

After an Xcode upgrade, an unreadable `*.priors` warning normally indicates stale DerivedData,
not a project source error. Remove the app's DerivedData, select a valid iOS destination, and run a
clean build.

## Offline Drafts And File Storage

- Preventive and corrective drafts can be saved locally after one successful online sign-in.
- Draft payloads, signatures, and evidence are written atomically under iOS Application Support
  with file protection.
- Synchronization retries when connectivity returns, when the app becomes active, and during
  periodic reconciliation.
- A server-version conflict moves the draft to a needs-attention state instead of overwriting a
  newer report.
- Report finalization remains online because it can commit lifecycle and inventory changes.
- Captured evidence can also be saved to the iPad Photos library when photo access is granted.
- PostgreSQL stores attachment metadata and relative storage keys; binary files remain outside the
  database under the configured attachment/report storage roots.

## Authentication And Security

- Passwords are stored with Argon2.
- Access tokens expire after 15 minutes by default.
- Refresh tokens expire after 7 days, rotate on use, and can be revoked through tracked refresh
  sessions.
- Logout revokes the refresh session and removes local Keychain data.
- Password changes revoke active refresh sessions.
- Imported `mock:<password>` hashes are upgraded to Argon2 after a successful login.
- Administrator role preview is available only outside production.

Administrative user recovery commands:

```bash
cd backend
make ENV=local user-set-password EMAIL=usuario@hitachirail.com
make ENV=local user-bootstrap-disabled
```

## Legacy Excel Import

The importer under `backend/src/legacy_import/` validates and imports the original WBS and storage
workbooks using deterministic identifiers, source-row hashes, PostgreSQL upserts, and auditable
batch/row results.

```bash
cd backend
python -m legacy_import validate
python -m legacy_import import-wbs
python -m legacy_import import-storage
python -m legacy_import import-all
```

Use `--dry-run` to execute transformations and constraints and then roll back. Use `--strict` to
roll back the complete batch if any source row fails. Company Excel source files are intentionally
excluded from Git.

## Validation

Backend tests and lint:

```bash
cd backend
make test
make lint
```

Build the iOS application from the repository root:

```bash
xcodebuild \
  -project frontend/ios/MaintenanceAppMock.xcodeproj \
  -scheme MaintenanceApp \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  build
```

For login and Keychain validation, run the normally signed build from Xcode. A command-line build
with signing disabled is suitable only for compilation verification.

## Further Documentation

- [`docs/architecture.md`](docs/architecture.md) - system architecture.
- [`docs/database-schema.md`](docs/database-schema.md) - normalized database design.
- [`docs/data-dictionary.md`](docs/data-dictionary.md) - domain and field definitions.
- [`docs/environment-setup.md`](docs/environment-setup.md) - LOCAL/DEV/QA setup.
- [`docs/legacy-data-import.md`](docs/legacy-data-import.md) - importer operation.
- [`docs/offline-workflow.md`](docs/offline-workflow.md) - local draft and synchronization flow.
- [`docs/product-spec.md`](docs/product-spec.md) - product scope.
- [`docs/ui-spec.md`](docs/ui-spec.md) - UI/UX conventions.
- [`backend/README.md`](backend/README.md) - backend-specific details.
- [`frontend/ios/README.md`](frontend/ios/README.md) - iOS-specific details.

## Production Readiness Note

The application is currently prepared for DEV/QA use on a Mac-hosted environment and direct Xcode
installation on a test iPad. A production deployment still requires a confirmed hosting model,
production secrets and TLS, backup/restore procedures, monitoring, email delivery policy, final
device distribution/signing, and production acceptance testing.
