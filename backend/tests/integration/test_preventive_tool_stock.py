"""Run against a disposable migrated PostgreSQL, never the business database."""

import asyncio
import os
from datetime import date, timedelta
from decimal import Decimal
from uuid import UUID, uuid4

import pytest
from fastapi import HTTPException
from sqlalchemy import select

pytestmark = pytest.mark.skipif(
    os.getenv("TEST_TOOL_ADMIN_DB") != "1", reason="Requires disposable PostgreSQL"
)


def test_preventive_start_and_completion_move_only_automatic_stock() -> None:
    asyncio.run(_workflow())


async def _workflow() -> None:
    import app.models  # noqa: F401
    from app.database import async_session_factory, engine
    from modules.asset_management.infrastructure.postgres.catalog_models import LocationTypeRecord
    from modules.asset_management.infrastructure.postgres.domain_models import InventoryLocationRecord
    from modules.identity_access.infrastructure.postgres.models import UserRecord
    from modules.identity_access.interfaces.schemas import UserDTO
    from modules.maintenance_execution.application.lifecycle import MaintenanceLifecycleCommand
    from modules.maintenance_execution.infrastructure.postgres.report_models import (
        MaintenanceActivityRecord,
        MaintenanceReportRecord,
        ReportVersionRecord,
    )
    from modules.maintenance_execution.infrastructure.postgres.template_models import (
        MaintenanceTemplateRecord,
    )
    from modules.maintenance_execution.infrastructure.postgres.tool_inventory_item_models import (
        ToolInventoryItemRecord,
    )
    from modules.maintenance_execution.infrastructure.postgres.tool_inventory_models import (
        ToolInventoryRecord,
        ToolMovementRecord,
    )
    from modules.maintenance_execution.infrastructure.postgres.tool_models import (
        OperationalChecklistItemRecord,
        OperationalChecklistRevisionRecord,
        ToolCatalogItemRecord,
        ToolCertificationRecord,
    )
    from modules.maintenance_execution.interfaces import tool_admin_router as tools
    from modules.maintenance_execution.interfaces.router import _transition_maintenance_activity
    from modules.organizational_context.infrastructure.postgres.models import (
        ProjectRecord,
        SiteRecord,
        SubsystemRecord,
        SystemRecord,
    )
    from shared_kernel.schemas import UserRole

    suffix = uuid4().hex
    engineer = UserDTO(
        id=suffix, name="Ingeniero", email=f"{suffix}@example.test",
        role=UserRole.MAINTENANCE_ENGINEER, role_label="Ingeniero",
    )
    admin = engineer.model_copy(update={"role": UserRole.ADMINISTRATOR})
    try:
        async with async_session_factory() as session:
            session.add(UserRecord(
                id=engineer.id, name=engineer.name, email=engineer.email, role=engineer.role.value,
                role_label=engineer.role_label, password_hash="disabled", is_active=True,
            ))
            site = SiteRecord(id=uuid4(), name=suffix)
            session.add(site)
            await session.flush()
            project = ProjectRecord(id=uuid4(), name=suffix, site_id=site.id)
            session.add(project)
            await session.flush()
            system = SystemRecord(id=uuid4(), name=suffix, project_id=project.id)
            session.add(system)
            await session.flush()
            subsystem = SubsystemRecord(id=uuid4(), name=suffix, code=suffix, system_id=system.id)
            session.add(subsystem)
            await session.flush()
            template = MaintenanceTemplateRecord(
                id=uuid4(), report_code=suffix, subsystem_id=subsystem.id, activity_n1="Preventivo",
            )
            location_type = await session.scalar(select(LocationTypeRecord).where(
                LocationTypeRecord.code == "ALMACENAMIENTO"
            ))
            if location_type is None:
                location_type = LocationTypeRecord(
                    id=uuid4(), code="ALMACENAMIENTO", name="Almacenamiento", is_active=True,
                )
                session.add(location_type)
                await session.flush()
            warehouse_id = uuid4()
            session.add_all([template, InventoryLocationRecord(
                id=warehouse_id, name=f"Almacén {suffix}", location_type_id=location_type.id,
            )])
            await session.flush()
            activity_id = uuid4()
            revision = OperationalChecklistRevisionRecord(
                id=uuid4(), maintenance_template_id=template.id, revision_number=1,
            )
            session.add_all([
                revision,
                MaintenanceActivityRecord(
                    id=activity_id, activity_type="PREVENTIVE", status="SCHEDULED",
                    project_id=project.id, subsystem_id=subsystem.id,
                    maintenance_template_id=template.id, title="Preventivo", internal_code=suffix,
                ),
            ])
            await session.commit()
            revision_id, template_id = revision.id, template.id
            project_id, subsystem_id = project.id, subsystem.id
            bulk_name, meter_name = f"Paños {suffix}", f"Medidor {suffix}"
            item_id = UUID((await tools.create_inventory_item(tools.InventoryItemWrite(
                name=bulk_name, quantity=5, classification="CONSUMIBLE",
                inventory_location_id=warehouse_id,
            ), session))["id"])
            bulk = await session.get(ToolInventoryItemRecord, item_id)
            meter = ToolCatalogItemRecord(
                id=uuid4(), name=meter_name, category="EQUIPMENT", requires_identified_unit=True,
            )
            session.add(meter)
            await session.flush()
            for catalog_id, name, category, quantity, sequence in [
                (bulk.catalog_item_id, bulk_name, "CONSUMABLE", 4, 1),
                (meter.id, meter_name, "EQUIPMENT", None, 2),
            ]:
                session.add(OperationalChecklistItemRecord(
                    checklist_revision_id=revision_id, catalog_item_id=catalog_id, item_name=name,
                    category=category, default_quantity=quantity, sequence=sequence,
                ))
            await session.commit()
            manual = tools.InventoryIssueWrite(
                id=uuid4(), quantity=1, responsible_user_id=engineer.id, activity_ids=[activity_id],
            )
            await tools.issue_inventory_item(item_id, manual, admin, session)

            async def transition(command):
                return await _transition_maintenance_activity(
                    activity_id=str(activity_id), command=command, current_user=engineer,
                    session=session,
                )

            async def automatic(kind):
                return (await session.scalars(select(ToolMovementRecord).where(
                    ToolMovementRecord.automatic_activity_id == activity_id,
                    ToolMovementRecord.kind == kind,
                ))).all()

            async def bulk_stock():
                return await session.scalar(select(ToolInventoryRecord).where(
                    ToolInventoryRecord.inventory_item_id == item_id,
                ).execution_options(populate_existing=True))

            with pytest.raises(HTTPException) as no_stock:
                await transition(MaintenanceLifecycleCommand.START)
            assert no_stock.value.status_code == 409 and meter_name in no_stock.value.detail
            assert (await session.get(MaintenanceActivityRecord, activity_id)).status == "SCHEDULED"
            assert (await bulk_stock()).available == 4 and not await automatic("ISSUE")

            meter_item = UUID((await tools.create_inventory_item(tools.InventoryItemWrite(
                name=meter_name, quantity=1, classification="EQUIPO", tool_code=suffix,
                inventory_location_id=warehouse_id,
            ), session))["id"])
            meter_tool_id = (await session.get(ToolInventoryItemRecord, meter_item)).tool_id
            today = date.today()
            session.add(ToolCertificationRecord(
                tool_id=meter_tool_id, calibration_company="Laboratorio", certification_number=suffix,
                calibration_date=today - timedelta(days=1), validity_days=365,
                next_calibration_date=today + timedelta(days=364), is_active=True,
            ))
            await session.commit()
            assert (await transition(MaintenanceLifecycleCommand.START)).status == "IN_PROGRESS"
            issued = await automatic("ISSUE")
            assert sorted(row.quantity for row in issued) == [1, 3]
            assert all(row.responsible_user_id == engineer.id for row in issued)
            assert (await bulk_stock()).available == 1
            with pytest.raises(HTTPException) as repeat:
                await transition(MaintenanceLifecycleCommand.START)
            assert repeat.value.status_code == 409
            assert len(await automatic("ISSUE")) == 2

            with pytest.raises(HTTPException) as no_report:
                await transition(MaintenanceLifecycleCommand.COMPLETE)
            assert no_report.value.status_code == 422 and not await automatic("RETURN")
            report = MaintenanceReportRecord(
                id=uuid4(), maintenance_activity_id=activity_id, report_kind="PREVENTIVE",
                status="FINALIZED", created_by_user_id=engineer.id,
            )
            session.add(report)
            await session.flush()
            session.add(ReportVersionRecord(
                maintenance_report_id=report.id, version_number=1, document_status="FINALIZED",
                created_by_user_id=engineer.id,
            ))
            await session.commit()
            assert (await bulk_stock()).available == 1 and not await automatic("RETURN")

            bulk_issue = next(row for row in await automatic("ISSUE") if row.quantity == 3)
            await tools.move(tools.MovementWrite(
                id=uuid4(), inventory_id=bulk_issue.inventory_id,
                kind="CONSUMED", quantity=Decimal(1), issue_id=bulk_issue.id,
            ), admin, session)
            assert (await transition(MaintenanceLifecycleCommand.COMPLETE)).status == "COMPLETED"
            assert sorted(row.quantity for row in await automatic("RETURN")) == [1, 2]
            assert (await bulk_stock()).available == 3
            meter_balance = await session.scalar(select(ToolInventoryRecord).where(
                ToolInventoryRecord.tool_id == meter_tool_id,
            ))
            assert meter_balance.available == 1
            pending = await tools.movements(offset=0, limit=100, open_only=True, session=session)
            assert [row["id"] for row in pending if str(activity_id) in row["activity_ids"]] == [manual.id]

            bulk_requirement = await session.scalar(select(OperationalChecklistItemRecord).where(
                OperationalChecklistItemRecord.checklist_revision_id == revision_id,
                OperationalChecklistItemRecord.item_name == bulk_name,
            ))
            bulk_requirement.default_quantity = 2
            competing_ids = [uuid4(), uuid4()]
            for identifier in competing_ids:
                session.add(MaintenanceActivityRecord(
                    id=identifier, activity_type="PREVENTIVE", status="SCHEDULED",
                    project_id=project_id, subsystem_id=subsystem_id,
                    maintenance_template_id=template_id, title="Preventivo",
                    internal_code=str(identifier),
                ))
            await session.commit()

            async def competing_start(identifier):
                async with async_session_factory() as transaction:
                    try:
                        result = await _transition_maintenance_activity(
                            activity_id=str(identifier), command=MaintenanceLifecycleCommand.START,
                            current_user=engineer, session=transaction,
                        )
                        return result.status
                    except HTTPException as error:
                        assert error.status_code == 409
                        return "REJECTED"

            outcomes = await asyncio.gather(*(competing_start(identifier) for identifier in competing_ids))
            assert sorted(outcomes) == ["IN_PROGRESS", "REJECTED"]
            assert (await bulk_stock()).available == 1
    finally:
        await engine.dispose()
