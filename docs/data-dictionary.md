# Diccionario de datos

**Base:** PostgreSQL normalizada de MaintenanceApp  
**Estado:** vigente con Alembic `20260730_0010`  
**Tablas de negocio actuales:** 78, más `alembic_version`

Este documento describe el modelo que debe considerarse fuente de verdad para la
API y la aplicación iOS. Las tablas `tbl_*` no viven en PostgreSQL: son nombres
de hojas/tablas de los archivos Excel históricos. La columna **Origen** indica de
qué hoja provienen los datos cuando existe una equivalencia; `APP` significa que
la tabla nació en la aplicación, `DERIVED` que se calculó a partir de otras
tablas y `PCON` que pertenece al módulo nativo de planificación.

## Reglas para leer el modelo

- `assets` contiene tanto equipos grandes como componentes. Un equipo grande se
  identifica con `is_business_anchor = true`; no existe una tabla separada para
  equipos grandes.
- `asset_closure` permite consultar todos los descendientes de un equipo grande.
  `depth = 0` es el propio equipo, `depth = 1` es un hijo directo, y así
  sucesivamente.
- `asset_assignments` representa la instalación temporal y el padre/slot actual.
  `slot_locations` es la ubicación lógica del slot, no un activo.
- `maintenance_templates` define qué se hace; `maintenance_template_scopes`
  define sobre qué equipo y ubicación aplica; `maintenance_plan_entries` define
  cuántas ocurrencias existen en un mes; `maintenance_activities` registra la
  ejecución concreta.
- En `maintenance_plan_entries`, `year` y `month` significan planificación
  mensual. No significan que exista una fecha exacta. Esa fecha vive en
  `maintenance_activities.scheduled_start_at` y `scheduled_end_at`.
- `actual_start_at` y `actual_end_at` indican la ejecución real. `status` no debe
  sustituir estas fechas para análisis históricos.
- Las tablas con `legacy_id` conservan el identificador proveniente del Excel.
  La relación completa entre origen y destino está en
  `legacy_record_mappings`.
- Las tablas operativas tienen `id`, `created_at` y `updated_at`. Esos campos se
  omiten en las listas de campos clave para que el diccionario sea legible.

## Contexto organizacional

| Tabla | Contenido y campos clave | Origen |
|---|---|---|
| `sites` | Sedes: `name`, `description` | `tbl_Proyect` / catálogo normalizado |
| `projects` | Proyectos ligados a sede: `site_id`, `name` | `tbl_Proyect` |
| `stages` | Etapas del proyecto: `project_id`, `name`, fechas y `operational_status` | `tbl_Stage` |
| `systems` | Sistemas del proyecto: `project_id`, `name` | `tbl_Proyect` |
| `subsystems` | Subsistemas: `system_id`, `code`, `name` | `tbl_Subsystem` |
| `work_areas` | Áreas laborales y de autorización: `name`, `description` | `tbl_Work_Area` |
| `geographic_locations` | Árbol de ubicación física: `parent_location_id`, `level`, `full_path` | `tbl_Area` |
| `location_types` | Tipos de ubicación física: `code`, `name` | `tbl_Location_Type` |
| `asset_stage_assignments` | Relación temporal equipo-etapa: `asset_id`, `stage_id`, vigencia y `role` | `tbl_Equipment` / `tbl_Stage` |
| `location_stage_assignments` | Relación ubicación-etapa con vigencia | `tbl_Area` / `tbl_Stage` |

`stages` describe dónde está el proyecto en su estructura contractual. Una
ubicación como patio, estación, sala o cuarto debe consultarse en
`geographic_locations`; no se debe usar `stages.name` como ubicación física.

## Identidad y acceso

| Tabla | Contenido y campos clave | Origen |
|---|---|---|
| `users` | Usuarios, correo, rol, área laboral, estado y hash de contraseña: `email`, `role`, `work_area_id`, `is_active` | `tbl_Worker` |
| `auth_refresh_sessions` | Sesiones de refresh token rotables: `user_id`, `token_hash`, expiración y revocación | `APP` |

