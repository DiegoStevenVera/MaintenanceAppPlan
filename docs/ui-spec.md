# UI Specification

**Version:** 0.1  
**Status:** Draft  
**Last Updated:** 2026-06-16

---

## 1. Product Direction

The first UI deliverable should be a mock-first iPad experience that demonstrates:

- home/dashboard summary,
- preventive maintenance flow,
- corrective maintenance flow,
- asset search/hierarchy,
- report versioning,
- PDF generation/share,
- shared-iPad participant signature flow.

The first UI work may be design-only before production code.

---

## 2. Target Device

Primary v1 target:

- shared iPad,
- iPadOS 26.5,
- touch-first,
- field-friendly,
- minimal typing,
- large tap targets,
- clear status visibility.

Future:

- iPhone support is enabled in the Xcode target for iOS 26.5 validation, but the primary UX/design validation remains iPad until physical iPhone testing is completed.

---

## 3. Roles in UI

| Role | UI Behavior |
|------|-------------|
| Maintenance Engineer | Can start, edit, finalize report versions, complete activities |
| Coordinator | Can do maintenance engineer actions, close and reopen activities |
| Boss | Read-only; can view metrics, reports, PDFs, timelines |
| Administrator | Full access including configuration |

Do not use the label "Supervisor" in new UI.

---

## 4. Main Screens

### 4.1 Home

Shows:

- maintenance summary,
- activities due today,
- corrective events open/in progress,
- preventive activities due today,
- completed/pending/closed counts.

The three summary indicators are interactive single-selection filters. Tapping an
indicator shows only its matching activity group, tapping a different indicator
replaces the prior filter, and tapping the selected indicator again clears it.
Without an indicator filter, Home shows both `Preventivos de hoy` and
`Correctivos`, where the corrective section contains scheduled and in-progress
activities. `Pendientes de cierre` shows completed activities awaiting the
coordinator close transition.

### 4.2 Preventive

Shows:

- scheduled activities,
- time filters for `Hoy`, `Esta semana`, `Este Mes`, and specific month/year,
- activity detail with scheduled context and reusable template guidance,
- template steps/tests without captured checks, comments, conclusions, or results,
- manual PDF,
- reusable chat-like maintainer comments for the same maintenance template or `Equipo`,
- report versions belonging to the selected scheduled activity,
- historical preventive reports for the same template and business-anchor equipment, with the same read-only detail/PDF preview structure as current versions,
- actions based on status.

For track-circuit maintenance only, the preventive report form adds a `Calibración del circuito
de vía` block. It uses compact native controls: frequency in Hz, transmitter jumpers, a receiver
count stepper from 1 to 4, and a segmented receiver selector. Only the selected receiver's jumpers,
TCA9, and rail-current fields are expanded at a time. The generated companion calibration version
appears in the normal version list and opens the shared read-only viewer with PDF and Share Sheet
actions after finalization.

### 4.3 Corrective

Shows:

- corrective events,
- status filters,
- create corrective event flow from the `+` action,
- event detail,
- timeline,
- report versions,
- dynamic corrective report form,
- replacement blocks inside activities.

Corrective event creation should use a large iPad sheet. It captures read-only project context (`Sede`, `Proyecto`, `Etapa`, `Sistema`), a selectable subsystem (`ATS`, `CBTC`, `IXL`), a searchable business-anchor `Equipo` list filtered by subsystem, a hierarchical affected asset selector starting from the selected `Equipo`, default location from the selected equipment, editable SAP event name, editable SAP notification, editable notice creation date/time, and an automatic response date/time set at creation. Physical/geographic location is metadata, not a selectable asset tree node.

The `+` action is available to Maintenance Engineer, Coordinator, and Administrator. Creating an event must refresh the normalized corrective list immediately.

### 4.4 Equipos

Shows:

- business-facing list of large or operationally meaningful assets labeled `Equipos`,
- quick search by equipment name, category, type, serial number, internal code, or part number,
- equipment detail,
- current location/parent,
- completed maintenance history; a finalized version opens the shared read-only
  report/PDF screen, while an activity without a finalized version opens its
  maintenance detail,
- replacement history.

Technical note: `Equipos` are Assets marked as business anchors. Smaller Assets such as cards, racks, cableado, and replaceable components remain in the asset hierarchy but are not shown in the main `Equipos` tab by default.

### 4.5 Stock / Inventory

Shows:

- stock assets available for replacement,
- paginated API search by serial number, internal code, asset type, part number,
  or inventory location,
- status and location,
- asset movement history.

### 4.6 Profile

Shows:

- current user,
- role,
- non-production role preview for Administrators, backed by a real active user
  session and a protected return to the original Administrator session,
- logout,
- future account/signature settings.

The app starts behind the API login gate and stores access and refresh tokens in
Keychain. Role preview is not a local visual override and is disabled by the
backend in production environments.

### 4.7 Buttons

Action buttons should use centered icon + label content, full available width inside their grid cell, and adaptive two/three-column layouts on iPad where space allows. Inline toolbar controls may remain native compact controls.

