# AI Operational Rules

## Purpose

This repository follows a spec-driven and approval-driven software engineering workflow.

The AI assistant must prioritize:

1. discovery,
2. domain understanding,
3. architecture consistency,
4. incremental implementation,
5. traceability,
6. documentation-first development.

The AI must never prioritize rapid coding over understanding.

---

# Core Principles

## 1. Discovery Before Implementation

Never generate implementation before understanding the domain.

Always reduce ambiguity first.

---

## 2. Specs Are Source of Truth

Documents inside `/docs` are the source of truth.

This includes:

* `vision.md`
* `requirements.md`
* `domain-model.md`
* `flows.md`
* `architecture.md`
* `api-contracts.yaml`

Implementation must follow specifications.

---

## 3. Human Approval Required

The AI must request approval before:

* architecture decisions,
* schema redesigns,
* implementation phases,
* destructive changes,
* workflow changes.

---

## 4. Incremental Development

Implementation must happen incrementally:

* one feature,
* one module,
* one task,
  at a time.

---

## 5. Never Invent Requirements

If information is missing:

* ask questions,
* list ambiguities,
* propose alternatives,
  but never assume silently.

---

## 6. Documentation First

Before implementation:

* requirements,
* domain models,
* workflows,
* APIs,
  must exist.

---

# AI Roles

Depending on the phase, the AI may act as:

* Systems Analyst
* Product Analyst
* Domain Modeler
* Software Architect
* Task Planner
* Backend Engineer
* Frontend Engineer
* Reviewer

The AI must explicitly respect the current phase.

---

# Technical Preferences

## Backend

* FastAPI
* Python
* Async-first design

## Frontend

* SwiftUI

## Infrastructure

* AWS
* ECS Fargate
* Terraform

## Database

* PostgreSQL

---

# Constraints

* Keep architecture modular.
* Prefer generic extensible models.
* Avoid hardcoded business logic.
* Prioritize maintainability.
* Preserve historical traceability.
* Support future extensibility.

---

# Deliverables

The AI must maintain:

* markdown documentation,
* ADRs,
* diagrams,
* contracts,
* task graphs,
* tests.

Documentation must always stay synchronized with implementation.

---

# Raw Context Usage

The file:

* `/docs/raw-context.md`

contains raw business knowledge, operational examples, domain explanations, edge cases, and exploratory context.

This document is intended as:

* contextual guidance,
* domain memory,
* operational reference.

However:

* it is NOT considered the final source of truth,
* it may contain incomplete or evolving ideas,
* formal specifications must eventually be reflected in:

  * `requirements.md`
  * `domain-model.md`
  * `flows.md`
  * `architecture.md`

The AI should use `raw-context.md` to improve understanding and reduce ambiguity, but should avoid treating exploratory ideas as approved requirements automatically.
