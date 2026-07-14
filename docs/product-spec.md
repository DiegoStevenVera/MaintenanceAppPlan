# Product Specification & UX Blueprint

**Version:** 0.3
**Status:** Draft
**Based on:** Domain Model v0.3, Architecture v0.2, Engineering Guide v0.2
**Last Updated:** 2026-06-16

---

## 0. Clarified Product Decisions

- Initial device target: shared iPads. iPhone support is future and depends on corporate approval.
- Initial delivery strategy: design and flows with mocks first, then backend/API, then real SwiftUI integration.
- Infrastructure for v1: local demo/development environment, such as iPad connected to a Mac-hosted backend.
- PDF generation is required in v1, even with simple raw-data templates.
- Email/share in v1 uses the iOS Share Sheet with the generated PDF. Backend email is future.
- Roles: Technician, Coordinator, Boss, Administrator. "Supervisor" in older drafts means Boss only when it refers to read-only leadership; operational closure belongs to Coordinator.
- Maintenance lifecycle for preventive and corrective: Scheduled, In Progress, Completed, Closed.
- Reports can be edited while the maintenance activity is not Closed. Each finalized edit creates a version.
- Corrective reports use dynamic blocks based on the real report format. They are not fixed to six sections.
- Asset and Component are unified under Asset. Component is an asset category, not a separate primary entity for v1.

---

## 1. User Personas

### 1.1 Maintenance Technician

| Attribute | Detail |
|-----------|--------|
| **Role** | Field operator, frontline maintenance staff |
| **Count** | ~6â€“8 per site |
| **Technical proficiency** | Lowâ€“medium. Comfortable with smartphones, NOT comfortable with complex UIs, databases, or abstract concepts. Uses phone primarily for calls, WhatsApp, camera. |
| **Device** | Shared team iPad running iPadOS 26.5 as the primary validation device. Company-issued iPhone support targets iOS 26.5, pending physical phone testing. |
| **Primary goal** | Record what was done, find the right asset, attach photos, get signatures, finish shift. Minimize paperwork. |
| **Frustrations** | Slow forms, too many taps, unclear hierarchy, losing unsaved work, poor network in tunnels/workshops, being asked for data they don't have. |
| **Daily workflow** | 1. Receive event/task assignment (verbally or via app notification). 2. Navigate to asset in hierarchy. 3. Review existing state/history. 4. Perform maintenance. 5. Open report â†’ add tasks â†’ add photos â†’ add signatures â†’ submit. Repeat for next event. Shift end: verify all reports submitted. |
| **Permissions** | Read assets in assigned subsystems. Create/edit/submit corrective reports (own only). Read preventive schedules. Execute assigned preventive tasks. Submit reports for own work. |
| **Mobility constraints** | Frequently in low-connectivity areas (train tunnels, remote yards). Needs offline tolerance for report drafting. Photos are critical. |
| **Offline tolerance** | Must be able to draft reports, capture photos, and capture signatures without network. Submission requires connectivity. |

### 1.2 Boss

| Attribute | Detail |
|-----------|--------|
| **Role** | Read-only operational leader, formerly called Supervisor in older drafts |
| **Count** | ~2â€“3 per site |
| **Technical proficiency** | Medium. Uses Excel, email, generic maintenance systems. Comfortable with basic data entry and reporting. |
| **Device** | Shared iPad initially; future iPhone access depends on corporate approval. |
| **Primary goal** | Review maintenance metrics, inspect specific maintenance records, and understand operational status without editing data. |
| **Frustrations** | Incomplete reports, missing signatures, technicians skipping fields, not knowing what happened during the shift. |
| **Daily workflow** | 1. Review dashboard metrics. 2. Inspect open or closed maintenance activities if needed. 3. Review reports, PDFs, and asset history in read-only mode. |
| **Permissions** | Read all reports, assets, timelines, summaries, and dashboards. No operational create/edit/close permissions. |
| **Mobility constraints** | Mostly workshop/office based, but walks the floor. Connectivity generally good. |
| **Offline tolerance** | Low â€” primarily online review work. |

### 1.3 Warehouse / Inventory Operator

| Attribute | Detail |
|-----------|--------|
| **Role** | Spare parts and tool management |
| **Count** | ~1â€“2 per site |
| **Technical proficiency** | Medium. Uses inventory systems, barcode scanners, Excel. |
| **Device** | Company-issued iPhone or dedicated scanner + iPhone. |
| **Primary goal** | Track tool check-out/check-in, manage spare part stock, process replacements reported by technicians. |
| **Frustrations** | Discrepancies between reported replacements and actual stock, technicians not reporting parts used, unclear replacement history. |
| **Daily workflow** | 1. Review replacement requests from overnight reports. 2. Issue parts from warehouse. 3. Update stock levels. 4. Process returned parts (RMA, scrap, restock). 5. Reconcile physical inventory with system. |
| **Permissions** | Read tools/stock. Create tool instances. Update warehouse stock. Link parts to replacement records. |
| **Mobility constraints** | Within warehouse/yard. WiFi coverage typically good. |
| **Offline tolerance** | Low â€” stock operations benefit from real-time accuracy. |

### 1.4 Coordinator

| Attribute | Detail |
|-----------|--------|
| **Role** | Maintenance planner, documentation owner, schedule coordinator, and activity closer/reopener |
| **Count** | ~1â€“2 per site |
| **Technical proficiency** | Mediumâ€“high. Uses planning software, ERP systems, Excel (often advanced). |
| **Device** | Office desktop/laptop primarily. Uses iPad for walkarounds. |
| **Primary goal** | Plan preventive maintenance schedules. Import/manage PCON plans. Manage asset hierarchy. Manage users and permissions. Ensure regulatory compliance. |
| **Frustrations** | Manual PCON import processes, rigid hierarchy that doesn't match reality, difficult reporting for audits. |
| **Daily workflow** | 1. Review upcoming PM schedules. 2. Adjust plans based on operational needs. 3. Import/update PCON Excel files. 4. Manage asset hierarchy changes (new assets, decommission, moves). 5. Generate compliance reports. 6. Manage user accounts and roles. |
| **Permissions** | Technician capabilities plus close/reopen maintenance activities. Future: create/edit schedules, import PCON, manage documentation workflows. |
| **Mobility constraints** | Mostly office-based. Connectivity good. |
| **Offline tolerance** | Very low â€” planning is online-intensive. |

### 1.5 Administrator

| Attribute | Detail |
|-----------|--------|
| **Role** | System administrator |
| **Primary goal** | Manage configuration, catalogs, users, roles, and platform-level settings. |
| **Permissions** | All capabilities from Technician, Coordinator, and Boss, plus administrative configuration. |

---

## 2. MVP Scope Definition

### 2.1 MVP (v1.0)

The smallest production-valuable system that replaces the current paper-based process and provides immediate value.

| Workflow | Included in MVP | Rationale |
|----------|----------------|-----------|
| User authentication (email/password) | Yes | Gate for all other workflows |
| Asset hierarchy browsing | Yes | Core navigation â€” finding the right asset is step 1 |
| Asset search (serial, part number, name) | Yes | Fast asset location without hierarchy drilling |
| Asset detail view | Yes | See position, history, specs |
| Create corrective event | Yes | Replace paper event logging |
| Start/resolve/close corrective event | Yes | Full lifecycle for corrective events |
| Create corrective report (draft, dynamic blocks) | Yes | Replace the real corrective report format; component replacement fields appear only when that activity type is selected |
| Add tasks to report (StandardActivity + ReplacementTask) | Yes | Document what was done, including component replacements |
| Stop Here indicator | Yes | Filters/prints the report only up to the indicated point so blank later fields do not appear in the PDF |
| Mark individual report sections as complete | Yes | Visual progress tracking per section |
| Upload photo attachments (per section) | Yes | Photo is the most critical field evidence |
| Capture signature (PencilKit) | Yes | Replace wet signatures on paper |
| Finalize corrective report version | Yes | Generates/stores a report version while the activity remains editable until closed |
| View corrective event timeline | Yes | See what happened during the event |
| View maintenance history per asset | Yes | See past events for an asset |
| Record asset replacement | Yes | Replace paper replacement records |
| Move asset (reassign parent) | Yes | Warehouse/removal/installation tracking |
| Basic preventive schedule view | Yes | Technicians need to see assigned PMs |
| Create preventive report (draft) | Yes | Replace paper PM checklists |
| Submit preventive report | Yes | Finalize PM documentation |
| User roles (Technician/Coordinator/Boss/Administrator) | Yes | Basic access control |

### 2.2 V1.1 (Post-MVP)

| Workflow | Rationale |
|----------|-----------|
| Preventive schedule management (create/edit schedules) | Coordinators can manage PM calendar in-app |
| Template creation | Define standard PM task templates |
| PCON Excel import | Automate plan import |
| Warehouse stock management | Basic inventory tracking for spare parts |
| Tool check-out/check-in | Track tool usage per event |
| Coordinator report review and reopen | Quality control loop |
| Report editing (non-draft) with audit trail | Fix errors in submitted reports |
| Dashboard (open events, pending tasks) | At-a-glance operational view |
| Push notifications | Alert technicians of new assignments |
| Offline draft persistence | Cache drafts locally when network drops |
| Attachment thumbnail generation | Faster gallery browsing |
| Search history and recent assets | Time-saving for repeat visits |

### 2.3 Future Platform Capabilities (Post-v1.1)

| Capability | Rationale |
|------------|-----------|
| Full offline mode with sync | Required for tunnels/remote areas without any connectivity |
| Advanced PDF templates | Improve the simple v1 PDF templates and align them with official formats |
| PCON compliance analytics | Audit-readiness dashboards |
| Geofencing for asset location | Verify technician is at correct location |
| Barcode/QR code scanning | Fast asset identification |
| SAP/ERP integration | Bidirectional data sync |
| Web frontend (React) | Office users without iOS devices |
| Multi-site support | Multiple railway depots |
| Role-based custom permissions (RBAC) | Fine-grained access control |
| Predictive maintenance analytics | Failure prediction from historical data |
| Integration with IoT sensor data | Real-time equipment monitoring |

### 2.4 Operational Assumptions (MVP)

- Technicians initially use shared iPads. iPhone support is future and depends on corporate security approval.
- Network connectivity is generally available at shift start/end; brief dead zones exist.
- Photos are taken with the device camera; no external camera integration.
- Signatures are captured on-device (finger or Apple Pencil).
- The asset hierarchy is pre-loaded by the administrator before technician use.
- Corrective maintenance allows one report per shift per corrective event.
- Stop Here is an indicator for report/PDF filtering, not a hard section-based state machine.
- PCON plans are currently managed outside the system; MVP reads plans but does not create them.
- Components (serialized inventory) are a separate concern from Assets (hierarchical equipment). Components live in slots; Assets are the parent equipment that contains those slots.
- Corrective reports follow the real corrective format using dynamic blocks, especially in the activities section.

