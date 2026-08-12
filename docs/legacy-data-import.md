# Legacy Excel Data Import

**Status:** Implemented and validated with transactional dry runs  
**Source workbooks:** `WBS_V2.xlsx` and `BD_Storage.xlsx`  
**Database migration head:** `20260730_0010`

## 1. Purpose

The importer migrates the current Power Apps Excel data into the normalized PostgreSQL schema.
It is portable Python code committed with the backend, so the same commands can be run on Windows,
macOS, or the future server after pulling the repository.

The importer does not truncate business tables. It uses deterministic target IDs, source-row
hashes, PostgreSQL upserts, and `legacy_record_mappings` to support repeatable and incremental
executions.

## 2. Prerequisites

1. PostgreSQL is running and the backend `.env` points to the intended database.
2. The Python 3.12 virtual environment is active.
3. Backend dependencies are installed.
4. Alembic is at migration head.

```bash
python -m pip install -e ".[dev]"
alembic upgrade head
alembic check
```

The import runtime requires `openpyxl` and `tzdata`; both are declared backend dependencies.

## 3. Validate the Workbooks

Workbook validation checks required worksheets, source keys, and conflicting duplicate rows. It
does not connect to PostgreSQL.

```bash
python -m legacy_import validate \
  --kind wbs \
  --file ../docs/OldVersionApp/Database/WBS_V2.xlsx

python -m legacy_import validate \
  --kind storage \
  --file ../docs/OldVersionApp/Database/BD_Storage.xlsx
```

Exact duplicate rows with the same source key and content are counted and skipped. Conflicting
rows with the same source key stop validation.

## 4. Mandatory Dry Run

Run both workbooks in dependency order within one transaction:

```bash
python -m legacy_import import-all \
  --wbs-file ../docs/OldVersionApp/Database/WBS_V2.xlsx \
  --storage-file ../docs/OldVersionApp/Database/BD_Storage.xlsx \
  --dry-run \
  --strict
```

`--dry-run` executes transformations and PostgreSQL constraints and then rolls back. `--strict`
also returns a non-zero exit code when any row fails.

The validated source snapshot produced:

| Source | Rows | Failed |
|---|---:|---:|
| WBS master data | 3,136 | 0 |
| Operational storage | 27,131 | 0 |

## 5. Initial Import

After reviewing a successful dry-run summary, remove only `--dry-run`:

```bash
python -m legacy_import import-all \
  --wbs-file ../docs/OldVersionApp/Database/WBS_V2.xlsx \
  --storage-file ../docs/OldVersionApp/Database/BD_Storage.xlsx \
  --strict
```

The command commits WBS and operational data together. If any source row fails, `--strict` rolls
back the complete run.

## 6. Incremental Imports

For regular refreshes of `BD_Storage.xlsx`, import only the operational workbook:

```bash
python -m legacy_import import-storage \
  --file ../docs/OldVersionApp/Database/BD_Storage.xlsx \
  --all \
  --dry-run \
  --strict
```

After validation, rerun without `--dry-run`. Rows whose stored source hash has not changed are
reported as `unchanged`. New source keys are inserted and changed source keys are updated. This
avoids deleting the PostgreSQL tables and allows records added after the previous migration to be
processed safely.

Use `--force` only when transformation logic changed and every source row must be reprocessed even
when the Excel values are unchanged.

## 7. Focused Commands

One supported source sheet can be processed for diagnosis:

```bash
python -m legacy_import import-wbs \
  --file ../docs/OldVersionApp/Database/WBS_V2.xlsx \
  --table tbl_Component \
  --dry-run

python -m legacy_import import-storage \
  --file ../docs/OldVersionApp/Database/BD_Storage.xlsx \
  --table Maintenance_Storage \
  --dry-run
```

Focused commands assume their dependency data already exists in PostgreSQL. Use `import-all` for a
new database.

## 8. Auditing

```sql
SELECT *
FROM data_import_batches
ORDER BY started_at DESC;

SELECT source_table, operation, status, count(*)
FROM data_import_row_results
GROUP BY source_table, operation, status
ORDER BY source_table, operation, status;

SELECT source_table, source_primary_key, target_table, mapping_role, target_record_id
FROM legacy_record_mappings
ORDER BY source_table, source_primary_key, target_table, mapping_role;
```

Dry-run audit rows are rolled back with the rest of the transaction. Committed runs retain batch,
row-result, source hash, and source-to-target mapping records.

## 9. Legacy Data Decisions

- Repeated `Maintenance_Storage` rows for one scheduled activity become versions of one logical
  preventive report.
- PDF and XLSX calibration files attach to the same calibration report version.
- Transmitter and receiver measurements remain separate ordered rows.
- Components without a mapped component type use the Spanish business value
  `Componente no tipificado`; their source mapping remains auditable.
- A component's immediate parent is the component occupying its nearest ancestor slot in the same
  inventory location. When no ancestor slot is occupied, the related large equipment remains the
  parent. This keeps the asset hierarchy aligned with the independent `slot_locations` hierarchy.
- Duplicate source serial numbers are not accepted as unique serial identities. They remain in the
  legacy display value and use `REQUIRES_VERIFICATION`.
- Historical tasks or parent rows missing from the current workbook are reconstructed with an
  explicit Spanish warning.
- Files whose maintenance row is absent are retained under a report named
  `Registro histórico incompleto ...`.
- Consumable sheets remain deferred.

## 10. Database Transfer

Alembic transfers schema changes, while the importer transfers Excel business data. For moving an
already populated PostgreSQL environment exactly as-is, use PostgreSQL `pg_dump` and `pg_restore`.
Do not use Alembic as a data-copy mechanism.

For the Mac and future server, the recommended clean process is:

1. Pull the same Git revision.
2. Configure `.env`.
3. Run `alembic upgrade head`.
4. Run the strict combined dry run.
5. Run the strict combined import.
6. Review the audit queries and business row counts.
