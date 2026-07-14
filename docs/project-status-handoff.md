# Project Status Handoff

Last updated: 2026-07-13  
Project root: `/Users/diego/Documents/Projects/MaintenanceAppPlan`

This document is a handoff for another AI/coding assistant. It summarizes the current state of the MaintenanceApp project, what has already been built, how to run it, and what remains to be done. Use this together with the rest of the `docs/` folder; do not treat this file as a replacement for the product/domain documentation.

## First Rules For The Next Assistant

- Do not revert or discard existing changes. The worktree is intentionally dirty and contains the current project state.
- Read the docs before changing behavior. Start with this file, then read:
  - `docs/product-spec.md`
  - `docs/domain-model.md`
  - `docs/architecture.md`
  - `docs/ui-spec.md`
  - `docs/mock-data.md`
  - `docs/ipad-navigation-map.md`
  - `docs/sql-domain-notes.md`
  - `docs/requirements.md`
- The iPad SwiftUI mock is now the visual/flow reference for V1, but the app is already partially connected to FastAPI/PostgreSQL.
- The role formerly called `Tecnico mantenedor` / `Técnico mantenedor` has been renamed in active code and documentation to `Ingeniero de Mantenimiento`.
- Business language matters. The tab visible to users is `Equipos`, while the technical/domain concept may still use `assets`.
- "Equipo grande" means the business-anchor asset/equipment. It must remain easy to distinguish from lower-level assets/components such as cards, racks, cabling, modules, etc.

## Current High-Level State

The project began as planning plus an iPad SwiftUI mock. It has now moved into an early V1 transition:

- Frontend: SwiftUI iPad app/mock in `frontend/ios/MaintenanceAppMock`.
- Backend: FastAPI app in `backend/src`.
- Database: PostgreSQL through Docker Compose.
- Migrations: Alembic in `backend/migrations`.
- Seed data: the former Swift static mock data has been moved into backend seed generation and PostgreSQL.
- Current app data flow: Swift loads a complete app-state snapshot from the backend with `GET /api/v1/app-state/current`, and can save it back with `PUT /api/v1/app-state/current`.

Important architecture note: the current backend includes both domain-oriented endpoints and a transitional `app-state` snapshot endpoint. The snapshot endpoint is useful to keep the full Swift mock flowing from PostgreSQL quickly, but it should gradually be replaced by proper domain APIs for production V1.

## Repository Areas

### Documentation

Important docs:

- `docs/product-spec.md`: product scope and behavior.
- `docs/domain-model.md`: domain model notes.
- `docs/architecture.md`: architecture direction.
- `docs/ui-spec.md`: UI/design rules.
- `docs/mock-data.md`: mock data and business data notes.
- `docs/ipad-navigation-map.md`: iPad navigation and screen behavior.
- `docs/sql-domain-notes.md`: database/domain mapping notes.
- `docs/task-graph.md`: task planning.
- `docs/Cronograma_V1_MaintenanceApp.xlsx`: planning spreadsheet.

`docs/raw-context.md` contains raw source context and may still include older wording such as `Técnico básico`. Do not blindly edit it unless the user asks; it is closer to source material than active product language.

### iOS Frontend

Main paths:

- Xcode project: `frontend/ios/MaintenanceAppMock.xcodeproj`
- App entry: `frontend/ios/MaintenanceAppMock/MaintenanceAppMockApp.swift`
- Models: `frontend/ios/MaintenanceAppMock/Models/MockModels.swift`
- Store: `frontend/ios/MaintenanceAppMock/MockData/MockMaintenanceStore.swift`
- Networking:
  - `frontend/ios/MaintenanceAppMock/Networking/APIClient.swift`
  - `frontend/ios/MaintenanceAppMock/Networking/AuthService.swift`
  - `frontend/ios/MaintenanceAppMock/Networking/AppStateService.swift`
- Login: `frontend/ios/MaintenanceAppMock/Views/Auth/LoginView.swift`
- Main tabs: `frontend/ios/MaintenanceAppMock/Views/MainTabView.swift`
- Home: `frontend/ios/MaintenanceAppMock/Views/HomeView.swift`
- Preventive:
  - `Views/Preventive/PreventiveListView.swift`
  - `Views/Preventive/PreventiveDetailView.swift`
  - `Views/Preventive/PreventiveReportFormView.swift`
  - `Views/Preventive/PDFPreviewView.swift`
- Corrective:
  - `Views/Corrective/CorrectiveListView.swift`
  - `Views/Corrective/CorrectiveDetailView.swift`
  - `Views/Corrective/CorrectiveReportFormView.swift`
  - `Views/Corrective/CorrectivePDFPreviewView.swift`
- Equipment/assets:
  - `Views/Assets/AssetSearchView.swift`
