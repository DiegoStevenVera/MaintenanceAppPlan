# Mock Slice 01: iPad Preventive Flow

**Version:** 0.1  
**Status:** Draft  
**Last Updated:** 2026-06-19

---

## 1. Purpose

This document defines the first mock-first implementation slice for the iPad prototype.

The goal is to validate the core preventive maintenance flow with realistic Spanish app-visible data before building backend APIs.

This slice is UI-only and must use local mock data.

---

## 2. Scope

### Included

- iPad-first SwiftUI app shell.
- Hitachi visual direction from `docs/product-spec.md` and `docs/ui-spec.md`.
- Main tab navigation.
- Home summary screen.
- Preventive activity list.
- Preventive activity detail.
- Basic preventive report form mock.
- Report version list mock.
- PDF preview placeholder.
- Share Sheet placeholder/action stub.
- Role-aware actions for Technician, Coordinator, Boss, and Administrator.

### Not Included

- Real backend API calls.
- Real authentication.
- Real database persistence.
- Real PDF generation.
- Real file upload.
- Corrective report flow.
- Asset replacement workflow.
- Stock search workflow.

---

## 3. Primary User Story

As a `Tecnico mantenedor`, I want to open the iPad app, see today's preventive activities, start one activity, fill a basic report mock, finalize a version, and preview/share the generated report placeholder.

---

## 4. App-Visible Labels

App-visible labels must be in Spanish.

Core labels for this slice:

| English Concept | Spanish UI Label |
|-----------------|------------------|
| Home | Inicio |
| Preventive | Preventivos |
| Corrective | Correctivos |
| Assets | Activos |
| Stock | Stock |
| Profile | Perfil |
| Scheduled | Programado |
| In Progress | En progreso |
| Completed | Completado |
| Closed | Cerrado |
| Start | Iniciar |
| Edit Report | Editar reporte |
| Complete | Completar |
| Close | Cerrar |
| Reopen | Reabrir |
| Share PDF | Compartir PDF |
| Report Versions | Versiones del reporte |

---

## 5. Screens

### 5.1 App Shell

Use iPad tab navigation:

1. Inicio
2. Preventivos
3. Correctivos
4. Activos
5. Stock
6. Perfil

Only `Inicio`, `Preventivos`, and `Perfil` need functional mock content in this slice. Other tabs may show simple placeholders with correct labels.

### 5.2 Inicio

Shows:

- greeting with current mock user,
- current role,
- preventive activities due today,
- active corrective count,
- pending closure count,
- quick action to open `Preventivos`.

Primary visual behavior:

- Hitachi red for primary actions and selected tab.
- Neutral background for operational readability.
- Status badges using semantic colors.

### 5.3 Preventivos

Shows grouped list sections:

- Vencidos
- Hoy
- Esta semana
- Completados

Each row shows:

- activity name,
- asset or business anchor asset,
- location,
- subsystem,
- scheduled date,
- status badge,
- latest report version if available.

### 5.4 Detalle Preventivo

Shows:

- activity title,
- status,
- asset(s),
- location,
- subsystem,
- manual reference,
- frequency,
- expected duration,
- required personnel,
- required tools,
- report versions,
- available actions by role and status.

Action matrix:

| Status | Technician | Coordinator | Boss | Administrator |
|--------|------------|-------------|------|---------------|
| Programado | Iniciar | Iniciar | View only | Iniciar |
| En progreso | Editar reporte, Completar | Editar reporte, Completar | View only | Editar reporte, Completar |
| Completado | Editar reporte, Compartir PDF | Editar reporte, Compartir PDF, Cerrar | View only | Editar reporte, Compartir PDF, Cerrar |
| Cerrado | View only | Reabrir | View only | Reabrir |

### 5.5 Formulario Reporte Preventivo

Mock form sections:

1. Datos generales.
2. Personal participante.
3. Herramientas.
4. Pasos del mantenimiento.
5. Pruebas y resultados.
6. Evidencias.
7. Conclusiones.
8. Firmas.

Minimum interactive behavior:

- mark steps as completed,
- enter comments,
- select participants,
- show signature placeholder,
- finalize mock version.

### 5.6 PDF Preview Placeholder

Shows:

- report title,
- activity metadata,
- participant list,
- step summary,
- signature placeholders,
- version number.

The share action should open a placeholder flow in this slice. Real PDF generation and iOS Share Sheet integration come later.

---

## 6. Mock Data Required

Use data from `docs/mock-data.md`.

Minimum records needed:

- `user-diego` as `Tecnico mantenedor`.
- `user-coordinator` as `Coordinador`.
- `user-boss` as `Jefe`.
- `prv-001`.
- `prv-002`.
- `prv-003`.
- `template-ats-sw`.
- `template-frontam-inspection`.
- relevant assets: `Software ATS Patio`, `Frontam Colectora`, `CRK 1`, `CRK 2`.

---

## 7. State Behavior

This slice may keep state in memory only.

Expected mock transitions:

```text
Programado -> En progreso -> Completado -> Cerrado
```

Rules:

- `Iniciar` moves the activity to `En progreso`.
- Finalizing a report creates or updates a mock report version.
- `Completar` moves the activity to `Completado`.
- `Cerrar` is visible only for Coordinator and Administrator.
- `Reabrir` is visible only for Coordinator and Administrator when status is `Cerrado`.
- Boss can navigate and view but cannot mutate state.

---

## 8. Acceptance Criteria

- The app launches directly into the mock tab interface.
- The selected tab uses Hitachi red.
- `Inicio` shows realistic preventive summary data in Spanish.
- `Preventivos` shows grouped activity rows with status badges.
- Tapping a preventive activity opens its detail.
- Starting a scheduled activity updates visible state to `En progreso`.
- Editing the report opens the mock preventive report form.
- Finalizing the form creates a visible report version.
- Completing the activity changes state to `Completado`.
- Coordinator can close and reopen; Boss cannot.
- No screen requires network, backend, database, or real login.

---

## 9. Review Questions for User Testing

Use these questions after the first iPad mock is available:

1. Is the first screen useful for a technician starting the shift?
2. Are the preventive activity statuses clear?
3. Is the activity detail missing any critical field?
4. Is the report form order natural compared with current work?
5. Are the actions by role correct?
6. Does the Hitachi visual direction feel appropriate without distracting from field work?

