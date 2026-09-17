"""Online tool administration; report consumption never writes inventory."""

import base64
import binascii
from datetime import date
from decimal import Decimal
import hashlib
import mimetypes
from pathlib import Path
from typing import Literal
import unicodedata
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import FileResponse
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import func, select, text, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session
from modules.identity_access.interfaces.dependencies import get_current_user, require_roles
from modules.identity_access.interfaces.schemas import UserDTO
from modules.maintenance_execution.infrastructure.postgres.tool_models import (
    ToolCertificationRecord,
    ToolCatalogItemRecord,
    ToolRecord,
    OperationalChecklistRevisionRecord,
    OperationalChecklistItemRecord,
)
from modules.maintenance_execution.infrastructure.postgres.tool_inventory_models import (
    ToolInventoryRecord,
    ToolMovementRecord,
)
from modules.maintenance_execution.infrastructure.postgres.tool_inventory_item_models import (
    ToolInventoryItemImageRecord,
    ToolInventoryItemRecord,
)
from modules.asset_management.infrastructure.postgres.domain_models import InventoryLocationRecord
from modules.maintenance_execution.infrastructure.postgres.template_models import (
    MaintenanceTemplateRecord,
)
from modules.maintenance_execution.infrastructure.postgres.report_models import (
    MaintenanceActivityRecord,
)
from modules.maintenance_execution.infrastructure.postgres.report_writer import PostgresReportWriter
from shared_kernel.schemas import UserRole
from app.config import settings
from shared_kernel.storage import resolve_storage_reference, storage_key

router = APIRouter(tags=["tools"], dependencies=[Depends(get_current_user)])
admin = require_roles(UserRole.ADMINISTRATOR)
Category = Literal["MANUAL_TOOL", "CONSUMABLE", "EQUIPMENT", "ACCESS_KEY"]


class CatalogWrite(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)
    name: str = Field(min_length=1, max_length=200)
    category: Category
    default_unit: str = Field(default="unidad", min_length=1, max_length=40)
    requires_identified_unit: bool = False
    is_active: bool = True


class ChecklistLine(BaseModel):
    catalog_item_id: UUID
    default_quantity: float | None = Field(default=None, ge=0, allow_inf_nan=False)
    unit: str = Field(default="unidad", min_length=1, max_length=40)
    notes: str | None = Field(default=None, max_length=2000)


class ChecklistWrite(BaseModel):
    base_revision_id: UUID | None = None
    items: list[ChecklistLine] = Field(max_length=500)


class StockWrite(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)
    catalog_item_id: UUID
    location: str = Field(min_length=1, max_length=200)
    serial_number: str | None = Field(default=None, max_length=120)
    model: str | None = Field(default=None, max_length=120)
    brand: str | None = Field(default=None, max_length=120)


class MovementWrite(BaseModel):
    id: UUID
    inventory_id: UUID
    kind: Literal[
        "RECEIPT", "ISSUE", "RETURN", "CONSUMED", "DAMAGED", "LOST", "ADJUST_ADD", "ADJUST_REMOVE"
    ]
    quantity: Decimal = Field(gt=0, max_digits=18, decimal_places=3)
    issue_id: UUID | None = None
    responsible_user_id: str | None = None
    activity_ids: list[UUID] = Field(default_factory=list, max_length=100)
    notes: str | None = Field(default=None, max_length=2000)


