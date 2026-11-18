import base64
import binascii
import hashlib
import mimetypes
from pathlib import Path
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from fastapi.responses import FileResponse
from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_session, uses_postgres
from modules.asset_management.infrastructure.postgres.catalog_models import (
    AssetStatusRecord,
    EquipmentCategoryRecord,
)
from modules.asset_management.infrastructure.postgres.models import AssetImageRecord, AssetRecord
from modules.asset_management.infrastructure.postgres.domain_models import InventoryLocationRecord
from modules.asset_management.infrastructure.postgres.repository import PostgresAssetRepository
from modules.asset_management.infrastructure.seed_repository import asset_repository
from modules.asset_management.interfaces.schemas import (
    AssetAdministrationCatalogDTO,
    AssetCatalogOptionDTO,
    AssetComponentChangesRequest,
    AssetDTO,
    AssetHistoryEntryDTO,
    AssetImageDTO,
    AssetImageWriteRequest,
    AssetTreeNodeDTO,
    AssetWriteRequest,
    ComponentDetailDTO,
    ComponentMovementDTO,
    ComponentWriteRequest,
    EquipmentSlotDTO,
    EquipmentSlotOccupancyRequest,
    EquipmentSlotWriteRequest,
    EquipmentCategoryOptionDTO,
    GeographicLocationOptionDTO,
    StockAssetDTO,
    StockAssetWriteRequest,
    StockAdministrationCatalogDTO,
)
from modules.identity_access.interfaces.dependencies import get_current_user, require_roles
from modules.identity_access.interfaces.schemas import UserDTO
from modules.organizational_context.infrastructure.postgres.models import SubsystemRecord
from modules.organizational_context.infrastructure.postgres.operational_models import (
    GeographicLocationRecord,
)
from shared_kernel.schemas import Page, UserRole
from shared_kernel.storage import resolve_storage_reference, storage_key

router = APIRouter(
    prefix="/assets",
    tags=["assets"],
    dependencies=[Depends(get_current_user)],
)


def _administrator(user: UserDTO) -> None:
    # The authenticated module permission dependency already requires WRITE access.
    # Keep this hook so existing endpoint call sites remain explicit.
    _ = user


def _decode_image(payload: AssetImageWriteRequest) -> bytes:
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
    media_type = payload.media_type or mimetypes.guess_type(payload.file_name)[0]
    if not media_type or not media_type.startswith("image/"):
        raise HTTPException(status_code=422, detail="El archivo debe ser una imagen.")
    return content


def _image_dto(image: AssetImageRecord) -> AssetImageDTO:
    return AssetImageDTO(
        id=image.id,
        file_name=image.file_name,
        media_type=image.media_type,
        byte_size=image.byte_size,
        caption=image.caption,
        is_primary=image.is_primary,
        sort_order=image.sort_order,
        url=f"/api/v1/assets/{image.asset_id}/images/{image.id}",
    )


@router.get("", response_model=Page[AssetDTO])
async def list_assets(
    q: str | None = None,
    business_anchor: bool | None = Query(default=True),
    subsystem: str | None = None,
    category: str | None = None,
    status: str | None = None,
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    session: AsyncSession = Depends(get_session),
) -> Page[AssetDTO]:
    if uses_postgres():
        assets, total = await PostgresAssetRepository(session).list_assets(
            q=q,
            business_anchor=business_anchor,
            subsystem=subsystem,
            category=category,
            status=status,
            limit=limit,
            offset=offset,
        )
        return Page(items=assets, total=total, limit=limit, offset=offset)
    else:
        assets = asset_repository.list_assets(q=q, business_anchor=business_anchor)
        if subsystem:
            assets = [item for item in assets if item.subsystem.casefold() == subsystem.casefold()]
        if category:
            assets = [item for item in assets if item.category.casefold() == category.casefold()]
        if status:
            assets = [item for item in assets if item.status.casefold() == status.casefold()]
    return Page(items=assets[offset : offset + limit], total=len(assets), limit=limit, offset=offset)


