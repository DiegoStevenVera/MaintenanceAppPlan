"""Run only against a disposable migrated PostgreSQL, never a business DB."""

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


def test_inventory_and_revision_workflows():
    asyncio.run(run_workflow(workflows))


def test_warehouse_issue_and_partial_settlement():
    asyncio.run(run_workflow(warehouse_issue_workflow))


async def run_workflow(workflow):
    from app.database import engine

    try:
        await workflow()
    finally:
        await engine.dispose()


async def warehouse_issue_workflow():
    import app.models  # noqa: F401
    from app.database import async_session_factory
    from modules.asset_management.infrastructure.postgres.catalog_models import LocationTypeRecord
    from modules.asset_management.infrastructure.postgres.domain_models import InventoryLocationRecord
    from modules.identity_access.infrastructure.postgres.models import UserRecord
    from modules.identity_access.interfaces.schemas import UserDTO
    from modules.maintenance_execution.interfaces import tool_admin_router as api
    from shared_kernel.schemas import UserRole

    uid = str(uuid4())
    user = UserDTO(
        id=uid, name="Administrador", email=f"{uid}@example.test",
        role=UserRole.ADMINISTRATOR, role_label="Admin",
    )
    async with async_session_factory() as s:
        s.add(UserRecord(
            id=uid, name=user.name, email=user.email, role=user.role.value,
            role_label=user.role_label, password_hash="disabled", is_active=True,
        ))
        location_type = await s.scalar(select(LocationTypeRecord).where(
            LocationTypeRecord.code == "ALMACENAMIENTO"
        ))
        if location_type is None:
            location_type = LocationTypeRecord(
                id=uuid4(), code="ALMACENAMIENTO", name="Almacenamiento", is_active=True
            )
            s.add(location_type)
            await s.flush()
        warehouse = InventoryLocationRecord(
            id=uuid4(), name=f"Almacén {uid}", location_type_id=location_type.id, is_active=True,
        )
        s.add(warehouse)
        await s.flush()
        draft = api.InventoryItemWrite(
            name=f"Paño {uid}", quantity=5, classification="CONSUMIBLE",
            inventory_location_id=warehouse.id,
        )
        warehouse_id = warehouse.id
        item_id = UUID((await api.create_inventory_item(draft, s))["id"])
        other_id = UUID((await api.create_inventory_item(draft, s))["id"])
        request = api.InventoryIssueWrite(id=uuid4(), quantity=4, responsible_user_id=uid)
        await api.issue_inventory_item(item_id, request, user, s)
        await api.issue_inventory_item(item_id, request, user, s)

        async def items():
            page = await api.inventory_items(q=uid, offset=0, limit=10, session=s)
            return {UUID(row["id"]): row for row in page["items"]}

        rows = await items()
        assert rows[item_id]["quantity"] == 1 and rows[item_id]["stock_locked"]
        assert rows[other_id]["quantity"] == 5 and not rows[other_id]["stock_locked"]
        with pytest.raises(HTTPException) as ex:
            await api.issue_inventory_item(
                item_id, request.model_copy(update={"id": uuid4(), "quantity": Decimal(2)}), user, s
            )
        assert ex.value.status_code == 409
        await s.rollback()

        async def pending():
            rows = await api.movements(offset=0, limit=100, open_only=True, session=s)
            return next((row for row in rows if row["id"] == request.id), None)

        assert (await pending())["outstanding"] == 4
        balance_id = (await pending())["inventory_id"]
        for kind, quantity, expected in [
            ("RETURN", 2, 2), ("DAMAGED", 1, 1), ("CONSUMED", 1, 0),
        ]:
            await api.move(api.MovementWrite(
                id=uuid4(), inventory_id=balance_id, kind=kind,
                quantity=quantity, issue_id=request.id,
            ), user, s)
            row = await pending()
            assert (row["outstanding"] if row else 0) == expected
        assert (await items())[item_id]["quantity"] == 3
        history = await api.movements(offset=0, limit=100, open_only=False, session=s)
        assert {row["kind"] for row in history if row["inventory_id"] == balance_id} == {
            "ISSUE", "RETURN", "DAMAGED", "CONSUMED",
        }
        await api.update_inventory_item(item_id, draft.model_copy(update={"quantity": 99}), s)
        assert (await items())[item_id]["quantity"] == 3
        with pytest.raises(HTTPException) as error:
            await api.delete_inventory_item(item_id, s)
        assert error.value.status_code == 409
        await s.rollback()

        serial = api.InventoryItemWrite(
            name=f"Medidor {uid}", tool_code=uid, quantity=1, classification="EQUIPO",
            inventory_location_id=warehouse_id,
        )
        serial_id = UUID((await api.create_inventory_item(serial, s))["id"])
        with pytest.raises(HTTPException) as error:
            await api.issue_inventory_item(
                serial_id, api.InventoryIssueWrite(id=uuid4(), quantity=2, responsible_user_id=uid),
                user, s,
            )
        assert error.value.status_code == 422
        await s.rollback()
        serial_issue = api.InventoryIssueWrite(id=uuid4(), quantity=1, responsible_user_id=uid)
        await api.issue_inventory_item(serial_id, serial_issue, user, s)
        assert (await items())[serial_id]["quantity"] == 0
        assert (await items())[serial_id]["status"] == "SIN STOCK"

    from app.main import create_app
    from httpx import ASGITransport, AsyncClient
    from modules.identity_access.interfaces.dependencies import get_current_user

    app = create_app()
    app.dependency_overrides[get_current_user] = lambda: user.model_copy(
        update={"role": UserRole.MAINTENANCE_ENGINEER}
    )
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        assert (await client.post(
            f"/api/v1/tool-admin/items/{other_id}/issue",
            json=request.model_dump(mode="json"),
        )).status_code == 403


