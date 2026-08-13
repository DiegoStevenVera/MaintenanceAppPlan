# MaintenanceApp Backend

Local-first FastAPI backend for MaintenanceApp v1.

## Current Slice

The backend exposes versioned API contracts backed by PostgreSQL, plus seed
repositories used only by isolated tests.

Implemented endpoints:

- `GET /health`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
- `GET /api/v1/auth/me`
- `POST /api/v1/auth/change-password`
- `GET /api/v1/auth/impersonation-roles`
- `POST /api/v1/auth/impersonate-role`
- `GET /api/v1/assets`
- `GET /api/v1/assets/stock`
- `GET /api/v1/assets/{asset_id}`
- `GET /api/v1/assets/{asset_id}/tree`
- `GET /api/v1/assets/{asset_id}/history`
- `GET /api/v1/maintenance-activities`
- `GET /api/v1/maintenance-dashboard`
- `GET /api/v1/maintenance-activities/{activity_id}`
- `GET /api/v1/maintenance-activities/{activity_id}/reports`
- `GET /api/v1/report-versions/{version_id}`
- `POST /api/v1/report-versions/{version_id}/generate-pdf`
- `GET /api/v1/report-versions/{version_id}/pdf`
- `POST /api/v1/maintenance-activities/{activity_id}/start`
- `POST /api/v1/maintenance-activities/{activity_id}/complete`
- `POST /api/v1/maintenance-activities/{activity_id}/close`
- `POST /api/v1/maintenance-activities/{activity_id}/reopen`
- `GET /api/v1/maintenance-activities/{activity_id}/report-editor`
- `GET /api/v1/maintenance-activities/{activity_id}/preventive-guide`
- `PUT /api/v1/maintenance-activities/{activity_id}/report-draft`
- `POST /api/v1/maintenance-activities/{activity_id}/report-finalize`
- `GET /api/v1/maintenance-activities/{activity_id}/comments`
- `POST /api/v1/maintenance-activities/{activity_id}/comments`
- `GET /api/v1/attachments/{attachment_id}/content`
- `GET /api/v1/schedules`
- `GET /api/v1/corrective-events`
- `GET /api/v1/corrective-events/{event_id}`
- `POST /api/v1/corrective-events`

## Run Locally

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
uvicorn app.main:app --app-dir src --reload
```

Then open:

- `http://127.0.0.1:8000/health`
- `http://127.0.0.1:8000/docs`

## Run Locally With PostgreSQL

The local v1 backend can run against PostgreSQL in Docker while keeping the seed
repositories available for tests.

From the project root:

```bash
docker compose up -d postgres
cp .env.example .env
make db-up
make db-migrate
make db-seed
make backend-dev-postgres
```

Use the root `.env` as the main local configuration file. Docker Compose reads
the root `.env`, and the FastAPI backend also reads it. `backend/.env` is only a
module-local override for exceptional cases and should normally be omitted.

## Run FastAPI And PostgreSQL In Docker

The root `docker-compose.yml` runs both services in one Compose project:

- `maintenance_postgres`: PostgreSQL 16 with the persistent
  `maintenance_postgres_data` volume.
- `maintenance_backend`: FastAPI, WeasyPrint and the API dependencies built from
  `backend/Dockerfile`.

The backend connects to PostgreSQL using the Compose service name
`POSTGRES_HOST=postgres`, not `localhost`. Evidence and generated PDFs use the
host bind mount `./backend/storage:/app/storage`, so recreating the backend
container does not remove them. PostgreSQL stores only portable keys relative
to the configured storage root, for example `report.pdf` or `evidence.jpg`.

First setup or after changing the Dockerfile:

```bash
docker compose up -d --build
docker compose exec backend alembic upgrade head
docker compose ps
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/health/db
```

Daily usage normally only needs:

```bash
docker compose up -d
```

Rebuild after changing Python dependencies or the Docker image definition:

```bash
docker compose up -d --build backend
```

View logs or stop the stack:

```bash
docker compose logs -f backend postgres
docker compose stop
```

`docker compose down` removes containers and the network but keeps named
volumes. `docker compose down -v` also deletes the PostgreSQL volume and must
only be used when the local database is intentionally disposable.

PostgreSQL applies `POSTGRES_DB`, `POSTGRES_USER`, and `POSTGRES_PASSWORD` only
when its Docker volume is initialized for the first time. If credentials change
after the volume already exists, recreate the local volume with
`docker compose down -v` or update the password inside PostgreSQL manually.

Add a private signing key to the root `.env` before starting FastAPI:

```env
JWT_SECRET_KEY=replace-with-at-least-32-random-characters
JWT_ISSUER=maintenance-app
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=7
```

