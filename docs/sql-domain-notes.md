# SQL Domain Notes

**Version:** 0.1  
**Status:** Draft  
**Last Updated:** 2026-06-19

---

## 1. Purpose

This document records the SQL-level modeling decisions behind assets, business anchor assets, report scope assets, and rollout stages.

Documentation and schema names are written in English. App-visible values and seed data must remain in Spanish.

---

## 2. Asset Levels

The model uses one `assets` table for every trackable item.

The distinction between a large business asset and a smaller component is handled by category, hierarchy, and reporting flags, not by separate tables.

```sql
asset_types (
  id uuid primary key,
  name text not null,
  category text not null, -- LARGE_EQUIPMENT, EQUIPMENT, COMPONENT, SOFTWARE, TOOL, LOGICAL
  part_number text null,
  subsystem_id uuid not null,
  requires_serial_number boolean not null default false,
  supports_version boolean not null default false
);

assets (
  id uuid primary key,
  asset_type_id uuid not null references asset_types(id),
  name text not null,
  serial_number text null,
  internal_code text not null unique,
  software_version text null,
  lifecycle_status text not null,
  is_business_anchor boolean not null default false,
  business_label text null, -- e.g. Equipo for app-facing business navigation
  current_parent_asset_id uuid null references assets(id),
  current_position text null,
  current_location_id uuid null,
  created_at timestamptz not null,
  updated_at timestamptz not null
);
```

Examples:

| Asset | Category | Business Label | Business Anchor? |
|-------|----------|----------------|------------------|
| Tren 14 | LARGE_EQUIPMENT | Equipo | Yes |
| Zone Controller 2 | LARGE_EQUIPMENT | Equipo | Yes |
| Gabinete Frontam Patio | LARGE_EQUIPMENT | Equipo | Yes |
| LIMSYS001 | EQUIPMENT | Equipo | Yes, because Stage 1A treats ATS servers as equipos grandes |
| Tarjeta CIER 1 | COMPONENT | - | No, unless the business needs direct reliability metrics |
| Software ATS Patio | LOGICAL | Equipo / scope funcional | Yes |

In Spanish UI, the `Equipos` tab filters assets where `is_business_anchor = true` and usually `business_label = 'Equipo'`. Smaller assets such as cards, racks, cableado, and replaceable parts remain in the same `assets` table but are not shown in the main `Equipos` list unless promoted by business need.

---

## 3. Asset Hierarchy and History

Current parent fields on `assets` make common reads fast. Historical truth lives in `asset_assignments`.

```sql
asset_assignments (
  id uuid primary key,
  asset_id uuid not null references assets(id),
  parent_asset_id uuid null references assets(id),
  position text null,
  location_id uuid null,
  assigned_at timestamptz not null,
  unassigned_at timestamptz null,
  reason text null,
  source_report_version_id uuid null
);
```

For fast descendant and ancestor queries, keep a closure table updated whenever assignments change.

```sql
asset_closure (
  ancestor_asset_id uuid not null references assets(id),
  descendant_asset_id uuid not null references assets(id),
  depth integer not null,
  primary key (ancestor_asset_id, descendant_asset_id)
);
```

This enables the core business question:

```sql
-- Maintenance history for Zone Controller 2,
-- including reports on cards, servers, or software below it.
select distinct m.*
from maintenance_activities m
join maintenance_activity_assets maa
  on maa.maintenance_activity_id = m.id
join asset_closure ac
  on ac.descendant_asset_id = maa.asset_id
where ac.ancestor_asset_id = :zone_controller_2_asset_id;
```

---

## 4. Report Scope Assets

Maintenance reports should not store one vague `asset_id`. They should store asset links with roles.

```sql
maintenance_activities (
  id uuid primary key,
  activity_type text not null, -- PREVENTIVE or CORRECTIVE
  status text not null,        -- SCHEDULED, IN_PROGRESS, COMPLETED, CLOSED
  project_id uuid not null,
  primary_stage_id uuid null,
  title text not null,
  created_at timestamptz not null
);

maintenance_activity_assets (
  id uuid primary key,
  maintenance_activity_id uuid not null references maintenance_activities(id),
  asset_id uuid not null references assets(id),
  role text not null, -- PRIMARY_TARGET, INVOLVED, AFFECTED, REPLACED, INSTALLED, CONTEXT
  include_descendants boolean not null default true,
  notes text null
);
```

Typical usage:

| Scenario | Linked Assets |
|----------|---------------|
| Preventive maintenance on two Zone Controller cabinets | Two rows with `role = PRIMARY_TARGET` |
| Preventive ATS software maintenance across many servers | One logical asset "Software ATS Patio" as `PRIMARY_TARGET`, servers as `INVOLVED` |
| Corrective failure on Frontam cabinet | Frontam as `AFFECTED`; replaced server/card as `REPLACED` and `INSTALLED` |

Each finalized report version should snapshot its scope so future PDFs do not change if asset names or hierarchy change later.

```sql
report_version_assets (
  id uuid primary key,
  report_version_id uuid not null,
  asset_id uuid not null references assets(id),
  role text not null,
  snapshot_name text not null,
  snapshot_internal_code text not null,
  snapshot_path text null
);
```