### 2.5 High-Risk Workflows (MVP)

| Risk | Workflow | Mitigation |
|------|----------|------------|
| Data loss | Report drafting | Auto-save draft every 30 seconds. Confirm before discard. |
| Network failure | Report submission | Queue submission. Show pending status. Retry on connectivity. |
| Wrong asset selection | Hierarchy navigation | Breadcrumb always visible. Search by serial # is primary path. |
| Signature forgery | Signature capture | Capture timestamp + device metadata. Audit trail links signer. |
| Concurrent edits | Report submission | Optimistic locking (version column). Show conflict UI. |

---

## 3. User Stories

### US-AUTH-01: User Login

| Field | Value |
|-------|-------|
| **ID** | US-AUTH-01 |
| **Title** | User logs into the application |
| **Actor** | Technician, Coordinator, Boss, Administrator |
| **Preconditions** | User account exists. User has email and password. |
| **Main flow** | 1. User opens app. 2. App displays login screen. 3. User enters email and password. 4. User taps "Sign In". 5. System validates credentials. 6. System returns JWT access + refresh tokens. 7. App navigates to main tab view. |
| **Alternate flows** | **Invalid credentials:** Show inline error "Invalid email or password". Allow retry. **Network error:** Show "No network connection. Please try again." alert. **Expired session (on app launch):** Redirect to login silently. |
| **Acceptance criteria** | Valid credentials â†’ navigates to home. Invalid credentials â†’ error message, stays on login. Network error â†’ user-friendly alert. Token stored securely in Keychain. |
| **Priority** | P0 |

### US-AUTH-02: Token Refresh

| Field | Value |
|-------|-------|
| **ID** | US-AUTH-02 |
| **Title** | System silently refreshes expired access token |
| **Actor** | All authenticated users |
| **Preconditions** | User has valid refresh token stored. Access token expired. |
| **Main flow** | 1. App makes API request. 2. Server returns 401. 3. Auth interceptor catches 401. 4. App calls `/auth/refresh` with refresh token. 5. Server returns new access token. 6. Original request retried with new token. |
| **Alternate flows** | **Refresh token expired:** Clear stored tokens. Navigate to login screen. **Refresh token invalid:** Same as expired. |
| **Acceptance criteria** | Expired access token â†’ silent refresh â†’ original request succeeds. Expired refresh token â†’ redirect to login. No data loss. |
| **Priority** | P0 |

### US-ASSET-01: Browse Asset Hierarchy

| Field | Value |
|-------|-------|
| **ID** | US-ASSET-01 |
| **Title** | User browses asset hierarchy by drill-down |
| **Actor** | Technician, Coordinator, Boss, Administrator |
| **Preconditions** | User is authenticated. Asset hierarchy exists. |
| **Main flow** | 1. User taps "Assets" tab. 2. App displays top-level containers (Trains, Workshops, Warehouses). 3. User taps a container (e.g., a Train). 4. App navigates to child level (Cars). 5. User taps a Car â†’ navigates to subsystems (HVAC, Doors, Brakes). 6. User taps a Subsystem â†’ Components (Cabinet, Rack) â†’ Line Replaceable Units. 7. Breadcrumb visible at all times. 8. User can tap breadcrumb to jump back to any ancestor level. |
| **Alternate flows** | **Empty level:** Show empty state "No assets at this level". **Deep hierarchy (>5 levels):** Keep navigation smooth with lazy loading per level. |
| **Acceptance criteria** | Each level loads children asynchronously. Breadcrumb updates with each navigation. Tapping breadcrumb navigates to that level. Back gesture works (swipe). |
| **Priority** | P0 |

### US-ASSET-02: Search Assets

| Field | Value |
|-------|-------|
| **ID** | US-ASSET-02 |
| **Title** | User searches for an asset by serial number, part number, or name |
| **Actor** | Technician, Coordinator, Boss, Administrator |
| **Preconditions** | User is authenticated. Assets exist in the system. |
| **Main flow** | 1. User taps search bar on Assets tab. 2. Keyboard appears. 3. User types partial serial/name (minimum 3 characters). 4. System debounces 300ms then queries `/assets?q=...`. 5. Results appear in a list below the search bar. 6. Each result shows: name, serial number, breadcrumb path (ancestors), asset type icon. 7. User taps a result â†’ navigates to asset detail. |
| **Alternate flows** | **No results:** Show "No assets found matching 'query'" with suggestion to try serial number. **Network error:** Show cached results if available, with "Offline results" badge. |
| **Acceptance criteria** | Search triggers after 3 chars + 300ms debounce. Results show breadcrumb. Tapping result navigates to detail. Empty state for no results. |
| **Priority** | P0 |

### US-ASSET-03: View Asset Detail

| Field | Value |
|-------|-------|
| **ID** | US-ASSET-03 |
| **Title** | User views detailed information about an asset |
| **Actor** | Technician, Coordinator, Boss, Administrator |
| **Preconditions** | User navigated to asset via hierarchy or search. |
| **Main flow** | 1. App displays asset detail screen. 2. Header shows: asset name, serial number, asset type icon, status badge. 3. Breadcrumb shown below header. 4. Tabs or sections: Info, Children, History. 5. Info: serial, part number, manufacturer, installation date, position, location. 6. Children: list of direct children with drill-down. 7. History: timeline of events, reports, replacements, movements. |
| **Alternate flows** | **Asset decommissioned:** Show decommissioned status badge in red. **No children:** Hide children section or show "No sub-assemblies". **No history:** Show "No maintenance history for this asset". |
| **Acceptance criteria** | All asset fields displayed. Breadcrumb navigable. History shows chronologically. Children expandable. |
| **Priority** | P0 |

### US-ASSET-04: View Asset History

| Field | Value |
|-------|-------|
| **ID** | US-ASSET-04 |
| **Title** | User views maintenance and movement history of an asset |
| **Actor** | Technician, Coordinator, Boss, Administrator |
| **Preconditions** | User is viewing asset detail. Asset has past events or movements. |
| **Main flow** | 1. User taps "History" section/tab. 2. App shows chronological timeline. 3. Each entry shows: date, event type icon, title, summary. 4. Types: Corrective Event, Preventive Report, Replacement, Move/Reinstall. 5. User taps an entry â†’ navigates to that report/event detail. |
| **Alternate flows** | **No history:** Empty state "No recorded history for this asset". |
| **Acceptance criteria** | History shows in reverse chronological order. Each type has distinct icon/color. Tapping opens detail. Loading state while fetching. |
| **Priority** | P1 |

### US-COR-01: Create Corrective Event

| Field | Value |
|-------|-------|
| **ID** | US-COR-01 |
| **Title** | Technician or Coordinator creates a corrective maintenance event |
| **Actor** | Technician, Coordinator |
| **Preconditions** | User is authenticated. Affected asset exists or can be entered for later reconciliation. |
| **Main flow** | 1. User taps "Corrective" tab. 2. Taps "+" button. 3. Selects affected asset. 4. Selects subsystem. 5. Sets severity. 6. Adds description. 7. Optionally adds initial photo. 8. Taps "Create Event". 9. System creates event in SCHEDULED/OPEN state. |
| **Alternate flows** | **Asset not found:** Allow manual reference for later reconciliation. **Cancel:** Discard draft with confirmation. |
| **Acceptance criteria** | Event is created. Technician/Coordinator can start it. Boss can view it read-only. |
| **Priority** | P0 |

### US-COR-02: View Corrective Events

| Field | Value |
|-------|-------|
| **ID** | US-COR-02 |
| **Title** | User views corrective events |
| **Actor** | Technician, Coordinator, Boss, Administrator |
| **Preconditions** | User is authenticated. Events exist. |
| **Main flow** | 1. User taps "Corrective" tab. 2. App displays events by status. 3. Technician sees operational events. 4. Coordinator sees events for review/closure. 5. Boss sees read-only events and metrics. 6. User taps event to open detail. |
| **Acceptance criteria** | List loads with filters by status, asset, severity, date, and user scope. |
| **Priority** | P0 |

### US-COR-03: View Corrective Event Detail & Timeline

| Field | Value |
|-------|-------|
| **ID** | US-COR-03 |
| **Title** | User views corrective event with timeline and report versions |
| **Actor** | Technician, Coordinator, Boss, Administrator |
| **Preconditions** | User selected an event. |
| **Main flow** | 1. App displays event header, status, severity, asset, subsystem, description. 2. Timeline shows Created, Started, Report Versions, Completed, Closed/Reopened. 3. Report versions are tappable. 4. Actions depend on role and status. |
| **Acceptance criteria** | Timeline shows status transitions, report versions, replacements, and closure/reopen records. Boss sees no edit actions. |
| **Priority** | P0 |

### US-COR-04: Start Corrective Maintenance

| Field | Value |
|-------|-------|
| **ID** | US-COR-04 |
| **Title** | Technician starts working on a corrective event |
| **Actor** | Technician, Coordinator |
| **Preconditions** | Event is SCHEDULED/OPEN. |
| **Main flow** | 1. User opens event detail. 2. Taps "Start Maintenance". 3. System transitions event to IN_PROGRESS. 4. Timestamp is recorded. |
| **Acceptance criteria** | Event status becomes IN_PROGRESS and is visible to all users. |
| **Priority** | P0 |

### US-COR-05: Create/Edit Corrective Report Version

| Field | Value |
|-------|-------|
| **ID** | US-COR-05 |
| **Title** | Technician creates or edits a corrective shift report version |
| **Actor** | Technician, Coordinator |
| **Preconditions** | Event is IN_PROGRESS or COMPLETED, not CLOSED. |
| **Main flow** | 1. User taps "Create/Edit Report". 2. System opens a dynamic corrective report based on the real format. 3. User fills event, failure, impact, activities, tests, attachments, conclusions, and comments. 4. User adds activities performed. 5. If activity type is Component Replacement, replacement fields appear inside that activity block. 6. User selects removed asset, installed asset, source, destination, and reason. 7. User captures participant signatures on the shared iPad. 8. User optionally sets Stop Here marker. 9. User finalizes the current report version. 10. System saves the snapshot, generates PDF, and updates timeline. |
| **Alternate flows** | **Stop Here:** Marker controls PDF visibility. **Network error:** Save draft locally and queue upload. **Closed event:** Editing blocked until Coordinator reopens. |
| **Acceptance criteria** | Report uses dynamic blocks. Replacement fields appear only for replacement activities. Finalizing creates a new version and PDF. Previous versions remain visible. |
| **Priority** | P0 |

### US-COR-06: Complete and Close Corrective Event

