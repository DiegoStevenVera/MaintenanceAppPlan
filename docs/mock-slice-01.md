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
- Share Sheet mock using native iOS sharing.
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

As a `Ingeniero de Mantenimiento`, I want to open the iPad app, see today's preventive activities, start one activity, fill a basic report mock, finalize a version, and preview/share the generated report placeholder.

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
| Completado | Reabrir, Compartir PDF | Reabrir, Compartir PDF, Cerrar | View only | Reabrir, Compartir PDF, Cerrar |
| Cerrado | View only | Reabrir | View only | Reabrir |

### 5.5 Formulario Reporte Preventivo

Mock form sections:

1. Datos generales.
2. Herramientas.
3. Pasos del mantenimiento con pruebas/resultados por paso.
4. Evidencias.
5. Participantes y firmas.
6. Conclusiones.

Minimum interactive behavior:

- mark steps as completed,
- enter comments,
- select active-day participants checked by default,
- capture/show drawable signature per participant,
- select test results from dropdowns within each step,
- select conclusion from the controlled list using the label `Estado final del equipo`,
- enter `Comentarios adicionales del mantenimiento`,
- finalize mock version.

Detalle preventivo:

- El bloque `Acciones` aparece despues de la imagen referencial del equipo y antes de datos generales.
- El mantenimiento preventivo ATS usa una imagen referencial de gabinete/rack en el mock para validar como se muestran fotografias reales del equipo.
- Los botones de accion usan grilla adaptable con icono y ancho completo disponible.
- `Reportes anteriores` lista historicos del mismo equipo grande y cada item navega a la vista previa PDF historica.
- La pantalla de `Preventivos` incluye filtros tipo botonera: `Hoy`, `Esta semana`, `Este Mes` y `Mes especifico` con selector de mes/anio.
- Los filtros de `Preventivos` actuan sobre la fecha de programacion del mantenimiento e incluyen busqueda por nombre de mantenimiento.
- La pantalla de `Correctivos` reutiliza la misma seccion de filtros, pero la fecha es opcional: sin filtro activo muestra correctivos abiertos, en progreso, completados y cerrados; con filtro activo usa la fecha de creacion de aviso.
- La pantalla de `Equipos` mantiene solo `Mantenimientos realizados`, con reportes/versiones ya generados que abren vista previa PDF.

Firmas:

- Preventivos y correctivos usan el mismo componente visual de `Participantes y firmas`.
- El boton de firma y la previsualizacion de firma aparecen en una misma fila.
- La firma capturada se escala para verse completa en la previsualizacion y en el PDF mock.

### 5.6 PDF Preview Placeholder

Shows:

- report title,
- activity metadata,
- participant list,
- step summary,
- participant signatures,
- version number.

The share action opens the native iOS Share Sheet in the SwiftUI mock using temporary share text. The real app should share the generated PDF artifact.

---

## 6. Mock Data Required

Use data from `docs/mock-data.md`.

Minimum records needed:

- `user-diego` as `Ingeniero de Mantenimiento`.
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
- `Reabrir` from `Completado` is visible for Technician, Coordinator, and Administrator and moves the maintenance back to `En progreso`.
- `Reabrir` from `Cerrado` is visible only for Coordinator and Administrator and moves the maintenance back to `En progreso`.
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
- The mock starts with a local login screen. It does not require network, backend, database, or real authentication.
- Test users use `123456` as temporary password while validating flows.

---

## 9. Review Questions for User Testing

Use these questions after the first iPad mock is available:

1. Is the first screen useful for a technician starting the shift?
2. Are the preventive activity statuses clear?
3. Is the activity detail missing any critical field?
4. Is the report form order natural compared with current work?
5. Are the actions by role correct?
6. Does the Hitachi visual direction feel appropriate without distracting from field work?
