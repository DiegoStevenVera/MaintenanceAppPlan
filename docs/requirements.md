# Requirements Document

**Version:** 0.2 (Draft)
**Phase:** Phase 2 — Requirements Definition
**Last Updated:** 2026-06-16

---

## Table of Contents

1. [Overview](#1-overview)
2. [Actors](#2-actors)
3. [Organizational Structure](#3-organizational-structure)
4. [Platform Modules](#4-platform-modules)
5. [Functional Requirements](#5-functional-requirements)
6. [Asset Management Requirements](#6-asset-management-requirements)
7. [Preventive Maintenance Requirements](#7-preventive-maintenance-requirements)
8. [Corrective Maintenance Requirements](#8-corrective-maintenance-requirements)
9. [Reporting Requirements](#9-reporting-requirements)
10. [Traceability Requirements](#10-traceability-requirements)
11. [Operational Constraints](#11-operational-constraints)
12. [Non-Functional Requirements](#12-non-functional-requirements)
13. [Future Extensibility Requirements](#13-future-extensibility-requirements)
14. [Open Questions](#14-open-questions)

---

## 1. Overview

### 1.1 Business Context

This platform is an enterprise maintenance management system for railway operations. The initial deployment targets the Signaling maintenance domain of Metro Lima Linea 2. The platform replaces or centralizes maintenance processes currently managed through manual workflows, spreadsheets, documents, and operational knowledge.

### 1.2 Scope

The initial scope includes two operational modules:

- **Preventive Maintenance Reports** — generation, execution, and historical recording of planned periodic maintenance activities.
- **Corrective Maintenance Reports** — generation, execution, and tracking of reactive maintenance activities triggered by incidents or failures.

The platform is designed for modular growth. Future modules, systems, and maintenance disciplines must be supported without structural redesign.

### 1.2.1 Current Planning Decisions

The following decisions supersede earlier draft assumptions:

- The initial device target is shared iPad devices used by the maintenance team. iPhone support is future and depends on corporate security approval.
- Current mock validation targets iPadOS 26.5 on the shared iPad. iPhone support targets iOS 26.5 but still requires physical-device validation.
- v1 is local-first: the app and backend will initially run in a local demonstration/development environment, such as an iPad connected to a Mac-hosted backend.
- The long-term deployment target is not approved yet. The architecture must allow on-premise, Azure, or AWS without coupling domain logic to any provider.
- PDF generation is required from the first version, even if the first templates are simple and use raw report data.
- Email delivery in v1 uses the iOS Share Sheet to share the generated PDF. Backend-managed email is future.
- The role formerly called "Supervisor" is now called "Boss". The Boss has read-only operational visibility and metrics access.
- The four application roles are Maintenance Engineer, Coordinator, Boss, and Administrator.
- Preventive and corrective maintenance use the same activity lifecycle: SCHEDULED, IN_PROGRESS, COMPLETED, CLOSED.
- Reports may be edited while the maintenance activity is not CLOSED. Edits create report versions. Once the maintenance activity is CLOSED, editing requires a Coordinator to reopen the activity.
- Assets and components are modeled with one unified Asset model. "Component" is an operational category of Asset, not a separate primary entity in v1.

### 1.3 Core Principles

- Centralize maintenance operational records.
- Digitize maintenance reporting.
- Standardize maintenance workflows where applicable.
- Preserve full historical traceability of assets, activities, and replacements.
- Support complex hierarchical asset structures with variable depth.
- Support multi-project deployment with data isolation.

### 1.4 Key Terminology

| Term | Definition |
|------|------------|
| PCON Plan | Annual preventive maintenance plan in Excel format specifying which activities are scheduled per month |
| Site | Geographic or organizational location (e.g., Metro Lima) |
| Project | Specific railway project (e.g., Metro Lima Linea 2, Metro Lima Linea 1, Madrid Linea 1) |
| Stage | Subdivision of a project (e.g., Stage 1A, 1B, 2A) |
| System | Maintenance discipline or domain (e.g., Signaling, Infrastructure, Civil, Networking) |
| Subsystem | Technical subdivision within a system (e.g., ATS, CBTC, IXL) |
| Corrective Event | An unplanned incident or failure that initiates corrective maintenance; may span multiple shifts and generate multiple reports |
| Maintenance Activity | A preventive or corrective maintenance work item that moves through SCHEDULED, IN_PROGRESS, COMPLETED, and CLOSED states |
| Maintenance Report | The operational document generated from a maintenance activity. It may have versions while the activity is still editable |
| Asset | Any trackable technical item, including trains, cabinets, servers, cards, fans, software, tools, and replaceable parts |
| Equipment / Equipo | Business-facing label for large or operationally meaningful Assets shown in the app as `Equipos`. These are the "equipos grandes" used for maintenance navigation, reporting, metrics, and history, and must be easy to distinguish from smaller assets such as cards, racks, cable runs, and replaceable components. |
| Component | A smaller or replaceable Asset category. It is not a separate top-level entity in v1 |
| Business Anchor Asset | A major or operationally meaningful Asset used for business questions, maintenance history, and metrics, such as a train, Zone Controller, Frontam cabinet, CRK cabinet, server, or functional software group |
| Report Scope Asset | An Asset linked to a maintenance activity or report because it is the primary target, an involved asset, an affected asset, or a replaced/installed component |
| Boss | Read-only leadership role formerly referred to as Supervisor in older draft documents |

---

## 2. Actors

### 2.1 Actor Catalog

| Actor | Role Description | System Interaction |
|-------|-----------------|-------------------|
| **Maintenance Engineer** | Engineer executing preventive and corrective activities on field equipment. Performs inspections, replacements, and documentation. Uses shared iPad devices. | Creates and edits reports while the activity is editable. Records asset replacements. Signs reports with drawn signature. Logs tools and materials used. Can create corrective events in v1. |
| **Coordinator** | Maintenance coordinator responsible for reviewing, closing, reopening, planning, documentation, and monthly work schedules. May also perform maintenance work. | All maintenance engineer capabilities. Can close and reopen maintenance activities. Future: manages planning, schedules, and documentation workflows. |
| **Boss** | Leadership/read-only role focused on metrics and operational visibility. Formerly called Supervisor in older drafts. | Read-only access to reports, maintenance activity details, summaries, and dashboards. No operational edits. |
| **Administrator** | System administrator with access to all capabilities. | Has all permissions from Maintenance Engineer, Coordinator, and Boss. Manages users, catalogs, configuration, and future admin features. |
| **Engineering Team** (External) | Defines technical maintenance procedures, equipment architecture, and hierarchy rules. External to the system. | Does not interact with the platform directly. Provides procedure definitions that must be loaded or entered by the maintenance team. |
| **Warehouse Team** (External) | Manages spare parts and tool inventory. External to the application initially. | The platform must show stock availability for replacement workflows, but the external warehouse process remains the operational source until a future integration exists. |

### 2.2 Actor Privileges Summary

| Capability | Maintenance Engineer | Coordinator | Boss | Administrator |
|------------|-----------|-------------|------|---------------|
| Create preventive report | Yes | Yes | No | Yes |
| Complete preventive report | Yes | Yes | No | Yes |
| Create corrective event | Yes (v1) | Yes | No | Yes |
| Create corrective report | Yes | Yes | No | Yes |
| Edit report while activity is editable | Yes | Yes | No | Yes |
| Sign report as participant | Yes | Yes | No, unless participating operationally | Yes |
| Asset replacement | Yes | Yes | No | Yes |
| Resolve / complete maintenance activity | Yes | Yes | No | Yes |
| Close maintenance activity | No | Yes | No | Yes |
| Reopen closed maintenance activity | No | Yes | No | Yes |
| View all reports | Yes | Yes | Yes | Yes |
| Assign weekly activities | No | Yes (future) | No | Yes |
| Assign shift schedule | No | Yes (future) | No | Yes |
| View dashboards / summaries | Yes | Yes | Yes | Yes |

---

## 3. Organizational Structure

### 3.1 Hierarchy

The platform supports a multi-level organizational hierarchy that determines data scope, module visibility, and operational context:

`
Site
 └── Project
      └── Stage
           └── System
                └── Subsystem
`

### 3.2 Examples

| Level | Example 1 | Example 2 | Example 3 |
|-------|-----------|-----------|-----------|
| Site | Metro Lima | Metro Lima | Metro Madrid |
| Project | Linea 2 | Linea 1 | Linea 1 |
| Stage | 1A | 1A | Phase 1 |
| System | Signaling | Signaling | Signaling |
| Subsystem | ATS, CBTC, IXL | CBTC | ATS |

### 3.3 Behavior Rules

- **OR-RQ-001:** Module visibility must be configurable per project and per stage. A project may enable modules only for specific subsystems.
- **OR-RQ-002:** The same subsystem (e.g., ATS) may exist in multiple projects with independent module configurations.
- **OR-RQ-003:** All activity and report data must be scoped to a project and may reference one or more stages for planning/reporting context.
- **OR-RQ-004:** Cross-project data visibility must be prohibited unless explicitly configured.
- **OR-RQ-005:** Stage must be treated as rollout/planning scope, not as a strict visibility boundary for maintenance engineers. Users may see assets and stations from all active stages in their project when their role allows it.
- **OR-RQ-006:** Assets and geographic locations may be assigned to one or more stages over time, supporting assets that operate across stages such as trains.
- **OR-RQ-007:** Future stage imports, such as Stage 1B assets and stations, must be addable without redesigning the asset hierarchy or report model.

---

## 4. Platform Modules

### 4.1 Current Modules

| Module | Status | Description |
|--------|--------|-------------|
| Preventive Maintenance Reports | Initial scope | Planned periodic maintenance activity recording |
| Corrective Maintenance Reports | Initial scope | Reactive incident-based maintenance recording |

### 4.2 Module Extension Points

The platform must provide explicit mechanisms for adding future modules. Each module must be able to:

- Register its own entities and fields while sharing the core asset hierarchy.
- Define its own visibility rules within the organizational hierarchy.
- Extend existing workflows without modifying core infrastructure.
- Access shared services (attachment storage, authentication, asset lookup, location lookup).

### 4.3 Planned Future Modules (Not in Scope)

- PCON Plan Management (annual planning)
- Weekly Activity Scheduling
- Shift Schedule Management
- Warehouse & Inventory Management
- Corrective Maintenance Procedure Standardization
- Manager Dashboards & Analytics
- SAP Integration
- Asset Lifecycle Management
- Predictive Maintenance (AI-assisted)
- Maintenance Scheduling & Calendar
- Notification & Approval Workflows

---

## 5. Functional Requirements

### 5.1 Authentication & Identity

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-AUTH-001 | The system must support individual user accounts with username and password authentication. | High |
| FR-AUTH-002 | Each drawn signature must be associated with the authenticated user account that produced it. | High |
| FR-AUTH-003 | The system must support session management appropriate for shared iPad devices (e.g., session timeout, re-authentication). | High |
| FR-AUTH-004 | The system must prevent a user from signing on behalf of another user. | High |
| FR-AUTH-005 | User profiles must support a profile image uploaded from the device gallery or a selectable default avatar provided by the app. | Medium |
| FR-AUTH-006 | In non-production environments, Administrators may temporarily preview the application through a real active user session of another role; this capability must be disabled in production. | Medium |

### 5.2 User Interface (iPad)

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-UI-001 | The primary interface must be designed for iPad usage with touch-first interaction. | High |
| FR-UI-002 | The interface must support field operation conditions (bright outdoor light, glove-friendly targets, minimal typing). | High |
| FR-UI-003 | The system must display only the modules and subsystems relevant to the current project and user role. | High |
| FR-UI-004 | Asset selection during maintenance must support both hierarchical navigation (drill-down through equipment tree) and direct search (by type, name, serial number, part number). | High |

### 5.3 Attachment Management

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-ATT-001 | The system must support image attachment capture from the iPad camera during report creation. | High |
| FR-ATT-002 | The system must support uploading stored images to reports. | High |
| FR-ATT-003 | All attachments must be permanently associated with the report they were uploaded to. | High |
| FR-ATT-004 | No attachment format or size limit shall be enforced at this stage (defined at infrastructure level). | Low |
| FR-ATT-005 | Attachments must be preserved as part of the historical record even after asset changes. | Medium |

### 5.4 Multi-Project Isolation

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-MPI-001 | Data from one project must not be visible to users of another project. | High |
| FR-MPI-002 | A user account must be tied to a single project and site initially; cross-project access is a future requirement. | Medium |
| FR-MPI-003 | Organizational hierarchy context must be available throughout all workflows. | High |

---
## 6. Asset Management Requirements

### 6.1 Asset Hierarchy

#### 6.1.1 Fundamental Nature

Assets in the system form a recursive tree structure where:

- An asset may contain zero or more child assets.
- Each child asset occupies a specific position or slot within its parent.
- There is no fixed maximum depth.
- Any asset type may be a child of any other asset type unless constrained by explicit rules.

#### 6.1.2 Asset Types

Assets must support categorization by type and category. The v1 model uses one unified Asset entity for all trackable technical items. "Component" is a category of Asset, not a separate primary entity.

| Asset Category | Examples | Has Serial Number | Has Part Number | Has Version |
|----------------|----------|-------------------|-----------------|-------------|
| Large Equipment | Train, Cabinet, Zone Controller | Optional | Usually via AssetType | No |
| Equipment | CC, BTM, TOD, Server, Fan, Workstation | Usually | Via AssetType | No |
| Component | Card (CIER, MTORE), PCSG, SCCR, replaceable server module | Usually | Via AssetType | No |
| Software | ATS, CBTC application | No | No | Yes |
| Tool | Maintenance tools and measuring equipment | Usually | Via AssetType when applicable | No |

#### 6.1.3 Asset Identity

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-ASM-001 | Every physical asset shall be uniquely identified by its serial number, when available. | High |
| FR-ASM-002 | Part number identifies the AssetType, not the individual Asset instance. Assets of the same type may share the same part number. | High |
| FR-ASM-003 | Software assets shall be identified by name and version number, not serial number. | High |
| FR-ASM-004 | The system must allow assets without serial numbers (e.g., trains, large cabinets where serial is not assigned). | High |
| FR-ASM-005 | The combination of (parent asset, slot/position, type) must be unique within the parent. | High |
| FR-ASM-022 | Every asset without a serial number must have a unique internal code generated or assigned by the system. | High |

#### 6.1.4 Business Anchor Assets and Report Scope

Business users commonly ask questions about major operational assets, not only about small replaceable components. The model must support this explicitly.

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-ASM-023 | The system must mark whether an Asset is a business anchor asset for reporting and operational navigation. | High |
| FR-ASM-024 | Maintenance activities must link to one or many report scope assets with an explicit role, such as primary target, involved asset, affected asset, replaced asset, installed asset, or context asset. | High |
| FR-ASM-025 | Preventive maintenance should normally use business anchor assets as the report scope, while corrective maintenance may additionally reference smaller component assets for replacement traceability. | High |
| FR-ASM-026 | Asset history queries for a business anchor asset must include maintenance performed directly on that asset and maintenance involving its descendant assets. | High |
| FR-ASM-027 | The system must allow logical or functional assets, such as "Software ATS Patio", when a maintenance activity targets a functional scope distributed across several physical servers. | Medium |
| FR-ASM-028 | The app must expose business anchor assets to users under the Spanish UI label `Equipos`, while technical documentation and schema may continue using Asset / BusinessAnchorAsset terminology. | High |
| FR-ASM-029 | The data model must support fast filtering of `Equipos` independently from smaller Assets such as cards, racks, cableado, replaceable parts, and other child components. | High |

#### 6.1.5 Hierarchy Rules

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-ASM-006 | The system must allow defining composition rules per asset type, per subsystem: which child types are allowed and in what order. | Medium |
| FR-ASM-007 | Composition rules must be configurable, not hardcoded. | Medium |
| FR-ASM-008 | Example rule: "A CC equipment type may contain exactly 2 cabinets; Cabinet 1 must contain rack types in a specific sequence: SCCR A, SCCR B, TIR A, TIR B, ..." | Medium |
| FR-ASM-009 | The system may initially support manual rule definition with validation enforcement deferred to a future phase. | Medium |

### 6.2 Locations

#### 6.2.1 Location Types

The platform distinguishes two separate location concepts:

| Location Type | Description | Examples | Applies To |
|---------------|-------------|----------|------------|
| **Geographic Location** | Physical geographic or facility location | Station, Tunnel section, Technical room, Open yard, Platform | Parent assets (cabinets, trains, zone controllers) |
| **Slot / Position** | Position of a child asset within its parent | Rack A, Slot 3, Coche M1, Interior, Puerta frontal | Child assets within their parent |

#### 6.2.2 Location Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-LOC-001 | Fixed-location assets must have a geographic location. | High |
| FR-LOC-002 | Mobile assets (trains) must have a location recorded at the time of maintenance only; continuous location tracking is out of scope. | High |
| FR-LOC-003 | Geographic locations must support hierarchical structure: Site > Facility > Area > Room, or similar. | Medium |
| FR-LOC-004 | Slot/position must be stored as a property of the parent-child relationship, not as a separate location entity. | High |
| FR-LOC-005 | An asset's geographic location may change over time; the system must preserve location history as part of asset traceability. | Medium |

### 6.3 Asset Lifecycle & Operations

#### 6.3.1 Asset Registration

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-ASM-010 | Assets may be registered in the hierarchy before or at the time of maintenance. | High |
| FR-ASM-011 | During corrective maintenance replacement, if the new component's serial number is not found in the database, the user must be able to enter it manually. The system shall register it as a new asset in the hierarchy. | High |
| FR-ASM-012 | Manually entered assets must be flagged as "manually registered" for traceability. | Medium |

#### 6.3.2 Asset Replacement

The asset replacement workflow is a critical operational path:

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-ASM-013 | When a component is replaced, the system must: (a) record the removed component's identity, origin, and destination; (b) record the installed component's identity and origin; (c) update the live hierarchy so the new component becomes the child of the parent asset; (d) preserve the removed component's history as part of the parent asset's historical record. | High |
| FR-ASM-014 | The source of the new component must be selected from known locations in the database (e.g., "SPV Warehouse", another train, another cabinet). | High |
| FR-ASM-015 | If the new component's serial number is unknown to the system, the user must provide: serial number, part number, and any additional required data. The system shall then register it and record the movement from its origin. | High |
| FR-ASM-016 | The removed component's destination must be recorded (e.g., warehouse, scrap, quarantine, repair). The maintenance engineer chooses the destination at time of replacement. | High |
| FR-ASM-017 | The system must maintain a bidirectional traceability link between a component and every parent asset it has ever belonged to. | High |

#### 6.3.3 Software Assets

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-ASM-018 | Software shall be recordable as a child asset of a server or hardware asset. | Medium |
| FR-ASM-019 | Software version updates shall be recorded as a simplified replacement event (only version number changes, no serial number). | Medium |
| FR-ASM-020 | Software assets do not require location or slot/position assignment beyond their parent-child relationship. | Medium |
| FR-ASM-021 | Preventive maintenance may be performed on the host server; software itself is not maintained (no code changes through the platform). | Medium |

### 6.4 Warehouse & Inventory Interface

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-INV-001 | The system must maintain its own view of warehouse inventory (spare components available at warehouse locations). | Medium |
| FR-INV-002 | Warehouse inventory is a best-effort representation. The platform is not the single source of truth for warehouse stock. | Medium |
| FR-INV-003 | When a component is moved from warehouse to an asset (during replacement), the system must decrement the warehouse record and create the asset in the hierarchy. | High |
| FR-INV-004 | When a removed component is sent to warehouse, the system must update the warehouse record to reflect the new stock. | High |
| FR-INV-005 | Warehouse inventory must be searchable by component type (part number) and serial number during the replacement workflow. | High |
| FR-INV-006 | The system must allow an asset to be registered directly in the warehouse (as available stock) without being installed in any equipment. | Medium |
| FR-INV-007 | Tools are separate from component inventory. Tools used in maintenance must be recorded by serial number. | High |
| FR-INV-008 | The Stock tab must list only Assets currently assigned to an inventory location and support server-side search across serial number, internal code, part number, type, and location. | High |

---
## 7. Preventive Maintenance Requirements

### 7.1 Nature of Preventive Maintenance

Preventive maintenance consists of planned, periodic activities performed on one or multiple assets according to a schedule defined by technical manuals.

Key characteristics:

- Activities are defined per asset type or per specific asset.
- An activity may involve one or multiple assets (e.g., "Inspect CRK-1 and CRK-2" is a single activity covering two cabinets).
- Each activity is associated with a specific location (e.g., "Frontam cabinet in patio location" vs "Frontam cabinet in colectora location").
- Activities are executed within a single shift (no shift handover for preventive work).

### 7.2 Activity Definition

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-PRV-001 | The system must allow defining preventive maintenance activities with associated assets, location, required tools, procedures, steps, and expected results. | High |
| FR-PRV-002 | A single preventive activity may be linked to one or multiple assets (both large and small). | High |
| FR-PRV-003 | Each activity must have a default location derived from its primary asset's geographic location. | High |
| FR-PRV-004 | Activity definitions must be scoped to a specific subsystem within a project. | High |
| FR-PRV-005 | Procedure definitions (steps, tests, result options) are defined by the Engineering team (external); the system must support importing or manually entering these definitions. | High |
| FR-PRV-006 | Activity definitions must include: activity name, associated assets, location, frequency (from manual), estimated duration, required tools, required personnel count. | Medium |

### 7.3 Planning & Scheduling

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-PRV-007 | The system must display the annual PCON plan as a 12-month quantity matrix grouped by subsystem, equipment category, geographic location, equipment, and equipment maintenance. Each monthly quantity is the number of planned maintenance executions, not an equipment count. | High |
| FR-PRV-008 | Coordinator and Administrator must be able to select monthly activities, propose an exact date and time range for a Monday-Sunday week, and adjust the proposal before confirmation. | High |
| FR-PRV-009 | A weekly planning meeting must be confirmed as one atomic block. If any proposal fails validation, none of the exact dates are published. Maintenance Engineer and Boss must have read-only PCON access. | High |
| FR-PRV-027 | Reprogramming a previously confirmed preventive activity must require a reason and retain both the previous and replacement ranges in planning history. | High |
| FR-PRV-028 | PCON must prevent overlapping proposals for the same primary equipment within the confirmed weekly block. | High |
| FR-PRV-029 | Monthly reassignment is permitted only before an activity starts and before it has an exact confirmed date. Activities with confirmed dates must use the weekly reprogramming flow. | High |
| FR-PRV-030 | Coordinator and Administrator may adjust a monthly PCON quantity. Increasing it creates individually schedulable occurrences; reducing it may remove only occurrences that have no exact date, proposal, execution, or report. | High |
| FR-PRV-031 | Opening a year without a persisted PCON plan must show the latest prior year's maintenance rows with zero monthly quantities. This virtual baseline does not create occurrences until an editor writes or explicitly copies the plan. | High |
| FR-PRV-032 | Coordinator and Administrator must be able to copy a prior annual plan into a target year. Copying preserves existing target cells, copies monthly quantities without exact weekly dates, and records the source year. | High |
| FR-PRV-033 | Coordinator and Administrator must be able to add an existing maintenance definition to an eligible equipment, create additional occurrences in any month, move untouched occurrences between months, and remove or cancel future occurrences under the applicable traceability rules. | High |
| FR-PRV-034 | Every annual-plan copy, maintenance-row addition, quantity change, occurrence move, removal, or cancellation must record actor, timestamp, affected year/month, quantity delta, and reason when supplied. | High |
| FR-PRV-035 | A cancelled PCON occurrence must not appear in preventive activity lists, annual quantities, weekly planning candidates, or dashboard counts, while remaining available in audit history. | High |

### 7.4 Report Execution

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-PRV-010 | When executing a preventive activity, the system must allow the maintenance engineer to: (a) confirm the activity being performed; (b) follow predefined steps/tests; (c) record results for each step; (d) attach images; (e) log tools used (by serial number); (f) log materials/spare parts consumed (general description, no precise quantity tracking); (g) record observations/comments; (h) record conclusions. | High |
| FR-PRV-011 | The system must support capturing a drawn signature from each participating maintenance engineer at report completion. | High |
| FR-PRV-012 | The system must allow multiple maintenance engineers to sign the same preventive report (all participants in the shift). | High |
| FR-PRV-013 | A preventive report must be completed within a single shift. No partial or handover reports for preventive activities. | High |
| FR-PRV-014 | Preventive reports remain editable while the maintenance activity is SCHEDULED, IN_PROGRESS, or COMPLETED. Each finalized edit creates a new report version. Once the activity is CLOSED, editing is blocked unless the Coordinator reopens the activity. | High |
| FR-PRV-015 | The system must support versioning of activity procedures (e.g., when the Engineering team updates a maintenance manual). | Medium |
| FR-PRV-018 | A preventive activity usually produces one main maintenance report, but the system must support additional report types for exceptional activities, such as track circuit calibration reports. | Medium |
| FR-PRV-019 | Preventive detail screens must show reusable maintenance comments in a chat-like thread, including author name, role, profile image/avatar, message, and scope context. These comments must be available to future executions of the same maintenance template or same business anchor equipment. | High |
| FR-PRV-020 | Preventive report general metadata must include site, project, stage, system, subsystem, current date, activity start time, editable activity end time, full geographic location path, equipment, and manual reference. All fields except activity end time are system-populated/read-only during execution. | High |
| FR-PRV-021 | The preventive report form must preselect the maintainers active on the current day as participants and allow users to uncheck anyone who did not participate. | High |
| FR-PRV-022 | Each maintenance step must contain its own tests/results section. Test results must use configured result options, presented as dropdowns when the result type is option-based. | High |
| FR-PRV-023 | Preventive conclusions must be selected from controlled values: Equipo operativo, Equipo no operativo, Equipo medio operativo. | High |
| FR-PRV-024 | Participant signatures should be captured from the participant row so each selected maintainer draws their own signature. | High |
| FR-PRV-025 | Preventive detail screens must show a reference image or visual identifier for the business anchor equipment being maintained. | Medium |
| FR-PRV-026 | Preventive detail screens must distinguish current report versions from previous reports performed on the same business anchor equipment. | High |
| FR-PRV-028 | Only preventive maintenance associated with a track-circuit asset may create a calibration report. Finalizing such maintenance must atomically finalize both the main preventive version and its companion calibration version. | High |
| FR-PRV-029 | Calibration captures track-circuit frequency in Hz, transmitter jumpers, and a receiver count from 1 to 4 in the current iPad UI. Each numbered receiver captures jumpers, TCA9, and rail current; the domain model must permit more receivers later without a schema change. | High |
| FR-PRV-030 | A finalized calibration version must have its own read-only detail, faithful HTML/PDF output, persisted generated-report metadata, PDF viewer, download, and iOS Share Sheet action. | High |

### 7.5 Historical Records

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-PRV-016 | All completed preventive reports must be searchable by: date range, asset, subsystem, maintenance engineer, activity type. | High |
| FR-PRV-017 | The system must display the last execution date of each preventive activity for visibility into upcoming due dates. | Medium |
| FR-PRV-027 | The system must show historical preventive reports for the selected business anchor equipment, including activity name, maintenance engineer, date, and final result. | High |

---

## 8. Corrective Maintenance Requirements

### 8.1 Nature of Corrective Maintenance

Corrective maintenance is reactive, triggered by unexpected incidents or failures. Key characteristics:

- Initiated by the first maintenance engineer arriving on site after receiving an SAP alarm notification and obtaining permissions.
- Activities may span multiple shifts; each shift produces its own corrective report.
- All corrective reports for a single incident are linked under a single "Corrective Event."
- Procedures are not predefined; the maintenance engineer records actions performed in a free-form or semi-structured manner.
- Asset replacements are a critical sub-workflow within corrective maintenance.

### 8.2 Corrective Event Lifecycle

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-COR-001 | The system must allow a maintenance engineer to create a new Corrective Event at the start of a corrective activity. | High |
| FR-COR-002 | A Corrective Event must capture: read-only project context (site, project, stage, system, subsystem), affected asset selected from the asset hierarchy, default asset location, SAP event name, SAP notification code, notice creation timestamp, response timestamp, description of the problem/incident, failure type (free text initially, standardized in future), and initiating maintenance engineer. | High |
| FR-COR-002A | The affected asset selector must first filter by subsystem, then start from a searchable business anchor `Equipo` and allow drilling down through lower asset/component levels before confirming the exact failed asset. Physical/geographic location must not appear as a selectable asset node. | High |
| FR-COR-003 | The system must allow multiple Corrective Reports to be linked to a single Corrective Event. | High |
| FR-COR-004 | Each Corrective Report must be associated with the shift in which it was generated (day or night shift). | High |
| FR-COR-005 | The system must display the event timeline across all shifts: all reports, actions, replacements, and timestamps in chronological order. | High |
| FR-COR-006 | When a new shift takes over, arriving maintenance engineers must be able to view all previous reports for the same Corrective Event. | High |
| FR-COR-007 | The system must support sending email notifications with completed reports to the next shift (manual or automatic). | Medium |

### 8.3 Corrective Report Content

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-COR-008 | Each Corrective Report must capture: maintenance engineer(s) involved, shift identification, date/time, SAP notification code, subsystem, equipment affected, physical location, recorded symptom, detailed technical description, operational impact, failure analysis, validation fields, conclusions, and signatures. | High |
| FR-COR-009 | The system must support recording maintenance actions/tasks in a semi-structured dynamic form: each task has a type, start date/time, end date/time, and task-specific fields. Standard activities capture description; component replacement captures removed/installed asset data. | High |
| FR-COR-010 | Task types must be configurable per system/subsystem and may include: "Component Replacement", "Inspection", "Cleaning", "Adjustment", "Measurement", "Software Action", "Other." | Medium |
| FR-COR-011 | When the task type is "Component Replacement", the system must invoke the asset replacement workflow (see FR-ASM-013 through FR-ASM-017). | High |
| FR-COR-012 | The system must support logging tools used in the corrective activity by serial number. | High |
| FR-COR-013 | The system must support image attachments captured or uploaded during the corrective report. | High |
| FR-COR-014 | The system must support free-text comments/observations. | High |
| FR-COR-015 | Each corrective report must be signed by all participating maintenance engineers before submission. | High |
| FR-COR-016 | Corrective reports can be created or edited only while the corrective event is IN_PROGRESS. Each finalized edit creates a new report version. Completed or closed events are read-only for report editing unless reopened into an editable state. | High |
| FR-COR-019 | Corrective reports must not be constrained to a fixed 6-section structure. The UI should follow the real corrective report format and use dynamic blocks, especially for component replacement activities. | High |

### 8.4 Asset Replacement Sub-Workflow

The asset replacement sub-workflow within corrective maintenance is defined in the Asset Management Requirements (Section 6.3.2). Key integration points:

- The replacement must be initiated from within the corrective report.
- The replacement record must be linked to both the corrective event and the corrective report.
- The system must update the live asset hierarchy to reflect the replacement.
- The old component's history must be preserved and traceable.

### 8.5 Event Closure

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-COR-017 | A Corrective Event may be marked COMPLETED/RESOLVED by a Maintenance Engineer or Coordinator when the work is finished. Only the Coordinator or Administrator may close it definitively. | High |
| FR-COR-018 | Closed events must remain fully accessible for historical review. | High |

---

## 9. Reporting Requirements

### 9.1 Report Types

| Report Type | Source Module | Description |
|-------------|---------------|-------------|
| Preventive Maintenance Report | Preventive | Detailed report of a completed preventive activity execution |
| Corrective Maintenance Report | Corrective | Detailed report of a corrective shift's work |
| Corrective Event Summary | Corrective | Aggregated view of all reports across shifts for a single event |

### 9.2 Report Content Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-RPT-001 | Every report must include: project/stage/system/subsystem context, date/time, maintenance engineer(s) names and signatures, equipment involved, location. | High |
| FR-RPT-002 | Preventive reports must include: activity name, procedure steps and results, tools used, observations, conclusions, attachments. | High |
| FR-RPT-003 | Corrective reports must include: SAP code, failure description, fault type, task list with types and descriptions, asset replacements (if any), tools used, attachments. | High |
| FR-RPT-004 | Both report types must include digital (drawn) signatures of all participating maintenance engineers. | High |
| FR-RPT-005 | Reports must be viewable on the iPad and exportable to a portable format (PDF) for sharing with the client. | High |

### 9.3 Future Reporting

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-RPT-006 | The system must support future generation of: summary reports (aggregated counts by type, by subsystem, by month), asset replacement reports, maintenance frequency reports, maintenance engineer workload reports. | Low |
| FR-RPT-007 | The system architecture must not prevent future dashboard and analytics capabilities for Boss and Administrator roles. | Medium |

---
## 10. Traceability Requirements

### 10.1 Core Traceability Principles

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-TRC-001 | Every modification to the asset hierarchy must be recorded with: timestamp, actor (user), action type, before/after state, and associated report ID (if applicable). | High |
| FR-TRC-002 | The system must support full audit trail for asset replacements: who replaced what, when, from where, to where, under which corrective event. | High |
| FR-TRC-003 | The system must preserve the complete history of parent-child relationships for every asset, even after the asset is removed from its current parent. | High |
| FR-TRC-004 | The system must preserve the complete history of geographic location changes for every asset. | Medium |
| FR-TRC-005 | The system must support querying the asset tree as it existed at any point in time (temporal/historical query capability). | Medium |

### 10.2 Maintenance History

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-TRC-006 | Every asset must display its complete maintenance history: all preventive and corrective reports that involved this asset. | High |
| FR-TRC-007 | Every asset must display its complete replacement history: every time this asset was installed or removed from a parent. | High |
| FR-TRC-008 | Every corrective event must display its complete report history in chronological order across all shifts. | High |

### 10.3 Report Integrity

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-TRC-009 | Report versions must be preserved. Editing an existing report creates a new version while retaining the previous generated PDF and data snapshot. | High |
| FR-TRC-010 | If a correction is needed after the activity is CLOSED, the Coordinator must reopen the maintenance activity before a new report version can be created. | High |
| FR-TRC-011 | Signatures must be stored as part of the report and must be verifiably linked to the authenticated user. | High |
| FR-TRC-012 | In v1, participant signatures are drawn on the shared iPad after selecting the participant name. Strong per-user approval workflows are future functionality. | Medium |

---

## 11. Operational Constraints

### 11.1 Hardware & Environment

| ID | Constraint | Impact |
|----|------------|--------|
| OC-001 | The primary device is a shared iPad (2 devices currently available for the team). Session management must support shared-device operation. | Authentication must be quick; session timeout must balance security with usability. |
| OC-002 | Devices operate in field conditions: tunnels, outdoor stations, technical rooms with limited lighting. UI must be high contrast, large touch targets, minimal text input. | Search and selection via hierarchical navigation and filtering preferred over typing. |
| OC-003 | iPhone support is future and depends on corporate security approval. | iPad UX is the initial target; iPhone optimization is out of scope for v1. |

### 11.2 External Dependencies

| ID | Constraint | Impact |
|----|------------|--------|
| OC-004 | The PCON annual plan is an external Excel file. No direct integration. | The system must support manual input or import of planned activities. |
| OC-005 | Weekly activity scheduling is done in Excel by the coordinator. | The system must accommodate flexibility in which activities are executed vs planned. |
| OC-006 | SAP notification codes are reference fields only. No real-time SAP integration. | SAP code is a manually entered text field. Future integration anticipated. |
| OC-007 | Warehouse inventory is maintained by a different area, but v1 must allow maintenance engineers to consult available stock for replacement workflows. | The system must handle cases where the warehouse view is outdated or incomplete. |
| OC-008 | Shift schedules are managed in Excel by the coordinator. | Maintenance Engineer assignment to shifts is out of scope; maintenance engineers self-identify. |

### 11.3 Workflow Constraints

| ID | Constraint | Impact |
|----|------------|--------|
| OC-009 | Preventive maintenance is single-shift only. | No partial completion or handover for preventive reports. |
| OC-010 | Corrective maintenance may span multiple shifts. | Event-level aggregation required; each shift produces independent reports. |
| OC-011 | Participant signatures are sufficient for report PDF generation. Closing the maintenance activity is a Coordinator action, not a Boss approval workflow. | Report completion and activity closure are separate states. |
| OC-012 | No formal incident classification system exists yet. Failure types are free text. | Corrective event classification must support future standardization without breaking existing data. |

---

## 12. Non-Functional Requirements

### 12.1 Scalability

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-SCL-001 | The system must support a minimum of 3 concurrent projects (e.g., Metro Lima Linea 2, Linea 1, Madrid Linea 1) with full data isolation. | High |
| NFR-SCL-002 | The system must support hierarchical asset trees with up to 10+ depth levels and thousands of assets per project without performance degradation. | High |
| NFR-SCL-003 | The system must support at least 10 concurrent iPad users. | High |
| NFR-SCL-004 | The system must support future expansion to hundreds of users across multiple projects. | Medium |

### 12.2 Performance

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-PRF-001 | Asset hierarchy navigation and search must complete within 2 seconds on typical field network conditions. | High |
| NFR-PRF-002 | Report submission (including image attachments) must complete within 5 seconds. | High |
| NFR-PRF-003 | The system must remain responsive under low-bandwidth or intermittent network conditions typical of tunnel environments. | Medium |

### 12.3 Reliability & Availability

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-RLB-001 | The system must preserve all in-progress report data in case of network interruption or device failure. | High |
| NFR-RLB-002 | Submitted reports must be durably stored and never lost. | High |
| NFR-RLB-003 | The system must support data synchronization when connectivity is restored after offline periods. | Medium |
| NFR-RLB-004 | Preventive and corrective report drafts, including signatures and evidence, must survive app termination while offline. | High |
| NFR-RLB-005 | Offline draft synchronization must detect a newer server report version and must not overwrite it silently. | High |

### 12.4 Security

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-SEC-001 | Authentication must be required for all system access. | High |
| NFR-SEC-002 | Passwords must be stored securely (hashed). | High |
| NFR-SEC-003 | A user must not be able to sign a report on behalf of another user. | High |
| NFR-SEC-004 | Data must be encrypted in transit. | High |
| NFR-SEC-005 | Data must be encrypted at rest. | High |
| NFR-SEC-006 | Session management must implement auto-logout after a configurable period of inactivity. | High |

### 12.5 Maintainability

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-MNT-001 | The system must be modular: adding a new module must not require modification of existing modules. | High |
| NFR-MNT-002 | Business rules (e.g., equipment composition rules, task types, module visibility) must be configurable, not hardcoded. | High |
| NFR-MNT-003 | The asset hierarchy model must be generic and not tied to a specific maintenance domain. | High |

---

## 13. Future Extensibility Requirements

### 13.1 Extension Point 1: Module Registration

The platform must define a mechanism by which future modules can be added without modifying core platform code. Each module must be able to:

- Register its own data entities that reference the core asset hierarchy.
- Define its own UI screens and navigation entries.
- Define its own visibility rules (by project, system, subsystem).
- Register its own workflows.

### 13.2 Extension Point 2: Event & Notification Framework

The platform should provide an event framework that future modules can hook into:

- Asset replacement events
- Report submission events
- Corrective event creation/closure events
- Preventive activity completion events

### 13.3 Extension Point 3: Integration Framework

The platform should provide an integration layer to support future connections with:

- SAP (reference code validation, notification creation)
- Warehouse management systems (inventory sync)
- External scheduling systems (PCON import)
- Email/SMS notification services

### 13.4 Extension Point 4: Analytics & Dashboard

The platform should store data in a structure that supports future:

- Aggregated maintenance metrics (MTBF, MTTR preparation)
- Asset reliability reporting
- Maintenance Engineer productivity analysis
- Maintenance cost tracking (future)
- Trend analysis on failure types (once standardized)

### 13.5 Explicitly Scoped for Future

| Capability | Current Status | Future Intent |
|-----------|----------------|---------------|
| PCON Plan Management | External Excel | Native module with calendar, scheduling, automated reminders |
| Weekly Activity Scheduling | External Excel | Native module with drag-and-drop planning, assignment to teams |
| Shift Schedule Management | External Excel | Native module with coordinator assignment, shift calendar |
| Inventory/Warehouse Management | Best-effort platform view | Full inventory sync with warehouse system |
| Corrective Procedure Standardization | Free text task types | Structured procedure library per subsystem |
| Dashboards | None | Boss and Administrator views with KPIs |
| SAP Integration | Manual reference code | API-based notification creation and status updates |
| Approval Workflows | Not required | Future approval gates, if needed, must remain separate from Coordinator closure |
| Notification System | Email only (manual) | In-app notifications, automated email alerts |
| Offline Mode | None | Full offline capability with sync |
| Mobile (iPhone) | Out of scope for v1 | Future mobile optimization after corporate security approval |
| Corrective Classification | Free text failure types | Standardized taxonomy with criticality levels |
| Lead Maintenance Engineer Role | Not defined | Role with elevated field privileges |

---

## 14. Open Questions

The following items were clarified during the requirements review. Items marked as "Resolved" are now considered decisions; "Pending" items still require external alignment.

| # | Question | Resolution / Answer | Owner | Status |
|---|----------|---------------------|-------|--------|
| OQ-001 | Should equipment composition rules be enforced strictly (prevent invalid configurations) or serve as guidelines/warnings? | Pending — requires alignment with the Engineering team to define enforcement level. | Engineering Team | Pending |
| OQ-002 | How is the PCON Excel file structured? Can it be imported programmatically? | It can be imported programmatically via an algorithm. A dedicated module for PCON import may be built in the future. | Maintenance Team | Resolved |
| OQ-003 | What is the exact process for obtaining permission to start corrective maintenance after an SAP alarm? Is this documented? | The process is not documented. The maintenance engineer calls OYM (Operations Yard Management) to communicate the intent. This is external to the app. | Maintenance Team | Resolved |
| OQ-004 | Should the system support "Draft" state for reports that are in progress but not yet submitted? | Yes. Drafts should be supported to handle network interruptions and partial completion. | Product | Resolved |
| OQ-005 | What are the retention/purging policies for historical data? | No retention policies defined. Store everything indefinitely. | Legal / Compliance | Resolved |
| OQ-006 | Should the system generate a unique corrective event ID or use the SAP code? | Both. The SAP code is the external reference (from another system). The app should also generate its own unique corrective event ID for internal cross-shift communication and linking. | Maintenance Team | Resolved |
| OQ-007 | What information does the weekly activity scheduling Excel contain, and what is the format? | The Excel table contains: Date, Start hour, Maximum end hour, Description, Code (a code different from SAP). A future module may manage this natively. | Coordinator | Resolved |
| OQ-008 | Should the platform support multiple languages? | Yes, in the future. Not required for initial version. | Product | Resolved |
| OQ-009 | Are there any regulatory or compliance requirements? | None identified at this moment. | Legal / Compliance | Resolved |
| OQ-010 | What is the expected frequency of corrective events per month? | Unknown. Cannot estimate at this time. | Maintenance Team | Pending |
| OQ-011 | Should the platform support a "Quick Search" across all assets by serial number or part number? | Yes. This should be available from the main screen. | Maintenance Engineer Team | Resolved |
| OQ-012 | How should the system prevent two maintenance engineers from working on the same corrective event simultaneously? | Implement a "Start Maintenance" action (without requiring any fields or details) that changes the event status to "In Progress." This status is visible to all users, preventing overlap. | Coordinator | Resolved |

---

*End of Requirements Document (Draft v0.1)*