| Field | Value |
|-------|-------|
| **ID** | US-COR-06 |
| **Title** | Technician completes and Coordinator closes a corrective event |
| **Actor** | Technician (complete), Coordinator (close/reopen) |
| **Preconditions** | Event is IN_PROGRESS. At least one report version exists. |
| **Main flow** | 1. Technician taps "Complete/Resolve". 2. Adds notes if needed. 3. System transitions event to COMPLETED. 4. Coordinator reviews event. 5. Coordinator taps "Close Event". 6. System transitions event to CLOSED. |
| **Alternate flows** | **Correction needed:** Coordinator reopens with notes and event returns to IN_PROGRESS. |
| **Acceptance criteria** | Completed events remain editable; closed events are read-only until reopened by Coordinator/Admin. |
| **Priority** | P0 |

### US-COR-07: Mark Stop Here on Corrective Report

| Field | Value |
|-------|-------|
| **ID** | US-COR-07 |
| **Title** | Technician marks Stop Here for report/PDF filtering |
| **Actor** | Technician |
| **Preconditions** | Report is editable and parent event is not CLOSED. |
| **Main flow** | 1. User taps "Stop Here". 2. Chooses a block/point in the report. 3. Adds optional handover note. 4. System stores marker. 5. Generated PDF hides later blank fields after marker. |
| **Acceptance criteria** | Stop Here is a marker, not a locked partial-submission state. Later shifts can continue and correct previous fields while event is editable. |

### US-COR-08: Continue Corrective Documentation Next Shift

| Field | Value |
|-------|-------|
| **ID** | US-COR-08 |
| **Title** | Technician continues corrective documentation in the next shift |
| **Actor** | Technician |
| **Preconditions** | Corrective event is not CLOSED. Previous shift may contain Stop Here marker. |
| **Main flow** | 1. Technician opens event detail. 2. Reviews previous report versions and marker. 3. Creates/edits the report for current shift. 4. Continues documentation and may correct previous fields if needed. 5. Finalizes a new report version. |
| **Acceptance criteria** | Next shift can continue after Stop Here without unlocking disabled sections, because Stop Here is only a marker. |
### US-COMP-01: Register New Component

| Field | Value |
|-------|-------|
| **ID** | US-COMP-01 |
| **Title** | Warehouse operator registers a new component in inventory |
| **Actor** | Warehouse / Inventory Operator |
| **Preconditions** | ComponentType exists in catalog. |
| **Main flow** | 1. Operator navigates to Components tab. 2. Taps "Register New". 3. Selects component type from catalog (filtered by subsystem). 4. Enters serial number (scanned via camera or typed). 5. Optionally enters: manufacturing date, batch number, initial warehouse location, notes. 6. Taps "Register". 7. System creates Component with status REGISTERED â†’ EN_STOCK. 8. Component appears in inventory list. |
| **Alternate flows** | **Duplicate serial number:** Show error "Serial number already registered for this component type". **Unknown component type:** Operator can request new type creation (admin). |
| **Acceptance criteria** | Component registered with unique serial. Status transitions to EN_STOCK. Movement history created with initial location. |

### US-COMP-02: Install Component in Slot

| Field | Value |
|-------|-------|
| **ID** | US-COMP-02 |
| **Title** | Technician installs a component in an equipment slot (via ReplacementTask) |
| **Actor** | Technician |
| **Preconditions** | Corrective event is IN_PROGRESS. ReplacementTask is being performed. Component is EN_STOCK. Slot exists and is empty. |
| **Main flow** | 1. During corrective report creation, technician adds a ReplacementTask. 2. Technician taps "Select Component". 3. System shows available EN_STOCK components matching slot requirements (filtered by ComponentType). 4. Technician selects component. 5. System auto-assigns to current slot (based on task context). 6. Component status changes to INSTALLED. 7. Slot shows as occupied. 8. ComponentMovement recorded (INSTALL). |
| **Alternate flows** | **Component not in stock:** Show "No available components. Request warehouse." **Wrong component type for slot:** Validation error. **Slot occupied:** Show current occupant. Require removal first. |
| **Acceptance criteria** | Component transitions from EN_STOCK to INSTALLED. Slot becomes occupied. Movement history recorded. Asset replacement linked. |

### US-COMP-03: Remove Component from Slot

| Field | Value |
|-------|-------|
| **ID** | US-COMP-03 |
| **Title** | Technician removes a component from its slot (via ReplacementTask) |
| **Actor** | Technician |
| **Preconditions** | Corrective event is IN_PROGRESS. ReplacementTask is being performed. Component is INSTALLED in the slot. |
| **Main flow** | 1. During corrective report creation, technician selects "Remove Component". 2. System shows currently installed component in the slot. 3. Technician confirms removal. 4. Component status changes to REMOVED (or EN_REPARACIÃ“N if sent for repair). 5. Slot becomes empty. 6. ComponentMovement recorded (REMOVE). 7. Asset lifecycle updated (AssetReplacement record created). |
| **Alternate flows** | **Send to repair:** Select destination "Repair" â€” status becomes EN_REPARACIÃ“N. **Mark lost:** Select "Lost" â€” status becomes PERDIDO. |
| **Acceptance criteria** | Component transitions from INSTALLED to REMOVED/EN_REPARACIÃ“N/PERDIDO. Slot becomes empty. Movement history recorded. Asset replacement record created. |

### US-COMP-04: View Component Movement History

| Field | Value |
|-------|-------|
| **ID** | US-COMP-04 |
| **Title** | User views full movement history of a component |
| **Actor** | Technician, Coordinator, Boss, Administrator |
| **Preconditions** | Component exists. Component has at least one movement. |
| **Main flow** | 1. User navigates to component detail. 2. "Movement History" section shows reverse-chronological timeline. 3. Each entry shows: date, movement type (INSTALL, REMOVE, WAREHOUSE_TRANSFER, REPAIR, SCRAP), from/to location, related replacement task or corrective event. 4. User can tap an entry for more detail. |
| **Acceptance criteria** | All movements displayed chronologically. Each movement includes location, type, and related context. |

### US-PREV-01: View Preventive Schedule

| Field | Value |
|-------|-------|
| **ID** | US-PREV-01 |
| **Title** | Technician views assigned preventive maintenance schedule |
| **Actor** | Technician |
| **Preconditions** | Preventive schedule exists. Technician is assigned tasks. |
| **Main flow** | 1. Technician taps "Preventive" tab. 2. App displays list of scheduled activities. 3. Each row shows: title, due date, asset, priority, status badge. 4. List grouped by: Overdue (red), Today, This Week, This Month. 5. User taps an activity â†’ navigates to schedule detail with template steps. |
| **Alternate flows** | **No schedules:** Empty state "No preventive tasks scheduled". **Overdue tasks:** Shown at top with red badge. |
| **Acceptance criteria** | Schedule loads with grouping. Overdue tasks prioritized. Tapping navigates to detail. |
| **Priority** | P0 |

### US-PREV-02: Execute Preventive Report

| Field | Value |
|-------|-------|
| **ID** | US-PREV-02 |
| **Title** | Technician executes a preventive maintenance task and submits report |
| **Actor** | Technician |
| **Preconditions** | Preventive schedule exists. Technician has been assigned or is acting ad-hoc. |
| **Main flow** | 1. Technician opens schedule detail. 2. Views checklist of tasks/steps from template. 3. Performs each step. 4. Marks each step as completed or N/A. 5. Adds optional notes per step. 6. Captures photos. 7. Records replaced consumables. 8. Captures signatures from all participating workers. 10. Taps "Submit Report". 11. System validates and submits report. 12. Schedule status updated. |
| **Alternate flows** | **Skipped step (N/A):** Marked with N/A status, reason required. **Deferred task:** Option to defer to next cycle with notes. |
| **Acceptance criteria** | Template steps shown as checklist. Each step completable. Photos attachable per step. Signatures required. Submission locks the report. |
| **Priority** | P0 |

### US-ATTACH-01: Upload Photo Attachment

| Field | Value |
|-------|-------|
| **ID** | US-ATTACH-01 |
| **Title** | User takes or selects a photo and attaches it to a report |
| **Actor** | Technician |
| **Preconditions** | Report is in DRAFT state. |
| **Main flow** | 1. User taps "Add Photo" on report form. 2. Action sheet: "Take Photo" / "Choose from Library". 3. If "Take Photo": camera opens (AVCaptureSession). User captures photo. 4. If "Choose from Library": PhotosPicker opens. User selects photos (multi-select). 5. Selected photos appear as thumbnails in attachment grid. 6. User can tap a photo to view full screen. 7. User can swipe to delete a photo. 8. Photos uploaded to server when user saves/submits. |
| **Alternate flows** | **Camera not available:** Show only "Choose from Library" option. **Photo too large:** Auto-resize to 1920px max dimension. **Upload fails:** Retry with exponential backoff. Show failed badge on thumbnail. |
| **Acceptance criteria** | Camera and library integration work. Multi-select supported. Thumbnails display in grid. Full-screen preview available. Swipe to delete. Failed upload shows error badge. |
| **Priority** | P0 |

### US-SIG-01: Capture Signature

| Field | Value |
|-------|-------|
| **ID** | US-SIG-01 |
| **Title** | User captures their signature on the report using PencilKit |
| **Actor** | Technician, Coordinator, Boss, Administrator |
| **Preconditions** | Report is in DRAFT state. User is on the signature step. |
| **Main flow** | 1. User taps "Add Signature". 2. Full-screen PencilKit canvas opens. 3. "Sign here" guide line displayed. 4. User signs with finger or Apple Pencil. 5. User taps "Confirm". 6. Canvas rendered as PNG image. 7. Signature uploaded as attachment. 8. Participant record created linking user + report + signature. 9. Signature thumbnail shown in report. |
| **Alternate flows** | **Clear signature:** User taps "Clear" to reset canvas. **Re-sign:** User can delete existing signature and re-sign. |
| **Acceptance criteria** | PencilKit canvas opens full screen. Signature renders as clean PNG. Signature uploaded and linked. Thumbnail displays. Can clear and re-sign. |
| **Priority** | P0 |

### US-REPLACE-01: Record Asset Replacement

| Field | Value |
|-------|-------|
| **ID** | US-REPLACE-01 |
| **Title** | Technician records that a component was replaced during maintenance |
| **Actor** | Technician |
| **Preconditions** | Report is in DRAFT state. Both old and new assets exist in the system. |
| **Main flow** | 1. User taps "Record Replacement" on report form. 2. Selects old asset (removed/replaced component). 3. Selects new asset (installed component). 4. Selects replacement reason (failed, worn, upgrade). 5. Adds notes (optional). 6. Taps "Save". 7. Replacement record added to report. 8. Old asset's status updated to REMOVED. 9. New asset linked to old asset's position via replacement chain. |
| **Alternate flows** | **New asset from warehouse:** Select "From Warehouse" â†’ show warehouse stock list. **New asset not in system:** Free-text entry (post-MVP). **Wrong asset selected:** Allow delete and reselect before submission. |
| **Acceptance criteria** | Replacement record created. Old asset status = REMOVED. New asset inherits position. Replacement chain documented (old â†’ new). Visible in asset history. |
| **Priority** | P1 |

