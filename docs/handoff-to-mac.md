# Handoff to Company Mac

**Version:** 0.1  
**Status:** Draft  
**Last Updated:** 2026-06-19

---

## 1. Purpose

This file lets the project continue on the company Mac without depending on the current Codex chat session.

The repository documentation is the source of truth. The chat history is useful, but it should not be required to restart work.

---

## 2. Current Project State

- The project is in planning and mock-first design phase.
- No production implementation has started.
- The first implementation slice should be an iPad-oriented SwiftUI mock/design prototype.
- The first mock implementation scope is defined in `docs/mock-slice-01.md`.
- App-visible labels, seed data, statuses, role labels, and report content must be in Spanish.
- Project documentation, code, code comments, schema names, and technical identifiers should be in English.
- Initial runtime target is local development/demo, likely iPad connected to a Mac-hosted backend later.

---

## 3. Documents to Read First

Read in this order:

1. `ai/init.md`
2. `ai/workflow.md`
3. `docs/raw-context.md`
4. `docs/vision.md`
5. `docs/requirements.md`
6. `docs/domain-model.md`
7. `docs/sql-domain-notes.md`
8. `docs/mock-first-flow.md`
9. `docs/mock-data.md`
10. `docs/ipad-wireframes.md`
11. `docs/ipad-navigation-map.md`
12. `docs/mock-slice-01.md`
13. `docs/product-spec.md`
14. `docs/architecture.md`
15. `docs/engineering-guide.md`
16. `docs/task-graph.md`

---

## 4. Suggested First Prompt on the Mac

```text
We are continuing the MaintenanceApp project from planning. Do not code yet unless I explicitly ask.

Read ai/init.md, ai/workflow.md, docs/raw-context.md, docs/vision.md, and then all docs/*.md.

Important decisions:
- The app starts mock-first for iPad.
- App-visible labels/data must be in Spanish.
- Documentation, code, schema names, and comments must be in English.
- Roles are Maintenance Engineer, Coordinator, Boss, Administrator in documentation; Spanish UI labels are Ingeniero de Mantenimiento, Coordinador, Jefe, Administrador.
- The Asset model is unified. Component is an Asset category.
- Business anchor assets are the primary reporting/metrics assets.
- Maintenance reports link to report scope assets with roles.
- Stage is rollout/planning scope, not a hard maintenance engineer visibility boundary.

After reading, summarize what you understand and propose the next mock-first SwiftUI design slice.
```

---

## 5. Recommended Mac Setup

Install or verify:

- Xcode from the Mac App Store.
- Xcode Command Line Tools: `xcode-select --install`.
- Codex desktop app or Codex CLI, depending on the workflow being used.
- Git.
- A Git remote for this repository, or another safe way to move the project folder to the Mac.
- Optional but recommended for backend work later: Docker Desktop, Python 3.12, `uv`, Node.js LTS.

---

## 6. Session Migration Reality

If Codex supports account-level thread sync in the installed app, opening the same account on the Mac may show the same session.

If the session does not appear, start a new Codex thread inside the repository and use the prompt in Section 4. The project should continue from the files, not from memory.

---

## 7. Pending Before Visual Mock Implementation

- Use the Hitachi logo palette already documented in `docs/product-spec.md` and `docs/ui-spec.md`.
- Build the first SwiftUI iPad mock skeleton from `docs/mock-slice-01.md`.
- Add the prepared SwiftUI source scaffold from `frontend/ios/MaintenanceAppMock/` to the Xcode project.
- Keep all app-visible labels and mock data in Spanish.
