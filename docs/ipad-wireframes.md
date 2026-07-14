# iPad Wireframes

**Version:** 0.1  
**Status:** Draft  
**Last Updated:** 2026-06-17

---

## 1. Purpose

This document defines functional iPad wireframes for the mock-first prototype.

Documentation is written in English. App-visible labels and data are written in Spanish.

These wireframes are not final visual design. They describe:

- screen layout,
- visible sections,
- primary actions,
- state-dependent behavior,
- role-dependent behavior.

---

## 2. Global Layout

### 2.1 iPad Shell

```
┌────────────────────────────────────────────────────────────┐
│ Top Bar: Logo / Project Context / User / Role              │
├────────────────────────────────────────────────────────────┤
│                                                            │
│ Main Content Area                                          │
│                                                            │
├────────────────────────────────────────────────────────────┤
│ Tab Bar: Inicio | Preventivos | Correctivos | Activos      │
│          Stock | Perfil                                    │
└────────────────────────────────────────────────────────────┘
```

### 2.2 Top Bar

Visible items:

- App name or logo placeholder.
- Context: `Metro Lima Linea 2 · Etapa 1A · Senalizacion`.
- User name.
- Role label: `Ingeniero de Mantenimiento`, `Coordinador`, `Jefe`, `Administrador`.

### 2.3 Tab Bar Labels

| Tab | App Label |
|-----|-----------|
| Home | Inicio |
| Preventive | Preventivos |
| Corrective | Correctivos |
| Assets | Activos |
| Stock | Stock |
| Profile | Perfil |

---

## 3. Home

### 3.1 Layout

```
┌────────────────────────────────────────────────────────────┐
│ Inicio                                                     │
│ Hola, Diego Vera                                           │
│ Rol: Ingeniero de Mantenimiento                                    │
├────────────────────────────────────────────────────────────┤
│ [Preventivos de hoy] [Correctivos activos]                 │
│ [Pendientes de cierre] [Buscar activo]                     │
├────────────────────────────────────────────────────────────┤
│ Actividades para hoy                                       │
│ - Mantenimiento preventivo de software ATS - ECIN          │
│ - Inspeccion de gabinete Frontam - Colectora               │
├────────────────────────────────────────────────────────────┤
│ Correctivos abiertos / en progreso                         │
│ - E22 Falla de servidor Frontam                            │
└────────────────────────────────────────────────────────────┘
```

### 3.2 Cards

| Card Label | Content | Tap Target |
|------------|---------|------------|
| Preventivos de hoy | Count and first activities | Preventive list filtered to today |
| Correctivos activos | Count and active events | Corrective list filtered to open/in progress |
| Pendientes de cierre | Completed activities awaiting closure | Coordinator review list |
| Buscar activo | Search shortcut | Asset search |

### 3.3 Role Behavior

| Role | Behavior |
|------|----------|
| Technician | Sees own/current-scope operational work |
| Coordinator | Also sees pending closure |
| Boss | Sees metrics and read-only summaries |
| Administrator | Sees all data and admin shortcuts |

---

## 4. Preventive List

### 4.1 Layout

```
┌────────────────────────────────────────────────────────────┐
│ Preventivos                                  [Filtro]      │
├────────────────────────────────────────────────────────────┤
│ Filtros: Hoy | Esta semana | Este Mes | Mes/año + buscar   │
├────────────────────────────────────────────────────────────┤
│ Hoy                                                        │
│ ┌────────────────────────────────────────────────────────┐ │
│ │ Mantenimiento preventivo de software ATS - ECIN        │ │
│ │ LIMSYS001, LIMSYS002 · ATS · Sala 2.21                 │ │
│ │ Programado · 17/06/2026                                │ │
│ └────────────────────────────────────────────────────────┘ │
│ ┌────────────────────────────────────────────────────────┐ │
│ │ Inspeccion de gabinete Frontam - Colectora             │ │
│ │ Frontam Colectora · CBTC · Sala 2.21                   │ │
│ │ En progreso · Version 1 disponible                     │ │
│ └────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────┘
```

### 4.2 Row Content

- Activity name.
- Asset summary.
- Subsystem.
- Location.
- Date.
- Status badge.
- Latest report version if available.

### 4.3 Filters

App-visible labels:

