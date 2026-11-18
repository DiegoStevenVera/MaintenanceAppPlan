# Consulta De Soluciones

## Entrega Inicial

Accesos: **Correctivos → Consulta de soluciones** y **Detalle correctivo → Ver
casos similares**. No se agregan pestañas principales. La ficha reúne reportes y
turnos del evento, acciones intentadas, reemplazos, evidencias, comentarios y
pruebas. Cada reporte tiene como referencia su última versión finalizada; los
borradores recientes están marcados y las versiones anteriores permanecen
accesibles desde la ficha y el lector original.

El buscador inicial es **textual y contextual**, no semántico ni diagnóstico.
Normaliza tildes, admite errores de escritura en palabras y un conjunto pequeño
de alias técnicos inspeccionables en `solution_matching.py`. Los códigos con
números exigen coincidencia; se conservan negaciones básicas. Esos alias deben
ser revisados por el equipo antes de ampliarlos. No hay resúmenes generados ni
porcentajes de certeza. La selección de un equipo y subsistema son filtros
obligatorios: no se amplían silenciosamente.

Si no hay descripción, se muestran antecedentes por contexto, no una propuesta
de diagnóstico. Las sugerencias de síntomas proceden de los reportes existentes.
La etiqueta **Liberación con validación documentada** requiere evento completado
o cerrado, prueba descrita, validación conforme, estado operativo y servicio
liberado en el reporte principal más reciente. Un borrador reciente impide esa
etiqueta. No se afirma que una acción particular sea la causa de la resolución.
Todos los antecedentes son documentales, no procedimientos revisados.

## Datos Y Actualización

Alembic `20261117_0035` crea `corrective_solution_cases`, una proyección reconstruible.
Las fuentes no se modifican. Durante la consulta se consolidan todas las fuentes;
solo se escriben filas cuyo fingerprint cambió. Si falla, se reintenta en otra
consulta. El guardado y finalización de reportes no dependen del buscador.

La primera entrega todavía lee las fuentes para verificar cambios en cada consulta;
no tiene cola de indexación asíncrona ni índices vectoriales. Debe medirse con el
volumen real antes de prometer las metas de latencia del plan.

Contratos bajo `/api/v1/corrective-solutions`:

- `GET /search`: `q`, `asset_id`, `subsystem`, `similar_to` (evento o actividad),
  `include_provisional`, `limit`, `offset`. Página y total calculados en servidor.
- `GET /cases/{event_id}`: ficha completa reconstruida.
- `GET /bundle`: descarga paginada por equipo o subsistema. `revision` permite
  detectar cambios durante la descarga y evitar guardar un paquete incompleto.
- `GET /evidence/{attachment_id}`: contenido de una evidencia de reporte correctivo.

Todos requieren autenticación y permiso de lectura de **Correctivos**, incluso
las evidencias. Se usa el mismo alcance de historial que Correctivos; no se añade
un filtro ficticio por área, dado que el módulo actual no tiene esa restricción
por fila. La proyección no concede acceso a otros módulos.

## Consulta Offline

Descarga fichas por equipo o subsistema, o guarda una ficha individual. No se
confunden con los paquetes offline de formularios. La consulta local usa solo
fichas descargadas y muestra cantidad, cobertura y fecha de descarga. Es textual,
no semántica. Las evidencias de imagen se guardan individualmente desde su vista
(hasta 20 MB por imagen); los PDF completos no se descargan con este paquete.

Los archivos están en Application Support, protegidos con protección de archivos
de iOS y excluidos de copias de seguridad. El espacio se identifica mediante un
hash de usuario, rol, entorno, URL y permisos. Al cambiar de cuenta o permisos no
se muestran las descargas de otro espacio. Una revocación realizada en el servidor
no puede descubrirse mientras el dispositivo permanezca totalmente desconectado;
se aplican los últimos permisos autenticados disponibles, como en el modo offline
de la app. El usuario puede eliminar las descargas desde la consulta.

## Pendiente Del Plan

1. Seleccionar y evaluar un modelo semántico local, precisión, licencia y recursos.
   Esta entrega no instala ni descarga modelos, ni envía documentos a una nube.
2. Migrar la recuperación a índices híbridos y actualización asíncrona si las
   mediciones de volumen lo justifican.
3. Definir responsables de revisar soluciones para reutilización y valoraciones.
4. Evaluar con consultas reales de los ingenieros. El 85 % en top 3 y p95 inferior
   a dos segundos son metas propuestas, no resultados ya obtenidos.

Pruebas automatizadas cubren alias, tildes, errores, negaciones, códigos distintos,
reportes por turnos/versiones, borradores, fuentes antiguas, paginación, reaperturas,
filtros estrictos, reconstrucción y rechazo al retirar permisos. La revisión visual
en un iPad real y las pruebas de descarga en modo avión siguen siendo necesarias.
