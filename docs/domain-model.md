# Domain Model

**Version:** 0.2 (Draft)
**Phase:** Phase 3 — Domain Modeling
**Last Updated:** 2026-06-06

---

## Table of Contents

1. [Domain Overview](#1-domain-overview)
2. [Ubiquitous Language](#2-ubiquitous-language)
3. [Organizational Context](#3-organizational-context)
4. [Core Domain: Asset Management](#4-core-domain-asset-management)
5. [Core Domain: Preventive Maintenance](#5-core-domain-preventive-maintenance)
6. [Core Domain: Corrective Maintenance](#6-core-domain-corrective-maintenance)
7. [Supporting Domain: Personnel](#7-supporting-domain-personnel)
8. [Supporting Domain: Inventory & Tools](#8-supporting-domain-inventory--tools)
9. [Cross-Cutting: Attachments](#9-cross-cutting-attachments)
10. [Entity Relationship Summary](#10-entity-relationship-summary)
11. [Aggregates & Ownership Boundaries](#11-aggregates--ownership-boundaries)
12. [Domain Constraints & Invariants](#12-domain-constraints--invariants)
13. [Lifecycle State Machines](#13-lifecycle-state-machines)
14. [Architectural Principles](#14-architectural-principles)
15. [Bounded Contexts (Modular Monolith)](#15-bounded-contexts-modular-monolith)
16. [Domain Events](#16-domain-events)
17. [Future Extensibility Considerations](#17-future-extensibility-considerations)
18. [Open Questions](#18-open-questions)

---

## 1. Domain Overview

### 1.1 Domain Statement

This platform manages the lifecycle of railway maintenance operations, including asset hierarchy management, preventive maintenance execution, and corrective maintenance tracking. The domain centers on the operational reality of maintaining complex, hierarchical equipment in a signaling system across multiple railway projects.

### 1.2 Subdomain Map

| Subdomain | Type | Description |
|-----------|------|-------------|
| Asset Management | **Core** | Recursive equipment hierarchy, types, composition rules, locations, replacements, historical traceability |
| Preventive Maintenance | **Core** | Procedure definitions, annual planning, weekly scheduling, report execution |
| Corrective Maintenance | **Core** | Incident events, multi-shift reporting, asset replacements, timeline management |
| Personnel | Supporting | User identities, roles, participation, drawn signatures |
| Inventory & Tools | Supporting | Flat tool inventory, warehouse stock (best-effort view of external system) |
| Organizational Context | Generic | Site/Project/Stage/System/Subsystem scoping |

### 1.3 Design Principles

- AssetType is a pure type descriptor, free of operational or contextual rules.
- Composition rules are scoped by Subsystem, not embedded in AssetType.
- The asset hierarchy is recursive and unbounded in depth.
- Identity is system-generated UUID; serial/part numbers are business identifiers (optional when unavailable).
- Draft is a document-level status, orthogonal to operational lifecycle status.
- Reports become immutable upon submission.
- Replacements are first-class domain entities affecting hierarchy, traceability, and history.

---

## 2. Ubiquitous Language

| Term | Domain Definition |
|------|------------------|
| Asset | Any equipment, component, or software entity in the maintenance hierarchy. Identified by system-generated UUID. May have serial number (optional). |
| AssetType | A pure classification of assets defining identity policies (serial number rules, part number rules, support for versioning). Does not define composition rules. |
| AssetCompositionRule | A contextual policy defining which child AssetTypes a parent AssetType may contain, in what quantity, and in which position. Scoped per Subsystem. |
| GeographicLocation | A physical facility or geographic position (station, tunnel section, technical room). Applies to fixed and mobile assets. |
| Slot / Position | The specific position a child asset occupies within its parent asset. Stored as a property of the parent-child relationship. |
| AssetReplacement | A first-class domain entity recording the replacement of one component by another, including origin, destination, timestamp, and responsible personnel. |
| MaintenanceTemplate | The standard definition of a preventive maintenance procedure, including steps, tests, required tools, and expected results. |
| MaintenancePlanEntry | A long-term planning record linking a template to a specific period (e.g., PCON: "perform this activity in March"). |
| MaintenanceSchedule | A concrete scheduled occurrence derived from a plan entry, specifying date, shift, and assigned personnel. |
| PreventiveReport | The execution record of a scheduled preventive maintenance activity. Captures step results, tools used, participants, and signatures. |
| CorrectiveEvent | An unplanned incident or failure triggering corrective maintenance. Has an explicit lifecycle: not-started, in-progress, resolved, closed. |
| CorrectiveReport | The shift-level report within a corrective event. Records tasks, replacements, tools, participants, and signatures. |
| CorrectiveTask | A single action or step performed during corrective maintenance. May trigger an AssetReplacement if the task type is "Component Replacement." |
| TaskType | A configurable classification of corrective actions (e.g., Component Replacement, Inspection, Cleaning). Scoped per Subsystem. |
| Participant | A technician who participated in a maintenance activity, linked to the report with their drawn signature. |
| Draft | A document-level status indicating the report is being created and not yet finalized. Independent of operational status. |
| PCON | Annual preventive maintenance plan expressed as a collection of MaintenancePlanEntry instances. Originates as an external Excel file. |
| SAP Code | An external reference identifier from the SAP system. Not used for system-internal identity. |
| AssetAssignment | A first-class entity representing a period during which an Asset was installed at a specific position within a parent Asset. Used for historical hierarchy reconstruction and temporal queries. |
| Domain Event | An in-process event representing a significant occurrence within the domain, used for internal consistency workflows and decoupling within the modular monolith. Not a distributed integration event. |
| Integration Event | A future event type intended for communication with external systems (SAP, warehouse, analytics). Not yet implemented. |
| UserProjectAssignment | A join entity that explicitly associates a User with a Project. Currently implicit (one user, one project); future cross-project support uses this model. |

---

## 3. Organizational Context

### 3.1 Purpose

The organizational context provides operational scoping for all domain entities. It controls module visibility, data isolation, and the applicability of rules (such as asset composition).

### 3.2 Hierarchy

`
Site
 └── Project
      └── Stage
           └── System
                └── Subsystem
`

### 3.3 Entities

| Entity | Description |
|--------|-------------|
| **Site** | Geographic or operational location (e.g., Metro Lima). |
| **Project** | A railway project within a site (e.g., Linea 2, Linea 1, Madrid Linea 1). |
| **Stage** | A subdivision or phase of a project (e.g., 1A, 1B, 2A). |
| **System** | A maintenance discipline or domain (e.g., Signaling, Infrastructure, Civil, Networking). |
| **Subsystem** | A technical subsystem within a system (e.g., ATS, CBTC, IXL for Signaling). |

### 3.4 Domain Rules

| Rule | Description |
|------|-------------|
| CTX-R001 | Module visibility is configured per Project and Stage, and may enable modules only for specific Subsystems. |
| CTX-R002 | The same Subsystem name may exist under different Projects with independent configurations. |
| CTX-R003 | All assets, activities, and reports are scoped to a Subsystem within a Project and Stage. |
| CTX-R004 | Cross-project data visibility is prohibited. A user is tied to a single Project. |

### 3.5 Relationship to Core Domain

The organizational context acts as a **root scope** for all aggregates:

- Every **Asset** belongs to one Subsystem.
- Every **AssetCompositionRule** is defined for one Subsystem.
- Every **MaintenanceTemplate** belongs to one Subsystem.
- Every **CorrectiveEvent** belongs to one Subsystem.
- Every **User** is scoped to one Project (initially).

---

## 4. Core Domain: Asset Management

### 4.1 Overview

Asset Management is the central subdomain of the platform. It manages a recursive equipment hierarchy with unbounded depth, where every item of equipment or software is represented as an Asset. The hierarchy supports variable depth per branch, multiple asset types, composition rules, geographic and positional location, and full historical traceability including replacements.

### 4.2 Asset

#### 4.2.1 Description

An Asset is a node in the recursive equipment hierarchy. It represents any physical or logical entity subject to maintenance.

#### 4.2.2 Attributes

| Attribute | Type | Description | Constraints |
|-----------|------|-------------|-------------|
| id | System-generated UUID | Internal unique identifier | Primary identity. Never exposed as a business key externally unless needed. |
| name | String | Human-readable designation (e.g., "Tren 14", "CRK 1", "CIER 1") | Required |
| serialNumber | String (optional) | Manufacturer-assigned serial number | Nullable. Unique when present. Not all assets have serial numbers. |
| partNumber | String (optional) | Manufacturer-assigned part number identifying the type | Nullable. Multiple assets may share the same part number. |
| assetType | Reference to AssetType | Classification of this asset | Required |
| parentAsset | Self-reference (optional) | The containing parent asset | Null for top-level assets. An asset has at most one direct parent at any time. |
| position | String (optional) | Slot or position within the parent asset | Required when parentAsset is set. Describes where the asset lives within its parent (e.g., "Coche M1", "Rack A", "Slot 3"). Free-text or constrained by composition rules. |
| geographicLocation | Reference to GeographicLocation (optional) | Current operational geographic location | Required for fixed-location assets. Optional for mobile assets. Represents the latest known location, may change over time. |
| subsystem | Reference to Subsystem | The subsystem this asset belongs to | Required. Determines which composition rules apply. |
| isMobile | Boolean | Whether this asset changes geographic location | Derived from AssetType policy or explicit. True for trains. |
| registrationMethod | Enum: PRE_REGISTERED, MANUAL | How the asset was entered into the system | MANUAL means the asset was entered ad-hoc during corrective maintenance. |
| lifecycleStatus | Enum: ACTIVE, REMOVED, SCRAPPED, IN_WAREHOUSE | Current operational status | ACTIVE = installed in hierarchy and operational. REMOVED = was in hierarchy but removed. SCRAPPED = discarded. IN_WAREHOUSE = stored as spare. |
| softwareVersion | String (optional) | Version number for software assets | Only applicable when assetType.supportsVersion is true. |
| createdAt | Timestamp | When the asset record was created | Immutable after creation |

#### 4.2.3 Identity Rules

| Rule | Description |
|------|-------------|
| ASM-ASM-001 | The system-generated UUID is the permanent identity of an Asset. It must never be reused or reassigned. |
| ASM-ASM-002 | Serial number is a business identifier. It must be unique when present, but is not required. |
| ASM-ASM-003 | An asset without a serial number is still fully valid in the hierarchy. Its identity is the UUID. |
| ASM-ASM-004 | Part number identifies the type of asset, not the individual instance. Multiple assets share the same part number. |

#### 4.2.4 Recursive Structure Rules

| Rule | Description |
|------|-------------|
| ASM-REC-001 | An Asset may contain zero or more child Assets. |
| ASM-REC-002 | There is no maximum depth. The hierarchy is fully recursive. |
| ASM-REC-003 | Each child must have a defined position/slot within its parent. |
| ASM-REC-004 | The combination (parentAsset + position) must be unique. No two children can share the same position. |
| ASM-REC-005 | An Asset cannot be its own ancestor (acyclic constraint). |
| ASM-REC-006 | An Asset can have only one direct parent at any point in time. |
| ASM-REC-007 | When an Asset is removed from a parent, the parent-child relationship is preserved historically (the relationship is not deleted, only deactivated). |
| ASM-REC-008 | Hierarchy traversal optimization strategies (closure table, materialized path, graph traversal, ltree, etc.) are infrastructure concerns and intentionally excluded from the domain model. The current model assumes recursive Asset references with adjacency semantics. |
| ASM-REC-009 | Recursive traversal across multiple Asset nodes is a query concern, not aggregate ownership. Full subtree loading into memory is prohibited by design. |

### 4.3 AssetType

#### 4.3.1 Description

AssetType is a pure type descriptor. It defines what an Asset *is*, not how it fits into the hierarchy. Composition rules are intentionally separated into AssetCompositionRule (Section 4.5).

#### 4.3.2 Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| id | UUID | Internal identifier |
| name | String | Type name (e.g., "Train", "Cabinet", "Server", "CIER Card", "Software", "Workstation") |
| serialNumberPolicy | Enum: REQUIRED, OPTIONAL, NOT_APPLICABLE | Whether assets of this type must, may, or cannot have serial numbers |
| partNumberPolicy | Enum: REQUIRED, OPTIONAL, NOT_APPLICABLE | Whether assets of this type must, may, or cannot have part numbers |
| supportsVersion | Boolean | Whether assets of this type use version numbers instead of or in addition to serial numbers (true for Software) |
| description | String | Free-text description of this type |

#### 4.3.3 Domain Rules

| Rule | Description |
|------|-------------|
| ASM-TYPE-001 | AssetType must not contain composition rules or hierarchy policies. Composition is a separate concern (see AssetCompositionRule). |
| ASM-TYPE-002 | AssetType identification policies determine validation rules: a "Card" type REQUIRES serial number and part number; a "Train" type may have serialNumberPolicy = OPTIONAL. |
| ASM-TYPE-003 | AssetType definitions are shared across all Projects and Subsystems. They form a global catalog. |
| ASM-TYPE-004 | If a future Project or Subsystem needs a type with different policies, a new AssetType should be created rather than modifying an existing one with conditional logic. |

#### 4.3.4 Examples

| AssetType | Serial Number Policy | Part Number Policy | Supports Version |
|-----------|---------------------|-------------------|------------------|
| Train | OPTIONAL | OPTIONAL | false |
| Cabinet | OPTIONAL | OPTIONAL | false |
| Cargo Controller (CC) | OPTIONAL | OPTIONAL | false |
| Server | REQUIRED | REQUIRED | false |
| Card (CIER, MTORE) | REQUIRED | REQUIRED | false |
| Software | NOT_APPLICABLE | NOT_APPLICABLE | true |
| Workstation | OPTIONAL | OPTIONAL | false |
| Fan | OPTIONAL | OPTIONAL | false |
| Tool | REQUIRED | OPTIONAL | false |

### 4.4 GeographicLocation

#### 4.4.1 Description

GeographicLocation represents a physical place where assets are situated. The platform distinguishes between:

- **Geographic Location**: A physical facility or area (station, tunnel section, technical room, open yard).
- **Slot/Position**: The position within a parent asset (handled as a property of the parent-child relationship, NOT as a GeographicLocation).

#### 4.4.2 Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| id | UUID | Internal identifier |
| name | String | Human-readable name (e.g., "Estación San Borja", "Túnel San Borja - La Cultura") |
| locationType | Enum: STATION, TUNNEL_SECTION, TECHNICAL_ROOM, OPEN_YARD, PLATFORM, OTHER | Classification of the location |
| parentLocation | Self-reference (optional) | Hierarchical containment (e.g., Technical Room belongs to a Station) |
| fullPath | String (derived) | Computed full path from root (e.g., "Metro Lima / Linea 2 / Estación San Borja / Sala Técnica 1") |

#### 4.4.3 Domain Rules

| Rule | Description |
|------|-------------|
| ASM-LOC-001 | Fixed-location assets must have a geographic location. This is the current operational location and may change. |
| ASM-LOC-002 | Mobile assets (trains) may have an optional current geographic location representing the latest known operational position. Location history is preserved. |
| ASM-LOC-003 | When maintenance is performed, the location at the time of maintenance must be recorded on the report (immutable snapshot). This is separate from the asset's current location. |
| ASM-LOC-004 | Geographic locations form a hierarchy but are not equivalent to the organizational hierarchy (Site/Project/Stage). They represent physical geography. |

### 4.5 AssetCompositionRule

#### 4.5.1 Description

AssetCompositionRule is a contextual policy model, explicitly separated from AssetType. It defines which child AssetTypes a parent AssetType is allowed to contain, in what quantity, and in which position. Rules are scoped per Subsystem.

This separation allows:
- The same AssetType (e.g., "Cabinet") to have different compositions under different Subsystems.
- Future Projects to define their own composition rules without modifying the AssetType catalog.
- Hierarchy policies to evolve independently from type definitions.

#### 4.5.2 Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| id | UUID | Internal identifier |
| subsystem | Reference to Subsystem | The subsystem context for this rule |
| parentAssetType | Reference to AssetType | The parent type this rule applies to |
| childAssetType | Reference to AssetType | The child type allowed under the parent |
| minQuantity | Integer (default: 0) | Minimum number of this child type required |
| maxQuantity | Integer (default: unlimited) | Maximum number of this child type allowed |
| allowedPositions | List of String (ordered) | The exact list of valid position names for children of this type. Position determines child order. |
| childOrderIndex | Integer | Specifies the overall ordering of this child type relative to other child types within the same parent |

#### 4.5.3 Domain Rules

| Rule | Description |
|------|-------------|
| ASM-CMP-001 | Composition rules are scoped per Subsystem. The same parent-child type pair may have different rules in different Subsystems. |
| ASM-CMP-002 | If no composition rule exists for a given (subsystem, parentAssetType, childAssetType) combination, any quantity and position is allowed (no constraint). |
| ASM-CMP-003 | allowedPositions, when defined, constrains the valid values for the position field of child Assets. |
| ASM-CMP-004 | Enforcement of composition rules (strict vs advisory) is deferred to a future phase (see OQ-001). |
| ASM-CMP-005 | Composition rules are reviewed by the Engineering team. They may be imported or entered manually. |

#### 4.5.4 Example

For Subsystem "CBTC", parent type "Cargo Controller (CC)":
`
Rule 1: parent=CC, child=Cabinet, min=2, max=2, allowedPositions=["Cabinet 1", "Cabinet 2"]
Rule 2: parent=Cabinet, child=SCCR, allowedPositions=["SCCR A", "SCCR B"]
Rule 3: parent=SCCR, child=Card, allowedPositions=["ACSDVP 11", "CCTE 1", "CBOP 1"]
`

For Subsystem "ATS", parent type "Cabinet":
`
Rule 1: parent=Cabinet, child=Server, allowedPositions=["LIMSYS001", "LIMSYS002", "LIMCOM001"]
`

### 4.6 AssetReplacement

#### 4.6.1 Description

AssetReplacement is a first-class domain entity representing the operation of removing one component and installing another. It affects multiple concerns: the asset hierarchy, operational traceability, lifecycle history, location history, and maintenance history.

Replacements may occur during corrective maintenance initially, but the model supports standalone replacement operations in the future (e.g., bulk updates when all equipment is mapped).

#### 4.6.2 Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| id | UUID | Internal identifier |
| removedAsset | Reference to Asset | The component that was taken out |
| installedAsset | Reference to Asset | The component that was put in |
| parentAsset | Reference to Asset | The parent asset where the replacement occurred (the common parent of both removed and installed) |
| position | String | The position/slot within the parent where the replacement occurred |
| source | Reference or Text | Where the installed asset came from (e.g., WarehouseLocation, another parent asset, or free text) |
| destination | Reference or Text | Where the removed asset went (e.g., WarehouseLocation, "SCRAPPED", "REPAIR", "QUARANTINE") |
| replacedAt | Timestamp | When the replacement occurred |
| responsibleUser | Reference to User | Who performed the replacement |
| relatedCorrectiveEvent | Reference to CorrectiveEvent (optional) | The corrective event this replacement is part of (if applicable) |
| relatedCorrectiveReport | Reference to CorrectiveReport (optional) | The specific report this replacement is recorded in (if applicable) |
| reason | Text | Free-text explanation of why the replacement was necessary |

#### 4.6.3 Replacement Effect Rules

| Rule | Description |
|------|-------------|
| ASM-RPL-001 | When a replacement is recorded, the system must atomically: (a) update the live hierarchy so installedAsset becomes a child of parentAsset at the specified position; (b) remove removedAsset from the hierarchy (set its parent to null); (c) create the AssetReplacement record; (d) set removedAsset.lifecycleStatus to the appropriate state (REMOVED, SCRAPPED, or IN_WAREHOUSE); (e) set installedAsset.lifecycleStatus to ACTIVE. |
| ASM-RPL-002 | The removedAsset's history as a child of parentAsset is preserved. The relationship is not deleted, only deactivated. |
| ASM-RPL-003 | The installedAsset's previous parent (if any) is updated to reflect the removal. |
| ASM-RPL-004 | If installedAsset is new to the system (not found in the database), it must be created ad-hoc as part of the replacement operation. See Asset.registrationMethod. |
| ASM-RPL-005 | The source and destination must be recorded even if they refer to unmanaged locations (free text is acceptable). |
| ASM-RPL-006 | A replacement is always associated with a parentAsset. A replacement without a parent (e.g., direct warehouse transfer) is a different operation (inventory management, future scope). |

#### 4.6.4 Replacement Chain

A component may be replaced multiple times over its life. The system must support traversing the replacement chain:

`
Asset X was installed in Parent A
  → replaced by Asset Y (Timestamp T1, Reason R1)
  → replaced by Asset Z (Timestamp T2, Reason R2)
`

Each replacement preserves backward references: given Asset Y, the system can show that it was installed in Parent A, removed at T1, and replaced by Z.

### 4.7 AssetAssignment

#### 4.7.1 Description

AssetAssignment is a first-class entity for temporal hierarchy and history tracking. It represents a period during which an Asset was installed at a specific position within a parent Asset. While Asset.parentAsset and position remain the authoritative current-state operational structure, AssetAssignment provides the historical and audit representation of hierarchy membership over time.

**Important distinction:** The current operational hierarchy is always read from Asset.parentAsset. AssetAssignment is the append-only historical record. Current hierarchy updates must automatically create or close assignment records.

#### 4.7.2 Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| id | UUID | Internal identifier |
| assetId | Reference to Asset | The Asset whose assignment is being recorded |
| parentAssetId | Reference to Asset (nullable) | The parent Asset at the time of assignment. Null for warehouse, scrapped, or top-level assets. |
| position | String (optional) | The position/slot within the parent at the time of assignment |
| assignedAt | Timestamp | When this assignment began |
| assignedBy | Reference to User (optional) | Who performed the assignment operation |
| assignmentReason | String (optional) | Context: "initial_registration", "replacement", "reinstall", "warehouse_transfer" |
| deactivatedAt | Timestamp (optional) | When this assignment ended. Null means currently active. |
| deactivationReason | String (optional) | Context: "replaced", "scrapped", "warehouse_transfer", "removed" |
| replacedByAssignmentId | Reference to AssetAssignment (self, optional) | The next assignment in the replacement chain, if applicable |

#### 4.7.3 Domain Rules

| Rule | Description |
|------|-------------|
| AST-ASG-001 | Only one active AssetAssignment may exist for an Asset at a time. Active means deactivatedAt IS NULL. |
| AST-ASG-002 | Assignment intervals for the same Asset must not overlap. |
| AST-ASG-003 | A replacement operation must close the previous assignment (set deactivatedAt) and create the new assignment atomically within the same transaction. |
| AST-ASG-004 | Warehouse assets may have null parentAssetId in their active assignment. |
| AST-ASG-005 | AssetAssignment is append-only. Historical records must never be physically deleted. Deactivation is done by setting deactivatedAt. |
| AST-ASG-006 | When Asset.parentAsset or position is updated, the corresponding AssetAssignment must be created or deactivated accordingly. |

#### 4.7.4 Supported Queries

AssetAssignment enables the following temporal and historical queries:

- "Where was Asset X installed on 2026-03-15?" — find the assignment record where assignedAt ≤ T and (deactivatedAt IS NULL OR deactivatedAt > T).
- "What was the composition of Train Y at time T?" — find all assignments where parentAssetId = Train Y AND interval overlaps T.
- "Show the replacement lineage of this card" — follow the replacedByAssignmentId chain.
- "How many times has this component been installed and removed?" — count all assignments for an Asset.
- "Where did this asset go after it was removed from Train 14?" — find the next assignment after deactivation.

### 4.8 Warehouse Location (Asset Context)

WarehouseLocation is a simple label indicating that an Asset is stored as spare inventory rather than installed in the equipment hierarchy.

| Attribute | Type | Description |
|-----------|------|-------------|
| id | UUID | Internal identifier |
| name | String | Warehouse name (e.g., "SPV Warehouse") |
| description | Text | Optional description |

#### Domain Rules

| Rule | Description |
|------|-------------|
| ASM-WHS-001 | An Asset with lifecycleStatus = IN_WAREHOUSE has no parentAsset (parent is null) and its geographicLocation is the WarehouseLocation. |
| ASM-WHS-002 | Warehouse stock is a best-effort representation. The platform is not the single source of truth. |
| ASM-WHS-003 | An Asset may transition between warehouse and hierarchy multiple times over its life. Each transition is recorded as a replacement or movement. |
| ASM-WHS-004 | Warehouse inventory is searchable by part number and serial number during replacement workflows. |

### 4.9 Asset Lifecycle Summary

`
[Creation]
    │
    ▼
REGISTRATION (PRE_REGISTERED or MANUAL)
    │
    ├──► ACTIVE (assigned to a parent in the hierarchy)
    │        │
    │        ├──► REMOVED (removed from parent, not yet assigned to new location)
    │        │        │
    │        │        ├──► IN_WAREHOUSE (stored as spare)
    │        │        ├──► SCRAPPED (discarded)
    │        │        └──► ACTIVE (reinstalled elsewhere)
    │        │
    │        └──► IN_WAREHOUSE (direct transfer without removal)
    │
    └──► IN_WAREHOUSE (registered directly as spare stock)
`

---

## 5. Core Domain: Preventive Maintenance

### 5.1 Overview

Preventive Maintenance follows a four-layer separation: **definition** (what to do), **planning** (when to do it broadly), **scheduling** (concrete assignment), and **execution** (what was actually done). This separation preserves traceability and supports the current externally-managed PCON process while preparing for future native modules.

### 5.2 MaintenanceTemplate

#### 5.2.1 Description

The authoritative definition of a preventive maintenance procedure. Created by the Engineering team and imported or entered into the system. Templates may be versioned.

#### 5.2.2 Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| id | UUID | Internal identifier |
| name | String | Activity name (e.g., "Inspección FRONTAM", "Limpieza Estación Trabajo FRONTAM") |
| subsystem | Reference to Subsystem | The subsystem this procedure belongs to |
| relatedAssetTypes | List of Reference to AssetType | Which asset types this procedure applies to |
| frequency | Text | Frequency specification from the technical manual (e.g., "Monthly", "Every 3 months") |
| estimatedDuration | Duration | Expected time to complete |
| requiredPersonnelCount | Integer | Minimum number of technicians required |
| version | String | Version identifier for this procedure definition |
| isActive | Boolean | Whether this template is currently in use |
| createdAt | Timestamp | Creation timestamp |
| effectiveDate | Date | When this version became effective |

#### 5.2.3 Contained Value Objects

**MaintenanceStep** (ordered collection within Template):

| Attribute | Type | Description |
|-----------|------|-------------|
| orderIndex | Integer | Step sequence number |
| description | Text | What to do in this step |
| testType | String (optional) | Type of test or measurement (configurable) |
| resultOptions | List of String (optional) | Predefined result values (e.g., "Pass", "Fail", "N/A", or specific measurements) |
| requiresPhoto | Boolean | Whether a photo attachment is required for this step |

**ToolRequirement** (collection within Template):

| Attribute | Type | Description |
|-----------|------|-------------|
| toolName | String | Name or description of required tool |
| quantity | Integer | How many units needed |

#### 5.2.4 Domain Rules

| Rule | Description |
|------|-------------|
| PRV-TPL-001 | A template belongs to exactly one Subsystem. |
| PRV-TPL-002 | Templates may be versioned. When a new version is created, future schedules should reference the new version. |
| PRV-TPL-003 | Completed reports reference the template version that was current at the time of execution. |
| PRV-TPL-004 | A template may be linked to one or more AssetTypes, indicating it applies to assets of those types. |

### 5.3 MaintenancePlanEntry

#### 5.3.1 Description

A planning-level entity representing the annual PCON plan. It defines which activities should be performed in a given month, without specifying the exact date or personnel.

#### 5.3.2 Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| id | UUID | Internal identifier |
| template | Reference to MaintenanceTemplate | The activity to perform |
| subsystem | Reference to Subsystem | Operational scope |
| year | Integer | Planning year |
| month | Integer | Planning month (1-12) |
| plannedDate | Date (optional) | Specific day if known at planning time |
| scope | Text | Which specific assets or locations this plan entry covers (free text, may reference specific asset serial numbers or location names) |
| source | Enum: PCON_IMPORT, MANUAL | How this entry was created |

#### 5.3.3 Domain Rules

| Rule | Description |
|------|-------------|
| PRV-PLN-001 | A MaintenancePlanEntry is derived from the external PCON Excel file or manually entered. |
| PRV-PLN-002 | Multiple entries may reference the same template for different months or different asset scopes. |
| PRV-PLN-003 | Plan entries are independent of scheduling; a plan entry may generate zero, one, or multiple MaintenanceSchedule instances. |

### 5.4 MaintenanceSchedule

#### 5.4.1 Description

A concrete scheduled occurrence of a preventive activity. Created during weekly planning meetings when specific activities from the monthly PCON plan are selected for the upcoming week.

#### 5.4.2 Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| id | UUID | Internal identifier |
| planEntry | Reference to MaintenancePlanEntry (optional) | The plan entry this schedule derives from |
| template | Reference to MaintenanceTemplate | The activity to perform |
| scheduledDate | Date | When the activity is scheduled |
| scheduledShift | Enum: DAY, NIGHT | Which shift should perform it |
| assignedTechnicians | List of Reference to User (optional) | Which technicians are assigned (informational for now) |
| status | Enum: SCHEDULED, IN_PROGRESS, COMPLETED, CANCELLED | Current scheduling status |
| location | Reference to GeographicLocation (optional) | Where the activity will be performed |

#### 5.4.3 Domain Rules

| Rule | Description |
|------|-------------|
| PRV-SCH-001 | A schedule is created by selecting activities from plan entries during weekly planning. |
| PRV-SCH-002 | One plan entry may produce multiple schedule instances (e.g., monthly activity scheduled for each week). |
| PRV-SCH-003 | A schedule may exist without a plan entry (ad-hoc preventive activity). |
| PRV-SCH-004 | The schedule becomes IN_PROGRESS when a technician starts the associated report. |
| PRV-SCH-005 | Preventive activities are single-shift only. No schedule spans more than one shift. |

### 5.5 PreventiveReport

#### 5.5.1 Description

The execution record of a preventive maintenance activity. Captures what was done, by whom, with what tools, and what results were observed.

#### 5.5.2 Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| id | UUID | Internal identifier |
| schedule | Reference to MaintenanceSchedule (optional) | The schedule this report fulfills |
| template | Reference to MaintenanceTemplate | The template that was followed (versioned reference) |
| subsystem | Reference to Subsystem | Scoping context |
| locationSnapshot | Reference to GeographicLocation | The geographic location at time of maintenance (immutable snapshot) |
| involvedAssets | List of Reference to Asset | The assets that received maintenance |
| actualDate | Date | When the activity was performed |
| shift | Enum: DAY, NIGHT | Which shift performed it |
| documentStatus | Enum: DRAFT, SUBMITTED | Document lifecycle status |
| submittedAt | Timestamp (optional) | When the report was finalized |
| stepResults | Collection of StepResult | Results for each step in the template |
| toolsUsed | Collection of ToolUsage | Tools logged during the activity |
| materialsConsumed | Text | Free-text description of spare parts or consumables used |
| observations | Text | Free-text observations from the technicians |
| conclusions | Text | Final conclusions |
| participants | Collection of Participant | Technicians who participated and signed |
| attachments | Collection of Attachment | Images or documents captured during maintenance |

#### 5.5.3 StepResult (Value Object)

| Attribute | Type | Description |
|-----------|------|-------------|
| stepIndex | Integer | Maps to MaintenanceStep.orderIndex |
| resultValue | String | The recorded result (e.g., "Pass", "Fail", or a measurement value) |
| observations | Text | Step-specific comments |
| hasPhoto | Boolean | Whether a photo was attached for this step |

#### 5.5.4 Domain Rules

| Rule | Description |
|------|-------------|
| PRV-RPT-001 | A PreventiveReport references the version of the MaintenanceTemplate that was current when the activity was performed. |
| PRV-RPT-002 | A PreventiveReport is linked to zero or one MaintenanceSchedule. If no schedule exists, this is an ad-hoc preventive execution. |
| PRV-RPT-003 | A PreventiveReport must involve at least one Asset. |
| PRV-RPT-004 | When documentStatus = DRAFT, the report may be modified. When documentStatus = SUBMITTED, the report is immutable. |
| PRV-RPT-005 | A PreventiveReport must have at least one Participant with a signature before submission. |
| PRV-RPT-006 | A PreventiveReport is completed within a single shift. |
| PRV-RPT-007 | The locationSnapshot is captured at execution time and does not change even if the asset's geographicLocation changes later. |
| PRV-RPT-008 | When submitted, if linked to a MaintenanceSchedule, the schedule status becomes COMPLETED. |

### 5.6 Preventive Maintenance Entity Lifecycle

`
MaintenanceTemplate (definition)
       │
       ▼
MaintenancePlanEntry (annual planning, PCON)
       │
       ▼
MaintenanceSchedule (weekly scheduling)
       │
       ▼
PreventiveReport (execution)
       │
       ├── DRAFT (in progress, not finalized)
       │
       └── SUBMITTED (finalized, immutable)
`

---

## 6. Core Domain: Corrective Maintenance

### 6.1 Overview

Corrective maintenance is reactive. The core entity is the **CorrectiveEvent** representing an incident or failure. Events have an explicit lifecycle. Within an event, multiple **CorrectiveReport** instances may be created (one per shift). Reports contain **CorrectiveTask** entries describing actions taken, and may trigger **AssetReplacement** operations.

### 6.2 CorrectiveEvent

#### 6.2.1 Description

A CorrectiveEvent represents an unplanned incident or failure that requires corrective maintenance. It serves as the aggregation root for all related reports and replacements across potentially multiple shifts.

#### 6.2.2 Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| id | UUID | System-generated internal event identifier |
| eventCode | String (system-generated) | Human-readable event code for cross-shift reference (e.g., "COR-2026-0001") |
| sapCode | String (optional) | External SAP notification reference code. Manually entered. Not required for event identity. |
| subsystem | Reference to Subsystem | The subsystem where the incident occurred |
| locationSnapshot | Reference to GeographicLocation | Where the incident occurred (immutable) |
| affectedAsset | Reference to Asset | The primary asset affected (may be a top-level or nested asset) |
| occurrenceTimestamp | Timestamp | When the incident was reported to have occurred |
| maintenanceStartTimestamp | Timestamp | When corrective maintenance actually started |
| description | Text | Description of the problem or incident |
| failureType | Text (free text initially) | Type of failure. Will be standardized in the future. |
| initiatingTechnician | Reference to User | The technician who created the event |
| lifecycleStatus | Enum: NOT_STARTED, IN_PROGRESS, RESOLVED, CLOSED | Operational lifecycle status |
| resolvedAt | Timestamp (optional) | When the event was marked resolved |
| resolvedBy | Reference to User (optional) | Who resolved the event |
| closedAt | Timestamp (optional) | When the event was formally closed |
| closedBy | Reference to User (optional) | Who closed the event |
| isReopened | Boolean | Whether this event was formally reopened after closure |
| reopenHistory | List of ReopenRecord (optional) | History of reopen events |

#### 6.2.3 ReopenRecord (Value Object)

| Attribute | Type | Description |
|-----------|------|-------------|
| reopenedAt | Timestamp | When it was reopened |
| reopenedBy | Reference to User | Who reopened it |
| reason | Text | Why it was reopened |

#### 6.2.4 Domain Rules

| Rule | Description |
|------|-------------|
| COR-EVT-001 | A CorrectiveEvent must have a unique internal eventCode. The sapCode is an external reference and may be duplicated across events (if SAP sends multiple notifications for the same incident). |
| COR-EVT-002 | A CorrectiveEvent belongs to exactly one Subsystem. |
| COR-EVT-003 | A CorrectiveEvent must reference at least the affectedAsset at the time of creation. If the exact component is unknown, the nearest known parent asset is used. |
| COR-EVT-004 | The lifecycleStatus follows the state machine defined in Section 13. |
| COR-EVT-005 | When lifecycleStatus = CLOSED, no new CorrectiveReports may be added without reopening the event. |
| COR-EVT-006 | The event maintains a chronological timeline of all linked reports, replacements, and status transitions. |

### 6.3 CorrectiveReport

#### 6.3.1 Description

A CorrectiveReport captures the maintenance work performed during a single shift within a corrective event. An event may have multiple reports if the incident spans multiple shifts.

#### 6.3.2 Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| id | UUID | Internal identifier |
| correctiveEvent | Reference to CorrectiveEvent | The event this report belongs to |
| shift | Enum: DAY, NIGHT | Which shift produced this report |
| startTimestamp | Timestamp | When this shift's maintenance work began |
| endTimestamp | Timestamp (optional) | When this shift's work ended |
| sapCode | String (optional) | SAP code (may be repeated from the event or refined) |
| subsystem | Reference to Subsystem | Scoping context |
| affectedAsset | Reference to Asset | The asset worked on (may be more specific than the event-level asset) |
| locationSnapshot | Reference to GeographicLocation | Immutable location at time of work |
| failureDescription | Text | Description of the failure as observed by this shift |
| faultType | Text | Type of fault (free text, future standardization) |
| documentStatus | Enum: DRAFT, SUBMITTED | Document lifecycle status |
| submittedAt | Timestamp (optional) | When the report was finalized |
| tasks | Collection of CorrectiveTask | Actions performed during this shift |
| toolsUsed | Collection of ToolUsage | Tools logged during this shift |
| comments | Text | Free-text shift notes and observations |
| participants | Collection of Participant | Technicians who participated and signed |
| attachments | Collection of Attachment | Images captured during this shift |

#### 6.3.3 Domain Rules

| Rule | Description |
|------|-------------|
| COR-RPT-001 | A CorrectiveReport belongs to exactly one CorrectiveEvent. |
| COR-RPT-002 | A CorrectiveEvent may have multiple CorrectiveReports (one per shift). |
| COR-RPT-003 | Reports are ordered within the event by startTimestamp. |
| COR-RPT-004 | When documentStatus = DRAFT, the report may be modified. When SUBMITTED, the report is immutable. |
| COR-RPT-005 | A report must have at least one Participant with a signature before submission. |
| COR-RPT-006 | The locationSnapshot is captured at execution time and does not change. |
| COR-RPT-007 | If the event is IN_PROGRESS, multiple reports may be in DRAFT simultaneously (e.g., if two notes are being prepared within the same shift). However, only one report per shift should be submitted for each shift period. |

### 6.4 CorrectiveTask

#### 6.4.1 Description

A single action or step performed during corrective maintenance. Tasks are semi-structured: they have a type (from a configurable list) and a free-text description. When the task type is "Component Replacement," the task triggers an AssetReplacement.

#### 6.4.2 Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| id | UUID | Internal identifier |
| correctiveReport | Reference to CorrectiveReport | The report this task belongs to |
| orderIndex | Integer | Sequence number within the report |
| taskType | Reference to TaskType | Classification of the task |
| description | Text | Free-text description of what was done |
| duration | Duration (optional) | How long this task took |
| isReplacement | Boolean | Derived from taskType (true if taskType.requiresReplacement) |
| assetReplacement | Reference to AssetReplacement (optional) | Set when isReplacement = true |

#### 6.4.3 Domain Rules

| Rule | Description |
|------|-------------|
| COR-TSK-001 | A CorrectiveTask belongs to exactly one CorrectiveReport. |
| COR-TSK-002 | Task types are configurable per Subsystem. See TaskType entity (Section 6.5). |
| COR-TSK-003 | When isReplacement = true, an AssetReplacement must be created and linked. |
| COR-TSK-004 | A task without replacement may still reference an asset (e.g., "Inspected LIMSYS001"). |

### 6.5 TaskType

#### 6.5.1 Description

A configurable classification of corrective maintenance actions. TaskTypes are scoped per Subsystem, allowing different classifications for different operational contexts.

#### 6.5.2 Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| id | UUID | Internal identifier |
| subsystem | Reference to Subsystem | The subsystem context |
| name | String | Task type name (e.g., "Component Replacement", "Inspection", "Cleaning", "Adjustment", "Measurement", "Software Action", "Other") |
| requiresReplacement | Boolean | Whether tasks of this type must trigger an AssetReplacement |
| description | Text | Description of when this task type should be used |
| isActive | Boolean | Whether this task type is currently available |

#### 6.5.3 Domain Rules

| Rule | Description |
|------|-------------|
| COR-TTP-001 | TaskType is scoped per Subsystem. Different Subsystems may have different task type catalogs. |
| COR-TTP-002 | The set of task types may evolve in the future toward a standardized corrective procedure library. |

---

## 7. Supporting Domain: Personnel

### 7.1 Overview

The Personnel domain manages user identities, roles, and participation tracking. All field operations require authenticated user accounts with traced signatures.

### 7.2 User

#### 7.2.1 Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| id | UUID | Internal identifier |
| username | String | Login name |
| passwordHash | String | Securely stored credential |
| fullName | String | Display name |
| role | Enum: TECHNICIAN, COORDINATOR, MAINTENANCE_MANAGER, PROJECT_MANAGER | System role |
| project | Reference to Project (optional) | Default project scope. Initially tied to one project. |
| isActive | Boolean | Whether the account is active |
| createdAt | Timestamp | Account creation timestamp |

### 7.3 Participant

#### 7.3.1 Description

A Participant records a technician's involvement in a specific maintenance report and captures their drawn signature.

#### 7.3.2 Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| id | UUID | Internal identifier |
| user | Reference to User | The participating technician |
| reportId | UUID | Polymorphic reference to PreventiveReport or CorrectiveReport |
| reportType | Enum: PREVENTIVE, CORRECTIVE | Discriminator for the report reference |
| signedAt | Timestamp | When the signature was captured |
| signature | Reference to Signature | The drawn signature data |

### 7.4 Signature

#### 7.4.1 Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| id | UUID | Internal identifier |
| user | Reference to User | The user who produced this signature |
| imageData | Binary or Reference | The drawn signature image (stored as image data or reference to storage) |
| capturedAt | Timestamp | When the signature was drawn |

#### 7.4.2 Domain Rules

| Rule | Description |
|------|-------------|
| PER-SIG-001 | A signature is always associated with the authenticated User who produced it. |
| PER-SIG-002 | A User cannot sign on behalf of another User. |
| PER-SIG-003 | Once a report is submitted, the signature is immutable as part of the report record. |
| PER-SIG-004 | Multiple Participants may sign the same report. Each signature is independent. |
| PER-SIG-005 | A report must have at least one Participant signature before submission. |

---

## 8. Supporting Domain: Inventory & Tools

### 8.1 Overview

This domain manages two separate inventory concepts:

- **Tools**: Maintenance equipment tracked by serial number, used in activities.
- **Warehouse Stock**: Spare components stored as inventory, best-effort view from an external warehouse system.

Tools are NOT part of the operational asset hierarchy. They are a flat inventory.

### 8.2 Tool

#### 8.2.1 Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| id | UUID | Internal identifier |
| serialNumber | String | Tool serial number (unique business identifier) |
| name | String | Tool name or description |
| partNumber | String (optional) | Manufacturer part number |
| toolType | String (optional) | Classification (e.g., "Multimeter", "Wrench", "Torque Tool") |
| availabilityStatus | Enum: AVAILABLE, IN_USE, LOST, UNDER_MAINTENANCE | Current availability |
| currentLocation | Text (optional) | Free-text current location |

#### 8.2.2 ToolUsage (Value Object)

| Attribute | Type | Description |
|-----------|------|-------------|
| tool | Reference to Tool | The tool used |
| reportId | UUID | Polymorphic reference to the report |
| reportType | Enum: PREVENTIVE, CORRECTIVE | Discriminator |
| usedAt | Timestamp | When the tool was used |

#### 8.2.3 Domain Rules

| Rule | Description |
|------|-------------|
| INV-TOOL-001 | Tools are not part of the recursive asset hierarchy. They exist in a separate inventory. |
| INV-TOOL-002 | Tools are tracked by serial number. |
| INV-TOOL-003 | Tool usage is recorded after the activity is complete. Check-in/check-out workflows are future scope. |
| INV-TOOL-004 | Tool availability may be updated based on usage records, but is not a real-time system. |

### 8.3 WarehouseStock

#### 8.3.1 Description

WarehouseStock represents the platform's view of spare components stored in a warehouse. This is a best-effort representation; the warehouse is managed by an external team.

#### 8.3.2 Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| asset | Reference to Asset | The component stored as spare (lifecycleStatus = IN_WAREHOUSE) |
| warehouseLocation | Reference to WarehouseLocation | Where in the warehouse it is stored |
| lastUpdated | Timestamp | When this record was last synchronized or modified |

#### 8.3.3 Domain Rules

| Rule | Description |
|------|-------------|
| INV-WHS-001 | A component in warehouse stock is an Asset with lifecycleStatus = IN_WAREHOUSE and no parentAsset. |
| INV-WHS-002 | WarehouseStock is a best-effort view. The platform is not authoritative for warehouse inventory. |
| INV-WHS-003 | When a component moves from warehouse to active hierarchy, a movement record is created, and the WarehouseStock entry is removed. |
| INV-WHS-004 | When a removed component arrives at warehouse, a WarehouseStock entry is created. |

### 8.4 WarehouseLocation

| Attribute | Type | Description |
|-----------|------|-------------|
| id | UUID | Internal identifier |
| name | String | Warehouse name (e.g., "SPV Warehouse") |

---

## 9. Cross-Cutting: Attachments

### 9.1 Attachment

#### 9.1.1 Description

Attachments are images or documents captured during maintenance activities and permanently associated with their parent report.

#### 9.1.2 Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| id | UUID | Internal identifier |
| fileReference | String | Reference to stored file (location in storage) |
| capturedAt | Timestamp | When the attachment was captured or uploaded |
| attachmentType | Enum: IMAGE, DOCUMENT | Type of attachment |
| description | Text (optional) | User-provided description |
| reportId | UUID | Polymorphic reference to PreventiveReport or CorrectiveReport |
| reportType | Enum: PREVENTIVE, CORRECTIVE | Discriminator |
| stepIndex | Integer (optional) | If the attachment is associated with a specific step in a preventive report |

#### 9.1.3 Domain Rules

| Rule | Description |
|------|-------------|
| ATT-001 | Attachments are permanently associated with the report they were uploaded to. |
| ATT-002 | Attachments are preserved as part of the historical record even after asset changes. |
| ATT-003 | When a report is submitted, all its attachments become immutable as part of the report. |

---

## 10. Entity Relationship Summary

### 10.1 Core Asset Management

`
AssetType (pure type descriptor)
    1
    │
    *
    ▼
Asset ── * ──── 1 ── Subsystem
  │  (subsystem)
  │
  │ (parent) 0..1   ───→ AssetAssignment (1..*)
  │     │                  (historical assignment records,
  │     └─── * (children)  append-only lineage)
  │                │
  │                └── position (current-state on Asset;
  │                              historical on AssetAssignment)
  │
  │ 1
  │ *
  │ ▼
  AssetReplacement ─── * ──── CorrectiveEvent (optional)
       │                      CorrectiveReport (optional)
       │
       ├── removedAsset ─── Asset
       ├── installedAsset ─── Asset
       ├── parentAsset ─── Asset
       └── (triggers) ─── AssetAssignment close + create

AssetCompositionRule ─── * ──── Subsystem
     │                         AssetType (parentAssetType)
     │                         AssetType (childAssetType)
     └── (contextual policy model, not owned by AssetType)

GeographicLocation ─── * ──── Asset (current location)
     │                       PreventiveReport (locationSnapshot)
     │                       CorrectiveReport (locationSnapshot)
     │                       CorrectiveEvent (locationSnapshot)
`

### 10.2 Preventive Maintenance

`
MaintenanceTemplate ─── * ──── Subsystem
     │                         AssetType (relatedAssetTypes)
     │
     │ 1
     │ *
     │ ▼
     MaintenanceStep (value object collection)
     ToolRequirement (value object collection)
     │
     │ 1
     │ *
     │ ▼
     MaintenancePlanEntry ─── * ──── Subsystem
     │ 1
     │ *
     │ ▼
     MaintenanceSchedule ─── * ──── User (assignedTechnicians)
     │
     │ 0..1
     │ ▼
     PreventiveReport ─── * ──── Participant
          │                    ToolUsage
          │                    Attachment
          │                    StepResult (value object)
          │                    Asset (involvedAssets)
`

### 10.3 Corrective Maintenance

`
CorrectiveEvent ─── * ──── Subsystem
     │                    GeographicLocation (locationSnapshot)
     │                    Asset (affectedAsset)
     │                    User (initiatingTechnician)
     │
     │ 1
     │ *
     │ ▼
     CorrectiveReport ─── * ──── Participant
          │                     ToolUsage
          │                     Attachment
          │                     Asset (affectedAsset)
          │
          │ 1
          │ *
          │ ▼
          CorrectiveTask ─── * ──── TaskType
               │
               │ 0..1 (when isReplacement)
               │ ▼
               AssetReplacement
`

### 10.4 Supporting

`
User ─── * ──── Participant ─── * ──── PreventiveReport / CorrectiveReport
     │                              Signature
     │
     └── * ──── MaintenanceSchedule (assignedTechnicians)

Tool ─── * ──── ToolUsage ─── * ──── PreventiveReport / CorrectiveReport

WarehouseLocation ─── * ──── Asset (IN_WAREHOUSE)
`

---

## 11. Aggregates & Ownership Boundaries

### 11.1 Aggregate Definitions

| Aggregate Root | Entities Inside | Value Objects | Notes |
|---------------|----------------|---------------|-------|
| **Asset** | Asset (single node only — children via references, NOT ownership) | GeographicLocation, Position | The Asset aggregate is exactly one node + immediate children references. Full subtree loading is prohibited. Children are separate aggregate roots. Composition rules are external. Recursive traversal is a query concern. |
| **AssetAssignment** | AssetAssignment | — | Append-only historical record. Populated by hierarchy mutation events. Never physically deleted. |
| **AssetType** | AssetType | — | Pure type descriptor. No composition rules. |
| **AssetCompositionRule** | AssetCompositionRule | — | Standalone aggregate. Looked up by (subsystem, parentType, childType). |
| **AssetReplacement** | AssetReplacement | — | References Asset (removed/installed) but does not own them. Requires cross-aggregate coordination via domain service. |
| **CorrectiveEvent** | CorrectiveEvent, ReopenRecord (VO) | — | Owns its lifecycle state. References reports by ID but does not own them. Cross-aggregate consistency via domain service. |
| **CorrectiveReport** | CorrectiveReport, CorrectiveTask | Participant, ToolUsage, Attachment | Owns its tasks, participants, tool usages, and attachments. References event. |
| **PreventiveReport** | PreventiveReport | StepResult, Participant, ToolUsage, Attachment | Owns its results, participants, tool usages, and attachments. |
| **MaintenanceTemplate** | MaintenanceTemplate | MaintenanceStep, ToolRequirement | Owns its step definitions. |
| **MaintenancePlanEntry** | MaintenancePlanEntry | — | Standalone planning record. |
| **MaintenanceSchedule** | MaintenanceSchedule | — | Standalone scheduling record. |
| **User** | User | — | Owns identity and credentials. |
| **Tool** | Tool | — | Standalone inventory item. |
| **GeographicLocation** | GeographicLocation | — | Standalone location catalog. |
| **WarehouseLocation** | WarehouseLocation | — | Standalone warehouse catalog. |

### 11.2 Ownership & Reference Rules

| Rule | Description |
|------|-------------|
| AGG-001 | An Aggregate Root must be loaded and saved as a whole within its boundary. |
| AGG-002 | References between aggregates use the root's UUID. Navigation across aggregates must go through domain services or repositories. |
| AGG-003 | **Asset** and **AssetReplacement** are separate aggregates. A replacement operation requires a domain service that coordinates transactionally across both. |
| AGG-004 | **CorrectiveEvent** and **CorrectiveReport** are separate aggregates. The event references reports by ID but does not own them. A domain service manages their coordination (event creation, report linking, status transitions). |
| AGG-005 | **AssetType** does not own **AssetCompositionRule**. Composition rules are resolved by lookup, not by traversal. |
| AGG-006 | **PreventiveReport** references but does not own its **MaintenanceTemplate**. The template version is captured at report creation time for immutable traceability. |

### 11.3 Domain Service Candidates

| Service | Responsibility |
|---------|---------------|
| **AssetCompositionService** | Resolves composition rules for a given (subsystem, parentAsset). Validates whether a proposed child type and position comply with rules. |
| **AssetReplacementService** | Coordinates the atomic replacement operation: creates AssetReplacement, updates live hierarchy, updates lifecycle statuses, links to corrective context. |
| **CorrectiveEventLifecycleService** | Manages state transitions (start, resolve, close, reopen). Enforces invariants. |
| **ReportSubmissionService** | Validates completeness of a report (signatures required, minimum data present), transitions document status to SUBMITTED, updates related entities (schedule status, event timeline). |
| **AssetSearchService** | Provides hierarchical navigation (drill-down by parent) and direct search (by serial number, part number, name, type). Used extensively during maintenance workflows. |

---

## 12. Domain Constraints & Invariants

### 12.1 Structural Invariants

| ID | Invariant | Scope | Enforcement |
|----|-----------|-------|-------------|
| INV-001 | An Asset must not be its own ancestor (no cycles in the hierarchy). | Asset Aggregate | Strict |
| INV-002 | An Asset has at most one direct parent. | Asset Aggregate | Strict |
| INV-003 | The combination (parentAsset, position) is unique among siblings. | Asset Aggregate | Strict |
| INV-004 | An Asset with lifecycleStatus = IN_WAREHOUSE must have parentAsset = null. | Asset Aggregate | Strict |
| INV-005 | An Asset with lifecycleStatus = ACTIVE must have a parentAsset, OR it is a top-level asset with a geographic location. | Asset Aggregate | Strict |
| INV-006 | Software version is only applicable when AssetType.supportsVersion = true. | Asset Aggregate | Strict |

### 12.2 Operational Invariants

| ID | Invariant | Scope | Enforcement |
|----|-----------|-------|-------------|
| INV-010 | A PreventiveReport must have at least one Participant signature before submission. | PreventiveReport | Strict |
| INV-011 | A CorrectiveReport must have at least one Participant signature before submission. | CorrectiveReport | Strict |
| INV-012 | A PreventiveReport involves exactly one shift. It cannot be linked to another shift's report. | PreventiveReport | Strict |
| INV-013 | A CorrectiveReport belongs to exactly one CorrectiveEvent. | CorrectiveReport | Strict |
| INV-014 | A CorrectiveEvent in CLOSED status cannot have new CorrectiveReports added. | CorrectiveEvent | Strict |
| INV-015 | A report with documentStatus = SUBMITTED is immutable. | Both report types | Strict |
| INV-016 | At most one active CorrectiveEvent can be IN_PROGRESS for the same (subsystem, affectedAsset) combination. | CorrectiveEvent | Advisory (prevented by "Start Maintenance" flow) |

### 12.3 Replacement Invariants

| ID | Invariant | Scope | Enforcement |
|----|-----------|-------|-------------|
| INV-020 | An AssetReplacement must record both removedAsset and installedAsset. | AssetReplacement | Strict |
| INV-021 | The removedAsset and installedAsset must be different instances. | AssetReplacement | Strict |
| INV-022 | A replacement must update the live hierarchy atomically with the creation of the replacement record. | AssetReplacement + Asset | Strict (coordinated by domain service) |
| INV-023 | The parentAsset in a replacement must be the common parent of both removed and installed assets. | AssetReplacement | Strict |

### 12.4 AssetAssignment Invariants

| ID | Invariant | Scope | Enforcement |
|----|-----------|-------|-------------|
| INV-040 | Only one active AssetAssignment may exist for an Asset at a time (deactivatedAt IS NULL). | AssetAssignment | Strict |
| INV-041 | Assignment intervals for the same Asset must not overlap. | AssetAssignment | Strict |
| INV-042 | A replacement operation must close the previous assignment and create the new assignment atomically. | AssetAssignment + AssetReplacement | Strict (coordinated by domain service) |
| INV-043 | Historical AssetAssignment records must never be physically deleted. | AssetAssignment | Strict |
| INV-044 | When Asset.parentAsset or position changes, a corresponding AssetAssignment must be created or deactivated. | Asset + AssetAssignment | Strict |

### 12.5 Composition Invariants (Future)

| ID | Invariant | Scope | Enforcement |
|----|-----------|-------|-------------|
| INV-030 | A child Asset's position must be valid according to the applicable AssetCompositionRule (if defined). | Asset + CompositionRule | Advisory (future strict enforcement) |
| INV-031 | The quantity of children of a given type must not exceed the maxQuantity defined by the composition rule. | Asset + CompositionRule | Advisory (future strict enforcement) |

---

## 13. Lifecycle State Machines

### 13.1 CorrectiveEvent Lifecycle

`
                    ┌──────────────────────────────────────────────┐
                    │                                              │
                    ▼                                              │
            ┌──────────────┐                                       │
    ┌──────►│ NOT_STARTED  │                                       │
    │       └──────┬───────┘                                       │
    │              │                                               │
    │              │ startMaintenance()                            │
    │              ▼                                               │
    │       ┌──────────────┐                                       │
    │       │ IN_PROGRESS  │◄──────────────────────────────────────┘
    │       └──────┬───────┘                                       
    │              │                                               
    │              ├──────────────────┐                            
    │              │ resolve()        │ (report may be in DRAFT   
    │              ▼                  │  but operational work is  
    │       ┌──────────────┐          │  complete for this shift)
    │       │  RESOLVED    │          │                            
    │       └──────┬───────┘          │                            
    │              │                  │                            
    │              │ close()          └── (stays IN_PROGRESS if    
    │              ▼                       more shifts needed)    
    │       ┌──────────────┐                                       
    │       │   CLOSED     │                                       
    │       └──────┬───────┘                                       
    │              │                                               
    │              │ reopen()                                      
    │              │ (authorized workflow)                         
    │              ▼                                               
    │       ┌──────────────┐                                       
    └───────│ IN_PROGRESS  │                                       
            └──────────────┘                                       

Transitions:
  NOT_STARTED  → IN_PROGRESS  : startMaintenance()
  IN_PROGRESS  → RESOLVED     : resolve()       (all reports submitted, no further work)
  IN_PROGRESS  → (stays)      : addReport()     (another shift starts, still IN_PROGRESS)
  RESOLVED     → CLOSED       : close()         (formal closure, locked)
  CLOSED       → IN_PROGRESS  : reopen()        (authorized, reason required)
`

### 13.2 Report Document Status (Both Preventive and Corrective)

`
       ┌─────────┐
       │  DRAFT  │
       └────┬────┘
            │
            │ submit() (requires: at least one signature, required fields filled)
            ▼
       ┌───────────┐
       │ SUBMITTED │  (IMMUTABLE)
       └───────────┘

DRAFT     → the report is being created, saved, or edited. May be saved multiple times.
SUBMITTED → the report is finalized, signed, and locked. No further modifications.
             Corrections require a linked addendum or new report.
`

### 13.3 Asset Lifecycle Status

`
     ┌──────────────┐
     │ NOT_TRACKED  │ (ad-hoc asset created during corrective maintenance,
     └──────┬───────┘  before being formally assigned to a location)
            │
            │ assignToParent() / registerInWarehouse()
            ▼
     ┌──────────────┐
     │   ACTIVE     │◄──────────────┐
     └──────┬───────┘               │
            │                       │
            │ removeFromParent()    │
            ▼                       │
     ┌──────────────┐               │
     │   REMOVED    │───────────────┘
     └──────┬───────┘  reinstall()
            │
            ├──────────────────┐
            │                  │
            ▼                  ▼
     ┌──────────────┐  ┌──────────────┐
     │ IN_WAREHOUSE │  │   SCRAPPED   │
     └──────────────┘  └──────────────┘
`

---

## 14. Architectural Principles

### 14.1 Operational Simplicity First

The system prioritizes:

- **Field operability** — maintenance technicians work in tunnels, stations, and technical rooms with shared iPad devices. The domain model must support quick data entry, minimal typing, and reliable capture.
- **Auditability** — every maintenance action, asset change, and report submission must be traceable to an authenticated user and timestamp.
- **Transactional consistency** — critical operations (replacements, report submissions, hierarchy changes) must maintain strong consistency within the v1 modular monolith.
- **Traceability** — historical records are append-only and immutable once finalized.

over:

- Distributed scalability,
- Eventual consistency for core workflows,
- Premature optimization of infrastructure concerns.

### 14.2 Modular Monolith Strategy

The intended architecture evolution path is:

```
Modular monolith
  → Internal domain events
  → Extracted read models (when justified by query complexity)
  → Optional asynchronous integrations (SAP, warehouse, analytics)
  → Selective service extraction only if operationally justified
```

The domain model must not assume microservices from the start. Bounded contexts are logical boundaries within the same deployable unit.

### 14.3 Asset Hierarchy Philosophy

The recursive Asset model represents **operational install relationships**, not physical engineering decomposition.

This distinction is important because:

- Some real-world subcomponents are intentionally not modeled as Assets.
- Hierarchy depth is operationally driven (how deep do technicians actually maintain?).
- Replacement granularity depends on maintenance practices, not engineering blueprints.
- The model must remain flexible enough to include or exclude components as operational needs evolve.

### 14.4 Historical Traceability Principle

The platform must preserve the following as first-class architectural concerns:

- Historical hierarchy state (via AssetAssignment)
- Maintenance lineage (reports linked to assets over time)
- Replacement lineage (via AssetReplacement chain + AssetAssignment)
- Immutable submitted reports (documentStatus = SUBMITTED)
- Signature traceability (user-bound, never proxy-signable)
- Lifecycle transitions (CorrectiveEvent state machine, Asset lifecycle)

### 14.5 Replacement Semantics

AssetReplacement is a **business event**, not merely a hierarchy mutation. It exists independently because it captures:

- Operational intent — why was this replacement necessary?
- Technician action — who performed it and under which corrective context?
- Maintenance context — which report, event, or shift does it belong to?
- Lifecycle transition — the removed asset changes state, the installed asset changes state.
- Historical traceability — the replacement is recorded permanently, enabling lineage queries.

---

## 15. Bounded Contexts (Modular Monolith)

### 15.1 Context Map

The platform is organized into the following logical bounded contexts within a **modular monolith** deployment. These are architectural boundaries, not microservice boundaries.

```
┌─────────────────────────────────────────────────────────────────┐
│                     IDENTITY & ACCESS                            │
│  Entities: User, Participant, Signature                         │
│  Owns: who can act, authentication, signatures                  │
│  Depends on: nothing (shared kernel with all contexts)          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────┐  ┌──────────────────────────────┐  │
│  │  ASSET MANAGEMENT        │  │  MAINTENANCE EXECUTION      │  │
│  │                          │  │                              │  │
│  │  Asset                   │  │  CorrectiveEvent            │  │
│  │  AssetType               │◄─┤  CorrectiveReport           │  │
│  │  AssetAssignment         │  │  CorrectiveTask             │  │
│  │  AssetCompositionRule    │  │  TaskType                   │  │
│  │  AssetReplacement        │  │  PreventiveReport           │  │
│  │  GeographicLocation      │  │                              │  │
│  │                          │  │  Owns: maintenance          │  │
│  │  Owns: asset tree,       │  │  operations and reports     │  │
│  │  hierarchy rules,        │  │                              │  │
│  │  replacements, history   │  │  Depends on: Asset          │  │
│  │                          │  │  Management (asset refs,    │  │
│  │  Depends on: nothing     │  │  replacement creation)      │  │
│  └──────────────────────────┘  └──────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────┐  ┌──────────────────────────────┐  │
│  │  PLANNING & SCHEDULING    │  │  INVENTORY                  │  │
│  │  (future-separable)       │  │                              │  │
│  │                          │  │  Tool, ToolUsage             │  │
│  │  MaintenanceTemplate     │  │  WarehouseStock              │  │
│  │  MaintenancePlanEntry    │  │  WarehouseLocation           │  │
│  │  MaintenanceSchedule     │  │                              │  │
│  │                          │  │  Owns: tools,                │  │
│  │  Owns: definitions,      │  │  warehouse (best-effort)    │  │
│  │  plans, schedules        │  │                              │  │
│  │                          │  │  Depends on: Asset (for      │  │
│  │  Depends on: Asset       │  │  warehouse stock refs)       │  │
│  │  Management (asset       │  └──────────────────────────────┘  │
│  │  type refs)              │                                    │
│  └──────────────────────────┘                                    │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  REPORTING (read-model oriented, non-authoritative)        │  │
│  │  Consumes events from all contexts to build projections    │  │
│  │  Owns: aggregated views, dashboards, analytics (future)    │  │
│  └────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 15.2 Integration Notes for v1

| Integration | Mechanism | Notes |
|-------------|-----------|-------|
| Asset Management ↔ Maintenance Execution | Direct in-process calls via domain services | AssetReplacement is a shared concept; replacement service lives in Asset Management context |
| Asset Management ↔ Inventory | Asset reference + WarehouseStock lookup | Inventory reads Asset lifecycle status |
| All contexts → Identity & Access | Shared User reference | User is a shared kernel concept |
| Planning & Scheduling ↔ Maintenance Execution | MaintenanceSchedule → PreventiveReport link | Schedule is created in Planning, consumed in Execution |
| All contexts → Reporting | Future domain events | Read models built asynchronously from event streams |

### 15.3 Read-Model Guidance (CQRS-lite)

For v1, the architecture remains a **transactional relational model** with **normalized write models**. However, optimized query projections are acceptable where justified:

- The Asset closure table or equivalent hierarchy projection is a **read-optimized view** that can be derived from the adjacency model.
- AssetAssignment enables temporal queries without overloading the current-state Asset model.
- A denormalized timeline view for CorrectiveEvent (aggregating reports, replacements, status changes) is a candidate **read projection**.

Do NOT introduce:

- Separate read/write application layers,
- Event sourcing terminology,
- Separate databases for read models.

Design the domain event publishing mechanism so that future read models can be built by subscribing to events without modifying the write model.

---

## 16. Domain Events

### 16.1 Approach

Domain events are modeled as **in-process events** for internal consistency workflows and decoupling within the modular monolith. They are NOT distributed integration events. The current architecture assumes synchronous transactional consistency inside a modular monolith. Domain events are modeled primarily for decoupling and future extensibility, not for immediate distributed deployment.

Integration events (for future SAP, warehouse sync, analytics, etc.) are architecturally distinct and are not defined at this stage.

### 16.2 Event Catalog

| Event | Payload | Trigger | Consumer(s) |
|-------|---------|---------|-------------|
| `AssetCreated` | assetId, assetTypeId, subsystemId, registrationMethod, timestamp | Asset registration | AssetAssignment (create initial record), Search index |
| `AssetHierarchyModified` | assetId, oldParentId, newParentId, positionChanged, timestamp | Replacement, reinstall, direct assignment | AssetAssignment (close previous, create new), Closure table updater |
| `AssetLifecycleStatusChanged` | assetId, oldStatus, newStatus, reason, timestamp | Replacement, scrapping, warehouse transfer | WarehouseStock, Dashboard projections |
| `AssetReplacementCompleted` | replacementId, removedAssetId, installedAssetId, parentAssetId, timestamp, correctiveEventId (optional) | Replacement execution | AssetAssignment (close + create), Hierarchy updater, Report linker, Analytics |
| `CorrectiveEventCreated` | eventId, eventCode, sapCode, subsystemId, affectedAssetId, timestamp | First technician starts maintenance | Timeline service, Dashboard |
| `CorrectiveEventStatusChanged` | eventId, oldStatus, newStatus, userId, reason, timestamp | Start, resolve, close, reopen | Dashboard, Analytics, Notification |
| `CorrectiveReportSubmitted` | reportId, eventId, shift, timestamp, participantIds, assetReplacementIds | Report finalization | CorrectiveEvent lifecycle check (auto-resolve if all reports submitted), Asset history, Next-shift notification |
| `PreventiveReportSubmitted` | reportId, templateId, scheduleId, timestamp, participantIds | Report finalization | MaintenanceSchedule status update, Asset history, Dashboard |
| `ToolUsed` | toolId, reportId, reportType, timestamp | Report submission | Tool availability update, Future usage analytics |
| `MaintenanceScheduleCompleted` | scheduleId, reportId, templateId, actualDate, timestamp | PreventiveReport submission | Planning system, Dashboard |

### 16.3 Event Handling Principles

| Principle | Description |
|-----------|-------------|
| EVT-001 | Domain events are raised **inside** the aggregate or domain service that performs the operation. |
| EVT-002 | Event handlers run **in-process** within the same transaction for v1 critical paths (replacement, report submission). |
| EVT-003 | Non-critical event handlers (index updates, analytics projections) may be queued for **immediate eventual consistency** within the same process. |
| EVT-004 | The event catalog is **not exhaustive** for v1 implementation. Only events with explicit consumers need to be implemented initially. |
| EVT-005 | Integration events (external systems) are explicitly **out of scope** for the current domain model. They will be defined when integration requirements emerge. |

---

## 17. Future Extensibility Considerations

### 17.1 Extension Points

| Extension Point | Current State | Future Capability |
|----------------|---------------|-------------------|
| **AssetCompositionRule enforcement** | Advisory (rules exist but not enforced) | Strict validation on hierarchy modifications; enforcement strategy configurable per subsystem or project |
| **Standalone AssetReplacement UI** | Only within corrective reports | Dedicated interface for bulk hierarchy updates, warehouse transfers, unmapped-equipment imports |
| **Tool lifecycle management** | Usage logging only | Checkout/return, calibration tracking, maintenance scheduling for tools |
| **Inventory synchronization** | Best-effort manual view | API integration with external warehouse system |
| **Corrective failure classification** | Free text failureType | Standardized taxonomy with criticality levels, trend analysis |
| **PCON Plan Module** | External Excel, manual import | Native annual planning with calendar view and automated reminders |
| **Weekly Scheduling Module** | External Excel | Native drag-and-drop scheduling with shift assignment |
| **Shift Management Module** | External Excel | Native shift calendar with coordinator assignment |
| **Manager Dashboards** | None | Aggregated KPIs, MTBF/MTTR analytics, productivity reports |
| **SAP Integration** | Manual sapCode entry | API-based notification creation, status updates, bidirectional sync |
| **Multi-language support** | Not required | Spanish, English, and future locale support |
| **Approval workflows** | Not required | Coordinator/Manager approval gates before report closure; verifier/witness signature types |
| **Offline mode** | Not supported | Full offline capability with conflict resolution on sync |

### 17.2 Model Extensibility Guidelines

| Guideline | Description |
|-----------|-------------|
| EXT-001 | AssetType must remain a pure type descriptor. Do not add composition or context-specific rules. |
| EXT-002 | AssetCompositionRule is the correct extension point for hierarchy constraints. Keep it scoped per Subsystem. |
| EXT-003 | TaskType is the correct extension point for corrective maintenance action classification. Keep it scoped per Subsystem. |
| EXT-004 | New modules should extend the platform by adding new aggregate roots that reference the core Asset hierarchy, not by modifying existing ones. |
| EXT-005 | The four-layer separation (Template → PlanEntry → Schedule → Report) is designed to support future scheduling, planning, and reporting modules independently. |
| EXT-006 | AssetReplacement is designed for both corrective-context and standalone use. Future bulk operations should reuse the same entity. |

### 17.3 Role Model Evolution

The current User.role is an enum (TECHNICIAN, COORDINATOR, MAINTENANCE_MANAGER, PROJECT_MANAGER). These are coarse-grained operational roles for the initial implementation. Future role evolution may introduce:

| Concept | Description | When |
|---------|-------------|------|
| Permission | Granular action-level permissions (e.g., "can_edit_asset", "can_close_event") | When approval workflows emerge |
| RoleAssignment | Dynamic role-permission mapping instead of enum | When role complexity grows |
| ProjectScopedRole | Roles that vary per project | When multi-project access is needed |
| UserProjectAssignment | Explicit user-to-project association (replacing direct FK) | When cross-project support is required |
| SignatureRole | Verifier, witness, approver signature types on reports | When approval workflows emerge |

These concepts are intentionally **not modeled yet** to avoid premature complexity.

### 17.4 Polymorphic References Note

The current model uses polymorphic (reportId + reportType) references for Participant, ToolUsage, and Attachment. This approach is intentional because:

- PreventiveReport and CorrectiveReport are separate aggregates with different semantics and lifecycles.
- Attachment, signature, and tool usage semantics are shared, but the reports themselves are not interchangeable.

Future evolution may introduce:

- An abstract Report identity or shared interface.
- Explicit linking tables instead of polymorphic references.
- A common Report supertype with subtype-specific extensions.

The current polymorphic approach is acceptable for v1.

---

## 18. Open Questions

| # | Question | Resolution | Impact | Status |
|---|----------|------------|--------|--------|
| DM-OQ-001 | Should AssetCompositionRule enforcement be strict or advisory? | Advisory initially to avoid blocking field operations during early hierarchy digitization. The domain model supports future strict enforcement without structural changes. Enforcement strategy should become configurable per subsystem or project. | Validation behavior; policy configuration model | Resolved |
| DM-OQ-002 | Are there explicit ISO 55000 or railway regulatory constraints? | Not yet incorporated. The model intentionally preserves traceability, immutability of submitted reports, lifecycle history, and auditability to facilitate future compliance alignment if required. | No immediate model changes | Resolved |
| DM-OQ-003 | Should the User aggregate support multiple Projects? | Current model scopes User to one Project. Future multi-project support should be introduced through an explicit UserProjectAssignment model rather than expanding the current field into conditional logic. | UserProjectAssignment entity in future | Resolved |
| DM-OQ-004 | Should sign-off workflows support verifier/witness roles? | Not for v1. The current Participant model captures only execution signatures. Future workflow extensions may introduce role-based signature types without changing the underlying report model. | Future signature role types | Resolved |
| DM-OQ-005 | Should software assets support license tracking? | No. Software assets focus on operational version traceability only. License management, support contracts, and end-of-life tracking are future extensions. | No model expansion needed | Resolved |
| DM-OQ-006 | Does the Asset model support partial replacements? | Yes — the recursive Asset model already supports replacements at arbitrary hierarchy levels, provided the replaced component is represented as an Asset. Future requirements may introduce lighter-weight subcomponent tracking for non-independent parts. | No model changes needed | Resolved |

---

*End of Domain Model Document (Draft v0.2)*
