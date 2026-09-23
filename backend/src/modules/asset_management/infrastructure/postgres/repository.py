from uuid import uuid4

from sqlalchemy import Select, delete, func, or_, select, text, update
from sqlalchemy.ext.asyncio import AsyncSession

from modules.asset_management.infrastructure.postgres.catalog_models import (
    AssetStatusRecord,
    EquipmentCategoryRecord,
    ManufacturerRecord,
)
from modules.asset_management.infrastructure.postgres.domain_models import (
    AssetClosureRecord,
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
        stmt: Select[tuple[AssetRecord]] = select(AssetRecord).order_by(AssetRecord.name)
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
        if inventory_location:
            stmt = stmt.where(
                func.lower(InventoryLocationRecord.name) == inventory_location.casefold()
            )

        total = await self._session.scalar(
            select(func.count()).select_from(stmt.order_by(None).subquery())
        )
        rows = (await self._session.execute(stmt.limit(limit).offset(offset))).all()
        return [
            StockAssetDTO(
                id=record.id,
                name=record.name,
                asset_type=record.asset_type,
                serial_number=record.serial_number,
                internal_code=record.internal_code,
                part_number=record.part_number,
                status=record.status,
                inventory_location=location,
                subsystem=record.subsystem,
                manufacturer=manufacturer,
                model=record.model,
            )
            for record, location, manufacturer in rows
        ], total or 0

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
        if not rows:
            return []

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
        slot_records = {
            slot.id: slot
            for slot in (
                await self._session.scalars(select(SlotLocationRecord))
            ).all()
        }
        included_slots: set[str] = set()
        for slot_id in current_slots:
            current_id: str | None = slot_id
            while current_id and current_id not in included_slots:
                included_slots.add(current_id)
                current = slot_records.get(current_id)
                current_id = current.parent_slot_location_id if current else None

        # A slot that owns exactly one installed asset is the physical identity
        # of that asset, not an extra folder. Rendering both used to produce
        # paths such as TIR 1 -> TIR 1 EQUIPED 600 -> its components. Map those
        # slots to their asset, while retaining virtual folders for empty slots
        # and slots holding multiple assets.
        assets_by_slot: dict[str, list[AssetRecord]] = {}
        for _, record, _, _ in rows:
            if record.current_slot_location_id in included_slots:
                assets_by_slot.setdefault(record.current_slot_location_id, []).append(record)
        slot_owner_asset_id = {
            slot_id: records[0].id
            for slot_id, records in assets_by_slot.items()
            if len(records) == 1
        }

        def slot_node_id(slot_id: str) -> str:
            return slot_owner_asset_id.get(slot_id, f"slot:{slot_id}")

        def parent_slot_node_id(slot_id: str | None) -> str:
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
                status="ACTIVE",
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

    async def apply_component_changes(
        self,
        root_asset_id: str,
        operations: list[AssetComponentOperationDTO],
    ) -> list[AssetTreeNodeDTO]:
        """Apply a staged component administration batch atomically.

        The root equipment itself cannot be edited here. Existing components must
        belong to its current tree; a move may target another business-anchor
        equipment, which is the explicit "move to another equipment" operation.
        """
        root = await self._session.get(AssetRecord, root_asset_id)
        if root is None or not root.is_business_anchor:
            raise ValueError("El equipo principal no existe o no es administrable.")

        for operation in operations:
            if operation.action == "CREATE":
                await self._create_component(root, operation)
            else:
                if not operation.component_id:
                    raise ValueError("La operación requiere el componente a modificar.")
                component = await self._session.get(AssetRecord, operation.component_id)
                if component is None:
                    raise ValueError("El componente seleccionado ya no existe.")
                if not await self._is_descendant(root_asset_id, component.id):
                    raise ValueError("El componente ya no pertenece a este equipo.")
                if operation.action == "UPDATE":
                    self._update_component(component, operation)
                elif operation.action == "MOVE":
                    await self._move_component(component, operation)
                elif operation.action == "DELETE":
                    await self._delete_component(component.id)

        await self._session.flush()
        await self._rebuild_asset_closure()
        return await self.get_tree(root_asset_id)

    async def _create_component(
        self,
        root: AssetRecord,
        operation: AssetComponentOperationDTO,
    ) -> None:
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
                category=self._value_or_default(operation.category, "Componente"),
                asset_type=self._value_or_default(operation.asset_type, "Componente no tipificado"),
                subsystem=parent.subsystem,
                serial_or_code=serial or f"ADM-{component_id[:8].upper()}",
                part_number=self._empty_to_none(operation.part_number),
                status=self._value_or_default(operation.status, "OPERATIVO"),
                physical_location=parent.physical_location,
                is_business_anchor=False,
                parent_id=parent.id,
                children=[],
                asset_type_id=None,
                equipment_category_id=parent.equipment_category_id,
                equipment_kind_id=parent.equipment_kind_id,
                subsystem_id=parent.subsystem_id,
                manufacturer_id=None,
                status_id=None,
                current_geographic_location_id=parent.current_geographic_location_id,
                current_inventory_location_id=None,
                current_slot_location_id=None,
                internal_code=f"ADM-{component_id[:12].upper()}",
                serial_number=serial,
                serial_number_status="KNOWN" if serial else "NOT_CAPTURED",
                model=self._empty_to_none(operation.model),
                manufacture_date=None,
                software_version=None,
                current_position=self._empty_to_none(operation.current_position),
                business_label="Componente",
                registration_method="MANUAL",
                is_mobile=False,
            )
        )

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
        if operation.current_position is not None:
            component.current_position = PostgresAssetRepository._empty_to_none(operation.current_position)

    async def _move_component(
        self,
        component: AssetRecord,
        operation: AssetComponentOperationDTO,
    ) -> None:
        if not operation.parent_id:
            raise ValueError("Seleccione el equipo destino para mover el componente.")
        destination = await self._session.get(AssetRecord, operation.parent_id)
        if destination is None or not destination.is_business_anchor:
            raise ValueError("El destino debe ser un equipo principal existente.")
        if component.id == destination.id or await self._is_descendant(component.id, destination.id):
            raise ValueError("No se puede mover un componente dentro de sí mismo.")
        descendant_ids = select(AssetClosureRecord.descendant_asset_id).where(
            AssetClosureRecord.ancestor_asset_id == component.id
        )
        await self._session.execute(
            update(AssetRecord)
            .where(AssetRecord.id.in_(descendant_ids))
            .values(
                subsystem=destination.subsystem,
                subsystem_id=destination.subsystem_id,
                physical_location=destination.physical_location,
                current_geographic_location_id=destination.current_geographic_location_id,
            )
        )
        component.parent_id = destination.id

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
