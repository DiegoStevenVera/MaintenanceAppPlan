from collections import defaultdict
from collections.abc import Awaitable, Callable, Sequence
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from uuid import UUID, uuid4

from sqlalchemy import Table, func, select, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

import app.models  # noqa: F401
from app.database import Base
from legacy_import.ids import stable_uuid
from legacy_import.values import json_value
from legacy_import.workbook import SourceRow

SOURCE_SYSTEM = "POWER_APPS_EXCEL"


@dataclass(frozen=True)
class MappingTarget:
    table: str
    record_id: str
    role: str = "PRIMARY"


@dataclass
class ImportStats:
    total: int = 0
    inserted: int = 0
    updated: int = 0
    unchanged: int = 0
    failed: int = 0

    def as_dict(self) -> dict[str, int]:
        return {
            "total": self.total,
            "inserted": self.inserted,
            "updated": self.updated,
            "unchanged": self.unchanged,
            "failed": self.failed,
        }


RowHandler = Callable[[SourceRow], Awaitable[Sequence[MappingTarget]]]


class ImportContext:
    def __init__(
        self,
        session: AsyncSession,
        *,
        source_file: Path,
        source_checksum: str,
        import_mode: str,
        dry_run: bool,
        force: bool = False,
    ) -> None:
        self.session = session
        self.source_file = source_file.resolve()
        self.source_checksum = source_checksum
        self.import_mode = import_mode
        self.dry_run = dry_run
        self.force = force
        self.batch_id: UUID = uuid4()
        self.stats = ImportStats()
        self.sheet_stats: dict[str, ImportStats] = {}
        self.error_samples: list[dict[str, Any]] = []
        self._error_sample_counts: dict[str, int] = defaultdict(int)
        self._mapping_cache: dict[
            str,
            dict[str, list[dict[str, Any]]],
        ] = {}

    @property
    def tables(self) -> dict[str, Table]:
        return Base.metadata.tables

    async def start(self) -> None:
        batches = self.tables["data_import_batches"]
        now = datetime.now(UTC)
        await self.session.execute(
            batches.insert().values(
                id=self.batch_id,
                project_id=None,
                stage_id=None,
                source_system=SOURCE_SYSTEM,
                source_file_name=self.source_file.name,
                source_file_checksum=self.source_checksum,
                import_mode=self.import_mode,
                status="RUNNING",
                started_at=now,
                completed_at=None,
                imported_by_user_id=None,
                total_rows=0,
                inserted_rows=0,
                updated_rows=0,
                unchanged_rows=0,
                failed_rows=0,
                summary=None,
            )
        )

    async def finish(self) -> None:
        status = "DRY_RUN" if self.dry_run else ("COMPLETED_WITH_ERRORS" if self.stats.failed else "COMPLETED")
        batches = self.tables["data_import_batches"]
        await self.session.execute(
            update(batches)
            .where(batches.c.id == self.batch_id)
            .values(
                status=status,
                completed_at=datetime.now(UTC),
                total_rows=self.stats.total,
                inserted_rows=self.stats.inserted,
                updated_rows=self.stats.updated,
                unchanged_rows=self.stats.unchanged,
                failed_rows=self.stats.failed,
                summary={
                    "dry_run": self.dry_run,
                    "sheets": {
                        name: stats.as_dict()
                        for name, stats in sorted(self.sheet_stats.items())
                    },
                },
            )
        )

    async def process_rows(
        self,
        sheet_name: str,
        rows: Sequence[SourceRow],
        handler: RowHandler,
    ) -> ImportStats:
        await self._load_mapping_cache(sheet_name)
        sheet_stats = ImportStats()
        self.sheet_stats[sheet_name] = sheet_stats

        for row in rows:
            self.stats.total += 1
            sheet_stats.total += 1
            existing = self._mapping_cache[sheet_name].get(row.key, [])
            if (
                not self.force
                and existing
                and all(item["source_row_hash"] == row.row_hash for item in existing)
            ):
                self.stats.unchanged += 1
                sheet_stats.unchanged += 1
                await self._record_row_result(row, operation="UNCHANGED", status="SUCCESS")
                continue

            operation = "UPDATE" if existing else "INSERT"
            savepoint = await self.session.begin_nested()
            try:
                targets = list(await handler(row))
                if not targets:
                    raise ValueError("Importer did not produce a target mapping")
                for target in targets:
                    await self._record_mapping(row, target)
                await savepoint.commit()
            except Exception as error:  # noqa: BLE001 - row failures are quarantined
                await savepoint.rollback()
                self.stats.failed += 1
                sheet_stats.failed += 1
                if (
                    len(self.error_samples) < 100
                    and self._error_sample_counts[row.sheet] < 3
                ):
                    self.error_samples.append(
                        {
                            "sheet": row.sheet,
                            "row_number": row.row_number,
                            "source_key": row.key,
                            "error": f"{type(error).__name__}: {error}",
                        }
                    )
                    self._error_sample_counts[row.sheet] += 1
                await self._record_row_result(
                    row,
                    operation=operation,
                    status="FAILED",
                    error=error,
                )
                continue

            if operation == "INSERT":
                self.stats.inserted += 1
                sheet_stats.inserted += 1
            else:
                self.stats.updated += 1
                sheet_stats.updated += 1
            await self._record_row_result(
                row,
                operation=operation,
                status="SUCCESS",
                target=targets[0],
            )

        return sheet_stats

    async def upsert(
        self,
        table_name: str,
        values: dict[str, Any],
        *,
        conflict_columns: Sequence[str] = ("id",),
        update_columns: Sequence[str] | None = None,
    ) -> None:
        table = self.tables[table_name]
        payload = dict(values)
        statement = pg_insert(table).values(**payload)
        if update_columns is None:
            update_columns = tuple(
                key
                for key in payload
                if key not in set(conflict_columns) | {"created_at"}
            )
        updates = {
            column: getattr(statement.excluded, column)
            for column in update_columns
            if column in table.c
        }
        if "updated_at" in table.c:
            updates["updated_at"] = func.now()
        if updates:
            statement = statement.on_conflict_do_update(
                index_elements=list(conflict_columns),
                set_=updates,
            )
        else:
            statement = statement.on_conflict_do_nothing(
                index_elements=list(conflict_columns)
            )
        await self.session.execute(statement)

    async def scalar_id(
        self,
        table_name: str,
        *,
        column: str,
        value: Any,
    ) -> Any | None:
        table = self.tables[table_name]
        return await self.session.scalar(select(table.c.id).where(table.c[column] == value))

    async def mapped_target_id(
        self,
        *,
        source_table: str,
        source_key: Any,
        target_table: str,
        role: str = "PRIMARY",
    ) -> str | None:
        mappings = self.tables["legacy_record_mappings"]
        return await self.session.scalar(
            select(mappings.c.target_record_id).where(
                mappings.c.source_system == SOURCE_SYSTEM,
                mappings.c.source_table == source_table,
                mappings.c.source_primary_key == str(source_key),
                mappings.c.target_table == target_table,
                mappings.c.mapping_role == role,
            )
        )

    async def _load_mapping_cache(self, sheet_name: str) -> None:
        if sheet_name in self._mapping_cache:
            return
        mappings = self.tables["legacy_record_mappings"]
        result = await self.session.execute(
            select(mappings).where(
                mappings.c.source_system == SOURCE_SYSTEM,
                mappings.c.source_table == sheet_name,
            )
        )
        cache: dict[str, list[dict[str, Any]]] = defaultdict(list)
        for row in result.mappings():
            cache[row["source_primary_key"]].append(dict(row))
        self._mapping_cache[sheet_name] = dict(cache)

    async def _record_mapping(self, row: SourceRow, target: MappingTarget) -> None:
        mappings = self.tables["legacy_record_mappings"]
        now = datetime.now(UTC)
        mapping_id = stable_uuid(
            SOURCE_SYSTEM,
            row.sheet,
            row.key,
            target.table,
            target.role,
        )
        statement = pg_insert(mappings).values(
            id=mapping_id,
            source_system=SOURCE_SYSTEM,
            source_table=row.sheet,
            source_primary_key=row.key,
            source_row_hash=row.row_hash,
            target_table=target.table,
            target_record_id=target.record_id,
            mapping_role=target.role,
            first_import_batch_id=self.batch_id,
            last_import_batch_id=self.batch_id,
            last_seen_at=now,
        )
        statement = statement.on_conflict_do_update(
            constraint="uq_legacy_record_mappings_source_target_role",
            set_={
                "source_row_hash": statement.excluded.source_row_hash,
                "target_record_id": statement.excluded.target_record_id,
                "last_import_batch_id": statement.excluded.last_import_batch_id,
                "last_seen_at": statement.excluded.last_seen_at,
                "updated_at": func.now(),
            },
        )
        await self.session.execute(statement)
        cached = {
            "source_row_hash": row.row_hash,
            "target_table": target.table,
            "target_record_id": target.record_id,
            "mapping_role": target.role,
        }
        sheet_cache = self._mapping_cache.setdefault(row.sheet, {})
        items = sheet_cache.setdefault(row.key, [])
        items[:] = [
            item
            for item in items
            if not (
                item["target_table"] == target.table
                and item.get("mapping_role", "PRIMARY") == target.role
            )
        ]
        items.append(cached)

    async def _record_row_result(
        self,
        row: SourceRow,
        *,
        operation: str,
        status: str,
        target: MappingTarget | None = None,
        error: Exception | None = None,
    ) -> None:
        await self.upsert(
            "data_import_row_results",
            {
                "id": stable_uuid(self.batch_id, row.sheet, row.key),
                "import_batch_id": self.batch_id,
                "source_table": row.sheet,
                "source_primary_key": row.key,
                "source_row_hash": row.row_hash,
                "operation": operation,
                "status": status,
                "target_table": target.table if target else None,
                "target_record_id": target.record_id if target else None,
                "error_code": type(error).__name__ if error else None,
                "error_message": str(error)[:4000] if error else None,
                "source_payload": {
                    key: json_value(value)
                    for key, value in row.values.items()
                },
            },
            conflict_columns=(
                "import_batch_id",
                "source_table",
                "source_primary_key",
            ),
        )
