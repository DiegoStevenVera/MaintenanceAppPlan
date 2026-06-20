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
  current_parent_asset_id uuid null references assets(id),
  current_position text null,
  current_location_id uuid null,
  created_at timestamptz not null,
  updated_at timestamptz not null
);
```

Examples:

| Asset | Category | Business Anchor? |
|-------|----------|------------------|
| Tren 14 | LARGE_EQUIPMENT | Yes |
| Zone Controller 2 | LARGE_EQUIPMENT | Yes |
| Gabinete Frontam Patio | LARGE_EQUIPMENT | Yes |
| LIMSYS001 | EQUIPMENT | Yes, if users report metrics at server level |
| Tarjeta CIER 1 | COMPONENT | No, unless the business needs direct reliability metrics |
| Software ATS Patio | LOGICAL | Yes |

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

## 5. Stages as Rollout Scope

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