### US-ASSIGN-01: Assign Technician to Event

| Field | Value |
|-------|-------|
| **ID** | US-ASSIGN-01 |
| **Title** | Coordinator assigns one or more technicians to a corrective event |
| **Actor** | Coordinator |
| **Preconditions** | Event exists in OPEN status. Technicians exist in the system. |
| **Main flow** | 1. Coordinator opens event detail. 2. Taps "Assign Technicians". 3. Shows list of available technicians. 4. Coordinator selects one or more. 5. Taps "Confirm". 6. Technicians receive event in their corrective list. |
| **Alternate flows** | **Reassign:** Coordinator can remove and reassign technicians. |
| **Acceptance criteria** | Technician list loads. Multi-select works. Technicians see event immediately after assignment. |
| **Priority** | P1 |

### US-HIST-01: View Asset Maintenance History

| Field | Value |
|-------|-------|
| **ID** | US-HIST-01 |
| **Title** | User views complete maintenance history for an asset |
| **Actor** | Technician, Coordinator, Boss, Administrator |
| **Preconditions** | Asset exists. Previous events/reports exist. |
| **Main flow** | 1. User navigates to asset detail. 2. Taps "History" section. 3. App shows chronological list of all events, reports, replacements, movements. 4. Each entry tappable â†’ navigates to that entry's detail. 5. Filters available: "All / Corrective / Preventive / Replacements / Moves". |
| **Alternate flows** | **No history:** Empty state with CTA to "Create first event". |
| **Acceptance criteria** | History entries chronologically sorted. Filters work. Each entry navigates to detail. Loading state while fetching. |
| **Priority** | P1 |

---

## 4. User Flows

### 4.1 Login Flow

```
[App Launch]
    â”‚
    â”œâ”€â”€ [Has valid stored token?] â”€â”€Yesâ”€â”€â†’ [Navigate to Main Tab View]
    â”‚
    â””â”€â”€ No
         â”‚
         â–¼
    [Login Screen]
         â”‚
         â”œâ”€â”€ [Enter email + password]
         â”‚       â”‚
         â”‚       â–¼
         â”‚   [Tap "Sign In"]
         â”‚       â”‚
         â”‚       â–¼
         â”‚   [Validate locally] â”€â”€Invalidâ”€â”€â†’ [Show inline error "Enter valid email"]
         â”‚       â”‚
         â”‚       â–¼
         â”‚   [POST /api/v1/auth/login]
         â”‚       â”‚
         â”‚       â”œâ”€â”€ [200 OK] â”€â”€â†’ [Store tokens in Keychain]
         â”‚       â”‚                     â”‚
         â”‚       â”‚                     â–¼
         â”‚       â”‚                [Navigate to Main Tab View]
         â”‚       â”‚
         â”‚       â”œâ”€â”€ [401] â”€â”€â†’ [Show "Invalid email or password"]
         â”‚       â”‚
         â”‚       â””â”€â”€ [Network error] â”€â”€â†’ [Show "No network connection" alert]
         â”‚                                     â”‚
         â”‚                                     â””â”€â”€ [Retry?] â”€â”€â†’ [Return to login]
         â”‚
         â””â”€â”€ [Version check] (optional background check)
                 â”‚
                 â””â”€â”€ [Update available] â”€â”€â†’ [Show "Update required" modal]
```

**Validation points:**
- Email format (client-side regex)
- Password non-empty
- Network availability
- Token expiry on app launch

**Failure states:**
- Network: "Unable to connect. Check your internet connection."
- Invalid credentials: "Invalid email or password. Please try again."
- Account locked: "Account temporarily locked. Contact your administrator."

### 4.2 Asset Search Flow

```
[Assets Tab]
    â”‚
    â”œâ”€â”€ [Hierarchy browse] (see 4.3)
    â”‚
    â””â”€â”€ [Tap Search Bar]
            â”‚
            â–¼
    [Search becomes active]
            â”‚
            â”œâ”€â”€ [Type 3+ characters]
            â”‚       â”‚
            â”‚       â–¼
            â”‚   [300ms debounce]
            â”‚       â”‚
            â”‚       â–¼
            â”‚   [GET /api/v1/assets?q={query}]
            â”‚       â”‚
            â”‚       â”œâ”€â”€ [Results found] â”€â”€â†’ [Show results list]
            â”‚       â”‚                           â”‚
            â”‚       â”‚                           â”œâ”€â”€ [Tap result] â”€â”€â†’ [Asset Detail]
            â”‚       â”‚                           â”‚
            â”‚       â”‚                           â””â”€â”€ [Scroll results]
            â”‚       â”‚
            â”‚       â””â”€â”€ [No results] â”€â”€â†’ [Show empty state "No assets found"]
            â”‚
            â”œâ”€â”€ [Type <3 chars] â”€â”€â†’ [Show recent searches or suggestions]
            â”‚
            â””â”€â”€ [Tap Cancel / Clear] â”€â”€â†’ [Dismiss search]
```

**Optimistic UI:**
- Show spinner on first keystroke batch, then show cached results from previous searches while re-fetching.

**Navigation transitions:**
- Search bar animates to active state (expands, shows cancel button).
- Results slide in from bottom.
- Asset detail pushes onto navigation stack (right-to-left slide).

### 4.3 Hierarchy Drill-Down Flow

```
[Assets Tab â†’ Top-Level]
    â”‚
    â”œâ”€â”€ [Pull-to-refresh] â”€â”€â†’ [Fetch children for current level]
    â”‚
    â”œâ”€â”€ [Tap disclosure chevron or row]
    â”‚       â”‚
    â”‚       â–¼
    â”‚   [GET /api/v1/assets/{id}/children?page=1&per_page=50]
    â”‚       â”‚
    â”‚       â”œâ”€â”€ [Has children] â”€â”€â†’ [Push next level onto navigation stack]
    â”‚       â”‚                           â”‚
    â”‚       â”‚                           â”œâ”€â”€ [Tap child] â”€â”€â†’ Continue drill-down
    â”‚       â”‚                           â”‚   ...
    â”‚       â”‚                           â””â”€â”€ [Tap leaf asset (LRU)] â”€â”€â†’ Asset Detail
    â”‚       â”‚
    â”‚       â””â”€â”€ [No children / leaf] â”€â”€â†’ [Navigate to Asset Detail]
    â”‚
    â””â”€â”€ [Long press row] â”€â”€â†’ [Context menu: View Detail, Copy Serial]
```

**Navigation transitions:**
- Drill-down uses `NavigationStack` with slide-in animation.
- Swipe-back gesture pops to previous level.
- Breadcrumb at top: tappable segments allow jumping to any ancestor level.
- `matchedGeometryEffect` on asset type icon for smooth cross-screen transition.

**Failure states:**
- Network error loading children: Show error toast "Failed to load. Pull to retry."
- Empty level (no children): Show "No sub-assemblies" with icon.

### 4.4 Corrective Event Reporting Flow

```
[Corrective Tab â†’ Event List]
    â”‚
    â”œâ”€â”€ [Tap event] â”€â”€â†’ [Event Detail]
    â”‚                       â”‚
    â”‚                       â”œâ”€â”€ [Status: OPEN]
    â”‚                       â”‚       â”‚
    â”‚                       â”‚       â”œâ”€â”€ [Tap "Start Maintenance"] â”€â”€â†’ [Status: IN_PROGRESS]
    â”‚                       â”‚       â”‚                                       â”‚
    â”‚                       â”‚       â”‚                                       â–¼
    â”‚                       â”‚       â”‚                                  [Button â†’ "Resolve"]
    â”‚                       â”‚       â”‚
    â”‚                       â”‚       â””â”€â”€ [Tap "Create Report"]
    â”‚                       â”‚               â”‚
    â”‚                       â”‚               â–¼
    â”‚                       â”‚          [Report Form (DRAFT)]
    â”‚                       â”‚               â”‚
    â”‚                       â”‚               â”œâ”€â”€ [Fill work description] â”€â”€â†’ Auto-save every 30s
    â”‚                       â”‚               â”œâ”€â”€ [Add tasks] â”€â”€â†’ Select task type, add notes
    â”‚                       â”‚               â”œâ”€â”€ [Add photos] â”€â”€â†’ Camera / Gallery â†’ Upload
    â”‚                       â”‚               â”œâ”€â”€ [Record replacements] â”€â”€â†’ Select old+new asset
    â”‚                       â”‚               â”œâ”€â”€ [Add participant signatures] â”€â”€â†’ PencilKit
    â”‚                       â”‚               â”œâ”€â”€ [Add own signature] â”€â”€â†’ PencilKit
    â”‚                       â”‚               â”‚
    â”‚                       â”‚               â””â”€â”€ [Tap "Submit"]
    â”‚                       â”‚                       â”‚
    â”‚                       â”‚                       â”œâ”€â”€ [Validation OK] â”€â”€â†’ [POST submit]
    â”‚                       â”‚                       â”‚                            â”‚
    â”‚                       â”‚                       â”‚                            â–¼
    â”‚                       â”‚                       â”‚                       [Status: SUBMITTED]
    â”‚                       â”‚                       â”‚                            â”‚
    â”‚                       â”‚                       â”‚                            â–¼
    â”‚                       â”‚                       â”‚                 [Event Timeline Updated]
    â”‚                       â”‚                       â”‚
    â”‚                       â”‚                       â””â”€â”€ [Validation fail] â”€â”€â†’ [Highlight errors]
    â”‚                       â”‚
    â”‚                       â”œâ”€â”€ [Status: IN_PROGRESS]
    â”‚                       â”‚       â”‚
    â”‚                       â”‚       â”œâ”€â”€ [Tap "Resolve"] â”€â”€â†’ [Add notes] â”€â”€â†’ [Status: RESOLVED]
    â”‚                       â”‚       â”‚
    â”‚                       â”‚       â””â”€â”€ [View reports] â”€â”€â†’ [List of submitted reports]
    â”‚                       â”‚
    â”‚                       â””â”€â”€ [Status: RESOLVED]
    â”‚                               â”‚
    â”‚                               â”œâ”€â”€ [Coordinator: "Close Event"] â”€â”€â†’ [Status: CLOSED]
    â”‚                               â””â”€â”€ [Coordinator: "Reopen"] â”€â”€â†’ [Status: IN_PROGRESS]
    â”‚
    â””â”€â”€ [Tap "+" (Technician/Coordinator)] â”€â”€â†’ [Create Event Form]
                                        â”‚
                                        â”œâ”€â”€ [Select asset] â”€â”€â†’ Search/select asset
                                        â”œâ”€â”€ [Set severity]
                                        â”œâ”€â”€ [Add description]
                                        â”œâ”€â”€ [Add initial photo (optional)]
                                        â””â”€â”€ [Tap "Create"] â”€â”€â†’ [Event created (OPEN)]
                                              â”‚
                                              â””â”€â”€ [Assign technicians] â”€â”€â†’ [Select from list]
```

