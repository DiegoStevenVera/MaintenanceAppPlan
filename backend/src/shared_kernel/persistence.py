from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import Boolean, DateTime, Integer, Uuid, func
from sqlalchemy.orm import Mapped, declarative_mixin, mapped_column


@declarative_mixin
class OperationalRecordMixin:
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )


@declarative_mixin
class CatalogRecordMixin(OperationalRecordMixin):
    legacy_id: Mapped[int | None] = mapped_column(Integer, unique=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
