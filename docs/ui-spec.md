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
- touch-first,
- field-friendly,
- minimal typing,
- large tap targets,
- clear status visibility.

Future:

- iPhone support after corporate approval.

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
- overdue/today/week filters,
- activity detail,
- manual PDF,
- comments/notes from maintainers,
- report versions,
- actions based on status.

### 4.3 Corrective

Shows:

- corrective events,
- status filters,
- event detail,
- timeline,
- report versions,
- dynamic corrective report form,
- replacement blocks inside activities.

### 4.4 Assets

Shows:

- hierarchy drill-down,
- quick search by name, serial number, internal code, part number,
- asset detail,
- current location/parent,
- maintenance history,
- replacement history.

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

---

## 5. Activity Status UI

| Status | Meaning | Primary Actions |
|--------|---------|-----------------|
| Scheduled | Not started | Start |
| In Progress | Work underway | Generate/Edit Report, Complete |
| Completed | Work done, report can still be refined | Edit Report, Share PDF, Close (Coordinator only) |
| Closed | Fully closed | View only; Reopen (Coordinator/Admin only) |

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
- failure and impact,
- activities performed,
- replacement details when task type is Component Replacement,
- tests and validation,
- attachments,
- participants/signatures,
- comments/conclusion.

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

---

## 9. PDF Sharing UI

Use iOS Share Sheet in v1:

1. User taps Share PDF.
2. App generates/downloads latest PDF.
3. iOS Share Sheet opens.
4. User shares through available corporate apps.

No delivery tracking in v1.