**Optimistic UI:**
- Task completion: checkmark animates immediately, save in background.
- Photo upload: thumbnail appears immediately, upload happens async.
- Status transitions: button disabled and shows spinner during API call.

**Validation points:**
- Report: at least one task required.
- Report: work description required.
- Report: at least one signature (own) required.
- Report: photos optional.
- Resolve: resolution notes optional.

**Failure states:**
- Submit fails (network): Save locally, show "Pending submission" badge, retry on connectivity.
- Submit fails (validation): Highlight all invalid fields, scroll to first error.
- Submit fails (concurrent modification): Show "Report was modified by another user. Refresh and try again."
- Photo upload fails: Red badge on thumbnail, tap to retry.

### 4.5 Preventive Maintenance Execution Flow

```
[Preventive Tab â†’ Schedule List]
    â”‚
    â”œâ”€â”€ [Tap scheduled activity]
    â”‚       â”‚
    â”‚       â–¼
    â”‚   [Schedule Detail â†’ Template Steps]
    â”‚       â”‚
    â”‚       â”œâ”€â”€ [Tap "Execute"]
    â”‚       â”‚       â”‚
    â”‚       â”‚       â–¼
    â”‚       â”‚   [Preventive Report Form (DRAFT)]
    â”‚       â”‚       â”‚
    â”‚       â”‚       â”œâ”€â”€ [Step 1] â”€â”€â†’ Check completed / N/A / Failed
    â”‚       â”‚       â”‚   â”œâ”€â”€ [Completed] â†’ Add notes (optional)
    â”‚       â”‚       â”‚   â”œâ”€â”€ [N/A] â†’ Add reason
    â”‚       â”‚       â”‚   â””â”€â”€ [Failed] â†’ Add notes â†’ Creates corrective event?
    â”‚       â”‚       â”œâ”€â”€ [Step 2] â”€â”€â†’ Same
    â”‚       â”‚       â”œâ”€â”€ ...
    â”‚       â”‚       â”œâ”€â”€ [Add photos per step or overall]
    â”‚       â”‚       â”œâ”€â”€ [Add participant signatures]
    â”‚       â”‚       â”œâ”€â”€ [Add own signature]
    â”‚       â”‚       â””â”€â”€ [Submit]
    â”‚       â”‚
    â”‚       â””â”€â”€ [Cancel] â”€â”€â†’ [Confirm discard] â”€â”€â†’ Return to list
    â”‚
    â””â”€â”€ [Overdue section at top] â”€â”€â†’ Tap to prioritize
```

### 4.6 Replacement Workflow

```
[Report Form â†’ "Record Replacement"]
    â”‚
    â–¼
[Step 1: Select Old Asset]
    â”‚
    â”œâ”€â”€ [Current asset (auto-selected if context known)]
    â””â”€â”€ [Search/select different asset]
    â”‚
    â–¼
[Step 2: Select New Asset]
    â”‚
    â”œâ”€â”€ [Search asset hierarchy]
    â”œâ”€â”€ [Browse warehouse stock]
    â”‚       â”‚
    â”‚       â””â”€â”€ [Select from stock list â†’ marks as issued]
    â””â”€â”€ [Enter serial manually (future)]
    â”‚
    â–¼
[Step 3: Select Reason]
    â”‚
    â”œâ”€â”€ Failed
    â”œâ”€â”€ Worn / End of Life
    â”œâ”€â”€ Upgrade
    â””â”€â”€ Other (free text)
    â”‚
    â–¼
[Step 4: Add Notes (optional)]
    â”‚
    â–¼
[Save]
    â”‚
    â”œâ”€â”€ [Replacement added to report]
    â”œâ”€â”€ [Old asset: status â†’ REMOVED]
    â”œâ”€â”€ [New asset: linked to position]
    â””â”€â”€ [Both updated in asset history]
```

### 4.7 Attachment Upload Flow

```
[Report Form â†’ "Add Photo"]
    â”‚
    â”œâ”€â”€ [Action Sheet]
    â”‚   â”œâ”€â”€ [ðŸ“· Take Photo] â”€â”€â†’ [Camera opens (AVCaptureSession)]
    â”‚   â”‚                           â”‚
    â”‚   â”‚                           â””â”€â”€ [Photo captured] â”€â”€â†’ [Thumbnail in grid]
    â”‚   â”‚                                                            â”‚
    â”‚   â”‚                                                   [Upload in background]
    â”‚   â”‚                                                            â”‚
    â”‚   â”‚                                                   â”œâ”€â”€ [Success] â”€â”€â†’ [Green check badge]
    â”‚   â”‚                                                   â””â”€â”€ [Failure] â”€â”€â†’ [Red error badge]
    â”‚   â”‚                                                                         â”‚
    â”‚   â”‚                                                                   [Tap to retry]
    â”‚   â”‚
    â”‚   â””â”€â”€ [ðŸ–¼ Choose from Library] â”€â”€â†’ [PhotosPicker opens]
    â”‚                                       â”‚
    â”‚                                       â””â”€â”€ [Select (multi)] â”€â”€â†’ [Thumbnails in grid]
    â”‚                                                                        â”‚
    â”‚                                                               [Upload batch]
    â”‚
    â””â”€â”€ [Tap existing thumbnail]
            â”‚
            â”œâ”€â”€ [Full screen preview]
            â”œâ”€â”€ [Share]
            â””â”€â”€ [Delete (with confirmation)]
```

**Upload strategy:**
- Each photo uploaded immediately (not batched with report submit).
- Max 10MB per photo, auto-resize to 1920px max dimension.
- Max 50MB total per report.
- Upload progress indicator on each thumbnail (CircularProgressView).

### 4.8 Offline Draft Recovery Flow

```
[Report Form â†’ Network Drops]
    â”‚
    â”œâ”€â”€ [Auto-save fires] â”€â”€â†’ [Draft saved to local SwiftData / JSON]
    â”‚
    â”œâ”€â”€ [User continues editing] â”€â”€â†’ [All changes saved locally]
    â”‚
    â”œâ”€â”€ [User taps Submit]
    â”‚       â”‚
    â”‚       â”œâ”€â”€ [No network] â”€â”€â†’ [Show "No network connection. Report will be submitted when connected."]
    â”‚       â”‚                         â”‚
    â”‚       â”‚                         â””â”€â”€ [Save to pending queue]
    â”‚       â”‚                               â”‚
    â”‚       â”‚                               â””â”€â”€ [Badge on tab: "1 pending"]
    â”‚       â”‚
    â”‚       â””â”€â”€ [Network restored]
    â”‚               â”‚
    â”‚               â”œâ”€â”€ [Auto-retry pending submissions]
    â”‚               â”‚       â”‚
    â”‚               â”‚       â”œâ”€â”€ [Success] â”€â”€â†’ [Remove from queue, clear badge]
    â”‚               â”‚       â””â”€â”€ [Failure] â”€â”€â†’ [Keep in queue, retry later]
    â”‚               â”‚
    â”‚               â””â”€â”€ [User returns to app] â”€â”€â†’ [Pending queue checked]
    â”‚
    â””â”€â”€ [User closes app / navigates away]
            â”‚
            â”œâ”€â”€ [Draft saved] â”€â”€â†’ [Next open: "You have an unsaved report. Continue editing?"]
            â”‚
            â””â”€â”€ [Draft discarded] â”€â”€â†’ [No recovery possible]
```

---

## 5. Screen Inventory

### 5.1 Auth Module

| Screen | Purpose | Primary Actions | Data Displayed | Entry Points | API Endpoints | Required Role | Offline Behavior | Media |
|--------|---------|----------------|----------------|--------------|---------------|---------------|------------------|-------|
| **Login** | Authenticate user | Sign In, Forgot Password | Email field, password field, app logo | App launch | `POST /auth/login`, `POST /auth/refresh` | None | Show cached state, allow retry | None |
| **Session Expired** | Re-authenticate after token expiry | Sign In | Message, email field (pre-filled), password field | Interceptor redirect | `POST /auth/login` | All | N/A | None |

### 5.2 Assets Module

| Screen | Purpose | Primary Actions | Data Displayed | Entry Points | API Endpoints | Required Role | Offline Behavior | Media |
|--------|---------|----------------|----------------|--------------|---------------|---------------|------------------|-------|
| **Hierarchy Browser** | Explore asset tree | Drill-down, search, pull-to-refresh | Level title, children list with icons, breadcrumb | Assets tab | `GET /assets/{id}/children`, `GET /assets/{id}/subtree` | All | Cache last-viewed level | Asset type icons |
| **Asset Search** | Find asset by serial/name | Type query, select result | Results with breadcrumb, recent searches | Search bar on Hierarchy | `GET /assets?q=...` | All | Cache recent results | Asset type icons |
| **Asset Detail** | View asset info & history | View hierarchy position, view history, start event | Name, serial, part number, breadcrumb, children, events, history | Hierarchy tap, search result | `GET /assets/{id}` | All | Show cached detail if available | Asset photos (optional) |
| **Move Asset** | Reassign asset parent | Select new parent, confirm | Current position, selectable new parent | Asset Detail â†’ Move | `POST /assets/{id}/move` | Coordinator | Not available offline | None |

### 5.3 Corrective Module

| Screen | Purpose | Primary Actions | Data Displayed | Entry Points | API Endpoints | Required Role | Offline Behavior | Media |
|--------|---------|----------------|----------------|--------------|---------------|---------------|------------------|-------|
| **Event List** | View open events | Filter, pull-to-refresh, create event (+ for Technician/Coordinator) | Event rows with severity, status, asset, time | Corrective tab | `GET /corrective-events` | Tech/Coord/Boss | Show cached list | None |
| **Event Detail** | View event info & timeline | Start, resolve, close, create report, assign techs | Status, severity, description, asset, timeline, reports | Event list tap | `GET /corrective-events/{id}` | Tech/Coord/Boss | Show cached timeline | Initial photo |
| **Create Event** | Start new corrective event | Select asset, set severity, describe, add photo | Asset search, severity picker, description field | Event list â†’ + | `POST /corrective-events` | Technician/Coordinator | Save as draft locally | Initial photo |
| **Assign Technicians** | Assign techs to event | Select/deselect techs, confirm | Available techs list | Event Detail â†’ Assign | `POST /corrective-events/{id}/assign` planned | Coordinator | Not available offline | None |
| **Report Form** | Fill shift report | Add tasks, photos, signatures, replacements, submit | Tasks, attachments, signatures, replacements | Event Detail â†’ Create Report | `POST /corrective-events/{id}/reports`, `PATCH /corrective-reports/{id}` | Tech/Coord/Boss | Auto-save draft every 30s. Queue submit. | Photos, signatures |
| **Report Detail** | View submitted report | View tasks, photos, signatures, print/share | Full report content | Event timeline tap, asset history | `GET /corrective-reports/{id}` | Tech/Coord/Boss | Show cached report | Photos, signatures |

