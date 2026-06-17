# Mock-First iPad Flow

**Version:** 0.1  
**Status:** Draft  
**Last Updated:** 2026-06-17

---

## 1. Purpose

This document defines the first mock-first iPad experience before backend and real API implementation.

The goal is to validate:

- navigation,
- screen behavior,
- maintenance lifecycle,
- report versioning,
- corrective dynamic forms,
- asset selection,
- stock selection,
- participant signatures,
- PDF preview/share behavior.

This is not a database schema, API contract, or final UI design.

---

## 2. Mock-First Principles

- Use realistic fake data from Metro Lima Line 2 / Signaling.
- Prioritize iPad workflows.
- Avoid backend dependencies.
- Use in-memory or static mock data.
- Show real operational states and actions.
- Validate the experience with technicians/coordinator before backend work.
- Use English documentation and technical labels.
- App-visible labels, seed data, dropdown values, report content, and database business data must be in Spanish because end users are Spanish-speaking.
- Code, code comments, technical identifiers, and project documentation remain in English.

---

## 3. Roles in the Prototype

| Role | Mock Behavior |
|------|---------------|
| Technician | Display label: Tecnico mantenedor. Can start maintenance, create/edit reports, complete activities, sign as participant |
| Coordinator | Display label: Coordinador. Can do Technician actions, close and reopen activities |
| Boss | Display label: Jefe. Read-only access to metrics, activity details, reports, PDFs, timelines |
| Administrator | Display label: Administrador. Full access; admin screens can be mocked as placeholders |

---

## 4. Global Navigation

Recommended tab structure for the iPad mock:

1. Inicio
2. Preventivos
3. Correctivos
4. Activos
5. Stock
6. Perfil

Optional future tabs:

- Planning
- Reports
- Admin

---

## 5. Global Status Model

Preventive and corrective activities share the same lifecycle.

| Status | Meaning | Main Actions |
|--------|---------|--------------|
| Programado | Activity exists but has not started | Iniciar |
| En progreso | Work is underway | Generar/Editar reporte, Completar |
| Completado | Work is done but report can still be refined | Editar reporte, Compartir PDF, Cerrar |
| Cerrado | Coordinator closed the activity | Solo ver, Reabrir |

Rules:

- Technician can start and complete activities.
- Coordinator can close and reopen activities.
- Boss can only view.
- Administrator can do all actions.
- Reports are editable until the activity is Cerrado.
- Editing/finalizing creates a new report version.

---

## 6. Home Flow

### 6.1 Entry

User opens the app after login.

### 6.2 Screen Content

Home should show:

- user greeting,
- current role,
- today's preventive activities,
- open/in-progress corrective events,
- pending completed activities waiting for Coordinator closure,
- maintenance counters,
- quick search entry point.

### 6.3 Primary Cards

| Card | Shows | Tap Behavior |
|------|-------|--------------|
| Today's Preventive | Count and short list | Opens Preventive tab filtered to Today |
| Correctivos activos | Count and severity list | Opens Corrective tab filtered to Abiertos/En progreso |
| Pendientes de cierre | Completed activities not closed | Coordinator opens review list |
| Quick Asset Search | Search field/button | Opens Asset Search |

### 6.4 Empty States

- No preventive today: "No preventive activities scheduled for today."
- No corrective events: "No open corrective events."
- No pending closure: "No activities waiting for closure."

Mock UI copy should use Spanish equivalents:

- "No hay preventivos programados para hoy."
- "No hay correctivos abiertos."
- "No hay actividades pendientes de cierre."

---

## 7. Preventive Flow

### 7.1 Preventive List

List sections:

- Vencidos
- Hoy
- Esta semana
- Este mes
- Cerrados

Each row shows:

- activity name,
- asset(s),
- subsystem,
- area/location,
- scheduled date,
- status badge,
- latest report version if any.

### 7.2 Preventive Detail

Shows:

- activity name,
- status,
- system/subsystem,
- asset(s),
- location,
- manual reference,
- frequency,
- expected duration,
- required tools,
- required personnel count,
- maintainer notes/comments,
- related images,
- report versions.

### 7.3 Preventive Detail Actions

| Status | Technician | Coordinator | Boss |
|--------|------------|-------------|------|
| Programado | Iniciar | Iniciar | Ver |
| En progreso | Generar/Editar reporte, Completar when report exists | Generar/Editar reporte, Completar | Ver |
| Completado | Editar reporte, Compartir PDF | Editar reporte, Compartir PDF, Cerrar | Ver |
| Cerrado | Ver historial de PDF/versiones | Ver, Reabrir | Ver |

### 7.4 Start Preventive

Flow:

1. User taps Start.
2. Status changes to En progreso.
3. Start timestamp is shown.
4. Report actions become available.

### 7.5 Preventive Report Form

Sections:

1. General metadata
2. Personnel
3. Tools
4. Template steps
5. Tests/results
6. Attachments
7. Conclusions/comments
8. Participant signatures

Each step row shows:

- task/step title,
- completion checkbox,
- manual page button,
- tests/results button,
- optional comment.

### 7.6 Manual Page Popup

When user taps manual reference:

1. Show PDF placeholder or mock preview.
2. Open at the task-specific page.
3. Allow close/back.

### 7.7 Tests Popup

Shows one or more tests for a step.

Each test has:

- test name,
- result input/dropdown,
- optional notes.

### 7.8 Finalize Preventive Report Version

Flow:

1. User validates required fields.
2. User captures participant signatures.
3. User taps Finalize Report.
4. System creates new version.
5. System generates mock PDF.
6. User returns to Preventive Detail.

### 7.9 Complete Preventive

Enabled only after at least one report version exists.

Flow:

1. Technician taps Complete.
2. Optional notes.
3. Status changes to Completado.
4. Coordinator can close later.

---

## 8. Corrective Flow

### 8.1 Corrective List

List sections:

- Abiertos/Programados
- En progreso
- Completados
- Cerrados

Each row shows:

- event code,
- SAP code,
- affected asset,
- subsystem,
- location,
- severity,
- status,
- latest report version,
- opened time.

### 8.2 Create Corrective Event

Available to:

- Technician in v1,
- Coordinator,
- Administrator.

Flow:

1. User taps +.
2. Select/search affected asset.
3. Select subsystem.
4. Enter SAP code if available.
5. Select severity.
6. Enter short issue description.
7. Add optional initial photo.
8. Create event.

Initial status:

- Programado/Abierto.

### 8.3 Corrective Event Detail

Shows:

- event status,
- severity,
- SAP code,
- affected asset link,
- location,
- subsystem,
- failure description,
- timeline,
- report versions,
- replacement summary if any.

### 8.4 Corrective Event Actions

| Status | Technician | Coordinator | Boss |
|--------|------------|-------------|------|
| Programado/Abierto | Iniciar, Crear/Editar reporte | Iniciar, Crear/Editar reporte | Ver |
| En progreso | Crear/Editar reporte, Completar | Crear/Editar reporte, Completar | Ver |
| Completado | Editar reporte, Compartir PDF | Editar reporte, Compartir PDF, Cerrar | Ver |
| Cerrado | Ver | Ver, Reabrir | Ver |

### 8.5 Corrective Dynamic Report Form

The form is dynamic and follows the real corrective report structure.

Recommended mock blocks:

1. Event metadata
2. Affected asset and location
3. Failure description and operational impact
4. Activities performed
5. Tests and validation
6. Attachments
7. Conclusions/comments
8. Participants and signatures

### 8.6 Activities Performed Block

User can add multiple activities.

Each activity has:

- activity type,
- description,
- optional start/end time,
- optional notes.

Mock activity types:

- Inspeccion / Levantamiento de data
- Cambio de componente
- Limpieza
- Ajuste
- Medicion
- Accion de software
- Investigacion / Pruebas
- Otro

### 8.7 Cambio de componente Dynamic Sub-Block

Appears only when activity type = Cambio de componente.

Fields:

- parent/affected asset,
- removed asset,
- installed asset,
- source of installed asset,
- destination of removed asset,
- replacement reason,
- notes.

Actions:

- Select removed asset from current hierarchy.
- Select installed asset from Stock.
- Search asset manually.
- Enter unknown asset manually as mock future behavior.

### 8.8 Stop Here Marker

Stop Here is a marker, not a locked partial report state.

Flow:

1. User taps Stop Here.
2. User selects a block/point in the report.
3. User adds optional handover note.
4. Marker appears in report form and timeline.
5. Mock PDF hides empty blocks after the marker.

### 8.9 Finalize Corrective Report Version

Flow:

1. Validate required fields.
2. Validate participant signatures.
3. Apply replacement changes in mock state if any.
4. Create new report version.
5. Generate mock PDF.
6. Update event timeline.

### 8.10 Complete Corrective Event

Enabled when at least one report version exists.

Flow:

1. Technician taps Complete/Resolve.
2. Adds optional resolution notes.
3. Status changes to Completado.
4. Coordinator closes later.

---

## 9. Asset Flow

### 9.1 Asset Search

Search by:

- name,
- serial number,
- internal code,
- part number,
- subsystem,
- category.

Each result shows:

- asset name,
- category,
- serial/internal code,
- part number,
- status,
- breadcrumb path.

### 9.2 Asset Hierarchy Browse

Mock hierarchy should support:

- top-level assets,
- nested child assets,
- software children,
- stock/warehouse assets.

Example:

```
Zone Controller 4
  -> PCSG 1
    -> CIER 1
```

### 9.3 Asset Detail

Shows:

- name,
- category,
- asset type,
- serial number or internal code,
- part number,
- current status,
- current parent/location,
- children,
- maintenance history,
- replacement history.

---

## 10. Stock Flow

### 10.1 Stock List

Shows assets available for replacement.

Filters:

- subsystem,
- category,
- asset type,
- part number,
- status,
- location.

### 10.2 Stock Selection

Used from corrective replacement block.

Flow:

1. User taps Select Installed Asset.
2. Stock picker opens.
3. User filters by part number/type.
4. User selects available asset.
5. Selected asset returns to replacement block.

---

## 11. Signature Flow

Flow:

1. User adds/selects participant.
2. User opens Signature Pad.
3. Participant signs on shared iPad.
4. Signature thumbnail appears.
5. Signature is linked to the participant and report version.

Mock behavior:

- Signature can be represented by a simple drawn canvas placeholder.
- Future version may require account-level approval per participant.

---

## 12. PDF Preview and Share Flow

### 12.1 PDF Preview

For mock:

- show generated PDF placeholder,
- show version number,
- show included sections/blocks,
- show hidden blocks if Stop Here is active.

### 12.2 Share Sheet

Flow:

1. User taps Share PDF.
2. App opens native iOS Share Sheet in real SwiftUI prototype.
3. For design-only mock, show a modal named "iOS Share Sheet".

No delivery tracking in v1.

---

## 13. Prototype Success Criteria

The mock-first prototype is successful when the team can answer:

- Can a technician understand what to do next?
- Are preventive and corrective flows clear?
- Are report versions understandable?
- Does Stop Here behave as expected?
- Is component replacement naturally placed inside activities performed?
- Can users find assets quickly?
- Can stock selection be understood without inventory training?
- Does Coordinator closure make sense?
- Is Boss read-only behavior clear?

When validating with end users, these questions should be asked in Spanish even though this document is maintained in English.
