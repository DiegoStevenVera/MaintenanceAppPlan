.PHONY: backend-dev backend-dev-postgres backend-test backend-lint db-up db-down db-logs db-migrate db-seed

backend-dev:
	cd backend && REPOSITORY_BACKEND=seed ../app_mant/bin/uvicorn app.main:app --app-dir src --reload

backend-dev-postgres:
	cd backend && REPOSITORY_BACKEND=postgres ../app_mant/bin/uvicorn app.main:app --app-dir src --reload --host 0.0.0.0

backend-test:
	cd backend && REPOSITORY_BACKEND=seed ../app_mant/bin/python -m pytest

backend-lint:
	cd backend && ../app_mant/bin/python -m ruff check src tests

db-up:
	docker compose up -d postgres

db-down:
	docker compose down

db-logs:
	docker compose logs -f postgres

db-migrate:
	cd backend && REPOSITORY_BACKEND=postgres ../app_mant/bin/alembic upgrade head

db-seed:
	cd backend && REPOSITORY_BACKEND=postgres ../app_mant/bin/python -m app.seed
