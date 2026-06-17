# Mock Data

**Version:** 0.1  
**Status:** Draft  
**Last Updated:** 2026-06-17

---

## 1. Purpose

This document defines representative fake data for the mock-first iPad prototype.

The data should feel realistic enough for maintenance users to validate flows, without depending on the current Power Apps database.

Documentation, technical identifiers, and code-oriented names are written in English.

App-visible data, business values, dropdown options, report content, role labels, statuses, and database seed values must be in Spanish.

---

## 2. Organizational Context

### Site

| ID | Name |
|----|------|
| site-lima | Lima |

### Project

| ID | Site | Name |
|----|------|------|
| project-ml2 | Lima | Metro Lima Line 2 |

### Stage

| ID | Project | Name |
|----|---------|------|
| stage-1a | Metro Lima Line 2 | Stage 1A |

### System

| ID | Name |
|----|------|
| system-signaling | Signaling |

### Subsystems

| ID | Name |
|----|------|
| subsystem-ats | ATS |
| subsystem-cbtc | CBTC |
| subsystem-ixl | IXL |

---

## 3. Users

| ID | Name | Role | Email |
|----|------|------|-------|
| user-diego | Diego Vera | Tecnico mantenedor | diego.vera@example.com |
| user-joab | Joab Apaza | Tecnico mantenedor | joab.apaza@example.com |
| user-fredy | Fredy Navarrete | Tecnico mantenedor | fredy.navarrete@example.com |
| user-coordinator | Coordinador de mantenimiento | Coordinador | coordinator@example.com |
| user-boss | Jefe de mantenimiento | Jefe | boss@example.com |
| user-admin | Administrador del sistema | Administrador | admin@example.com |

---

## 4. Locations

| ID | Level | Name | Parent |
|----|-------|------|--------|
| loc-patio | Area N1 | Patio | - |
| loc-patio-sa | Area N2 | Patio Santa Anita | loc-patio |
| loc-station | Area N1 | Estacion | - |
| loc-colectora | Area N2 | Colectora Industrial (PL22) | loc-station |
| loc-colectora-tech | Area N3 | Area tecnica | loc-colectora |
| loc-room-221 | Area N4 | Sala 2.21 | loc-colectora-tech |
| loc-tunnel | Area N1 | Tunel | - |
| loc-tunnel-hv-co | Area N2 | Tunel Hermilio Valdizan - Colectora | loc-tunnel |
| loc-stock-spv | Almacen | Almacen SPV | - |
| loc-stock-hitachi | Almacen | Almacenamiento Mantto Hitachi | - |

---

## 5. Asset Types

Part number belongs to AssetType.

| ID | Name | Category | Part Number | Subsystem |
|----|------|----------|-------------|-----------|
| type-train | Tren | Equipo mayor | - | CBTC |
| type-cabinet-frontam | Gabinete Frontam | Equipo mayor | FRNT-CAB-001 | CBTC |
| type-server-frontam | Servidor Frontam | Equipo | SRV-FRONTAM-001 | CBTC |
| type-pcsg | Servidor PCSG | Equipo | PCSG-001 | CBTC |
| type-cier | Tarjeta CIER | Componente | CIER-001 | CBTC |
| type-crk-cabinet | Gabinete CRK | Equipo mayor | CRK-CAB-001 | ATS |
| type-ats-server | Servidor ATS | Equipo | ATS-SRV-001 | ATS |
| type-ats-software | Software ATS | Software | - | ATS |
| type-tod | TOD | Equipment | TOD-001 | CBTC |
| type-cdv | Circuito de via | Equipo mayor | CDV-001 | IXL |

---

## 6. Assets

### Top-Level Assets

| ID | Name | Type | Category | Serial/Internal Code | Status | Location |
|----|------|------|----------|----------------------|--------|----------|
| asset-train-14 | Tren 14 | Tren | Equipo mayor | INT-TRAIN-014 | Activo | Movil |
| asset-train-26 | Tren 26 | Tren | Equipo mayor | INT-TRAIN-026 | Activo | Movil |
| asset-frontam-colectora | Frontam Colectora | Gabinete Frontam | Equipo mayor | FRNT-CO-001 | Activo | Sala 2.21 |
| asset-frontam-patio | Frontam Patio | Gabinete Frontam | Equipo mayor | FRNT-PT-001 | Activo | Patio Santa Anita |
| asset-crk-1 | CRK 1 | Gabinete CRK | Equipo mayor | CRK-SN-001 | Activo | Colectora Industrial |
| asset-crk-2 | CRK 2 | Gabinete CRK | Equipo mayor | CRK-SN-002 | Activo | Colectora Industrial |
| asset-cdv-1018 | CBDAC 1018 | Circuito de via | Equipo mayor | CDV-1018 | Activo | Patio Santa Anita |