- `Vencidos`
- `Hoy`
- `Semana`
- `Mes`
- `Cerrados`

---

## 5. Preventive Detail

### 5.1 Layout

```
┌────────────────────────────────────────────────────────────┐
│ Inspeccion de gabinete Frontam - Colectora                 │
│ Estado: En progreso                                        │
├────────────────────────────────────────────────────────────┤
│ Imagen referencial del equipo grande                       │
├────────────────────────────────────────────────────────────┤
│ Acciones                                                   │
│ [icon Generar/Editar reporte] [icon Completar] [icon PDF]  │
│ Botonera en grilla, botones anchos, centrados y full width │
├────────────────────────────────────────────────────────────┤
│ Activo: Frontam Colectora                                  │
│ Subsistema: CBTC                                           │
│ Ubicacion: Sala 2.21                                       │
│ Manual: ML2-CBTC-FRONTAM-MN-001             [Abrir PDF]    │
├────────────────────────────────────────────────────────────┤
│ Versiones de reporte                                       │
│ - Version 2 · 17/06/2026 10:42 · PDF disponible            │
│ - Version 1 · 17/06/2026 10:15 · PDF disponible            │
├────────────────────────────────────────────────────────────┤
│ Reportes anteriores                                        │
│ - Historico del equipo grande -> abre vista previa PDF     │
├────────────────────────────────────────────────────────────┤
│ Notas de mantenedores                                      │
│ - Revisar ventiladores antes de iniciar limpieza.          │
└────────────────────────────────────────────────────────────┘
```

### 5.2 Actions by Status

| Status | Technician | Coordinator | Boss |
|--------|------------|-------------|------|
| Programado | Iniciar | Iniciar | Ver |
| En progreso | Generar/Editar reporte, Completar | Generar/Editar reporte, Completar | Ver |
| Completado | Reabrir, Compartir PDF | Reabrir, Compartir PDF, Cerrar | Ver |
| Cerrado | Ver | Reabrir | Ver |

---

## 6. Preventive Report Form

### 6.1 Layout

```
┌────────────────────────────────────────────────────────────┐
│ Reporte preventivo                                         │
│ Actividad: Inspeccion de gabinete Frontam - Colectora      │
├────────────────────────────────────────────────────────────┤
│ Datos generales                                            │
│ Fecha, hora inicio, hora fin, orden SAP, orden trabajo      │
├────────────────────────────────────────────────────────────┤
│ Herramientas                                               │
│ [Agregar herramienta]                                      │
├────────────────────────────────────────────────────────────┤
│ Pasos del procedimiento                                    │
│ [✓] Inspeccion visual del gabinete       [Manual] [Pruebas]│
│ [✓] Verificacion de ventiladores         [Manual] [Pruebas]│
│ [ ] Verificacion de servidores           [Manual] [Pruebas]│
├────────────────────────────────────────────────────────────┤
│ Fotos / Anexos                                             │
│ [+ Agregar foto]                                           │
├────────────────────────────────────────────────────────────┤
│ Participantes y firmas                                     │
│ Participante activo [Dibujar firma] [Preview firma]        │
├────────────────────────────────────────────────────────────┤
│ Conclusiones / Comentarios                                 │
│ Estado final del equipo: [dropdown ancho]                  │
│ Comentarios adicionales del mantenimiento: [texto]         │
├────────────────────────────────────────────────────────────┤
│ [Guardar borrador] [Finalizar reporte]                     │
└────────────────────────────────────────────────────────────┘
```

### 6.2 Task Row Behavior

Each task row has:

- completion checkbox,
- manual PDF button,
- tests popup button,
- optional comment field.

### 6.3 Finalize Behavior

When user taps `Finalizar reporte`:

1. Validate required fields.
2. Validate participant signatures.
3. Create new report version.
4. Generate PDF placeholder.
5. Return to Preventive Detail.

---

## 7. Corrective List

### 7.1 Layout

