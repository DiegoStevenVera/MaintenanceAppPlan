# User and Operational Flows

**Version:** 0.1  
**Status:** Draft  
**Last Updated:** 2026-06-16

---

## 1. Shared Maintenance Lifecycle

Applies to both preventive and corrective maintenance.

```
[SCHEDULED]
    |
    | Maintenance Engineer starts work
    v
[IN_PROGRESS]
    |
    | Maintenance Engineer finalizes at least one report version
    | Maintenance Engineer marks work as completed/resolved
    v
[COMPLETED]
    |
    | Coordinator reviews and closes
    v
[CLOSED]
    |
    | Coordinator/Admin reopens if correction is needed
    v
[IN_PROGRESS]
```

Rules:

- Maintenance Engineer can move SCHEDULED -> IN_PROGRESS.
- Maintenance Engineer can move IN_PROGRESS -> COMPLETED.
- Coordinator/Admin can move COMPLETED -> CLOSED.
- Coordinator/Admin can reopen CLOSED -> IN_PROGRESS.
- Boss is read-only.
- Reports are editable until CLOSED.

---

## 2. Preventive Flow

```
[Preventive List]
    |
    | Select scheduled preventive activity
    v
[Preventive Detail]
    |
    | Shows scheduled context, assets, status and reusable comments
    | Shows template steps/tests as guidance, without execution results
    | Shows current activity versions and previous finalized executions separately
    | A version/history row opens the immutable execution detail and PDF
    |
    | If SCHEDULED:
    |   Maintenance Engineer taps Start
    v
[IN_PROGRESS Preventive Detail]
    |
    | Maintenance Engineer taps Generate/Edit Report
    v
[Preventive Report Form]
    |
    | Load template steps/tests/manual references
    | Fill results, comments, tools, attachments
    | Open manual at task-specific PDF page
    | Capture participant signatures
    v
[Finalize Report Version]
    |
    | Save data snapshot
    | Generate PDF
    | Create report version
    v
[Preventive Detail]
    |
    | Show report versions
    | Enable Complete/Resolve after at least one report version
    | Enable Share PDF via iOS Share Sheet
    v
[COMPLETED]
    |
    | Coordinator closes after review
    v
[CLOSED]
```

Notes:

- Most preventive activities have one main report.
- Track-circuit preventive activities produce a main preventive report and a companion calibration
  report in the same save/finalize transaction.
- The calibration form captures frequency, transmitter jumpers, and one to four current receivers.
  Each receiver captures jumpers, TCA9, and rail current. The backend model supports additional
  numbered receivers without a schema change.
- Each companion calibration is a separate logical report/version with its own read-only detail,
  HTML template, persisted PDF, viewer, download, and iOS Share Sheet action.
- Editing a report creates a new version while the activity is not CLOSED.
- The guide always comes from `maintenance_templates`; captured results are visible only after opening a `report_version`.
- Previous executions must match both the preventive template and the business-anchor equipment.

---

## 3. Corrective Flow

```
[Corrective List]
    |
    | Maintenance Engineer, Coordinator, or Administrator taps +
    | Select subsystem and search business-anchor equipment
    | Select the affected asset in the real equipment tree
    | Load read-only project/location context from the equipment
    | Enter SAP data, severity, and notice date/time
    | Create event and normalized maintenance activity atomically
    v
[Corrective Event Detail]
    |
    | If SCHEDULED/OPEN:
    |   Maintenance Engineer taps Start
    v
[IN_PROGRESS Corrective Event]
    |
    | Maintenance Engineer creates/edits report for the current shift
    v
[Corrective Report Form]
    |
    | Fill event data
    | Fill failure/impact details
    | Add activities performed
    | Select activity type per activity
    | If activity type = Component Replacement:
    |   Show replacement fields inside the activity block
    |   Select removed asset
    |   Select installed asset from stock or asset search
    |   Select source/destination/reason
    | Add tests/validation
    | Add attachments
    | Capture participant signatures
    | Optionally set Stop Here marker
    v
[Finalize Report Version]
    |
    | Save immutable data and component metadata snapshots
    | Create report version without changing live inventory
    | Enable PDF generation using Stop Here marker if present
    v
[Corrective Event Detail]
    |
    | Show event timeline and report versions
    | Maintenance Engineer resolves/completes when work is done
    | On Complete, atomically apply pending component replacements
    | Enrich only missing normalized asset metadata
    | Skip replacements already applied by this maintenance activity
    v
[COMPLETED]
    |
    | Coordinator closes after review
    v
[CLOSED]
```

Notes:

- Corrective maintenance allows one report per shift per event.
- Stop Here does not lock future sections. It only controls report/PDF visibility up to a marker.
- The next shift may continue after the marker and may correct previous fields if needed.

---

## 4. Asset Replacement Flow

