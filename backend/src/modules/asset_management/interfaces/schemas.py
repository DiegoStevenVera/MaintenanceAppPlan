from pydantic import BaseModel


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
    children: list[str] = []


class AssetHistoryEntryDTO(BaseModel):
    id: str
    report_type: str
    report_id: str
    title: str
    performed_at: str
    result: str
