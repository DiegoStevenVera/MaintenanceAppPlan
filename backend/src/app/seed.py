import asyncio

from sqlalchemy import delete, func, select

import app.models  # noqa: F401
from app.app_state_seed import build_app_state
from app.database import Base, async_session_factory, engine
from modules.app_state.infrastructure.postgres.repository import PostgresAppStateRepository
from modules.identity_access.application.security import hash_password
from modules.asset_management.infrastructure.postgres.models import (
    AssetHistoryRecord,
    AssetRecord,
)
from modules.identity_access.infrastructure.postgres.models import UserRecord
from modules.maintenance_execution.infrastructure.postgres.models import (
    CorrectiveEventRecord,
    PreventiveScheduleRecord,
)


async def create_schema() -> None:
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)


async def seed_database() -> None:
    await create_schema()
    app_state = build_app_state()

    async with async_session_factory() as session:
        await session.execute(delete(AssetHistoryRecord))
        await session.execute(delete(CorrectiveEventRecord))
        await session.execute(delete(PreventiveScheduleRecord))
        await session.execute(delete(AssetRecord))
        await session.execute(delete(UserRecord))

        await PostgresAppStateRepository(session).upsert_current(app_state)

        for user in app_state["loginUsers"]:
            await session.merge(
                UserRecord(
                    id=user["id"],
                    name=user["name"],
                    email=user["email"],
                    role=_role_to_backend(user["role"]),
                    role_label=_role_label(user["role"]),
                    password_hash=hash_password("123456"),
                )
            )

        for asset in app_state["assets"]:
            await session.merge(
                AssetRecord(
                    id=asset["id"],
                    name=asset["name"],
                    category=asset["category"],
                    asset_type=asset["type"],
                    subsystem=_infer_subsystem(asset["type"], asset["name"]),
                    serial_or_code=asset["serialOrCode"],
                    part_number=asset["partNumber"],
                    status=asset["status"],
                    physical_location=asset["location"],
                    is_business_anchor=asset["isBusinessAnchor"],
                    parent_id=asset["parent"],
                    children=asset["children"],
                )
            )
        for report in app_state["historicalReports"]:
            asset = next(
                (item for item in app_state["assets"] if item["name"] == report["equipmentName"]),
                None,
            )
            if asset is not None:
                await session.merge(
                    AssetHistoryRecord(
                        id=report["id"],
                        asset_id=asset["id"],
                        report_type="preventive",
                        report_id=report["id"],
                        title=report["activityName"],
                        performed_at=report["performedAt"],
                        result=report["result"],
                    )
                )

        for schedule in app_state["activities"]:
            await session.merge(
                PreventiveScheduleRecord(
                    id=schedule["id"],
                    name=schedule["name"],
                    template_name=schedule["templateName"],
                    asset_ids=_asset_ids_for_names(app_state["assets"], schedule["assets"]),
                    asset_names=schedule["assets"],
                    subsystem=schedule["subsystem"],
                    scheduled_at=schedule["scheduledDate"],
                    status=_status_to_backend(schedule["status"]),
                    physical_location=schedule["locationPath"],
                    report_version_count=len(schedule["reportVersions"]),
                )
            )

        for event in app_state["correctiveEvents"]:
            await session.merge(
                CorrectiveEventRecord(
                    id=event["id"],
                    code=event["code"],
                    sap_code=event["sapCode"],
                    name=event["name"],
                    affected_asset_id=_asset_id_for_name(app_state["assets"], event["affectedAsset"]),
                    affected_asset_path=event["affectedAsset"],
                    subsystem=event["subsystem"],
                    severity=event["severity"].upper(),
                    status=_status_to_backend(event["status"]),
                    notice_created_at=event["noticeCreatedAt"],
                    response_at=event["responseAt"],
                    physical_location=event["location"],
                    report_version_count=len(event["reportVersions"]),
                    timeline=[
                        {
                            "id": item["id"],
                            "occurred_at": event["noticeCreatedAt"],
                            "text": item["text"],
                        }
                        for item in event["timeline"]
                    ],
                )
            )

        await session.commit()

        user_count = await session.scalar(select(func.count(UserRecord.id)))
        asset_count = await session.scalar(select(func.count(AssetRecord.id)))
        schedule_count = await session.scalar(select(func.count(PreventiveScheduleRecord.id)))
        corrective_count = await session.scalar(select(func.count(CorrectiveEventRecord.id)))

    print(
        "Seed completed: "
        f"{user_count} users, {asset_count} assets, "
        f"{schedule_count} preventive schedules, {corrective_count} corrective events."
    )


def _role_to_backend(role: str) -> str:
    return {
        "maintenanceEngineer": "MAINTENANCE_ENGINEER",
        "coordinator": "COORDINATOR",
        "boss": "BOSS",
        "administrator": "ADMINISTRATOR",
    }[role]


def _role_label(role: str) -> str:
    return {
        "maintenanceEngineer": "Ingeniero de Mantenimiento de Sistemas de Señalización",
        "coordinator": "Coordinador",
        "boss": "Jefe",
        "administrator": "Administrador",
    }[role]


def _status_to_backend(status: str) -> str:
    return {
        "scheduled": "SCHEDULED",
        "inProgress": "IN_PROGRESS",
        "completed": "COMPLETED",
        "closed": "CLOSED",
    }[status]


def _infer_subsystem(asset_type: str, name: str) -> str:
    folded = f"{asset_type} {name}".lower()
    if any(token in folded for token in ["ats", "lim", "crk", "erk", "simulador"]):
        return "ATS"
    if any(token in folded for token in ["frontam", "zc", "tren"]):
        return "CBTC"
    return "IXL"


def _asset_id_for_name(assets: list[dict], name: str) -> str | None:
    match = next((asset for asset in assets if asset["name"] == name), None)
    return match["id"] if match else None


def _asset_ids_for_names(assets: list[dict], names: list[str]) -> list[str]:
    return [asset_id for name in names if (asset_id := _asset_id_for_name(assets, name))]


def main() -> None:
    asyncio.run(seed_database())


if __name__ == "__main__":
    main()
