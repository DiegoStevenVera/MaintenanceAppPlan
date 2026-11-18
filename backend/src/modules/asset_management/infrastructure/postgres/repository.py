from datetime import UTC, datetime
from uuid import UUID, uuid4

from sqlalchemy import Select, delete, func, or_, select, text, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from modules.asset_management.infrastructure.postgres.catalog_models import (
    AssetStatusRecord,
    EquipmentCategoryRecord,
    ManufacturerRecord,
    MovementTypeRecord,
    SlotTypeRecord,
)
from modules.asset_management.infrastructure.postgres.domain_models import (
    AssetClosureRecord,
    AssetMovementRecord,
    AssetAssignmentRecord,
    AssetTypeRecord,
    InventoryLocationRecord,
    SlotLocationRecord,
)
from modules.asset_management.infrastructure.postgres.models import (
    AssetHistoryRecord,
    AssetImageRecord,
    AssetRecord,
)
from modules.asset_management.interfaces.schemas import (
    AssetComponentOperationDTO,
    AssetDTO,
    AssetHistoryEntryDTO,
    AssetImageDTO,
    AssetTreeNodeDTO,
    AssetWriteRequest,
    ComponentDetailDTO,
    ComponentMovementDTO,
    ComponentWriteRequest,
    EquipmentSlotDTO,
    EquipmentSlotOccupancyRequest,
    EquipmentSlotWriteRequest,
    StockAssetWriteRequest,
    StockAssetDTO,
)
from modules.maintenance_execution.infrastructure.postgres.report_models import (
    CorrectiveReportDetailRecord,
    MaintenanceActivityAssetRecord,
    MaintenanceActivityRecord,
    MaintenanceReportRecord,
    PreventiveReportDetailRecord,
    ReportVersionRecord,
)
from modules.organizational_context.infrastructure.postgres.models import SubsystemRecord
from modules.organizational_context.infrastructure.postgres.operational_models import (
    GeographicLocationRecord,
)


class PostgresAssetRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def list_assets(
        self,
        q: str | None = None,
        business_anchor: bool | None = None,
        subsystem: str | None = None,
        category: str | None = None,
        status: str | None = None,
        limit: int = 50,
        offset: int = 0,
    ) -> tuple[list[AssetDTO], int]:
        stmt: Select[tuple[AssetRecord]] = select(AssetRecord).order_by(AssetRecord.name, AssetRecord.id)
        if business_anchor is not None:
            stmt = stmt.where(AssetRecord.is_business_anchor.is_(business_anchor))
        if q:
            query = f"%{q.casefold()}%"
            stmt = stmt.where(
                or_(
                    func.lower(AssetRecord.name).like(query),
                    func.lower(AssetRecord.category).like(query),
                    func.lower(AssetRecord.asset_type).like(query),
                    func.lower(AssetRecord.serial_or_code).like(query),
                    func.lower(AssetRecord.serial_number).like(query),
                    func.lower(AssetRecord.internal_code).like(query),
                    func.lower(AssetRecord.part_number).like(query),
                )
            )
        if subsystem:
            stmt = stmt.where(func.lower(AssetRecord.subsystem) == subsystem.casefold())
        if category:
            stmt = stmt.where(func.lower(AssetRecord.category) == category.casefold())
        if status:
            stmt = stmt.where(func.lower(AssetRecord.status) == status.casefold())

        total = await self._session.scalar(
            select(func.count()).select_from(stmt.order_by(None).subquery())
        )
        records = list((await self._session.scalars(stmt.limit(limit).offset(offset))).all())
        images = await self._images_by_asset([record.id for record in records])
        return [
            self._to_asset_dto(record, images=images.get(record.id, []))
            for record in records
        ], total or 0

    async def get_asset(self, asset_id: str) -> AssetDTO | None:
        row = (
            await self._session.execute(
                select(AssetRecord, ManufacturerRecord.name)
                .outerjoin(
                    ManufacturerRecord,
                    ManufacturerRecord.id == AssetRecord.manufacturer_id,
                )
                .where(AssetRecord.id == asset_id)
            )
        ).one_or_none()
        if row is None:
            return None
        record, manufacturer = row
        component_count = await self._session.scalar(
            select(func.count())
            .select_from(AssetClosureRecord)
            .where(
                AssetClosureRecord.ancestor_asset_id == asset_id,
                AssetClosureRecord.depth > 0,
            )
        )
        return self._to_asset_dto(
            record,
            manufacturer=manufacturer,
            component_count=component_count or 0,
            images=(await self._images_by_asset([record.id])).get(record.id, []),
        )

    async def get_component(self, asset_id: str) -> ComponentDetailDTO | None:
        parent = aliased(AssetRecord)
        row = (await self._session.execute(
            select(AssetRecord, parent.name, InventoryLocationRecord.name, SlotLocationRecord.path)
            .outerjoin(parent, parent.id == AssetRecord.parent_id)
            .outerjoin(
                InventoryLocationRecord,
                InventoryLocationRecord.id == AssetRecord.current_inventory_location_id,
            )
            .outerjoin(SlotLocationRecord, SlotLocationRecord.id == AssetRecord.current_slot_location_id)
            .where(AssetRecord.id == asset_id, AssetRecord.is_business_anchor.is_(False))
        )).one_or_none()
        if row is None:
            return None
        record, parent_name, inventory_location, slot = row
        asset = await self.get_asset(asset_id)
        if asset is None:
            return None
        component_type = await self._session.get(AssetTypeRecord, record.asset_type_id) if record.asset_type_id else None
        if component_type:
            asset = asset.model_copy(update={"part_number": component_type.part_number})
        return ComponentDetailDTO(
            asset=asset, asset_type_id=record.asset_type_id,
            internal_code=record.internal_code, serial_number=record.serial_number,
            parent_name=parent_name, inventory_location=inventory_location, slot=slot,
            manufacture_date=record.manufacture_date,
        )

    async def update_component(
        self, asset_id: str, payload: ComponentWriteRequest,
    ) -> ComponentDetailDTO | None:
        record = await self._session.get(AssetRecord, asset_id, with_for_update=True)
        if record is None or record.is_business_anchor:
            return None
        component_type = await self._session.get(AssetTypeRecord, record.asset_type_id) if record.asset_type_id else None
        canonical_part = component_type.part_number if component_type else record.part_number
        if ("part_number" in payload.model_fields_set
                and self._empty_to_none(payload.part_number) != canonical_part):
            raise ValueError("El part number pertenece al modelo del catálogo, no a la unidad física.")
        serial = self._empty_to_none(payload.serial_number)
        if serial != record.serial_number:
            if serial and (
                await self._serial_or_code_exists(serial, excluding_id=asset_id)
                or await self._session.scalar(select(AssetRecord.id).where(
                    AssetRecord.id != asset_id, func.lower(AssetRecord.serial_number) == serial.casefold()
                ).limit(1))
            ):
                raise ValueError("Ya existe un activo con ese número de serie.")
            previous_serial = record.serial_number
            record.serial_number = serial
            record.serial_number_status = "KNOWN" if serial else "NOT_CAPTURED"
            if serial or record.serial_or_code == previous_serial:
                record.serial_or_code = serial or record.internal_code or record.id
        if payload.status_id is not None and payload.status_id != record.status_id:
            asset_status = await self._session.get(AssetStatusRecord, payload.status_id)
            if asset_status is None or not asset_status.is_active:
                raise ValueError("El estado seleccionado no está disponible.")
            record.status = asset_status.name
            record.status_id = asset_status.id
        record.name = payload.name
        record.part_number = canonical_part
        record.model = self._empty_to_none(payload.model)
        record.software_version = self._empty_to_none(payload.software_version)
        record.manufacturer_id = await self._manufacturer_id(payload.manufacturer)
        await self._session.flush()
        return await self.get_component(asset_id)

    async def component_movements(
        self, asset_id: str, limit: int, offset: int,
    ) -> tuple[list[ComponentMovementDTO], int] | None:
        asset = await self._session.get(AssetRecord, asset_id)
        if asset is None or asset.is_business_anchor:
            return None
        movement = AssetMovementRecord
        from_location, to_location = aliased(InventoryLocationRecord), aliased(InventoryLocationRecord)
        from_slot, to_slot = aliased(SlotLocationRecord), aliased(SlotLocationRecord)
        from_status, to_status = aliased(AssetStatusRecord), aliased(AssetStatusRecord)
        criterion = movement.asset_id == asset_id
        assignment_parent = aliased(AssetRecord)

        def parent_at(assignment_date):
            return (
                select(assignment_parent.name)
                .select_from(AssetAssignmentRecord)
                .join(assignment_parent, assignment_parent.id == AssetAssignmentRecord.parent_asset_id)
                .where(
                    AssetAssignmentRecord.asset_id == movement.asset_id,
                    assignment_date == movement.moved_at,
                    MovementTypeRecord.code == "ASIGNACION_COMPONENTE",
                )
                .order_by(AssetAssignmentRecord.id)
                .limit(1)
                .correlate(movement, MovementTypeRecord)
                .scalar_subquery()
            )

        total = await self._session.scalar(select(func.count()).select_from(movement).where(criterion))
        rows = (await self._session.execute(
            select(
                movement, MovementTypeRecord.name, from_location.name, to_location.name,
                from_slot.path, to_slot.path, from_status.name, to_status.name,
                parent_at(AssetAssignmentRecord.unassigned_at),
                parent_at(AssetAssignmentRecord.assigned_at),
            )
            .join(MovementTypeRecord, MovementTypeRecord.id == movement.movement_type_id)
            .outerjoin(from_location, from_location.id == movement.from_inventory_location_id)
            .outerjoin(to_location, to_location.id == movement.to_inventory_location_id)
            .outerjoin(from_slot, from_slot.id == movement.from_slot_location_id)
            .outerjoin(to_slot, to_slot.id == movement.to_slot_location_id)
            .outerjoin(from_status, from_status.id == movement.from_status_id)
            .outerjoin(to_status, to_status.id == movement.to_status_id)
            .where(criterion)
            .order_by(movement.moved_at.desc(), movement.id)
            .limit(limit).offset(offset)
        )).all()

        def label(location: str | None, slot: str | None) -> str | None:
            return " · ".join(dict.fromkeys(value for value in (location, slot) if value)) or None

        return [
            ComponentMovementDTO(
                id=record.id, kind=kind, moved_at=record.moved_at,
                origin=label(origin_parent or origin, origin_slot),
                destination=label(destination_parent or destination, destination_slot),
                from_status=previous, to_status=current, notes=record.notes,
            )
            for (
                record, kind, origin, destination, origin_slot, destination_slot,
                previous, current, origin_parent, destination_parent,
            ) in rows
        ], total or 0

    async def create_asset(self, payload: AssetWriteRequest) -> AssetDTO:
        code = payload.serial_or_code.strip()
        if await self._serial_or_code_exists(code):
            raise ValueError("Ya existe un equipo con ese código o número de serie.")
        category, subsystem, asset_status, location = await self._master_data(payload)
        record = AssetRecord(
            id=str(uuid4()),
            name=payload.name.strip(),
            category=category.name_n1,
            asset_type=self._category_type_name(category),
            subsystem=subsystem.code,
            serial_or_code=code,
            part_number=self._empty_to_none(payload.part_number),
            status=asset_status.name,
            physical_location=location.full_path,
            is_business_anchor=True,
            parent_id=None,
            children=[],
            internal_code=code,
            serial_number=code,
            serial_number_status="KNOWN",
            model=self._empty_to_none(payload.model),
            software_version=self._empty_to_none(payload.software_version),
            business_label=self._empty_to_none(payload.business_label) or "Equipo",
            registration_method="MANUAL",
            is_mobile=False,
            manufacturer_id=await self._manufacturer_id(payload.manufacturer),
            equipment_category_id=category.id,
            subsystem_id=subsystem.id,
            status_id=asset_status.id,
            current_geographic_location_id=location.id,
        )
        self._session.add(record)
        await self._session.flush()
        await self._session.execute(
            text("SELECT sync_equipment_slot_structure(:id)"), {"id": record.id}
        )
        await self._rebuild_asset_closure()
        return await self.get_asset(record.id)

    async def update_asset(self, asset_id: str, payload: AssetWriteRequest) -> AssetDTO:
        record = await self._session.get(AssetRecord, asset_id)
        if record is None or not record.is_business_anchor:
            raise ValueError("El equipo no existe o no es un equipo principal.")
        code = payload.serial_or_code.strip()
        if await self._serial_or_code_exists(code, excluding_id=asset_id):
            raise ValueError("Ya existe un equipo con ese código o número de serie.")
        category, subsystem, asset_status, location = await self._master_data(payload)
        record.name = payload.name.strip()
        record.category = category.name_n1
        record.asset_type = self._category_type_name(category)
        record.subsystem = subsystem.code
        record.serial_or_code = code
        record.internal_code = code
        record.serial_number = code
        record.serial_number_status = "KNOWN"
        record.part_number = self._empty_to_none(payload.part_number)
        record.status = asset_status.name
        record.physical_location = location.full_path
        record.business_label = self._empty_to_none(payload.business_label) or "Equipo"
        record.model = self._empty_to_none(payload.model)
        record.software_version = self._empty_to_none(payload.software_version)
        record.manufacturer_id = await self._manufacturer_id(payload.manufacturer)
        record.equipment_category_id = category.id
        record.subsystem_id = subsystem.id
        record.status_id = asset_status.id
        record.current_geographic_location_id = location.id
        await self._session.flush()
        return await self.get_asset(record.id)

    async def archive_asset(self, asset_id: str) -> AssetDTO:
        record = await self._session.get(AssetRecord, asset_id)
        if record is None or not record.is_business_anchor:
            raise ValueError("El equipo no existe o no es un equipo principal.")
        record.status = "DADO DE BAJA"
        archived_status = await self._session.scalar(
            select(AssetStatusRecord).where(AssetStatusRecord.code == "DADO_DE_BAJA")
        )
        record.status_id = archived_status.id if archived_status is not None else None
        await self._session.flush()
        return await self.get_asset(record.id)

    async def _serial_or_code_exists(
        self, code: str, *, excluding_id: str | None = None
    ) -> bool:
        stmt = select(func.count()).select_from(AssetRecord).where(
            func.lower(AssetRecord.serial_or_code) == code.casefold()
        )
        if excluding_id:
            stmt = stmt.where(AssetRecord.id != excluding_id)
        return bool(await self._session.scalar(stmt))

    async def _master_data(self, payload: AssetWriteRequest):
        category = await self._session.get(
            EquipmentCategoryRecord, payload.equipment_category_id
        )
        subsystem = await self._session.get(SubsystemRecord, payload.subsystem_id)
        asset_status = await self._session.get(AssetStatusRecord, payload.status_id)
        location = await self._session.get(
            GeographicLocationRecord, payload.geographic_location_id
        )
        if category is None or not category.is_active:
            raise ValueError("La categoría o tipo seleccionado no está disponible.")
        if subsystem is None or not subsystem.is_active:
            raise ValueError("El subsistema seleccionado no está disponible.")
        if category.subsystem_id != subsystem.id:
            raise ValueError("La categoría no pertenece al subsistema seleccionado.")
        if asset_status is None or not asset_status.is_active:
            raise ValueError("El estado seleccionado no está disponible.")
        if location is None or not location.is_active or location.level != 4:
            raise ValueError("Debe seleccionar una ubicación completa hasta el nivel 4.")
        return category, subsystem, asset_status, location

    @staticmethod
    def _category_type_name(category: EquipmentCategoryRecord) -> str:
        return " - ".join(
            value for value in (category.name_n1, category.name_n2) if value
        )

    async def _manufacturer_id(self, value: str | None):
        name = self._empty_to_none(value)
        if name is None:
            return None
        manufacturer = await self._session.scalar(
            select(ManufacturerRecord).where(func.lower(ManufacturerRecord.name) == name.casefold())
        )
        if manufacturer is None:
            manufacturer = ManufacturerRecord(
                id=uuid4(), name=name, description=None, is_active=True
            )
            self._session.add(manufacturer)
            await self._session.flush()
        elif not manufacturer.is_active:
            manufacturer.is_active = True
        return manufacturer.id

    async def _images_by_asset(self, asset_ids: list[str]) -> dict[str, list[AssetImageDTO]]:
        if not asset_ids:
            return {}
        rows = list(
            (
                await self._session.scalars(
                    select(AssetImageRecord)
                    .where(AssetImageRecord.asset_id.in_(asset_ids))
                    .order_by(
                        AssetImageRecord.asset_id,
                        AssetImageRecord.is_primary.desc(),
                        AssetImageRecord.sort_order,
                        AssetImageRecord.created_at,
                    )
                )
            ).all()
        )
        result: dict[str, list[AssetImageDTO]] = {}
        for image in rows:
            result.setdefault(image.asset_id, []).append(
                AssetImageDTO(
                    id=image.id,
                    file_name=image.file_name,
                    media_type=image.media_type,
                    byte_size=image.byte_size,
                    caption=image.caption,
                    is_primary=image.is_primary,
                    sort_order=image.sort_order,
                    url=f"/api/v1/assets/{image.asset_id}/images/{image.id}",
                )
            )
        return result

    async def list_stock_assets(
        self,
        *,
        q: str | None = None,
        subsystem: str | None = None,
        status: str | None = None,
        inventory_location: str | None = None,
        limit: int = 200,
        offset: int = 0,
    ) -> tuple[list[StockAssetDTO], int]:
        stmt = (
            select(
                AssetRecord,
                InventoryLocationRecord.name.label("inventory_location"),
                ManufacturerRecord.name.label("manufacturer"),
            )
            .join(
                InventoryLocationRecord,
                InventoryLocationRecord.id == AssetRecord.current_inventory_location_id,
            )
            .outerjoin(
                ManufacturerRecord,
                ManufacturerRecord.id == AssetRecord.manufacturer_id,
            )
            .where(AssetRecord.current_inventory_location_id.is_not(None))
            .order_by(InventoryLocationRecord.name, AssetRecord.name)
        )
        if q:
            query = f"%{q.casefold()}%"
            stmt = stmt.where(
                or_(
                    func.lower(AssetRecord.name).like(query),
                    func.lower(AssetRecord.asset_type).like(query),
                    func.lower(func.coalesce(AssetRecord.serial_number, "")).like(query),
                    func.lower(func.coalesce(AssetRecord.internal_code, "")).like(query),
                    func.lower(func.coalesce(AssetRecord.part_number, "")).like(query),
                    func.lower(InventoryLocationRecord.name).like(query),
                )
            )
        if subsystem:
            stmt = stmt.where(func.lower(AssetRecord.subsystem) == subsystem.casefold())
        if status:
            stmt = stmt.where(func.lower(AssetRecord.status) == status.casefold())
        if inventory_location:
            stmt = stmt.where(
                func.lower(InventoryLocationRecord.name) == inventory_location.casefold()
            )

        total = await self._session.scalar(
            select(func.count()).select_from(stmt.order_by(None).subquery())
        )
        rows = (await self._session.execute(stmt.limit(limit).offset(offset))).all()
        images = await self._images_by_asset([record.id for record, _, _ in rows])
        return [
            StockAssetDTO(
                id=record.id,
                name=record.name,
                category=record.category,
                asset_type=record.asset_type,
                serial_number=record.serial_number,
                internal_code=record.internal_code,
                part_number=record.part_number,
                status=record.status,
                inventory_location=location,
                subsystem=record.subsystem,
                manufacturer=manufacturer,
                model=record.model,
                software_version=record.software_version,
                equipment_category_id=record.equipment_category_id,
                subsystem_id=record.subsystem_id,
                status_id=record.status_id,
                inventory_location_id=record.current_inventory_location_id,
                images=images.get(record.id, []),
            )
            for record, location, manufacturer in rows
        ], total or 0

    async def get_stock_asset(self, asset_id: str) -> StockAssetDTO | None:
        row = (
            await self._session.execute(
                select(
                    AssetRecord,
                    InventoryLocationRecord.name.label("inventory_location"),
                    ManufacturerRecord.name.label("manufacturer"),
                )
                .join(
                    InventoryLocationRecord,
                    InventoryLocationRecord.id == AssetRecord.current_inventory_location_id,
                )
                .outerjoin(
                    ManufacturerRecord,
                    ManufacturerRecord.id == AssetRecord.manufacturer_id,
                )
                .where(
                    AssetRecord.id == asset_id,
                    AssetRecord.current_inventory_location_id.is_not(None),
                )
            )
        ).one_or_none()
        if row is None:
            return None
        record, location, manufacturer = row
        images = (await self._images_by_asset([record.id])).get(record.id, [])
        return StockAssetDTO(
            id=record.id,
            name=record.name,
            category=record.category,
            asset_type=record.asset_type,
            serial_number=record.serial_number,
            internal_code=record.internal_code,
            part_number=record.part_number,
            status=record.status,
            inventory_location=location,
            subsystem=record.subsystem,
            manufacturer=manufacturer,
            model=record.model,
            software_version=record.software_version,
            equipment_category_id=record.equipment_category_id,
            subsystem_id=record.subsystem_id,
            status_id=record.status_id,
            inventory_location_id=record.current_inventory_location_id,
            images=images,
        )

    async def create_stock_asset(
        self, payload: StockAssetWriteRequest
    ) -> StockAssetDTO:
        code = payload.serial_or_code.strip()
        if await self._serial_or_code_exists(code):
            raise ValueError("Ya existe un activo con ese código o número de serie.")
        category, subsystem, asset_status, location = await self._stock_master_data(
            payload
        )
        record = AssetRecord(
            id=str(uuid4()),
            name=payload.name.strip(),
            category=category.name_n1,
            asset_type=self._category_type_name(category),
            subsystem=subsystem.code,
            serial_or_code=code,
            part_number=self._empty_to_none(payload.part_number),
            status=asset_status.name,
            physical_location=location.name,
            is_business_anchor=False,
            parent_id=None,
            children=[],
            internal_code=code,
            serial_number=code,
            serial_number_status="KNOWN",
            model=self._empty_to_none(payload.model),
            software_version=self._empty_to_none(payload.software_version),
            business_label="Elemento de stock",
            registration_method="MANUAL",
            is_mobile=True,
            manufacturer_id=await self._manufacturer_id(payload.manufacturer),
            equipment_category_id=category.id,
            subsystem_id=subsystem.id,
            status_id=asset_status.id,
            current_inventory_location_id=location.id,
        )
        self._session.add(record)
        await self._session.flush()
        result = await self.get_stock_asset(record.id)
        if result is None:
            raise ValueError("No se pudo recuperar el elemento de stock creado.")
        return result

    async def update_stock_asset(
        self, asset_id: str, payload: StockAssetWriteRequest
    ) -> StockAssetDTO:
        record = await self._session.get(AssetRecord, asset_id)
        if record is None or record.current_inventory_location_id is None:
            raise ValueError("El elemento de stock no existe.")
        code = payload.serial_or_code.strip()
        if await self._serial_or_code_exists(code, excluding_id=asset_id):
            raise ValueError("Ya existe un activo con ese código o número de serie.")

        category, subsystem, asset_status, location = await self._stock_master_data(
            payload
        )

        record.name = payload.name.strip()
        record.category = category.name_n1
        record.asset_type = self._category_type_name(category)
        record.subsystem = subsystem.code
        record.serial_or_code = code
        record.internal_code = code
        record.serial_number = code
        record.serial_number_status = "KNOWN"
        record.part_number = self._empty_to_none(payload.part_number)
        record.status = asset_status.name
        record.physical_location = location.name
        record.model = self._empty_to_none(payload.model)
        record.software_version = self._empty_to_none(payload.software_version)
        record.manufacturer_id = await self._manufacturer_id(payload.manufacturer)
        record.equipment_category_id = category.id
        record.subsystem_id = subsystem.id
        record.status_id = asset_status.id
        record.current_inventory_location_id = location.id
        await self._session.flush()
        result = await self.get_stock_asset(asset_id)
        if result is None:
            raise ValueError("No se pudo recuperar el elemento de stock actualizado.")
        return result

    async def _stock_master_data(self, payload: StockAssetWriteRequest):
        category = await self._session.get(
            EquipmentCategoryRecord, payload.equipment_category_id
        )
        subsystem = await self._session.get(SubsystemRecord, payload.subsystem_id)
        asset_status = await self._session.get(AssetStatusRecord, payload.status_id)
        location = await self._session.get(
            InventoryLocationRecord, payload.inventory_location_id
        )
        if category is None or not category.is_active:
            raise ValueError("La categoría seleccionada no está disponible.")
        if subsystem is None or not subsystem.is_active:
            raise ValueError("El subsistema seleccionado no está disponible.")
        if category.subsystem_id != subsystem.id:
            raise ValueError("La categoría no pertenece al subsistema seleccionado.")
        if asset_status is None or not asset_status.is_active:
            raise ValueError("El estado seleccionado no está disponible.")
        if location is None or not location.is_active:
            raise ValueError("La ubicación de stock seleccionada no está disponible.")
        return category, subsystem, asset_status, location

    async def get_tree(self, asset_id: str) -> list[AssetTreeNodeDTO]:
        rows = (
            await self._session.execute(
                select(
                    AssetClosureRecord.depth,
                    AssetRecord,
                    SlotLocationRecord.path,
                    ManufacturerRecord.name,
                )
                .join(
                    AssetRecord,
                    AssetRecord.id == AssetClosureRecord.descendant_asset_id,
                )
                .outerjoin(
                    SlotLocationRecord,
                    SlotLocationRecord.id == AssetRecord.current_slot_location_id,
                )
                .outerjoin(
                    ManufacturerRecord,
                    ManufacturerRecord.id == AssetRecord.manufacturer_id,
                )
                .where(
                    AssetClosureRecord.ancestor_asset_id == asset_id,
                    AssetClosureRecord.depth > 0,
                )
                .order_by(
                    AssetClosureRecord.depth,
                    SlotLocationRecord.path,
                    AssetRecord.name,
                )
            )
        ).all()
        # The imported asset parent relation is useful when it exists, but many
        # legacy records are attached directly to the equipment. Their actual
        # physical arrangement lives in slot_locations (for example
        # /R1/CC/Cubiculo 2/SCCR B1). Expose those slot levels as virtual nodes
        # so clients can navigate the real installation instead of a flat list.
        asset_ids = {record.id for _, record, _, _ in rows}
        current_slots = {
            record.current_slot_location_id
            for _, record, _, _ in rows
            if record.current_slot_location_id
        }
        slot_scope = SlotLocationRecord.equipment_asset_id == asset_id
        if current_slots:
            slot_scope = or_(slot_scope, SlotLocationRecord.equipment_asset_id.is_(None))
        slot_records = {
            slot.id: slot
            for slot in (
                await self._session.scalars(select(SlotLocationRecord).where(slot_scope))
            ).all()
        }
        included_slots = {
            slot.id for slot in slot_records.values()
            if slot.equipment_asset_id == asset_id and slot.is_active
        }
        for slot_id in current_slots:
            current_id: UUID | None = slot_id
            while current_id in slot_records and current_id not in included_slots:
                included_slots.add(current_id)
                current_id = slot_records[current_id].parent_slot_location_id

        # A slot that owns exactly one installed asset is the physical identity
        # of that asset, not an extra folder. Rendering both used to produce
        # paths such as TIR 1 -> TIR 1 EQUIPED 600 -> its components. Map those
        # slots to their asset, while retaining virtual folders for empty slots
        # and slots holding multiple assets.
        assets_by_slot: dict[UUID, list[AssetRecord]] = {}
        for _, record, _, _ in rows:
            if record.current_slot_location_id in included_slots:
                assets_by_slot.setdefault(record.current_slot_location_id, []).append(record)
        slot_owner_asset_id = {
            slot_id: records[0].id
            for slot_id, records in assets_by_slot.items()
            if len(records) == 1 and slot_records[slot_id].equipment_asset_id is None
        }

        def slot_node_id(slot_id: UUID) -> str:
            return slot_owner_asset_id.get(slot_id, f"slot:{slot_id}")

        def parent_slot_node_id(slot_id: UUID | None) -> str:
            if not slot_id:
                return asset_id
            slot = slot_records.get(slot_id)
            if slot is None or slot.parent_slot_location_id not in included_slots:
                return asset_id
            return slot_node_id(slot.parent_slot_location_id)

        root_and_assets = asset_ids | {asset_id}
        asset_nodes: list[AssetTreeNodeDTO] = []
        for depth, record, slot_path, manufacturer in rows:
            if record.current_slot_location_id in included_slots:
                if slot_owner_asset_id.get(record.current_slot_location_id) == record.id:
                    parent_id = parent_slot_node_id(record.current_slot_location_id)
                else:
                    parent_id = slot_node_id(record.current_slot_location_id)
            else:
                parent_id = (
                    record.parent_id
                    if record.parent_id in root_and_assets
                    else asset_id
                )
            asset_nodes.append(
                AssetTreeNodeDTO(
                    id=record.id,
                    name=record.name,
                    category=record.category,
                    asset_type=record.asset_type,
                    status=record.status,
                    serial_number=record.serial_number or record.serial_or_code or None,
                    part_number=record.part_number,
                    model=record.model,
                    manufacturer=manufacturer,
                    parent_id=parent_id,
                    depth=depth,
                    slot_path=slot_path,
                    position=record.current_position,
                )
            )

        location_nodes = [
            AssetTreeNodeDTO(
                id=f"slot:{slot.id}",
                name=slot.name,
                category="Ubicacion fisica",
                asset_type="Ubicacion",
                status=(
                    "ACTIVE" if slot.equipment_asset_id is None else
                    "Contenedor" if not slot.accepts_asset else
                    "Ocupado" if slot.id in assets_by_slot else "Libre"
                ),
                parent_id=parent_slot_node_id(slot.id),
                depth=0,
                slot_path=slot.path,
                position=None,
                node_kind="LOCATION",
                selectable=False,
            )
            for slot_id in included_slots
            if (
                slot_id not in slot_owner_asset_id
                and (slot := slot_records.get(slot_id)) is not None
            )
        ]

        all_nodes = {node.id: node for node in location_nodes + asset_nodes}
        def node_depth(node_id: str, visiting: set[str] | None = None) -> int:
            node = all_nodes[node_id]
            parent_id = node.parent_id
            if parent_id == asset_id or parent_id not in all_nodes:
                return 1
            visiting = visiting or set()
            if node_id in visiting:
                return 1
            return node_depth(parent_id, visiting | {node_id}) + 1

        resolved = [
            node.model_copy(update={"depth": node_depth(node.id)})
            for node in all_nodes.values()
        ]
        return sorted(
            resolved,
            key=lambda node: (
                node.depth,
                node.parent_id or "",
                0 if node.node_kind == "LOCATION" else 1,
                node.name.casefold(),
            ),
        )

    async def equipment_slots(self, asset_id: str) -> list[EquipmentSlotDTO] | None:
        equipment = await self._session.get(AssetRecord, asset_id)
        if equipment is None or not equipment.is_business_anchor:
            return None
        rows = (await self._session.execute(
            select(SlotLocationRecord, AssetRecord.id, AssetRecord.name)
            .outerjoin(AssetRecord, AssetRecord.current_slot_location_id == SlotLocationRecord.id)
            .where(
                SlotLocationRecord.equipment_asset_id == asset_id,
                SlotLocationRecord.is_active.is_(True),
            )
            .order_by(SlotLocationRecord.path, SlotLocationRecord.id)
        )).all()
        return [
            EquipmentSlotDTO(
                id=slot.id, name=slot.name, path=slot.path, parent_id=slot.parent_slot_location_id,
                accepts_asset=slot.accepts_asset, occupant_id=occupant_id, occupant_name=occupant_name,
            )
            for slot, occupant_id, occupant_name in rows
        ]

    async def component_editor_options(self, asset_id: str) -> dict:
        root = await self._session.get(AssetRecord, asset_id)
        if root is None or not root.is_business_anchor:
            raise ValueError("Equipo no encontrado.")
        types = (await self._session.scalars(select(AssetTypeRecord).where(
            AssetTypeRecord.category == "COMPONENT", AssetTypeRecord.is_active.is_(True),
        ).order_by(AssetTypeRecord.name))).all()
        statuses = set((await self._session.scalars(select(AssetStatusRecord.name))).all())
        statuses.update((await self._session.scalars(select(AssetRecord.status).where(
            AssetRecord.is_business_anchor.is_(False), AssetRecord.subsystem == root.subsystem,
        ).distinct())).all())
        return {"classifications": [
                    {"id": str(item.id), "category": "Componente", "type": item.name,
                     "part_number": item.part_number, "serial_number_policy": item.serial_number_policy}
                    for item in types],
                "statuses": sorted(statuses)}

    async def _validate_component_fields(self, root, operation, component=None) -> AssetTypeRecord | None:
        options = await self.component_editor_options(root.id)
        status = operation.status or (component.status if component else "OPERATIVO")
        if status not in options["statuses"]:
            raise ValueError("Selecciona un estado del catálogo.")
        if operation.category is not None and operation.category != "Componente":
            raise ValueError("La categoría de una unidad de componente es Componente.")
        if operation.new_type_name:
            if operation.action != "CREATE" or operation.asset_type_id is not None:
                raise ValueError("Crear un modelo nuevo solo está disponible al agregar una unidad.")
            name = operation.new_type_name.strip()
            part = self._empty_to_none(operation.new_type_part_number)
            if not name or not part:
                raise ValueError("Indica el nombre y part number del nuevo modelo.")
            existing = await self._session.scalar(select(AssetTypeRecord.id).where(or_(
                func.lower(AssetTypeRecord.name) == name.casefold(),
                func.lower(AssetTypeRecord.part_number) == part.casefold(),
            )).limit(1))
            if existing:
                raise ValueError("El modelo o part number ya existe. Selecciónalo del catálogo.")
            selected = AssetTypeRecord(id=uuid4(), name=name, part_number=part,
                category="COMPONENT", serial_number_policy="OPTIONAL", part_number_policy="OPTIONAL")
            self._session.add(selected)
            await self._session.flush()
        elif operation.asset_type_id:
            selected = await self._session.get(AssetTypeRecord, operation.asset_type_id)
        elif component and component.asset_type_id and not operation.asset_type:
            selected = await self._session.get(AssetTypeRecord, component.asset_type_id)
        else:
            selected = await self._session.scalar(select(AssetTypeRecord).where(
                AssetTypeRecord.name == operation.asset_type, AssetTypeRecord.category == "COMPONENT",
            ))
        if selected is None or selected.category != "COMPONENT" or not selected.is_active:
            raise ValueError("Selecciona un modelo de componente del catálogo.")
        if operation.part_number is not None and self._empty_to_none(operation.part_number) != selected.part_number:
            raise ValueError("El part number se obtiene del modelo seleccionado y no se puede editar aquí.")
        serial = self._empty_to_none(operation.serial_number)
        if selected.serial_number_policy == "NOT_APPLICABLE" and serial:
            raise ValueError("Este modelo no utiliza número de serie.")
        if selected.serial_number_policy == "REQUIRED" and not (serial or (component and component.serial_number)):
            raise ValueError("Este modelo requiere número de serie.")
        if serial and await self._session.scalar(select(AssetRecord.id).where(
            func.lower(AssetRecord.serial_number) == serial.casefold(),
            AssetRecord.id != (component.id if component else ""),
        ).limit(1)):
            raise ValueError("Ya existe una unidad con ese número de serie.")
        return selected

    async def _apply_component_position(self, root_id, component_id, position, user_id):
        component = await self._session.get(AssetRecord, component_id)
        current_slot = (await self._session.get(SlotLocationRecord, component.current_slot_location_id)
                        if component.current_slot_location_id else None)
        if current_slot and position == current_slot.path:
            return
        if position is None or position == (component.current_position or ""):
            return
        if not position:
            if component.current_slot_location_id:
                slot = current_slot
                if slot.equipment_asset_id == root_id:
                    await self.place_equipment_component(root_id, slot.id,
                        EquipmentSlotOccupancyRequest(expected_occupant_id=component_id), user_id)
                else:
                    raise ValueError("Selecciona un espacio del equipo para cambiar la posición importada.")
            return
        slot = await self._session.scalar(select(SlotLocationRecord).where(
            SlotLocationRecord.equipment_asset_id == root_id, SlotLocationRecord.path == position,
            SlotLocationRecord.accepts_asset.is_(True), SlotLocationRecord.is_active.is_(True),
        ))
        if slot is None:
            raise ValueError("Selecciona una posición del equipo.")
        await self.place_equipment_component(root_id, slot.id,
            EquipmentSlotOccupancyRequest(component_id=component_id), user_id)

    async def _owned_slot(self, asset_id: str, slot_id: UUID) -> SlotLocationRecord:
        slot = await self._session.get(SlotLocationRecord, slot_id, with_for_update=True)
        if slot is None or slot.equipment_asset_id != asset_id or not slot.is_active:
            raise ValueError("La ubicación no pertenece al equipo actual.")
        return slot

    async def create_equipment_slot(
        self, asset_id: str, payload: EquipmentSlotWriteRequest,
    ) -> list[EquipmentSlotDTO] | None:
        await self._session.execute(text("SELECT pg_advisory_xact_lock(20261117)"))
        equipment = await self._session.get(AssetRecord, asset_id)
        if equipment is None or not equipment.is_business_anchor:
            return None
        parent = await self._owned_slot(asset_id, payload.parent_id) if payload.parent_id else None
        if "/" in payload.name:
            raise ValueError("El nombre no puede contener el separador /.")
        if parent and parent.level >= 12:
            raise ValueError("La jerarquía admite hasta 12 niveles.")
        duplicate = await self._session.scalar(select(SlotLocationRecord.id).where(
            SlotLocationRecord.equipment_asset_id == asset_id,
            SlotLocationRecord.parent_slot_location_id == payload.parent_id,
            func.lower(SlotLocationRecord.name) == payload.name.lower(),
        ))
        if duplicate:
            raise ValueError("Ya existe un espacio con ese nombre en este nivel.")
        slot_type = await self._session.scalar(select(SlotTypeRecord).where(
            SlotTypeRecord.name == "Espacio interno personalizado"
        ))
        if slot_type is None:
            slot_type = SlotTypeRecord(id=uuid4(), name="Espacio interno personalizado")
            self._session.add(slot_type)
            await self._session.flush()
        if parent:
            parent.is_leaf = False
        self._session.add(SlotLocationRecord(
            id=uuid4(), equipment_asset_id=asset_id, slot_type_id=slot_type.id,
            name=payload.name, parent_slot_location_id=payload.parent_id,
            level=(parent.level + 1) if parent else 1,
            path=f"{parent.path if parent else ''}/{payload.name}",
            is_leaf=True, accepts_asset=payload.accepts_asset,
        ))
        await self._session.flush()
        await self._session.execute(
            text("SELECT sync_equipment_slot_structure(:id)"), {"id": asset_id}
        )
        return await self.equipment_slots(asset_id)

    async def place_equipment_component(
        self, asset_id: str, slot_id: UUID, payload: EquipmentSlotOccupancyRequest, user_id: str,
    ) -> list[EquipmentSlotDTO]:
        await self._session.execute(text("SELECT pg_advisory_xact_lock(20261117)"))
        slot = await self._owned_slot(asset_id, slot_id)
        occupant = await self._session.scalar(select(AssetRecord).where(
            AssetRecord.current_slot_location_id == slot.id
        ).with_for_update())
        if (occupant.id if occupant else None) != payload.expected_occupant_id:
            raise ValueError("La ocupación cambió. Recarga antes de guardar.")
        if payload.component_id is None:
            if occupant is None:
                return await self.equipment_slots(asset_id)
            component, new_slot = occupant, None
        else:
            if not slot.accepts_asset:
                raise ValueError("Este espacio organiza ubicaciones y no admite componentes.")
            if occupant and occupant.id != payload.component_id:
                raise ValueError("El espacio ya está ocupado. Libéralo antes de asignar otro componente.")
            component = await self._session.get(AssetRecord, payload.component_id, with_for_update=True)
            if component is None or not await self._is_descendant(asset_id, component.id):
                raise ValueError("El componente debe pertenecer a este equipo.")
            new_slot = slot
        old_id = component.current_slot_location_id
        new_id = new_slot.id if new_slot else None
        if old_id == new_id:
            return await self.equipment_slots(asset_id)
        kind = await self._session.scalar(select(MovementTypeRecord).where(
            MovementTypeRecord.code == "UBICACION_INTERNA"
        ))
        if kind is None:
            kind = MovementTypeRecord(id=uuid4(), code="UBICACION_INTERNA", name="Ubicación interna")
            self._session.add(kind)
            await self._session.flush()
        now = datetime.now(UTC)
        await self._session.execute(update(AssetAssignmentRecord).where(
            AssetAssignmentRecord.asset_id == component.id,
            AssetAssignmentRecord.unassigned_at.is_(None),
        ).values(unassigned_at=now))
        self._session.add(AssetAssignmentRecord(
            asset_id=component.id, parent_asset_id=component.parent_id,
            slot_location_id=new_id, position_snapshot=new_slot.path[-200:] if new_slot else None,
            geographic_location_id=component.current_geographic_location_id,
            assigned_at=now, reason="Cambio de ubicación interna",
        ))
        self._session.add(AssetMovementRecord(
            asset_id=component.id, movement_type_id=kind.id, moved_at=now, moved_by_user_id=user_id,
            from_slot_location_id=old_id, to_slot_location_id=new_id,
            from_status_id=component.status_id, to_status_id=component.status_id,
            notes="Asignación a un espacio interno." if new_slot else "Espacio liberado.",
        ))
        component.current_slot_location_id = new_id
        component.current_position = new_slot.path[-200:] if new_slot else None
        await self._session.flush()
        return await self.equipment_slots(asset_id)

    async def _require_unplaced_subtree(self, component_id: str, *, exclude_root: bool = False) -> None:
        descendants = select(AssetClosureRecord.descendant_asset_id).where(
            AssetClosureRecord.ancestor_asset_id == component_id,
        )
        assigned = await self._session.scalar(select(AssetRecord.id).join(
            SlotLocationRecord, SlotLocationRecord.id == AssetRecord.current_slot_location_id,
        ).where(
            or_(AssetRecord.id == component_id, AssetRecord.id.in_(descendants)),
            AssetRecord.id != component_id if exclude_root else text("true"),
            text("true") if exclude_root else SlotLocationRecord.equipment_asset_id.is_not(None),
        ).limit(1))
        if assigned:
            raise ValueError("Libera primero las posiciones internas de los componentes hijos."
                if exclude_root else "Libera primero los espacios internos del componente y sus hijos.")

    async def apply_component_changes(
        self,
        root_asset_id: str,
        operations: list[AssetComponentOperationDTO],
        user_id: str | None = None,
    ) -> list[AssetTreeNodeDTO]:
        """Apply a staged component administration batch atomically.

        The root equipment itself cannot be edited here. Existing components must
        belong to its current tree; a move may target another business-anchor
        equipment, which is the explicit "move to another equipment" operation.
        """
        await self._session.execute(text("SELECT pg_advisory_xact_lock(20261117)"))
        root = await self._session.get(AssetRecord, root_asset_id, with_for_update=True)
        if root is None or not root.is_business_anchor:
            raise ValueError("El equipo principal no existe o no es administrable.")

        positions = []
        for operation in operations:
            if operation.action == "CREATE":
                component_type = await self._validate_component_fields(root, operation)
                component_id = await self._create_component(root, operation, component_type)
                positions.append((root.id, component_id, operation.current_position))
            elif operation.action == "ASSIGN":
                await self._assign_existing_component(root, operation, user_id)
                positions.append((root.id, operation.component_id, operation.current_position))
            else:
                if not operation.component_id:
                    raise ValueError("La operación requiere el componente a modificar.")
                component = await self._session.get(AssetRecord, operation.component_id)
                if component is None:
                    raise ValueError("El componente seleccionado ya no existe.")
                if not await self._is_descendant(root_asset_id, component.id):
                    raise ValueError("El componente ya no pertenece a este equipo.")
                if operation.action == "UPDATE":
                    component_type = await self._validate_component_fields(root, operation, component)
                    self._update_component(component, operation)
                    component.asset_type_id = component_type.id
                    component.asset_type = component_type.name[:120]
                    component.category = "Componente"
                    component.part_number = component_type.part_number
                    positions.append((root.id, component.id, operation.current_position))
                elif operation.action == "MOVE":
                    destination_id = operation.destination_equipment_id or operation.parent_id
                    destination = await self._session.get(AssetRecord, destination_id) if destination_id else None
                    if destination is None or not destination.is_business_anchor:
                        raise ValueError("Selecciona un equipo destino válido.")
                    await self._assign_existing_component(destination, operation.model_copy(update={
                        "action": "ASSIGN", "component_id": component.id,
                        "expected_parent_id": (operation.expected_parent_id
                            if "expected_parent_id" in operation.model_fields_set else component.parent_id),
                        "parent_id": operation.parent_id if operation.destination_equipment_id else destination.id,
                    }), user_id)
                    positions.append((destination.id, component.id, operation.current_position))
                elif operation.action == "DELETE":
                    await self._delete_component(component.id)

        await self._session.flush()
        await self._rebuild_asset_closure()
        for destination_id, component_id, position in positions:
            await self._apply_component_position(destination_id, component_id, position, user_id)
        return await self.get_tree(root_asset_id)

    async def _assign_existing_component(
        self, root: AssetRecord, operation: AssetComponentOperationDTO, user_id: str | None,
    ) -> None:
        if not operation.component_id:
            raise ValueError("Selecciona un componente existente.")
        component = await self._session.get(AssetRecord, operation.component_id, with_for_update=True)
        if component is None or component.is_business_anchor:
            raise ValueError("Selecciona un componente existente, no un equipo principal.")
        if component.parent_id != operation.expected_parent_id:
            raise ValueError("El componente cambió de equipo. Recarga antes de asignarlo.")
        parent = await self._session.get(AssetRecord, operation.parent_id or root.id)
        if parent is None or not await self._is_descendant(root.id, parent.id, include_root=True):
            raise ValueError("El padre destino debe pertenecer al equipo actual.")
        if component.parent_id == parent.id:
            if operation.current_position is not None:
                return
            raise ValueError("El componente ya está asignado a ese padre.")
        if component.id == parent.id or await self._is_descendant(component.id, parent.id):
            raise ValueError("No se puede asignar un componente dentro de sí mismo.")
        if component.subsystem_id != root.subsystem_id or component.subsystem != root.subsystem:
            raise ValueError("El componente debe pertenecer al mismo subsistema que el equipo.")
        same_equipment = await self._is_descendant(root.id, component.id)
        if not same_equipment:
            await self._require_unplaced_subtree(component.id, exclude_root=True)
        previous_parent = await self._session.get(AssetRecord, component.parent_id) if component.parent_id else None
        previous_location = await self._session.get(
            InventoryLocationRecord, component.current_inventory_location_id
        ) if component.current_inventory_location_id else None
        destination_locations = (await self._session.scalars(
            select(InventoryLocationRecord).where(
                InventoryLocationRecord.related_asset_id == root.id,
                InventoryLocationRecord.is_active.is_(True),
            ).order_by(InventoryLocationRecord.id).limit(2)
        )).all()
        destination_location = destination_locations[0] if len(destination_locations) == 1 else None
        kind = await self._session.scalar(
            select(MovementTypeRecord).where(MovementTypeRecord.code == "ASIGNACION_COMPONENTE")
        )
        if kind is None:
            kind = MovementTypeRecord(id=uuid4(), code="ASIGNACION_COMPONENTE", name="Asignación de componente")
            self._session.add(kind)
            await self._session.flush()
        now = datetime.now(UTC)
        origin = previous_parent.name if previous_parent else (
            previous_location.name if previous_location else "Sin asignación registrada"
        )
        self._session.add(AssetMovementRecord(
            asset_id=component.id, movement_type_id=kind.id, moved_at=now, moved_by_user_id=user_id,
            from_inventory_location_id=component.current_inventory_location_id,
            to_inventory_location_id=destination_location.id if destination_location else None,
            from_slot_location_id=component.current_slot_location_id,
            to_slot_location_id=component.current_slot_location_id if same_equipment else None,
            from_status_id=component.status_id, to_status_id=component.status_id,
            notes=f"Asignación desde {origin} hacia {root.name} / {parent.name}.",
        ))
        await self._session.execute(update(AssetAssignmentRecord).where(
            AssetAssignmentRecord.asset_id == component.id,
            AssetAssignmentRecord.unassigned_at.is_(None),
        ).values(unassigned_at=now))
        self._session.add(AssetAssignmentRecord(
            asset_id=component.id, parent_asset_id=parent.id, assigned_at=now,
            slot_location_id=component.current_slot_location_id if same_equipment else None,
            position_snapshot=component.current_position if same_equipment else None,
            geographic_location_id=root.current_geographic_location_id,
            reason=f"Asignación desde {origin} hacia {root.name} / {parent.name}.",
        ))
        descendants = select(AssetClosureRecord.descendant_asset_id).where(
            AssetClosureRecord.ancestor_asset_id == component.id
        )
        placement_changes = {} if same_equipment else {"current_slot_location_id": None, "current_position": None}
        await self._session.execute(update(AssetRecord).where(or_(
            AssetRecord.id == component.id, AssetRecord.id.in_(descendants)
        )).values(
            physical_location=root.physical_location,
            current_geographic_location_id=root.current_geographic_location_id,
            current_inventory_location_id=destination_location.id if destination_location else None,
            **placement_changes,
        ))
        component.parent_id = parent.id
        await self._session.flush()
        await self._rebuild_asset_closure()

    async def _create_component(
        self,
        root: AssetRecord,
        operation: AssetComponentOperationDTO,
        component_type: AssetTypeRecord,
    ) -> str:
        if not operation.name or not operation.name.strip():
            raise ValueError("El nombre del componente es obligatorio.")
        parent = root
        if operation.parent_id:
            parent = await self._session.get(AssetRecord, operation.parent_id)
            if parent is None or not await self._is_descendant(root.id, parent.id, include_root=True):
                raise ValueError("El componente padre debe pertenecer al equipo actual.")
        component_id = str(uuid4())
        serial = self._empty_to_none(operation.serial_number)
        self._session.add(
            AssetRecord(
                id=component_id,
                name=operation.name.strip(),
                category="Componente",
                asset_type=component_type.name[:120],
                subsystem=parent.subsystem,
                serial_or_code=serial or f"ADM-{component_id[:8].upper()}",
                part_number=component_type.part_number,
                status=self._value_or_default(operation.status, "OPERATIVO"),
                physical_location=parent.physical_location,
                is_business_anchor=False,
                parent_id=parent.id,
                children=[],
                asset_type_id=component_type.id,
                equipment_category_id=None,
                equipment_kind_id=None,
                subsystem_id=parent.subsystem_id,
                manufacturer_id=None,
                status_id=None,
                current_geographic_location_id=parent.current_geographic_location_id,
                current_inventory_location_id=None,
                current_slot_location_id=None,
                internal_code=f"ADM-{component_id[:12].upper()}",
                serial_number=serial,
                serial_number_status=("KNOWN" if serial else "NOT_APPLICABLE"
                    if component_type.serial_number_policy == "NOT_APPLICABLE" else "NOT_CAPTURED"),
                model=self._empty_to_none(operation.model),
                manufacture_date=None,
                software_version=None,
                current_position=None,
                business_label="Componente",
                registration_method="MANUAL",
                is_mobile=False,
            )
        )
        return component_id

    @staticmethod
    def _update_component(component: AssetRecord, operation: AssetComponentOperationDTO) -> None:
        if operation.name is not None:
            if not operation.name.strip():
                raise ValueError("El nombre del componente no puede estar vacío.")
            component.name = operation.name.strip()
        if operation.category is not None:
            component.category = operation.category.strip() or component.category
        if operation.asset_type is not None:
            component.asset_type = operation.asset_type.strip() or component.asset_type
        if operation.status is not None:
            component.status = operation.status.strip() or component.status
        if operation.serial_number is not None:
            component.serial_number = PostgresAssetRepository._empty_to_none(operation.serial_number)
            component.serial_number_status = "KNOWN" if component.serial_number else "NOT_CAPTURED"
        if operation.part_number is not None:
            component.part_number = PostgresAssetRepository._empty_to_none(operation.part_number)
        if operation.model is not None:
            component.model = PostgresAssetRepository._empty_to_none(operation.model)

    async def _delete_component(self, component_id: str) -> None:
        has_children = await self._session.scalar(
            select(func.count())
            .select_from(AssetRecord)
            .where(AssetRecord.parent_id == component_id)
        )
        if has_children:
            raise ValueError("No se puede eliminar un componente que contiene otros componentes.")
        # Historical references are protected by PostgreSQL foreign keys. A delete
        # therefore succeeds only for an unreferenced leaf component.
        await self._session.execute(delete(AssetRecord).where(AssetRecord.id == component_id))

    async def _is_descendant(
        self,
        ancestor_id: str,
        descendant_id: str,
        *,
        include_root: bool = False,
    ) -> bool:
        minimum_depth = 0 if include_root else 1
        found = await self._session.scalar(
            select(func.count())
            .select_from(AssetClosureRecord)
            .where(
                AssetClosureRecord.ancestor_asset_id == ancestor_id,
                AssetClosureRecord.descendant_asset_id == descendant_id,
                AssetClosureRecord.depth >= minimum_depth,
            )
        )
        return bool(found)

    async def _rebuild_asset_closure(self) -> None:
        await self._session.execute(delete(AssetClosureRecord))
        await self._session.execute(
            text(
                """
                WITH RECURSIVE hierarchy AS (
                    SELECT id AS ancestor_asset_id, id AS descendant_asset_id, 0 AS depth
                    FROM assets
                    UNION ALL
                    SELECT hierarchy.ancestor_asset_id, child.id, hierarchy.depth + 1
                    FROM hierarchy JOIN assets child ON child.parent_id = hierarchy.descendant_asset_id
                )
                INSERT INTO asset_closure (ancestor_asset_id, descendant_asset_id, depth)
                SELECT ancestor_asset_id, descendant_asset_id, MIN(depth)
                FROM hierarchy GROUP BY ancestor_asset_id, descendant_asset_id
                """
            )
        )
        await self._session.execute(
            text(
                """
                UPDATE assets parent SET children = COALESCE(
                    (SELECT jsonb_agg(child.name ORDER BY child.name)
                     FROM assets child WHERE child.parent_id = parent.id),
                    '[]'::jsonb
                )
                """
            )
        )

    @staticmethod
    def _empty_to_none(value: str | None) -> str | None:
        return value.strip() or None if value is not None else None

    @staticmethod
    def _value_or_default(value: str | None, default: str) -> str:
        return value.strip() or default if value is not None else default

    async def get_history(self, asset_id: str) -> list[AssetHistoryEntryDTO]:
        latest_versions = (
            select(
                ReportVersionRecord.maintenance_report_id.label("report_id"),
                func.max(ReportVersionRecord.version_number).label("version_number"),
            )
            .where(ReportVersionRecord.document_status == "FINALIZED")
            .group_by(ReportVersionRecord.maintenance_report_id)
            .subquery()
        )

        rows = (
            await self._session.execute(
                select(
                    MaintenanceActivityRecord,
                    MaintenanceReportRecord,
                    ReportVersionRecord,
                    PreventiveReportDetailRecord.final_result,
                    CorrectiveReportDetailRecord.technical_status,
                )
                .join(
                    MaintenanceActivityAssetRecord,
                    MaintenanceActivityAssetRecord.maintenance_activity_id
                    == MaintenanceActivityRecord.id,
                )
                .outerjoin(
                    MaintenanceReportRecord,
                    MaintenanceReportRecord.maintenance_activity_id
                    == MaintenanceActivityRecord.id,
                )
                .outerjoin(
                    latest_versions,
                    latest_versions.c.report_id == MaintenanceReportRecord.id,
                )
                .outerjoin(
                    ReportVersionRecord,
                    (
                        ReportVersionRecord.maintenance_report_id
                        == latest_versions.c.report_id
                    )
                    & (
                        ReportVersionRecord.version_number
                        == latest_versions.c.version_number
                    ),
                )
                .outerjoin(
                    PreventiveReportDetailRecord,
                    PreventiveReportDetailRecord.report_version_id == ReportVersionRecord.id,
                )
                .outerjoin(
                    CorrectiveReportDetailRecord,
                    CorrectiveReportDetailRecord.report_version_id == ReportVersionRecord.id,
                )
                .where(
                    MaintenanceActivityAssetRecord.asset_id == asset_id,
                    MaintenanceActivityRecord.status.in_(["COMPLETED", "CLOSED"]),
                )
                .order_by(
                    func.coalesce(
                        ReportVersionRecord.finalized_at,
                        MaintenanceActivityRecord.completed_at,
                        MaintenanceActivityRecord.actual_end_at,
                        MaintenanceActivityRecord.scheduled_start_at,
                        MaintenanceActivityRecord.created_at,
                    ).desc()
                )
            )
        ).all()

        normalized = [
            AssetHistoryEntryDTO(
                id=str(version.id if version is not None else activity.id),
                report_type=activity.activity_type.casefold(),
                report_id=str(
                    version.id
                    if version is not None
                    else report.id
                    if report is not None
                    else activity.id
                ),
                title=activity.title,
                performed_at=(
                    version.finalized_at
                    if version is not None and version.finalized_at is not None
                    else activity.completed_at
                    or activity.actual_end_at
                    or activity.scheduled_start_at
                    or activity.created_at
                ).isoformat(),
                result=preventive_result
                or corrective_status
                or "Sin resultado registrado",
                activity_id=str(activity.id),
                activity_status=activity.status,
                report_kind=report.report_kind if report is not None else None,
                version_number=version.version_number if version is not None else None,
            )
            for activity, report, version, preventive_result, corrective_status in rows
        ]
        if normalized:
            return normalized

        # Transitional development databases may still contain only the old history projection.
        result = await self._session.scalars(
            select(AssetHistoryRecord)
            .where(AssetHistoryRecord.asset_id == asset_id)
            .order_by(AssetHistoryRecord.performed_at.desc())
        )
        return [
            AssetHistoryEntryDTO(
                id=record.id,
                report_type=record.report_type,
                report_id=record.report_id,
                title=record.title,
                performed_at=record.performed_at,
                result=record.result,
            )
            for record in result.all()
        ]

    @staticmethod
    def _to_asset_dto(
        record: AssetRecord,
        *,
        manufacturer: str | None = None,
        component_count: int = 0,
        images: list[AssetImageDTO] | None = None,
    ) -> AssetDTO:
        return AssetDTO(
            id=record.id,
            name=record.name,
            category=record.category,
            asset_type=record.asset_type,
            subsystem=record.subsystem,
            serial_or_code=record.serial_or_code,
            part_number=record.part_number,
            status=record.status,
            physical_location=record.physical_location,
            is_business_anchor=record.is_business_anchor,
            parent_id=record.parent_id,
            children=record.children,
            business_label=record.business_label,
            manufacturer=manufacturer,
            model=record.model,
            software_version=record.software_version,
            current_position=record.current_position,
            equipment_category_id=record.equipment_category_id,
            subsystem_id=record.subsystem_id,
            status_id=record.status_id,
            geographic_location_id=record.current_geographic_location_id,
            component_count=component_count,
            images=images or [],
        )
