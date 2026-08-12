# Architecture Blueprint

**Version:** 0.3 (Draft)
**Phase:** Architecture — Complete
**Based on Domain Model:** v0.3
**Last Updated:** 2026-06-16

---

## Current Architectural Clarifications

- v1 is local-first for demonstration and validation. Cloud deployment is intentionally provider-neutral until on-premise, Azure, or AWS is approved.
- The domain uses a unified Asset model. Component is an Asset category, not a separate primary aggregate for v1.
- Business anchor assets are modeled explicitly with asset category/flags and query support through hierarchy closure.
- Maintenance activities and report versions link to assets through role-based scope records, not through a single ambiguous asset field.
- Stage is a rollout/planning scope. Asset and location assignment to stages is many-to-many over time.
- The role model is Maintenance Engineer, Coordinator, Boss, Administrator. Boss is read-only.
- Maintenance activities use the lifecycle SCHEDULED, IN_PROGRESS, COMPLETED, CLOSED.
- Reports are versioned while their parent maintenance activity is editable. Closing the activity freezes report editing until a Coordinator reopens it.
- Corrective reports use dynamic blocks and real-format sections, not a fixed six-section architecture.
- Stop Here is a report/PDF visibility marker for corrective shift handover, not a separate partial-submission state machine.
- v1 PDF generation is required. Email sharing uses iOS Share Sheet; backend email is future.

---

## Table of Contents

