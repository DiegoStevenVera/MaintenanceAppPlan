# Engineering Guide

**Version:** 0.2
**Status:** Draft
**Based on:** Domain Model v0.3, Architecture v0.2
**Last Updated:** 2026-06-16

---

## 0. Current Engineering Decisions

- v1 is local-first for demo and validation. Cloud provider is not approved yet.
- Keep infrastructure provider-neutral until on-premise, Azure, or AWS is selected.
- iPad is the initial target. iPhone is future.
- Use unified `asset_management` for equipment, components, software, tools when they need hierarchy/history traceability.
- Treat `component_inventory` references below as legacy draft structure unless inventory complexity later justifies a separate bounded context.
- Corrective reports use dynamic blocks, not a fixed six-section model.

---

## 1. Monorepo Structure

```
maintenance-app/
├── backend/                    # Python FastAPI application
├── ios/                        # SwiftUI iOS application
├── infra/                      # Terraform infrastructure
├── docs/                       # Project documentation
├── scripts/                    # Development & CI helper scripts
├── .github/                    # GitHub Actions workflows
│   └── workflows/
├── .gitignore
├── .pre-commit-config.yaml
├── docker-compose.yml          # Local development stack
├── Makefile                    # Common dev commands
├── pyproject.toml              # Root-level Python tooling config
└── README.md
```

---

## 2. Backend Folder Organization

```
backend/
├── src/
│   ├── app/                    # FastAPI application bootstrap
│   │   ├── __init__.py
│   │   ├── main.py             # FastAPI app factory, middleware, router includes
│   │   ├── config.py           # Pydantic Settings — environment configuration
│   │   ├── database.py         # Engine, session factory, Base metadata
│   │   ├── dependencies.py     # FastAPI dependency injection (get_db, get_current_user, etc.)
│   │   ├── exceptions.py       # Global exception handlers -> structured error responses
│   │   └── lifespan.py         # App startup/shutdown hooks
│   │
│   ├── modules/                # Domain modules (bounded contexts)
│   │   ├── asset_management/
│   │   │   ├── __init__.py
│   │   │   ├── domain/         # Entities, value objects, aggregates, domain events
│   │   │   ├── application/    # Use cases / application services
│   │   │   ├── infrastructure/ # Repositories, ORM mapping, event handlers
│   │   │   ├── interfaces/     # API route definitions (FastAPI routers)
│   │   │   └── tests/          # Module-specific tests
│   │   │
│   │   ├── maintenance_execution/
│   │   │   ├── __init__.py
│   │   │   ├── domain/
│   │   │   ├── application/
│   │   │   ├── infrastructure/
│   │   │   ├── interfaces/
│   │   │   └── tests/
│   │   │
│   │   ├── component_inventory/
│   │   │   ├── __init__.py
│   │   │   ├── domain/
│   │   │   ├── application/
│   │   │   ├── infrastructure/
│   │   │   ├── interfaces/
│   │   │   └── tests/
│   │   │
│   │   ├── inventory/
│   │   │   ├── __init__.py
│   │   │   ├── domain/
│   │   │   ├── application/
│   │   │   ├── infrastructure/
│   │   │   ├── interfaces/
│   │   │   └── tests/
│   │   │
│   │   ├── planning_scheduling/
│   │   │   ├── __init__.py
│   │   │   ├── domain/
│   │   │   ├── application/
│   │   │   ├── infrastructure/
│   │   │   ├── interfaces/
│   │   │   └── tests/
│   │   │
│   │   ├── identity_access/
│   │   │   ├── __init__.py
│   │   │   ├── domain/
│   │   │   ├── application/
│   │   │   ├── infrastructure/
│   │   │   ├── interfaces/
│   │   │   └── tests/
│   │   │
│   │   └── reporting/          # Phase 2 stub
│   │       └── __init__.py
│   │
│   ├── shared_kernel/          # Shared kernel
│   │   ├── __init__.py
│   │   ├── base.py             # Base entity, aggregate root, value object
│   │   ├── events.py           # Domain event base, event dispatcher interface
│   │   ├── repository.py       # Base repository interface
│   │   ├── exceptions.py       # Domain exceptions
│   │   ├── value_objects.py    # Shared value objects (DateRange, Money, etc.)
│   │   ├── file_storage.py     # FileStorageService abstraction
│   │   └── pagination.py       # Pagination types & utilities
│   │
│   └── extensions/             # Cross-cutting concerns
│       ├── __init__.py
│       ├── audit.py            # Audit trail middleware / mixin
│       ├── auth.py             # JWT token handling, password hashing
│       └── event_bus.py        # In-process event bus (sync handler dispatch)
│
├── alembic/                    # Database migrations
│   ├── env.py
│   ├── alembic.ini
│   └── versions/               # Migration scripts
│
├── tests/
│   ├── conftest.py             # Shared fixtures (test DB, test client, factories)
│   ├── unit/                   # Unit tests (fast, no DB)
│   ├── integration/            # Integration tests (real DB, real filesystem)
│   ├── e2e/                    # End-to-end API tests
│   └── factories/              # Test data factories (via factory_boy or custom)
│
├── alembic.ini
├── pyproject.toml              # Project metadata, dependencies, tool config
├── Dockerfile
└── .env.example                # Environment variable template
```