```
┌────────────────────────────────────────────────────────────┐
│ Correctivos                                      [+]        │
├────────────────────────────────────────────────────────────┤
│ Filtros opcionales: Hoy | Esta semana | Este Mes | Mes/año  │
│ Buscar por evento, SAP o equipo                            │
├────────────────────────────────────────────────────────────┤
│ Segments: Abiertos | En progreso | Completados | Cerrados  │
├────────────────────────────────────────────────────────────┤
│ En progreso                                               │
│ ┌────────────────────────────────────────────────────────┐ │
│ │ E22 Falla de servidor Frontam                          │ │
│ │ COR-2026-001 · SAP 110010514 · CBTC                    │ │
│ │ Frontam Colectora · Alta · En progreso                 │ │
│ └────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────┘
```

### 7.2 Create Button

Visible to:

- Technician,
- Coordinator,
- Administrator.

Hidden/read-only for:

- Boss.

### 7.3 Create Corrective Event

The `+` opens a large iPad sheet with a focused creation flow.

```
┌────────────────────────────────────────────────────────────┐
│ Nuevo correctivo                                           │
├────────────────────────────────────────────────────────────┤
│ Datos del contexto                                         │
│ Sede, Proyecto, Etapa, Sistema (read-only)                 │
│ Subsistema [ATS | CBTC | IXL]                              │
│ Severidad [Baja | Media | Alta]                            │
│ Ubicacion fisica del asset (from selected equipment)       │
├────────────────────────────────────────────────────────────┤
│ Equipo afectado                                            │
│ [Buscar equipo grande]                                     │
│ Lista filtrada por subsistema                              │
│ ▾ Equipo grande                                            │
│   ▾ Gabinete / conjunto principal                          │
│     ▾ Modulo interno                                       │
│       ( ) Fuente de poder                                  │
│       (✓) Tarjeta de comunicacion                          │
├────────────────────────────────────────────────────────────┤
│ Nombre del evento SAP [editable]                           │
│ Notificacion SAP [editable]                                │
│ Fecha y hora de creacion de aviso [editable]               │
│ Fecha y hora de respuesta [read-only default now]          │
├────────────────────────────────────────────────────────────┤
│ [Crear Correctivo]                                         │
└────────────────────────────────────────────────────────────┘
```

---

## 8. Corrective Event Detail

### 8.1 Layout

```
┌────────────────────────────────────────────────────────────┐
│ E22 Falla de servidor Frontam                              │
│ Estado: En progreso · Severidad: Alta                      │
├────────────────────────────────────────────────────────────┤
│ Acciones                                                   │
│ [Crear/Editar reporte] [Completar] [Compartir PDF]         │
├────────────────────────────────────────────────────────────┤
│ SAP: 110010514                                             │
│ Activo: Frontam Colectora                                  │
│ Ubicacion: Estacion Colectora > Sala tecnica > Sala 2.21   │
│ Subsistema: CBTC                                           │
├────────────────────────────────────────────────────────────┤
│ Timeline                                                   │
│ 07:42 Evento creado por Diego Vera                         │
│ 08:05 Mantenimiento iniciado                               │
│ 09:10 Version 1 del reporte finalizada                     │
│ 09:12 Stop Here despues de actividades                     │
├────────────────────────────────────────────────────────────┤
│ Versiones de reporte                                       │
│ - Version 1 · Diego Vera · PDF disponible                  │
└────────────────────────────────────────────────────────────┘
```

### 8.2 Actions by Status

| Status | Technician | Coordinator | Boss |
|--------|------------|-------------|------|
| Programado/Abierto | Iniciar | Iniciar | Ver |
| En progreso | Crear/Editar reporte, Completar | Crear/Editar reporte, Completar | Ver |
| Completado | Reabrir, Compartir PDF | Reabrir, Compartir PDF, Cerrar | Ver |
| Cerrado | Ver | Reabrir | Ver |

---

## 9. Corrective Dynamic Report Form

### 9.1 Layout

```
┌────────────────────────────────────────────────────────────┐
│ Reporte correctivo                                         │
│ Evento: E22 Falla de servidor Frontam                      │
├────────────────────────────────────────────────────────────┤
│ Datos del evento                                           │
│ SAP, fecha ocurrencia, hora ocurrencia, subsistema          │
├────────────────────────────────────────────────────────────┤
│ Activo y ubicacion                                         │
│ Frontam Colectora · Estacion Colectora > Sala tecnica      │
├────────────────────────────────────────────────────────────┤
│ Descripcion de falla e impacto                             │
│ Sintoma, descripcion tecnica, impacto operacional           │
├────────────────────────────────────────────────────────────┤
│ Actividades realizadas                         [+ Agregar] │
│ 1. Inspeccion / Levantamiento de data                      │
│ 2. Cambio de componente                                    │
├────────────────────────────────────────────────────────────┤
│ Pruebas y validacion                                       │
├────────────────────────────────────────────────────────────┤
│ Fotos / Anexos                                             │
├────────────────────────────────────────────────────────────┤
│ Conclusiones / Comentarios                                 │
├────────────────────────────────────────────────────────────┤
│ Participantes / Firmas                                     │
├────────────────────────────────────────────────────────────┤
│ [Guardar borrador] [Stop Here] [Finalizar version]          │
└────────────────────────────────────────────────────────────┘
```

