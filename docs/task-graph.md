# Task Graph

**Version:** 0.1  
**Status:** Draft  
**Last Updated:** 2026-06-16

---

## 1. Current Phase

The project is still in planning/discovery. No implementation should start until the formal specs are approved.

---

## 2. Recommended Planning Tasks

| ID | Task | Depends On | Status |
|----|------|------------|--------|
| PLAN-001 | Align requirements with clarified decisions | User clarifications | Done |
| PLAN-002 | Create initial domain model | PLAN-001 | Done |
| PLAN-003 | Create initial operational flows | PLAN-001 | Done |
| PLAN-004 | Create initial UI specification | PLAN-001 | Done |
| PLAN-005 | Review real preventive report PDF template | User provides template | Pending |
| PLAN-006 | Review real corrective report format | User provides/validates format | Pending |
| PLAN-007 | Define seed data needed for mock UI | PLAN-002, PLAN-003 | Pending |
| PLAN-008 | Define local demo architecture | PLAN-002 | Pending |
| PLAN-009 | Define initial API contracts | PLAN-002, PLAN-003 | Pending |
| PLAN-010 | Reconcile legacy detailed sections in domain-model.md and architecture.md with clarified decisions | PLAN-001 | Pending |
| PLAN-011 | Approve first implementation slice | PLAN-007, PLAN-008, PLAN-009, PLAN-010 | Pending |

---

## 3. Recommended First Implementation Slices

Implementation should start only after approval.

1. SwiftUI mock/design prototype for iPad flows.
2. Backend local skeleton with FastAPI and PostgreSQL.
3. Asset model and seed hierarchy.
4. Preventive activity/report version flow.
5. Corrective event/report dynamic block flow.
6. PDF generation with simple raw-data templates.
7. Share Sheet integration in iPad app.

---

## 4. Blockers Before Coding

- Confirm real corrective report block structure.
- Provide or define first PDF template expectations.
- Decide initial seed data scope for Metro Lima Linea 2 / Senalizacion.
- Clean legacy detailed sections that still mention the old six-section / SECTIONAL_DRAFT model.
- Approve whether implementation starts with design mockups or backend skeleton.