1. [Application Architecture](#1-application-architecture)
2. [Modular Monolith Design](#2-modular-monolith-design)
3. [Use Case / Application Service Mapping](#3-use-case--application-service-mapping)
4. [Persistence & Query Architecture](#4-persistence--query-architecture)
5. [API Architecture](#5-api-architecture)
6. [Frontend (SwiftUI) Architecture](#6-frontend-swiftui-architecture)
7. [Infrastructure & Deployment](#7-infrastructure--deployment)
8. [ADR Candidates](#8-adr-candidates)

---

## 1. Application Architecture

### 1.1 Architectural Overview

The system is a **modular monolith** with four layers, organized into bounded-context modules within a single deployable unit. The architecture prioritizes transactional consistency, auditability, and operational simplicity over distributed scalability.

The architecture evolution path is:

`
Modular monolith (v1)
  → Internal domain events with synchronous handlers
  → Extracted read models (when query complexity justifies it)
  → Optional async integrations (SAP, warehouse sync, analytics)
  → Selective service extraction only if operationally justified
`

### 1.2 Four-Layer Architecture

`
┌─────────────────────────────────────────────────────────────┐
│                   INTERFACE / API LAYER                      │
│  FastAPI route handlers, middleware, request/response DTOs   │
│  Auth guards, input validation, API versioning               │
│  Multipart upload handling                                   │
│  WebSocket (future)                                          │
├─────────────────────────────────────────────────────────────┤
│                   APPLICATION LAYER                          │
│  Use case / application services                             │
│  Orchestration of domain services + aggregates               │
│  Transaction coordination                                    │
│  Authorization checks                                        │
│  Event publishing                                            │
│  DTO mapping (API ↔ Application)                             │
├─────────────────────────────────────────────────────────────┤
│                   DOMAIN LAYER                               │
│  Aggregates, Entities, Value Objects                         │
│  Domain Services                                             │
│  Repository interfaces                                       │
│  Domain Events                                               │
│  Domain invariants and validation                            │
│  Aggregate roots (as defined in domain model v0.3)           │
├─────────────────────────────────────────────────────────────┤
│                   INFRASTRUCTURE LAYER                       │
│  Repository implementations (PostgreSQL)                     │
│  File storage (local filesystem / blob)                      │
│  Authentication provider (JWT)                               │
│  Unit of work / transaction management                       │
│  Event handler implementations                               │
│  External service clients (future: SAP, warehouse)           │
└─────────────────────────────────────────────────────────────┘
`

### 1.3 Layer Responsibilities

| Layer | Owns | Depends On | Never Contains |
|-------|------|------------|----------------|
| **Interface** | Route handlers, request/response models, middleware, multipart parsing | Application layer (via service interfaces) | Business logic, domain rules, database access |
| **Application** | Use case orchestration, transaction scope, event publishing, DTO mapping | Domain layer (aggregates, repositories, services) | HTTP details, infrastructure concerns, framework imports |
| **Domain** | Aggregates, entities, value objects, domain events, repository interfaces, domain services, invariants | Nothing (innermost layer) | Framework dependencies, HTTP, database, serialization |
| **Infrastructure** | Repository implementations, file storage, JWT provider, DB context, external clients | Domain layer (repository interfaces), Application layer (event handlers via interface) | Business rules, domain logic |

### 1.4 Dependency Direction Rules

| Rule | Description |
|------|-------------|
| DEP-001 | Dependencies point **inward**: Interface → Application → Domain ← Infrastructure |
| DEP-002 | Domain layer has **zero dependencies** on any framework, library, or infrastructure concern. |
| DEP-003 | Infrastructure implements domain interfaces. It depends on the domain layer, not the other way around. |
| DEP-004 | Application layer depends on domain layer and may reference infrastructure interfaces (DI container wiring). |
| DEP-005 | Interface layer depends on Application layer and Infrastructure (for DI configuration). |
| DEP-006 | No layer may reference another layer's sibling modules directly (e.g., Asset Management interface cannot import Maintenance Execution application service directly — must go through a shared boundary). |
| DEP-007 | Cross-module communication within the application layer uses **in-process domain events** or **shared kernel abstractions**. |

### 1.5 Module Boundaries

The monolith is organized into these logical **modules**, each mapped to a bounded context:

`
src/
├── asset_management/          # Core — Asset hierarchy, types, replacements
│   ├── interface/             # API routes for asset operations
│   ├── application/           # Asset use cases
│   ├── domain/                # Aggregates: Asset, AssetType, AssetAssignment, etc.
│   └── infrastructure/        # PostgreSQL repositories, file storage
│
├── component_inventory/       # Core — Serialized components, slots, movements
│   ├── interface/             # API routes for components, slots, locations
│   ├── application/           # Component movement, slot configuration
│   ├── domain/                # Aggregates: ComponentType, Component, SlotLocation, Location
│   └── infrastructure/        # PostgreSQL repositories
│
├── maintenance_execution/     # Core — Preventive + Corrective reports
│   ├── interface/             # Report and event API routes
│   ├── application/           # Report submission, event lifecycle, Stop Here
│   ├── domain/                # Aggregates: CorrectiveEvent, Reports, Tasks
│   └── infrastructure/        # Report repositories
│
├── inventory/                 # Supporting — Tools, warehouse, certifications
│   ├── interface/             # Tool and warehouse API routes
│   ├── application/           # Tool usage, warehouse movements
│   ├── domain/                # Aggregates: Tool, ToolCertification, ConsumableType
│   └── infrastructure/        # Tool repositories
│
├── planning_scheduling/       # Future-separable — Templates, plans, schedules
│   ├── interface/             # Planning API routes
│   ├── application/           # Schedule creation, plan import
│   ├── domain/                # Aggregates: Templates, PlanEntries, Schedules
│   └── infrastructure/        # Planning repositories
│
├── identity_access/           # Shared — Users, authentication, authorization
│   ├── interface/             # Auth routes, user management
│   ├── application/           # Login, token refresh, role checks
│   ├── domain/                # Aggregate: User
│   └── infrastructure/        # JWT provider, password hashing
│
├── reporting/                 # Future — Read models, dashboards (empty for v1)
│
└── shared_kernel/             # Cross-cutting — Base types, domain event bus, common value objects
    ├── domain/                # DomainEvent base class, Entity base, ValueObject base, UUID generation
    └── infrastructure/        # Event bus implementation (in-process)
`

### 1.6 Shared Kernel Rules

| Rule | Description |
|------|-------------|
| SK-001 | The shared kernel contains only: base types (Entity, AggregateRoot, ValueObject), DomainEvent base class, Unit of Work interface, and UUID generation. |
| SK-002 | No business logic lives in the shared kernel. |
| SK-003 | All modules may reference the shared kernel. |
| SK-004 | The shared kernel must never reference any module. |
| SK-005 | Common value objects (Address, DateRange, Money) shared across modules live here. For this domain, the primary shared VOs are Participant, Signature, ToolUsage, and Attachment. |

### 1.7 Cross-Cutting Concerns

| Concern | Strategy | Layer |
|---------|----------|-------|
| **Logging** | Structured logging with correlation ID per request. Passed through application and domain via context object. | Infrastructure (via middleware) → Application → Domain (accepts logger interface) |
| **Validation** | Two-stage: input validation (interface layer via Pydantic), domain invariant validation (domain layer via aggregate methods). | Interface + Domain |
| **Authentication** | JWT bearer tokens validated at the interface layer. User identity injected into application context. | Interface (middleware) → Application (context) |
| **Authorization** | Role-based checks in application layer. Resource-scoped access (user scoped to project). | Application layer |
| **Audit** | Domain events persisted to event store. All aggregate mutations go through domain events. | Domain (events) + Infrastructure (event store) |
| **Exception handling** | Domain exceptions (typed by business rule) mapped to HTTP error codes in interface layer. | Interface (middleware) |
| **Transaction management** | Unit of Work pattern wraps application service operation. One transaction per use case. Rollback on any domain exception. | Infrastructure (UoW) + Application (scope) |
| **File storage** | Abstraction interface in shared kernel. Local filesystem implementation for v1, Blob storage implementation for future. | Infrastructure (filesystem) |

### 1.8 Transaction Boundaries

| Rule | Description |
|------|-------------|
| TX-001 | One application service operation = one transaction boundary. |
| TX-002 | Aggregates loaded within a transaction participate in that transaction until commit. |
| TX-003 | Cross-aggregate consistency is achieved by: (a) loading all required aggregates within the same Unit of Work; (b) coordinating via the Application Service or a Domain Service; (c) committing atomically. |
| TX-004 | For the v1 monolith, all operations use a **single database transaction** managed by the Unit of Work. |
| TX-005 | Operations that must span multiple aggregates (replacement, report submission, event closure) use an Application Service that orchestrates the domain services within one transaction. |
| TX-006 | Event handlers that update read models (closure table, timeline projections) run **in-process** within the same transaction for critical paths, or in a **background task** after commit for non-critical paths. |

### 1.9 Domain Service Orchestration Rules

| Rule | Description |
|------|-------------|
| ORC-001 | Domain services encapsulate operations that span multiple aggregates. They coordinate but do NOT manage transactions (that is the Application Service's role). |
| ORC-002 | Application services call domain services, passing in repository interfaces and unit of work. |
| ORC-003 | Domain services return result objects (not side effects on infrastructure). |
| ORC-004 | Example: AssetReplacementService coordinates Asset (×2), AssetReplacement, and AssetAssignment. The Application Service opens the transaction, the Domain Service performs the logic, the Application Service commits. |

### 1.10 Read-Model Strategy

| Rule | Description |
|------|-------------|
| RM-001 | The operational write model is the canonical source of truth (normalized tables for aggregates). |
| RM-002 | Read models are derived projections maintained synchronously within the same transaction or immediately after commit. |
| RM-003 | For v1, the following read models are explicitly defined: (a) Asset closure table for hierarchy traversal; (b) CorrectiveEvent timeline view (denormalized); (c) AssetAssignment for temporal queries (this is part of the domain, not a read model, but serves read purposes). |
| RM-004 | No separate read/write application layers. No separate databases. |
| RM-005 | The closure table is a read projection maintained synchronously (same transaction as hierarchy mutations). See §4.2. |

### 1.11 Internal Event Handling Approach

| Rule | Description |
|------|-------------|
| EVT-001 | Domain events are plain Python objects raised by aggregate methods after state changes. |
| EVT-002 | An in-process event bus collects events raised during a transaction and dispatches them after the aggregate operation completes, but before the transaction commits (for critical handlers) or after commit (for non-critical handlers). |
| EVT-003 | Handlers are registered at application startup via DI. Each handler implements a simple interface: handle(event: DomainEvent) -> None. |
| EVT-004 | The event bus is a simple in-process publish/subscribe mechanism. No message broker, no serialization, no external dependencies. |
| EVT-005 | Exactly which events exist is defined in the domain model v0.3 (§19). |

### 1.12 Authorization Strategy

| Aspect | Approach |
|--------|----------|
| **Authentication** | JWT bearer tokens. Token contains: userId, username, role, projectId. Short-lived access token (15 min) + long-lived refresh token (7 days). |
| **Role model** | Enum-based for v1: MAINTENANCE_ENGINEER, COORDINATOR, BOSS, ADMINISTRATOR. Boss is read-only. Future RBAC can evolve later. |
| **Resource scoping** | All data is scoped to a project. The JWT contains the user's projectId. All queries filter by this scope. Cross-project access is prohibited. |
| **Permission checks** | Authorization logic lives in the Application layer. Each use case checks: (a) is the user authenticated? (b) does the user's role permit this action? (c) does the user's project scope match the resource? |
| **Report ownership** | Maintenance Engineers can edit reports while the parent maintenance activity is not CLOSED. Coordinators and Administrators can reopen CLOSED activities. Boss is read-only. Each finalized edit creates a version. |
| **Boss access** | Boss has read-only access to all reports and dashboards. Boss cannot create or modify operational data. |

### 1.13 File Storage Strategy

| Aspect | Approach |
|--------|----------|
| **Abstraction** | FileStorage interface in shared_kernel.domain. Methods: store(file: BinaryIO, path: str) -> str, 
etrieve(path: str) -> BinaryIO, delete(path: str). |
| **v1 implementation** | Local filesystem storage. Uploaded files stored under storage/{module}/{entity_id}/{filename}. Metadata (original filename, content type, size) stored in database Attachment record. |
| **Future implementation** | Azure Blob Storage (or equivalent) via the same interface. Migration is transparent to the application. |
| **Path scheme** | ttachments/{report_type}/{report_id}/{uuid}{ext} where report_type = preventive or corrective. |
| **Content types** | Primarily images (JPEG, PNG, HEIC). Future: PDF documents. |
| **Size limits** | No hard limit in domain. Infrastructure handles large file streaming. |

### 1.14 Auditability Strategy

| Concern | Approach |
|---------|----------|
| **Domain event store** | All domain events are persisted to an event_store table: id, event_type, aggregate_type, aggregate_id, payload (JSON), occurred_at, correlation_id. |
| **Report versioning** | Reports are versioned. Prior versions and generated PDFs are retained. A CLOSED maintenance activity blocks further editing until reopened by Coordinator or Administrator. |
| **Signature traceability** | Signatures are stored as image records linked to the authenticated user. The user_id is captured at signature time and stored immutably with the report. |
| **Asset mutation audit** | Every change to Asset.parentAsset or lifecycleStatus generates an AssetAssignment record and a domain event. |
| **User action audit** | All state-changing API calls are logged with: userId, action, resource type, resource id, timestamp, IP, correlation id. |
| **Temporal queries** | AssetAssignment enables temporal reconstruction of the hierarchy at any point in time. |
| **Retention** | No data is ever physically deleted. Status-based soft deletion (lifecycleStatus, isActive) is used throughout. |

---

## 2. Modular Monolith Design

### 2.1 Module Dependency Map

`
identity_access (shared)
     │
     ├───────────────────────────────────────────────────────────────┐
     ▼                                                               │
asset_management ◄──────────────────────────────────────┐            │
     │                                                   │            │
     ├──► maintenance_execution (references Asset)       │            │
     │         │                                         │            │
     │         ├──► component_inventory (via events)     │            │
     │         ├──► inventory (references Tool, Report)  │            │
     │         │                                         │            │
     │         └──► planning_scheduling (via events)     │            │
     │                                                    │            │
     ├──► reporting (future, consumes events)             │            │
     │                                                    │            │
     └──► component_inventory (references Asset for slot) │            │
                                                          │            │
      (AssetReplacementService lives in asset_management, │            │
       called by maintenance_execution via domain service)┘            │
                                                                       │
      component_inventory (standalone, references Asset for slot) ─────┘
                                                                       │
      planning_scheduling (future-separable)                           │
           │                                                          │
           └──► maintenance_execution (via MaintenanceSchedule)       │
                                                                       │
      inventory (standalone, references Asset for warehouse) ──────────┘
`

### 2.2 Asset Management Module

**Package:** sset_management

**Responsibilities:**
- Manage the recursive asset hierarchy (CRUD, move, remove).
- Maintain AssetType catalog.
- Enforce asset identity rules (serial/part number policies).
- Manage AssetCompositionRule definitions (per subsystem).
- Execute AssetReplacement operations (cross-aggregate orchestration).
- Maintain AssetAssignment historical records.
- Manage GeographicLocation catalog.

**Aggregates Owned:**

| Aggregate Root | Key Entities / VOs Inside | Repositories Needed |
|---------------|---------------------------|---------------------|
| Asset | Asset (single node), Position (VO), EquipmentCategory (ref), EquipmentKind (ref) | AssetRepository: findById, findByParent, findBySerialNumber, findByPartNumber, findAncestors, findDescendants (via closure table) |
| AssetType | AssetType | AssetTypeRepository: findById, findAll, findByPolicy |
| EquipmentCategory | EquipmentCategory | EquipmentCategoryRepository: findBySubsystem |
| EquipmentKind | EquipmentKind | EquipmentKindRepository: findByEquipmentCategory |
| AssetCompositionRule | AssetCompositionRule | CompositionRuleRepository: findBySubsystemAndParentType |
| AssetAssignment | AssetAssignment | AssetAssignmentRepository: findActiveByAsset, findByAssetAndTime, findLineageByAsset |
| AssetReplacement | AssetReplacement | AssetReplacementRepository: findByEvent, findByAsset, findChain |
| GeographicLocation | GeographicLocation (recursive) | GeographicLocationRepository: findById, findChildren, findByLevel |

**Domain Services:**

| Service | Responsibility | Involved Aggregates |
|---------|---------------|---------------------|
| AssetReplacementService | Coordinates atomic replacement: close old AssetAssignment, create new AssetAssignment, update both Assets, create AssetReplacement record | Asset (×2), AssetReplacement, AssetAssignment |
| AssetCompositionService | Resolves composition rules for (subsystem, parentType). Validates child type, position, quantity. | AssetCompositionRule, AssetType |
| AssetSearchService | Provides hierarchical drill-down and direct search across the asset tree. | Asset (query only) |
| HierarchyMutationService | Coordinates non-replacement moves (reinstall, warehouse transfer, parent change without replacement). | Asset, AssetAssignment |
| EquipmentCategoryService | Manages N1/N2 classification catalog per subsystem. | EquipmentCategory, EquipmentKind |

**Domain Events Published:**

| Event | When | Payload |
|-------|------|---------|
| AssetCreated | New asset registered | assetId, assetTypeId, subsystemId, registrationMethod, timestamp |
| AssetHierarchyModified | Asset parent or position changed | assetId, oldParentId, newParentId, oldPosition, newPosition, timestamp |
| AssetLifecycleStatusChanged | Asset lifecycle status changed | assetId, oldStatus, newStatus, reason, timestamp |
| AssetReplacementCompleted | Replacement executed | replacementId, removedAssetId, installedAssetId, parentAssetId, timestamp, correctiveEventId? |

**Integration Points:**
- Called by: Maintenance Execution (when corrective task triggers replacement)
- Calls: Identity & Access (via shared kernel)
- Consumed by: Infrastructure (closure table updater)

### 2.3 Maintenance Execution Module

**Package:** maintenance_execution

**Responsibilities:**
- Manage CorrectiveEvent lifecycle (create, start, resolve, close, reopen).
- Manage CorrectiveReport creation, drafting, submission.
- Manage PreventiveReport creation, drafting, submission.
- Manage MaintenanceTemplate definitions (imported from Engineering).
- Manage TaskType configuration per subsystem.
- Capture participant signatures on reports.
- Link AssetReplacement operations (delegated to Asset Management).

**Aggregates Owned:**

| Aggregate Root | Key Entities / VOs Inside | Repositories Needed |
|---------------|---------------------------|---------------------|
| CorrectiveEvent | CorrectiveEvent, ReopenRecord (VO) | CorrectiveEventRepository: findById, findByStatus, findByAsset, findOpenByAssetAndSubsystem |
| CorrectiveReport | CorrectiveReport, CorrectiveTask (polymorphic: StandardActivity, ReplacementTask), DynamicReportBlock, StopHereMarker | CorrectiveReportRepository: findByEvent, findById, findEditableByEventAndShift |
| PreventiveReport | PreventiveReport, StepResult (VO), TestExecutionResult (VO), PersonnelEntry (VO) | PreventiveReportRepository: findBySchedule, findById, findByAsset |
| MaintenanceTemplate | MaintenanceTemplate, MaintenanceStep (VO), TestDefinition (VO), TestResultOption (VO), ToolRequirement (VO), PersonnelRequirement (VO) | MaintenanceTemplateRepository: findById, findBySubsystem, findActive |
| TaskType | TaskType | TaskTypeRepository: findBySubsystem, findById |

**Anti-Corruption Boundaries:**

| Boundary | Purpose | Mechanism |
|----------|---------|-----------|
| Asset Management | Maintenance Execution references Assets but does not own them | AssetRepository interface (read-only queries) is injected. Asset mutation is done via AssetReplacementService (domain service from Asset Management module). |
| Component Inventory | ReplacementTask triggers ComponentMovement(s) | ComponentMovementService interface is injected. Maintenance Execution does not mutate component state directly. |
| Inventory | Reports reference Tools via ToolUsage (VO) | ToolRepository interface (read-only lookup by serial). Maintenance Execution does not mutate Tool state. |

**Domain Services:**

| Service | Responsibility | Involved Aggregates |
|---------|---------------|---------------------|
| CorrectiveEventLifecycleService | Manages state transitions: start, resolve, close, reopen. Validates preconditions (no overlapping IN_PROGRESS events, all reports submitted before resolve). | CorrectiveEvent, CorrectiveReport (query) |
| ReportSubmissionService | Validates completeness (signatures, required fields), transitions documentStatus to SUBMITTED, updates related entities (event timeline, schedule status), publishes events. | CorrectiveReport / PreventiveReport, CorrectiveEvent (status check), MaintenanceSchedule (status update) |
| SignatureCaptureService | Records a drawn signature for a user on a report. Validates user authentication link. | Signature, Participant |
| StopHereMarkerService | Records the point up to which a corrective report should be printed/shared when work continues across shifts. | CorrectiveReport |
| CorrectiveReportVersioningService | Creates new report versions while the parent event is not CLOSED. | CorrectiveReport |

**Domain Events Published:**

| Event | When | Payload |
|-------|------|---------|
| CorrectiveEventCreated | First maintenance engineer starts event | eventId, eventCode, sapCode, subsystemId, affectedAssetId, timestamp |
| CorrectiveEventStatusChanged | Event transitions state | eventId, oldStatus, newStatus, userId, reason, timestamp |
| CorrectiveReportSubmitted | Report finalized | reportId, eventId, shift, timestamp, participantIds, assetReplacementIds |
| CorrectiveReportStopHereMarked | Stop Here marker changed | reportId, eventId, markerBlockId, note, timestamp |
| PreventiveReportSubmitted | Report finalized | reportId, templateId, scheduleId, timestamp, participantIds |
| MaintenanceScheduleCompleted | Schedule fulfilled by report submission | scheduleId, reportId, templateId, actualDate, timestamp |

**Integration Points:**
- Calls: Asset Management (AssetReplacementService for replacement operations, AssetRepository for asset lookups)
- Calls: Component Inventory (ComponentMovementService for component movements triggered by ReplacementTask)
- Calls: Inventory (ToolRepository for tool validation)
- Called by: Planning & Scheduling (schedule → report reference)
- Consumed by: Infrastructure (report immutability enforcement, timeline projection)

### 2.4 Component Inventory Module

**Status:** Superseded for v1 by the unified Asset model.

The earlier draft separated `Component` from `Asset`. For v1, component-like items are represented as Assets with category = COMPONENT. Warehouse stock is represented by Asset lifecycle status and location/assignment records. A separate Component Inventory bounded context may be reconsidered later only if warehouse operations become complex enough to justify it.

**Package:** component_inventory

**Responsibilities:**
- Manage ComponentType catalog (part-number-based component definitions).
- Manage inventory of serialized Component instances with full lifecycle tracking.
- Manage SlotLocation hierarchy (physical slots within equipment, organized per EquipmentKind).
- Manage physical Location catalog (warehouse zones, shelves, bins).
- Track ComponentMovement events (install, remove, transfer, repair, scrap).
- Coordinate with Maintenance Execution on ReplacementTask-triggered movements.

**Aggregates Owned:**

| Aggregate Root | Key Entities / VOs Inside | Repositories Needed |
|---------------|---------------------------|---------------------|
| ComponentType | ComponentType | ComponentTypeRepository: findById, findByPartNumber, findBySubsystem |
| Component | Component, ComponentMovement (collection) | ComponentRepository: findById, findBySerialNumber, findByCurrentSlot, findByCurrentAsset, findByStatus, findByComponentType |
| SlotLocation | SlotLocation (recursive), SlotType, SlotImage | SlotLocationRepository: findById, findByEquipmentKind, findByParentSlot, findAvailable |
| Location | Location, LocationType | LocationRepository: findById, findByType, findChildren |
| SlotImage | SlotImage | SlotImageRepository: findBySlotLocation |

**Domain Services:**

| Service | Responsibility | Involved Aggregates |
|---------|---------------|---------------------|
| ComponentMovementService | Coordinates component movements across slots, warehouses, and lifecycle states. Validates slot compatibility (SlotType × ComponentType). Creates ComponentMovement records. | Component, SlotLocation, Location |
| ReplacementMovementCoordinator | Called by Maintenance Execution when a ReplacementTask completes. Creates ComponentMovement for removed component (→ REMOVED) and installed component (→ INSTALLED at slot). | Component (×2), SlotLocation, AssetReplacement |

**Domain Events Published:**

| Event | When | Payload |
|-------|------|---------|
| ComponentInstalled | Component placed in slot | componentId, slotLocationId, assetId, replacementTaskId, correctiveEventId?, timestamp |
| ComponentRemoved | Component taken out of slot | componentId, slotLocationId, assetId, replacementTaskId, correctiveEventId?, timestamp |
| ComponentStatusChanged | Status transition (warehouse, repair, scrap) | componentId, oldStatus, newStatus, location, timestamp |

**Integration Points:**
- Called by: Maintenance Execution (via ComponentMovementService for ReplacementTask)
- References: Asset Management (SlotLocation references Asset for equipment context)

### 2.5 Inventory Module

**Package:** inventory

**Responsibilities:**
- Manage Tool catalog (serial-number-tracked maintenance equipment).
- Manage ToolCertification records (calibration, periodic inspection).
- Record ToolUsage during maintenance activities.
- Manage ConsumableType catalog (oils, greases, general consumables).
- Manage WarehouseLocation catalog.

**Aggregates Owned:**

| Aggregate Root | Key Entities / VOs Inside | Repositories Needed |
|---------------|---------------------------|---------------------|
| Tool | Tool, ToolCertification (collection) | ToolRepository: findBySerialNumber, findById, findByAvailability |
| ToolCertification | ToolCertification | ToolCertificationRepository: findByTool, findByExpirationDate |
| ConsumableType | ConsumableType | ConsumableTypeRepository: findById, findAll |
| WarehouseLocation | WarehouseLocation | WarehouseLocationRepository: findById, findAll |

**Domain Events Published:**

| Event | When | Payload |
|-------|------|---------|
| ToolUsed | Tool logged on report submission | toolId, reportId, reportType, timestamp |

**Integration Points:**
- Called by: Maintenance Execution (tool lookup, usage recording)
- References: Asset Management (warehouse locations)

### 2.6 Planning & Scheduling Module

**Package:** planning_scheduling

**Responsibilities:**
- Manage MaintenanceTemplate definitions (imported from Engineering).
- Manage MaintenancePlanEntry (PCON plan, annual/monthly planning).
- Manage MaintenanceSchedule (weekly concrete schedules).
- Future: native PCON import algorithm.

**Aggregates Owned:**

| Aggregate Root | Key Entities / VOs Inside | Repositories Needed |
|---------------|---------------------------|---------------------|
| MaintenanceTemplate | MaintenanceTemplate (shared with Maintenance Execution? — clarify below) | MaintenanceTemplateRepository |
| MaintenancePlanEntry | MaintenancePlanEntry | MaintenancePlanEntryRepository: findByMonth, findByYear, findByTemplate |
| MaintenanceSchedule | MaintenanceSchedule | MaintenanceScheduleRepository: findByDate, findByMaintenance Engineer, findByPlan |

**Note on MaintenanceTemplate ownership:** The domain model v0.3 places MaintenanceTemplate in the Preventive Maintenance context, which maps to Maintenance Execution in this architecture. However, Planning & Scheduling also needs read access to templates. For v1, MaintenanceTemplate is owned by **Maintenance Execution** and exposed to Planning & Scheduling via a read-only repository interface. If the Planning module is later extracted, it would either: (a) reference the template via the monolith's shared kernel API, or (b) cache its own copy via domain events.

**Integration Points:**
- Calls: Maintenance Execution (template lookup via read-only interface)
- Called by: (future) PCON import process

### 2.7 Identity & Access Module

**Package:** identity_access

**Responsibilities:**
- Manage User accounts and authentication.
- Issue and validate JWT tokens.
- Provide authorization context (role, project scope) to all other modules.
- Manage User drawn signatures.

**Aggregates Owned:**

| Aggregate Root | Key Entities / VOs Inside | Repositories Needed |
|---------------|---------------------------|---------------------|
| User | User, Signature (referenced, but Signature is a separate conceptual entity) | UserRepository: findById, findByUsername, findByProject |

**Shared Kernel Entities (used by multiple modules but owned here):**

| Entity | Used By | Ownership Note |
|--------|---------|----------------|
| User | All modules (references) | Owned by Identity & Access. Other modules have read-only reference. |
| Participant | Maintenance Execution (reports) | Created by Maintenance Execution, references User. Not part of Identity module. |
| Signature | Maintenance Execution (linked to Participant) | Stored with report data. User reference for traceability. |

**Integration Points:**
- Called by: All modules (for authentication and authorization context)
- Provides: JWT validation middleware shared across all modules

### 2.8 Reporting Module (Future)

**Package:** 
eporting

**Status:** Empty for v1. Will be built when dashboard/analytics requirements emerge.

**Architectural Notes:**
- Will consume domain events from all modules.
- Will build read projections (aggregated KPIs, MTBF/MTTR, trend charts).
- Will be non-authoritative (read-only, derived data).
- Will not modify any domain aggregates.

---

## 3. Use Case / Application Service Mapping

Each use case below defines:
- **Input DTO**: Data received from the API layer.
- **Orchestration flow**: Step-by-step application service logic.
- **Aggregates involved**: Which aggregates are loaded, modified, or created.
- **Transaction scope**: What operations are covered by a single database transaction.
- **Domain events emitted**: Events raised during the operation.
- **Validations**: Business rules checked before execution.
- **Failure scenarios**: Expected error conditions and their handling.

### 3.1 Use Case: Start Corrective Maintenance

| Aspect | Detail |
|--------|--------|
| **Module** | Maintenance Execution |
| **Application Service** | StartCorrectiveMaintenanceService |
| **Input DTO** | { subsystemId, affectedAssetId, sapCode?, occurrenceTimestamp, locationSnapshotId, description, failureType, initiatingEngineerId } |
| **Orchestration** | 1. Load Asset (affectedAssetId) — verify exists and is ACTIVE. 2. Check no open IN_PROGRESS event exists for this (subsystem, asset) — reject if conflict. 3. Create CorrectiveEvent with status = NOT_STARTED. 4. Transition to IN_PROGRESS via startMaintenance(). 5. Set maintenanceStartTimestamp. 6. Save event. 7. Publish CorrectiveEventCreated. |
| **Aggregates involved** | CorrectiveEvent (create + transition) |
| **Transaction scope** | Single transaction: create event + status transition |
| **Events emitted** | CorrectiveEventCreated |
| **Validations** | Asset exists and is ACTIVE. No overlapping IN_PROGRESS event for same (subsystem, asset). SAP code is optional free text. Location must exist. |
| **Failure scenarios** | Asset not found → 404. Overlapping event → 409 Conflict. Invalid subsystem → 400. |

### 3.2 Use Case: Submit Corrective Report

| Aspect | Detail |
|--------|--------|
| **Module** | Maintenance Execution |
| **Application Service** | SubmitCorrectiveReportService |
| **Input DTO** | { correctiveEventId, shift, startTimestamp, endTimestamp?, sapCode?, affectedAssetId, locationSnapshotId, failureDescription, faultType, dynamicBlocks[], tasks[], toolUsages[], participantSignatures[], attachmentIds[], stopHereMarker? } |
| **Orchestration** | 1. Load CorrectiveEvent — verify status is IN_PROGRESS or COMPLETED, not CLOSED. 2. Load all referenced Assets, Tools, Participants. 3. Create or update the editable CorrectiveReport version for this event and shift. 4. For each task: if taskType = ReplacementTask, invoke AssetReplacementService and stock movement services. 5. Link each AssetReplacement to the task. 6. If stopHereMarker exists, store it as a PDF/report visibility marker. 7. Add all participant signatures. 8. Finalize the current version. 9. From the read-only version screen, generate the PDF and persist the artifact. 10. Publish CorrectiveReportVersionFinalized. |
| **Aggregates involved** | CorrectiveEvent (read), CorrectiveReport (create/update version), CorrectiveTask (create × N — polymorphic), AssetReplacement (create × N via Asset Management), Asset (update × N), AssetAssignment (close + create × N) |
| **Transaction scope** | Single transaction: report version + tasks + replacements + hierarchy updates. PDF generation may run after commit but must be traceably linked to the finalized version. |
| **Events emitted** | CorrectiveReportVersionFinalized, CorrectiveReportStopHereMarked (if marker), AssetReplacementCompleted (×N), AssetHierarchyModified (×N), ToolUsed (×N) |
| **Validations** | Event is editable. All referenced assets exist. Participant signatures are present. Dynamic block data is valid. If task type is ReplacementTask, AssetReplacement and stock movement records must be created. |
| **Failure scenarios** | Event not found → 404. Event CLOSED → 422 (must reopen). Missing participant signatures → 422. Replacement validation fails → 422. Dynamic block data invalid → 422. |

### 3.3 Use Case: Submit Preventive Report

| Aspect | Detail |
|--------|--------|
| **Module** | Maintenance Execution |
| **Application Service** | SubmitPreventiveReportService |
| **Input DTO** | { templateId, scheduleId?, involvedAssetIds[], locationSnapshotId, actualDate, shift, stepResults[], toolUsages[], materialsConsumed?, observations?, conclusions?, participantIds[], attachmentIds[] } |
| **Orchestration** | 1. Load MaintenanceTemplate (versioned reference). 2. Load schedule (if provided) — verify status is SCHEDULED or IN_PROGRESS. 3. Load involved Assets. 4. Create PreventiveReport with documentStatus = DRAFT. 5. Map stepResults to template steps (validate stepIndex exists). 6. Add all Participants with signatures. 7. Call ReportSubmissionService.submit(report) — validate, transition to SUBMITTED. 8. If linked to schedule, update schedule status to COMPLETED. 9. Save report. 10. Publish PreventiveReportSubmitted + (if scheduled) MaintenanceScheduleCompleted. |
| **Aggregates involved** | PreventiveReport (create), MaintenanceSchedule (update status), MaintenanceTemplate (read-only) |
| **Transaction scope** | Single transaction: report + schedule update |
| **Events emitted** | PreventiveReportSubmitted, MaintenanceScheduleCompleted (if scheduled), ToolUsed (×N) |
| **Validations** | Template exists and is active. At least one participant with signature. All step results map to valid template step indexes. Schedule (if linked) is not already COMPLETED. Preventive activity is single-shift only. |
| **Failure scenarios** | Template not found → 404. Schedule already COMPLETED → 409. Missing signature → 422. Step index mismatch → 422. |

### 3.4 Use Case: Perform Asset Replacement

| Aspect | Detail |
|--------|--------|
| **Module** | Asset Management (called from Maintenance Execution) |
| **Application Service** | PerformAssetReplacementService |
| **Input DTO** | { parentAssetId, position, removedAssetId, installedAssetId, source, destination, reason, responsibleUserId, correctiveEventId?, correctiveReportId? } |
| **Orchestration** | 1. Load parent Asset. 2. Load removed Asset — verify it is currently a child of parent at position. 3. Load installed Asset — if not found, create new Asset with registrationMethod = MANUAL. 4. Verify installed Asset is not already active in another parent. 5. Call AssetReplacementService.execute(): (a) close removedAsset's active AssetAssignment (set deactivatedAt); (b) close installedAsset's previous assignment (if any); (c) update removedAsset: parentAsset = null, lifecycleStatus = REMOVED; (d) update installedAsset: parentAsset = parent, position = position, lifecycleStatus = ACTIVE; (e) create new AssetAssignment for installedAsset; (f) create AssetReplacement record. 6. Save all changes. 7. Publish events. |
| **Aggregates involved** | Asset (×2 — removed + installed), AssetReplacement (create), AssetAssignment (close × 1-2, create × 1) |
| **Transaction scope** | Single transaction. This is the most coordination-intensive operation. Must be atomic. |
| **Events emitted** | AssetReplacementCompleted, AssetHierarchyModified (×2), AssetLifecycleStatusChanged (×2) |
| **Validations** | Removed asset is currently a child of parentAsset at specified position. Installed asset is not already active elsewhere (unless being moved). Source and destination are recorded (free text allowed if location not in DB). |
| **Failure scenarios** | Parent not found → 404. Removed asset not found or not a child → 422. Installed asset is the same as removed → 422. Concurrency conflict (someone else modified hierarchy) → 409. |

### 3.5 Use Case: Move Asset to Warehouse

| Aspect | Detail |
|--------|--------|
| **Module** | Asset Management |
| **Application Service** | MoveAssetToWarehouseService |
| **Input DTO** | { assetId, warehouseLocationId, reason, responsibleUserId } |
| **Orchestration** | 1. Load Asset — verify it is ACTIVE and has a parentAsset. 2. Load WarehouseLocation. 3. Close current AssetAssignment. 4. Update Asset: parentAsset = null, lifecycleStatus = IN_WAREHOUSE, geographicLocation = warehouseLocation. 5. Create WarehouseStock entry. 6. Save. 7. Publish events. |
| **Aggregates involved** | Asset (update), AssetAssignment (close), WarehouseStock (create) |
| **Transaction scope** | Single transaction |
| **Events emitted** | AssetLifecycleStatusChanged, AssetHierarchyModified |
| **Validations** | Asset is ACTIVE. Asset has a parentAsset (is not already warehouse). Warehouse location exists. |
| **Failure scenarios** | Asset not found → 404. Asset already in warehouse → 422. |

### 3.6 Use Case: Reinstall Asset

| Aspect | Detail |
|--------|--------|
| **Module** | Asset Management |
| **Application Service** | ReinstallAssetService |
| **Input DTO** | { assetId, newParentAssetId, position, reason, responsibleUserId } |
| **Orchestration** | 1. Load Asset — verify lifecycleStatus is REMOVED or IN_WAREHOUSE. 2. Load new parent Asset — verify it is ACTIVE. 3. If IN_WAREHOUSE, remove WarehouseStock entry. 4. Close current AssetAssignment (if any). 5. Update Asset: parentAsset = newParent, position = position, lifecycleStatus = ACTIVE. 6. Create new AssetAssignment. 7. Save. 8. Publish events. |
| **Aggregates involved** | Asset (update), AssetAssignment (close + create), WarehouseStock (delete if applicable) |
| **Transaction scope** | Single transaction |
| **Events emitted** | AssetLifecycleStatusChanged, AssetHierarchyModified |
| **Validations** | Asset is in valid state for reinstall (REMOVED or IN_WAREHOUSE). New parent is ACTIVE. Position is unique within new parent. |
| **Failure scenarios** | Asset not found → 404. Asset is already ACTIVE → 422. |

### 3.7 Use Case: Assign Maintenance Engineers to Schedule

| Aspect | Detail |
|--------|--------|
| **Module** | Planning & Scheduling |
| **Application Service** | AssignMaintenance EngineersToScheduleService |
| **Input DTO** | { scheduleId, maintenance engineerUserIds[] } |
| **Orchestration** | 1. Load MaintenanceSchedule. 2. Load all Users (verify role = MAINTENANCE_ENGINEER or COORDINATOR). 3. Assign maintenance engineers to schedule. 4. Save. 5. (Optional future: publish notification event). |
| **Aggregates involved** | MaintenanceSchedule (update assignedEngineers) |
| **Transaction scope** | Single transaction |
| **Events emitted** | None currently (future: Maintenance EngineersAssigned) |
| **Validations** | Schedule exists and is not COMPLETED or CANCELLED. All referenced users exist and have appropriate roles. |
| **Failure scenarios** | Schedule not found → 404. User not found → 404. User not a maintenance engineer → 422. |

### 3.8 Use Case: Capture Participant Signatures

| Aspect | Detail |
|--------|--------|
| **Module** | Maintenance Execution |
| **Application Service** | CaptureSignatureService |
| **Input DTO** | { reportId, reportType, userId, signatureImageData (base64 or multipart) } |
| **Orchestration** | 1. Load report (Preventive or Corrective based on reportType). 2. Verify documentStatus = DRAFT. 3. Load User — verify isActive. 4. Store signature image via FileStorage abstraction. 5. Create Signature record. 6. Create Participant linking user, report, and signature. 7. Add to report's participant collection. 8. Save. |
| **Aggregates involved** | PreventiveReport / CorrectiveReport (add participant), Signature (create), Participant (create) |
| **Transaction scope** | Single transaction (signature storage may be outside transaction if filesystem) |
| **Events emitted** | None |
| **Validations** | Report exists and is DRAFT. User exists and is active. Signature image is valid image data. User has not already signed this report (optional: depending on workflow). |
| **Failure scenarios** | Report not found → 404. Report already SUBMITTED → 422. User not found → 404. |

### 3.9 Use Case: Upload Attachments

| Aspect | Detail |
|--------|--------|
| **Module** | Cross-cutting (shared) |
| **Application Service** | UploadAttachmentService |
| **Input DTO** | { reportId, reportType, file (binary), description?, stepIndex? } (multipart upload) |
| **Orchestration** | 1. Determine storage path: ttachments/{reportType}/{reportId}/{uuid}{ext}. 2. Store file via FileStorage. 3. Create Attachment record with fileReference. 4. Attach to report (add to report's attachment collection). 5. Save. |
| **Aggregates involved** | PreventiveReport / CorrectiveReport (add attachment), Attachment (create) |
| **Transaction scope** | File storage + DB record. If file storage is filesystem, the DB transaction covers the Attachment record creation. File storage failure should roll back the DB operation. |
| **Events emitted** | None |
| **Validations** | Report exists. File is valid image type. Storage path is writable. |
| **Failure scenarios** | Report not found → 404. File too large → 413. Invalid file type → 415. Storage unavailable → 500. |

### 3.10 Use Case: Search Asset Hierarchy

| Aspect | Detail |
|--------|--------|
| **Module** | Asset Management |
| **Application Service** | SearchAssetHierarchyService |
| **Input DTO** | { query (serialNumber or partNumber or name), subsystemId?, typeId?, maxResults } |
| **Orchestration** | 1. Route to appropriate search strategy based on input fields: if serialNumber → direct lookup; if partNumber → filter by part number; if name → fuzzy match; if typeId → filter by type. 2. Query assets with filters. 3. For each result, include: current location (breadcrumb path from root via closure table), lifecycle status, type info. 4. Return results ordered by relevance. |
| **Aggregates involved** | Asset (read-only query) |
| **Transaction scope** | Read-only. No transaction needed. |
| **Events emitted** | None |
| **Validations** | At least one search criterion provided. |
| **Failure scenarios** | No search criteria → 400. Too many results → may paginate. |

### 3.11 Use Case: View Historical Hierarchy

| Aspect | Detail |
|--------|--------|
| **Module** | Asset Management |
| **Application Service** | ViewHistoricalHierarchyService |
| **Input DTO** | { assetId, pointInTime (timestamp) } |
| **Orchestration** | 1. Load all AssetAssignment records for the asset with assignedAt ≤ pointInTime and (deactivatedAt IS NULL OR deactivatedAt > pointInTime). 2. For each assignment, load the parent asset and its assignments recursively to reconstruct the hierarchy snapshot at pointInTime. 3. Return reconstructed tree. |
| **Aggregates involved** | AssetAssignment (query), Asset (read-only) |
| **Transaction scope** | Read-only |
| **Events emitted** | None |
| **Validations** | Asset exists. |
| **Failure scenarios** | Asset not found → 404. No assignments found at pointInTime → 404 (or empty tree). |

### 3.12 Use Case: Reopen Corrective Event

| Aspect | Detail |
|--------|--------|
| **Module** | Maintenance Execution |
| **Application Service** | ReopenCorrectiveEventService |
| **Input DTO** | { correctiveEventId, reason, userId } |
| **Orchestration** | 1. Load CorrectiveEvent — verify lifecycleStatus = CLOSED. 2. Verify authorized user (coordinator or above). 3. Call CorrectiveEventLifecycleService.reopen(event, userId, reason): creates ReopenRecord, transitions status back to IN_PROGRESS. 4. Save. 5. Publish event. |
| **Aggregates involved** | CorrectiveEvent (reopen) |
| **Transaction scope** | Single transaction |
| **Events emitted** | CorrectiveEventStatusChanged |
| **Validations** | Event is CLOSED. User has coordinator role or higher. Reason is provided. |
| **Failure scenarios** | Event not found → 404. Event is not CLOSED → 422. Unauthorized → 403. |

### 3.13 Use Case: Quick Asset Search

| Aspect | Detail |
|--------|--------|
| **Module** | Asset Management |
| **Application Service** | QuickAssetSearchService |
| **Input DTO** | { searchText (free text), maxResults } |
| **Orchestration** | 1. Search across all asset fields: serialNumber, partNumber, name. Use partial/fuzzy matching. 2. Return flat list of matching assets with: id, name, serialNumber, partNumber, typeName, currentLocation (breadcrumb). |
| **Aggregates involved** | Asset (read-only query) |
| **Transaction scope** | Read-only |
| **Events emitted** | None |
| **Validations** | Search text is non-empty. |
| **Failure scenarios** | Empty search → 400. No results → empty list (200). |

### 3.14 Use Case: Mark Stop Here on Corrective Report

| Aspect | Detail |
|--------|--------|
| **Module** | Maintenance Execution |
| **Application Service** | MarkStopHereService |
| **Input DTO** | { reportId, markerBlockId, note?, userId } |
| **Orchestration** | 1. Load CorrectiveReport and parent event. 2. Verify parent event is not CLOSED. 3. Store/update Stop Here marker against a dynamic block or report point. 4. Save. 5. Publish CorrectiveReportStopHereMarked. |
| **Aggregates involved** | CorrectiveReport |
| **Transaction scope** | Single transaction |
| **Events emitted** | CorrectiveReportStopHereMarked |
| **Validations** | Parent event is editable. markerBlockId is valid for the report format. |
| **Failure scenarios** | Report not found -> 404. Event CLOSED -> 422. Invalid marker -> 422. |

### 3.15 Use Case: Continue Corrective Report (Next Shift)

| Aspect | Detail |
|--------|--------|
| **Module** | Maintenance Execution |
| **Application Service** | ContinueCorrectiveReportService |
| **Input DTO** | { correctiveEventId, previousReportId?, shift, userId } |
| **Orchestration** | 1. Load corrective event and previous shift report if provided. 2. Verify event is not CLOSED. 3. Create or open editable report data for the current shift. 4. Allow continuation after Stop Here marker and correction of previous fields when needed. 5. Save draft/version. |
| **Aggregates involved** | CorrectiveEvent, CorrectiveReport |
| **Transaction scope** | Single transaction |
| **Events emitted** | None initially |
| **Validations** | Event is editable. User is authorized for corrective work. |
| **Failure scenarios** | Event/report not found -> 404. Event CLOSED -> 422. |
### 3.16 Use Case: Register Asset in Stock

| Aspect | Detail |
|--------|--------|
| **Module** | Asset Management / Inventory |
| **Application Service** | RegisterAssetInStockService |
| **Input DTO** | { assetTypeId, serialNumber?, internalCode?, initialLocationId?, initialStatus = IN_STOCK, manufacturingDate?, batchNumber?, notes? } |
| **Orchestration** | 1. Load AssetType. 2. Verify serial number or internal code uniqueness. 3. Create Asset with category from AssetType. 4. Create stock/location assignment. 5. Save. |
| **Aggregates involved** | Asset, AssetAssignment / StockRecord, AssetType |
| **Transaction scope** | Single transaction |
| **Events emitted** | AssetCreated, AssetLifecycleStatusChanged |
| **Validations** | AssetType exists. Serial/internal code is unique. Location exists if provided. |
| **Failure scenarios** | AssetType not found -> 404. Duplicate identifier -> 409. Location not found -> 404. |

### 3.17 Use Case: Install Asset in Slot

| Aspect | Detail |
|--------|--------|
| **Module** | Asset Management |
| **Application Service** | InstallAssetInSlotService |
| **Input DTO** | { installedAssetId, parentAssetId, position, replacementTaskId?, correctiveEventId?, userId } |
| **Orchestration** | 1. Load installed Asset and parent Asset. 2. Verify installed Asset is installable. 3. Verify position is available. 4. Create AssetAssignment under parent at position. 5. Update lifecycle status. 6. Save. |
| **Aggregates involved** | Asset, AssetAssignment |
| **Transaction scope** | Single transaction |
| **Events emitted** | AssetHierarchyModified, AssetLifecycleStatusChanged |
| **Validations** | Assets exist. Position is available. Installed asset is not active elsewhere. |
| **Failure scenarios** | Asset not found -> 404. Position occupied -> 409. Asset not installable -> 422. |

### 3.18 Use Case: Remove Asset from Slot

| Aspect | Detail |
|--------|--------|
| **Module** | Asset Management / Inventory |
| **Application Service** | RemoveAssetFromSlotService |
| **Input DTO** | { removedAssetId, reason, destinationLocationId?, replacementTaskId?, correctiveEventId?, userId } |
| **Orchestration** | 1. Load Asset. 2. Verify it is installed/active. 3. Close current AssetAssignment. 4. Set lifecycle status according to reason. 5. If destination is provided, create stock/location assignment. 6. Save. |
| **Aggregates involved** | Asset, AssetAssignment, Location |
| **Transaction scope** | Single transaction |
| **Events emitted** | AssetHierarchyModified, AssetLifecycleStatusChanged |
| **Validations** | Asset exists and is installed. Reason is valid. |
| **Failure scenarios** | Asset not found -> 404. Asset not installed -> 422. |
---

## 4. Persistence & Query Architecture

### 4.1 Relational Schema Strategy

| Principle | Description |
|-----------|-------------|
| PS-001 | Each aggregate root maps to its own table (or set of tables). Entity collections inside an aggregate (e.g., CorrectiveTask within CorrectiveReport) map to child tables with FK to the aggregate root. |
| PS-002 | Value objects are inlined as columns within the aggregate table or stored as JSON when the structure is variable. |
| PS-003 | Domain events are persisted to an event_store table (separate from aggregate tables). |
| PS-004 | Read-model projections (closure table, timeline views) are stored in separate tables, updated synchronously with the write model. |
| PS-005 | No cross-aggregate foreign keys outside of references. Aggregate references use UUIDs without enforced FK constraints at the database level (enforced by application). |
| PS-006 | All tables use UUID primary keys generated by the application. |
| PS-007 | All tables include created_at and updated_at timestamps. |

### 4.2 Recursive Hierarchy Persistence

#### 4.2.1 Architectural Separation

The asset hierarchy is persisted using **two complementary structures**:

| Structure | Purpose | Nature | Updated |
|-----------|---------|--------|---------|
| **Adjacency list** (sset.parent_asset_id + sset.position) | Operational write model. Authoritative current state of the hierarchy. | Canonical domain model | Directly by application |
| **Closure table** (sset_closure) | Read/query optimization. Enables deep hierarchy traversal without recursive queries. | Read projection derived from adjacency list | Synchronously via domain event or domain service |

Additionally, **AssetAssignment** provides temporal/historical hierarchy tracking (see §4.3).

#### 4.2.2 Closure Table Design (Architectural Artifact)

The closure table is an **infrastructure concern** and is NOT part of the canonical domain model.

`
Table: asset_closure

Column              Type        Description
─────────────────────────────────────────────────────────────
ancestor_id         UUID        FK → asset.id (the parent in the relationship)
descendant_id       UUID        FK → asset.id (the child in the relationship)
depth               INTEGER     Distance from ancestor to descendant (0 = self-reference)
created_at          TIMESTAMP   When this path was established
`

**Characteristics:**
- Contains all ancestor-descendant pairs, including self-references (depth = 0).
- Example: For Train → CC → Cabinet → SCCR → Card, the closure table contains:
  - (Train, Train, 0), (Train, CC, 1), (Train, Cabinet, 2), (Train, SCCR, 3), (Train, Card, 4)
  - (CC, CC, 0), (CC, Cabinet, 1), (CC, SCCR, 2), (CC, Card, 3)
  - (Cabinet, Cabinet, 0), (Cabinet, SCCR, 1), (Cabinet, Card, 2)
  - etc.

#### 4.2.3 Queries the Closure Table Optimizes

| Query | Without Closure Table | With Closure Table |
|-------|-----------------------|--------------------|
| "Find all descendants of Train 14" | Recursive CTE or N queries | SELECT descendant_id FROM asset_closure WHERE ancestor_id = :trainId AND depth > 0 — single query |
| "Find the breadcrumb path for Card 123" | Recursive CTE walking up parents | SELECT ancestor_id, depth FROM asset_closure WHERE descendant_id = :cardId ORDER BY depth DESC — single query |
| "Find all ancestors at depth 2 (cabinets) of any card in Train 14" | Complex recursive join | Simple two-step query via closure table |
| "Count all components in a cabinet" | Recursive CTE | SELECT COUNT(*) FROM asset_closure WHERE ancestor_id = :cabinetId AND depth > 0 |

#### 4.2.4 Synchronization Strategy

| Rule | Description |
|------|-------------|
| CLS-001 | The closure table is updated **synchronously within the same transaction** as the hierarchy mutation (replacement, move, reinstall, warehouse transfer). |
| CLS-002 | On hierarchy mutation: (a) delete all rows where descendant_id is the moved subtree's root; (b) insert new rows by cross-joining the new ancestors with the moved subtree's descendants. |
| CLS-003 | The update logic is encapsulated in a **Domain Service** (HierarchyMutationService) or an **Infrastructure Service** (ClosureTableUpdater), NOT in the domain entities. |
| CLS-004 | For initial data load (bulk import of the full hierarchy), the closure table can be rebuilt from scratch using a stored procedure or batch job. |
| CLS-005 | A reconciliation script should exist to detect and repair closure table inconsistencies (e.g., if a bug causes drift between adjacency list and closure table). |

#### 4.2.5 Rebuild / Reconciliation Strategy

`
Function: rebuild_asset_closure()
  TRUNCATE asset_closure;
  INSERT INTO asset_closure (ancestor_id, descendant_id, depth)
  WITH RECURSIVE tree AS (
    SELECT id, id AS root_id, 0 AS depth
    FROM asset
    WHERE parent_asset_id IS NULL
    UNION ALL
    SELECT c.id, t.root_id, t.depth + 1
    FROM asset c
    JOIN tree t ON c.parent_asset_id = t.id
  )
  SELECT root_id, id, depth FROM tree
  UNION ALL
  SELECT id, id, 0 FROM asset;  -- self-references for orphans
`

This rebuild function should be:
- Available as a maintenance operation (admin endpoint or CLI command).
- Safe to run against production (read-only lock on asset table).
- Used during initial deployment, bulk imports, and as a repair mechanism.

#### 4.2.6 Indexing Strategy for Closure Table

| Index | Columns | Purpose |
|-------|---------|---------|
| Primary | (ancestor_id, descendant_id) | Unique path constraint, prevents duplicates |
| Secondary | (descendant_id) | Reverse traversal (find ancestors of a given descendant) |
| Secondary | (ancestor_id, depth) | Filtered queries (e.g., "find immediate children" WHERE depth = 1) |

#### 4.2.7 Future Evolution Possibilities

| Alternative | When to Consider | Tradeoff |
|-------------|------------------|----------|
| **Materialized path** (e.g., PostgreSQL ltree) | When write frequency is low and read performance is critical | Simpler than closure table for writes, less flexible for arbitrary depth queries |
| **Graph database** (e.g., Dgraph, Neo4j, or PostgreSQL with AGE) | When the hierarchy is used for complex graph traversal (impact analysis, dependency mapping) | Additional infrastructure; overkill for current requirements |
| **Nested sets** | When hierarchy is mostly static | Very expensive writes; not suitable for frequent replacements |
| **Only adjacency list + recursive CTE** | If hierarchy depth is shallow (< 5 levels) and query volume is low | Simplest; but depth is unbounded per domain model |

For v1, the **adjacency list + closure table** hybrid is recommended. Future evolution may add materialized path as an additional read optimization if closure table maintenance proves operationally expensive.

### 4.3 Temporal History Modeling (AssetAssignment)

AssetAssignment is a **first-class domain entity** (see domain model §4.9), not a read projection. It is the authoritative historical record of the hierarchy.

#### 4.3.1 Persistence Structure

`
Table: asset_assignment

Column              Type        Description
─────────────────────────────────────────────────────────────
id                  UUID        PK
asset_id            UUID        FK → asset.id
parent_asset_id     UUID?       FK → asset.id (nullable for warehouse/top-level)
position            String?     Position within parent at time of assignment
assigned_at         TIMESTAMP   When this assignment started (NOT NULL)
assigned_by         UUID?       FK → user.id
assignment_reason   String?     Context: initial_registration, replacement, etc.
deactivated_at      TIMESTAMP?  When this assignment ended (NULL = active)
deactivation_reason String?     Context: replaced, scrapped, warehouse, etc.
replaced_by_id      UUID?       FK → asset_assignment.id (self-ref for lineage)
`

#### 4.3.2 Key Queries

| Query | SQL Pattern |
|-------|-------------|
| Active assignment for an asset | WHERE asset_id = ? AND deactivated_at IS NULL |
| Assignments at a point in time | WHERE asset_id = ? AND assigned_at <= ? AND (deactivated_at IS NULL OR deactivated_at > ?) |
| Replacement lineage | Recursive: follow 
eplaced_by_id chain |
| Composition of a parent at time T | WHERE parent_asset_id = ? AND assigned_at <= T AND (deactivated_at IS NULL OR deactivated_at > T) |
| Full history of an asset | WHERE asset_id = ? ORDER BY assigned_at ASC |

#### 4.3.3 Indexing

| Index | Columns | Purpose |
|-------|---------|---------|
| Primary | (asset_id, deactivated_at) | Find active assignment |
| Secondary | (parent_asset_id, assigned_at, deactivated_at) | Temporal composition queries |
| Secondary | (asset_id, assigned_at) | Ordered history lookup |
| Lineage | (replaced_by_id) | Replacement chain traversal |

### 4.4 Event Store Persistence

`
Table: event_store

Column              Type        Description
─────────────────────────────────────────────────────────────
id                  UUID        PK
event_type          String      Fully qualified event class name
aggregate_type      String      e.g., "Asset", "CorrectiveEvent", "CorrectiveReport"
aggregate_id        UUID        The aggregate that raised the event
payload             JSONB       Event-specific data (serialized domain event)
occurred_at         TIMESTAMP   When the event occurred
correlation_id      UUID        Correlation ID for tracing across events in one operation
user_id             UUID?       The user who triggered the operation (from application context)
`

**Properties:**
- Append-only. Never modified or deleted.
- Indexed by (aggregate_type, aggregate_id) for replaying history of a specific aggregate.
- Indexed by correlation_id for tracing an entire operation's event chain.
- The event store is not a message queue. It is an audit log and a source for future read-model projection rebuilding.

### 4.5 Report Version Persistence

| Principle | Description |
|-----------|-------------|
| RPT-VER-001 | Reports are versioned. Each finalized edit creates a new immutable report version snapshot, from which an authorized user can generate a PDF. |
| RPT-VER-002 | Latest editable report data may be updated while the parent activity/event is not CLOSED. |
| RPT-VER-003 | Once the parent activity/event is CLOSED, the application layer rejects edits until a Coordinator or Administrator reopens it. |
| RPT-VER-004 | Report data is stored in normalized form where the structure is stable; dynamic corrective blocks may use structured JSON payloads if the block schema varies by task type. |
| RPT-VER-005 | Signatures and attachments are linked to the report version they were captured for. |

### 4.6 Attachment Storage Strategy

| Aspect | Approach |
|--------|----------|
| **v1 backend** | Local filesystem under storage/attachments/{report_type}/{report_id}/ |
| **Metadata** | Stored in ttachment table: id, report_id, report_type, file_path, original_filename, content_type, size_bytes, captured_at, step_index? |
| **Abstraction** | FileStorage interface in shared_kernel. Method: store(file, path) → path, 
etrieve(path) → stream, delete(path). |
| **On-premises** | Filesystem implementation. Directory structure organized by module and entity. |
| **Cloud migration** | When migrating to Azure Blob Storage (or equivalent), only the infrastructure implementation changes. The storage path convention ({module}/{entity_type}/{entity_id}/{filename}) translates naturally to blob container paths. |

### 4.7 Read Projections / Views

In addition to the closure table (which is the primary read projection), the architecture explicitly defines:

| Projection | Purpose | Update Strategy |
|------------|---------|-----------------|
| **asset_closure** | Hierarchy traversal | Synchronous (same transaction as hierarchy mutations) |
| **corrective_event_timeline** | Denormalized view of an event with all its reports, tasks, replacements, and status transitions | Updated on report submission and event status change (synchronous within transaction, or immediate background task) |
| **asset_maintenance_history** | All reports and replacements involving a specific asset | Could be a database view joining report + replacement tables |
| **dashboard_summaries** (future) | Aggregated KPIs per subsystem, per month | Background job consuming domain events |

### 4.8 Concurrency Control

| Approach | Description |
|----------|-------------|
| **Optimistic locking** | Each aggregate root table has an ersion integer column. Before update, the application checks that the loaded version matches the database version. On mismatch, the operation fails with a 409 Conflict. |
| **Applied to** | All aggregate root tables: Asset, CorrectiveEvent, CorrectiveReport, PreventiveReport, etc. |
| **Replacement operations** | Highest risk of concurrent modification. The AssetReplacementService loads all involved aggregates with their current versions and updates them atomically within a single transaction. |
| **Hierarchy mutations** | The closure table update must be part of the same transaction as the parent mutation. If the closure table update fails, the entire transaction rolls back. |

### 4.9 Indexing Strategy Summary

| Table | Key Indexes | Purpose |
|-------|-------------|---------|
| asset | (parent_asset_id) | Find children |
| asset | (serial_number) | Unique lookup |
| asset | (part_number) | Type-based filtering |
| asset | (asset_type_id, subsystem_id) | Composition rule enforcement |
| asset_assignment | (asset_id, deactivated_at) | Active assignment lookup |
| asset_assignment | (parent_asset_id, assigned_at, deactivated_at) | Temporal composition |
| asset_closure | (ancestor_id, descendant_id) PK | Primary path lookup |
| asset_closure | (descendant_id) | Reverse traversal |
| asset_closure | (ancestor_id, depth) | Level-filtered queries |
| event_store | (aggregate_type, aggregate_id) | Aggregate event history |
| event_store | (correlation_id) | Operation tracing |
| (all report tables) | (document_status) | Filter submitted vs draft |
| corrective_report | (corrective_event_id) | Reports by event |
| preventive_report | (schedule_id) | Report by schedule |

---

## 5. API Architecture

### 5.1 API Style & Conventions

| Aspect | Decision |
|--------|----------|
| **Protocol** | REST over HTTPS |
| **Content type** | JSON (application/json) for data. Multipart/form-data for file uploads. |
| **Base URL** | /api/v1 (versioned from the start) |
| **Naming** | Plural nouns for resources: /assets, /corrective-events, /reports |
| **HTTP methods** | GET (read), POST (create), PUT (full update), PATCH (partial update), DELETE (soft delete / deactivate) |
| **Error format** | { "error": { "code": "ERROR_CODE", "message": "...", "details": {} } } |
| **Pagination** | Cursor-based for hierarchy traversal, offset-based for flat lists |
| **Authentication** | JWT Bearer token in Authorization header |
| **Request ID** | All requests should include X-Request-Id header for tracing |

### 5.2 Authentication Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | /api/v1/auth/login | Authenticate user, return access + refresh tokens |
| POST | /api/v1/auth/refresh | Refresh access token |
| POST | /api/v1/auth/logout | Invalidate refresh token |
| GET | /api/v1/auth/me | Current user profile |
| POST | /api/v1/auth/change-password | Change password and revoke all refresh sessions |

### 5.3 Asset Management Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | /api/v1/assets | Search assets (query params: q, serial_number, part_number, type_id, subsystem_id, page, limit) |
| GET | /api/v1/assets/stock | List Assets whose current inventory location is set, with server-side search and pagination |
| GET | /api/v1/assets/{id} | Get asset detail with breadcrumb path |
| GET | /api/v1/assets/{id}/children | Get immediate children (query: page, limit, type_id?) |
| GET | /api/v1/assets/{id}/subtree | Get full subtree (uses closure table) |
| GET | /api/v1/assets/{id}/ancestors | Get breadcrumb path to root |
| GET | /api/v1/assets/{id}/history | Get AssetAssignment history (temporal) |
| GET | /api/v1/assets/{id}/history?at={timestamp} | Get hierarchy snapshot at point in time |
| GET | /api/v1/assets/{id}/replacements | Get replacement lineage for this asset |
| POST | /api/v1/assets | Create new asset |
| PATCH | /api/v1/assets/{id} | Update asset attributes (name, position, location) |
| POST | /api/v1/assets/{id}/move | Move asset to new parent or warehouse |
| POST | /api/v1/assets/{id}/reinstall | Reinstall asset from warehouse/removed state |
| GET | /api/v1/asset-types | List all asset types |
| GET | /api/v1/geographic-locations | List geographic locations (hierarchical) |

The equipment maintenance-history projection returns the finalized report
version identifier when one exists. iOS reuses the shared immutable
`PDFPreviewView` for that version, preserving one rendering and PDF-generation
flow across preventive, corrective, and equipment entry points. A completed
activity without a finalized version falls back to its activity detail.

Administrator role preview is a non-production authentication aid, not a
client-side permission override. `GET /api/v1/auth/impersonation-roles` exposes
only roles backed by active users. `POST /api/v1/auth/impersonate-role` issues a
normal token pair for the selected representative user. iOS protects the
original Administrator refresh token in Keychain and can restore it by normal
token rotation. Both endpoints reject production environments.

### 5.4 Corrective Maintenance Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | /api/v1/maintenance-activities | Unified normalized preventive/corrective activity list (query: activity_type, status, subsystem, q, date_from, date_to, planned_year, planned_month, limit, offset) |
| GET | /api/v1/maintenance-dashboard | Operational Home counts and today's exact-date preventive activities |
| GET | /api/v1/maintenance-activities/{id} | Normalized activity detail with assets, report versions, and latest report results |
| GET | /api/v1/maintenance-activities/{id}/reports | Report versions for a normalized maintenance activity |
| POST | /api/v1/maintenance-activities/{id}/start | Transition SCHEDULED to IN_PROGRESS; Maintenance Engineer, Coordinator, or Administrator |
| POST | /api/v1/maintenance-activities/{id}/complete | Transition IN_PROGRESS to COMPLETED; Maintenance Engineer, Coordinator, or Administrator |
| POST | /api/v1/maintenance-activities/{id}/close | Transition COMPLETED to CLOSED; Coordinator or Administrator only |
| POST | /api/v1/maintenance-activities/{id}/reopen | Transition COMPLETED or CLOSED to IN_PROGRESS with a required reason; CLOSED requires Coordinator or Administrator |
| GET | /api/v1/maintenance-activities/{id}/report-editor | Load report draft, preventive template, participants, equipment tree, stock, comments, and evidence |
| GET | /api/v1/maintenance-activities/{id}/preventive-guide | Load the reusable preventive template guide and finalized history for the same template and business-anchor equipment |
| PUT | /api/v1/maintenance-activities/{id}/report-draft | Create or replace the mutable draft version while the activity is IN_PROGRESS |
| POST | /api/v1/maintenance-activities/{id}/report-finalize | Validate signatures and required fields, finalize the immutable version, and execute component replacements atomically |
| GET/POST | /api/v1/maintenance-activities/{id}/comments | Read or append reusable preventive knowledge comments or event-local corrective comments |
| GET | /api/v1/attachments/{id}/content | Authenticated evidence download |
| GET | /api/v1/corrective-events | List events (query: status, subsystem, date_from, date_to, page, limit) |
| GET | /api/v1/corrective-events/creation-context | Resolve read-only site/project/stage/system/subsystem/location context from a business-anchor asset |
| GET | /api/v1/corrective-events/{id} | Get event detail with timeline |
| POST | /api/v1/corrective-events | Atomically create the corrective event, normalized maintenance activity, asset links, and initial status history |
| POST | /api/v1/corrective-events/{id}/resolve | Mark event as resolved |
| POST | /api/v1/corrective-events/{id}/close | Close event |
| POST | /api/v1/corrective-events/{id}/reopen | Reopen event |
| GET | /api/v1/corrective-events/{id}/reports | List reports for event |
| POST | /api/v1/corrective-events/{id}/reports | Create new corrective report (draft) |
| GET | /api/v1/corrective-reports/{id} | Get report detail |
| PATCH | /api/v1/corrective-reports/{id} | Update report (only when DRAFT) |
| POST | /api/v1/corrective-reports/{id}/submit | Submit report (finalize) |
| POST | /api/v1/corrective-reports/{id}/tasks | Add task to report |
| POST | /api/v1/corrective-reports/{id}/stop-here | Activate Stop Here at section N |
| POST | /api/v1/corrective-reports/{id}/resume | Resume report (next shift) |
| POST | /api/v1/corrective-reports/{id}/signatures | Add participant signature |
| GET | /api/v1/corrective-reports/{id}/sections | Get section completion states |
| PATCH | /api/v1/corrective-reports/{id}/sections/{sectionIndex} | Mark section as complete |
| GET | /api/v1/task-types | List task types (query: subsystem_id) |

### 5.5 Preventive Maintenance Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | /api/v1/templates | List maintenance templates |
| GET | /api/v1/templates/{id} | Get template detail with steps |
| GET | /api/v1/schedules | List schedules (query: date, status, engineer_id, subsystem_id) |
| POST | /api/v1/schedules | Create schedule (coordinator) |
| PATCH | /api/v1/schedules/{id} | Update schedule |
| POST | /api/v1/schedules/{id}/assign | Assign maintenance engineers |
| GET | /api/v1/pcon/plan | List monthly PCON entries with exact/proposed state |
| PUT | /api/v1/pcon/plan/month | Batch-reassign unconfirmed entries to a month |
| GET | /api/v1/pcon/annual-plan | Read the annual hierarchy and twelve monthly occurrence counts |
| PUT | /api/v1/pcon/annual-plan/count | Adjust one maintenance scope's monthly occurrence quantity |
| POST | /api/v1/pcon/annual-plan/copy | Copy prior-year memberships and quantities into empty target cells |
| GET | /api/v1/pcon/catalog | Read eligible equipment and maintenance definitions for plan administration |
| POST | /api/v1/pcon/plan-scopes | Add an equipment-maintenance row and its initial occurrences |
| POST | /api/v1/pcon/occurrences | Create additional monthly occurrences |
| PATCH | /api/v1/pcon/occurrences/{planEntryId} | Move an eligible occurrence to another month |
| DELETE | /api/v1/pcon/occurrences/{planEntryId} | Remove an untouched occurrence |
| POST | /api/v1/pcon/occurrences/{planEntryId}/cancel | Logically cancel a confirmed future occurrence |
| GET | /api/v1/pcon/change-history | Read the annual plan administrative audit trail |
| GET | /api/v1/pcon/weeks/{weekStart}/current | Read the current weekly draft or confirmation |
| POST | /api/v1/pcon/weeks/{weekStart}/sessions | Create/resume a weekly draft |
| PUT | /api/v1/pcon/sessions/{id}/proposals/{activityId} | Upsert an exact-date proposal |
| DELETE | /api/v1/pcon/sessions/{id}/proposals/{activityId} | Remove a draft proposal |
| POST | /api/v1/pcon/sessions/{id}/confirm | Atomically confirm the complete weekly block |
| GET | /api/v1/pcon/history | Read confirmed/superseded schedule revisions |
| POST | /api/v1/plan-entries/import | Import PCON Excel (future replacement for the existing legacy importer) |
| GET | /api/v1/preventive-reports/{id} | Get report detail |
| POST | /api/v1/preventive-reports | Create preventive report (draft) from schedule or ad-hoc |
| PATCH | /api/v1/preventive-reports/{id} | Update report (only when DRAFT) |
| POST | /api/v1/preventive-reports/{id}/submit | Submit report (finalize) |
| POST | /api/v1/preventive-reports/{id}/signatures | Add participant signature |
| GET | /api/v1/preventive-reports/{id}/generate-pdf | Generate PDF for report |

### 5.6 Attachment & File Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | /api/v1/reports/{type}/{id}/attachments | Upload attachment (multipart) |
| GET | /api/v1/attachments/{id} | Download attachment file |
| DELETE | /api/v1/attachments/{id} | Delete attachment (only when report is DRAFT) |

Preventive and corrective versions use the same version-oriented contract:

| POST | `/api/v1/report-versions/{version_id}/generate-pdf` | Select the template by report kind, render, and persist the finalized PDF. |
| GET | `/api/v1/report-versions/{version_id}` | Read-only version detail for the iPad. |
| GET | `/api/v1/report-versions/{version_id}/pdf` | Download the latest generated PDF. |

Calibration uses the same version-oriented contract. For an eligible track-circuit preventive
activity, saving or finalizing the preventive editor also persists a companion `CALIBRATION`
version. `POST /api/v1/report-versions/{version_id}/generate-pdf` selects the dedicated calibration
HTML template, and the common download endpoint supplies the file to the PDF viewer and Share Sheet.

### 5.7 Component Inventory Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | /api/v1/component-types | List component types (query: subsystem_id, part_number) |
| GET | /api/v1/component-types/{id} | Get component type detail |
| POST | /api/v1/component-types | Create component type |
| GET | /api/v1/components | List components (query: status, type_id, slot_id, serial_number, asset_id) |
| GET | /api/v1/components/{id} | Get component detail with movement history |
| POST | /api/v1/components | Register new component |
| POST | /api/v1/components/{id}/move | Move component (install, remove, transfer, repair, scrap) |
| GET | /api/v1/slot-locations | List slot locations (query: equipment_kind_id, parent_slot_id) |
| GET | /api/v1/slot-locations/{id} | Get slot detail with image |
| POST | /api/v1/slot-locations | Create slot location |
| GET | /api/v1/locations | List physical locations (warehouse zones, shelves) |
| GET | /api/v1/locations/{id} | Get location detail |
| POST | /api/v1/locations | Create location |

### 5.8 PDF Generation Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | /api/v1/reports/{type}/{id}/generate-pdf | Generate PDF (async, returns GeneratedReport) |
| GET | /api/v1/reports/{type}/{id}/pdf-status | Check PDF generation status |
| GET | /api/v1/pdf-reports/{generatedReportId}/download | Download generated PDF |

Where {type} = preventive or corrective.

### 5.9 Personnel & Tool Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | /api/v1/users | List users (query: role, project_id) |
| GET | /api/v1/users/{id} | Get user detail |
| GET | /api/v1/tools | List tools (query: serial, available, certified) |
| GET | /api/v1/tools/{id} | Get tool detail with certifications |
| POST | /api/v1/tools/{id}/certifications | Add tool certification |
| GET | /api/v1/consumable-types | List consumable types |

### 5.10 Pagination & Filtering

| Pattern | Description |
|---------|-------------|
| **Offset pagination** | ?page=1&per_page=20 — for flat, sortable lists (reports, events, users) |
| **Cursor pagination** | ?cursor={opaque_id}&limit=20 — for hierarchy children (consistent order under mutation) |
| **Response format** | { "data": [...], "pagination": { "total": 100, "page": 1, "per_page": 20, "next_cursor": "..." } } |
| **Filtering** | Query parameters matching entity fields: ?status=IN_PROGRESS&subsystem_id=uuid |
| **Sorting** | ?sort=created_at&order=desc |

### 5.11 Hierarchy Traversal Endpoints (Detailed)

These endpoints deserve special attention due to the recursive asset structure:

| Endpoint | Returns | Implementation |
|----------|---------|----------------|
| GET /assets/{id}/children | Flat list of immediate children | Direct query: WHERE parent_asset_id = :id ORDER BY position |
| GET /assets/{id}/subtree | Recursive tree structure | Uses closure table: SELECT descendant_id FROM asset_closure WHERE ancestor_id = :id AND depth > 0, then hydrate levels |
| GET /assets/{id}/ancestors | Ordered list from root to parent | Uses closure table: SELECT ancestor_id FROM asset_closure WHERE descendant_id = :id ORDER BY depth DESC |
| GET /assets/search?q=MTORE | Flat list of matching assets (with breadcrumb path) | Searches serial/part/name, enriches each result with ancestor path from closure table |

### 5.12 API Error Response Format

`json
{
  "error": {
    "code": "ASSET_NOT_FOUND",
    "message": "Asset with id 'uuid' was not found.",
    "details": {
      "asset_id": "uuid"
    }
  }
}
`

Standard HTTP status codes:
- 200 — Success
- 201 — Created
- 400 — Bad request (validation error)
- 401 — Unauthenticated
- 403 — Unauthorized (wrong role)
- 404 — Not found
- 409 — Conflict (concurrent modification, duplicate, overlapping event)
- 413 — Payload too large (attachment)
- 415 — Unsupported media type
- 422 — Unprocessable entity (business rule violation)
- 500 — Internal server error

---

## 6. Frontend (SwiftUI) Architecture

### 6.1 Architectural Pattern

**MVVM (Model-View-ViewModel)** with a service layer for API communication.

`
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│     View     │────▶│  ViewModel   │────▶│   Service    │────▶│  API Client  │
│ (SwiftUI)    │     │ (Observable) │     │   Layer      │     │  (URLSession)│
│              │◀────│              │◀────│              │◀────│              │
│  - Navigation│     │  - State     │     │  - Business  │     │  - JWT Auth  │
│  - Animations│     │  - Actions   │     │    logic     │     │  - JSON      │
│  - Gestures  │     │  - Validation│     │  - DTO maps  │     │  - Multipart │
│  - Camera    │     │              │     │              │     │              │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
`

**iPadOS/iOS 26.5 specific capabilities leveraged:**
- SwiftUI Observable patterns for reactive state management
- NavigationStack with programmatic navigation
- SwiftData or NSFetchRequest for local draft caching
- PhotosPicker with multi-selection for preventive evidence
- PencilKit for signature capture
- SwiftUI-Shimmer or custom transitions for loading states
- MatchedGeometryEffect for smooth hierarchy navigation transitions
- .scrollTransition for modern scroll effects
- Liquid Glass-capable surfaces for dashboards, controls, cards, and native navigation chrome
- VisionKit for future document scanning

### 6.2 Navigation Structure

`
Tab 1: Dashboard (future)
│
Tab 2: Corrective
│   ├── Active Events List
│   │   ├── Event Detail (timeline)
│   │   │   ├── Shift Reports
│   │   │   │   ├── Report Detail
│   │   │   │   │   ├── 6 Sections (summary, parts, labor, tests, doc, comments)
│   │   │   │   │   ├── Task List (StandardActivity / ReplacementTask)
│   │   │   │   │   │   └── Replacement Detail + Component Movement
│   │   │   │   │   ├── Attachments (per section)
│   │   │   │   │   └── Signatures
│   │   │   │   ├── Stop Here (section picker)
│   │   │   │   └── Resume (next shift)
│   │   │   ├── Start Maintenance
│   │   │   └── Event Controls (resolve, close, reopen)
│   │   └── Create New Event
│   └── History (closed events)
│
Tab 3: Preventive
│   ├── Scheduled Activities
│   │   └── Activity Detail
│   │       └── Create Report (with test steps, personnel requirements)
│   ├── Templates
│   └── History
│
Tab 4: Assets
│   ├── Full Hierarchy (drill-down navigation)
│   │   ├── Train → Car → Cabinet → Rack → Card
│   │   ├── Cabinet → Server → Software
│   │   └── Search (quick search bar always visible)
│   ├── Asset Detail
│   │   ├── Hierarchy position (breadcrumb)
│   │   ├── Maintenance history
│   │   ├── Replacement history
│   │   └── Warehouse movement history
│   └── Quick Search (presented as sheet)
│
Tab 5: Components
│   ├── Component List (filter: status, type, slot, asset)
│   │   ├── Component Detail
│   │   │   ├── Movement History
│   │   │   ├── Current Slot / Asset
│   │   │   └── Current Status
│   │   └── Register New Component
│   ├── Slot Locations (per EquipmentKind)
│   │   ├── Slot Detail (with image)
│   │   └── Available Slots
│   └── Physical Locations (warehouse)
│
Tab 6: Profile / Settings
    ├── User info
    ├── Signatures management
    └── Logout
`

### 6.3 Navigation in iPadOS/iOS 26.5

| Pattern | Usage |
|---------|-------|
| NavigationStack | Root navigation container for each tab |
| NavigationLink(value:) | Programmatic navigation with typed destinations |
| .navigationDestination(for:) | Destination resolution per type |
| .sheet(item:) | Modal presentations (search, camera, signature pad) |
| .fullScreenCover | Camera capture |
| Split view (NavigationSplitView) | iPad: master-detail for hierarchy browsing |

### 6.4 State Management

| Concern | Approach |
|---------|----------|
| **Server data** | Fetched on demand, cached in memory via ViewModel @Observable classes |
| **Draft reports** | Atomic JSON persistence in Application Support, managed by `OfflineReportStore` |
| **Auth token** | Access and refresh tokens stored in iOS Keychain |
| **User session** | Environment object plus non-sensitive cached profile for temporary offline restoration |
| **Navigation state** | Managed by NavigationStack path binding |
| **Loading states** | AsyncImage for thumbnails, custom LoadingState enum in ViewModels |
| **Error handling** | Alert and .alert() modifier for user-facing errors |

### 6.5 API Client Architecture

`
APIClient (singleton)
  ├── configure(baseURL, tokenProvider)
  ├── request<T: Decodable>(endpoint, method, body, query) async throws → T
  └── upload(endpoint, data, fieldName, filename) async throws → Response

Endpoint enum (per module):
  ├── AssetAPI
  │   ├── search(query) → [AssetSummary]
  │   ├── getChildren(id) → [AssetSummary]
  │   └── getDetail(id) → AssetDetail
  ├── CorrectiveAPI
  │   ├── listEvents(filters) → [EventSummary]
  │   ├── createEvent(dto) → CorrectiveEvent
  │   └── submitReport(id, dto) → CorrectiveReport
  ├── AuthAPI
  │   ├── login(username, password) → TokenPair
  │   └── refresh(refreshToken) → TokenPair
  └── ...
`

### 6.6 Camera / Attachment Capture

| Feature | iOS API | Integration |
|---------|---------|-------------|
| **Camera capture** | AVCaptureSession via CameraView (UIViewRepresentable wrapping AVCam) OR .sheet with PHPicker | Captured image → resize to max 1920px → upload via multipart to attachment endpoint |
| **Photo library** | PhotosPicker (iOS 16+) | Select multiple, normalize to JPEG, then batch with the report write |
| **Signature capture** | PencilKit PKCanvasView wrapped in SignaturePadView | Capture as PNG image → upload as attachment with type "signature" → link to Participant |
| **Image picker** | UIImagePickerController via representable | Fallback for older patterns |

### 6.7 Signature Capture Flow

`
1. User taps "Sign Report"
2. Present SignaturePadView (full screen sheet)
3. PencilKit canvas displayed with "Sign here" guide line
4. User draws signature with finger or Apple Pencil
5. "Confirm" button → capture PKCanvasView as UIImage
6. Upload signature image to server → create Signature record
7. Create Participant linking User + Report + Signature
8. Update report's participant list in UI
`

### 6.8 Offline Report Drafts

The iOS client persists preventive and corrective report drafts as one JSON document
per activity under the app's Application Support directory. Writes are atomic and use
`completeUntilFirstUserAuthentication` file protection. The local record includes the
form payload, cached editor context, cached activity detail, evidence data, owner,
server environment, retry metadata, and the report version used as its editing base.

`NWPathMonitor` starts synchronization as soon as connectivity returns. Foreground
activation and a bounded periodic retry also cover the case where Wi-Fi is available
but the FastAPI process is down. Retry delay grows from 5 to 60 seconds.

Draft synchronization uses optimistic concurrency. The client sends
`base_report_version_id` and `enforce_base_version`; if another device has created a
newer report version, the API responds with `409` and the draft becomes
`needsAttention`. The client never silently overwrites that server state.

Authentication tokens remain in Keychain. A non-sensitive cached user profile permits
session restoration during a temporary outage after at least one successful online
sign-in.

The scope is intentionally limited to report drafts. Report finalization, maintenance
lifecycle transitions, corrective creation, and inventory mutations require an online
server transaction.

| Feature | Implementation |
|---------|----------------|
| **Draft caching** | Atomic JSON files for in-progress preventive and corrective reports |
| **Editor cache** | Activity detail and editor context stored with each local draft |
| **Queue submissions** | Automatic retry on network recovery, foreground activation, and periodic availability checks |
| **Conflict resolution** | Optimistic base-version validation; conflicting drafts require explicit user review |

### 6.9 UI Component Guidelines

| Component | Approach |
|-----------|----------|
| **Hierarchy browser** | Recursive List with disclosure groups, custom disclosure indicator, matched geometry for drill-down |
| **Breadcrumb** | Horizontal scrollable HStack with chevron separators, tap any level to navigate |
| **Report form** | Form with sections: header, tasks/steps, tools, signatures, attachments |
| **Status badge** | Pill-shaped Text with colored background per status |
| **Timeline** | Vertical ScrollView with custom TimelineRow views connected by a vertical line |
| **Signature pad** | White canvas with bottom toolbar (clear, confirm) |
| **Image gallery** | Horizontal ScrollView with tappable thumbnails → full-screen viewer with ZoomView |

### 6.10 Dashboard Extensibility (Future)

- Each tab can later host dashboard SwiftUI Charts widgets.
- The dashboard area shows: open events count, pending schedules, recent reports.
- Widgets use the same API client, fetching aggregated data from future /api/v1/reporting/* endpoints.

---

## 7. Infrastructure & Deployment

### 7.1 Deployment Topology

```
┌─────────────────────────────────────────────────────────────┐
│                        User Device                           │
│              iPadOS/iOS 26.5 Native SwiftUI App              │
└──────────────────────┬──────────────────────────────────────┘
                       │ HTTPS (TLS 1.3)
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                      Reverse Proxy                           │
│              nginx / Caddy / Azure Application Gateway       │
│         TLS termination, rate limiting, request routing      │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                   Application Server                         │
│              Docker container (single host, v1)             │
│              FastAPI (ASGI via uvicorn/gunicorn)            │
└──────────┬───────────────────────────────┬──────────────────┘
           │                               │
           ▼                               ▼
┌─────────────────────┐       ┌─────────────────────────────┐
│   PostgreSQL 16      │       │    Filesystem Storage        │
│   (Docker or RDS)    │       │    /data/attachments/        │
│                      │       │    /data/reports/           │
│   - Main DB          │       │    /data/signatures/        │
│   - Event store      │       │                              │
│   (same instance,    │       │   (mounted Docker volume)    │
│    separate schema)  │       │                              │
└─────────────────────┘       └─────────────────────────────┘
```

In v1, all components run on a single server (physical or VM). The modular monolith is deployed as a single Docker container with PostgreSQL as an adjacent container or managed service.

### 7.2 Container Strategy

| Component | Image | Notes |
|-----------|-------|-------|
| **API Server** | Custom `Dockerfile` (Python 3.12-slim) | FastAPI app, uvicorn workers |
| **PostgreSQL** | `postgres:16-alpine` | Or use managed Azure Database for PostgreSQL |
| **Reverse proxy** | `nginx:alpine` or cloud LB | TLS, static file serving, rate limiting |

Docker Compose (development):

```yaml
version: '3.9'
services:
  api:
    build: .
    ports:
      - "8000:8000"
    volumes:
      - data:/data
    environment:
      - DATABASE_URL=postgresql://...
      - SECRET_KEY=${SECRET_KEY}
    depends_on:
      - db
  db:
    image: postgres:16-alpine
    volumes:
      - pgdata:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=maintenance
      - POSTGRES_USER=app
      - POSTGRES_PASSWORD=${DB_PASSWORD}
volumes:
  pgdata:
  data:
```

### 7.3 Environments

| Environment | Purpose | Infrastructure |
|-------------|---------|----------------|
| **Development** | Local development, all engineers | Docker Compose on dev machine |
| **Staging** | Integration testing, UAT | Single VM or Azure App Service (B2) |
| **Production** | Live system (~11 users) | Single VM (Standard_D2s_v3 equivalent) or Azure App Service (S1) |

**Promotion flow:** Dev → feature branch → staging → production.

Database migrations run as part of deployment (`alembic upgrade head`) before new app version starts.

### 7.4 Secrets Management

| Secret | Storage (dev) | Storage (prod) | Rotation |
|--------|---------------|----------------|----------|
| `SECRET_KEY` | `.env` file (gitignored) | Azure Key Vault / env on VM | On compromise |
| `DB_PASSWORD` | `.env` file | Azure Key Vault / env | Quarterly |
| `JWT_SECRET` | `.env` file | Azure Key Vault | Per release |
| `JWT_REFRESH_SECRET` | `.env` file | Azure Key Vault | Per release |
| API tokens (future) | `.env` file | Azure Key Vault | As needed |

### 7.5 Observability

| Area | Tool / Approach |
|------|----------------|
| **Application logs** | Structured JSON logging via `structlog` or `loguru` to stdout. Container runtime handles log shipping. |
| **Request tracing** | `X-Request-Id` correlation ID throughout stack. FastAPI middleware captures and logs. |
| **Metrics** | Prometheus client exposed at `/metrics` endpoint. FastAPI instrumentation. |
| **Health checks** | `/health` endpoint for container orchestration readiness/liveness probes. |
| **Error tracking** | Sentry integration for exception capture and performance monitoring (optional in v1). |
| **Database monitoring** | PostgreSQL `pg_stat_statements` for slow query identification. |

### 7.6 Backup & Recovery

| Asset | Strategy | Schedule | Retention |
|-------|----------|----------|-----------|
| **PostgreSQL (main)** | `pg_dump` to compressed SQL file | Daily full + WAL archiving (continuous) | 30 days daily, 12 monthly |
| **Attachment files** | rsync to secondary storage / Azure Blob copy | Daily incremental | 30 days |
| **Configuration** | Version-controlled (.env template excluded) | On change | Git history |

**Backup storage:** Initially to same server (separate disk), later to Azure Blob Storage / S3-compatible.

**Recovery drill:** Full restore from backup to staging environment annually.

### 7.7 CI/CD Pipeline

| Stage | Tool | Actions |
|-------|------|---------|
| **Lint** | `ruff`, `mypy` | Static analysis, type checking |
| **Test** | `pytest` | Unit tests (fast), integration tests (with PostgreSQL testcontainer) |
| **Build** | Docker build | Build production image, tag with git SHA |
| **Push** | Docker push | Push to private container registry (Docker Hub / Azure Container Registry) |
| **Deploy (staging)** | GitHub Actions / Azure DevOps | SSH deploy or Azure App Service deploy after staging approval |
| **Deploy (prod)** | Manual approval gate | Same as staging, requires approved PR to main branch |

**Git branching:**
- `main` — production-ready, protected
- `develop` — integration branch
- `feature/*` — feature work
- `fix/*` — bug fixes

### 7.8 On-Premise Deployment Notes

If cloud is not viable:
- All components (PostgreSQL, API, reverse proxy) run on a single Windows Server or Linux VM within the corporate network.
- TLS certificates from internal CA or Let's Encrypt (if domain-accessible).
- Backups to NAS or external USB drive.
- No cloud-specific dependencies beyond the filesystem abstraction layer.
- Deployment via Ansible playbook or manual Docker Compose.

### 7.9 Filesystem Storage Layout (v1)

```
/data/
  attachments/
    {report_type}/      # "corrective" or "preventive"
      {report_id}/
        {attachment_id}.{ext}    # actual file
        {attachment_id}_thumb.{ext}  # thumbnail (image attachments only)
  signatures/
    {report_type}/
      {report_id}/
        {signature_id}.png
  exports/              # generated PDFs, Excel exports (future)
```

The `FileStorageService` abstraction in the shared kernel allows future migration to Azure Blob Storage without changing domain or application code:

```python
class FileStorageService(ABC):
    @abstractmethod
    async def upload(self, path: str, content: bytes, content_type: str) -> str: ...
    @abstractmethod
    async def download(self, path: str) -> bytes: ...
    @abstractmethod
    async def delete(self, path: str) -> None: ...
```

### 7.10 Performance & Scalability Notes

- Current scale: ~11 users. Single server is sufficient for years.
- Monolith upgrade path: if performance becomes a concern, first optimize queries, then add read replicas, then extract bounded contexts.
- File uploads: limit individual attachment size to 10MB, total per report to 50MB.
- Image processing: server-side resize to max 1920px on upload, generate thumbnail.
- Connection pooling: use `asyncpg` connection pool (default: 10-20 connections).
- Caching: future `redis` for asset hierarchy cache if read performance degrades.

---

## 8. ADR Candidates

The following architectural decisions were made during the creation of this document. Each represents a significant design choice that should be formally documented as an Architecture Decision Record (ADR) before implementation begins.

| # | Title | Rationale | Implication |
|---|-------|-----------|-------------|
| ADR-001 | **Modular Monolith over Microservices** | ~11 users, single team, rapid development. DDD boundaries preserved within monolith. | Physical extraction path defined per module. No distributed transactions. |
| ADR-002 | **Adjacency List + Closure Table Dual Strategy** | Adjacency list for operational writes (single parent update). Closure table for read queries (subtree, ancestors). Synchronized in same transaction. | ~2x write cost; closure rebuild mechanism needed for consistency. |
| ADR-003 | **AssetAssignment as Temporal History Entity** | First-class entity tracking every move, install, removal, and replacement with effective dates. Enables time-travel queries. | More complex write path; simplifies audit and historical reporting. |
| ADR-004 | **In-Process Domain Events (No Message Broker)** | Monolith deployment, 11 users, no need for distributed messaging. Events are synchronous in transaction boundary. | Future extraction to message broker requires event schema compatibility. |
| ADR-005 | **Local Filesystem Storage with Abstraction Layer** | Simplest v1 storage; `FileStorageService` abstraction enables future blob migration. | Backup complexity; must plan for migration path early. |
| ADR-006 | **CQRS-Lite (No Separate Read/Write Models)** | Single model serves both purposes. Optimized projections (closure table, event store) exist within same database. | Read model tuning is per-use-case rather than architectural split. |
| ADR-007 | **Enum User Roles (Not RBAC)** | Four roles (Maintenance Engineer, Coordinator, Boss, Administrator). No requirement for custom role creation. | Future RBAC would require refactoring; document extensibility path. |
| ADR-008 | **Polymorphic Report References** | `Report` base with `CorrectiveReport` and `PreventiveReport` subtypes. Shared core fields, distinct behavior. | ORM mapping complexity; future evolution path to fully separate entities if divergence grows. |
| ADR-009 | **iPadOS/iOS 26.5 Native SwiftUI (Not React/Flutter)** | Enterprise Apple-platform deployment on current team devices. Premium animations, PencilKit, native camera API, adaptive TabView, and Liquid Glass-capable SwiftUI surfaces. | Single-platform only; future web frontend is a separate project. Requires Xcode/SDK support compatible with iOS 26.x; current local Xcode 26.2 accepts deployment target 26.5 with a warning until an SDK 26.5 toolchain is installed. |
| ADR-010 | **REST API over GraphQL** | Simple CRUD patterns, well-known ecosystem, easy to secure and cache. | Future GraphQL wrapper possible for complex hierarchy queries. |
| ADR-011 | **JWT Bearer Tokens (Short-Lived Access + Rotating Refresh)** | Access tokens remain stateless and short-lived. Refresh-token digests are persisted to support rotation and revocation. | Requires cleanup of expired `auth_refresh_sessions`; logout and password changes can revoke sessions immediately. |
| ADR-012 | **Event Store in Same PostgreSQL Instance** | Single database for transactional data and event store (separate schema). No operational complexity. | Migration path to dedicated event store if event volume grows significantly. |
| ADR-013 | **Optimistic Locking via `version` Column** | Concurrent modification detection for assets and reports. No pessimistic locks needed at current scale. | Retry logic required in application layer on `version` conflict. |
| ADR-014 | **Unified Asset Model for Equipment and Components** | The same traceability, hierarchy, replacement, stock, and history rules apply to large equipment and smaller replaceable components. | Reduces duplication in v1. Component Inventory may be split later if inventory complexity grows. |
| ADR-015 | **Jinja2 + WeasyPrint for PDF Generation** | PDF is a pure infrastructure concern. Jinja2 HTML templates + WeasyPrint rendering is the simplest Python PDF pipeline. No expensive report designer tooling. | Two templates (preventive/corrective). GeneratedReport entity for traceability only. In v1, generation is explicitly triggered from the read-only report-version screen. |
| ADR-016 | **Dynamic Corrective Report Blocks** | Corrective reports must follow the real report format and show specialized blocks only when needed, such as component replacement inside activities performed. | Avoids forcing a rigid six-section workflow. Requires block schemas and validation per task type. |
| ADR-017 | **Client-Side Share Sheet for v1 Email** | iOS native UIActivityViewController (Share Sheet) for PDF sharing — zero backend complexity. Backend async notification (email/SMS) is v2. Email is a presentation concern, not a domain concern. | PDF must be downloaded to device first. No delivery tracking, no scheduled notifications in v1. |
