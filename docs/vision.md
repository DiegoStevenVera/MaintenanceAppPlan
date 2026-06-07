# Project Vision

# Overview

This project aims to build an enterprise maintenance management platform focused initially on railway maintenance operations.

The first target operational environment is:

* Metro Lima Linea 2

However, the platform must be designed to support:

* additional railway projects,
* additional operational systems,
* additional maintenance domains,
* future maintenance modules.

The system must be scalable, modular, extensible, and capable of managing highly complex hierarchical equipment structures.

---

# Business Context

The maintenance operation involves multiple systems, subsystems, locations, equipment hierarchies, maintenance procedures, and maintenance reports.

The platform is intended to replace or centralize operational maintenance processes that are currently distributed across manual workflows, documents, spreadsheets, and operational knowledge.

The system must support:

* traceability,
* historical maintenance records,
* asset relationships,
* maintenance procedures,
* operational reporting,
* equipment replacement tracking,
* attachment management,
* personnel participation tracking.

The application must also support future growth across:

* different railway projects,
* different maintenance disciplines,
* additional operational modules.

---

# Initial Scope

The initial implementation includes two modules:

1. Preventive Maintenance Reports
2. Corrective Maintenance Reports

These modules currently belong to the Signaling maintenance domain but the platform must remain generic enough to support future systems and modules.

---

# Operational Structure

The platform must support organizational and operational segmentation through concepts such as:

* Site
* Project
* Stage
* System
* Subsystem

Examples include:

* Metro Lima Linea 2
* Metro Lima Linea 1
* Madrid Linea 1

Examples of systems include:

* Signaling
* Infrastructure
* Civil
* Networking

Examples of subsystems include:

* ATS
* CBTC
* IXL

The selected project/system/subsystem context influences:

* visible modules,
* maintenance definitions,
* workflows,
* assets,
* operational data.

---

# Asset Management Vision

One of the core goals of the platform is to support highly complex equipment hierarchies.

The system must support:

* large equipment,
* nested equipment,
* components,
* software,
* tools,
* replaceable parts,
* logical and physical relationships.

Examples include:

* trains,
* cabinets,
* servers,
* cards,
* fans,
* software systems,
* field equipment.

Assets may contain other assets recursively with variable hierarchy depth.

The system must preserve:

* serial number traceability,
* part number relationships,
* asset replacement history,
* parent-child relationships,
* location history,
* maintenance history.

The platform must support both:

* fixed-location assets,
* mobile assets.

---

# Preventive Maintenance Vision

Preventive maintenance operations are planned and periodic activities executed against one or multiple assets.

Each preventive maintenance activity may include:

* procedures,
* predefined steps,
* predefined tests,
* predefined result options,
* required tools,
* required personnel,
* manuals,
* attachments,
* comments,
* conclusions,
* historical execution records.

Maintenance reports must support:

* versioning,
* historical traceability,
* scheduled future maintenance visibility,
* image attachments,
* worker signatures,
* execution metadata.

The system must support different maintenance structures depending on:

* subsystem,
* asset type,
* location,
* operational context.

---

# Corrective Maintenance Vision

Corrective maintenance operations are reactive events triggered by unexpected incidents or failures.

Corrective reports must support:

* incident tracking,
* operational timelines,
* maintenance actions,
* asset replacements,
* equipment swaps,
* historical event records,
* worker participation,
* attachments,
* operational comments.

Corrective maintenance must also support dynamic workflows where procedures may vary depending on the event.

Asset replacements performed during corrective maintenance must update the operational asset hierarchy and preserve historical traceability.

---

# Main Goals

The platform aims to:

* Centralize maintenance operations
* Improve operational traceability
* Digitize maintenance reporting
* Standardize maintenance workflows
* Preserve historical maintenance records
* Improve asset visibility
* Improve maintenance planning
* Enable scalable future modules
* Support complex hierarchical asset relationships
* Support future analytics and reporting capabilities

---

# Technical Vision

The system is expected to support:

* iOS applications,
* backend APIs,
* cloud infrastructure,
* scalable services,
* attachment storage,
* future integrations,
* future AI-assisted operational features.

The architecture must prioritize:

* modularity,
* extensibility,
* maintainability,
* historical traceability,
* auditability,
* scalability.

---

# Initial Constraints

Current expected stack:

* Backend: FastAPI
* Frontend: SwiftUI
* Infrastructure: AWS
* Database: PostgreSQL
* Infrastructure as Code: Terraform

---

# Future Vision

The platform is expected to evolve into a generalized enterprise maintenance platform capable of supporting:

* multiple railway operators,
* multiple projects,
* multiple maintenance disciplines,
* multiple operational systems,
* future modules beyond maintenance reporting.

Potential future modules may include:

* inventory management,
* maintenance scheduling,
* asset lifecycle management,
* predictive maintenance,
* analytics,
* dashboards,
* AI-assisted diagnostics,
* operational monitoring.

---

# Open Questions

The following areas still require further discovery and clarification:

* Offline synchronization strategy
* User roles and permissions
* Scheduling workflows
* Notification workflows
* Approval workflows
* Integration requirements
* Reporting requirements
* Audit requirements
* Asset lifecycle rules
* Inventory integration
* Authentication strategy
* Multi-project isolation strategy