```
[Corrective Report Form]
    |
    | Add activity
    | Select type = Component Replacement
    v
[Replacement Block]
    |
    | Select parent/affected asset context
    | Select removed asset currently installed
    | Select installed asset from:
    |   - stock
    |   - asset search
    |   - manual registration if not found
    | Select removed asset destination:
    |   - stock/warehouse
    |   - repair
    |   - scrap
    |   - quarantine
    | Add reason and notes
    v
[Save Replacement]
    |
    | Close old AssetAssignment
    | Create new AssetAssignment
    | Update live hierarchy
    | Preserve movement/replacement history
    v
[Report Activity Saved]
```

---

## 5. Signature Flow

```
[Report Form]
    |
    | Add participant
    | Select participant name
    v
[Signature Pad]
    |
    | Participant signs on shared iPad
    v
[Confirm Signature]
    |
    | Store signature image
    | Link signature to participant and report version
    v
[Report Form]
```

Future:

- Each participant receives an approval/signature request in their own account/device.

---

## 6. PDF Sharing Flow

```
[Report Detail]
    |
    | Tap Share PDF
    v
[Generate (if missing) or Download Latest PDF]
    |
    | Open iOS Share Sheet
    v
[User chooses Mail / Outlook / Teams / Files / AirDrop]
```

v1 does not track delivery status.

---

## 7. Local-First Demo Flow

```
[Mac runs local backend + PostgreSQL]
    |
    | iPad connects over local network
    v
[SwiftUI App]
    |
    | Uses mock-first UI initially
    | Later connects to local API
```

Cloud/on-premise production deployment remains pending approval.

## 8. Offline Report Draft Flow

1. The engineer opens an in-progress preventive or corrective report while online.
2. The app caches the activity detail and report editor context locally.
3. Form changes are autosaved locally after a short debounce, including signatures and
   selected evidence.
4. If the API cannot be reached, `Guardar borrador` queues the local record and the UI
   displays `Pendiente de sincronizar`.
5. The engineer can close and reopen the app and return to the draft from the global
   offline status bar.
6. Connectivity recovery, foreground activation, or manual retry starts synchronization.
7. The API accepts the draft only if its base report version is still current.
8. On success the local record is removed. On a version conflict it remains visible as
   `Requiere atención`.
9. `Finalizar versión` is available only with a live server connection.

## 9. Equipment History Report Flow

1. The user opens `Equipos` and selects a business-anchor equipment.
2. `Mantenimientos realizados` shows only completed/closed activities linked to
   that exact equipment.
3. A row with a finalized version opens the shared immutable report-version
   screen, where its PDF can be viewed, generated, or shared.
4. A historical activity without a finalized version opens maintenance detail
   so its current report state remains visible.

## 10. Administrator Role Preview Flow

1. An Administrator opens Profile and selects `Cambiar rol de prueba`.
2. The API returns only roles represented by active users.
3. Selecting a role creates a normal session for that user; all backend
   authorization checks use the selected user's real role.
4. The original Administrator session remains protected in Keychain.
5. `Volver a administrador` refreshes and restores that original session.
6. The backend disables this flow when the environment is production.

## 11. PCON Annual and Weekly Planning Flow

1. Every authenticated role can open `Plan anual` and inspect the hierarchy
   `Subsystem -> Equipment category -> Geographic location -> Equipment ->
   Equipment maintenance`.
2. The twelve month columns contain quantities of planned maintenance
   executions. Parent rows aggregate their descendants; only the maintenance
   leaf is editable.
3. Selecting a monthly cell opens its concrete occurrences and planning states.
   Coordinator or Administrator may change the quantity. Increasing it creates
   individually schedulable occurrences. Reducing it is rejected when the
   affected occurrences already have a date, proposal, execution, or report.
4. A year with no persisted plan displays the latest prior year's maintenance
   rows with zero quantities. The user can either build it progressively or
   explicitly copy the prior year; copying never carries exact weekly dates and
   does not overwrite target cells that already contain occurrences.
5. `Administrar` allows Coordinator or Administrator to add an eligible
   equipment-maintenance pairing. A monthly cell allows creating extra
   occurrences, moving an untouched occurrence to another month, deleting an
   untouched occurrence, or cancelling a confirmed future occurrence with a
   reason. Every operation is added to annual plan history.
6. In `Programación semanal`, the editor chooses an unscheduled occurrence and
   records its exact start/end
   range. This creates or updates a `PROPOSED` schedule revision; it does not
   alter the maintenance activity yet.
7. A previously confirmed activity can be proposed again only with a reason.
8. The weekly screen accumulates proposals in one draft session.
9. `Confirmar semana` validates every proposal, the weekly date boundary,
   activity status, required reprogramming reasons, and overlapping activities
   for the same primary equipment.
10. If any validation fails, the transaction rolls back and no activity date
   changes.
11. If all validations pass, every activity receives its confirmed start/end
   range, revisions become `CONFIRMED`, prior revisions become `SUPERSEDED`,
   and the session becomes `CONFIRMED`.
12. The toolbar history separates annual administrative changes from weekly
    schedule revisions and exposes actor, reason, timestamp, and prior/replacement
    information as applicable.