### 5.4 Preventive Module

| Screen | Purpose | Primary Actions | Data Displayed | Entry Points | API Endpoints | Required Role | Offline Behavior | Media |
|--------|---------|----------------|----------------|--------------|---------------|---------------|------------------|-------|
| **Schedule List** | View PM schedule | Filter (overdue/today/week/month), pull-to-refresh | Activity rows with due date, asset, status | Preventive tab | `GET /schedules` | All | Show cached list | None |
| **Schedule Detail** | View PM activity | Execute, view template steps | Template steps, asset, due date, assigned techs | Schedule list tap | `GET /schedules/{id}` | Tech | Show cached template | Template diagrams (future) |
| **PM Report Form** | Execute PM report | Complete steps, add photos, sign, submit | Step checklist, notes, photos, signatures | Schedule Detail â†’ Execute | `POST /preventive-reports`, `PATCH /preventive-reports/{id}` | Tech | Auto-save, queue submit | Photos, signatures |
| **PM Report Detail** | View submitted PM report | View completed steps, photos, signatures | Completed checklist with notes | Schedule detail, asset history | `GET /preventive-reports/{id}` | All | Show cached | Photos, signatures |

### 5.5 Components Module

| Screen | Purpose | Primary Actions | Data Displayed | Entry Points | API Endpoints | Required Role | Offline Behavior | Media |
|--------|---------|----------------|----------------|--------------|---------------|---------------|------------------|-------|
| **Component List** | Browse all components with filters | Filter by status/type, search by serial, tap detail | Component cards: type icon, serial, current location, status badge | Tab "Components" | `GET /api/v1/components` | All | Show cached list | â€” |
| **Component Detail** | View component info + movement history | View current slot, view movement timeline, navigate to asset | Header: type, serial, status. Sections: current location, movements timeline | Component list tap | `GET /api/v1/components/{id}` | All | Cached detail | â€” |
| **Register Component** | Register new component in inventory | Select type, enter serial, add location, confirm | Form fields: type picker, serial input, location selector, notes | Components tab "+" | `POST /api/v1/components` | Warehouse Operator | Queue on disconnect | Camera for serial scan |
| **Slot Locations** | View slot hierarchy per equipment kind | Browse by equipment kind, view slot detail, see occupancy | Expandable tree of slots, occupancy indicator per slot | Components tab â†’ Slots | `GET /api/v1/slot-locations` | All | Cached tree | â€” |
| **Slot Detail** | View single slot with image and occupancy | View slot image, see current occupant, navigate to component | Slot info, image viewer, current component card | Slot location tap | `GET /api/v1/slot-locations/{id}` | All | Cached detail | Slot image |
| **Physical Locations** | Browse warehouse zones and shelves | View hierarchy of warehouse locations | Tree view of location hierarchy | Components tab â†’ Locations | `GET /api/v1/locations` | All | Cached tree | â€” |

### 5.6 Common / Shared Screens

| Screen | Purpose | Primary Actions | Data Displayed | Entry Points | API Endpoints | Required Role | Offline Behavior | Media |
|--------|---------|----------------|----------------|--------------|---------------|---------------|------------------|-------|
| **Signature Pad** | Capture signature via PencilKit | Sign, clear, confirm | White canvas with guide line | Report form â†’ Add Signature | `POST /.../signatures` | All | Queue upload | Signature PNG |
| **Photo Viewer** | Full-screen photo preview | Zoom, pan, share, delete | Full resolution image | Attachment thumbnail tap | `GET /attachments/{id}` | All | Show cached thumbnail | Photo |
| **Camera Capture** | Take photo for report | Capture, retake, use | Camera viewfinder | Report form â†’ Add Photo | Upload via multipart | All | Queue upload | Photo |

---

## 6. SwiftUI UX Architecture

### 6.1 Navigation Philosophy

- **Predictable:** Users always know where they are and how to go back. Breadcrumb in asset hierarchy. Back swipe everywhere.
- **Minimal taps:** High-frequency actions (view events, start report) are 1â€“2 taps from the tab bar.
- **Context-preserving:** Navigating to a report from the event timeline keeps the event context. Navigating back returns to the same scroll position.
- **Modal for creation:** Sheets for forms (create event, create report). Push for drill-down (hierarchy, detail views).

### 6.2 Tab Structure

```
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚  Corrective  â”‚  Preventive  â”‚   Assets     â”‚  Components  â”‚  Profile     â”‚  (Dashboard)â”‚
â”‚  (Tab 1)     â”‚  (Tab 2)     â”‚  (Tab 3)     â”‚  (Tab 4)     â”‚  (Tab 5)     â”‚  Future     â”‚
â”‚             â”‚              â”‚              â”‚              â”‚              â”‚             â”‚
â”‚  Icon:      â”‚  Icon:       â”‚  Icon:       â”‚  Icon:       â”‚  Icon:       â”‚             â”‚
â”‚  wrench     â”‚  calendar    â”‚  cube        â”‚  chip        â”‚  person      â”‚             â”‚
â”‚             â”‚              â”‚              â”‚  (cpu)       â”‚              â”‚             â”‚
â”‚  Badge:     â”‚  Badge:      â”‚              â”‚  Badge:      â”‚              â”‚             â”‚
â”‚  open count â”‚  overdue cnt â”‚              â”‚  low stock   â”‚              â”‚             â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
```

- Tab bar uses SF Symbols with selected/unselected states.
- Tab bar badge for corrective (open events assigned) and preventive (overdue tasks).
- Tab bar is always visible except during full-screen modal (camera, signature pad).

### 6.3 Detail Navigation Patterns

| Pattern | Usage | Animation |
|---------|-------|-----------|
| **Push (NavigationStack)** | Hierarchy drill-down, asset detail, event detail, report detail | Standard slide-right. Swipe-back to pop. |
| **Sheet (modal)** | Create event, create report, search, move asset, assign techs | Slide-up from bottom. Pull-down to dismiss. |
| **Full-screen cover** | Camera capture, signature pad | Slide-up, no pull-down dismiss. |
| **Popover (iPad)** | Quick actions, pickers (severity, reason) | Popover from source rect. |
| **Context menu** | Long press on asset row â†’ View Detail, Copy Serial | iOS standard peek. |

### 6.4 Modal Usage

- **Create forms** (Event, Report): Modal sheet. Discard confirmation if dirty. Auto-save draft.
- **Search:** Modal sheet over Assets tab. Search bar active on open. Dismiss with swipe-down or Cancel.
- **Photo picker:** System `PhotosPicker` sheet.
- **Signature pad:** Full-screen cover. No accidental dismiss.

### 6.5 Bottom Sheet Usage

Use `.sheet()` with modern iOS/iPadOS 26.5 presentation behavior and detents.

| Bottom Sheet | Usage | Detent |
|-------------|-------|--------|
| Severity picker | Create event | .medium |
| Reason picker | Replacement | .medium |
| Action picker | Photo source (camera/gallery) | .small (iOS 16+) |
| Filter options | Event/schedule list | .medium |

### 6.6 Search UX

- **Global search bar** on Assets tab (always visible, prominent).
- **Debounced** (300ms) after 3 characters minimum.
- **Results** show as a list below the search bar (not a separate screen).
- **Recent searches** shown when search bar is active but query is empty.
- **Cancel** dismisses search and restores hierarchy view.
- **Optimistic:** Show previous results while fetching.

### 6.7 Hierarchy Visualization UX

- **List-based drill-down** (not tree view). Each level is a separate screen in the `NavigationStack`.
- **Rows** show: asset type icon (SF Symbol), name, serial number (truncated), disclosure indicator.
- **Depth indicator:** Breadcrumb at top: `Train 101 â†’ Car A â†’ HVAC System â†’ ...`
- **Leaf nodes (LRUs):** No disclosure indicator. Tap navigates to asset detail.
- **Lazy loading:** Each level fetches children on appear. Pull-to-refresh at top level.

### 6.8 Form UX

- **Native SwiftUI `Form`** with section headers.
- **Inline validation:** Errors appear below fields immediately on blur or on submit attempt.
- **Auto-save:** Draft reports auto-save every 30 seconds. Visual indicator "Saved" / "Saving...".
- **Keyboard handling:** Scroll to active field. Keyboard toolbar with "Done" / "Next".
- **Photo grid:** Horizontally scrollable row of thumbnails with "+" add button.
- **Signature step:** Dedicated section with "Add Signature" button â†’ opens full-screen PencilKit.
- **Section completion:** Each of the 6 report sections shows a completion toggle (green checkmark / empty circle). Sections can be completed independently.
- **Stop Here:** A "Stop Here" button in the report footer opens a section picker sheet. Selecting a stop point stores a marker used to hide later blank fields in the generated PDF.

### 6.9 Error UX

| Error Type | UI Pattern | Response |
|-----------|------------|----------|
| **Network failure** | Toast/banner at top: "No internet connection" | Non-blocking. Operations queue. |
| **API error (4xx)** | Inline alert below relevant field | User can correct and retry. |
| **API error (5xx)** | Alert dialog: "Something went wrong. Please try again." | Retry button. |
| **Validation error** | Red border + error text below field. Scroll to first error. | User corrects. |
| **Concurrent modification** | Alert: "This report was modified. Refresh?" | Refresh data. |
| **Upload failure** | Red badge on thumbnail, toast "Upload failed" | Tap to retry. |

### 6.10 Loading & Empty State UX

| State | Pattern | Behavior |
|-------|---------|----------|
| **Initial load** | `ProgressView()` spinner centered on screen | Appears on first load of each tab/screen. |
| **Refresh** | Pull-to-refresh (`RefreshControl`) | Only on list screens. |
| **Background reload** | Shimmer skeleton (custom) | On hierarchy levels while children load. |
| **Pagination** | "Loading more..." at bottom of list | Triggered when scrolled near end. |
| **Empty state** | Icon + title + subtitle + optional CTA | "No events found" / "No assets at this level" |
| **Error state** | Icon + message + "Try Again" button | Replaces content on load failure. |
| **Pending submission** | Badge "1 pending" on tab + row indicator | Report row shows "Pending submission" with sync icon. |

### 6.11 Animation Philosophy