---

## 5. Activity Status UI

| Status | Meaning | Primary Actions |
|--------|---------|-----------------|
| Scheduled | Not started | Start |
| In Progress | Work underway | Generate/Edit Report, Complete |
| Completed | Work done, can be reopened for correction | Reopen to In Progress, Share PDF, Close (Coordinator only) |
| Closed | Fully closed by Coordinator/Admin | View only; Reopen to In Progress (Coordinator/Admin only) |

---

## 6. Report Version UI

Each report list should show:

- latest version first,
- version number,
- generated date/time,
- created by,
- PDF action,
- previous versions available for review.

Editing a report creates a new version when finalized.

---

## 7. Corrective Dynamic Form

The corrective form should not use a fixed six-section layout.

It should include blocks for:

- event/SAP/location/equipment,
- physical location of the business-anchor equipment,
- failure and impact: recorded symptom, detailed technical description, operational impact,
- failure analysis: functional, hardware, software, communications, or energy,
- activities performed,
- replacement details when task type is Component Replacement, including removed asset selection from the equipment tree and installed asset selection from stock filtered by warehouse,
- tests and validation: functional tests, result, service release, release date/time, responsible validator,
- attachments,
- participants/signatures,
- comments/conclusion with technical equipment status.

The component-replacement editor uses two visually separate blocks. `Componente a retirar` opens
the affected-equipment hierarchy and shows its full breadcrumb and stored technical metadata.
`Componente a reponer` first selects the source warehouse and then opens a searchable stock sheet.
Both blocks retain condition, destination/source, and notes. Corrective evidence uses the same
multi-image PhotosPicker behavior as preventive evidence.

Asset metadata must use the normalized `assets.serial_number`, never `internal_code` or
`serial_or_code` as a serial-number fallback. Existing part number, serial number, model, and
manufacturer values are read-only in the replacement form. Missing values become text inputs and
are saved with the report snapshot, then incorporated into the asset record when the corrective
activity is completed.

Report creation/editing is available only while the preventive or corrective maintenance is `En progreso`. Scheduled items can only be started; completed items can be shared/closed but not edited unless reopened into an editable state.

Corrective location rules:

- `Etapa` is project metadata and must not be displayed as physical location.
- Physical location is read from the selected business-anchor equipment, for example station, patio, technical room, track sector, or train car.
- The asset tree is structural only. Location metadata must never appear as a selectable asset branch.

List filtering:

- Preventive filters are mandatory and use scheduled maintenance date: `Hoy`, `Esta semana`, `Este Mes`, or a specific month/year, plus text search by maintenance name.
- Corrective filters are optional and use event notice creation date. With no date filter active, all corrective states remain visible.
- Equipment detail must expose preventive and corrective maintenance history for the selected business-anchor equipment as generated report/PDF versions only.

---

## 8. Signature UI

Flow:

1. Add participant.
2. Select participant name.
3. Open signature pad.
4. Participant signs on shared iPad.
5. Signature is linked to participant and report version.

Future:

- per-user approval/signature from personal device.

Preventive report participant rows should show each active maintainer checked by default, display their role and avatar/profile image, and expose the signature action directly in the participant segment.

Draft editors may retain selected and unselected participant rows so the selection can be changed. Read-only version detail, generated PDF, and Share Sheet output show only participants whose `selected` value was true when that version was saved.

In preventive and corrective editors, selected participants remain visible with their signature
action and preview. Unselected users are moved into a collapsed native disclosure row labeled
`No seleccionados (N)` and can be restored without leaving the form. The participant catalog is
limited to active users in the Signaling Maintenance work area
`006a0fb0-8fae-5ec6-88cb-4231d96d172a`.

## 8.1 Preventive Form UI

General metadata is read-only except for activity end time. The form shows site, project, stage, system, subsystem, current date, start time, end time, full location path, equipment, and manual reference.

Maintenance steps include their own tests/results area. Each test uses a dropdown when it has configured result options. Conclusions use a dropdown with: Equipo operativo, Equipo no operativo, Equipo medio operativo.

---

## 9. Visual Direction

The iPad mock-first UI should follow the Hitachi logo palette:

| Token | Hex | UI Usage |
|-------|-----|----------|
| Hitachi Red | `#E60012` | Primary actions, active tab, selected filters, key brand moments |
| Hitachi Black | `#000000` | High contrast text and dark mode foundation |
| Hitachi White | `#FFFFFF` | Primary app background |
| Hitachi Graphite | `#4A4A4A` | Secondary text, icons, quiet interface chrome |

Guidelines:

- Use red as a precise accent, not as a dominant background.
- Keep operational screens mostly neutral so forms, reports, and asset data are easy to scan.
- Do not use red for normal statuses if it could be confused with error or urgency.
- Use amber for in-progress, green for completed/finalized, graphite/dark gray for scheduled/closed, and red for overdue/critical/destructive states.
- Use a restrained Liquid Glass-inspired layer for iPad screens: translucent material cards, soft highlights, and interactive depth for dashboards, lists, search panels, and PDF previews.
- Preserve native iPadOS navigation and TabView behavior. Do not replace the system tab/navigation chrome with a custom bar unless there is a strong product reason.
- The pure screen background must remain Hitachi White in day mode and Hitachi Black in night mode. The signaling/rail-map line motif may sit above it as a subtle low-contrast layer, but no background color gradient should replace the pure base.
- Indicator cards should use a large numeric value, uppercase label, small status dot/text, and a faint oversized icon in the background.
- Preventive and corrective activity cards should use a high-contrast task-card structure: rounded card, optional red leading rail for active/urgent items, title/location/status hierarchy, and compact timing metadata.
- Preventive detail, preventive form, corrective detail, corrective form, equipment detail, stock, and PDF previews should use the same task-detail block system: strong title header where applicable, full-width Liquid Glass panels, nested detail tiles, and consistent section spacing.
- Each preventive test uses a native `Picker` populated from that test's configured result options. A result with controlled options is never rendered as free text.
- The preventive evidence picker supports selecting multiple library images in one operation. Selected images remain editable in the draft and are normalized before upload.
- Preventive and corrective forms render selected evidence as adaptive image
  thumbnails, whether the file is newly selected offline or already persisted.
  Immutable report-version detail uses the same visual grid and downloads
  stored images through the authenticated attachment endpoint. Tapping any
  thumbnail opens the complete image.
- The signature visual motif is a subtle signaling/rail-map background behind operational content. It should be low contrast and must never reduce form legibility.
- Large content blocks should expand to the same readable width inside their screen container. Avoid narrow left-aligned panels unless the block is intentionally a compact indicator card.

---

## 10. PDF Sharing UI

Use iOS Share Sheet in v1:

1. User taps Share PDF.
2. App generates/downloads latest PDF.
3. iOS Share Sheet opens.
4. User shares through available corporate apps.

The v1 implementation downloads the canonical preventive or corrective backend artifact to a temporary local URL, opens it with PDFKit, and invokes the iOS Share Sheet with that same PDF URL. Tapping any report version opens its immutable API snapshot. The read-only report-version screen is also the entry point for `Generar PDF` when a `FINALIZED` version has no generated artifact yet. Draft versions never expose PDF generation actions.

No delivery tracking in v1.

## 11. Offline Draft Feedback

- A compact global status bar appears when the device is offline or report drafts are
  pending. It shows connectivity, pending count, and access to the draft list.
- Preventive and corrective forms show a local state banner: saved locally, pending,
  synchronizing, synchronized, or requires attention.
- Unsaved edits are persisted after a short pause and whenever the app leaves the
  foreground.
- The draft list identifies maintenance type, activity, last local update, and retry
  state. It can reopen the appropriate form after an app restart.
- Manual retry is available, while normal recovery is automatic.
- Finalization is not presented as an offline-capable action. The UI explains that a
  server connection is required.

## 12. PCON Planning UI

- PCON is a native top-level tab with two primary segmented views: `Plan anual`
  and `Programación semanal`. Planning history is available from the toolbar.
- The annual view is an Excel-analogous twelve-month matrix with collapsible
  hierarchy: subsystem, equipment category, geographic location, equipment,
  and equipment maintenance.
- Every monthly cell shows the quantity of maintenance executions. Parent rows
  display aggregate quantities. Selecting a maintenance cell opens its concrete
  occurrences and their month-only, proposed, confirmed, or executed states.
- Leaf-cell quantities use the state color directly instead of a separate dot:
  red for month-only, amber for proposed, green for confirmed, and graphite for
  executed. A visible legend accompanies the matrix. When a cell contains mixed
  states, the number uses the most pending state in that order.
- Years without stored quantities still show the prior plan's hierarchy with
  zeroes and a visible baseline indicator. `Administrar` offers an explicit
  prior-year copy and an `Agregar mantenimiento` sheet with subsystem,
  searchable equipment, existing maintenance definition, month, and quantity.
- Coordinator and Administrator can adjust a maintenance cell quantity,
  move or remove individual annual occurrences, cancel confirmed future
  occurrences with a reason, program/reprogram weekly occurrences, delete draft
  proposals, and confirm the week.
- Maintenance Engineer and Boss see the same operational information with a
  `Solo lectura` indicator and no write controls.
- The weekly view displays individually schedulable occurrences from the
  corresponding monthly plan and keeps proposals in a clearly identified block.
  `Confirmar semana` always confirms the complete block and its confirmation
  dialog states that one invalid proposal prevents all changes.
- Exact dates use native date/time pickers constrained to the selected week.
  Reprogramming displays a mandatory reason field.
- Planning history is segmented into annual administrative changes and weekly
  schedule revisions.
- The visual treatment reuses the application's full-width Liquid Glass panels,
  Hitachi color tokens, pure white/black backgrounds, SF Symbols, Dynamic Type,
  and native TabView/navigation behavior.