La contraseña nunca se consulta en claro. El valor de prueba `123456` se valida
contra `password_hash` durante autenticación; no se almacena como texto.

## Catálogo de activos y composición

| Tabla | Contenido y campos clave | Origen |
|---|---|---|
| `assets` | Equipos, componentes, tarjetas, racks, cableado y demás activos: `name`, `subsystem`, `is_business_anchor`, `parent_id`, `serial_number`, `internal_code`, `part_number`, `model`, fabricante, ubicación y estado | `tbl_Equipment` + `tbl_Component` |
| `asset_history` | Histórico resumido por activo: reporte, título, fecha y resultado | `DERIVED` / histórico legacy |
| `asset_types` | Tipo técnico y políticas de serial/part number | `tbl_ComponentType` |
| `asset_statuses` | Catálogo de estados de activo | `tbl_ComponentStatus` |
| `equipment_categories` | Categoría de equipo por subsistema, con nombres N1/N2 | `tbl_Equipment_Category` |
| `equipment_kinds` | Tipo de equipo o clase técnica | `tbl_EquipmentKind` |
| `equipment_kind_categories` | Relación entre tipo y categoría | `DERIVED` de `tbl_EquipmentKind` / `tbl_Equipment_Category` |
| `manufacturers` | Fabricantes de activos y componentes | `tbl_Manufacturer` |
| `slot_types` | Tipos de slot o posición dentro de una clase de equipo | `tbl_TypeSlot` |
| `slot_locations` | Árbol de posiciones físicas/lógicas disponibles dentro de un equipo | `tbl_SlotLocation` |
| `slot_images` | Imágenes de referencia de slots | `tbl_SlotImage` |
| `asset_assignments` | Instalación, padre directo, slot, posición y vigencia | `tbl_InstalledComponent` |
| `asset_closure` | Cierre transitivo de ancestros y descendientes: `ancestor_asset_id`, `descendant_asset_id`, `depth` | `DERIVED` |
| `asset_composition_rules` | Reglas permitidas de composición padre-hijo por subsistema | `DERIVED` / catálogo técnico |
| `asset_composition_positions` | Posiciones permitidas dentro de una regla de composición | `DERIVED` / catálogo técnico |
| `inventory_locations` | Almacenes y ubicaciones de inventario: `name`, tipo y activo relacionado | `tbl_Location` |
| `movement_types` | Tipos de movimiento: instalado, retirado, ingreso, reparación, intercambio | `tbl_MovementType` |
| `asset_movements` | Movimientos de activos entre almacenes, slots y estados | `tbl_ComponentMovement` |
| `asset_replacements` | Par retirado/instalado durante un cambio: origen, destino, slot, estados y responsable | `tbl_WorkOrderComponent` |
| `documentation_resources` | Manuales, documentos e imágenes asociadas a una operación | `tbl_Documentation` |

Para rastrear un equipo grande se usa `assets.is_business_anchor = true`. Para
obtener su árbol se une `assets` con `asset_closure`; no se debe interpretar el
texto de `children` como fuente de verdad.

## Definiciones preventivas y PCON