### 9.2 Activity Block

When adding an activity:

```
Tipo de actividad: [Cambio de componente v]
Hora inicio:
Descripcion:
Hora fin:
```

### 9.3 Replacement Sub-Block

Appears only for `Cambio de componente`.

```
Activo padre: Frontam Colectora
Activo retirado: ruta completa desde equipo grande hasta hoja
Part number, serial, modelo, fabricante autocompletables
Estado del componente y destino de envio
Origen: Almacen SPV / Almacenamiento Mantto Hitachi
[Seleccionar de stock] -> sheet con buscador y lista filtrada
Activo instalado: datos autocompletados del stock seleccionado
```

---

## 10. Asset Search

### 10.1 Layout

```
┌────────────────────────────────────────────────────────────┐
│ Activos                                                    │
│ [Buscar por nombre, serie, codigo interno o part number]   │
├────────────────────────────────────────────────────────────┤
│ Resultados                                                 │
│ ┌────────────────────────────────────────────────────────┐ │
│ │ Frontam Colectora                                      │ │
│ │ Gabinete Frontam · FRNT-CO-001 · Activo                │ │
│ │ Colectora Industrial > Area tecnica > Sala 2.21        │ │
│ └────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────┘
```

### 10.2 Asset Detail

Shows:

- name,
- category,
- type,
- serial/internal code,
- part number,
- status,
- current location,
- parent,
- children,
- maintenance history split into Preventivos and Correctivos,
- replacement history.

---

## 11. Stock Selection

### 11.1 Layout

```
┌────────────────────────────────────────────────────────────┐
│ Seleccionar activo de stock                                │
│ [Buscar por serie, tipo o part number]                     │
├────────────────────────────────────────────────────────────┤
│ Filtros: Subsistema | Tipo | Ubicacion                     │
├────────────────────────────────────────────────────────────┤
│ ┌────────────────────────────────────────────────────────┐ │
│ │ Servidor Frontam repuesto 01                           │ │
│ │ CZ3909PF9W-SPARE · En stock · Almacen SPV              │ │
│ │ [Seleccionar]                                          │ │
│ └────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────┘
```

---

## 12. Signature Pad

### 12.1 Layout

```
┌────────────────────────────────────────────────────────────┐
│ Firma de participante                                      │
│ Participante: Diego Vera                                   │
├────────────────────────────────────────────────────────────┤
│                                                            │
│                  [Canvas de firma]                         │
│                                                            │
├────────────────────────────────────────────────────────────┤
│ [Limpiar] [Cancelar] [Confirmar firma]                     │
└────────────────────────────────────────────────────────────┘
```

### 12.2 Behavior

- User selects participant before opening the pad.
- Signature is linked to the selected participant.
- The mock can show a signature placeholder.

---

## 13. PDF Preview / Share

### 13.1 Layout

```
┌────────────────────────────────────────────────────────────┐
│ PDF del reporte                                            │
│ Version 2 · Generado el 17/06/2026 10:42                   │
├────────────────────────────────────────────────────────────┤
│ [Vista previa PDF]                                         │
├────────────────────────────────────────────────────────────┤
│ [Compartir PDF] [Cerrar]                                   │
└────────────────────────────────────────────────────────────┘
```

### 13.2 Share Sheet Mock

For design-only mock:

```
┌──────────────────────────────────────┐
│ Compartir con...                     │
│ Mail / Outlook / Teams / Archivos    │
└──────────────────────────────────────┘
```

In SwiftUI prototype, this uses the native iOS Share Sheet with temporary share content. In v1, the shared item should be the generated PDF artifact.