### Child Assets

| ID | Name | Type | Parent | Position | Serial/Internal Code | Status |
|----|------|------|--------|----------|----------------------|--------|
| asset-frontam-app1 | Servidor Frontam Aplicacion 1 | Servidor Frontam | Frontam Colectora | APP 1 | CZJ5470N75 | Activo |
| asset-frontam-app2 | Servidor Frontam Aplicacion 2 | Servidor Frontam | Frontam Colectora | APP 2 | CZ3909PF9W | Activo |
| asset-pcsg-1 | PCSG 1 | Servidor PCSG | Frontam Colectora | PCSG 1 | PCSG-SN-001 | Activo |
| asset-cier-1 | CIER 1 | Tarjeta CIER | PCSG 1 | Slot CIER 1 | CIER-SN-001 | Activo |
| asset-limsys001 | LIMSYS001 | Servidor ATS | CRK 1 | A | LIMSYS001-SN | Activo |
| asset-limsys002 | LIMSYS002 | Servidor ATS | CRK 1 | B | LIMSYS002-SN | Activo |
| asset-ats-sw-1 | Software ATS | Software ATS | LIMSYS001 | Software | ATS-v3.2.1 | Activo |
| asset-tod-train-26 | TOD Tren 26 M1 | TOD | Tren 26 | Coche M1 | TOD-26-M1 | Activo |

---

## 7. Stock Assets

| ID | Name | Type | Serial/Internal Code | Status | Location |
|----|------|------|----------------------|--------|----------|
| stock-frontam-server-01 | Servidor Frontam repuesto 01 | Servidor Frontam | CZ3909PF9W-SPARE | En stock | Almacen SPV |
| stock-frontam-server-02 | Servidor Frontam repuesto 02 | Servidor Frontam | CZ3909PF9W-SPARE-02 | En stock | Almacenamiento Mantto Hitachi |
| stock-cier-01 | Tarjeta CIER repuesto 01 | Tarjeta CIER | CIER-SPARE-001 | En stock | Almacen SPV |
| stock-pcsg-01 | PCSG repuesto 01 | Servidor PCSG | PCSG-SPARE-001 | En stock | Almacenamiento Mantto Hitachi |

---

## 8. Tools

| ID | Name | Serial | Certification Status |
|----|------|--------|----------------------|
| tool-laptop | Laptop de mantenimiento | LAP-001 | Vigente |
| tool-multimeter | Multimetro digital | DMM-001 | Vigente |
| tool-network-tester | Probador de red | NET-001 | Vigente |
| tool-torque | Torquimetro | TQ-001 | Por vencer |

---

## 9. Preventive Templates

### Template: Mantenimiento preventivo de software ATS

| Field | Value |
|-------|-------|
| ID | template-ats-sw |
| Subsystem | ATS |
| Manual Reference | ML2-AST-GEN-G-000-GRAL-SSATS-GEN-MN-3500-0A |
| Frequency | Revision periodica diaria |
| Required Personnel | 2 |
| Estimated Duration | 60 minutes |

Steps:

| Step | Name | Manual Page | Tests |
|------|------|-------------|-------|
| 1 | Revision de archivos de registro del sistema | 12 | Estado de archivos de registro |
| 2 | Verificacion de herramienta de estado del nodo | 15 | Estado de nodo |
| 3 | Verificacion del uso de memoria | 18 | Nivel de memoria |

### Template: Inspeccion de gabinete Frontam

| Field | Value |
|-------|-------|
| ID | template-frontam-inspection |
| Subsystem | CBTC |
| Manual Reference | ML2-CBTC-FRONTAM-MN-001 |
| Frequency | Mensual |
| Required Personnel | 2 |
| Estimated Duration | 90 minutes |

Steps:

| Step | Name | Manual Page | Tests |
|------|------|-------------|-------|
| 1 | Inspeccion visual del gabinete | 8 | Condicion del gabinete |
| 2 | Verificacion de ventiladores | 11 | Estado de ventiladores |
| 3 | Verificacion de servidores | 14 | Estado de servidores |

---

## 10. Preventive Activities