| Tabla | Contenido y campos clave | Origen |
|---|---|---|
| `maintenance_templates` | Definición reutilizable del mantenimiento, código de reporte, manual, frecuencia, duración y personal requerido | `tbl_Activity` |
| `maintenance_template_scopes` | Aplicabilidad de una definición a equipo grande, categoría y ubicación | `tbl_Equipment_Activity_Area` |
| `maintenance_template_steps` | Pasos ordenados del procedimiento y referencia de manual | `tbl_Activity_Task` |
| `maintenance_template_tests` | Pruebas de cada paso, tipo, rango, unidad y secuencia | `tbl_Test_Task` |
| `maintenance_template_test_options` | Valores permitidos para un resultado desplegable | `tbl_Test_Result` |
| `maintenance_template_conclusions` | Conclusiones técnicas disponibles para un mantenimiento | `tbl_Conclusion` |
| `maintenance_template_personnel` | Personal genérico requerido por definición: rol, cantidad y horas | `tbl_Personal_Activity` |
| `maintenance_template_tools` | Herramientas requeridas por definición | `tbl_Tools_Activity` |
| `maintenance_action_types` | Catálogo de tipos de actividad correctiva | `tbl_TypeActivity` |
| `maintenance_plan_entries` | Una ocurrencia mensual por equipo-mantenimiento: `year`, `month`, `planning_status`, horas y trabajadores requeridos | `tbl_Scheduled_Activities` + PCON nativo |
| `pcon_annual_plans` | Cabecera de plan anual, estado y año copiado | `PCON` |
| `pcon_annual_plan_scopes` | Filas que pertenecen a un plan anual aunque tengan cantidad cero | `PCON` |
| `pcon_plan_changes` | Auditoría de copias, altas, cambios de cantidad, movimientos, retiros y cancelaciones | `PCON` |
| `preventive_schedules` | Puente transitorio compatible con el frontend actual | `tbl_Scheduled_Activities` |
| `weekly_planning_sessions` | Bloque de reunión semanal: semana, versión, estado y confirmadores | `PCON` |
| `maintenance_schedule_revisions` | Propuestas, confirmaciones y reemplazos de fecha/rango horario | `PCON` |

Estados PCON importantes:

- `MONTH_ONLY`: se conoce el mes, todavía no la fecha exacta.
- `PROPOSED`: existe una propuesta en una reunión semanal.
- `CONFIRMED`: la fecha fue confirmada en bloque.
- `EXECUTED`: la actividad ya tiene ejecución finalizada.
- `CANCELLED` en `maintenance_plan_entries`: la ocurrencia queda auditada y no
  participa en los conteos activos.

## Ejecución de mantenimientos

| Tabla | Contenido y campos clave | Origen |
|---|---|---|
| `maintenance_activities` | Actividad preventiva/correctiva concreta, ciclo de vida, fechas planificadas y reales, proyecto, etapa, subsistema y ubicación | `Maintenance_Storage` + `tbl_Scheduled_Activities` |
| `maintenance_activity_assets` | Activos afectados por una actividad, con `role` e inclusión de descendientes | `Maintenance_Storage` / detalle correctivo |
| `maintenance_activity_assignments` | Asignaciones de usuarios a una actividad y rol de asignación | `tbl_Workers_Activity` |
| `maintenance_status_history` | Historial de cambios de estado y motivo | `APP` / ciclo de vida |
| `maintenance_reopen_records` | Auditoría de reaperturas por coordinador/administrador | `APP` |
| `report_audit_events` | Bitácora interna inmutable de creación/finalización de versiones y cierre/reapertura del mantenimiento, con fecha, actor y motivo cuando aplica | `APP` |
| `corrective_events` | Aviso correctivo, SAP, severidad, activo afectado, ubicación, estado y respuesta | `tbl_WorkMaintenanceCorrective` + `tbl_CorrectiveReports_Detail` |
| `corrective_event_comments` | Comentarios propios de una incidencia correctiva | `APP` / interfaz actual |
| `maintenance_knowledge_comments` | Comentarios reutilizables para futuras ejecuciones preventivas por plantilla o equipo | `APP` / interfaz actual |
| `preventive_schedules` | Vista operacional heredada de planificación, fechas exactas y contador de versiones | `tbl_Scheduled_Activities` |

## Reportes, versiones y evidencias