- Stock:
  - `Views/Stock/StockListView.swift`
- Design system:
  - `DesignSystem/DesignTokens.swift`
- Current ATS cabinet image:
  - `Resources/ats-cabinet-reference.png`

Current frontend behavior:

- Login screen is the initial screen.
- Login uses backend API:
  - `POST /api/v1/auth/login`
  - password is temporarily `123456` for all seeded users.
- The app loads full remote state from:
  - `GET /api/v1/app-state/current`
- The app saves modified state through:
  - `PUT /api/v1/app-state/current`
- The visible tab name is `Equipos`, not `Activos`.
- Day mode background should be pure white; night mode background should be pure black while keeping subtle background line effects.
- Navigation uses the newer adaptive SwiftUI tab behavior after reverting custom bottom navigation experiments.
- The UI has gone through several mock/design iterations:
  - improved dashboard indicator cards,
  - pending activity cards,
  - preventive/corrective detail layouts,
  - report forms,
  - signatures,
  - comments,
  - historical reports,
  - filters,
  - corrective creation flow,
  - equipment detail/history.

Known frontend caveat:

- The store is still named `MockMaintenanceStore` and many model names still include `Mock` because this codebase evolved from a mock. Do not interpret that as meaning all data is still static. The main app lists are now loaded from backend state.
- Some fallback UI strings/defaults exist for newly created objects, empty states, labels, and local formatting. Those are not the same as static seed data.
- Current persistence is coarse-grained: many store mutations call `persistRemoteState()`, which writes the whole snapshot. This is acceptable for the transition but not ideal for production.

### Backend

Main paths:

- FastAPI app: `backend/src/app/main.py`
- Settings: `backend/src/app/config.py`
- Database/session setup: `backend/src/app/database.py`
- SQLAlchemy model registry: `backend/src/app/models.py`
- Seed entrypoint: `backend/src/app/seed.py`
- Full app-state seed payload: `backend/src/app/app_state_seed.py`
- Modules:
  - `backend/src/modules/identity_access`
  - `backend/src/modules/asset_management`
  - `backend/src/modules/maintenance_execution`
  - `backend/src/modules/app_state`
  - `backend/src/shared_kernel`

Implemented API endpoints:

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

Backend modes:

- `REPOSITORY_BACKEND=seed`: in-memory/seed repositories used by tests.
- `REPOSITORY_BACKEND=postgres`: PostgreSQL repositories and app-state snapshot.

Current important backend design:

- `app_state_snapshots` stores a JSONB payload with the full UI state used by Swift.
- `app_state_seed.py` builds the state that used to live in Swift.
- `seed.py` populates:
  - `users`
  - `assets`
  - `asset_history`
  - `preventive_schedules`
  - `corrective_events`
  - `app_state_snapshots`
- `TECHNICIAN` users are displayed as `Ingeniero de Mantenimiento`.

Known backend caveat:

- The domain tables are not yet complete enough to replace the snapshot endpoint for all screens. For production V1, migrate from `app-state` snapshot writes to domain-specific endpoints and normalized tables.

### Database / Docker

Main files:

- `docker-compose.yml`
- `.env.example`
- `backend/.env.example`
- `backend/alembic.ini`
- `backend/migrations/versions/20260705_0001_initial_schema.py`
- `backend/migrations/versions/20260706_0002_app_state_snapshot.py`

Current migrations:

- `20260705_0001_initial_schema`
  - `assets`
  - `asset_history`
  - `corrective_events`
  - `preventive_schedules`
  - `users`
- `20260706_0002_app_state_snapshot`
  - `app_state_snapshots`

Important environment note:

- Docker Compose reads the root `.env`.
- The backend settings read both `backend/.env` and root `.env`.
- PostgreSQL only applies `POSTGRES_DB`, `POSTGRES_USER`, and `POSTGRES_PASSWORD` the first time the Docker volume is initialized.
- If credentials are changed after the volume already exists, either update the PostgreSQL user/password manually or recreate the local volume with `docker compose down -v`.

At the last verification, the user had local PostgreSQL created with:

- database: `maintenance_db`
- user: `root_mantto`

Do not assume the default `maintenance_user` exists in the current Docker volume.

## Python Environment

The repo-local virtual environment is named:

```bash
app_mant
```

Earlier setup used Python 3.12.13 from the Codex bundled runtime. The backend depends on Python 3.12-compatible packages.

Do not create a second venv unless the user asks. Use:

```bash
./app_mant/bin/python
```

or commands already wrapped by the root `Makefile`.

## Local Run Commands

From project root:

```bash
make db-up
make db-migrate
make db-seed
make backend-dev-postgres
```

Open:

- `http://127.0.0.1:8000/health`
- `http://127.0.0.1:8000/health/db`
- `http://127.0.0.1:8000/docs`

