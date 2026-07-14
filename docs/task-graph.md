# Task Graph

**Version:** 0.1  
**Status:** Draft  
**Last Updated:** 2026-06-21

---

## 1. Current Phase

The first iPad mock validation pass is complete. The project is entering v1 local-first implementation.

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
| PLAN-007 | Define seed data needed for mock UI | PLAN-002, PLAN-003 | Done |
| PLAN-008 | Define local demo architecture | PLAN-002 | Done |
| PLAN-009 | Define initial API contracts | PLAN-002, PLAN-003 | In Progress |
| PLAN-010 | Reconcile legacy detailed sections in domain-model.md and architecture.md with clarified decisions | PLAN-001 | Pending |
| PLAN-011 | Approve first implementation slice | PLAN-007, PLAN-008, PLAN-009, PLAN-010 | Done |
| PLAN-012 | Confirm official company logo colors / brand hex values | User provided logo references | Done |
| PLAN-013 | Review SQL domain notes for business anchor assets, report scope assets, and stage assignments | PLAN-002 | Done |
| PLAN-014 | Prepare handoff steps for moving work to company Mac | PLAN-001 | Done |
| PLAN-015 | Define first iPad mock implementation slice | PLAN-007, PLAN-012 | Done |
| PLAN-016 | Prepare SwiftUI source scaffold for first iPad mock slice | PLAN-015 | Done |

---

## 3. Recommended First Implementation Slices

Implementation should start only after approval.

1. SwiftUI mock/design prototype for iPad flows. Done.
2. Backend local skeleton with FastAPI and seed-backed API contracts. In Progress.
3. Asset model and seed hierarchy. In Progress.
4. Preventive activity/report version flow.
5. Corrective event/report dynamic block flow.
6. PDF generation with simple raw-data templates.
7. Share Sheet integration in iPad app.

---

## 4. Blockers Before Coding

- Confirm real corrective report block structure.
- Provide or define first PDF template expectations.
- Clean legacy detailed sections that still mention the old six-section / SECTIONAL_DRAFT model.
- Create the real Xcode project on the company Mac and add the SwiftUI scaffold files.
