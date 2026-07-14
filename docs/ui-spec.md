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
| Technician | Can start, edit, finalize report versions, complete activities |
| Coordinator | Can do technician actions, close and reopen activities |
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

### 4.2 Preventive

Shows:

- scheduled activities,
- time filters for `Hoy`, `Esta semana`, `Este Mes`, and specific month/year,
- activity detail,
- manual PDF,
- reusable chat-like maintainer comments for the same maintenance template or `Equipo`,
- report versions,
- historical preventive reports with the same PDF preview structure as current versions,
- actions based on status.

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

### 4.4 Equipos

Shows:

- business-facing list of large or operationally meaningful assets labeled `Equipos`,
- quick search by equipment name, category, type, serial number, internal code, or part number,
- equipment detail,
- current location/parent,
- completed maintenance history, showing only report/PDF versions already generated,
- replacement history.

Technical note: `Equipos` are Assets marked as business anchors. Smaller Assets such as cards, racks, cableado, and replaceable components remain in the asset hierarchy but are not shown in the main `Equipos` tab by default.

### 4.5 Stock / Inventory

Shows:

- stock assets available for replacement,
- search by serial/internal code/part number,
- status and location,
- asset movement history.

### 4.6 Profile

Shows:

- current user,
- role,
- logout,
- future account/signature settings.

The mock app starts behind a local login gate. Temporary test users use password `123456`; v1 replaces this with `/api/v1/auth/login`, token storage, refresh, and session timeout.

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
- The signature visual motif is a subtle signaling/rail-map background behind operational content. It should be low contrast and must never reduce form legibility.
- Large content blocks should expand to the same readable width inside their screen container. Avoid narrow left-aligned panels unless the block is intentionally a compact indicator card.

---

## 10. PDF Sharing UI

Use iOS Share Sheet in v1:

1. User taps Share PDF.
2. App generates/downloads latest PDF.
3. iOS Share Sheet opens.

The current SwiftUI mock uses native Share Sheet behavior with temporary share content so the team can validate the interaction. In v1, the preferred architecture is backend/infrastructure PDF generation for canonical, immutable report artifacts; the frontend receives or downloads that artifact and invokes the iOS Share Sheet.
4. User shares through available corporate apps.

No delivery tracking in v1.
