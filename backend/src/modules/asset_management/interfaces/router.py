from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session, uses_postgres
from modules.asset_management.infrastructure.seed_repository import asset_repository
from modules.asset_management.infrastructure.postgres.repository import PostgresAssetRepository
from modules.asset_management.interfaces.schemas import (
    AssetComponentChangesRequest,
    AssetDTO,
    AssetHistoryEntryDTO,
    AssetTreeNodeDTO,
    StockAssetDTO,
)
from modules.identity_access.interfaces.dependencies import get_current_user, require_roles
from modules.identity_access.interfaces.schemas import UserDTO
from shared_kernel.schemas import Page, UserRole

router = APIRouter(
    prefix="/assets",
    tags=["assets"],
    dependencies=[Depends(get_current_user)],
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
        inventory_location=inventory_location,
        limit=limit,
        offset=offset,
    )
    return Page(items=assets, total=total, limit=limit, offset=offset)


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
    _user=Depends(require_roles(UserRole.ADMINISTRATOR)),
) -> list[AssetTreeNodeDTO]:
    if not uses_postgres():
        raise HTTPException(status_code=501, detail="La administración requiere PostgreSQL.")
    repository = PostgresAssetRepository(session)
    try:
        tree = await repository.apply_component_changes(asset_id, payload.operations)
        await session.commit()
        return tree
    except ValueError as error:
        await session.rollback()
        raise HTTPException(status_code=422, detail=str(error)) from error
    except IntegrityError as error:
        await session.rollback()
        raise HTTPException(
            status_code=409,
            detail="No se puede eliminar el componente porque tiene historial o referencias operativas.",
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