Generate a suitable local key with:

```bash
openssl rand -hex 32
```

## Preventive PDF

The first PDF implementation uses the normalized report version, Jinja2 and
WeasyPrint. The logo comes from
`docs/OldVersionApp/Formats/img/Hitachi-Logo.png`. Generated files are stored
under `REPORT_STORAGE_PATH` and registered in `generated_reports`; existing
versions can therefore be opened from the same read-only version screen.
`generated_reports.file_reference` and `generated_reports.path` contain keys
relative to the report storage root, not paths from a developer laptop or
container.

On macOS, `make backend-dev-postgres` adds the Homebrew library paths needed by
WeasyPrint. If the backend is started manually, install `pango`, `cairo` and
`gdk-pixbuf` with Homebrew and export `DYLD_LIBRARY_PATH` with their `lib`
directories before running Uvicorn.

Validation URLs:

- `http://127.0.0.1:8000/health`
- `http://127.0.0.1:8000/health/db`
- `http://127.0.0.1:8000/api/v1/assets`
- `http://127.0.0.1:8000/api/v1/schedules`
- `http://127.0.0.1:8000/api/v1/corrective-events`
- `http://127.0.0.1:8000/api/v1/maintenance-activities`

Except for health and the login/refresh endpoints, domain APIs require an access
token in `Authorization: Bearer <token>`.

## Authentication

- Passwords are stored with Argon2.
- Existing `mock:<password>` hashes remain login-compatible once. A successful
  login automatically replaces that temporary value with an Argon2 hash.
- Access tokens expire after 15 minutes by default.
- Refresh tokens expire after 7 days, rotate on every use, and are tracked in
  `auth_refresh_sessions` so logout and password changes can revoke them.
- `BOSS` is read-only. Maintenance Engineer, Coordinator, and Administrator
  retain the operational permissions defined for the current slice.
- In non-production environments, an Administrator may request a temporary
  session for an active user of another role. The endpoint is disabled when
  `ENVIRONMENT` is `production` or `prod`.

Reset one imported user's password without exposing a public reset endpoint:

```bash
make user-set-password EMAIL=usuario@hitachirail.com
```

Enable every user still marked as `!legacy-import-disabled!`:

```bash
make user-bootstrap-disabled
```

Both commands request the password interactively and require at least 8
characters.

## Test

```bash
cd backend
pytest
```

## Current Read Slice

The preventive and corrective list/detail screens use the normalized
`maintenance_activities`, `maintenance_activity_assets`, `maintenance_reports`,
`report_versions`, and report-detail tables. Filters are applied in PostgreSQL
and the endpoints require an authenticated Bearer token.

Preventive date filtering preserves the two scheduling levels from
`tbl_Scheduled_Activities`:

- `Date_Activity_Scheduled` is the exact scheduled date and is required for
  day/week filters.
- `Year` plus `Month` is the planning period used by month filters when the
  exact date is still empty.
- `Date_Activity_Done` is the execution date and is not used as a replacement
  for the scheduled date.

The iOS client follows every API page until `total` is reached. Imported orphan
report placeholders remain in PostgreSQL for traceability but are excluded from
operational corrective lists. The Home indicators use
`GET /api/v1/maintenance-dashboard` rather than the former mock store.

Lifecycle commands validate the current state and authenticated role, update the
normalized activity and its preventive/corrective bridge, and append
`maintenance_status_history`. Reopening also appends
`maintenance_reopen_records` with the required reason.

- Maintenance Engineer, Coordinator, and Administrator can start and complete.
- Every role except Boss can reopen a `COMPLETED` activity.
- Only Coordinator and Administrator can close, or reopen a `CLOSED` activity.
- Boss remains read-only.

Preventive and corrective report drafts now persist normalized details, steps,
tests, performed activities, participants, signatures, evidence metadata, and a
complete JSON version snapshot. Finalized versions are immutable; a later
correction creates a new draft version. Corrective component replacements are
recorded in the report draft and update assignments, statuses, closure links,
and `asset_replacements` atomically only when the version is finalized.

Evidence bytes are stored outside PostgreSQL under
`ATTACHMENT_STORAGE_PATH`; PostgreSQL stores a relative file key, ownership,
media metadata, size, and SHA-256 checksum. The default maximum file size is
configured through `ATTACHMENT_MAX_BYTES`. Migration `20260812_0011`
converted existing local attachment and generated-report references while
leaving imported external URLs unchanged.

Generated PDF persistence, offline report draft retry, equipment history
navigation, and the normalized stock read screen are connected. The old
schedule and corrective-event endpoints remain available for compatibility
with transitional UI and import tools.
