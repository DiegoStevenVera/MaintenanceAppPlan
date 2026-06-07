# Workflow

# Phase 1 — Vision Definition

## Goal

Define the business vision, operational context, and high-level objectives of the platform.

## Deliverables

* `vision.md`

---

# Phase 2 — Requirements Definition

## Goal

Define the functional capabilities and business requirements of the system.

## Rules

* Focus on functional requirements.
* Avoid technical implementation details.
* Avoid database design.
* Avoid API definitions.
* Focus on what the system must do.

## Deliverables

* `requirements.md`

---

# Phase 3 — Discovery

## Goal

Understand the business domain completely before technical design.

## Rules

* No implementation.
* No database schema generation.
* No API implementation.
* No frontend implementation.
* Ask iterative questions.
* Detect ambiguities.
* Identify business entities.
* Identify workflows.
* Identify constraints.
* Identify edge cases.
* Use `/docs/raw-context.md` as auxiliary domain context.
* Extract implicit business rules from examples.
* Detect inconsistencies between raw context and formal specifications.
* Convert exploratory operational knowledge into structured specifications progressively.


## Deliverables

* Improved `vision.md`
* Improved `requirements.md`
* Initial `domain-model.md`
* Open questions list

---

# Phase 4 — Domain Modeling

## Goal

Create the conceptual domain model.

## Rules

* Focus on entities and relationships.
* Focus on business concepts.
* Avoid premature optimization.
* Avoid framework-specific decisions.

## Deliverables

* `domain-model.md`
* ER diagrams
* Relationship mappings
* Ubiquitous language glossary

---

# Phase 5 — User Flows

## Goal

Define operational workflows and UX flows.

## Deliverables

* `flows.md`
* User journeys
* Operational sequences
* Error flows

---

# Phase 6 — Architecture

## Goal

Define technical architecture.

## Deliverables

* `architecture.md`
* ADRs
* Service boundaries
* Infrastructure design

---

# Phase 7 — API Contracts

## Goal

Define contracts before implementation.

## Deliverables

* `api-contracts.yaml`
* Event contracts
* Validation rules

---

# Phase 8 — Planning

## Goal

Generate implementation roadmap.

## Deliverables

* `task-graph.md`
* Epics
* Tasks
* Dependencies

---

# Phase 9 — Implementation

## Goal

Implement approved tasks incrementally.

## Rules

* One task at a time.
* Generate tests.
* Update documentation.
* Respect contracts.

---

# Phase 10 — Validation

## Goal

Validate consistency and correctness.

## Deliverables

* Test reports
* Architecture review
* Documentation review
