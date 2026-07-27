import app.models  # noqa: F401
from app.database import Base

SECOND_ROUND_TABLES = {
    "asset_assignments",
    "asset_closure",
    "asset_composition_positions",
    "asset_composition_rules",
    "asset_movements",
    "asset_replacements",
    "asset_stage_assignments",
    "asset_types",
    "attachments",
    "calibration_measurements",
    "calibration_report_details",
    "corrective_activities",
    "corrective_event_comments",
    "corrective_report_blocks",
    "corrective_report_details",
    "data_import_batches",
    "data_import_row_results",
    "documentation_resources",
    "equipment_kind_categories",
    "generated_reports",
    "geographic_locations",
    "inventory_locations",
    "legacy_record_mappings",
    "location_stage_assignments",
    "maintenance_activities",
    "maintenance_activity_assets",
    "maintenance_activity_assignments",
    "maintenance_knowledge_comments",
    "maintenance_plan_entries",
    "maintenance_reopen_records",
    "maintenance_reports",
    "maintenance_status_history",
    "maintenance_template_conclusions",
    "maintenance_template_personnel",
    "maintenance_template_scopes",
    "maintenance_template_steps",
    "maintenance_template_test_options",
    "maintenance_template_tests",
    "maintenance_template_tools",
    "maintenance_templates",
    "preventive_report_details",
    "preventive_step_results",
    "preventive_test_results",
    "report_participants",
    "report_signatures",
    "report_tool_usages",
    "report_version_assets",
    "report_versions",
    "slot_images",
    "slot_locations",
    "tool_certifications",
    "tools",
}


def _foreign_key_targets(table_name: str) -> set[str]:
    return {
        foreign_key.target_fullname
        for foreign_key in Base.metadata.tables[table_name].foreign_keys
    }


def test_second_round_tables_are_registered() -> None:
    assert SECOND_ROUND_TABLES <= set(Base.metadata.tables)


def test_report_versions_are_owned_by_logical_reports() -> None:
    assert _foreign_key_targets("maintenance_reports") >= {"maintenance_activities.id"}
    assert _foreign_key_targets("report_versions") >= {
        "maintenance_reports.id",
        "report_versions.id",
    }
    assert _foreign_key_targets("report_version_assets") >= {
        "report_versions.id",
        "assets.id",
    }


def test_asset_hierarchy_tracks_current_and_historical_positions() -> None:
    assert _foreign_key_targets("slot_locations") >= {
        "equipment_kinds.id",
        "slot_types.id",
        "slot_locations.id",
    }
    assert _foreign_key_targets("asset_assignments") >= {
        "assets.id",
        "slot_locations.id",
        "report_versions.id",
    }
    assert {"ancestor_asset_id", "descendant_asset_id", "depth"} <= set(
        Base.metadata.tables["asset_closure"].columns.keys()
    )


def test_calibration_measurements_support_multiple_equipment_roles() -> None:
    columns = set(Base.metadata.tables["calibration_measurements"].columns.keys())
    assert {
        "report_version_id",
        "asset_id",
        "asset_role",
        "measurement_name",
        "measured_value",
        "sequence",
    } <= columns


def test_import_control_uses_stable_source_keys_and_hashes() -> None:
    mapping_columns = set(Base.metadata.tables["legacy_record_mappings"].columns.keys())
    row_result_columns = set(Base.metadata.tables["data_import_row_results"].columns.keys())

    assert {
        "source_system",
        "source_table",
        "source_primary_key",
        "source_row_hash",
        "target_table",
        "target_record_id",
        "mapping_role",
    } <= mapping_columns
    assert {"source_primary_key", "source_row_hash", "operation", "status"} <= row_result_columns


def test_consumable_tables_remain_deferred() -> None:
    assert {
        "consumable_types",
        "consumable_inventory",
        "work_order_consumables",
    }.isdisjoint(Base.metadata.tables)
