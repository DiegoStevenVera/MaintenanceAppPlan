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

También puede descargarse un único trabajo desde su detalle. El paquete contiene
el detalle de la actividad, el formulario, pasos, pruebas, participantes,
activos disponibles, stock que el editor ya expone y las evidencias existentes.

Los paquetes se guardan en `Application Support/OfflineWorkPackages` del
contenedor de la app, con protección
`completeUntilFirstUserAuthentication`. Solo se muestran al mismo usuario y
al mismo entorno compilado (`DEV`, `QA`, etc.). Cambiar la IP DHCP de la Mac no
oculta ni borra el trabajo descargado.

## En campo

- Un paquete descargado puede abrir el formulario sin API.
- Los cambios del reporte, firmas y evidencias se guardan localmente.
- Los comentarios y transiciones de estado se agregan a una cola local.
- La finalización oficial de una versión sigue requiriendo servidor: fuera de
  red el reporte queda como borrador listo para sincronizar. Esto evita cerrar
  una actividad sin que el backend valide su versión y sus reglas de negocio.
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
estado, comentarios y eventos correctivos pendientes. La banda superior y la
pantalla **Trabajo offline** muestran el estado y permiten reintentar.

No se elimina un paquete si conserva un borrador o una operación pendiente.
Los registros que el servidor rechace pasan a **Necesita revisión** y permanecen
en el iPad hasta que el usuario los corrija o reintente.

Para esta etapa los archivos se conservan hasta que el usuario elimine el
paquete sin pendientes, cierre sesión, desinstale la app o el sistema borre el
contenedor por una restauración del dispositivo. En QA se recomienda
sincronizar al regresar el mismo día; técnicamente los datos pueden permanecer
por semanas mientras el iPad conserve la app y su almacenamiento.