| Tabla | Contenido y campos clave | Origen |
|---|---|---|
| `maintenance_reports` | Reporte lógico por actividad y tipo, número anual correctivo y estado | `Maintenance_Storage` / reportes legacy |
| `report_versions` | Versiones editables/finalizadas, snapshot JSON, creador y fecha de finalización | `Maintenance_Storage` / `tbl_Reports` |
| `report_formats` | Formatos oficiales versionados por tipo de reporte: código, revisión, HTML activo y vigencia lógica | `APP` / control documental |
| `report_version_assets` | Snapshot inmutable de activos que aparecieron en una versión | `DERIVED` |
| `report_participants` | Participantes seleccionados y rol congelado para una versión | `tbl_Workers_Activity` |
| `report_signatures` | Firma dibujada o archivo de firma del participante | `tbl_Workers_Activity` / `APP` |
| `preventive_report_details` | Datos generales, fecha, horas, ubicación, resultado y comentarios del preventivo | `Maintenance_Storage` |
| `preventive_step_results` | Resultado de cada paso, snapshot del título y comentario | `task_activity` / `tbl_Activity_Task` |
| `preventive_test_results` | Resultado elegido, valor numérico y notas de cada prueba | `tbl_Test_Result_Activity` |
| `corrective_report_details` | Síntoma, análisis, pruebas, liberación, estado técnico y conclusiones | `tbl_CorrectiveReports_Detail` |
| `corrective_report_blocks` | Bloques configurables del reporte correctivo y payload JSON | `APP` / formato correctivo |
| `corrective_activities` | Actividades realizadas, secuencia, descripción y horas | `tbl_CorrectiveActivities` |
| `attachments` | Evidencias y archivos relacionados a versiones, pasos o actividades correctivas | `Images_Activity` |
| `generated_reports` | PDF/XLSX generado, nombre, ubicación, checksum y usuario generador | `tbl_Reports` |
| `calibration_report_details` | Cabecera del reporte de calibración de circuito de vía | `tbl_Calibration` |
| `calibration_measurements` | Mediciones ordenadas por activo/rol: transmisor y receptores | `tbl_Calibration` |
| `report_tool_usages` | Herramientas efectivamente utilizadas en una versión | `Tools_Activity` |
| `corrective_equipment_groups` | Grupos lógicos permitidos como objetivo inicial de un correctivo; no son activos físicos | `APP` / regla operativa ATS |
| `corrective_equipment_group_members` | Equipos grandes físicos pertenecientes a un grupo lógico correctivo | `APP` / `assets` |
| `corrective_event_affected_assets` | Uno o más activos afectados por evento y su ruta al crear el aviso; la criticidad vive en el evento | `APP` / correctivos existentes |
| `asset_groups` | Alcance operativo de preventivos, siempre usado incluso para relaciones 1:1 | `APP` / normalización de equipos legacy |
| `asset_group_members` | Relación 1:N entre un grupo preventivo y sus activos físicos | `APP` / `assets` |

`report_tool_usages` también conserva los campos snapshot `tool_name_snapshot`,
`tool_serial_snapshot`, `certification_number_snapshot` y
`certification_valid_until_snapshot` para que una versión histórica sea auditable.

## Herramientas

| Tabla | Contenido y campos clave | Origen |
|---|---|---|
| `tools` | Herramientas identificables por modelo, serie, marca y estado | `tbl_Tool` |
| `tool_certifications` | Certificados de calibración, vigencia, empresa y archivo | `tbl_Certification` |

## Importación y compatibilidad

| Tabla | Contenido y campos clave | Origen |
|---|---|---|
| `data_import_batches` | Una ejecución de importación, checksum, modo, estado y contadores | `APP` |
| `data_import_row_results` | Resultado por fila: insertada, actualizada, sin cambios o fallida | `APP` |
| `legacy_record_mappings` | Mapeo auditable de clave Excel a tabla/registro normalizado | `APP` |
| `app_state_snapshots` | Snapshot transitorio usado por compatibilidad durante la migración | `APP` / mock antiguo |

## Cómo consultar el esquema exacto

El diccionario explica significado y procedencia. Para ver todas las columnas,
tipos, nulabilidad y el orden real en la instancia:

```sql
SELECT table_name, ordinal_position, column_name, data_type,
       is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
ORDER BY table_name, ordinal_position;
```

Para inspeccionar relaciones entre tablas:

```sql
SELECT tc.table_name, kcu.column_name,
       ccu.table_name AS referenced_table,
       ccu.column_name AS referenced_column
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
 AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage ccu
  ON ccu.constraint_name = tc.constraint_name
 AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
ORDER BY tc.table_name, kcu.column_name;
```

Las consultas de negocio listas para usar están en
[`sql-query-cookbook.sql`](sql-query-cookbook.sql).