For iOS simulator, use this API URL in the login screen:

```text
http://127.0.0.1:8000
```

For physical iPad, use the Mac LAN IP:

```text
http://<mac-ip>:8000
```

Example:

```text
http://192.168.1.20:8000
```

## Test / Validation Commands

Backend tests:

```bash
make backend-test
```

Backend lint:

```bash
make backend-lint
```

Compile Python:

```bash
cd backend
../app_mant/bin/python -m compileall -q src tests migrations
```

iOS build:

```bash
xcodebuild \
  -project frontend/ios/MaintenanceAppMock.xcodeproj \
  -scheme MaintenanceAppMock \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /Users/diego/Documents/Projects/MaintenanceAppPlan/tmp/DerivedData \
  build
```

Useful API checks once backend is running:

```bash
curl -s http://127.0.0.1:8000/health
curl -s http://127.0.0.1:8000/health/db
curl -s http://127.0.0.1:8000/api/v1/app-state/current
curl -s http://127.0.0.1:8000/api/v1/assets
curl -s http://127.0.0.1:8000/api/v1/schedules
curl -s http://127.0.0.1:8000/api/v1/corrective-events
```

Login check:

```bash
curl -s -X POST http://127.0.0.1:8000/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"diego@maintenance.local","password":"123456"}'
```

Expected user role label:

```text
Ingeniero de Mantenimiento
```

## Seeded Test Users

All seeded users currently use password:

```text
123456
```

Users:

- `diego@maintenance.local` - `Ingeniero de Mantenimiento`
- `joab@maintenance.local` - `Ingeniero de Mantenimiento`
- `fredy@maintenance.local` - `Coordinador`
- `jefe@maintenance.local` - `Jefe`
- `admin@maintenance.local` - `Administrador`

## Last Known Verification

Last full verification was run before this handoff and included:

- `make db-migrate`: OK
- `make db-seed`: OK
- PostgreSQL direct checks: OK
- `POST /api/v1/auth/login`: OK
- `GET /api/v1/app-state/current`: OK
- `PUT /api/v1/app-state/current`: OK
- `GET /api/v1/assets`: OK
- `GET /api/v1/schedules`: OK
- `GET /api/v1/corrective-events`: OK
- `make backend-test`: 6 tests passed
- `make backend-lint`: OK
- iOS build through `xcodebuild`: `BUILD SUCCEEDED`

Data counts from the last PostgreSQL/app-state verification:

- users: 5
- assets/equipment: 173
- preventive schedules/activities: 5
- corrective events: 3
- stock assets: 6
- historical reports: 8
- preventive signature sets: 1
- corrective signature sets: 1

## Major Product / UI Decisions Already Made

- The visible user-facing tab is `Equipos`.
- The technical concept `asset` remains valid internally, but business-anchor assets are "equipos grandes".
- "Equipos grandes" must be differentiable from child assets/components.
- Main navigation was restored to the original iPadOS adaptive `TabView` style after failed bottom-nav/liquid-glass experiments.
- Dark mode:
  - pure black base background,
  - subtle red line effects may remain.
- Day mode:
  - pure white base background.
- Profile screen controls theme mode.
- Preventive comments:
  - reusable across future executions by preventive type and/or equipo grande.
- Corrective comments:
  - scoped only to the specific corrective event.
- Preventive detail:
  - includes previous reports/historical reports.
  - historical report tap opens PDF preview-like screen.
- Corrective creation:
  - has `+` flow.
  - includes subsystem selection before equipment selection.
  - filters large equipment by subsystem.
  - has search for equipment.
  - asset tree should not show physical location as selectable asset.
- Corrective report:
  - includes event data, physical location, failure description/impact, failure analysis, performed activities, component replacement, tests/validation, conclusions/comments, participants/signatures, PDF preview.
- Preventive and corrective reports can be signed by each participant.
- Completed maintenance can be reopened:
  - from `Completado` to `En progreso` by Ingeniero de Mantenimiento, Coordinador, or Administrador.
  - from `Cerrado` to `En progreso` only by Coordinador or Administrador.
  - `Jefe` is read-only for these actions.
- Preventive/corrective report edit/create buttons should generally be available only when the maintenance is `En progreso`.

## Important Data Corrections Already Applied

- `CRK 1 - 2` and `ERK 1 - 2` were corrected conceptually into separate equipos grandes:
  - `CRK 1`
  - `CRK 2`
  - `ERK 1`
  - `ERK 2`
- Equipment history should show only maintenance performed on the same equipo grande.
- `Etapa 1A` is project stage, not physical location.
- Physical location means station/yard/room/cabinet location, e.g. `Patio Santa Anita -> Sala tecnica -> Sala 2.21`.
- The asset tree must not include physical location as a selectable asset node.