class InventoryItemWrite(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    model_code: str | None = Field(default=None, max_length=160)
    tool_code: str | None = Field(default=None, max_length=160)
    label: str | None = Field(default=None, max_length=80)
    quantity: Decimal = Field(default=0, ge=0, max_digits=18, decimal_places=3)
    name: str = Field(min_length=1, max_length=240)
    description: str | None = Field(default=None, max_length=20_000)
    cabinet: str | None = Field(default=None, max_length=200)
    cabinet_detail: str | None = Field(default=None, max_length=200)
    company: str | None = Field(default=None, max_length=200)
    classification: str | None = Field(default=None, max_length=100)
    category: str | None = Field(default=None, max_length=120)
    inventory_location_id: UUID | None = None
    location_text: str | None = Field(default=None, max_length=200)
    status: str | None = Field(default="DISPONIBLE", max_length=60)
    observations: str | None = Field(default=None, max_length=20_000)
    image_base64: str | None = None
    image_file_name: str | None = Field(default=None, max_length=255)
    image_media_type: str | None = Field(default=None, max_length=100)
    replace_image_ids: list[UUID] = Field(default_factory=list, max_length=20)


def _certification_status(
    certification: ToolCertificationRecord | None,
) -> str:
    if certification is None:
        return "MISSING"
    return "VALID" if certification.next_calibration_date >= date.today() else "EXPIRED"


def _inventory_item_payload(item, location_name, images, tool=None, certification=None):
    return {
        "id": str(item.id),
        "source_file": item.source_file,
        "source_row_number": item.source_row_number,
        "catalog_item_id": str(item.catalog_item_id) if item.catalog_item_id else None,
        "tool_id": str(item.tool_id) if item.tool_id else None,
        "model_code": item.model_code,
        "tool_code": item.tool_code,
        "label": item.label,
        "quantity": float(item.quantity),
        "name": item.name,
        "description": item.description,
        "cabinet": item.cabinet,
        "cabinet_detail": item.cabinet_detail,
        "company": item.company,
        "classification": item.classification,
        "category": item.category,
        "inventory_location_id": str(item.inventory_location_id)
        if item.inventory_location_id
        else None,
        "location": location_name or item.location_text,
        "location_text": item.location_text,
        "status": item.status,
        "observations": item.observations,
        "serial_number": tool.serial_number if tool else None,
        "certification_number": (
            certification.certification_number if certification else None
        ),
        "certification_valid_until": (
            certification.next_calibration_date if certification else None
        ),
        "certification_status": (
            _certification_status(certification) if tool else "NOT_REQUIRED"
        ),
        "images": [
            {
                "id": str(image.id),
                "file_name": image.file_name,
                "media_type": image.media_type,
                "byte_size": image.byte_size,
                "url": f"/api/v1/tool-admin/items/{item.id}/images/{image.id}",
            }
            for image in images
        ],
    }


def _normalized_inventory_value(value: str | None) -> str:
    text_value = str(value or "").strip()
    decomposed = unicodedata.normalize("NFKD", text_value)
    return "".join(char for char in decomposed if not unicodedata.combining(char)).upper()


def _catalog_category_for_inventory(classification: str | None) -> str:
    classification_key = _normalized_inventory_value(classification)
    if "CONSUMIBLE" in classification_key:
        return "CONSUMABLE"
    if "LLAVE" in classification_key or "ACCESO" in classification_key:
        return "ACCESS_KEY"
    if "EQUIPO" in classification_key:
        return "EQUIPMENT"
    return "MANUAL_TOOL"


async def _catalog_for_inventory(
    session: AsyncSession,
    payload: InventoryItemWrite,
) -> ToolCatalogItemRecord:
    category = _catalog_category_for_inventory(payload.classification)
    catalog = await session.scalar(
        select(ToolCatalogItemRecord).where(
            func.lower(ToolCatalogItemRecord.name) == payload.name.lower(),
            ToolCatalogItemRecord.category == category,
        )
    )
    if catalog is None:
        catalog = ToolCatalogItemRecord(
            id=uuid4(),
            name=payload.name,
            category=category,
            default_unit="unidad",
            requires_identified_unit=category == "EQUIPMENT",
            is_active=True,
        )
        session.add(catalog)
        await session.flush()
    elif not catalog.is_active:
        catalog.is_active = True
    return catalog


async def _inventory_location_for_payload(
    session: AsyncSession,
    payload: InventoryItemWrite,
) -> InventoryLocationRecord | None:
    if payload.inventory_location_id is None:
        return None
    location = await session.get(InventoryLocationRecord, payload.inventory_location_id)
    if location is None or not location.is_active:
        fail("La ubicación de almacenamiento no existe o está inactiva.", 422)
    return location


def _decode_inventory_image(payload: InventoryItemWrite) -> tuple[bytes, str, str] | None:
    if not payload.image_base64:
        return None
    encoded = payload.image_base64.split(",", 1)[-1]
    try:
        content = base64.b64decode(encoded, validate=True)
    except (binascii.Error, ValueError) as error:
        raise HTTPException(status_code=422, detail="La imagen no tiene un formato válido.") from error
    if not content:
        raise HTTPException(status_code=422, detail="La imagen está vacía.")
    if len(content) > settings.attachment_max_bytes:
        raise HTTPException(
            status_code=413,
            detail=f"La imagen supera el límite de {settings.attachment_max_bytes} bytes.",
        )
    media_type = payload.image_media_type or mimetypes.guess_type(payload.image_file_name or "")[0]
    if not media_type or not media_type.startswith("image/"):
        raise HTTPException(status_code=422, detail="El archivo debe ser una imagen.")
    file_name = Path(payload.image_file_name or "imagen").name
    if not file_name or file_name in {".", ".."}:
        file_name = "imagen"
    return content, media_type, file_name


async def _remove_inventory_image_file(image: ToolInventoryItemImageRecord) -> None:
    path = resolve_storage_reference(image.file_reference, settings.resolved_attachment_root)
    if path is not None:
        path.unlink(missing_ok=True)


async def _apply_inventory_item_payload(
    session: AsyncSession,
    item: ToolInventoryItemRecord,
    payload: InventoryItemWrite,
) -> None:
    location = await _inventory_location_for_payload(session, payload)
    catalog = await _catalog_for_inventory(session, payload)
    effective_status = payload.status
    linked_tool = await session.get(ToolRecord, item.tool_id) if item.tool_id else None
    if catalog.requires_identified_unit:
        serial_number = (payload.tool_code or "").strip()
        if not serial_number:
            fail("Los equipos deben tener un código o número de serie.")
        duplicate = await session.scalar(
            select(ToolRecord).where(ToolRecord.serial_number == serial_number)
        )
        if duplicate is not None and (
            linked_tool is None or duplicate.id != linked_tool.id
        ):
            linked_item = await session.scalar(
                select(ToolInventoryItemRecord.id).where(
                    ToolInventoryItemRecord.tool_id == duplicate.id,
                    ToolInventoryItemRecord.id != item.id,
                )
            )
            if linked_item is not None:
                fail("Ese código o número de serie ya pertenece a otro equipo.", 409)
            linked_tool = duplicate
        if linked_tool is None:
            linked_tool = ToolRecord(
                id=uuid4(),
                serial_number=serial_number,
                name=payload.name,
                availability_status="AVAILABLE",
            )
        linked_tool.catalog_item_id = catalog.id
        linked_tool.serial_number = serial_number
        linked_tool.name = payload.name
        linked_tool.model = payload.model_code
        linked_tool.brand = payload.company
        linked_tool.tool_type = payload.category or "INSTRUMENTO"
        linked_tool.current_location = location.name if location else payload.location_text
        linked_tool.availability_status = (
            "AVAILABLE"
            if _normalized_inventory_value(payload.status) == "DISPONIBLE"
            and payload.quantity > 0
            else "UNAVAILABLE"
        )
        linked_tool.is_active = True
        session.add(linked_tool)
        await session.flush()
        item.tool_id = linked_tool.id
        item.quantity = Decimal(1)
        stock = await session.scalar(
            select(ToolInventoryRecord).where(
                ToolInventoryRecord.tool_id == linked_tool.id
            )
        )
        if stock is None:
            is_available = linked_tool.availability_status == "AVAILABLE"
            session.add(
                ToolInventoryRecord(
                    id=uuid4(),
                    catalog_item_id=catalog.id,
                    tool_id=linked_tool.id,
                    location=linked_tool.current_location or "Sin ubicación",
                    available=1 if is_available else 0,
                    unavailable=0 if is_available else 1,
                )
            )
        else:
            stock.catalog_item_id = catalog.id
            stock.location = linked_tool.current_location or stock.location
            open_quantity = await session.scalar(
                text("""
                SELECT coalesce(sum(
                    movement.quantity - coalesce((
                        SELECT sum(settlement.quantity)
                        FROM tool_inventory_movements settlement
                        WHERE settlement.issue_id = movement.id
                    ), 0)
                ), 0)
                FROM tool_inventory_movements movement
                WHERE movement.inventory_id = :inventory_id
                  AND movement.kind = 'ISSUE'
                """),
                {"inventory_id": stock.id},
            )
            if open_quantity > 0:
                linked_tool.availability_status = "UNAVAILABLE"
                effective_status = "SIN STOCK"
            else:
                is_available = linked_tool.availability_status == "AVAILABLE"
                stock.available = 1 if is_available else 0
                stock.unavailable = 0 if is_available else 1
    elif linked_tool is not None:
        fail(
            "Un equipo identificado no puede convertirse en herramienta o consumible.",
            409,
        )
    item.catalog_item_id = catalog.id
    item.model_code = payload.model_code
    item.tool_code = payload.tool_code
    item.label = payload.label
    if item.tool_id is None:
        item.quantity = payload.quantity
    item.name = payload.name
    item.description = payload.description
    item.cabinet = payload.cabinet
    item.cabinet_detail = payload.cabinet_detail
    item.company = payload.company
    item.classification = payload.classification
    item.category = payload.category
    item.inventory_location_id = location.id if location else None
    item.location_text = location.name if location else payload.location_text
    item.status = effective_status
    item.observations = payload.observations
    session.add(item)
    await session.flush()

    if payload.replace_image_ids:
        images = (
            await session.scalars(
                select(ToolInventoryItemImageRecord).where(
                    ToolInventoryItemImageRecord.inventory_item_id == item.id,
                    ToolInventoryItemImageRecord.id.in_(payload.replace_image_ids),
                )
            )
        ).all()
        for image in images:
            await _remove_inventory_image_file(image)
            await session.delete(image)

    decoded_image = _decode_inventory_image(payload)
    if decoded_image is not None:
        content, media_type, file_name = decoded_image
        suffix = Path(file_name).suffix.lower()
        if not suffix:
            suffix = mimetypes.guess_extension(media_type) or ".bin"
        image_root = settings.resolved_attachment_root / "tool-inventory" / str(item.id)
        image_root.mkdir(parents=True, exist_ok=True)
        target = image_root / f"{uuid4().hex}{suffix}"
        target.write_bytes(content)
        session.add(
            ToolInventoryItemImageRecord(
                id=uuid4(),
                inventory_item_id=item.id,
                file_name=file_name,
                file_reference=storage_key(target, settings.resolved_attachment_root),
                media_type=media_type,
                byte_size=len(content),
                checksum=hashlib.sha256(content).hexdigest(),
            )
        )


def fail(message: str, code: int = 422):
    raise HTTPException(code, message)


@router.get("/tool-admin/items", dependencies=[Depends(admin)])
async def inventory_items(
    q: str | None = None,
    classification: str | None = None,
    status: str | None = None,
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
    session: AsyncSession = Depends(get_session),
):
    query = select(ToolInventoryItemRecord)
    if q:
        pattern = f"%{q.strip()}%"
        query = query.where(
            ToolInventoryItemRecord.name.ilike(pattern)
            | ToolInventoryItemRecord.tool_code.ilike(pattern)
            | ToolInventoryItemRecord.label.ilike(pattern)
            | ToolInventoryItemRecord.description.ilike(pattern)
            | ToolInventoryItemRecord.location_text.ilike(pattern)
        )
    if classification:
        query = query.where(ToolInventoryItemRecord.classification == classification)
    if status:
        query = query.where(ToolInventoryItemRecord.status == status)
    total = await session.scalar(
        select(func.count()).select_from(query.order_by(None).subquery())
    )
    rows = (
        await session.scalars(
            query.order_by(ToolInventoryItemRecord.name, ToolInventoryItemRecord.source_row_number)
            .offset(offset)
            .limit(limit)
        )
    ).all()
    item_ids = [item.id for item in rows]
    images = (
        (
            await session.scalars(
                select(ToolInventoryItemImageRecord)
                .where(ToolInventoryItemImageRecord.inventory_item_id.in_(item_ids))
                .order_by(ToolInventoryItemImageRecord.file_name)
            )
        ).all()
        if item_ids
        else []
    )
    locations = {}
    for item in rows:
        if item.inventory_location_id:
            locations[item.inventory_location_id] = item.location_text
    if locations:
        from modules.asset_management.infrastructure.postgres.domain_models import (
            InventoryLocationRecord,
        )

        locations.update(
            {
                location.id: location.name
                for location in (
                    await session.scalars(
                        select(InventoryLocationRecord).where(
                            InventoryLocationRecord.id.in_(locations)
                        )
                    )
                ).all()
            }
        )
    by_item = {}
    for image in images:
        by_item.setdefault(image.inventory_item_id, []).append(image)
    tool_ids = [item.tool_id for item in rows if item.tool_id]
    tools_by_id = (
        {
            tool.id: tool
            for tool in (
                await session.scalars(
                    select(ToolRecord).where(ToolRecord.id.in_(tool_ids))
                )
            ).all()
        }
        if tool_ids
        else {}
    )
    certifications_by_tool = {}
    if tool_ids:
        certifications = (
            await session.scalars(
                select(ToolCertificationRecord)
                .where(
                    ToolCertificationRecord.tool_id.in_(tool_ids),
                    ToolCertificationRecord.is_active.is_(True),
                )
                .order_by(
                    ToolCertificationRecord.tool_id,
                    ToolCertificationRecord.next_calibration_date.desc(),
                )
            )
        ).all()
        for certification in certifications:
            certifications_by_tool.setdefault(certification.tool_id, certification)
    return {
        "items": [
            _inventory_item_payload(
                item,
                locations.get(item.inventory_location_id),
                by_item.get(item.id, []),
                tools_by_id.get(item.tool_id),
                certifications_by_tool.get(item.tool_id),
            )
            for item in rows
        ],
        "total": total or 0,
        "limit": limit,
        "offset": offset,
    }


@router.get("/tool-admin/storage-locations", dependencies=[Depends(admin)])
async def storage_locations(session: AsyncSession = Depends(get_session)):
    rows = (
        await session.scalars(
            select(InventoryLocationRecord)
            .where(InventoryLocationRecord.is_active.is_(True))
            .order_by(InventoryLocationRecord.name)
        )
    ).all()
    return [
        {"id": str(row.id), "name": row.name, "description": row.description}
        for row in rows
    ]


@router.post("/tool-admin/items", dependencies=[Depends(admin)])
async def create_inventory_item(
    payload: InventoryItemWrite,
    session: AsyncSession = Depends(get_session),
):
    await session.execute(text("SELECT pg_advisory_xact_lock(20260916)"))
    next_row = await session.scalar(
        select(func.coalesce(func.max(ToolInventoryItemRecord.source_row_number), 0) + 1).where(
            ToolInventoryItemRecord.source_file == "ADMIN_UI"
        )
    )
    item = ToolInventoryItemRecord(
        id=uuid4(),
        source_file="ADMIN_UI",
        source_row_number=int(next_row or 1),
    )
    await _apply_inventory_item_payload(session, item, payload)
    await session.commit()
    return {"id": str(item.id)}


@router.put("/tool-admin/items/{item_id}", dependencies=[Depends(admin)])
async def update_inventory_item(
    item_id: UUID,
    payload: InventoryItemWrite,
    session: AsyncSession = Depends(get_session),
):
    item = await session.get(ToolInventoryItemRecord, item_id)
    if item is None:
        raise HTTPException(status_code=404, detail="Herramienta no encontrada.")
    await _apply_inventory_item_payload(session, item, payload)
    await session.commit()
    return {"id": str(item.id)}


@router.delete("/tool-admin/items/{item_id}", dependencies=[Depends(admin)])
async def delete_inventory_item(
    item_id: UUID,
    session: AsyncSession = Depends(get_session),
):
    item = await session.get(ToolInventoryItemRecord, item_id)
    if item is None:
        raise HTTPException(status_code=404, detail="Herramienta no encontrada.")
    images = (
        await session.scalars(
            select(ToolInventoryItemImageRecord).where(
                ToolInventoryItemImageRecord.inventory_item_id == item.id
            )
        )
    ).all()
    for image in images:
        await _remove_inventory_image_file(image)
    if item.tool_id:
        tool = await session.get(ToolRecord, item.tool_id)
        if tool is not None:
            tool.is_active = False
    await session.delete(item)
    await session.commit()
    return {"deleted": True, "id": str(item.id)}


@router.get("/tool-admin/items/{item_id}/images/{image_id}", dependencies=[Depends(admin)])
async def inventory_item_image(
    item_id: UUID,
    image_id: UUID,
    session: AsyncSession = Depends(get_session),
):
    image = await session.scalar(
        select(ToolInventoryItemImageRecord).where(
            ToolInventoryItemImageRecord.id == image_id,
            ToolInventoryItemImageRecord.inventory_item_id == item_id,
        )
    )
    if image is None:
        raise HTTPException(status_code=404, detail="Imagen no encontrada.")
    path = resolve_storage_reference(image.file_reference, settings.resolved_attachment_root)
    if path is None:
        raise HTTPException(status_code=404, detail="Archivo de imagen no encontrado.")
    return FileResponse(path, media_type=image.media_type)


@router.delete(
    "/tool-admin/items/{item_id}/images/{image_id}",
    dependencies=[Depends(admin)],
)
async def delete_inventory_item_image(
    item_id: UUID,
    image_id: UUID,
    session: AsyncSession = Depends(get_session),
):
    image = await session.scalar(
        select(ToolInventoryItemImageRecord).where(
            ToolInventoryItemImageRecord.id == image_id,
            ToolInventoryItemImageRecord.inventory_item_id == item_id,
        )
    )
    if image is None:
        raise HTTPException(status_code=404, detail="Imagen no encontrada.")
    await _remove_inventory_image_file(image)
    await session.delete(image)
    await session.commit()
    return {"deleted": True, "id": str(image.id)}


async def get_catalog(session, item_id, active=True):
    item = await session.get(ToolCatalogItemRecord, item_id)
    if item is None or (active and not item.is_active):
        fail("El elemento no existe o está desactivado.", 404)
    return item


@router.get("/tool-admin/catalog", dependencies=[Depends(admin)])
async def catalog(
    session: AsyncSession = Depends(get_session),
    include_inactive: bool = False,
):
    query = select(ToolCatalogItemRecord)
    if not include_inactive:
        query = query.where(ToolCatalogItemRecord.is_active.is_(True))
    records = (
        await session.scalars(
            query.order_by(
                ToolCatalogItemRecord.category, ToolCatalogItemRecord.name
            )
        )
    ).all()
    return [
        dict(
            id=str(r.id),
            name=r.name,
            category=r.category,
            default_unit=r.default_unit,
            requires_identified_unit=r.requires_identified_unit,
            is_active=r.is_active,
        )
        for r in records
    ]


async def save_catalog(session, payload, item=None):
    # Serializes normalized-name uniqueness checks, including concurrent creates.
    await session.execute(text("SELECT pg_advisory_xact_lock(20260915)"))
    duplicate = await session.scalar(
        select(ToolCatalogItemRecord).where(
            func.lower(ToolCatalogItemRecord.name) == payload.name.lower(),
            ToolCatalogItemRecord.category == payload.category,
        )
    )
    if duplicate and (item is None or duplicate.id != item.id):
        fail("Ya existe un elemento con ese nombre y categoría.", 409)
    if item is not None and (
        item.category != payload.category
        or item.requires_identified_unit != payload.requires_identified_unit
    ):
        used = await session.scalar(
            select(ToolInventoryRecord.id)
            .where(ToolInventoryRecord.catalog_item_id == item.id)
            .limit(1)
        )
        required = await session.scalar(
            select(OperationalChecklistItemRecord.id)
            .where(OperationalChecklistItemRecord.catalog_item_id == item.id)
            .limit(1)
        )
        if used or required:
            fail(
                "No se puede cambiar la clasificación de un elemento con existencias o checklists.",
                409,
            )
    if payload.category == "EQUIPMENT" and not payload.requires_identified_unit:
        fail("Los equipos requieren una unidad identificada.")
    item = item or ToolCatalogItemRecord(id=uuid4())
    for key, value in payload.model_dump().items():
        setattr(item, key, value)
    session.add(item)
    await session.commit()
    return {"id": str(item.id)}


@router.post("/tool-admin/catalog", dependencies=[Depends(admin)])
async def create_catalog(payload: CatalogWrite, session: AsyncSession = Depends(get_session)):
    return await save_catalog(session, payload)


@router.put("/tool-admin/catalog/{item_id}", dependencies=[Depends(admin)])
async def edit_catalog(
    item_id: UUID, payload: CatalogWrite, session: AsyncSession = Depends(get_session)
):
    return await save_catalog(session, payload, await get_catalog(session, item_id, active=False))


@router.get("/preventive-templates")
async def templates(asset_id: str | None = None, session: AsyncSession = Depends(get_session)):
    # Applicability comes from scopes, not from historical report executions.
    rows = await session.execute(
        text("""
        SELECT DISTINCT t.id, coalesce(nullif(t.activity_n3_summary,''),t.activity_n2,t.activity_n1) AS name,
          s.name AS subsystem,
          (SELECT r.id FROM maintenance_operational_checklist_revisions r WHERE r.maintenance_template_id=t.id AND r.status='ACTIVE' ORDER BY r.revision_number DESC LIMIT 1) AS revision_id,
          (SELECT count(*) FROM maintenance_operational_checklist_items i JOIN maintenance_operational_checklist_revisions r ON r.id=i.checklist_revision_id WHERE r.maintenance_template_id=t.id AND r.status='ACTIVE') AS item_count
        FROM maintenance_templates t JOIN subsystems s ON s.id=t.subsystem_id
        WHERE t.is_active AND (CAST(:asset_id AS text) IS NULL OR EXISTS (
          SELECT 1 FROM maintenance_template_scopes sc
          WHERE sc.maintenance_template_id=t.id AND (sc.asset_id=:asset_id OR EXISTS (
            SELECT 1 FROM asset_group_members gm WHERE gm.asset_group_id=sc.asset_group_id AND gm.asset_id=:asset_id
          ))
        )) ORDER BY subsystem,name
    """),
        {"asset_id": asset_id},
    )
    return [dict(r) for r in rows.mappings()]


@router.get("/preventive-templates/{template_id}")
async def template_detail(template_id: UUID, session: AsyncSession = Depends(get_session)):
    template = await session.get(MaintenanceTemplateRecord, template_id)
    if template is None:
        fail("Mantenimiento no encontrado.", 404)
    revisions = (
        await session.scalars(
            select(OperationalChecklistRevisionRecord)
            .where(OperationalChecklistRevisionRecord.maintenance_template_id == template_id)
            .order_by(OperationalChecklistRevisionRecord.revision_number.desc())
        )
    ).all()
    active = next((r for r in revisions if r.status == "ACTIVE"), None)
    writer = PostgresReportWriter(session)
    context = MaintenanceActivityRecord(maintenance_template_id=template_id)
    return dict(
        id=str(template_id),
        name=template.activity_n3_summary or template.activity_n2 or template.activity_n1,
        manual_reference=template.manual_reference,
        revision_id=str(active.id) if active else None,
        manual_checklist=await writer._manual_checklist(context),
        operational_checklist=await writer._operational_checklist(context),
        steps=await writer._template_steps(context),
        revisions=[
            dict(
                id=str(r.id),
                number=r.revision_number,
                status=r.status,
                created_at=r.created_at,
                created_by_user_id=r.created_by_user_id,
            )
            for r in revisions
        ],
    )


@router.put("/preventive-templates/{template_id}/checklist")
async def publish_checklist(
    template_id: UUID,
    payload: ChecklistWrite,
    user: UserDTO = Depends(admin),
    session: AsyncSession = Depends(get_session),
):
    template = await session.scalar(
        select(MaintenanceTemplateRecord)
        .where(MaintenanceTemplateRecord.id == template_id)
        .with_for_update()
    )
    if template is None:
        fail("Mantenimiento no encontrado.", 404)
    current = await session.scalar(
        select(OperationalChecklistRevisionRecord).where(
            OperationalChecklistRevisionRecord.maintenance_template_id == template_id,
            OperationalChecklistRevisionRecord.status == "ACTIVE",
        )
    )
    if (current.id if current else None) != payload.base_revision_id:
        fail("Otro administrador actualizó el checklist. Recarga antes de guardar.", 409)
    ids = [i.catalog_item_id for i in payload.items]
    if len(ids) != len(set(ids)):
        fail("No repitas un elemento en el checklist.")
    catalogs = [await get_catalog(session, i) for i in ids]
    number = await session.scalar(
        select(func.max(OperationalChecklistRevisionRecord.revision_number)).where(
            OperationalChecklistRevisionRecord.maintenance_template_id == template_id
        )
    )
    if current:
        current.status = "ARCHIVED"
    revision = OperationalChecklistRevisionRecord(
        id=uuid4(),
        maintenance_template_id=template_id,
        revision_number=(number or 0) + 1,
        status="ACTIVE",
        created_by_user_id=user.id,
    )
    session.add(revision)
    await session.flush()
    for sequence, (item, catalog) in enumerate(zip(payload.items, catalogs), 1):
        session.add(
            OperationalChecklistItemRecord(
                checklist_revision_id=revision.id,
                catalog_item_id=catalog.id,
                category=catalog.category,
                item_name=catalog.name,
                default_quantity=item.default_quantity,
                unit=item.unit.strip(),
                is_required=True,
                sequence=sequence,
                notes=item.notes,
            )
        )
    await session.commit()
    return {"id": str(revision.id)}


@router.get("/tool-admin/inventory", dependencies=[Depends(admin)])
async def inventory(session: AsyncSession = Depends(get_session)):
    rows = await session.execute(
        text("""SELECT i.*, c.name,c.category,c.default_unit,t.serial_number,t.model,t.brand,
        (SELECT max(next_calibration_date) FROM tool_certifications tc WHERE tc.tool_id=t.id AND tc.is_active) AS calibration_until
        FROM tool_inventory i JOIN tool_catalog_items c ON c.id=i.catalog_item_id
        LEFT JOIN tools t ON t.id=i.tool_id ORDER BY c.name,i.location,t.serial_number""")
    )
    return [dict(r) for r in rows.mappings()]


@router.post("/tool-admin/inventory", dependencies=[Depends(admin)])
async def create_stock(payload: StockWrite, session: AsyncSession = Depends(get_session)):
    await session.execute(text("SELECT pg_advisory_xact_lock(20260915)"))
    catalog = await get_catalog(session, payload.catalog_item_id)
    if catalog.requires_identified_unit != bool(payload.serial_number):
        fail(
            "Indica un código o número de serie para las unidades identificadas; omítelo para existencias por cantidad."
        )
    tool_id = None
    if payload.serial_number:
        if await session.scalar(
            select(ToolRecord.id).where(ToolRecord.serial_number == payload.serial_number)
        ):
            fail("Ese código o serie ya existe.", 409)
        tool = ToolRecord(
            id=uuid4(),
            catalog_item_id=catalog.id,
            name=catalog.name,
            serial_number=payload.serial_number,
            model=payload.model,
            brand=payload.brand,
            availability_status="UNAVAILABLE",
            current_location=payload.location,
        )
        session.add(tool)
        await session.flush()
        tool_id = tool.id
        next_row = await session.scalar(
            select(func.coalesce(func.max(ToolInventoryItemRecord.source_row_number), 0) + 1)
            .where(ToolInventoryItemRecord.source_file == "ADMIN_IDENTIFIED_TOOLS")
        )
        session.add(
            ToolInventoryItemRecord(
                id=uuid4(),
                source_file="ADMIN_IDENTIFIED_TOOLS",
                source_row_number=int(next_row or 1),
                catalog_item_id=catalog.id,
                tool_id=tool.id,
                model_code=payload.model,
                tool_code=payload.serial_number,
                label=payload.serial_number,
                quantity=1,
                name=catalog.name,
                company=payload.brand,
                classification="EQUIPO",
                category="INSTRUMENTO",
                location_text=payload.location,
                status="SIN STOCK",
            )
        )
    else:
        existing = await session.scalar(
            select(ToolInventoryRecord).where(
                ToolInventoryRecord.catalog_item_id == catalog.id,
                ToolInventoryRecord.location == payload.location,
                ToolInventoryRecord.tool_id.is_(None),
            )
        )
        if existing:
            return {"id": str(existing.id)}
    stock = ToolInventoryRecord(
        id=uuid4(),
        catalog_item_id=catalog.id,
        tool_id=tool_id,
        location=payload.location,
        available=0,
        unavailable=0,
    )
    session.add(stock)
    await session.commit()
    return {"id": str(stock.id)}


@router.get("/tool-admin/people", dependencies=[Depends(admin)])
async def people(session: AsyncSession = Depends(get_session)):
    rows = await session.execute(text("SELECT id, name FROM users WHERE is_active ORDER BY name"))
    return [dict(r) for r in rows.mappings()]


@router.get("/tool-admin/movements", dependencies=[Depends(admin)])
async def movements(
    offset: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=200),
    open_only: bool = False,
    session: AsyncSession = Depends(get_session),
):
    rows = await session.execute(
        text("""SELECT m.*,c.name,i.location,t.serial_number,u.name AS responsible_name,
        m.quantity-coalesce((SELECT sum(x.quantity) FROM tool_inventory_movements x WHERE x.issue_id=m.id),0) AS outstanding
        FROM tool_inventory_movements m JOIN tool_inventory i ON i.id=m.inventory_id
        JOIN tool_catalog_items c ON c.id=i.catalog_item_id LEFT JOIN tools t ON t.id=i.tool_id
        LEFT JOIN users u ON u.id=m.responsible_user_id
        WHERE NOT :open_only OR (m.kind='ISSUE' AND m.quantity > coalesce((SELECT sum(x.quantity) FROM tool_inventory_movements x WHERE x.issue_id=m.id),0))
        ORDER BY m.created_at DESC,m.id LIMIT :limit OFFSET :offset"""),
        dict(open_only=open_only, limit=limit, offset=offset),
    )
    return [dict(r) for r in rows.mappings()]


