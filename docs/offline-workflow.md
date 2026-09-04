# Trabajo Offline en iPad

## Objetivo

Permitir que un ingeniero descargue trabajo mientras está conectado a la API,
avance en campo sin red y entregue los cambios al servidor al regresar a la
oficina.

## Paquetes de trabajo

En las pestañas **Preventivos** y **Correctivos** se usa **Descargar offline**.
El usuario puede filtrar por fecha, estado, subsistema, equipo o texto de
búsqueda, marcar varios trabajos y pulsar **Descargar seleccionados**. Cada
fila muestra un tamaño estimado, su estado de disponibilidad y si ya existe un
paquete local. La descarga avanza de forma secuencial: un error en un trabajo
no cancela los demás.

La descarga solo se inicia desde las listas de Preventivos y Correctivos. El
paquete contiene el detalle de la actividad, el formulario, pasos, pruebas,
participantes, activos disponibles, stock que el editor ya expone y las
evidencias existentes.

Los paquetes se guardan en `Application Support/OfflineWorkPackages` del
contenedor de la app, con protección
`completeUntilFirstUserAuthentication`. Solo se muestran al mismo usuario y
al mismo entorno compilado (`DEV`, `QA`, etc.). Cambiar la IP DHCP de la Mac no
oculta ni borra el trabajo descargado. Al abrir la aplicación sin red, Inicio,
Preventivos y Correctivos usan exclusivamente esos paquetes persistidos; no
intentan sustituirlos con una respuesta incompleta del servidor.

## En campo

- Un paquete descargado puede abrir el formulario sin API.
- Al iniciar una actividad sin red, el paquete conserva inmediatamente el
  estado `En progreso` y la hora local de inicio; el servidor recibe la misma
  transición antes de guardar el reporte cuando vuelva la conexión.
- Los cambios del reporte, firmas y evidencias se guardan localmente.
- Los comentarios y transiciones de estado se agregan a una cola local.
- Sin conexión solo está disponible **Guardar borrador**. Al guardarlo, la
  aplicación vuelve al detalle y muestra que el borrador está protegido y
  pendiente de sincronización. La versión se finaliza explícitamente cuando el
  iPad vuelve a tener conexión y el servidor puede aplicar sus validaciones.
- Un cambio de componente desde almacén, transferencia o intercambio se ve de
  forma provisional en el reporte local. El movimiento oficial se aplica solo
  al completar la actividad en el servidor.
- En **Perfil > Trabajo offline** se consultan y abren los paquetes disponibles.

## Nuevo correctivo offline

Antes de salir a campo, en **Perfil > Trabajo offline** se debe usar
**Descargar catálogo correctivo**. Esto descarga los objetivos correctivos de
ATS, CBTC e IXL, su contexto y sus árboles físicos de componentes.

Sin conexión, el botón `+` de Correctivos permite crear el evento usando ese
catálogo. El evento se guarda con un identificador local y se crea en el
backend durante la próxima sincronización. Hasta entonces no tiene código
oficial ni versión de reporte del servidor.

## Sincronización y seguridad

Al recuperar conectividad, la aplicación intenta enviar borradores, cambios de
estado, comentarios y eventos correctivos pendientes. El aviso compacto se
ubica en el borde inferior para no bloquear la navegación adaptable del iPad,
y la pantalla **Trabajo offline** muestra reportes, cambios de estado,
comentarios y eventos pendientes, y permite reintentar o descartar un cambio
de prueba obsoleto. El detalle de cada actividad también ofrece
**Sincronizar ahora** cuando hay red.

Un mantenimiento solo puede pasar a **Completado** cuando ya existe al menos
una versión de reporte `FINALIZED` en el servidor. Esta validación se aplica
en la interfaz y también en la API.

No se elimina un paquete si conserva un borrador o una operación pendiente.
Los registros que el servidor rechace pasan a **Necesita revisión** y permanecen
en el iPad hasta que el usuario los corrija o reintente.

Para una transferencia o intercambio, el servidor bloquea ambos activos al
sincronizar y confirma que mantienen las posiciones descargadas. Si otro
trabajo ya los movió, conserva el reporte y marca un conflicto de inventario;
nunca sobrescribe la ubicación central sin validación.

Para esta etapa los archivos se conservan hasta que el usuario elimine el
paquete sin pendientes, cierre sesión, desinstale la app o el sistema borre el
contenedor por una restauración del dispositivo. En QA se recomienda
sincronizar al regresar el mismo día; técnicamente los datos pueden permanecer
por semanas mientras el iPad conserve la app y su almacenamiento.