## What Is Complete Enough For Now

- iPad SwiftUI mock screens are ready as the visual/flow baseline.
- Login screen exists and blocks access until successful login.
- Backend skeleton exists and runs locally.
- PostgreSQL Docker setup exists.
- Alembic migrations exist.
- Seed data exists in backend/PostgreSQL.
- Swift no longer depends on the old static factories for core app data.
- Role rename is reflected in active app/backend/docs.
- App can read and write the transitional app state snapshot through backend APIs.

## What Is Not Yet Production-Ready

The project is not yet a fully normalized production backend. The next assistant should not overstate current completion.

Main gaps:

- Replace the `app-state` JSON snapshot persistence with domain-specific endpoints.
- Normalize report data into relational tables:
  - preventive report header,
  - preventive steps,
  - preventive tests/results,
  - corrective report header,
  - corrective activities,
  - component replacements,
  - validation results,
  - signatures,
  - comments,
  - PDF/report versions.
- Add authenticated sessions/JWT validation beyond the current mock token behavior.
- Replace temporary universal password `123456` with real password hashing/auth policy.
- Add authorization enforcement per role in backend, not only UI/store logic.
- Add backend APIs for:
  - starting/completing/closing/reopening preventive activities,
  - starting/completing/closing/reopening corrective events,
  - creating/updating preventive reports,
  - creating/updating corrective reports,
  - comments,
  - signatures,
  - stock selection,
  - PDF/share generation,
  - user profile/photo settings,
  - theme preference.
- Decide PDF generation strategy:
  - current app has share-sheet style mock text/preview behavior,
  - production should likely generate canonical PDFs server-side or with a clearly versioned template.
- Add integration tests against PostgreSQL, not only seed-backed tests.
- Add iOS UI tests or at least API integration smoke tests.
- Review deployment design for on-premise:
  - Docker Compose or orchestration,
  - PostgreSQL backup/restore,
  - logs,
  - secrets,
  - TLS,
  - service restart policy,
  - future web apps/services sharing infrastructure.

## Recommended Next Implementation Path

1. Stabilize the current backend/iOS bridge.
   - Keep `app-state` only as compatibility during migration.
   - Add tests that verify `GET /api/v1/app-state/current` returns fields Swift requires.

2. Build real domain APIs for read flows.
   - Assets/equipment with tree/detail/history.
   - Preventive schedules/detail.
   - Corrective events/detail.
   - Stock list/filter.

3. Build real domain APIs for workflow actions.
   - Start/complete/close/reopen.
   - Create corrective.
   - Save preventive report.
   - Save corrective report.
   - Save comments.
   - Save signatures.

4. Move Swift screens one by one from snapshot state to domain services.
   - Keep the UI/layout intact.
   - Replace only the data source and mutation calls.

5. Normalize database tables after each domain slice.
   - Use Alembic migrations.
   - Keep seed data realistic and aligned with docs.

6. Add role-based backend authorization.
   - `Ingeniero de Mantenimiento`
   - `Coordinador`
   - `Jefe`
   - `Administrador`

7. Implement PDF generation/sharing.
   - Choose server-side canonical PDF generation unless there is a strong reason to generate on-device.

## Known Worktree State

The repository currently has many modified and untracked files. This is expected because the project has been evolving quickly through mock and V1 setup work.

Before making risky changes, run:

```bash
git status --short
```

Do not use destructive commands such as:

```bash
git reset --hard
git checkout -- .
git clean -fd
```

unless the user explicitly asks and understands the consequences.

## Useful Search Commands

Find old role wording:

```bash
rg -n "Tecnico mantenedor|Técnico mantenedor|Tecnico:|Técnico:" frontend/ios/MaintenanceAppMock backend docs README.md
```

Find old Swift static factories:

```bash
rg -n "makeActivities|makeAssets|makeStockAssets|makeHistoricalReports|makeCorrectiveEvents" frontend/ios/MaintenanceAppMock
```

Find API usage in Swift:

```bash
rg -n "AuthService|AppStateService|APIClient|fetchCurrentState|replaceCurrentState" frontend/ios/MaintenanceAppMock
```

Find backend routes:

```bash
find backend/src/modules -path '*router.py' -print
```

## Final Guidance For Another Model

The most important thing is not to rebuild from scratch. The iPad UI/UX work is valuable and should be preserved. Continue by extracting the current snapshot-backed behavior into real domain-backed APIs and persistence, screen by screen.

When in doubt:

1. Read the relevant `docs/` file.
2. Check the current Swift screen behavior.
3. Check `app_state_seed.py` for the current mock data shape.
4. Add/adjust backend DTOs and migrations.
5. Move only the narrow slice from snapshot to a real endpoint.
6. Run backend tests/lint and iOS build.

