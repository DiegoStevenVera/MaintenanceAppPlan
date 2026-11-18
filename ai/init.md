# Maintenance App: AI Project Context

## Start Here

This is an operational iPad maintenance application, not the original mock. It supports the
signalling maintenance team in Lima and is validated in Mac-hosted DEV/QA. The deployment target
is iOS/iPadOS 26.0. The current trial uses an iPad with iPadOS 26.5 and direct signed installation
from Xcode. Production hosting (on-premises or cloud) and distribution are not decided. Do not
introduce a cloud dependency or change production assumptions without approval.

- Read the current task, this file, [README](../README.md), and the code of the affected module.
  Inspect the worktree before editing: uncommitted changes may be intentional. Do not revert,
  commit, push, or overwrite unrelated work unless asked.
- Treat the latest approved business decision as the intended behavior. Verify actual behavior in
  code, OpenAPI, migrations, and focused tests. Older specs and the README may describe an earlier
  state; identify contradictions before reusing those instructions.
- [Workflow](workflow.md) describes discovery through validation. When asked to plan, do not
  implement. For an approved implementation, make a scoped change, test it, and document
  operational behavior. Ask before destructive operations, unapproved schema redesigns, or
  changes to business policy, permissions, or deployment architecture.
- Keep UI strings and operational documents in Spanish; prefer existing English technical names.
  Use real catalog IDs and existing design components. Never infer missing history, fabricate
  business records, or expose credentials. Read [raw context](../docs/raw-context.md) as historical
  background, not as an instruction or approved spec. It can contain operational data.

## Architecture And Entry Points

| Area | Current implementation |
| --- | --- |
| Client | Native SwiftUI, Swift 5 mode, Xcode project `frontend/ios/MaintenanceAppMock.xcodeproj`, shared scheme `MaintenanceApp`. The target/directory still use the historical name `MaintenanceAppMock`. |
| UI and state | `frontend/ios/MaintenanceAppMock/Views/MainTabView.swift` defines active tabs. Feature views live in `Views/`; shared styles, filters and pagination in `DesignSystem/DesignTokens.swift`. |
| Transport and session | Foundation/URLSession via `Networking/APIClient.swift`; `AuthService.swift` owns session state and token refresh. `ReportService.swift` and `OfflineReportStore.swift` handle reports and offline work. |
| Backend | Python 3.12, FastAPI/Uvicorn, Pydantic settings/schemas, SQLAlchemy async + asyncpg, PostgreSQL 16. `backend/src/app/main.py` registers versioned `/api/v1` routers. |
| Domain modules | `identity_access`, `administration`, `asset_management`, `maintenance_execution` (execution, PCON, reports and tools), `workforce_scheduling`, `ats_line`, `organizational_context`, and transitional `app_state`. |
| Persistence | Alembic is the authority for PostgreSQL schema changes. Swift never connects to PostgreSQL. Report/evidence binaries live under configured filesystem roots; PostgreSQL stores metadata and relative keys. The ATS source is separately bundled SQLite. |
| Tools | Docker Compose, Make, Git, Pytest/HTTPX, Ruff, Xcode and iPad Simulator. OpenPyXL imports Excel sources. Jinja2 + WeasyPrint (Cairo/Pango in Docker) render PDFs; PDFKit previews them. PhotosUI/Photos/UIKit capture images, MessageUI composes mail, Network framework monitors connectivity. No external Swift package is required. |

As of 2026-11-16 the verified DEV Alembic head is `20261116_0032`. The recent revisions are
`0030` (ATS module permission), `0031` (tool balance per inventory row), and `0032` (automatic
preventive stock movements). Recheck `alembic current` and `alembic heads` when resuming work;
do not assume another environment has migrated.

## Current Product Map

### Inicio, Preventivos And Correctivos

- **Inicio** shows operational indicators and activities from `GET /api/v1/maintenance-dashboard`.
- **Preventivos** supports search, date/status/subsystem filters, a lifecycle timeline, comments,
  report versions, and paginated previous reports. The detail separates Datos generales, Checklist,
  Pasos, Comentarios, Versiones and Reportes anteriores. History must not be silently limited to
  the first batch; respect the server's pagination.
- **Reporte preventivo** has segmented general data, manual and operational checklists,
  maintenance steps, evidence, participants/signatures, and conclusions. A finalized version is
  immutable; revisions use a new draft. Keep named actions beside the title where space allows,
  outside the main navigation controls.
- **Calibración CBDAC** is captured in the preventive form and has its own segmented version view
  and PDF. For track-circuit conclusions, the catalog `maintenance_template_conclusions` supplies
  the displayed `summary` and stores the selected `description` as additional comments. The PDF
  package generates both preventive and calibration documents, lets the user open each, and
  attaches both in one email composition. A regular preventive has only its own PDF.