### Module Internal Dependency Rule

Within `src/modules/*/`:

```
domain/       → No dependencies on application, infrastructure, or interfaces.
application/  → Depends on domain and shared_kernel only.
infrastructure/→ Depends on domain, shared_kernel, and SQLAlchemy/Alembic.
interfaces/   → Depends on application only.
```

Modules may depend on `shared_kernel` and `extensions` freely.
Modules may NOT import directly from other module `domain/` or `infrastructure/`. Cross-module communication happens via application services or domain events.

---

## 3. SwiftUI App Folder Organization

```
ios/
├── MaintenanceApp/
│   ├── MaintenanceAppApp.swift          # @main App struct
│   ├── ContentView.swift                # Root TabView
│   ├── AppDependencies.swift            # Service locator / DI container
│   │
│   ├── Core/                            # Shared infrastructure
│   │   ├── API/
│   │   │   ├── APIClient.swift          # URLSession-based HTTP client
│   │   │   ├── Endpoint.swift           # Endpoint enum (method, path, headers)
│   │   │   ├── AuthInterceptor.swift    # JWT token injection + refresh
│   │   │   └── DTOs/                    # Request/Response DTOs
│   │   ├── Extensions/
│   │   ├── Protocols/
│   │   ├── KeychainManager.swift
│   │   └── Constants.swift
│   │
│   ├── Modules/                         # Feature modules (one per domain)
│   │   ├── Auth/
│   │   │   ├── Models/
│   │   │   ├── ViewModels/
│   │   │   └── Views/
│   │   ├── Assets/
│   │   │   ├── Models/
│   │   │   ├── ViewModels/
│   │   │   └── Views/
│   │   │       ├── HierarchyView.swift
│   │   │       ├── AssetDetailView.swift
│   │   │       └── AssetSearchView.swift
│   │   ├── Corrective/
│   │   │   ├── Models/
│   │   │   ├── ViewModels/
│   │   │   └── Views/
│   │   ├── Preventive/
│   │   │   ├── Models/
│   │   │   ├── ViewModels/
│   │   │   └── Views/
│   │   ├── Components/
│   │   │   ├── Models/
│   │   │   ├── ViewModels/
│   │   │   └── Views/
│   │   └── Profile/
│   │       ├── Models/
│   │       ├── ViewModels/
│   │       └── Views/
│   │
│   ├── Common/                          # Shared UI components
│   │   ├── Components/                  # Reusable views
│   │   │   ├── StatusBadgeView.swift
│   │   │   ├── BreadcrumbView.swift
│   │   │   ├── SignaturePadView.swift
│   │   │   ├── CameraCaptureView.swift
│   │   │   ├── LoadingIndicator.swift
│   │   │   └── ErrorAlert.swift
│   │   ├── Navigation/
│   │   │   └── Route.swift              # Typed navigation destinations
│   │   └── Styles/                      # Design system
│   │       ├── AppTheme.swift
│   │       └── Typography.swift
│   │
│   └── Resources/
│       ├── Assets.xcassets
│       ├── Localization/
│       └── Preview Content/
│
├── MaintenanceApp.xcodeproj
├── MaintenanceAppTests/                 # Unit tests
│   ├── ViewModels/
│   └── Services/
├── MaintenanceAppUITests/               # UI tests
└── fastlane/                            # Fastlane configuration
    ├── Fastfile
    ├── Appfile
    └── Matchfile
```

