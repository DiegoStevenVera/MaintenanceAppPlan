# MaintenanceApp Backend

Local-first FastAPI backend for MaintenanceApp v1.

## Current Slice

This is the first non-mock backend slice. It exposes versioned API contracts and seed-backed repositories that will be replaced by SQLAlchemy/PostgreSQL repositories.

Implemented endpoints:

- `GET /health`
- `POST /api/v1/auth/login`
- `GET /api/v1/auth/me`
- `GET /api/v1/assets`
- `GET /api/v1/assets/{asset_id}`
- `GET /api/v1/assets/{asset_id}/history`
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

PostgreSQL applies `POSTGRES_DB`, `POSTGRES_USER`, and `POSTGRES_PASSWORD` only
when its Docker volume is initialized for the first time. If credentials change
after the volume already exists, recreate the local volume with
`docker compose down -v` or update the password inside PostgreSQL manually.

Validation URLs:

- `http://127.0.0.1:8000/health`
- `http://127.0.0.1:8000/health/db`
- `http://127.0.0.1:8000/api/v1/assets`
- `http://127.0.0.1:8000/api/v1/schedules`
- `http://127.0.0.1:8000/api/v1/corrective-events`

## Test

```bash
cd backend
pytest
```

## Next Step

Replace `SeedAssetRepository` and `SeedMaintenanceRepository` with SQLAlchemy repositories and migrations while preserving the API DTOs.
