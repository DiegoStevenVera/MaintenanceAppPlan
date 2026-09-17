from legacy_import.tool_inventory import _classification_code
from modules.maintenance_execution.interfaces.tool_admin_router import (
    _catalog_category_for_inventory,
)


def test_inventory_classification_is_the_only_checklist_grouping_source() -> None:
    assert _catalog_category_for_inventory("HERRAMIENTA MANUAL") == "MANUAL_TOOL"
    assert _catalog_category_for_inventory("LLAVE") == "ACCESS_KEY"
    assert _catalog_category_for_inventory("CONSUMIBLE") == "CONSUMABLE"
    assert _catalog_category_for_inventory("EQUIPO") == "EQUIPMENT"


def test_import_classification_matches_admin_classification() -> None:
    values = {
        "HERRAMIENTA MANUAL": "MANUAL_TOOL",
        "LLAVE": "ACCESS_KEY",
        "CONSUMIBLE": "CONSUMABLE",
        "EQUIPO": "EQUIPMENT",
    }

    for classification, expected in values.items():
        assert _classification_code(classification) == expected
        assert _catalog_category_for_inventory(classification) == expected
