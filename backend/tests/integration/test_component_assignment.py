"""Component changes run only against disposable migrated PostgreSQL."""

import asyncio
import os
from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import func, select, text

pytestmark = pytest.mark.skipif(
    os.getenv("TEST_COMPONENT_DB") != "1", reason="Requires disposable PostgreSQL"
)


def test_existing_component_assignment_images_and_history(tmp_path, monkeypatch):
    asyncio.run(_workflow(tmp_path, monkeypatch))


async def _workflow(tmp_path, monkeypatch):
    import app.models  # noqa: F401
    from app.config import settings
    from app.database import async_session_factory, engine
    from app.main import create_app
    from modules.asset_management.infrastructure.postgres.catalog_models import LocationTypeRecord
    from modules.asset_management.infrastructure.postgres.domain_models import (
        AssetAssignmentRecord, AssetTypeRecord, InventoryLocationRecord,
    )
    from modules.asset_management.infrastructure.postgres.models import AssetRecord
    from modules.asset_management.infrastructure.postgres.repository import PostgresAssetRepository
    from modules.asset_management.interfaces.schemas import AssetComponentOperationDTO
    from modules.identity_access.infrastructure.postgres.models import UserRecord
    from modules.identity_access.interfaces.dependencies import get_current_user
    from modules.identity_access.interfaces.schemas import UserDTO
    from shared_kernel.schemas import UserRole

    suffix = uuid4().hex
    admin = UserDTO(
        id=suffix, name="Admin", email=f"{suffix}@example.test",
        role=UserRole.ADMINISTRATOR, role_label="Administrador",
    )
    monkeypatch.setattr(settings, "attachment_storage_path", str(tmp_path))
    try:
        async with async_session_factory() as session:
            session.add(UserRecord(
                id=admin.id, name=admin.name, email=admin.email, role=admin.role.value,
                role_label=admin.role_label, password_hash="disabled",
            ))
            location_type = await session.scalar(select(LocationTypeRecord).where(
                LocationTypeRecord.code == "ALMACENAMIENTO"
            ))
            if location_type is None:
                location_type = LocationTypeRecord(
                    id=uuid4(), code="ALMACENAMIENTO", name="Almacenamiento",
                )
                session.add(location_type)
                await session.flush()
            warehouse = InventoryLocationRecord(
                id=uuid4(), name=f"Almacén {suffix}", location_type_id=location_type.id,
            )
            session.add(warehouse)
            component_type_id, component_part = uuid4(), f"PN-{suffix}"
            component_type = AssetTypeRecord(id=component_type_id, name=f"Modelo {suffix}", category="COMPONENT",
                part_number=component_part, serial_number_policy="OPTIONAL", part_number_policy="OPTIONAL")
            session.add(component_type)
            await session.flush()
            root_id, other_id, component_id, child_id, twin_id = [uuid4().hex for _ in range(5)]

            def asset(identifier, name, anchor=False, parent_id=None, location_id=None):
                return AssetRecord(
                    id=identifier, name=name, category="Equipo" if anchor else "Componente",
                    asset_type="Different" if identifier == root_id else "Test",
                    subsystem=f"ATS-{suffix}", serial_or_code=identifier,
                    status="Operativo", physical_location="Patio / Sala", is_business_anchor=anchor,
                    parent_id=parent_id, children=[], current_inventory_location_id=location_id,
                )

            session.add_all([asset(root_id, "Equipo destino", True), asset(other_id, "Otro equipo", True),
                             asset(twin_id, "Mismo tipo, otra serie", True)])
            await session.flush()
            session.add(asset(component_id, "Componente existente", location_id=warehouse.id))
            await session.flush()
            session.add(asset(child_id, "Componente hijo", parent_id=component_id))
            repo = PostgresAssetRepository(session)
            await session.flush()
            await repo._rebuild_asset_closure()
            await session.commit()
            operation = AssetComponentOperationDTO(
                action="ASSIGN", component_id=component_id, parent_id=root_id,
            )
            tree = await repo.apply_component_changes(root_id, [operation], user_id=admin.id)
            await session.commit()
            assert any(node.id == component_id for node in tree)
            assert any(node.id == child_id for node in tree)
            detail = await repo.get_component(component_id)
            assert detail.asset.parent_id == root_id
            assert detail.asset.serial_or_code == component_id
            assert detail.inventory_location is None
            movements, count = await repo.component_movements(component_id, 15, 0)
            assert count == 1 and movements[0].origin == warehouse.name
            assert movements[0].destination == "Equipo destino"
            assert "Equipo destino" in movements[0].notes
            assert await session.scalar(select(AssetAssignmentRecord).where(
                AssetAssignmentRecord.asset_id == component_id,
                AssetAssignmentRecord.parent_asset_id == root_id,
                AssetAssignmentRecord.unassigned_at.is_(None),
            )) is not None
            with pytest.raises(ValueError, match="cambió de equipo"):
                await repo.apply_component_changes(root_id, [operation], user_id=admin.id)
            await session.rollback()
            with pytest.raises(ValueError, match="dentro de sí mismo"):
                await repo.apply_component_changes(root_id, [operation.model_copy(update={
                    "expected_parent_id": root_id, "parent_id": child_id,
                })], user_id=admin.id)
            await session.rollback()
            tree = await repo.apply_component_changes(other_id, [operation.model_copy(update={
                "expected_parent_id": root_id, "parent_id": other_id,
            })], user_id=admin.id)
            await session.commit()
            assert any(node.id == component_id for node in tree)
            assert not any(node.id == component_id for node in await repo.get_tree(root_id))
            history, count = await repo.component_movements(component_id, 15, 0)
            assert count == 2
            assert (history[0].origin, history[0].destination) == ("Equipo destino", "Otro equipo")

        app = create_app()
        app.dependency_overrides[get_current_user] = lambda: admin
        image_payload = {
            "image_base64": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a7V8AAAAASUVORK5CYII=",
            "file_name": "componente.png", "media_type": "image/png",
        }
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            response = await client.post(f"/api/v1/assets/{child_id}/images", json=image_payload)
            assert response.status_code == 201, response.text
            image = response.json()
            assert image["is_primary"]
            assert (await client.get(image["url"])).status_code == 200
            assert (await client.get(
                f"/api/v1/assets/{child_id}/component-detail"
            )).json()["asset"]["images"][0]["id"] == image["id"]

            slots_url = f"/api/v1/assets/{other_id}/internal-slots"
            response = await client.post(slots_url, json={"name": "Armario", "accepts_asset": False})
            assert response.status_code == 201, response.text
            armario = response.json()[0]
            for name in ("Posición 1", "Posición 2"):
                response = await client.post(slots_url, json={
                    "name": name, "parent_id": armario["id"], "accepts_asset": True,
                })
                assert response.status_code == 201, response.text
            _, first, second = response.json()
            assert first["path"] == "/Armario/Posición 1"
            twin_slots = (await client.get(f"/api/v1/assets/{twin_id}/internal-slots")).json()
            assert [slot["path"] for slot in twin_slots] == ["/Armario", first["path"], second["path"]]
            assert all(slot["occupant_id"] is None for slot in twin_slots)
            assert {slot["id"] for slot in twin_slots}.isdisjoint({armario["id"], first["id"], second["id"]})
            foreign_url = f"/api/v1/assets/{root_id}/internal-slots"
            response = await client.post(foreign_url, json={"name": "Armario"})
            assert response.status_code == 201, response.text
            foreign = response.json()[0]
            assert foreign["id"] != armario["id"]
            assert (await client.post(slots_url, json={
                "name": "Inválido", "parent_id": foreign["id"],
            })).status_code == 422
            assert (await client.post(slots_url, json={"name": "armario"})).status_code == 422
            tree = (await client.get(f"/api/v1/assets/{root_id}/tree")).json()
            assert [(node["id"], node["status"]) for node in tree] == [(f"slot:{foreign['id']}", "Libre")]

            async def place(slot, component, expected=None):
                return await client.put(f"{slots_url}/{slot['id']}", json={
                    "component_id": component, "expected_occupant_id": expected,
                })

            assert (await place(armario, component_id)).status_code == 422
            assert (await place(foreign, component_id)).status_code == 422
            assert (await place(first, root_id)).status_code == 422
            assert (await place(first, component_id)).status_code == 200
            twin_tree = (await client.get(f"/api/v1/assets/{twin_id}/tree")).json()
            assert all(node["node_kind"] == "LOCATION" for node in twin_tree)
            options = (await client.get(f"/api/v1/assets/{other_id}/component-editor-options")).json()
            assert next(item for item in options["classifications"] if item["id"] == str(component_type_id))[
                "part_number"] == component_part
            pending = {"action": "CREATE", "parent_id": other_id, "name": "Nueva tarjeta",
                       "category": "Componente", "asset_type_id": str(component_type_id), "status": "Operativo",
                       "current_position": first["path"]}
            assert (await client.patch(f"/api/v1/assets/{other_id}/components", json={
                "operations": [pending],
            })).status_code == 422
            assert (await client.patch(f"/api/v1/assets/{other_id}/components", json={
                "operations": [{**pending, "category": "inventada", "current_position": ""}],
            })).status_code == 422
            assert (await place(first, child_id, component_id)).status_code == 422
            assert (await place(second, component_id)).status_code == 200
            tree = (await client.get(f"/api/v1/assets/{other_id}/tree")).json()
            assert next(node for node in tree if node["id"] == component_id)["parent_id"] == f"slot:{second['id']}"
            detail = (await client.get(f"/api/v1/assets/{component_id}/component-detail")).json()
            assert detail["asset"]["parent_id"] == other_id
            assert (await place(second, None)).status_code == 422
            assert (await place(second, None, component_id)).status_code == 200
            async with async_session_factory() as session:
                movements, _ = await PostgresAssetRepository(session).component_movements(component_id, 15, 0)
                assert (movements[1].origin, movements[1].destination) == (first["path"], second["path"])
            response = await client.patch(f"/api/v1/assets/{other_id}/components", json={"operations": [pending]})
            assert response.status_code == 200, response.text
            slots = (await client.get(slots_url)).json()
            new_unit = next(slot for slot in slots if slot["id"] == first["id"])
            assert new_unit["occupant_name"] == "Nueva tarjeta"
            new_detail = (await client.get(f"/api/v1/assets/{new_unit['occupant_id']}/component-detail")).json()
            assert new_detail["asset_type_id"] == str(component_type_id)
            assert new_detail["asset"]["part_number"] == component_part
            assert (await client.put(f"/api/v1/assets/{new_unit['occupant_id']}/component-detail", json={
                "name": "Nueva tarjeta", "part_number": "INVENTADO",
            })).status_code == 422
            assert (await client.put(f"/api/v1/assets/{new_unit['occupant_id']}/component-detail", json={
                "name": "Nueva tarjeta",
            })).status_code == 200
            assert (await client.patch(f"/api/v1/assets/{other_id}/components", json={"operations": [
                {**pending, "current_position": "", "part_number": "INVENTADO"},
            ]})).status_code == 422
            async with async_session_factory() as session:
                original_types = await session.scalar(select(func.count()).select_from(AssetTypeRecord))
            second_unit = {**pending, "name": "Segunda tarjeta", "serial_number": f"SER-{suffix}", "current_position": ""}
            assert (await client.patch(f"/api/v1/assets/{other_id}/components", json={"operations": [
                second_unit,
            ]})).status_code == 200
            assert (await client.patch(f"/api/v1/assets/{other_id}/components", json={"operations": [
                second_unit,
            ]})).status_code == 422
            async with async_session_factory() as session:
                assert await session.scalar(select(func.count()).select_from(AssetTypeRecord)) == original_types
                units = (await session.scalars(select(AssetRecord).where(AssetRecord.asset_type_id == component_type_id))).all()
                assert len(units) == 2
                assert all(unit.part_number == component_part for unit in units)
            new_model = {"action": "CREATE", "parent_id": other_id, "name": "Primer ejemplar",
                "status": "Operativo", "new_type_name": f"Modelo nuevo {suffix}",
                "new_type_part_number": f"PN-NUEVO-{suffix}"}
            assert (await client.patch(f"/api/v1/assets/{other_id}/components", json={
                "operations": [{**new_model, "current_position": first["path"]}],
            })).status_code == 422
            async with async_session_factory() as session:
                assert await session.scalar(select(AssetTypeRecord.id).where(
                    AssetTypeRecord.name == new_model["new_type_name"],
                )) is None
            assert (await client.patch(f"/api/v1/assets/{other_id}/components", json={
                "operations": [new_model],
            })).status_code == 200
            async with async_session_factory() as session:
                model = await session.scalar(select(AssetTypeRecord).where(AssetTypeRecord.name == new_model["new_type_name"]))
                unit = await session.scalar(select(AssetRecord).where(AssetRecord.asset_type_id == model.id))
                assert model.part_number == unit.part_number == new_model["new_type_part_number"]
            assert (await client.patch(f"/api/v1/assets/{other_id}/components", json={
                "operations": [new_model],
            })).status_code == 422

            response = await client.patch(f"/api/v1/assets/{twin_id}/components", json={"operations": [
                {**pending, "parent_id": twin_id, "name": "Padre destino", "current_position": ""},
            ]})
            assert response.status_code == 200, response.text
            holder = next(node for node in response.json() if node["name"] == "Padre destino")
            transfer = {"action": "ASSIGN", "component_id": new_unit["occupant_id"],
                "expected_parent_id": other_id, "parent_id": holder["id"], "current_position": "/No existe"}
            response = await client.patch(f"/api/v1/assets/{twin_id}/components", json={"operations": [transfer]})
            assert response.status_code == 422, response.text
            detail = (await client.get(f"/api/v1/assets/{new_unit['occupant_id']}/component-detail")).json()
            assert detail["asset"]["parent_id"] == other_id and detail["slot"] == first["path"]
            transfer["current_position"] = first["path"]
            twin_first = next(slot for slot in twin_slots if slot["path"] == first["path"])
            occupied_url = f"/api/v1/assets/{twin_id}/internal-slots/{twin_first['id']}"
            assert (await client.put(occupied_url, json={"component_id": holder["id"]})).status_code == 200
            assert (await client.patch(f"/api/v1/assets/{twin_id}/components", json={
                "operations": [transfer],
            })).status_code == 422
            assert (await client.put(occupied_url, json={
                "component_id": None, "expected_occupant_id": holder["id"],
            })).status_code == 200
            response = await client.patch(f"/api/v1/assets/{twin_id}/components", json={"operations": [transfer]})
            assert response.status_code == 200, response.text
            detail = (await client.get(f"/api/v1/assets/{new_unit['occupant_id']}/component-detail")).json()
            assert detail["asset"]["parent_id"] == holder["id"] and detail["slot"] == first["path"]
            assert next(slot for slot in (await client.get(slots_url)).json() if slot["id"] == first["id"])["occupant_id"] is None
            move = {"action": "MOVE", "component_id": new_unit["occupant_id"],
                "destination_equipment_id": other_id, "parent_id": other_id,
                "expected_parent_id": holder["id"], "current_position": second["path"]}
            response = await client.patch(f"/api/v1/assets/{twin_id}/components", json={"operations": [move]})
            assert response.status_code == 200, response.text
            detail = (await client.get(f"/api/v1/assets/{new_unit['occupant_id']}/component-detail")).json()
            assert detail["asset"]["parent_id"] == other_id and detail["slot"] == second["path"]
            assert (await client.patch(f"/api/v1/assets/{other_id}/components", json={"operations": [move]})).status_code == 422
            child_assignment = {"action": "ASSIGN", "component_id": child_id,
                "expected_parent_id": component_id, "parent_id": new_unit["occupant_id"],
                "current_position": first["path"]}
            assert (await client.patch(f"/api/v1/assets/{other_id}/components", json={
                "operations": [child_assignment],
            })).status_code == 200
            cross_with_child = {**move, "destination_equipment_id": twin_id, "parent_id": twin_id,
                "expected_parent_id": other_id, "current_position": first["path"]}
            assert (await client.patch(f"/api/v1/assets/{other_id}/components", json={
                "operations": [cross_with_child],
            })).status_code == 422
            internal_move = {**move, "expected_parent_id": other_id, "parent_id": component_id}
            response = await client.patch(f"/api/v1/assets/{other_id}/components", json={"operations": [internal_move]})
            assert response.status_code == 200, response.text
            child_detail = (await client.get(f"/api/v1/assets/{child_id}/component-detail")).json()
            assert child_detail["slot"] == first["path"]
            assert (await client.patch(f"/api/v1/assets/{other_id}/components", json={"operations": [
                {**move, "expected_parent_id": component_id},
            ]})).status_code == 200
            assert (await place(first, None, child_id)).status_code == 200
            assert (await client.patch(f"/api/v1/assets/{other_id}/components", json={"operations": [
                {**child_assignment, "expected_parent_id": new_unit["occupant_id"],
                    "parent_id": component_id, "current_position": ""},
            ]})).status_code == 200
            assert (await client.patch(f"/api/v1/assets/{other_id}/components", json={"operations": [
                {**move, "expected_parent_id": other_id, "parent_id": new_unit["occupant_id"]},
            ]})).status_code == 422
            assert (await client.patch(f"/api/v1/assets/{other_id}/components", json={"operations": [
                {"action": "DELETE", "component_id": new_unit["occupant_id"]},
            ]})).status_code == 409
            response = await client.patch(f"/api/v1/assets/{other_id}/components", json={"operations": [
                {**pending, "name": "Unidad sin historial", "current_position": ""},
            ]})
            disposable = next(node for node in response.json() if node["name"] == "Unidad sin historial")
            assert (await client.patch(f"/api/v1/assets/{other_id}/components", json={"operations": [
                {"action": "DELETE", "component_id": disposable["id"]},
            ]})).status_code == 200
            async with async_session_factory() as session:
                assert await session.get(AssetTypeRecord, component_type_id) is not None

            app.dependency_overrides[get_current_user] = lambda: admin.model_copy(
                update={"role": UserRole.MAINTENANCE_ENGINEER}
            )
            assert (await client.get(slots_url)).status_code == 200
            assert (await client.post(slots_url, json={"name": "No autorizado"})).status_code == 403
            assert (await place(first, component_id)).status_code == 403
            assert (await client.patch(f"/api/v1/assets/{other_id}/components", json={
                "operations": [{**new_model, "new_type_name": f"Prohibido {suffix}"}],
            })).status_code == 403
            assert (await client.patch(f"/api/v1/assets/{other_id}/components", json={
                "operations": [{**second_unit, "serial_number": f"SER-ENGINEER-{suffix}"}],
            })).status_code == 200
            assert (await client.post(
                f"/api/v1/assets/{child_id}/images", json=image_payload
            )).status_code == 403
            assert (await client.patch(
                f"/api/v1/assets/{root_id}/components",
                json={"operations": [operation.model_dump(mode="json")]},
            )).status_code == 403
    finally:
        await engine.dispose()


