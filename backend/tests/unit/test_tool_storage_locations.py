import asyncio
from unittest.mock import AsyncMock
from uuid import uuid4

import app.models  # noqa: F401
import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session

from modules.asset_management.infrastructure.postgres.catalog_models import LocationTypeRecord
from modules.asset_management.infrastructure.postgres.domain_models import InventoryLocationRecord
from modules.maintenance_execution.interfaces import tool_admin_router as api


def test_tools_only_list_and_accept_active_warehouses() -> None:
    engine = create_engine("sqlite://")
    LocationTypeRecord.__table__.create(engine)
    InventoryLocationRecord.__table__.create(engine)
    with Session(engine) as db:
        warehouse = LocationTypeRecord(id=uuid4(), code="ALMACENAMIENTO", name="Almacenamiento")
        cabinet = LocationTypeRecord(id=uuid4(), code="GABINETE", name="Gabinete")
        db.add_all([warehouse, cabinet])
        db.flush()
        active = InventoryLocationRecord(
            id=uuid4(), name="Almacén", location_type_id=warehouse.id, is_active=True
        )
        inactive = InventoryLocationRecord(
            id=uuid4(), name="Almacén inactivo", location_type_id=warehouse.id, is_active=False
        )
        equipment = InventoryLocationRecord(
            id=uuid4(), name="CRK 1", location_type_id=cabinet.id, is_active=True
        )
        db.add_all([active, inactive, equipment])
        db.flush()
        session = AsyncMock(spec=AsyncSession)
        session.scalar.side_effect = db.scalar
        session.scalars.side_effect = db.scalars

        assert asyncio.run(api.storage_locations(session)) == [
            {"id": str(active.id), "name": active.name, "description": None}
        ]
        payload = api.InventoryItemWrite(name="Herramienta", quantity=1)
        assert asyncio.run(api._inventory_location_for_payload(session, payload)) is None
        assigned = payload.model_copy(update={"inventory_location_id": active.id})
        assert asyncio.run(api._inventory_location_for_payload(session, assigned)) == active
        for update in (
            {"inventory_location_id": inactive.id},
            {"inventory_location_id": equipment.id},
            {"inventory_location_id": uuid4()},
            {"location_text": "CRK 1"},
        ):
            with pytest.raises(HTTPException) as error:
                asyncio.run(api._inventory_location_for_payload(
                    session, payload.model_copy(update=update)
                ))
            assert error.value.status_code == 422