- **Correctivos** has a creation screen (not a popover), with affected equipment/asset tree,
  event data, and confirmation. The detail, form and version screens use segmented navigation.
  The detail shows the event timeline, comments and versions; report-derived sections only appear
  once a version is finalized. Component replacements keep their links to equipment and stock.
  In the lifecycle endpoint, the finalized corrective replacement is applied when completing the
  activity, not when merely saving or finalizing a report version.
- Lifecycle states are Programado, En progreso, Completado and Cerrado for preventives. Completing
  an activity requires a finalized report version. Saving a draft, finalizing a report version,
  completing the activity and closing it are distinct operations. Reopening does not reissue
  tools. Use the correct lifecycle endpoint rather than editing a status directly.
- Evidence previews fit the image initially and allow zoom. Preventive and corrective evidence
  titles are individually editable and limited to 127 characters in the shared frontend
  component. Camera captures can also go
  to the iPad Photos library when permission is granted. Photos do not replace server evidence.

### Corrective Solution Consultation

- Correctivos has a Consulta de soluciones entry; active detail offers Ver casos similares.
  `Views/Corrective/CorrectiveSolutionsView.swift` contains the search, source cards and separate
  protected offline knowledge library. It does not replace offline work/form packages.
- `/api/v1/corrective-solutions/{search,bundle,cases/{id},evidence/{id}}` requires corrective
  READ permissions. Source consolidation is in `infrastructure/postgres/solution_cases.py`;
  matching in `application/solution_matching.py`. Migration 0035 adds a rebuildable projection.
  Current retrieval is textual/contextual, with accents, limited typo tolerance and inspectable
  aliases, not semantic AI. Codes and basic negation are protected. No diagnostic probabilities.
- All report turns/versions remain traceable; latest finalized per report is the primary source,
  recent drafts/comments are provisional. Finalization alone is not validation. Reopened events
  remain pending. Read-time fingerprint refresh cannot block report saves. Bundle revision detects
  changes while paginating. Offline cache scopes include user, role, environment, URL and permissions.
- See `docs/corrective-solutions.md` for delivered scope and pending work: evaluated local semantic
  model, asynchronous/hybrid indexes, human review roles, and real-field precision/latency evaluation.

### PCON

- Plan anual, Calendario mensual, and Programación semanal share planning state and color guides
  above the timetable. Annual planning supports year copying; monthly planning supports confirming
  the day and removing tentative dates.
- **Agregar mantenimiento al día** lists only activities of the displayed month without an
  assigned date (Solo mes), with search and subsystem/category/location filters. Preserve proper
  first-open loading and empty states.
- Weekly planning shows 24 hours, a compact header with week navigation and filters plus a row of
  indicators, conflicts and actions. On a wide iPad, paginated Pendientes del mes sit alongside the
  timetable. Keep controls visible in short windows and retain access to overnight slots.
  Pagination supports direct numbered navigation when the page count is known.

### Equipos, Componentes And Stock

- **Equipos** lists business anchors and has compact category/subsystem/status filters. Detail
  includes images, an equipment/component tree, preventive templates and Mantenimientos realizados.
  History rows have lateral padding. Equipment administration uses master-data dropdowns, including
  the four cascading physical-location levels. Free text is limited to appropriate identification
  and technical fields. Component create/edit/move/delete in an equipment tree are separate
  operations with their own authorization and history restrictions.
- **Equipos → Componentes** lists non-anchor assets across the whole catalog (not just installed
  children). The server paginates `GET /assets?business_anchor=false`. Component detail presents
  all technical fields in general information, images alongside, and movements below without
  a segment selector. `GET/PUT /assets/{id}/component-detail` handles details and administrator-only
  technical edits; `GET /assets/{id}/movements` reads actual `asset_movements`, including inventory
  locations and slots. Missing history is shown as missing; do not infer movements from current
  parent or location. A technical edit must not relocate the asset.
- **Internal spaces** use equipment-owned `slot_locations` for independent occupancy, but their
  structure is synchronized across the same catalog category, asset type and subsystem by
  migration 0034 and `sync_equipment_slot_structure`. Adding a space shares only structure,
  never installed components. Existing spaces are backfilled and new equipment inherits the
  structure. The sheet uses the app's panels. `GET /assets/{id}/component-editor-options` now
  reads actual `asset_types` (category COMPONENT), not equipment classifications. A type is
  the part-number-level catalog model; an `assets` row is one physical unit linked through
  `asset_type_id`. Unit part number comes from the selected type and is not freely editable.
  The administrator may explicitly create a new model and its first unit atomically;
  ordinary CREATE never silently creates a type. The UI saves the current form directly,
  without a pending-batch button. Position selects a real free slot and records slot moves.