@router.post("/tool-admin/movements")
async def move(
    payload: MovementWrite,
    user: UserDTO = Depends(admin),
    session: AsyncSession = Depends(get_session),
):
    stock = await session.scalar(
        select(ToolInventoryRecord)
        .where(ToolInventoryRecord.id == payload.inventory_id)
        .with_for_update()
    )
    if stock is None:
        fail("Existencia no encontrada.", 404)
    previous = await session.get(ToolMovementRecord, payload.id)
    if previous:
        same = (
            previous.inventory_id == payload.inventory_id
            and previous.kind == payload.kind
            and previous.quantity == payload.quantity
            and previous.issue_id == payload.issue_id
            and previous.responsible_user_id == payload.responsible_user_id
            and previous.activity_ids == [str(i) for i in payload.activity_ids]
            and previous.notes == payload.notes
            and previous.actor_user_id == user.id
        )
        if not same:
            fail("Este identificador corresponde a otro movimiento.", 409)
        return {"id": str(previous.id)}
    catalog = await get_catalog(session, stock.catalog_item_id, active=False)
    if stock.tool_id and payload.quantity != 1:
        fail("Una unidad identificada requiere cantidad 1.")
    if payload.kind in ("RECEIPT", "ISSUE", "ADJUST_ADD") and not catalog.is_active:
        fail("El elemento está desactivado.")
    if payload.kind == "ISSUE":
        if not payload.responsible_user_id:
            fail("Selecciona al responsable de la entrega.")
        valid = await session.scalar(
            text("SELECT id FROM users WHERE id=:id AND is_active"),
            {"id": payload.responsible_user_id},
        )
        if not valid:
            fail("Responsable no válido.")
    elif payload.responsible_user_id:
        fail("El responsable se registra en la salida de origen.")
    if payload.activity_ids:
        count = await session.scalar(
            select(func.count())
            .select_from(MaintenanceActivityRecord)
            .where(MaintenanceActivityRecord.id.in_(payload.activity_ids))
        )
        if count != len(set(payload.activity_ids)):
            fail("Alguno de los mantenimientos no existe.")
    settlement = payload.kind in ("RETURN", "CONSUMED", "DAMAGED", "LOST")
    if settlement:
        issue = (
            await session.get(ToolMovementRecord, payload.issue_id) if payload.issue_id else None
        )
        if issue is None or issue.kind != "ISSUE" or issue.inventory_id != stock.id:
            fail("Selecciona la salida que se está devolviendo o regularizando.")
        settled = await session.scalar(
            select(func.coalesce(func.sum(ToolMovementRecord.quantity), 0)).where(
                ToolMovementRecord.issue_id == issue.id
            )
        )
        if payload.quantity > issue.quantity - settled:
            fail("La cantidad supera lo pendiente de devolver.", 409)
        if payload.kind == "CONSUMED" and catalog.category != "CONSUMABLE":
            fail("Solo los consumibles pueden registrarse como consumidos.")
    elif payload.issue_id:
        fail("Este movimiento no admite una salida de origen.")
    if payload.kind.startswith("ADJUST") and not (payload.notes or "").strip():
        fail("Indica el motivo del ajuste.")
    if payload.kind in ("ISSUE", "ADJUST_REMOVE"):
        if stock.available < payload.quantity:
            fail("No hay cantidad disponible suficiente.", 409)
        stock.available -= payload.quantity
    elif payload.kind in ("RECEIPT", "RETURN", "ADJUST_ADD"):
        if stock.tool_id and payload.kind != "RETURN":
            open_quantity = await session.scalar(
                text("""SELECT coalesce(sum(m.quantity-coalesce((SELECT sum(x.quantity) FROM tool_inventory_movements x WHERE x.issue_id=m.id),0)),0)
                FROM tool_inventory_movements m WHERE m.inventory_id=:id AND m.kind='ISSUE'"""),
                {"id": stock.id},
            )
            if stock.available + stock.unavailable + open_quantity > 0:
                fail("La unidad ya está en inventario o entregada.", 409)
        stock.available += payload.quantity
    elif payload.kind == "DAMAGED":
        stock.unavailable += payload.quantity
    if stock.tool_id:
        inventory_status = (
            "DISPONIBLE"
            if stock.available > 0
            else ("AVERIADO" if stock.unavailable > 0 else "SIN STOCK")
        )
        await session.execute(
            update(ToolRecord)
            .where(ToolRecord.id == stock.tool_id)
                .values(availability_status="AVAILABLE" if stock.available > 0 else "UNAVAILABLE")
        )
        await session.execute(
            update(ToolInventoryItemRecord)
            .where(ToolInventoryItemRecord.tool_id == stock.tool_id)
            .values(quantity=1, status=inventory_status, location_text=stock.location)
        )
    session.add(
        ToolMovementRecord(
            **payload.model_dump(exclude={"activity_ids"}),
            activity_ids=[str(i) for i in payload.activity_ids],
            actor_user_id=user.id,
        )
    )
    await session.commit()
    return {"id": str(payload.id)}