def test_shared_structure_backfills_existing_occupied_slots():
    asyncio.run(_backfill_workflow())


async def _backfill_workflow():
    import app.models  # noqa: F401
    from app.database import async_session_factory, engine
    from modules.asset_management.infrastructure.postgres.catalog_models import SlotTypeRecord
    from modules.asset_management.infrastructure.postgres.domain_models import SlotLocationRecord
    from modules.asset_management.infrastructure.postgres.models import AssetRecord
    from modules.asset_management.infrastructure.postgres.repository import PostgresAssetRepository

    suffix = uuid4().hex
    try:
        async with async_session_factory() as session:
            def equipment():
                return AssetRecord(id=uuid4().hex, name="Equipo", category="Equipo",
                    asset_type=f"Tipo-{suffix}", subsystem="ATS", serial_or_code=uuid4().hex,
                    status="Operativo", physical_location="Patio", is_business_anchor=True, children=[])

            source, peer = equipment(), equipment()
            slot_type = SlotTypeRecord(id=uuid4(), name=f"Tipo espacio {suffix}")
            session.add_all([source, peer, slot_type])
            await session.flush()
            container = SlotLocationRecord(id=uuid4(), name="Armario", level=1, path="/Armario",
                equipment_asset_id=source.id, slot_type_id=slot_type.id, accepts_asset=False)
            session.add(container)
            await session.flush()
            position = SlotLocationRecord(id=uuid4(), name="Posición", level=2, path="/Armario/Posición",
                equipment_asset_id=source.id, slot_type_id=slot_type.id, accepts_asset=True,
                parent_slot_location_id=container.id)
            session.add(position)
            await session.flush()
            card = AssetRecord(id=uuid4().hex, name="Tarjeta", category="Componente", asset_type="Tarjeta",
                subsystem="ATS", serial_or_code=uuid4().hex, status="Operativo", physical_location="Patio",
                is_business_anchor=False, parent_id=source.id, children=[], current_slot_location_id=position.id)
            session.add(card)
            await session.flush()
            await session.execute(text("SELECT sync_equipment_slot_structure(:id)"), {"id": source.id})
            repo = PostgresAssetRepository(session)
            source_slots = await repo.equipment_slots(source.id)
            peer_slots = await repo.equipment_slots(peer.id)
            assert {slot.path for slot in peer_slots} == {"/Armario", "/Armario/Posición"}
            assert all(slot.occupant_id is None for slot in peer_slots)
            assert next(slot for slot in source_slots if slot.id == position.id).occupant_id == card.id
            cloned_container = next(slot for slot in peer_slots if slot.path == "/Armario")
            assert next(slot for slot in peer_slots if slot.path.endswith("/Posición")).parent_id == cloned_container.id
            future = equipment()
            session.add(future)
            await session.flush()
            await session.execute(text("SELECT sync_equipment_slot_structure(:id)"), {"id": future.id})
            assert len(await repo.equipment_slots(future.id)) == 2
    finally:
        await engine.dispose()
