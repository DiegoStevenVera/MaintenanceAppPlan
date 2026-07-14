from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session, uses_postgres
from modules.asset_management.infrastructure.seed_repository import asset_repository
from modules.asset_management.infrastructure.postgres.repository import PostgresAssetRepository
from modules.asset_management.interfaces.schemas import AssetDTO, AssetHistoryEntryDTO
from shared_kernel.schemas import Page

router = APIRouter(prefix="/assets", tags=["assets"])


@router.get("", response_model=Page[AssetDTO])
async def list_assets(
    q: str | None = None,
    business_anchor: bool | None = Query(default=True),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    session: AsyncSession = Depends(get_session),
) -> Page[AssetDTO]:
    if uses_postgres():
        assets = await PostgresAssetRepository(session).list_assets(q=q, business_anchor=business_anchor)
    else:
        assets = asset_repository.list_assets(q=q, business_anchor=business_anchor)
    return Page(items=assets[offset : offset + limit], total=len(assets), limit=limit, offset=offset)


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