---

## 5. Preventive Execution Details

Preventive reports need a normalized structure for participants, signatures, step results, and test results. General metadata is mostly a snapshot populated by the system; only the end time is editable during report execution.

```sql
preventive_reports (
  id uuid primary key,
  maintenance_activity_id uuid not null references maintenance_activities(id),
  site_id uuid not null,
  project_id uuid not null,
  stage_id uuid not null,
  system_id uuid not null,
  subsystem_id uuid not null,
  location_id uuid not null,
  location_path_snapshot text not null,
  actual_date date not null,
  activity_started_at timestamptz not null,
  activity_ended_at timestamptz null,
  final_result text null, -- OPERATIONAL, PARTIALLY_OPERATIONAL, NON_OPERATIONAL
  document_status text not null
);

preventive_report_participants (
  id uuid primary key,
  preventive_report_id uuid not null references preventive_reports(id),
  user_id uuid not null,
  role_snapshot text not null,
  selected boolean not null default true,
  signed_at timestamptz null,
  signature_ref text null
);

preventive_step_results (
  id uuid primary key,
  preventive_report_id uuid not null references preventive_reports(id),
  template_step_id uuid not null,
  is_completed boolean not null default true,
  comment text null,
  manual_page integer null
);

preventive_test_results (
  id uuid primary key,
  step_result_id uuid not null references preventive_step_results(id),
  test_definition_id uuid not null,
  selected_result text not null,
  notes text null
);
```

The `Reportes anteriores` section in preventive detail is a read model over finalized historical reports for the same business anchor equipment, not a version list for the current report. Each row opens the PDF preview for the report generated at that historical execution.

```sql
previous_preventive_reports_by_equipment as
select
  pr.id as preventive_report_id,
  maa.asset_id as equipment_asset_id,
  pr.actual_date,
  pr.final_result,
  mt.name as activity_name,
  u.full_name as technician_name
from preventive_reports pr
join maintenance_activity_assets maa
  on maa.maintenance_activity_id = pr.maintenance_activity_id
  and maa.role in ('PRIMARY_TARGET', 'INVOLVED')
join assets a
  on a.id = maa.asset_id
  and a.is_business_anchor = true
join maintenance_templates mt
  on mt.id = pr.template_id
left join preventive_report_participants prp
  on prp.preventive_report_id = pr.id
  and prp.selected = true
left join users u
  on u.id = prp.user_id;
```

Reusable maintainer comments are intentionally separate from report observations. They behave more like operational knowledge attached to a template and/or business anchor equipment.

```sql
maintenance_knowledge_comments (
  id uuid primary key,
  scope_type text not null, -- TEMPLATE, EQUIPMENT, TEMPLATE_EQUIPMENT
  maintenance_template_id uuid null,
  equipment_asset_id uuid null references assets(id),
  author_user_id uuid not null,
  message text not null,
  created_at timestamptz not null
);
```

Corrective comments are intentionally different: they are event-scoped notes attached only to a specific corrective event/work maintenance record. They must not be reused automatically in future corrective events, even when the affected equipment is the same.

```sql
corrective_event_comments (
  id uuid primary key,
  corrective_event_id uuid not null references corrective_events(id),
  author_user_id uuid not null references users(id),
  message text not null,
  created_at timestamptz not null default now()
);
```

User profile images can be stored as file/object references. If no uploaded image exists, the app can render a default avatar key.

```sql
user_profiles (
  user_id uuid primary key,
  profile_image_ref text null,
  default_avatar_key text null
);
```

---

## 6. Stages as Rollout Scope

Stage is a rollout/planning dimension. It must not prevent technicians from seeing assets that belong to their project.

Assets and locations can belong to more than one stage over time.

```sql
stages (
  id uuid primary key,
  project_id uuid not null,
  name text not null,
  planned_start_date date null,
  planned_end_date date null,
  operational_status text not null -- PLANNED, ACTIVE, COMPLETED
);

asset_stage_assignments (
  id uuid primary key,
  asset_id uuid not null references assets(id),
  stage_id uuid not null references stages(id),
  role text not null, -- INITIAL_SCOPE, EXPANDED_SCOPE, SHARED, RETIRED
  valid_from date not null,
  valid_to date null
);

location_stage_assignments (
  id uuid primary key,
  location_id uuid not null,
  stage_id uuid not null references stages(id),
  role text not null,
  valid_from date not null,
  valid_to date null
);
```

Examples:

| Item | Stage Assignment |
|------|------------------|
| Estacion Colectora Industrial | Stage 1A |
| Estacion Mercado Santa Anita | Stage 1A |
| Future Stage 1B station | Stage 1B |
| Tren 14 | Stage 1A and Stage 1B with role `SHARED` |

Future imports can be tracked with import batches.

```sql
asset_import_batches (
  id uuid primary key,
  project_id uuid not null,
  stage_id uuid null references stages(id),
  source_name text not null,
  imported_by_user_id uuid not null,
  imported_at timestamptz not null,
  status text not null
);
```