- **Purposeful:** Every animation communicates something â€” hierarchy drill-down, status change, submission success.
- **Subtle:** 0.3s ease-in-out defaults. No gratuitous bounce or parallax.
- **Status transitions:** Button morphs (e.g., "Start" â†’ spinner â†’ "In Progress" with checkmark).
- **List changes:** Animated inserts/removes for status filter changes.
- **Navigation:** Standard iOS stack transitions. `matchedGeometryEffect` for asset type icon during hierarchy drill-down.
- **Tab switching:** Cross-dissolve between tab root views (no slide).
- **Haptic feedback:** Light impact on status transitions. Success notification on submission.

---

## 7. Design System Foundations

### 7.1 Color Philosophy

- **Hitachi-branded, industrial, clear.** The UI uses the company logo colors as brand anchors: red, black, white, and graphite gray.
- **Red is the primary brand accent.** Use it for primary actions, active navigation, selected controls, and key brand moments.
- **Do not overuse red.** Red must remain visually important; avoid using it as a large background or decorative fill across operational screens.
- **Neutral base.** Operational screens should mostly use white, near-white, black, and graphite gray so reports and field data remain easy to read.
- **Status colors are semantic, not decorative.** Red can be used for critical/overdue/error states, but normal workflow status must still use distinct semantic colors.

### 7.1.1 Brand Palette

The palette is derived from the three provided Hitachi logo references:

| Token | Hex | Source / Usage |
|-------|-----|----------------|
| `brandRed` | `#E60012` | Hitachi red logo. Primary accent, selected states, primary CTA |
| `brandBlack` | `#000000` | Black logo variant. High contrast text and dark mode base |
| `brandWhite` | `#FFFFFF` | White logo background / negative space. Primary app background |
| `brandGraphite` | `#4A4A4A` | Gray "Inspire the Next" logo variant. Secondary text, icons, subdued chrome |
| `brandRedPressed` | `#B8000E` | Pressed/active variant of brand red |
| `brandRedSubtle` | `#FDEBEC` | Very light red tint for selected rows, alerts, and subtle brand surfaces |

| Token | Hex (Light) | Hex (Dark) | Usage |
|-------|-------------|------------|-------|
| `backgroundPrimary` | `#FFFFFF` | `#111111` | Screen backgrounds |
| `backgroundSecondary` | `#F6F6F6` | `#1C1C1E` | Grouped backgrounds |
| `backgroundTertiary` | `#EFEFEF` | `#2A2A2C` | Fills, search bars, disabled fields |
| `textPrimary` | `#1F1F1F` | `#F5F5F5` | Primary text |
| `textSecondary` | `#4A4A4A` | `#C7C7CC` | Secondary/label text |
| `textTertiary` | `#8A8A8A` | `#8E8E93` | Placeholder text |
| `accent` | `#E60012` | `#FF3B30` | Primary buttons, links, active states |
| `accentPressed` | `#B8000E` | `#FF6B63` | Pressed primary controls |
| `accentSubtle` | `#FDEBEC` | `#3A1114` | Selected rows, subtle highlights |
| `destructive` | `#B00020` | `#FF453A` | Delete, errors, destructive confirmation |
| `separator` | `#D9D9D9` | `#3A3A3C` | Dividers, borders |

### 7.2 Status Color System

| Status | Color | Hex | Icon |
|--------|-------|-----|------|
| Scheduled | Graphite | `#4A4A4A` | `calendar` |
| In Progress | Amber | `#C77800` | `arrow.triangle.2.circlepath` |
| Completed | Green | `#1F8A4C` | `checkmark.circle.fill` |
| Closed | Dark Gray | `#6B6B6B` | `lock.circle.fill` |
| Overdue | Hitachi Red | `#E60012` | `exclamationmark.circle.fill` |
| Draft | Graphite | `#4A4A4A` | `doc.text` |
| Finalized | Green | `#1F8A4C` | `checkmark.seal.fill` |
| Rejected | Dark Red | `#B00020` | `xmark.seal.fill` |
| Removed | Dark Gray | `#636366` | `trash.circle.fill` |
| Warehouse | Steel Blue | `#2F6F9F` | `shippingbox.fill` |
| Critical Severity | Hitachi Red | `#E60012` | `exclamationmark.triangle.fill` |
| High Severity | Orange | `#D56A00` | `exclamationmark.circle.fill` |
| Medium Severity | Yellow | `#B88700` | `exclamationmark.circle` |
| Low Severity | Gray | `#8A8A8A` | `info.circle.fill` |

### 7.3 Typography Hierarchy

| Style | Font | Weight | Size | Line Height | Usage |
|-------|------|--------|------|-------------|-------|
| **Large Title** | SF Pro | Bold | 34px | 41px | Screen title (asset name) |
| **Title 1** | SF Pro | Bold | 28px | 34px | Tab root titles |
| **Title 2** | SF Pro | Semibold | 22px | 28px | Section headers |
| **Title 3** | SF Pro | Semibold | 20px | 25px | Card titles, event names |
| **Headline** | SF Pro | Semibold | 17px | 22px | Row titles, button text |
| **Body** | SF Pro | Regular | 17px | 22px | Paragraph text, descriptions |
| **Callout** | SF Pro | Regular | 16px | 21px | Captions, annotations |
| **Subheadline** | SF Pro | Regular | 15px | 20px | Secondary info |
| **Footnote** | SF Pro | Regular | 13px | 18px | Timestamps, metadata |
| **Caption 1** | SF Pro | Regular | 12px | 16px | Badges, small labels |
| **Caption 2** | SF Pro | Medium | 11px | 13px | Tiny context, version |

### 7.4 Spacing System

| Token | Points | Usage |
|-------|--------|-------|
| `spacing.xxs` | 4 | Tight inner padding, icon gaps |
| `spacing.xs` | 8 | Between related elements, icon + text |
| `spacing.sm` | 12 | Between form fields, list item padding |
| `spacing.md` | 16 | Section margins, card padding |
| `spacing.lg` | 24 | Between sections, screen padding |
| `spacing.xl` | 32 | Tab spacing, large section breaks |
| `spacing.xxl` | 48 | Hero spacing, modal top padding |

### 7.5 Card Patterns

- **Corner radius:** 12pt (standard), 16pt (elevated cards).
- **Shadow:** Light: subtle shadow with 0.1 opacity. Dark: no shadow, use separator border instead.
- **Elevation levels:** Flat (standard list row), Elevated (report summary card, event summary card).
- **Inner padding:** 16pt all sides.

### 7.6 List Patterns

- **Inset grouped style** (iOS Settings style) for forms and data entry.
- **Plain style** for hierarchy drill-down and event lists.
- **Swipe actions:** Delete draft report (swipe left). Submit pending report (swipe left).
- **Pull-to-refresh** on all data list screens.

### 7.7 Form Controls

| Control | Styling |
|---------|---------|
| **Text field** | Rounded 10pt background (`.background(.quaternary)`), clear button, placeholder text |
| **Secure field** | Same as text field, with show/hide toggle |
| **Picker** | Menu-style picker (iOS 14+) inline in Form row |
| **Toggle** | Standard iOS switch |
| **Button** | Filled rounded rect (12pt corner, 16pt vertical padding) for primary. `.buttonStyle(.bordered)` for secondary. |
| **Segmented control** | For status filters (Open / Resolved / Closed) |
| **Stepper** | For quantity (tools, consumables) |

### 7.8 Badges & Chips

| Component | Design | Usage |
|-----------|--------|-------|
| **Status badge** | Pill shape, colored background, white text | Event status, report status, asset status |
| **Severity badge** | Pill shape, colored icon + text | Event severity (critical â†’ red, high â†’ orange, etc.) |
| **Count badge** | Small red circle with white number | Tab bar badge, unread count |
| **Role chip** | Small rounded rect with role name | User role display |
| **Filter chip** | Tappable pill, selected/unselected state | Quick filters on list screens |

### 7.9 Timeline Component

- **Vertical line** on the left side.
- **Circle node** at each event point (colored by event type).
- **Card** to the right of each node with: date, title, summary, tappable.
- **Line connects** nodes continuously. Dotted line for future/pending items.
- **First node** larger (origin event). **Last node** may be an action button if event is open.

### 7.10 Attachment Previews

| Type | Preview |
|------|---------|
| **Photo** | Square thumbnail, 80x80pt. Tap â†’ full-screen viewer with zoom/pan. Long press â†’ share sheet. |
| **Signature** | Slightly smaller thumbnail, white background, ink color preserved. Shows signer name below. |
| **PDF** (future) | Document icon with page count badge. Tap â†’ QuickLook preview. |

### 7.11 Dark Mode Strategy

- Follow system setting (`.preferredColorScheme(.none)`).
- All colors have dark mode variants defined in asset catalog.
- Status colors remain distinguishable in dark mode (slightly more saturated).
- Cards use bordered style instead of shadow in dark mode.

### 7.12 Accessibility

- **Dynamic Type** support for all text styles. Test at AX5.
- **VoiceOver** labels on all interactive elements. Custom actions on lists.
- **Haptic feedback**:
  - `.impact(style: .light)` on button taps.
  - `.notification(.success)` on report submission.
  - `.notification(.error)` on failure.
- **Minimum touch target:** 44x44pt for all interactive elements.
- **Reduce motion** respected: disable animations if `UIAccessibility.isReduceMotionEnabled`.

### 7.13 Animation Guidelines

| Animation | Duration | Curve | Usage |
|-----------|----------|-------|-------|
| Screen transition | 0.35s | `easeInOut` | Push/pop navigation |
| Modal present | 0.3s | `easeOut` | Sheet slide-up |
| Modal dismiss | 0.25s | `easeIn` | Sheet slide-down |
| Status change | 0.3s | `spring(response: 0.3)` | Button morph, badge update |
| List insert/remove | 0.35s | `spring` | Filter toggling |
| Search expand | 0.25s | `easeOut` | Search bar activation |

---

## 8. API-to-UI Mapping

### 8.1 Endpoint-to-Screen Matrix

