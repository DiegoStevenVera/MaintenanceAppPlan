PYTHON ?= $(if $(wildcard .venv/bin/python),.venv/bin/python,python)
WEASYPRINT_DYLD_PATH := $(shell if command -v brew >/dev/null 2>&1; then printf "%s/lib:%s/lib:%s/lib:%s/lib" "$$(brew --prefix)" "$$(brew --prefix glib)" "$$(brew --prefix pango)" "$$(brew --prefix cairo)"; fi)
ENV ?= local
ENV_FILE := environments/$(ENV)/.env
COMPOSE := docker compose --env-file $(ENV_FILE)

.PHONY: up build down logs status migrate current health test lint dev dev-postgres compose-up compose-build compose-down compose-logs backend-migrate db-up db-down db-logs db-migrate db-seed user-set-password user-bootstrap-disabled config

up:
	$(COMPOSE) up -d

compose-up: up

build:
	$(COMPOSE) up -d --build

compose-build: build

down:
	$(COMPOSE) down

compose-down: down

logs:
	$(COMPOSE) logs -f backend postgres

compose-logs: logs

status:
	$(COMPOSE) ps

migrate:
	$(COMPOSE) exec backend alembic upgrade head

backend-migrate: migrate

current:
	$(COMPOSE) exec backend alembic current

health:
	curl -fsS http://127.0.0.1:8000/health

test:
	REPOSITORY_BACKEND=seed $(PYTHON) -m pytest

lint:
	$(PYTHON) -m ruff check src tests

dev:
	APP_ENV_FILE=$(ENV_FILE) REPOSITORY_BACKEND=seed $(PYTHON) -m uvicorn app.main:app --app-dir src --reload

dev-postgres:
	APP_ENV_FILE=$(ENV_FILE) DYLD_LIBRARY_PATH="$(WEASYPRINT_DYLD_PATH):$${DYLD_LIBRARY_PATH}" REPOSITORY_BACKEND=postgres $(PYTHON) -m uvicorn app.main:app --app-dir src --reload --host 0.0.0.0

db-up:
	$(COMPOSE) up -d postgres

db-down:
	$(COMPOSE) down

db-logs:
	$(COMPOSE) logs -f postgres

db-migrate:
	APP_ENV_FILE=$(ENV_FILE) REPOSITORY_BACKEND=postgres $(PYTHON) -m alembic upgrade head

db-seed:
	APP_ENV_FILE=$(ENV_FILE) REPOSITORY_BACKEND=postgres $(PYTHON) -m app.seed

user-set-password:
	APP_ENV_FILE=$(ENV_FILE) REPOSITORY_BACKEND=postgres $(PYTHON) -m app.user_admin set-password --email "$(EMAIL)"

user-bootstrap-disabled:
	APP_ENV_FILE=$(ENV_FILE) REPOSITORY_BACKEND=postgres $(PYTHON) -m app.user_admin bootstrap-disabled

config:
	$(COMPOSE) config --quiet
