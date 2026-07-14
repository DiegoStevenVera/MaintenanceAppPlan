# Maintenance App

Monorepo for the maintenance team application.

The project has completed the first iPad mock validation pass and is now entering v1 implementation. The mock remains as the visual/flow reference while the backend and API contracts are built.

## Repository Structure

```text
MaintenanceApp/
  ai/         Project workflow and AI collaboration instructions
  docs/       Product, domain, architecture, mock data, and planning documents
  frontend/   SwiftUI iPad mock-first prototype and future API-connected app
  backend/    Local FastAPI v1 backend, database model, migrations, and services
  infra/      Future deployment and environment configuration
  scripts/    Local helper scripts for development and validation
```

## Current Direction

- Use the approved iPad mock as the reference for v1 flows.
- Build v1 local-first: Mac-hosted backend, iPad client, provider-neutral infrastructure.
- Use Spanish for app-visible labels, seed data, statuses, role labels, and report content.
- Use English for documentation, code, code comments, schema names, and technical identifiers.
- Keep frontend and backend in this single repository until the project needs independent release cycles or permission boundaries.
- Treat `docs/` as the source of truth while the product is being shaped.

## Current Implementation Slice

The first v1 slice is a local FastAPI backend skeleton with versioned API contracts:

1. System healthcheck.
2. Current user profile.
3. Business-anchor asset list/detail/history.
4. Preventive schedule list.
5. Corrective event list/detail/create.

The first repositories are seed-backed and shaped so they can be replaced by SQLAlchemy/PostgreSQL repositories without changing the API DTOs.

Backend scope starts in `backend/`.

Initial iOS scaffold: `frontend/ios/`.
