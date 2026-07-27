import argparse
import asyncio
import json
import sys
from pathlib import Path
from typing import Any

from app.database import async_session_factory
from legacy_import.context import ImportContext
from legacy_import.storage import STORAGE_SHEETS, StorageImporter
from legacy_import.wbs import WBS_SHEETS, WBSImporter
from legacy_import.workbook import LegacyWorkbook


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="legacy_import",
        description="Import the legacy Power Apps Excel data into PostgreSQL.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    wbs = subparsers.add_parser("import-wbs", help="Import WBS_V2 master data.")
    _add_import_options(wbs, table_choices=sorted(WBS_SHEETS))

    storage = subparsers.add_parser(
        "import-storage",
        help="Import BD_Storage transactional data.",
    )
    _add_import_options(storage, table_choices=sorted(STORAGE_SHEETS))

    all_data = subparsers.add_parser(
        "import-all",
        help="Import WBS_V2 and BD_Storage in one transaction.",
    )
    all_data.add_argument("--wbs-file", required=True, type=Path)
    all_data.add_argument("--storage-file", required=True, type=Path)
    _add_common_run_options(all_data)

    validate = subparsers.add_parser(
        "validate",
        help="Validate workbook sheets, keys, and duplicate rows without PostgreSQL writes.",
    )
    validate.add_argument("--file", required=True, type=Path)
    validate.add_argument("--kind", choices=("wbs", "storage"), required=True)
    return parser


def _add_import_options(
    parser: argparse.ArgumentParser,
    *,
    table_choices: list[str],
) -> None:
    parser.add_argument("--file", required=True, type=Path)
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument("--table", choices=table_choices)
    selection.add_argument(
        "--all",
        action="store_true",
        help="Import every supported sheet in dependency order.",
    )
    _add_common_run_options(parser)


def _add_common_run_options(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Execute all transformations and database constraints, then roll back.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Reprocess rows even when the stored source hash has not changed.",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Roll back the complete run when any source row fails.",
    )


async def run_import(args: argparse.Namespace) -> int:
    async with async_session_factory() as session:
        transaction = await session.begin()
        contexts: list[ImportContext] = []
        try:
            if args.command == "import-wbs":
                workbook = LegacyWorkbook(args.file)
                context = ImportContext(
                    session,
                    source_file=workbook.path,
                    source_checksum=workbook.file_checksum,
                    import_mode="WBS_MASTER",
                    dry_run=args.dry_run,
                    force=args.force,
                )
                contexts.append(context)
                await context.start()
                await WBSImporter(workbook, context).run(args.table)
                await context.finish()
            elif args.command == "import-storage":
                workbook = LegacyWorkbook(args.file)
                context = ImportContext(
                    session,
                    source_file=workbook.path,
                    source_checksum=workbook.file_checksum,
                    import_mode="STORAGE_INCREMENTAL",
                    dry_run=args.dry_run,
                    force=args.force,
                )
                contexts.append(context)
                await context.start()
                await StorageImporter(workbook, context).run(args.table)
                await context.finish()
            elif args.command == "import-all":
                wbs_workbook = LegacyWorkbook(args.wbs_file)
                wbs_context = ImportContext(
                    session,
                    source_file=wbs_workbook.path,
                    source_checksum=wbs_workbook.file_checksum,
                    import_mode="WBS_MASTER",
                    dry_run=args.dry_run,
                    force=args.force,
                )
                contexts.append(wbs_context)
                await wbs_context.start()
                await WBSImporter(wbs_workbook, wbs_context).run()
                await wbs_context.finish()

                storage_workbook = LegacyWorkbook(args.storage_file)
                storage_context = ImportContext(
                    session,
                    source_file=storage_workbook.path,
                    source_checksum=storage_workbook.file_checksum,
                    import_mode="STORAGE_INCREMENTAL",
                    dry_run=args.dry_run,
                    force=args.force,
                )
                contexts.append(storage_context)
                await storage_context.start()
                await StorageImporter(storage_workbook, storage_context).run()
                await storage_context.finish()

            failed = sum(context.stats.failed for context in contexts)
            if args.strict and failed:
                if transaction.is_active:
                    await transaction.rollback()
                _print_summary(contexts, rolled_back=True)
                return 1
            if args.dry_run:
                if transaction.is_active:
                    await transaction.rollback()
            else:
                if transaction.is_active:
                    await transaction.commit()
            _print_summary(contexts, rolled_back=args.dry_run)
            return 0 if not failed else 2
        except Exception:
            if transaction.is_active:
                await transaction.rollback()
            raise


def validate_workbook(args: argparse.Namespace) -> int:
    workbook = LegacyWorkbook(args.file)
    sheets = WBS_SHEETS if args.kind == "wbs" else STORAGE_SHEETS
    summary: dict[str, Any] = {}
    for sheet_name, key_column in sheets.items():
        rows = workbook.rows(sheet_name, key_column=key_column)
        summary[sheet_name] = {
            "rows": len(rows),
            "identical_duplicates_skipped": workbook.duplicate_counts.get(
                sheet_name,
                0,
            ),
        }
    print(
        json.dumps(
            {
                "file": str(workbook.path),
                "checksum": workbook.file_checksum,
                "sheets": summary,
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


def _print_summary(
    contexts: list[ImportContext],
    *,
    rolled_back: bool,
) -> None:
    payload = {
        "rolled_back": rolled_back,
        "runs": [
            {
                "batch_id": str(context.batch_id),
                "source_file": str(context.source_file),
                "mode": context.import_mode,
                **context.stats.as_dict(),
                "sheets": {
                    name: stats.as_dict()
                    for name, stats in sorted(context.sheet_stats.items())
                },
                "error_samples": context.error_samples,
            }
            for context in contexts
        ],
    }
    print(json.dumps(payload, ensure_ascii=False, indent=2))


def main(argv: list[str] | None = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.command == "validate":
        return validate_workbook(args)
    return asyncio.run(run_import(args))