---

## 4. Infrastructure Folder Organization

```
infra/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars
│   ├── staging/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars
│
├── modules/
│   ├── container-app/           # Azure Container App resource
│   ├── postgresql/              # Azure PostgreSQL flexible server
│   ├── blob-storage/            # Azure Blob Storage account & container
│   └── networking/              # VNet, subnets, NSG
│
├── global/
│   ├── main.tf                  # Shared resources (resource group, container registry)
│   ├── variables.tf
│   └── outputs.tf
│
├── backend-config/
│   ├── dev.hcl
│   ├── staging.hcl
│   └── prod.hcl
│
└── versions.tf                  # Terraform provider version constraints
```

---

## 5. Naming Conventions

### Python / Backend

| Element | Convention | Example |
|---------|------------|---------|
| Packages / modules | `snake_case` | `asset_management`, `value_objects.py` |
| Classes | `PascalCase` | `Asset`, `CorrectiveEvent`, `AssetService` |
| Functions / methods | `snake_case` | `move_asset()`, `submit_report()` |
| Variables | `snake_case` | `asset_id`, `subsystem_list` |
| Constants | `UPPER_SNAKE_CASE` | `MAX_UPLOAD_SIZE`, `DEFAULT_PAGE_SIZE` |
| Database tables | `snake_case` (plural) | `assets`, `corrective_events`, `asset_closure` |
| Database columns | `snake_case` | `parent_asset_id`, `created_at` |
| API routes | `kebab-case` | `/api/v1/asset-types`, `/corrective-events` |
| Enum members | `UPPER_SNAKE_CASE` | `IN_PROGRESS`, `RESOLVED` |
| Type variables | `PascalCase` | `TEntity`, `TId` |

### Swift / iOS

| Element | Convention | Example |
|---------|------------|---------|
| Files | `PascalCase` | `AssetDetailView.swift`, `APIClient.swift` |
| Classes / structs / enums | `PascalCase` | `AssetService`, `CorrectiveEvent` |
| Properties / methods | `camelCase` | `assetId`, `submitReport()` |
| Enum cases | `camelCase` | `.inProgress`, `.resolved` |
| Protocols | `PascalCase` | `AssetRepositoryProtocol` |
| DTOs | `PascalCase` with `DTO` suffix | `AssetDTO`, `ReportSubmissionDTO` |
| ViewModels | `PascalCase` with `ViewModel` suffix | `AssetListViewModel` |
| Views | `PascalCase` with `View` suffix | `HierarchyView` |

### Infrastructure (Terraform)

| Element | Convention | Example |
|---------|------------|---------|
| Resource names | `snake_case` | `azurerm_container_app` |
| Variable names | `snake_case` | `environment_name`, `app_version` |
| Output names | `snake_case` | `api_endpoint`, `database_host` |
| Module names | `kebab-case` | `container-app`, `blob-storage` |

---

## 6. Python Package Strategy

**Approach:** `src`-layout with namespace packages.

