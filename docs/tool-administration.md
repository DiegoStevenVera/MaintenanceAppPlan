# Herramientas y checklists preventivos

## Accesos

- Herramientas (solo administrador): inventario, salidas pendientes, movimientos
  y acceso a checklists preventivos.
- Perfil: Checklists preventivos (solo administrador).
- Equipos > Detalle > Mantenimientos preventivos que se le hace al equipo:
  mantenimientos genericos asociados por maintenance_template_scopes y miembros
  de asset_groups, independientemente de las ejecuciones del historico.
- Detalle generico: equipo y ubicacion de origen, manual, ambos checklists,
  pasos y pruebas. Solo el checklist operativo admite Editar, para administradores.
  No representa una actividad programada y no ofrece iniciar, finalizar o crear reporte.

La administracion requiere conexion. El flujo del reporte y su paquete offline
siguen utilizando los checklists descargados.

## Inventario

1. Crear el elemento generico en su categoria: ACCESS_KEY, MANUAL_TOOL,
   CONSUMABLE o EQUIPMENT. Los equipos requieren identificacion individual.
2. Registrar la ubicacion; para elementos identificados, registrar tambien
   codigo/serie, modelo y fabricante. No se crean existencias ficticias.
3. Abrir la existencia y registrar Ingreso con cantidad.
4. Registrar Salida, responsable y opcionalmente uno o varios mantenimientos.
5. En Salidas pendientes registrar devolucion, consumo (solo consumibles),
   devolucion danada o extravio. Se admiten regularizaciones parciales.
6. Consultar Movimientos para ver el historial. Los ajustes requieren motivo;
   no se borran movimientos ni elementos con historia (el catalogo se desactiva).

Una salida puede cubrir varios trabajos de una jornada. No se descuenta inventario
al guardar/finalizar un reporte. Las entregas vinculadas precargan cantidades y
series en formularios nuevos, sin marcar automaticamente que se llevaron.
El ingeniero confirma el checklist y puede registrar diferencias.

Las unidades existentes de tools con catalogo asociado se incorporan al inventario
con su ubicacion y disponibilidad actuales como saldo inicial. Los certificados
existentes se consultan; no se agrega un administrador de certificados.

## Checklists

Agregar desde el catalogo, crear un elemento si falta, modificar cantidad/unidad,
observaciones, quitar y reordenar. Copiar de otro mantenimiento agrega los elementos
faltantes sin borrar los actuales. Guardar publica una revision nueva con autor y
fecha. Cancelar descarta la edicion. Dos administradores no pueden sobrescribir
silenciosamente la misma revision: el segundo recibe un conflicto y debe recargar.

El checklist pertenece al tipo de mantenimiento, no al equipo desde el que se
abre. El editor advierte este alcance. Las revisiones anteriores no se eliminan;
los borradores y paquetes ya iniciados conservan sus requisitos. Los nombres del
catalogo no reescriben snapshots de revisiones publicadas; guardar una revision
nueva incorpora el nombre actual. El checklist del manual y los PDF no cambian.

## Tablas

| Tabla | Contenido |
| --- | --- |
| tool_catalog_items | Tipos de herramientas y sus cuatro categorias |
| tools | Unidades identificadas por serie/codigo |
| tool_certifications | Certificados de unidades identificadas |
| tool_inventory | Existencias disponibles y no disponibles por ubicacion/unidad |
| tool_inventory_movements | Historial de movimientos, responsable, autor, trabajos vinculados y salida de origen |
| maintenance_operational_checklist_revisions | Publicaciones por tipo de mantenimiento, autor y fecha |
| maintenance_operational_checklist_items | Requisitos de cada revision, enlazados al catalogo |
| report_checklist_item_snapshots | Lo registrado en cada version del reporte |
| report_tool_usages | Unidades identificadas realmente registradas en el reporte |
| tool_inventory_items | Registros del inventario fisico importado desde INVENTARIO_HERRAMIENTAS.xlsx |
| tool_inventory_item_images | Referencias relativas a las imagenes asociadas a cada registro del inventario |

