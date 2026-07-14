from sqlalchemy import Boolean, ForeignKey, String, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class AssetRecord(Base):
    __tablename__ = "assets"

    id: Mapped[str] = mapped_column(String(80), primary_key=True)
    name: Mapped[str] = mapped_column(String(240), nullable=False, index=True)
    category: Mapped[str] = mapped_column(String(120), nullable=False)
    asset_type: Mapped[str] = mapped_column(String(120), nullable=False)
    subsystem: Mapped[str] = mapped_column(String(40), nullable=False, index=True)
    serial_or_code: Mapped[str] = mapped_column(String(120), nullable=False)
    part_number: Mapped[str | None] = mapped_column(String(120))
    status: Mapped[str] = mapped_column(String(80), nullable=False)
    physical_location: Mapped[str] = mapped_column(Text, nullable=False)
    is_business_anchor: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    parent_id: Mapped[str | None] = mapped_column(ForeignKey("assets.id"))
    children: Mapped[list[str]] = mapped_column(JSONB, nullable=False, default=list)


class AssetHistoryRecord(Base):
    __tablename__ = "asset_history"

    id: Mapped[str] = mapped_column(String(80), primary_key=True)
    asset_id: Mapped[str] = mapped_column(ForeignKey("assets.id"), nullable=False, index=True)
    report_type: Mapped[str] = mapped_column(String(40), nullable=False)
    report_id: Mapped[str] = mapped_column(String(120), nullable=False)
    title: Mapped[str] = mapped_column(String(240), nullable=False)
    performed_at: Mapped[str] = mapped_column(String(80), nullable=False)
    result: Mapped[str] = mapped_column(String(120), nullable=False)
