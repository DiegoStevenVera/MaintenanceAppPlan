# Import all SQLAlchemy models so Base.metadata knows the complete schema.
from modules.app_state.infrastructure.postgres import import_models as _import_models  # noqa: F401
from modules.app_state.infrastructure.postgres.models import AppStateSnapshotRecord
from modules.asset_management.infrastructure.postgres import (  # noqa: F401
    domain_models as _asset_domain_models,
)
from modules.asset_management.infrastructure.postgres.catalog_models import (
    AssetStatusRecord,
    EquipmentCategoryRecord,
    EquipmentKindRecord,
    LocationTypeRecord,
    ManufacturerRecord,
    MovementTypeRecord,
    SlotTypeRecord,
)
from modules.asset_management.infrastructure.postgres.models import AssetHistoryRecord, AssetRecord
from modules.identity_access.infrastructure.postgres.models import UserRecord
from modules.maintenance_execution.infrastructure.postgres import (
    report_models as _report_models,  # noqa: F401
)
from modules.maintenance_execution.infrastructure.postgres import (
    template_models as _template_models,  # noqa: F401
)
from modules.maintenance_execution.infrastructure.postgres import (
    tool_models as _tool_models,  # noqa: F401
)
from modules.maintenance_execution.infrastructure.postgres.catalog_models import (
    MaintenanceActionTypeRecord,
)
from modules.maintenance_execution.infrastructure.postgres.models import (
    CorrectiveEventRecord,
    PreventiveScheduleRecord,
)
from modules.organizational_context.infrastructure.postgres import (  # noqa: F401
    operational_models as _organizational_operational_models,
)
from modules.organizational_context.infrastructure.postgres.models import (
    ProjectRecord,
    SiteRecord,
    StageRecord,
    SubsystemRecord,
    SystemRecord,
    WorkAreaRecord,
)

__all__ = [
    "AppStateSnapshotRecord",
    "AssetHistoryRecord",
    "AssetRecord",
    "AssetStatusRecord",
    "CorrectiveEventRecord",
    "EquipmentCategoryRecord",
    "EquipmentKindRecord",
    "LocationTypeRecord",
    "MaintenanceActionTypeRecord",
    "ManufacturerRecord",
    "MovementTypeRecord",
    "PreventiveScheduleRecord",
    "ProjectRecord",
    "SiteRecord",
    "SlotTypeRecord",
    "StageRecord",
    "SubsystemRecord",
    "SystemRecord",
    "UserRecord",
    "WorkAreaRecord",
]