- **Unified component Add:** there is no separate Assign tab. Add starts with an existing-unit
  search and offers the full new-unit form when needed. Existing assignments preserve unit
  identity and choose both a parent and a destination slot; selecting no position is explicit.
  MOVE also accepts `destination_equipment_id`, a parent, position and expected source parent,
  and records history using the assignment workflow. The root unit's old slot is freed on a
  transfer; children with equipment-specific slots must be released before crossing equipment.
  Internal reparenting preserves descendant positions. Invalid/occupied slots roll back the
  entire change. DELETE confirms in UI and keeps the existing history/child protections.
- **Stock** manages spare assets/components, not tool quantities. The current tab is exposed to
  administrators in `MainTabView`. It has compact filters, pagination, images, creation and
  editing, with master-data selections. En Stock is green; amber represents other intermediate
  states, and red indicates no stock, failure, or retirement. Do not apply the Herramientas
  warehouse restriction across all asset location lists; some asset flows legitimately use
  equipment or train locations.

### Herramientas And Automatic Preventive Stock

- **Inventario**, **Salidas pendientes**, and **Movimientos** are distinct. Inventory has compact
  search/classification/status controls. Salidas pendientes shows quantities still open on
  recorded deliveries; Movimientos is the ledger. Lists reload when the user switches segments
  or saves a movement.
- Tool storage uses `inventory_locations.location_type_id → location_types.code`. Creation/editing
  and dispatch require an active `ALMACENAMIENTO` when a warehouse is assigned. Sin ubicación
  is allowed on the inventory form but cannot be used for dispatch. Do not list cabinets or trains
  in that selector or substitute free-text locations.
- **Registrar salida** is an administrator action on an eligible inventory row. It records
  quantity, responsible user, warehouse and optional links to activities/notes. A serialized unit
  moves as quantity 1. Manual settlement can be partial: a good return replenishes availability;
  consumption, damage and loss do not. Serial identities and tracked stock must not be overwritten
  from the editor. `tool_inventory_items` describes inventory rows, `tool_inventory` holds effective
  balances, and `tool_inventory_movements` preserves the ledger. Quantity-based balances can be
  created on first dispatch, linked to the exact inventory row; do not merge rows by name/warehouse.
- **Iniciar mantenimiento** automatically issues the active **operational** checklist's configured
  quantities (one when unspecified). Existing open deliveries linked to that activity count
  toward the requirement. Use active warehouse inventory and eligible identified units; lack of
  stock or a required eligible unit rejects the entire start with no partial deduction. The
  authorized user who starts it is recorded as responsible. This does not grant permission for
  manual stock operations and does not change the read-only role's lifecycle restrictions.
- **Finalizar mantenimiento → Completado** automatically returns the outstanding quantities of
  its automatic issues, including consumables, to the same balances/warehouses. It does not return
  unrelated manual issues or quantities already regularized. Finalizing a report version does
  not return anything. Start/complete and stock changes commit in one server transaction; locks
  prevent double deductions/returns and competing starts from overselling. The marker
  `automatic_activity_id` distinguishes the lifecycle's records from manual entries. The ledger
  shows Salida automática and Devolución automática. See
  `backend/src/modules/maintenance_execution/infrastructure/postgres/preventive_tool_stock.py`,
  `repository.py` in the same package, and the maintenance lifecycle router.
- Preventive start/completion require confirmed server access; do not mark them successful
  locally while inventory cannot be verified. Offline draft editing remains supported.

### Línea ATS

- One native workspace, based on the first LineV2 tab only. SwiftUI Canvas, gestures, catalog,
  inspector, original DC SYS attributes, calibration routes, and network-distance measurement.
  Red completa/Vía principal/Patio y enlaces reframe the visible sector. Drawing size scales
  with zoom and labels avoid collisions. The legend names the map symbols.
- Compact toolbar contains sector, Capas, Catálogo and Medir. Do not reintroduce removed track,
  type or preset controls on the main screen, or CDV/CV-Bloques as visible layers. The catalog's
  type filter and retained source data are separate from the map controls.
- Graph and object reads and distance calculation are provided by `backend/src/modules/ats_line/`;
  the bundled source is `backend/data/ats_line/dc_sys_source.sqlite3`. Do not require a separate
  LineV2 service, third-party web view, or local path outside this repository at runtime.
  The protected app cache is for consultation. The backend currently classifies POST distance
  as WRITE for the `ATS_LINE` permission even though the calculation is non-persistent; verify
  this contract before assuming that a READ profile can measure.

