# Recuperacion de evidencias y sincronizacion offline

## Diagnostico del 11 de septiembre de 2026

Consulta de solo lectura en QA: el reporte del activo MAQUINAS DE CONMUTACION
105, version `518a8c7c-ab2f-4f42-a575-1e9dd23c730a`, esta en DRAFT y tiene ocho
adjuntos. Los ocho attachment_id de su data_snapshot ya no existen en attachments.
Cada fotografia tiene una coincidencia unica por nombre y fecha de captura en
los adjuntos actuales de esa misma version.

El guardado de borradores eliminaba y recreaba los adjuntos con IDs nuevos.
La app conservaba los IDs anteriores, tanto para descargar las miniaturas como
para volver a guardar sin reenviar los bytes. Esto producia miniaturas rotas y
el error de evidencia sin archivo, aunque la version del servidor tenia fotos.

## Correccion

- Conservar el ID del adjunto al actualizar la misma version.
- Asignar IDs deterministas por version y client_id a nuevos adjuntos.
- Guardar las referencias actuales en data_snapshot despues de persistir fotos.
- Recuperar referencias antiguas solo si existe una coincidencia unica de nombre,
  tipo y fecha de captura en la version actual o su version fuente autorizada.
  Nunca buscar fotos en otros mantenimientos ni adivinar entre duplicados.
- Reconciliar referencias locales al abrir el formulario con datos del servidor.
- Mostrar una ventana de sincronizacion con nombre, equipo, fecha y estado de
  cada trabajo; cerrarla no cancela la sincronizacion. No mostrar una alerta por
  cada reporte o cambio de estado.

No se eliminaron datos de QA. No se requiere migracion de esquema.

## Despliegue y validacion

Desde backend, con estos cambios disponibles en la rama que se va a desplegar:

```sh
make ENV=qa build
```

Compilar e instalar la app con Xcode sobre la instalacion existente, manteniendo
el Bundle ID y la configuracion QA. No desinstalar: contiene el borrador local.

1. Abrir con conexion y entrar en los trabajos pendientes.
2. Reintentar la sincronizacion del cambiavia 105; si esta marcado como necesita
   revision no se reintenta automaticamente hasta solicitarlo.
3. Abrir nuevamente el reporte y verificar las ocho imagenes. Guardar otra vez y
   comprobar que la version del servidor conserva las fotos.
4. Descargar otro trabajo, trabajar sin wifi, tomar varias fotos y guardar borrador.
5. Cerrar la app, activar wifi y abrirla. Verificar una ventana de progreso con
   los trabajos. Cerrar la ventana y comprobar que continua el envio.
6. Abrir el reporte sincronizado, modificar un comentario y guardar dos veces.
   Cerrar y abrir la app; las fotos deben seguir disponibles.
7. Repetir con un correctivo y con una nueva version de reporte. La nueva version
   no debe cambiar los adjuntos de la version anterior.

Si una evidencia no tiene coincidencia unica, se conserva el error y el borrador
local. No descartar trabajo pendiente como procedimiento de recuperacion.
