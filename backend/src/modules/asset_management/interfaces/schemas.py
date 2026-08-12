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
