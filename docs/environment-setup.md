# Entornos Locales De Demostración

## Propósito

LOCAL, DEV y QA pueden convivir en la misma Mac sin compartir base de datos,
evidencias, PDFs, puertos o secretos. Las ramas Git controlan el código; estos
archivos controlan dónde se ejecuta ese código.

| Entorno | API | PostgreSQL expuesto | Base | Volumen | Almacenamiento |
|---|---:|---:|---|---|---|
| LOCAL | 8000 | 5432 | existente | existente | `backend/storage` |
| DEV | 8001 | 5433 | `maintenance_dev` | `maintenance_dev_postgres_data` | `backend/runtime/dev/storage` |
| QA | 8002 | 5434 | `maintenance_qa` | `maintenance_qa_postgres_data` | `backend/runtime/qa/storage` |

Los archivos reales no se suben a Git:

```text
backend/environments/local/.env
backend/environments/dev/.env
backend/environments/qa/.env
```

Las plantillas sí se versionan:

```text
backend/environments/local/.env.example
backend/environments/dev/.env.example
backend/environments/qa/.env.example
```

## Configurar DEV Y QA

Desde `backend`, crea los archivos privados a partir de sus plantillas:

```bash
cp environments/dev/.env.example environments/dev/.env
cp environments/qa/.env.example environments/qa/.env
```

Edita en cada uno, como mínimo:

- `POSTGRES_PASSWORD`
- `JWT_SECRET_KEY` (genera uno con `openssl rand -hex 32`)
- `POSTGRES_DB`, `POSTGRES_USER` y los puertos, únicamente si los valores
  propuestos chocan con otro servicio de la Mac.

No copies el archivo LOCAL sobre DEV o QA: haría que los tres entornos apunten
a la misma base de datos.

Valida la configuración sin iniciar contenedores:

```bash
make ENV=local config
make ENV=dev config
make ENV=qa config
```

## Transición Del LOCAL Actual

El archivo actual se movió a `environments/local/.env` y conserva el volumen
`maintenanceappplan_maintenance_postgres_data` junto con `backend/storage`.
No crea ni modifica la base local existente.

Los contenedores anteriores usan los nombres fijos `maintenance_backend` y
`maintenance_postgres`. Antes del primer arranque bajo la nueva estructura,
deténlos para liberar los puertos, sin borrar los datos:

```bash
docker stop maintenance_backend maintenance_postgres
```

Luego inicia el nuevo proyecto LOCAL:

```bash
cd backend
make ENV=local up
make ENV=local health
make ENV=local current
```

No ejecutes `docker compose down -v`: borraría un volumen si el entorno no está
marcado como externo.

## Crear DEV Sin Importar Datos

El siguiente comando crea los contenedores y el volumen de DEV, pero no importa
Excel ni modifica LOCAL:

```bash
cd backend
make ENV=dev build
make ENV=dev migrate
make ENV=dev health
```

La importación de `WBS_V2.xlsx` y `BD_Storage.xlsx` se realizará después, desde
DEV, mediante un dry run y luego `legacy_import import-all`.

## Aplicación iPad Y Entorno Git

El proyecto Xcode tiene un solo esquema: `MaintenanceApp`. La URL de API y el
nombre del entorno se incluyen en la compilación desde este archivo versionado:

```text
frontend/ios/MaintenanceAppMock/Config/Environment.xcconfig
```

La rama `develop` conserva los valores DEV (`:8001`). Un commit de release
cambia ese archivo a QA (`:8002`) y el tag se crea sobre ese commit. Al abrir
el tag y compilar, el iPad se conecta automáticamente a QA; el login no permite
editar la URL.

Con Mac e iPad en la misma red Wi-Fi, actualiza la IP del archivo si la
dirección LAN de la Mac cambia. Comprueba la IP actual con:

```bash
ipconfig getifaddr en0
```

DEV y QA usan deliberadamente el mismo Bundle ID (`com.maintenanceapp.mock`),
por lo que instalar QA reemplaza DEV en el iPad. Cierra sesión antes de cambiar
de entorno para no conservar un token o borrador asociado al servidor anterior.

## Ramas Y Tag De QA

No guardes archivos `.env` en ramas. Un flujo inicial simple es:

```text
main                 versión estable
develop              código desplegable en DEV
feature/*            trabajo aislado
release/qa-*         configuración temporal para QA
tag qa-*             versión inmóvil que QA demuestra
```

Cuando decidas iniciar el flujo:

```bash
git switch main
git pull --ff-only
git switch -c develop
git push -u origin develop
```

Para una funcionalidad:

```bash
git switch develop
git switch -c feature/nombre-corto
```

Tras validar el trabajo en `develop`, prepara una rama de release para QA:

```bash
git switch develop
git pull --ff-only
git switch -c release/qa-demo-YYYY-MM-DD
```

Edita `frontend/ios/MaintenanceAppMock/Config/Environment.xcconfig`:

```text
API_BASE_URL = http:/$()/IP-DE-LA-MAC:8002
APP_ENVIRONMENT = QA
```

Luego confirma y etiqueta ese commit:

```bash
git add frontend/ios/MaintenanceAppMock/Config/Environment.xcconfig
git commit -m "Configure iPad build for QA"
git tag -a qa-demo-YYYY-MM-DD -m "Versión para demostración QA"
git push -u origin release/qa-demo-YYYY-MM-DD
git push origin qa-demo-YYYY-MM-DD
```

La rama/tag QA ejecuta un commit fijo. `develop` no se modifica y conserva la
configuración DEV. Si usas una sola carpeta de trabajo, puedes revisar el tag
con `git switch --detach qa-demo-YYYY-MM-DD`; si quieres mantener DEV y QA
activos con código distinto a la vez, usa una segunda copia del repositorio o
un `git worktree`.

Para compilar ese tag sin abandonar tu carpeta de trabajo `develop`:

```bash
cd ..
git -C MaintenanceAppPlan fetch --tags
git -C MaintenanceAppPlan worktree add MaintenanceAppPlan-QA qa-demo-YYYY-MM-DD
```

Abre `MaintenanceAppPlan-QA/frontend/ios/MaintenanceAppMock.xcodeproj` en
Xcode, selecciona el único esquema `MaintenanceApp` y ejecuta la app en el
iPad. Después de la prueba, vuelve a la carpeta principal en `develop`; esa
rama ya conserva los valores DEV.
