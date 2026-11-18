from collections import defaultdict
from datetime import datetime
from decimal import Decimal
from uuid import UUID, uuid4
from zoneinfo import ZoneInfo

from sqlalchemy import cast, func, or_, select
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from modules.asset_management.infrastructure.postgres.catalog_models import LocationTypeRecord
from modules.asset_management.infrastructure.postgres.domain_models import InventoryLocationRecord
from modules.maintenance_execution.application.lifecycle import InvalidMaintenanceTransitionError
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
    ToolRecord,
)


def _pending_quantity():
    settlement = aliased(ToolMovementRecord)
    return ToolMovementRecord.quantity - (
        select(func.coalesce(func.sum(settlement.quantity), 0))
        .where(settlement.issue_id == ToolMovementRecord.id)
        .scalar_subquery()
    )


async def issue_checklist_stock(
    session: AsyncSession,
    activity_id: UUID,
    template_id: UUID,
    user_id: str,
    changed_at: datetime,
) -> None:
    rows = (await session.execute(
        select(OperationalChecklistItemRecord, ToolCatalogItemRecord)
        .join(OperationalChecklistRevisionRecord)
        .join(ToolCatalogItemRecord, ToolCatalogItemRecord.id == OperationalChecklistItemRecord.catalog_item_id)
        .where(
            OperationalChecklistRevisionRecord.maintenance_template_id == template_id,
            OperationalChecklistRevisionRecord.status == "ACTIVE",
        )
        .order_by(OperationalChecklistItemRecord.sequence, OperationalChecklistItemRecord.id)
    )).all()
    if not rows:
        return

    required: dict[UUID, Decimal] = defaultdict(Decimal)
    catalogs: dict[UUID, ToolCatalogItemRecord] = {}
    for item, catalog in rows:
        quantity = Decimal(str(item.default_quantity)) if item.default_quantity is not None else Decimal(1)
        if not quantity.is_finite() or quantity < 0 or quantity >= Decimal(10**15):
            raise InvalidMaintenanceTransitionError(f"Cantidad inválida en el checklist: {item.item_name}.")
        if quantity != quantity.quantize(Decimal("0.001")):
            raise InvalidMaintenanceTransitionError(f"Revisa la precisión de la cantidad de {item.item_name}.")
        if catalog.requires_identified_unit and quantity != quantity.to_integral_value():
            raise InvalidMaintenanceTransitionError(f"{item.item_name} requiere una cantidad entera.")
        if quantity > 0:
            required[catalog.id] += quantity
            catalogs[catalog.id] = catalog
    if not required:
        return

    item = ToolInventoryItemRecord
    stock = ToolInventoryRecord
    location = InventoryLocationRecord
    # Lock inventory rows before balances, in stable order, as manual dispatch does.
    inventory = (await session.execute(
        select(item, location.name)
        .join(location, location.id == item.inventory_location_id)
        .join(LocationTypeRecord, LocationTypeRecord.id == location.location_type_id)
        .where(
            item.catalog_item_id.in_(required),
            location.is_active.is_(True),
            LocationTypeRecord.is_active.is_(True),
            LocationTypeRecord.code == "ALMACENAMIENTO",
        )
        .order_by(item.id).with_for_update(of=item)
    )).all()
    item_ids = [row.id for row, _ in inventory]
    tool_ids = {row.tool_id for row, _ in inventory if row.tool_id is not None}
    pending = _pending_quantity()
    is_delivery = (
        (ToolMovementRecord.kind == "ISSUE")
        & cast(ToolMovementRecord.activity_ids, JSONB).contains([str(activity_id)])
        & (pending > 0)
    )
    delivered_stock = select(ToolMovementRecord.inventory_id).where(is_delivery)
    balances = (await session.scalars(
        select(stock).where(or_(
            stock.inventory_item_id.in_(item_ids), stock.tool_id.in_(tool_ids),
            stock.id.in_(delivered_stock),
        )).order_by(stock.id).with_for_update()
    )).all()
    by_item = {balance.inventory_item_id: balance for balance in balances if balance.inventory_item_id}
    by_tool = {balance.tool_id: balance for balance in balances if balance.tool_id}
    delivered = dict((await session.execute(
        select(stock.catalog_item_id, func.sum(pending))
        .join(stock, stock.id == ToolMovementRecord.inventory_id)
        .where(is_delivery, stock.catalog_item_id.in_(required))
        .group_by(stock.catalog_item_id)
    )).all())

    eligible_tools = set()
    if tool_ids:
        day = changed_at.astimezone(ZoneInfo("America/Lima")).date()
        eligible_tools = set((await session.scalars(
            select(ToolRecord.id)
            .join(ToolCertificationRecord, ToolCertificationRecord.tool_id == ToolRecord.id)
            .where(
                ToolRecord.id.in_(tool_ids), ToolRecord.is_active.is_(True),
                ToolCertificationRecord.is_active.is_(True),
                ToolCertificationRecord.calibration_date <= day,
                ToolCertificationRecord.next_calibration_date >= day,
            )
        )).all())

    for row, warehouse in sorted(inventory, key=lambda pair: (pair[1], pair[0].id)):
        catalog = catalogs[row.catalog_item_id]
        remaining = required[catalog.id] - delivered.get(catalog.id, Decimal(0))
        if remaining <= 0 or not catalog.is_active:
            continue
        if catalog.requires_identified_unit:
            balance = by_tool.get(row.tool_id)
            if row.tool_id not in eligible_tools or balance is None or balance.available != 1:
                continue
        else:
            if row.tool_id is not None:
                continue
            balance = by_item.get(row.id)
        if balance is not None:
            if balance.location != warehouse or balance.catalog_item_id != catalog.id:
                continue
            available = balance.available
        else:
            if row.status is None or row.status.strip().upper() != "DISPONIBLE":
                continue
            available = row.quantity
        quantity = min(available, remaining)
        if quantity <= 0:
            continue
        if balance is None:
            balance = ToolInventoryRecord(
                id=uuid4(), catalog_item_id=catalog.id, inventory_item_id=row.id,
                location=warehouse, available=available, unavailable=0,
            )
            session.add(balance)
        balance.available -= quantity
        if balance.tool_id:
            tool = await session.get(ToolRecord, balance.tool_id)
            tool.availability_status = "UNAVAILABLE"
        required[catalog.id] -= quantity
        # Flush the lazily created balance before the movement references its ID.
        await session.flush()
        session.add(ToolMovementRecord(
            id=uuid4(), inventory_id=balance.id, kind="ISSUE", quantity=quantity,
            responsible_user_id=user_id, actor_user_id=user_id,
            activity_ids=[str(activity_id)], automatic_activity_id=activity_id,
            notes="Salida automática al iniciar el mantenimiento preventivo.",
        ))

    missing = [
        f"{catalogs[catalog_id].name}: faltan {quantity - delivered.get(catalog_id, Decimal(0)):f}"
        for catalog_id, quantity in required.items()
        if quantity > delivered.get(catalog_id, Decimal(0))
    ]
    if missing:
        raise InvalidMaintenanceTransitionError(
            "No hay stock disponible para iniciar el mantenimiento. " + "; ".join(missing)
        )


async def return_checklist_stock(session: AsyncSession, activity_id: UUID, user_id: str) -> None:
    movement = ToolMovementRecord
    issues = (
        movement.automatic_activity_id == activity_id, movement.kind == "ISSUE",
    )
    stock_ids = select(movement.inventory_id).where(*issues)
    balances = {row.id: row for row in (await session.scalars(
        select(ToolInventoryRecord).where(ToolInventoryRecord.id.in_(stock_ids))
        .order_by(ToolInventoryRecord.id).with_for_update()
    )).all()}
    if not balances:
        return
    pending = _pending_quantity()
    for issue, quantity in (await session.execute(
        select(movement, pending).where(*issues, pending > 0).order_by(movement.id)
    )).all():
        balance = balances[issue.inventory_id]
        balance.available += quantity
        if balance.tool_id:
            tool = await session.get(ToolRecord, balance.tool_id)
            tool.availability_status = "AVAILABLE"
        session.add(ToolMovementRecord(
            id=uuid4(), inventory_id=balance.id, kind="RETURN", issue_id=issue.id,
            quantity=quantity, actor_user_id=user_id, activity_ids=[str(activity_id)],
            automatic_activity_id=activity_id,
            notes="Devolución automática al completar el mantenimiento preventivo.",
        ))