| ID | Name | Template | Asset(s) | Location | Scheduled Date | Status |
|----|------|----------|----------|----------|----------------|--------|
| prv-001 | Mantenimiento preventivo de software ATS - ECIN | Mantenimiento preventivo de software ATS | LIMSYS001, LIMSYS002 | Sala 2.21 | 2026-06-17 | Programado |
| prv-002 | Inspeccion de gabinete Frontam - Colectora | Inspeccion de gabinete Frontam | Frontam Colectora | Sala 2.21 | 2026-06-17 | En progreso |
| prv-003 | Inspeccion de CRK 1 y CRK 2 | Inspeccion de gabinete Frontam | CRK 1, CRK 2 | Colectora Industrial | 2026-06-18 | Programado |
| prv-004 | Calibracion de circuito de via CBDAC 1018 | Calibracion de circuito de via | CBDAC 1018 | Patio Santa Anita | 2026-06-16 | Completado |

---

## 11. Corrective Events

| ID | Code | SAP Code | Name | Asset | Subsystem | Severity | Status |
|----|------|----------|------|-------|-----------|----------|--------|
| cor-001 | COR-2026-001 | 110010514 | E22 Falla de servidor Frontam | Frontam Colectora | CBTC | Alta | En progreso |
| cor-002 | COR-2026-002 | 110013642 | Frontam sin redundancia | Frontam Patio | CBTC | Media | Completado |
| cor-003 | COR-2026-003 | - | Pantalla TOD intermitente | TOD Tren 26 M1 | CBTC | Baja | Programado |

### Corrective Event Timeline Example

For `cor-001`:

| Time | Event |
|------|-------|
| 2026-06-17 07:42 | Evento creado por Diego Vera |
| 2026-06-17 08:05 | Mantenimiento iniciado |
| 2026-06-17 09:10 | Version 1 del reporte finalizada |
| 2026-06-17 09:12 | Marcador Stop Here agregado despues del bloque de actividades |

---

## 12. Corrective Activity Types

| ID | Name | Dynamic Fields |
|----|------|----------------|
| act-inspection | Inspeccion / Levantamiento de data | Descripcion, evidencia |
| act-replacement | Cambio de componente | Activo retirado, activo instalado, origen, destino, motivo |
| act-cleaning | Limpieza | Descripcion |
| act-adjustment | Ajuste | Descripcion, medicion si aplica |
| act-measurement | Medicion | Valores medidos, unidades |
| act-software | Accion de software | Nombre de software, version, accion |
| act-testing | Investigacion / Pruebas | Descripcion de prueba, resultado |
| act-other | Otro | Texto libre |

---

## 13. Corrective Report Mock Example

| Field | Value |
|-------|-------|
| Event | COR-2026-001 |
| Shift | Day |
| Version | 1 |
| Affected Asset | Frontam Colectora |
| Failure Type | Hardware |
| Operational Impact | Degradacion de servicio |
| Conclusion | Servidor de aplicacion restaurado parcialmente. Se requiere continuacion en el siguiente turno. |
| Stop Here | Despues de actividades realizadas |

Activities:

| Order | Type | Description |
|-------|------|-------------|
| 1 | Inspeccion / Levantamiento de data | Se verifico el gabinete Frontam y se confirmo falla de servidor. |
| 2 | Cambio de componente | Se reemplazo el Servidor Frontam Aplicacion 1. |

Replacement:

| Field | Value |
|-------|-------|
| Removed Asset | Servidor Frontam Aplicacion 1 / CZJ5470N75 |
| Installed Asset | Servidor Frontam repuesto 01 / CZ3909PF9W-SPARE |
| Source | Almacen SPV |
| Destination | Almacenamiento Mantto Hitachi |
| Reason | Falla de hardware |

Participants:

- Diego Vera
- Joab Apaza

---

## 14. Report Versions

| Report ID | Activity/Event | Version | Created By | Created At | PDF |
|-----------|----------------|---------|------------|------------|-----|
| rpt-prv-002-v1 | prv-002 | 1 | Joab Apaza | 2026-06-17 10:15 | Available |
| rpt-prv-002-v2 | prv-002 | 2 | Joab Apaza | 2026-06-17 10:42 | Available |
| rpt-cor-001-v1 | cor-001 | 1 | Diego Vera | 2026-06-17 09:10 | Available |

---

## 15. Boss Dashboard Mock Metrics

| Metric | Value |
|--------|-------|
| Preventive completed this month | 18 |
| Preventive pending today | 2 |
| Corrective events open | 1 |
| Corrective events completed pending closure | 1 |
| Actividades cerradas esta semana | 7 |
| Asset replacements this month | 3 |

---

## 16. Mock Data Notes

- All IDs are fake and stable for prototyping.
- Names are realistic but should not be treated as production seed data.
- The current Power Apps tables are reference only and should not drive the new model directly.
- The mock should include enough hierarchy depth to validate asset navigation.
