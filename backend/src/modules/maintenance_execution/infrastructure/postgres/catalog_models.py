from sqlalchemy import String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base
from shared_kernel.persistence import CatalogRecordMixin


class MaintenanceActionTypeRecord(CatalogRecordMixin, Base):
    __tablename__ = "maintenance_action_types"

    code: Mapped[str] = mapped_column(String(60), nullable=False, unique=True)
    name: Mapped[str] = mapped_column(String(160), nullable=False, unique=True)
    description: Mapped[str | None] = mapped_column(Text)