| Backend Use Case | REST Endpoint | iOS Screens | ViewModel(s) | Pagination | Caching | Optimistic Update |
|-----------------|---------------|-------------|--------------|------------|---------|-------------------|
| Authenticate user | `POST /auth/login` | Login | `LoginViewModel` | None | Token in Keychain | No |
| Refresh token | `POST /auth/refresh` | (interceptor) | `AuthInterceptor` | None | Token in Keychain | No |
| Search assets | `GET /assets?q=...` | Asset Search, Create Event â†’ Asset Picker | `AssetSearchViewModel`, `AssetPickerViewModel` | Offset | Recent results | Show previous results |
| List children | `GET /assets/{id}/children` | Hierarchy Browser | `HierarchyViewModel` | Cursor | Level cache | No |
| Get subtree | `GET /assets/{id}/subtree` | Asset Detail â†’ Children tab | `AssetDetailViewModel` | None | Level cache | No |
| Get ancestors | `GET /assets/{id}/ancestors` | Hierarchy Browser â†’ breadcrumb | `HierarchyViewModel` | None | Level cache | No |
| Get asset detail | `GET /assets/{id}` | Asset Detail | `AssetDetailViewModel` | None | Detail cache | No |
| Get asset history | `GET /assets/{id}/history` | Asset Detail â†’ History | `AssetDetailViewModel` | Offset | History cache | No |
| Create asset | `POST /assets` | (future â€” admin panel) | â€” | None | â€” | No |
| Move asset | `POST /assets/{id}/move` | Move Asset | `MoveAssetViewModel` | None | Invalidate caches | Yes (UI before API) |
| List events | `GET /corrective-events` | Event List | `EventListViewModel` | Offset | List cache | No |
| Get event detail | `GET /corrective-events/{id}` | Event Detail | `EventDetailViewModel` | None | Detail cache | No |
| Create event | `POST /corrective-events` | Create Event | `CreateEventViewModel` | None | Invalidate list | Yes (add to list) |
| Resolve event | `POST /corrective-events/{id}/resolve` | Event Detail | `EventDetailViewModel` | None | Invalidate | Yes (status change) |
| Close event | `POST /corrective-events/{id}/close` | Event Detail | `EventDetailViewModel` | None | Invalidate | Yes (status change) |
| Reopen event | `POST /corrective-events/{id}/reopen` | Event Detail | `EventDetailViewModel` | None | Invalidate | Yes (status change) |
| Create report | `POST /corrective-events/{id}/reports` | Report Form | `ReportFormViewModel` | None | Invalidate event detail | Yes (add report card) |
| Submit report | `POST /corrective-reports/{id}/submit` | Report Form | `ReportFormViewModel` | None | Invalidate | Yes (status change) |
| Get report detail | `GET /corrective-reports/{id}` | Report Detail | `ReportDetailViewModel` | None | Detail cache | No |
| Add task | `POST /corrective-reports/{id}/tasks` | Report Form | `ReportFormViewModel` | None | Draft save | Yes (add task row) |
| Add signature | `POST /corrective-reports/{id}/signatures` | Signature Pad | `SignatureViewModel` | None | Queue offline | Yes (show thumbnail) |
| Upload attachment | `POST /reports/{type}/{id}/attachments` | Report Form â†’ Camera/Gallery | `AttachmentViewModel` | None | Queue offline | Yes (show thumbnail) |
| Download attachment | `GET /attachments/{id}` | Photo Viewer | `PhotoViewerViewModel` | None | Thumbnail cache | No |
| List schedules | `GET /schedules` | Schedule List | `ScheduleListViewModel` | Offset | List cache | No |
| Get schedule detail | `GET /schedules/{id}` | Schedule Detail | `ScheduleDetailViewModel` | None | Detail cache | No |
| Create PM report | `POST /preventive-reports` | PM Report Form | `PMReportFormViewModel` | None | Invalidate schedule | Yes |
| Submit PM report | `POST /preventive-reports/{id}/submit` | PM Report Form | `PMReportFormViewModel` | None | Invalidate | Yes |
| Record replacement | (within report) | Report Form â†’ Replacement | `ReplacementViewModel` | None | Invalidate asset history | Yes |
| Assign technicians | `POST /corrective-events/{id}/assign` (future) | Assign Technicians | `AssignTechViewModel` | None | Invalidate event | Yes |

### 8.2 Where Pagination Exists

| Endpoint | Pagination Type | Default Per Page |
|----------|----------------|------------------|
| `GET /assets?q=` | Offset | 20 |
| `GET /assets/{id}/children` | Cursor | 50 |
| `GET /assets/{id}/history` | Offset | 20 |
| `GET /corrective-events` | Offset | 20 |
| `GET /schedules` | Offset | 20 |

### 8.3 Where Caching Exists

| Data | Cache Strategy | Invalidation |
|------|---------------|--------------|
| Asset hierarchy (children per level) | In-memory cache per session | Pull-to-refresh, or on asset move/create |
| Asset detail | In-memory cache per session | Pull-to-refresh, or on related event/report submit |
| Event list | In-memory cache per session | Pull-to-refresh, or on event create/status change |
| Event detail | In-memory cache per session | Pull-to-refresh, or on report submit |
| Schedule list | In-memory cache per session | Pull-to-refresh |
| Report detail | Not cached (read rarely repeated) | N/A |
| Auth tokens | Keychain | On expiry, logout |
| Recent searches | UserDefaults | FIFO, max 10 items |
| Draft reports | SwiftData / local JSON | On submit or discard |

### 8.4 Where Optimistic Updates Are Acceptable

| Operation | Risk | Strategy |
|-----------|------|----------|
| Status change (resolve, close, reopen) | Low | Update UI immediately, revert on API failure |
| Add task to report | Low | Add row instantly, sync on save |
| Add signature | Low | Show thumbnail instantly, upload async |
| Upload photo | Medium | Show thumbnail instantly, failed upload shows error badge |
| Create report (offline) | Medium | Save as pending-draft locally, submit when online |
| Assign technician | Low | Update UI immediately, revert on failure |
| Move asset | High | Show spinner, update only after API success |

---

## 9. Incremental Frontend Delivery Plan

### 9.1 Phase 1: Foundation & Navigation (Week 1â€“2)

**Goal:** Working navigation shell with mock data.

| Deliverable | Details |
|-------------|---------|
| Xcode project setup | iPadOS/iOS 26.5 deployment target, SwiftUI, `NavigationStack`, native adaptive `TabView`, Liquid Glass-capable design system |
| App structure | `MaintenanceAppApp.swift`, `ContentView.swift`, tab bar with 4 tabs |
| `APIClient` skeleton | Protocol-based, mock implementation returning fake JSON |
| `Route.swift` | Typed navigation destinations (enum with associated values) |
| Core components | `StatusBadgeView`, `LoadingIndicator`, `EmptyStateView`, `ErrorAlert` |
| Design system | Color assets, typography extensions, spacing constants in asset catalog |
| Tab stubs | Each tab shows placeholder screen with title and icon |
| Login screen (mock) | UI only, no auth. Tapping "Sign In" navigates to main tabs. |
| Asset hierarchy (mock) | Fake tree data. Drill-down navigation with breadcrumb. `matchedGeometryEffect` on drill-down. |
| Asset search (mock) | Search bar, fake results, debounce simulation. |

**Testing:** SwiftUI previews for all components and screens with mock data.

### 9.2 Phase 2: Corrective Module (Week 3â€“4)

**Goal:** Full corrective maintenance flow with mock data.

| Deliverable | Details |
|-------------|---------|
| Event list | Real UI, fake data. Filter by status. Pull-to-refresh. |
| Event detail | Timeline view (custom component). Action buttons per status. |
| Create event form | Asset picker (search), severity picker, description. |
| Report form | Tasks list, photo grid, signature step, submit flow. |
| Signature pad | PencilKit integration. "Sign here" guide. |
| Camera integration | `AVCaptureSession` wrapper. Resize to 1920px. |
| Photo grid component | Horizontal scroll, add/delete, full-screen preview. |
| Report detail | Read-only view of submitted report. Photo gallery. |
| Signature capture flow | Full canvas â†’ confirm â†’ upload simulation. |

**Testing:** SwiftUI previews, focus on form validation, signature pad, photo interactions.

### 9.3 Phase 3: Preventive Module & Edge Cases (Week 5)

**Goal:** Preventive flow, replacement workflow, polish.

| Deliverable | Details |
|-------------|---------|
| Schedule list | Grouped by overdue/today/week. Pull-to-refresh. |
| Schedule detail | Template steps checklist. |
| PM report form | Step-by-step completion. Photo per step. Signatures. |
| Replacement record | Within report form. Old/new asset selection. |
| Asset detail screen | Info, children, history tabs. History timeline filterable. |
| Move asset | Current position display. New parent browser. |
| Draft persistence | Auto-save every 30s to SwiftData. Resume on app relaunch. |
| Offline queue | Pending submissions badge. Auto-retry on connectivity. |
| Error handling | Toast, inline errors, retry buttons, conflict alerts. |

**Testing:** Full integration tests with mock API. Edge case testing (network drop, validation, empty states).

### 9.4 Phase 4: Real API Integration (Week 6â€“7)

**Goal:** Replace mocks with real API client. End-to-end flows.

| Deliverable | Details |
|-------------|---------|
| `APIClient` real implementation | URLSession, JWT injection, error mapping |
| `AuthInterceptor` | 401 handling, token refresh, request retry |
| `KeychainManager` | Secure token storage |
| Login â†’ real API | Replace mock login. Token management. |
| Asset â†’ real API | Replace mock hierarchy with real children/subtree endpoints |
| Corrective â†’ real API | Replace mock events, reports, signatures |
| Preventive â†’ real API | Replace mock schedules, reports |
| File upload â†’ real API | Multipart upload with progress |
| Pagination implementation | Offset and cursor-based. Infinite scroll. |

**Testing:** `APIClient` unit tests with `URLProtocol` mocking. Full E2E with test backend.

### 9.5 Phase 5: Polish & Hardening (Week 8)

**Goal:** Production-ready quality.

| Deliverable | Details |
|-------------|---------|
| Animations | `matchedGeometryEffect` polish, status transitions, loading sequences |
| Haptic feedback | All interactive feedback implemented |
| Dark mode | Test all screens in dark mode. Fix contrast issues. |
| Accessibility | VoiceOver labels, Dynamic Type testing (up to AX5) |
| Performance | Photo grid lazy loading. Hierarchy scroll performance. Memory profiling. |
| Edge cases | Empty states everywhere. Error states. Network transition handling. |
| Beta testing | TestFlight build. Internal feedback cycle. Bug fixes. |
| Fastlane setup | Code signing, TestFlight upload, App Store submission preparation |

### 9.6 Mock-First Strategy

1. **Define DTOs** (Swift `Codable` structs) for every API response/request.
2. **Define `APIClientProtocol`** with async methods returning `Result<T, APIError>` or `throws T`.
3. **Build `MockAPIClient`** implementing the protocol with fake JSON files + configurable delays.
4. **Build screens against `MockAPIClient`** injected via environment or init.
5. **Write SwiftUI previews** using `MockAPIClient` in `.previewEnvironment`.
6. **Replace with real `APIClient`** when API is ready â€” no UI changes needed.

### 9.7 SwiftUI Preview Strategy

- Every screen gets a `#Preview` block with mock data.
- Every ViewModel gets a preview-friendly initializer accepting mock dependencies.
- Preview data loaded from JSON files in `Resources/Preview Content/`.
- ViewModel previews use `@State` wrappers or `Observable` macros with pre-loaded state.
- Complex flows (report form with multiple steps) have previews for each step.

---

## Appendix: Document Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.1 | 2026-06-06 | Initial product specification and UX blueprint |

