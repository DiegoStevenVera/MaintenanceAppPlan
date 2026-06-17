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
    | Technician starts work
    v
[IN_PROGRESS]
    |
    | Technician finalizes at least one report version
    | Technician marks work as completed/resolved
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

- Technician can move SCHEDULED -> IN_PROGRESS.
- Technician can move IN_PROGRESS -> COMPLETED.
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
    | Shows activity, assets, manual PDF, comments, images, status
    |
    | If SCHEDULED:
    |   Technician taps Start
    v
[IN_PROGRESS Preventive Detail]
    |
    | Technician taps Generate/Edit Report
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
- Some preventive activities may have extra report types, such as calibration reports.
- Editing a report creates a new version while the activity is not CLOSED.

---

## 3. Corrective Flow

```
[Corrective List]
    |
    | Technician or Coordinator creates/selects event
    v
[Corrective Event Detail]
    |
    | If SCHEDULED/OPEN:
    |   Technician taps Start
    v
[IN_PROGRESS Corrective Event]
    |
    | Technician creates/edits report for the current shift
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
    | Save data snapshot
    | Update asset hierarchy/replacement records if needed
    | Generate PDF using Stop Here marker if present
    | Create report version
    v
[Corrective Event Detail]
    |
    | Show event timeline and report versions
    | Technician resolves/completes when work is done
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
[Generate or Download Latest PDF]
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