@router.get("/stock", response_model=Page[StockAssetDTO])
async def list_stock_assets(
    q: str | None = None,
    subsystem: str | None = None,
    status: str | None = None,
    inventory_location: str | None = None,
    limit: int = Query(default=100, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    session: AsyncSession = Depends(get_session),
    _: UserDTO = Depends(require_roles(UserRole.ADMINISTRATOR)),
) -> Page[StockAssetDTO]:
    if not uses_postgres():
        return Page(items=[], total=0, limit=limit, offset=offset)
    assets, total = await PostgresAssetRepository(session).list_stock_assets(
        q=q,
        subsystem=subsystem,
        status=status,
        inventory_location=inventory_location,
        limit=limit,
        offset=offset,
    )
    return Page(items=assets, total=total, limit=limit, offset=offset)


@router.get("/stock/administration/catalog", response_model=StockAdministrationCatalogDTO)
async def stock_administration_catalog(
    session: AsyncSession = Depends(get_session),
    _: UserDTO = Depends(require_roles(UserRole.ADMINISTRATOR)),
) -> StockAdministrationCatalogDTO:
    if not uses_postgres():
        raise HTTPException(status_code=501, detail="La administración requiere PostgreSQL.")
    categories = list((await session.scalars(
        select(EquipmentCategoryRecord)
        .where(EquipmentCategoryRecord.is_active.is_(True))
        .order_by(EquipmentCategoryRecord.name_n1, EquipmentCategoryRecord.name_n2)
    )).all())
    subsystems = list((await session.scalars(
        select(SubsystemRecord)
        .where(SubsystemRecord.is_active.is_(True))
        .order_by(SubsystemRecord.code)
    )).all())
    statuses = list((await session.scalars(
        select(AssetStatusRecord)
        .where(AssetStatusRecord.is_active.is_(True))
        .order_by(AssetStatusRecord.name)
    )).all())
    locations = list((await session.scalars(
        select(InventoryLocationRecord)
        .where(InventoryLocationRecord.is_active.is_(True))
        .order_by(InventoryLocationRecord.name)
    )).all())
    return StockAdministrationCatalogDTO(
        categories=[EquipmentCategoryOptionDTO(
            id=item.id, subsystem_id=item.subsystem_id,
            name_n1=item.name_n1, name_n2=item.name_n2,
        ) for item in categories],
        subsystems=[AssetCatalogOptionDTO(id=item.id, code=item.code, name=item.name) for item in subsystems],
        statuses=[AssetCatalogOptionDTO(id=item.id, code=item.code, name=item.name) for item in statuses],
        inventory_locations=[AssetCatalogOptionDTO(id=item.id, name=item.name) for item in locations],
    )


@router.get("/stock/{asset_id}", response_model=StockAssetDTO)
async def get_stock_asset(
    asset_id: str,
    session: AsyncSession = Depends(get_session),
    _: UserDTO = Depends(require_roles(UserRole.ADMINISTRATOR)),
) -> StockAssetDTO:
    if not uses_postgres():
        raise HTTPException(status_code=501, detail="La administración requiere PostgreSQL.")
    asset = await PostgresAssetRepository(session).get_stock_asset(asset_id)
    if asset is None:
        raise HTTPException(status_code=404, detail="El elemento de stock no existe.")
    return asset


@router.post("/stock", response_model=StockAssetDTO, status_code=status.HTTP_201_CREATED)
async def create_stock_asset(
    payload: StockAssetWriteRequest,
    session: AsyncSession = Depends(get_session),
    _: UserDTO = Depends(require_roles(UserRole.ADMINISTRATOR)),
) -> StockAssetDTO:
    if not uses_postgres():
        raise HTTPException(status_code=501, detail="La administración requiere PostgreSQL.")
    try:
        asset = await PostgresAssetRepository(session).create_stock_asset(payload)
        await session.commit()
        return asset
    except (IntegrityError, ValueError) as error:
        await session.rollback()
        detail = str(error) if isinstance(error, ValueError) else "El código ya está registrado."
        raise HTTPException(status_code=409, detail=detail) from error


@router.put("/stock/{asset_id}", response_model=StockAssetDTO)
async def update_stock_asset(
    asset_id: str,
    payload: StockAssetWriteRequest,
    session: AsyncSession = Depends(get_session),
    _: UserDTO = Depends(require_roles(UserRole.ADMINISTRATOR)),
) -> StockAssetDTO:
    if not uses_postgres():
        raise HTTPException(status_code=501, detail="La administración requiere PostgreSQL.")
    try:
        asset = await PostgresAssetRepository(session).update_stock_asset(asset_id, payload)
        await session.commit()
        return asset
    except (IntegrityError, ValueError) as error:
        await session.rollback()
        detail = str(error) if isinstance(error, ValueError) else "El código ya está registrado."
        raise HTTPException(status_code=409, detail=detail) from error


@router.get("/administration/catalog", response_model=AssetAdministrationCatalogDTO)
async def administration_catalog(
    session: AsyncSession = Depends(get_session),
    user: UserDTO = Depends(get_current_user),
) -> AssetAdministrationCatalogDTO:
    _administrator(user)
    if not uses_postgres():
        raise HTTPException(status_code=501, detail="La administración requiere PostgreSQL.")
    categories = list(
        (
            await session.scalars(
                select(EquipmentCategoryRecord)
                .where(EquipmentCategoryRecord.is_active.is_(True))
                .order_by(EquipmentCategoryRecord.name_n1, EquipmentCategoryRecord.name_n2)
            )
        ).all()
    )
    subsystems = list(
        (
            await session.scalars(
                select(SubsystemRecord)
                .where(SubsystemRecord.is_active.is_(True))
                .order_by(SubsystemRecord.code)
            )
        ).all()
    )
    statuses = list(
        (
            await session.scalars(
                select(AssetStatusRecord)
                .where(AssetStatusRecord.is_active.is_(True))
                .order_by(AssetStatusRecord.name)
            )
        ).all()
    )
    locations = list(
        (
            await session.scalars(
                select(GeographicLocationRecord)
                .where(GeographicLocationRecord.is_active.is_(True))
                .order_by(GeographicLocationRecord.level, GeographicLocationRecord.full_path)
            )
        ).all()
    )
    return AssetAdministrationCatalogDTO(
        categories=[
            EquipmentCategoryOptionDTO(
                id=item.id,
                subsystem_id=item.subsystem_id,
                name_n1=item.name_n1,
                name_n2=item.name_n2,
            )
            for item in categories
        ],
        subsystems=[
            AssetCatalogOptionDTO(id=item.id, code=item.code, name=item.name)
            for item in subsystems
        ],
        statuses=[
            AssetCatalogOptionDTO(id=item.id, code=item.code, name=item.name)
            for item in statuses
        ],
        locations=[
            GeographicLocationOptionDTO(
                id=item.id,
                name=item.name,
                level=item.level,
                parent_id=item.parent_location_id,
                full_path=item.full_path,
            )
            for item in locations
        ],
    )


@router.post("", response_model=AssetDTO, status_code=status.HTTP_201_CREATED)
async def create_asset(
    payload: AssetWriteRequest,
    session: AsyncSession = Depends(get_session),
    user: UserDTO = Depends(get_current_user),
) -> AssetDTO:
    _administrator(user)
    if not uses_postgres():
        raise HTTPException(status_code=501, detail="La administración requiere PostgreSQL.")
    try:
        asset = await PostgresAssetRepository(session).create_asset(payload)
        await session.commit()
        return asset
    except (IntegrityError, ValueError) as error:
        await session.rollback()
        detail = str(error) if isinstance(error, ValueError) else "El código del equipo ya está registrado."
        raise HTTPException(status_code=409, detail=detail) from error


@router.put("/{asset_id}", response_model=AssetDTO)
async def update_asset(
    asset_id: str,
    payload: AssetWriteRequest,
    session: AsyncSession = Depends(get_session),
    user: UserDTO = Depends(get_current_user),
) -> AssetDTO:
    _administrator(user)
    if not uses_postgres():
        raise HTTPException(status_code=501, detail="La administración requiere PostgreSQL.")
    try:
        asset = await PostgresAssetRepository(session).update_asset(asset_id, payload)
        await session.commit()
        return asset
    except (IntegrityError, ValueError) as error:
        await session.rollback()
        detail = str(error) if isinstance(error, ValueError) else "El código del equipo ya está registrado."
        raise HTTPException(status_code=409, detail=detail) from error


@router.delete("/{asset_id}", status_code=status.HTTP_204_NO_CONTENT)
async def archive_asset(
    asset_id: str,
    session: AsyncSession = Depends(get_session),
    user: UserDTO = Depends(get_current_user),
) -> Response:
    _administrator(user)
    if not uses_postgres():
        raise HTTPException(status_code=501, detail="La administración requiere PostgreSQL.")
    try:
        await PostgresAssetRepository(session).archive_asset(asset_id)
        await session.commit()
        return Response(status_code=status.HTTP_204_NO_CONTENT)
    except ValueError as error:
        await session.rollback()
        raise HTTPException(status_code=404, detail=str(error)) from error


@router.post(
    "/{asset_id}/images",
    response_model=AssetImageDTO,
    status_code=status.HTTP_201_CREATED,
)
async def add_asset_image(
    asset_id: str,
    payload: AssetImageWriteRequest,
    session: AsyncSession = Depends(get_session),
    user: UserDTO = Depends(get_current_user),
) -> AssetImageDTO:
    _administrator(user)
    if not uses_postgres():
        raise HTTPException(status_code=501, detail="La administración requiere PostgreSQL.")
    asset = await session.get(AssetRecord, asset_id)
    if asset is None:
        raise HTTPException(status_code=404, detail="Activo no encontrado.")
    if not asset.is_business_anchor and user.role != UserRole.ADMINISTRATOR:
        raise HTTPException(status_code=403, detail="Solo el administrador puede agregar imágenes de componentes.")
    content = _decode_image(payload)
    existing_count = await session.scalar(
        select(func.count())
        .select_from(AssetImageRecord)
        .where(AssetImageRecord.asset_id == asset_id)
    ) or 0
    is_primary = payload.is_primary or existing_count == 0
    if is_primary:
        await session.execute(
            update(AssetImageRecord)
            .where(AssetImageRecord.asset_id == asset_id)
            .values(is_primary=False)
        )
    file_name = Path(payload.file_name).name or "equipo.jpg"
    suffix = (
        Path(file_name).suffix.lower()
        or mimetypes.guess_extension(payload.media_type)
        or ".bin"
    )
    image_root = settings.resolved_attachment_root / "assets" / asset_id
    image_root.mkdir(parents=True, exist_ok=True)
    target = image_root / f"{uuid4().hex}{suffix}"
    target.write_bytes(content)
    image = AssetImageRecord(
        id=uuid4(),
        asset_id=asset_id,
        file_name=file_name,
        file_reference=storage_key(target, settings.resolved_attachment_root),
        media_type=payload.media_type,
        byte_size=len(content),
        checksum=hashlib.sha256(content).hexdigest(),
        caption=payload.caption.strip() if payload.caption else None,
        is_primary=is_primary,
        sort_order=existing_count,
    )
    session.add(image)
    await session.commit()
    return _image_dto(image)


@router.get("/{asset_id}/images/{image_id}")
async def asset_image_content(
    asset_id: str,
    image_id: UUID,
    session: AsyncSession = Depends(get_session),
):
    if not uses_postgres():
        raise HTTPException(status_code=404, detail="Imagen no encontrada.")
    image = await session.scalar(
        select(AssetImageRecord).where(
            AssetImageRecord.id == image_id,
            AssetImageRecord.asset_id == asset_id,
        )
    )
    if image is None:
        raise HTTPException(status_code=404, detail="Imagen no encontrada.")
    path = resolve_storage_reference(image.file_reference, settings.resolved_attachment_root)
    if path is None:
        raise HTTPException(status_code=404, detail="Archivo de imagen no encontrado.")
    return FileResponse(path, media_type=image.media_type, filename=image.file_name)


@router.delete("/{asset_id}/images/{image_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_asset_image(
    asset_id: str,
    image_id: UUID,
    session: AsyncSession = Depends(get_session),
    user: UserDTO = Depends(get_current_user),
) -> Response:
    _administrator(user)
    if not uses_postgres():
        raise HTTPException(status_code=404, detail="Imagen no encontrada.")
    image = await session.scalar(
        select(AssetImageRecord).where(
            AssetImageRecord.id == image_id,
            AssetImageRecord.asset_id == asset_id,
        )
    )
    if image is None:
        raise HTTPException(status_code=404, detail="Imagen no encontrada.")
    was_primary = image.is_primary
    path = resolve_storage_reference(image.file_reference, settings.resolved_attachment_root)
    if path is not None:
        path.unlink(missing_ok=True)
    await session.delete(image)
    await session.flush()
    if was_primary:
        replacement = await session.scalar(
            select(AssetImageRecord)
            .where(AssetImageRecord.asset_id == asset_id)
            .order_by(AssetImageRecord.sort_order, AssetImageRecord.created_at)
        )
        if replacement is not None:
            replacement.is_primary = True
    await session.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/{asset_id}", response_model=AssetDTO)
async def get_asset(
    asset_id: str,
    session: AsyncSession = Depends(get_session),
) -> AssetDTO:
    if uses_postgres():
        asset = await PostgresAssetRepository(session).get_asset(asset_id)
    else:
        asset = asset_repository.get_asset(asset_id)
    if asset is None:
        raise HTTPException(status_code=404, detail="Asset not found")
    return asset


@router.get("/{asset_id}/component-detail", response_model=ComponentDetailDTO)
async def get_component_detail(
    asset_id: str, session: AsyncSession = Depends(get_session),
) -> ComponentDetailDTO:
    if uses_postgres():
        component = await PostgresAssetRepository(session).get_component(asset_id)
    else:
        asset = asset_repository.get_asset(asset_id)
        component = ComponentDetailDTO(asset=asset) if asset and not asset.is_business_anchor else None
    if component is None:
        raise HTTPException(status_code=404, detail="Componente no encontrado.")
    return component


@router.put("/{asset_id}/component-detail", response_model=ComponentDetailDTO)
async def update_component_detail(
    asset_id: str, payload: ComponentWriteRequest,
    session: AsyncSession = Depends(get_session),
    user: UserDTO = Depends(get_current_user),
) -> ComponentDetailDTO:
    if user.role != UserRole.ADMINISTRATOR:
        raise HTTPException(status_code=403, detail="Solo el administrador puede editar componentes.")
    if not uses_postgres():
        raise HTTPException(status_code=501, detail="La administración requiere PostgreSQL.")
    try:
        result = await PostgresAssetRepository(session).update_component(asset_id, payload)
        if result is None:
            raise HTTPException(status_code=404, detail="Componente no encontrado.")
        await session.commit()
        return result
    except ValueError as error:
        await session.rollback()
        raise HTTPException(status_code=422, detail=str(error)) from error
    except IntegrityError as error:
        await session.rollback()
        raise HTTPException(status_code=409, detail="No se pudo guardar el componente. Revisa la serie.") from error


@router.get("/{asset_id}/movements", response_model=Page[ComponentMovementDTO])
async def get_component_movements(
    asset_id: str,
    limit: int = Query(default=15, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    session: AsyncSession = Depends(get_session),
) -> Page[ComponentMovementDTO]:
    if uses_postgres():
        result = await PostgresAssetRepository(session).component_movements(asset_id, limit, offset)
    else:
        asset = asset_repository.get_asset(asset_id)
        result = ([], 0) if asset and not asset.is_business_anchor else None
    if result is None:
        raise HTTPException(status_code=404, detail="Componente no encontrado.")
    items, total = result
    return Page(items=items, total=total, limit=limit, offset=offset)


@router.get("/{asset_id}/component-editor-options")
async def component_editor_options(asset_id: str, session: AsyncSession = Depends(get_session)):
    if not uses_postgres():
        return {"classifications": [], "statuses": []}
    try:
        return await PostgresAssetRepository(session).component_editor_options(asset_id)
    except ValueError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error


@router.get("/{asset_id}/internal-slots", response_model=list[EquipmentSlotDTO])
async def get_equipment_slots(asset_id: str, session: AsyncSession = Depends(get_session)):
    if not uses_postgres():
        asset = asset_repository.get_asset(asset_id)
        slots = [] if asset and asset.is_business_anchor else None
    else:
        slots = await PostgresAssetRepository(session).equipment_slots(asset_id)
    if slots is None:
        raise HTTPException(status_code=404, detail="Equipo no encontrado.")
    return slots


def _require_slot_administrator(user: UserDTO) -> None:
    if user.role != UserRole.ADMINISTRATOR:
        raise HTTPException(status_code=403, detail="Solo el administrador puede gestionar espacios internos.")
    if not uses_postgres():
        raise HTTPException(status_code=501, detail="La administración requiere PostgreSQL.")


@router.post("/{asset_id}/internal-slots", response_model=list[EquipmentSlotDTO], status_code=201)
async def create_equipment_slot(
    asset_id: str, payload: EquipmentSlotWriteRequest,
    session: AsyncSession = Depends(get_session), user: UserDTO = Depends(get_current_user),
):
    _require_slot_administrator(user)
    try:
        slots = await PostgresAssetRepository(session).create_equipment_slot(asset_id, payload)
        if slots is None:
            raise HTTPException(status_code=404, detail="Equipo no encontrado.")
        await session.commit()
        return slots
    except ValueError as error:
        await session.rollback()
        raise HTTPException(status_code=422, detail=str(error)) from error


@router.put("/{asset_id}/internal-slots/{slot_id}", response_model=list[EquipmentSlotDTO])
async def place_equipment_component(
    asset_id: str, slot_id: UUID, payload: EquipmentSlotOccupancyRequest,
    session: AsyncSession = Depends(get_session), user: UserDTO = Depends(get_current_user),
):
    _require_slot_administrator(user)
    try:
        slots = await PostgresAssetRepository(session).place_equipment_component(
            asset_id, slot_id, payload, user.id
        )
        await session.commit()
        return slots
    except ValueError as error:
        await session.rollback()
        raise HTTPException(status_code=422, detail=str(error)) from error


@router.get("/{asset_id}/tree", response_model=list[AssetTreeNodeDTO])
async def get_asset_tree(
    asset_id: str,
    session: AsyncSession = Depends(get_session),
) -> list[AssetTreeNodeDTO]:
    if uses_postgres():
        repository = PostgresAssetRepository(session)
        if await repository.get_asset(asset_id) is None:
            raise HTTPException(status_code=404, detail="Asset not found")
        return await repository.get_tree(asset_id)

    asset = asset_repository.get_asset(asset_id)
    if asset is None:
        raise HTTPException(status_code=404, detail="Asset not found")
    return [
        AssetTreeNodeDTO(
            id=f"{asset.id}-child-{index}",
            name=name,
            category="Componente",
            asset_type="Componente",
            status="Activo",
            parent_id=asset.id,
            depth=1,
        )
        for index, name in enumerate(asset.children)
    ]


@router.patch(
    "/{asset_id}/components",
    response_model=list[AssetTreeNodeDTO],
)
async def apply_component_changes(
    asset_id: str,
    payload: AssetComponentChangesRequest,
    session: AsyncSession = Depends(get_session),
    user: UserDTO = Depends(get_current_user),
) -> list[AssetTreeNodeDTO]:
    if not uses_postgres():
        raise HTTPException(status_code=501, detail="La administración requiere PostgreSQL.")
    repository = PostgresAssetRepository(session)
    try:
        if user.role != UserRole.ADMINISTRATOR and any(
            operation.action != "CREATE" or operation.new_type_name is not None for operation in payload.operations
        ):
            raise HTTPException(
                status_code=403,
                detail="Solo el administrador puede gestionar modelos, editar, mover o eliminar componentes.",
            )
        tree = await repository.apply_component_changes(asset_id, payload.operations, user_id=user.id)
        await session.commit()
        return tree
    except ValueError as error:
        await session.rollback()
        raise HTTPException(status_code=422, detail=str(error)) from error
    except IntegrityError as error:
        await session.rollback()
        raise HTTPException(
            status_code=409,
            detail="No se pudo guardar: el componente tiene referencias protegidas o un identificador duplicado.",
        ) from error


@router.get("/{asset_id}/history", response_model=list[AssetHistoryEntryDTO])
async def get_asset_history(
    asset_id: str,
    session: AsyncSession = Depends(get_session),
) -> list[AssetHistoryEntryDTO]:
    if uses_postgres():
        repository = PostgresAssetRepository(session)
        asset = await repository.get_asset(asset_id)
        if asset is None:
            raise HTTPException(status_code=404, detail="Asset not found")
        return await repository.get_history(asset_id)

    if asset_repository.get_asset(asset_id) is None:
        raise HTTPException(status_code=404, detail="Asset not found")
    return asset_repository.get_history(asset_id)
