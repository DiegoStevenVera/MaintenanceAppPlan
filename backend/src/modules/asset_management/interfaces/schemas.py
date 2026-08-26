from typing import Literal

from pydantic import BaseModel, Field


class AssetDTO(BaseModel):
    id: str
    name: str
    category: str
    asset_type: str
    subsystem: str
    serial_or_code: str
    part_number: str | None = None
    status: str
    physical_location: str
    is_business_anchor: bool
    parent_id: str | None = None
    children: list[str] = Field(default_factory=list)
    business_label: str | None = None
    manufacturer: str | None = None
    model: str | None = None
    software_version: str | None = None
    current_position: str | None = None
    component_count: int = 0


class AssetTreeNodeDTO(BaseModel):
    id: str
    name: str
    category: str
    asset_type: str
    status: str
    serial_number: str | None = None
    part_number: str | None = None
    model: str | None = None
    manufacturer: str | None = None
    parent_id: str | None = None
    depth: int
    slot_path: str | None = None
    position: str | None = None
    # A physical-location node is virtual: it organizes assets by their slot path
    # and therefore cannot be selected or persisted as an asset.
    node_kind: Literal["ASSET", "LOCATION"] = "ASSET"
    selectable: bool = True


class StockAssetDTO(BaseModel):
    id: str
    name: str
    asset_type: str
    serial_number: str | None = None
    internal_code: str | None = None
    part_number: str | None = None
    status: str
    inventory_location: str
    subsystem: str
    manufacturer: str | None = None
    model: str | None = None


class AssetHistoryEntryDTO(BaseModel):
    id: str
    report_type: str
    report_id: str
    title: str
    performed_at: str
    result: str
    activity_id: str | None = None
    activity_status: str | None = None
    report_kind: str | None = None
    version_number: int | None = None


class AssetComponentOperationDTO(BaseModel):
    """One staged component change applied atomically within an equipment tree."""

    action: Literal["CREATE", "UPDATE", "MOVE", "DELETE"]
    component_id: str | None = None
    parent_id: str | None = None
    name: str | None = Field(default=None, max_length=240)
    category: str | None = Field(default=None, max_length=120)
    asset_type: str | None = Field(default=None, max_length=120)
    status: str | None = Field(default=None, max_length=80)
    serial_number: str | None = Field(default=None, max_length=120)
    part_number: str | None = Field(default=None, max_length=120)
    model: str | None = Field(default=None, max_length=120)
    current_position: str | None = Field(default=None, max_length=200)


class AssetComponentChangesRequest(BaseModel):
    operations: list[AssetComponentOperationDTO] = Field(min_length=1, max_length=100)