El Excel se importa con `legacy_import import-tool-inventory`. Las columnas se
conservan aunque esten vacias. `GABINETE` se guarda como `cabinet_detail` y
`ARMARIO` como `cabinet`, respetando literalmente la estructura recibida. La
ubicacion se relaciona con `inventory_locations`; para `ALMACEN HITACHI` se usa
la ubicacion existente `Almacenamiento Mantto Hitachi`. Las fotos se copian al
volumen persistente de attachments y PostgreSQL guarda una referencia relativa,
MIME, tamano y checksum.

Las definiciones antiguas de herramientas manuales y consumibles que no esten
en el Excel se desactivan durante una importacion con `--replace`; no se borran
fisicamente para conservar reportes y checklists historicos.

### Administrador de inventario fisico

La pestaña Herramientas usa `tool_inventory_items` como fuente principal para el
inventario fisico. En modo horizontal muestra una tabla; en modo vertical muestra
tarjetas compactas. Ambos modos comparten busqueda, filtros por clasificacion y
estado, paginacion de diez registros, miniaturas, visor de imagen, alta, edicion
y eliminacion con confirmacion.

Las operaciones del administrador requieren un usuario administrador y conexion:

| Operacion | Endpoint |
| --- | --- |
| Listar y filtrar | `GET /api/v1/tool-admin/items` |
| Ubicaciones disponibles | `GET /api/v1/tool-admin/storage-locations` |
| Crear | `POST /api/v1/tool-admin/items` |
| Editar | `PUT /api/v1/tool-admin/items/{id}` |
| Eliminar | `DELETE /api/v1/tool-admin/items/{id}` |
| Ver imagen | `GET /api/v1/tool-admin/items/{id}/images/{image_id}` |
| Eliminar imagen | `DELETE /api/v1/tool-admin/items/{id}/images/{image_id}` |

El formulario acepta todos los campos del inventario (`Codigo_Modelo`, `Codigo`,
`Etiqueta`, `Cantidad`, `Nombre`, `Descripcion`, `Armario`, `Gabinete`,
`Empresa`, `Clasificacion`, `Categoria`, `Ubicacion`, `Estado`,
`Observaciones`) y permite agregar una imagen desde galeria o camara. Las fotos
se guardan en el almacenamiento persistente como referencias relativas, nunca
como rutas absolutas en PostgreSQL.

`tool_inventory_movements.id` es la clave de idempotencia generada por el cliente.
Los reintentos del mismo comando no duplican existencias. Las operaciones bloquean
la fila de inventario para impedir salidas concurrentes por encima del saldo.
`issue_id` vincula cada regularizacion con su salida; se rechazan devoluciones
superiores al saldo pendiente. Los movimientos son historicos, no editables.

## Desplegar

Desde backend, primero en DEV, con el codigo actualizado:

```sh
make ENV=dev build
make ENV=dev migrate
make ENV=dev current
```

El resultado esperado es `20260915_0021 (head)`. No basta reconstruir la imagen:
el esquema necesita la nueva migracion antes de usar el backend actualizado.
Para esta limpieza el resultado esperado pasa a ser `20260915_0022 (head)`.
La migracion `0022` elimina las revisiones y lineas de checklist operativo de
prueba, desactiva las definiciones antiguas que no tienen una fila en
`tool_inventory_items` y conserva los snapshots de reportes ya realizados.
Tras validar y llevar el codigo a la rama QA:

```sh
make ENV=qa build
make ENV=qa migrate
make ENV=qa current
```

Despues de aplicar la migracion, importar el inventario desde la raiz del
repositorio con el entorno que corresponda:

```sh
cd backend
# Al ejecutar el importador fuera del contenedor, apunta el almacenamiento al
# mismo directorio que STORAGE_HOST_PATH para que Docker vea las imagenes.
ATTACHMENT_STORAGE_PATH=runtime/dev/storage/attachments \
APP_ENV_FILE=environments/dev/.env REPOSITORY_BACKEND=postgres \
python -m legacy_import import-tool-inventory \
  --file ../docs/herramientas/INVENTARIO_HERRAMIENTAS.xlsx \
  --photos-dir ../docs/herramientas/FOTOS \
  --replace --dry-run

ATTACHMENT_STORAGE_PATH=runtime/dev/storage/attachments \
APP_ENV_FILE=environments/dev/.env REPOSITORY_BACKEND=postgres \
python -m legacy_import import-tool-inventory \
  --file ../docs/herramientas/INVENTARIO_HERRAMIENTAS.xlsx \
  --photos-dir ../docs/herramientas/FOTOS \
  --replace
```

El primer comando valida sin modificar la base ni copiar imagenes. El segundo
reemplaza la carga anterior del mismo Excel, importa las 200 filas no vacias y
asocia las fotos disponibles por `ETIQUETA`. Ejecuta el mismo flujo con
`environments/qa/.env`, cambiando el override a
`ATTACHMENT_STORAGE_PATH=runtime/qa/storage/attachments`, solamente despues de
validar DEV.

Compilar MaintenanceApp en Xcode con la configuracion del entorno correspondiente.
No desinstalar la app si contiene borradores pendientes. Actualizar los paquetes
offline antes de salir a campo para obtener los requisitos y entregas nuevos.

## Validacion funcional

1. Con administrador, comprobar Herramientas y ambos accesos al editor.
2. Abrir FRONTAM de Colectora: deben aparecer sus dos tipos de mantenimiento,
   ademas del historico separado. Entrar a uno y revisar el detalle generico.
3. Editar el checklist y cancelar: no debe cambiar. Guardar: debe crear revision.
4. Mantener un borrador previo, publicar otro checklist y reabrirlo: debe conservar
   su revision, tambien al sincronizar un borrador creado offline.
5. Registrar diez consumibles, entregar cuatro, devolver uno, consumir dos y
   devolver uno danado: disponibles siete, no disponibles uno, salida resuelta.
6. Intentar devolver de nuevo o entregar mas de siete: debe rechazarse.
7. Registrar equipo con serie y entregar a un mantenimiento. El formulario nuevo
   debe ofrecer esa serie para confirmacion sin descontar el equipo otra vez.
8. Como ingeniero, consultar detalle generico pero sin acceso de administracion;
   las APIs de escritura tambien deben devolver 403.

```sql
SELECT c.name, i.location, t.serial_number, i.available, i.unavailable
FROM tool_inventory i JOIN tool_catalog_items c ON c.id=i.catalog_item_id
LEFT JOIN tools t ON t.id=i.tool_id ORDER BY c.name, i.location;

SELECT m.id, c.name, m.kind, m.quantity, m.issue_id,
       u.name AS actor, r.name AS responsable, m.created_at, m.notes
FROM tool_inventory_movements m JOIN tool_inventory i ON i.id=m.inventory_id
JOIN tool_catalog_items c ON c.id=i.catalog_item_id
JOIN users u ON u.id=m.actor_user_id LEFT JOIN users r ON r.id=m.responsible_user_id
ORDER BY m.created_at DESC;

SELECT t.activity_n3_summary, r.revision_number, r.status, u.name, r.created_at
FROM maintenance_operational_checklist_revisions r
JOIN maintenance_templates t ON t.id=r.maintenance_template_id
LEFT JOIN users u ON u.id=r.created_by_user_id
ORDER BY r.created_at DESC;

SELECT i.name, i.tool_code, i.label, i.quantity, i.status,
       i.classification, i.category, i.location_text,
       count(img.id) AS image_count
FROM tool_inventory_items i
LEFT JOIN tool_inventory_item_images img ON img.inventory_item_id = i.id
GROUP BY i.id
ORDER BY i.name, i.source_row_number;
```

Pruebas automatizadas de integracion: `backend/tests/integration/test_tool_administration.py`.
Requieren PostgreSQL desechable migrado y `TEST_TOOL_ADMIN_DB=1`; no ejecutarlas
contra DEV/QA porque crean registros para probar los movimientos.