```
backend/
├── src/                          # Source root (PYTHONPATH)
│   ├── app/                      # Top-level app package
│   ├── modules/                  # Domain modules
│   │   ├── asset_management/
│   │   │   ├── domain/
│   │   │   │   ├── __init__.py
│   │   │   │   └── ...           # entities, value_objects, events
│   │   │   ├── application/
│   │   │   │   ├── __init__.py
│   │   │   │   └── ...
│   │   │   ├── infrastructure/
│   │   │   │   ├── __init__.py
│   │   │   │   └── ...
│   │   │   └── interfaces/
│   │   │       ├── __init__.py
│   │   │       └── ...
│   │   └── ...                   # All other modules follow same pattern
│   ├── shared_kernel/
│   │   └── __init__.py
│   └── extensions/
│       └── __init__.py
│
├── tests/
├── alembic/
├── pyproject.toml
└── Dockerfile
```

**Key rules:**
- Every folder under `src/` has an `__init__.py` (regular packages, not namespace packages — simpler for v1).
- `src/` is added to `PYTHONPATH` via `tool.setuptools.packages.find.where = ["src"]` in `pyproject.toml`.
- Import style: `from modules.asset_management.domain.asset import Asset` (fully qualified).
- No circular imports: domain never imports from infrastructure or interfaces.
- Module boundary enforcement is by convention and code review — no `importlinter` in v1 unless violations become frequent.

---

## 7. Dependency Management Strategy

**Tool:** `uv` (or `pip-tools` as fallback).

**Files:**

| File | Purpose |
|------|---------|
| `pyproject.toml` | Project metadata, build system, dev tool config (ruff, mypy, pytest) |
| `requirements/main.in` | Core production dependencies (FastAPI, SQLAlchemy, Pydantic, etc.) |
| `requirements/dev.in` | Dev-only dependencies (pytest, ruff, mypy, factory_boy, etc.) |
| `requirements/main.txt` | Pinned production dependencies (compiled) |
| `requirements/dev.txt` | Pinned all dependencies (compiled, includes `main.txt`) |

**Workflow:**

```bash
# Add dependency
echo "openpyxl" >> requirements/main.in

# Compile
uv pip compile requirements/main.in -o requirements/main.txt
uv pip compile requirements/dev.in -o requirements/dev.txt

# Install
uv pip sync requirements/dev.txt
```

**Docker build** uses `requirements/main.txt` only (no dev deps).

**Key production dependencies (initial):**

| Package | Purpose |
|---------|---------|
| `fastapi` | Web framework |
| `uvicorn[standard]` | ASGI server |
| `sqlalchemy[asyncio]` | ORM |
| `asyncpg` | PostgreSQL async driver |
| `alembic` | Migrations |
| `pydantic-settings` | Environment config |
| `python-jose[cryptography]` | JWT |
| `passlib[bcrypt]` | Password hashing |
| `python-multipart` | File uploads |
| `structlog` | Structured logging |
| `sentry-sdk` | Error tracking |
| `jinja2` | HTML template rendering for PDF generation |
| `weasyprint` | HTML → PDF conversion |
| `httpx` | HTTP client (future integrations) |

---

## 8. Environment Configuration Strategy

**Tool:** Pydantic Settings (`pydantic-settings`).

**Configuration hierarchy:**

1. Default values in `Settings` class
2. `.env` file (local development, gitignored)
3. Environment variables (staging/production)

**File:**

```python
# src/app/config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # Application
    app_name: str = "MaintenanceApp"
    debug: bool = False

    # Database
    database_url: str = "postgresql+asyncpg://app:password@localhost:5432/maintenance"

    # Auth
    jwt_secret_key: str
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 7

    # Storage
    storage_backend: str = "local"  # "local" | "azure_blob"
    storage_local_path: str = "/data/attachments"
    azure_storage_connection_string: str | None = None

    # CORS
    allowed_origins: list[str] = ["*"]

    # File upload limits
    max_upload_size_mb: int = 10
    max_report_total_mb: int = 50

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}
```

**Per-environment files:**

```
.env.development    # Local dev overrides (committed with safe defaults)
.env.staging        # Staging overrides
.env.production     # Production overrides (secrets via env vars, not file)
```

**Usage:**