async def workflows():
    import app.models  # noqa: F401
    from app.database import async_session_factory, engine
    from modules.identity_access.infrastructure.postgres.models import UserRecord
    from modules.identity_access.interfaces.schemas import UserDTO
    from modules.organizational_context.infrastructure.postgres.models import (
        SiteRecord,
        ProjectRecord,
        SystemRecord,
        SubsystemRecord,
    )
    from modules.maintenance_execution.infrastructure.postgres.template_models import (
        MaintenanceTemplateRecord,
    )
    from modules.maintenance_execution.infrastructure.postgres.tool_models import (
        OperationalChecklistRevisionRecord,
        OperationalChecklistItemRecord,
        ToolCertificationRecord,
    )
    from modules.maintenance_execution.infrastructure.postgres.tool_inventory_item_models import (
        ToolInventoryItemRecord,
    )
    from modules.maintenance_execution.infrastructure.postgres.tool_inventory_models import (
        ToolInventoryRecord,
    )
    from modules.maintenance_execution.infrastructure.postgres.report_models import (
        MaintenanceActivityRecord,
    )
    from modules.maintenance_execution.infrastructure.postgres.report_writer import (
        PostgresReportWriter,
    )
    from modules.maintenance_execution.interfaces.schemas import (
        PreventiveReportWriteDTO,
        OperationalChecklistItemWriteDTO,
    )
    from modules.maintenance_execution.interfaces import tool_admin_router as api
    from shared_kernel.schemas import UserRole

    uid = str(uuid4())
    user = UserDTO(
        id=uid,
        name="Test Admin",
        email=f"{uid}@example.test",
        role=UserRole.ADMINISTRATOR,
        role_label="Admin",
    )
    async with async_session_factory() as s:
        s.add(
            UserRecord(
                id=uid,
                name=user.name,
                email=user.email,
                role="ADMINISTRATOR",
                role_label="Admin",
                password_hash="disabled",
            )
        )
        site = SiteRecord(id=uuid4(), name=uid)
        s.add(site)
        await s.flush()
        project = ProjectRecord(id=uuid4(), name=uid, site_id=site.id)
        s.add(project)
        await s.flush()
        system = SystemRecord(id=uuid4(), name=uid, project_id=project.id)
        s.add(system)
        await s.flush()
        subsystem = SubsystemRecord(id=uuid4(), name=uid, code=uid, system_id=system.id)
        s.add(subsystem)
        await s.flush()
        template = MaintenanceTemplateRecord(
            id=uuid4(), report_code=uid, subsystem_id=subsystem.id, activity_n1="Test maintenance"
        )
        s.add(template)
        await s.commit()
        template_id = template.id
        project_id = project.id
        subsystem_id = subsystem.id
        created = await api.create_catalog(
            api.CatalogWrite(name="Cloth " + uid, category="CONSUMABLE"), s
        )
        catalog_id = UUID(created["id"])
        stock = await api.create_stock(
            api.StockWrite(catalog_item_id=catalog_id, location="Office"), s
        )
        stock_id = UUID(stock["id"])
        receipt = api.MovementWrite(id=uuid4(), inventory_id=stock_id, kind="RECEIPT", quantity=10)
        await api.move(receipt, user, s)
        await api.move(receipt, user, s)  # Same command is not received twice.
        await s.refresh(await s.get(ToolInventoryRecord, stock_id))
        assert (await s.get(ToolInventoryRecord, stock_id)).available == 10
        with pytest.raises(HTTPException) as ex:
            await api.move(receipt.model_copy(update={"quantity": Decimal(11)}), user, s)
        assert ex.value.status_code == 409
        await s.rollback()
        issue = api.MovementWrite(
            id=uuid4(), inventory_id=stock_id, kind="ISSUE", quantity=4, responsible_user_id=uid
        )
        await api.move(issue, user, s)
        for kind, quantity in [("RETURN", 1), ("CONSUMED", 2), ("DAMAGED", 1)]:
            await api.move(
                api.MovementWrite(
                    id=uuid4(),
                    inventory_id=stock_id,
                    kind=kind,
                    quantity=quantity,
                    issue_id=issue.id,
                ),
                user,
                s,
            )
        assert not any(
            str(r["id"]) == str(issue.id)
            for r in await api.movements(offset=0, limit=100, open_only=True, session=s)
        )
        balance = await s.get(ToolInventoryRecord, stock_id)
        assert balance.available == 7 and balance.unavailable == 1
        for payload in [
            api.MovementWrite(
                id=uuid4(),
                inventory_id=stock_id,
                kind="ISSUE",
                quantity=99,
                responsible_user_id=uid,
            ),
            api.MovementWrite(
                id=uuid4(), inventory_id=stock_id, kind="RETURN", quantity=1, issue_id=issue.id
            ),
        ]:
            with pytest.raises(HTTPException):
                await api.move(payload, user, s)
            await s.rollback()
        assert await api.people(s)
        assert await api.inventory(s)
        assert await api.catalog(s)
        assert any(str(r["id"]) == str(template_id) for r in await api.templates(session=s))
        published = await api.publish_checklist(
            template_id,
            api.ChecklistWrite(
                items=[api.ChecklistLine(catalog_item_id=catalog_id, default_quantity=2)]
            ),
            user,
            s,
        )
        revision_id = UUID(published["id"])
        line = await s.scalar(
            select(OperationalChecklistItemRecord).where(
                OperationalChecklistItemRecord.checklist_revision_id == revision_id
            )
        )
        old_line_id = str(line.id)
        with pytest.raises(HTTPException) as ex:
            await api.publish_checklist(template_id, api.ChecklistWrite(items=[]), user, s)
        assert ex.value.status_code == 409
        await s.rollback()
        await api.publish_checklist(
            template_id, api.ChecklistWrite(base_revision_id=revision_id, items=[]), user, s
        )
        detail = await api.template_detail(template_id, s)
        assert detail["operational_checklist"] == []
        assert len(detail["revisions"]) == 2
        archived = await s.get(OperationalChecklistRevisionRecord, revision_id)
        assert archived.status == "ARCHIVED" and archived.created_by_user_id == uid
        writer = PostgresReportWriter(s)
        old_draft = PreventiveReportWriteDTO(
            operational_checklist=[
                OperationalChecklistItemWriteDTO(
                    template_item_id=old_line_id, is_checked=True, quantity=2
                )
            ]
        )
        old_items = await writer._operational_checklist(
            MaintenanceActivityRecord(maintenance_template_id=template_id), old_draft
        )
        assert len(old_items) == 1 and old_items[0].id == old_line_id
        eq = await api.create_catalog(
            api.CatalogWrite(
                name="Meter " + uid, category="EQUIPMENT", requires_identified_unit=True
            ),
            s,
        )
        unit = await api.create_stock(
            api.StockWrite(catalog_item_id=UUID(eq["id"]), location="Lab", serial_number=uid), s
        )
        unit_id = UUID(unit["id"])
        identified_inventory_item = await s.scalar(
            select(ToolInventoryItemRecord).where(
                ToolInventoryItemRecord.tool_id.is_not(None),
                ToolInventoryItemRecord.tool_code == uid,
            )
        )
        assert identified_inventory_item is not None
        identified_tool_id = identified_inventory_item.tool_id
        await api.move(
            api.MovementWrite(id=uuid4(), inventory_id=unit_id, kind="RECEIPT", quantity=1), user, s
        )
        with pytest.raises(HTTPException):
            await api.move(
                api.MovementWrite(id=uuid4(), inventory_id=unit_id, kind="RECEIPT", quantity=1),
                user,
                s,
            )
        await s.rollback()
        activity = MaintenanceActivityRecord(
            id=uuid4(),
            activity_type="PREVENTIVE",
            status="IN_PROGRESS",
            project_id=project_id,
            subsystem_id=subsystem_id,
            maintenance_template_id=template_id,
            title="Test activity",
            internal_code=uid,
        )
        s.add(activity)
        await s.commit()
        activity_id = activity.id
        await api.move(
            api.MovementWrite(
                id=uuid4(),
                inventory_id=unit_id,
                kind="ISSUE",
                quantity=1,
                responsible_user_id=uid,
                activity_ids=[activity_id],
            ),
            user,
            s,
        )
        deliveries = await writer._tool_deliveries(activity_id)
        assert len(deliveries) == 1 and deliveries[0].quantity == 1
        available = await writer._available_tools(activity_id)
        assert (
            next(t for t in available if t.serial_number == uid).availability_status == "AVAILABLE"
        )
        assert next(t for t in available if t.serial_number == uid).is_selectable is False
        s.add(
            ToolCertificationRecord(
                id=uuid4(),
                tool_id=identified_tool_id,
                calibration_company="Test Lab",
                certification_number=uid,
                calibration_date=date.today(),
                validity_days=365,
                next_calibration_date=date.today() + timedelta(days=365),
                is_active=True,
            )
        )
        await s.commit()
        certified = await writer._available_tools(activity_id)
        assert next(t for t in certified if t.serial_number == uid).is_selectable is True
        unassigned = await writer._available_tools(uuid4())
        assert (
            next(t for t in unassigned if t.serial_number == uid).availability_status
            == "UNAVAILABLE"
        )

        from modules.asset_management.infrastructure.postgres.models import AssetRecord
        from modules.maintenance_execution.infrastructure.postgres.template_models import (
            MaintenanceTemplateScopeRecord,
        )

        asset = AssetRecord(
            id=uid,
            name="Test Frontam",
            category="Equipo",
            asset_type="Cabinet",
            subsystem="ATS",
            serial_or_code=uid,
            status="AVAILABLE",
            physical_location="Office",
            is_business_anchor=True,
        )
        s.add(asset)
        await s.flush()
        s.add(
            MaintenanceTemplateScopeRecord(
                maintenance_template_id=template_id, asset_id=uid, display_name="Test Frontam scope"
            )
        )
        await s.commit()
        assert len(await api.templates(asset_id=uid, session=s)) == 1
        assert await api.templates(asset_id=str(uuid4()), session=s) == []

    async def concurrent_issue():
        async with async_session_factory() as concurrent_session:
            try:
                await api.move(
                    api.MovementWrite(
                        id=uuid4(),
                        inventory_id=stock_id,
                        kind="ISSUE",
                        quantity=4,
                        responsible_user_id=uid,
                    ),
                    user,
                    concurrent_session,
                )
                return True
            except HTTPException as error:
                assert error.status_code == 409
                return False

    outcomes = await asyncio.gather(concurrent_issue(), concurrent_issue())
    assert outcomes.count(True) == 1  # Row locks prevent over-issuing seven units.

    # HTTP serialization and authorization use the actual FastAPI routes.
    from app.main import create_app
    from modules.identity_access.interfaces.dependencies import get_current_user
    from httpx import ASGITransport, AsyncClient

    app = create_app()
    app.dependency_overrides[get_current_user] = lambda: user
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        for path in [
            "tool-admin/catalog",
            "tool-admin/items",
            "tool-admin/inventory",
            "tool-admin/movements",
            "tool-admin/people",
            "preventive-templates",
            f"preventive-templates/{template_id}",
        ]:
            response = await client.get("/api/v1/" + path)
            assert response.status_code == 200, response.text
        inventory_response = await client.get("/api/v1/tool-admin/items")
        assert inventory_response.status_code == 200
        inventory_payload = inventory_response.json()
        image = next(
            (image for item in inventory_payload["items"] for image in item["images"]),
            None,
        )
        if image:
            image_response = await client.get(image["url"])
            assert image_response.status_code == 200
        app.dependency_overrides[get_current_user] = lambda: user.model_copy(
            update={"role": UserRole.MAINTENANCE_ENGINEER}
        )
        assert (await client.get("/api/v1/tool-admin/inventory")).status_code == 403
        assert (
            await client.put(
                f"/api/v1/preventive-templates/{template_id}/checklist", json={"items": []}
            )
        ).status_code == 403
        assert (await client.get(f"/api/v1/preventive-templates/{template_id}")).status_code == 200
    await engine.dispose()