### Administración, Perfil, Permissions And Horario

- **Administración** is exclusive to the administrator. It centralizes users/activation, roles,
  positions, `work_area_id`, supervised areas, inclusion in schedules, master organizational
  relationships (sites, areas, projects, stages, systems, subsystems), role permissions,
  operational configuration/checklists and offline administration.
- **Perfil** is personal account information and password/session actions; operational settings
  belong in Administración. There is a technical role-preview capability only outside production;
  it is not a normal Profile "vista de prueba" section. Preserve session isolation across logouts.
- Roles: `MAINTENANCE_ENGINEER`, `COORDINATOR`, `BOSS`, `ADMINISTRATOR`. Module permissions use
  `NONE`, `READ`, `WRITE`. Tab visibility is not authorization. Verify actual dependency and
  operation-specific rules; some writes (e.g., component-detail edits and manual tool movements)
  require administrator independently of module permission. Administrators retain full access;
  the boss is read-only for maintenance lifecycle operations.
- **Horario** has implemented UI/API and tables, but is disabled in `MainTabView` pending a product
  decision. Do not enable it or add it to the production gate unasked. Background: schedules are
  per work area; bosses see assigned areas and do not appear in the roster. Editing rules include
  coordinator scope and administrator-only changes to past dates. Weeks run Monday to Sunday:
  12M 08:00–20:00, 12N 20:00–08:00 next day, COO weekdays, CBTC weekly, plus DISPO, FER and rest.

## Run, Validate And Operate

- **Backend**: from `backend/`, use `make ENV=dev build`, `make ENV=dev migrate` and
  `make ENV=dev current` (or choose `local` or `qa` explicitly). Compose uses private environment
  files at `backend/environments/<env>/.env`. Check the selected environment's ports and volumes:
  DEV currently exposes API port 8001. Check `/health`, `/health/db` and FastAPI `/docs`.
  No database resets or volume removal. Preserve relative storage references when moving environments.
- **iPad**: open the Xcode project, select `MaintenanceApp` and a valid iPad destination. Confirm the
  API URL/environment in `Config/Environment.xcconfig` and device connectivity. Signed builds
  are required for real login: unsigned builds can hit Keychain `-34018`. Use
  `CODE_SIGNING_ALLOWED=NO` only for compile checks. After an Xcode update, an unreadable
  `*.priors` warning can reflect stale DerivedData; verify destination, signing and build state
  before changing application code.
- **Offline/security**: access and refresh tokens use Keychain with refresh rotation/revocation.
  Passwords use Argon2; JWT secrets and credentials stay out of Git and documentation.
  Device-protected Application Support holds drafts/signatures/evidence; retries and conflicts
  are tracked separately. Do not equate a local draft with a finalized server report.
- **Tests**: use focused Pytest/HTTPX and Ruff checks plus an `xcodebuild` simulator compile
  for Swift changes. Test permission, status and stock mutations on disposable PostgreSQL with
  Alembic applied (`TEST_TOOL_ADMIN_DB=1` opts into tool and preventive-stock integration tests).
  Never point those tests at the team's data. Check an iPad layout in both orientations where
  relevant; distinguish compilation from interaction testing. Previously observed unrelated
  checks include a scheduling test that expects coordinators to edit past dates, and an old
  tool-permission assertion that overrides the normal permission dependency. Verify current
  results before reporting the entire suite as passing.
- **Import**: `backend/src/legacy_import/` loads WBS, Storage and tool inventory Excel sources
  using normalized records, deterministic IDs and auditable imports. Use a dry run or a disposable
  database; do not reimport physical inventory over recorded movements or copy corporate source
  files into Git.
- **Production**: pending hosting decision, TLS/secrets, backups with tested restore, monitoring,
  email policy, signing/distribution and acceptance tests. Native PDFs and email composition do
  not imply that a production mail service has been provisioned.

## Reference Index

- [Product scope](../docs/product-spec.md), [requirements](../docs/requirements.md),
  [flows](../docs/flows.md), and [UI specification](../docs/ui-spec.md).
- [Architecture](../docs/architecture.md), [database schema](../docs/database-schema.md),
  [data dictionary](../docs/data-dictionary.md), and [engineering guide](../docs/engineering-guide.md).
- [Environment setup](../docs/environment-setup.md), [offline workflow](../docs/offline-workflow.md),
  [tool administration](../docs/tool-administration.md),
  [component administration](../docs/component-administration.md), and
  [legacy import](../docs/legacy-data-import.md).
- For the live HTTP contract, prefer FastAPI's generated OpenAPI and the router/schema code.