```python
from app.config import Settings
from functools import lru_cache

@lru_cache
def get_settings() -> Settings:
    return Settings()
```

---

## 9. CI/CD Structure

```
.github/workflows/
├── ci.yml                   # PR checks: lint, typecheck, test
├── cd-staging.yml           # Deploy to staging (on merge to develop)
└── cd-production.yml        # Deploy to production (on tag / manual approval)
```

### ci.yml

```yaml
name: CI
on: pull_request

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "3.12" }
      - run: pip install ruff mypy
      - run: ruff check backend/src
      - run: mypy backend/src

  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env: { POSTGRES_DB: test, POSTGRES_USER: app, POSTGRES_PASSWORD: test }
    steps:
      - uses: actions/checkout@v4
      - run: pip install -r backend/requirements/dev.txt
      - run: pytest backend/tests -v --cov=src --cov-report=term

  docker-build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: docker build -t app:${{ github.sha }} backend/
```

### cd-staging.yml

```yaml
name: Deploy Staging
on:
  push:
    branches: [develop]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: docker build -t app:staging backend/
      - run: docker push $REGISTRY/app:staging
      - run: terraform apply -auto-approve -var="image_tag=staging"
```

---

## 10. Testing Folder Structure

```
backend/tests/
├── conftest.py                        # Shared fixtures
│   ├── db_session()                   # Test database session (create/drop tables)
│   ├── client()                       # FastAPI TestClient
│   ├── auth_headers()                 # JWT token fixtures per role
│   └── factories/                     # Import helpers
│
├── unit/                              # Pure domain logic, no DB
│   ├── asset_management/
│   │   ├── test_asset.py              # Entity invariants, value objects
│   │   └── test_asset_service.py      # Application service logic (mocked repos)
│   ├── maintenance_execution/
│   │   ├── test_corrective_event.py
│   │   └── test_report.py
│   ├── inventory/
│   │   └── test_tool.py
│   ├── component_inventory/
│   │   ├── test_component.py
│   │   ├── test_slot.py
│   │   └── test_component_movement.py
│   ├── planning_scheduling/
│   │   └── test_schedule.py
│   └── identity_access/
│       └── test_user.py
│
├── integration/                       # Real DB, real filesystem
│   ├── asset_management/
│   │   ├── test_asset_repository.py   # CRUD, hierarchy queries
│   │   └── test_closure_table.py      # Closure table sync
│   ├── maintenance_execution/
│   │   ├── test_corrective_repository.py
│   │   └── test_report_submission.py  # Full flow with attachments
│   ├── test_event_store.py
│   └── test_file_storage.py
│
├── e2e/                               # Full API contract tests
│   ├── test_asset_lifecycle.py        # Create → move → reinstall → query history
│   ├── test_corrective_flow.py        # Event → report → submit → close
│   ├── test_auth_flow.py              # Login → access → refresh → logout
│   └── test_hierarchy_queries.py      # Children, subtree, ancestors, time-travel
│
└── factories/                         # Test data factories
    ├── __init__.py
    ├── asset_factory.py
    ├── event_factory.py
    ├── report_factory.py
    └── user_factory.py
```

**Testing principles:**
- **Unit tests:** Mock all external dependencies. Fast, no DB. Test domain logic exclusively.
- **Integration tests:** Use test DB (created per session via pytest fixture). Test repository implementations, event handlers, file storage.
- **E2E tests:** Hit the FastAPI TestClient with full application stack. Test complete user journeys.
- **Factories:** Use `factory_boy` for ORM-based factories. Simple `__init__` kwargs for domain entities.

---

## 11. ADR Organization

**Location:** `docs/adr/`

**File format:** `NNNN-title-with-dashes.md`

**Template:**

```markdown
# ADR-NNNN: Title

**Status:** Proposed | Accepted | Deprecated | Superseded

**Context:**
What is the issue that we're seeing that is motivating this decision or change?

**Decision:**
What is the change that we're proposing and/or doing?

**Consequences:**
What becomes easier or more difficult to do because of this change?
```

