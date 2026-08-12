WEASYPRINT_DYLD_PATH := $(shell if command -v brew >/dev/null 2>&1; then printf "%s/lib:%s/lib:%s/lib:%s/lib" "$$(brew --prefix)" "$$(brew --prefix glib)" "$$(brew --prefix pango)" "$$(brew --prefix cairo)"; fi)

.PHONY: backend-dev backend-dev-postgres backend-test backend-lint db-up db-down db-logs db-migrate db-seed user-set-password user-bootstrap-disabled

backend-dev:
	cd backend && REPOSITORY_BACKEND=seed ../app_mant/bin/uvicorn app.main:app --app-dir src --reload

backend-dev-postgres:
	cd backend && DYLD_LIBRARY_PATH="$(WEASYPRINT_DYLD_PATH):$${DYLD_LIBRARY_PATH}" REPOSITORY_BACKEND=postgres ../app_mant/bin/uvicorn app.main:app --app-dir src --reload --host 0.0.0.0

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

user-set-password:
	cd backend && REPOSITORY_BACKEND=postgres ../app_mant/bin/python -m app.user_admin set-password --email "$(EMAIL)"

user-bootstrap-disabled:
	cd backend && REPOSITORY_BACKEND=postgres ../app_mant/bin/python -m app.user_admin bootstrap-disabled
