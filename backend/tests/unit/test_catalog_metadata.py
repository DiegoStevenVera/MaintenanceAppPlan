import app.models  # noqa: F401
from app.database import Base

CATALOG_TABLES = {
    "asset_statuses",
    "equipment_categories",
    "equipment_kinds",
    "location_types",
    "maintenance_action_types",
    "manufacturers",
    "movement_types",
    "projects",
    "sites",
    "slot_types",
    "stages",
    "subsystems",
    "systems",
    "work_areas",
}


def test_foundational_catalogs_are_registered() -> None:
    assert CATALOG_TABLES <= set(Base.metadata.tables)


def test_catalogs_include_import_and_audit_columns() -> None:
    for table_name in CATALOG_TABLES:
        columns = set(Base.metadata.tables[table_name].columns.keys())
        assert {"id", "legacy_id", "is_active", "created_at", "updated_at"} <= columns


def test_organizational_foreign_keys_follow_the_expected_scope() -> None:
    expected_foreign_keys = {
        "projects": {"sites.id"},
        "stages": {"projects.id"},
        "systems": {"projects.id"},
        "subsystems": {"systems.id"},
        "equipment_categories": {"subsystems.id"},
    }

    for table_name, expected_targets in expected_foreign_keys.items():
        actual_targets = {
            foreign_key.target_fullname
            for foreign_key in Base.metadata.tables[table_name].foreign_keys
        }
        assert actual_targets == expected_targets
