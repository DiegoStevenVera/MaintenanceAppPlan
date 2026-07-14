# Import all SQLAlchemy models so Base.metadata knows the complete schema.
from modules.app_state.infrastructure.postgres.models import AppStateSnapshotRecord
from modules.asset_management.infrastructure.postgres.models import AssetHistoryRecord, AssetRecord
from modules.identity_access.infrastructure.postgres.models import UserRecord
from modules.maintenance_execution.infrastructure.postgres.models import (
    CorrectiveEventRecord,
    PreventiveScheduleRecord,
)

__all__ = [
    "AssetHistoryRecord",
    "AssetRecord",
    "AppStateSnapshotRecord",
    "CorrectiveEventRecord",
    "PreventiveScheduleRecord",
    "UserRecord",
]