**Index file:** `docs/adr/README.md` with table of all ADRs.

**Initial ADRs to create (extracted from architecture Phase 8):**

```
docs/adr/
├── README.md                    # Index of all ADRs
├── 0001-modular-monolith.md
├── 0002-closure-table-strategy.md
├── 0003-asset-assignment-temporal.md
├── 0004-in-process-domain-events.md
├── 0005-filesystem-storage.md
├── 0006-cqrs-lite.md
├── 0007-enum-user-roles.md
├── 0008-polymorphic-reports.md
├── 0009-ios-swiftui.md
├── 0010-rest-over-graphql.md
├── 0011-jwt-auth.md
├── 0012-event-store-same-db.md
├── 0013-optimistic-locking.md
├── 0014-component-inventory-context.md
├── 0015-jinja2-weasyprint-pdf.md
├── 0016-corrective-report-6-sections.md
└── 0017-client-side-share-sheet-email.md
```

---

## 12. Shared Utilities Strategy

### Backend (`src/shared_kernel/`)

| File | Content |
|------|---------|
| `base.py` | `Entity`, `AggregateRoot`, `ValueObject` base classes with `__eq__`, `__hash__`, `__repr__` |
| `events.py` | `DomainEvent` base, `EventDispatcher` interface (sync dispatch via `EventBus`) |
| `repository.py` | `Repository[TEntity, TId]` protocol — `get`, `add`, `update`, `delete`, `exists` |
| `exceptions.py` | `DomainError`, `EntityNotFoundError`, `ValidationError`, `BusinessRuleViolationError` |
| `value_objects.py` | `DateRange`, `TimeRange`, `Email`, `PhoneNumber`, `SerialNumber`, `PartNumber` |
| `file_storage.py` | `FileStorageService` ABC — `upload`, `download`, `delete` |
| `pagination.py` | `Page[T]`, `PageParams`, `PaginatedResult[T]` — offset-based pagination models |
| `types.py` | Type aliases: `EntityId = uuid.UUID`, `SerialNumber = str`, common type annotations |

**Shared kernel rules:**
- Zero dependencies on framework code (no FastAPI, no SQLAlchemy).
- Zero dependencies on modules.
- Dependencies: Python stdlib only + `pydantic` (for value object validation).
- Every shared kernel component must have unit tests.

### Backend (`src/extensions/`)

| File | Content |
|------|---------|
| `audit.py` | SQLAlchemy mixin (`created_at`, `updated_at`, `created_by`, `updated_by`) + event listener |
| `auth.py` | `hash_password`, `verify_password`, `create_access_token`, `decode_token`, `create_refresh_token` |
| `event_bus.py` | `EventBus` singleton — `register(handler)`, `dispatch(event)`. Synchronous, in-process. |

### iOS (`MaintenanceApp/Core/`)

| File | Content |
|------|---------|
| `APIClient.swift` | Generic `request<T: Decodable>` method with JWT injection, retry, error mapping |
| `Endpoint.swift` | Enum with computed `urlRequest` — method, path, headers, body |
| `AuthInterceptor.swift` | Intercepts 401, attempts token refresh, retries original request |
| `KeychainManager.swift` | Read/write/delete for secure token storage |
| `Constants.swift` | API base URL, date formats, pagination defaults |

---

## Appendix: Makefile Commands

```makefile
.PHONY: dev test lint typecheck migrate format clean

# Backend
dev:
	docker compose up -d
	cd backend && uvicorn src.app.main:app --reload

test:
	cd backend && pytest tests -v

lint:
	cd backend && ruff check src tests

typecheck:
	cd backend && mypy src

migrate:
	cd backend && alembic upgrade head

format:
	cd backend && ruff format src tests

clean:
	docker compose down -v
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true

# Infrastructure
terraform-plan:
	cd infra/environments/$(env) && terraform plan

terraform-apply:
	cd infra/environments/$(env) && terraform apply
```
