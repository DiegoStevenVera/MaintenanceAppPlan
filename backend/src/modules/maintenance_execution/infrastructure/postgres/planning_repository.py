from datetime import date, datetime, timedelta, timezone
from uuid import UUID, uuid4
from zoneinfo import ZoneInfo

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from modules.asset_management.infrastructure.postgres.catalog_models import (
    EquipmentCategoryRecord,
)
from modules.asset_management.infrastructure.postgres.models import AssetRecord
from modules.identity_access.infrastructure.postgres.models import UserRecord
from modules.maintenance_execution.infrastructure.postgres.models import PreventiveScheduleRecord
from modules.maintenance_execution.infrastructure.postgres.planning_models import (
    MaintenanceScheduleRevisionRecord,
    PCONAnnualPlanRecord,
    PCONAnnualPlanScopeRecord,
    PCONPlanChangeRecord,
    WeeklyPlanningSessionRecord,
)
from modules.maintenance_execution.infrastructure.postgres.report_models import (
    MaintenanceActivityAssetRecord,
    MaintenanceActivityRecord,
    MaintenanceReportRecord,
)
from modules.maintenance_execution.infrastructure.postgres.template_models import (
    MaintenancePlanEntryRecord,
    MaintenanceTemplateRecord,
    MaintenanceTemplateScopeRecord,
)
from modules.maintenance_execution.interfaces.planning_schemas import (
    AddPlanScopeResponse,
    CopyAnnualPlanResponse,
    PCONCatalogAssetDTO,
    PCONCatalogDTO,
    PCONCatalogTemplateDTO,
    PCONPlanChangeDTO,
    PCONAnnualMonthDTO,
    PCONAnnualPlanDTO,
    PCONAnnualRowDTO,
    PCONPlanItemDTO,
    PlanningHistoryItemDTO,
    PlanningState,
    ScheduleProposalDTO,
    ScheduleProposalRequest,
    WeeklyPlanningDetailDTO,
    WeeklyPlanningSessionDTO,
)
from modules.organizational_context.infrastructure.postgres.models import (
    SubsystemRecord,
    SystemRecord,
)
from modules.organizational_context.infrastructure.postgres.operational_models import (
    GeographicLocationRecord,
)

LIMA = ZoneInfo("America/Lima")


class PlanningValidationError(ValueError):
    pass


class PlanningNotFoundError(LookupError):
    pass


class PostgresPlanningRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def list_plan(
        self,
        *,
        year: int,
        month: int | None,
        subsystem: str | None,
        query: str | None,
    ) -> list[PCONPlanItemDTO]:
        statement = (
            select(
                MaintenancePlanEntryRecord,
                MaintenanceTemplateScopeRecord,
                MaintenanceTemplateRecord,
                SubsystemRecord,
                AssetRecord,
                EquipmentCategoryRecord,
                GeographicLocationRecord,
                MaintenanceActivityRecord,
            )
            .join(
                MaintenanceTemplateScopeRecord,
                MaintenanceTemplateScopeRecord.id
                == MaintenancePlanEntryRecord.maintenance_template_scope_id,
            )
            .join(
                MaintenanceTemplateRecord,
                MaintenanceTemplateRecord.id
                == MaintenanceTemplateScopeRecord.maintenance_template_id,
            )
            .join(
                SubsystemRecord,
                SubsystemRecord.id == MaintenanceTemplateRecord.subsystem_id,
            )
            .outerjoin(
                AssetRecord,
                AssetRecord.id == MaintenanceTemplateScopeRecord.asset_id,
            )
            .outerjoin(
                EquipmentCategoryRecord,
                EquipmentCategoryRecord.id
                == func.coalesce(
                    MaintenanceTemplateScopeRecord.equipment_category_id,
                    AssetRecord.equipment_category_id,
                ),
            )
            .outerjoin(
                GeographicLocationRecord,
                GeographicLocationRecord.id
                == func.coalesce(
                    MaintenanceTemplateScopeRecord.geographic_location_id,
                    AssetRecord.current_geographic_location_id,
                ),
            )
            .outerjoin(
                PreventiveScheduleRecord,
                PreventiveScheduleRecord.maintenance_plan_entry_id
                == MaintenancePlanEntryRecord.id,
            )
            .outerjoin(
                MaintenanceActivityRecord,
                MaintenanceActivityRecord.id
                == PreventiveScheduleRecord.maintenance_activity_id,
            )
            .where(
                MaintenancePlanEntryRecord.year == year,
                MaintenancePlanEntryRecord.planning_status == "PLANNED",
                MaintenanceActivityRecord.id.is_not(None),
            )
            .order_by(
                SubsystemRecord.code,
                MaintenanceTemplateScopeRecord.display_name,
                MaintenanceActivityRecord.title,
            )
        )
        if month is not None:
            statement = statement.where(MaintenancePlanEntryRecord.month == month)
        if subsystem:
            statement = statement.where(
                or_(
                    func.lower(SubsystemRecord.code) == subsystem.casefold(),
                    func.lower(SubsystemRecord.name) == subsystem.casefold(),
                )
            )
        if query and query.strip():
            pattern = f"%{query.strip()}%"
            statement = statement.where(
                or_(
                    MaintenanceActivityRecord.title.ilike(pattern),
                    MaintenanceTemplateScopeRecord.display_name.ilike(pattern),
                    AssetRecord.name.ilike(pattern),
                    EquipmentCategoryRecord.name_n1.ilike(pattern),
                    EquipmentCategoryRecord.name_n2.ilike(pattern),
                    GeographicLocationRecord.full_path.ilike(pattern),
                    SubsystemRecord.code.ilike(pattern),
                    SubsystemRecord.name.ilike(pattern),
                    MaintenanceTemplateRecord.activity_n1.ilike(pattern),
                    MaintenanceTemplateRecord.activity_n2.ilike(pattern),
                    MaintenanceTemplateRecord.activity_n3_summary.ilike(pattern),
                )
            )

        rows = (await self.session.execute(statement)).all()
        activity_ids = [row[7].id for row in rows]
        drafts = await self._draft_revisions_by_activity(activity_ids)
        items: list[PCONPlanItemDTO] = []
        for (
            plan,
            scope,
            template,
            subsystem_row,
            asset,
            category,
            location,
            activity,
        ) in rows:
            draft = drafts.get(activity.id)
            if activity.status in {"COMPLETED", "CLOSED"}:
                state = PlanningState.EXECUTED
            elif draft and activity.scheduled_start_at:
                state = PlanningState.RESCHEDULE_PENDING
            elif draft:
                state = PlanningState.PROPOSED
            elif activity.scheduled_start_at:
                state = PlanningState.CONFIRMED
            else:
                state = PlanningState.MONTH_ONLY
            items.append(
                PCONPlanItemDTO(
                    plan_entry_id=plan.id,
                    activity_id=activity.id,
                    maintenance_template_scope_id=scope.id,
                    maintenance_template_id=template.id,
                    title=activity.title,
                    template_name=template.activity_n1,
                    maintenance_name=(
                        template.activity_n3_summary
                        or template.activity_n2
                        or template.activity_n1
                    ),
                    frequency=template.frequency,
                    equipment_id=scope.asset_id,
                    equipment_name=asset.name if asset else scope.display_name,
                    equipment_category=(
                        category.name_n2
                        if category and category.name_n2
                        else category.name_n1
                        if category
                        else asset.category
                        if asset
                        else "Sin categoría"
                    ),
                    location_name=(
                        location.full_path
                        if location
                        else asset.physical_location
                        if asset
                        else "Sin ubicación"
                    ),
                    subsystem_code=subsystem_row.code,
                    subsystem_name=subsystem_row.name,
                    year=plan.year,
                    month=plan.month,
                    estimated_minutes=template.estimated_minutes,
                    required_workers=plan.required_workers or template.required_personnel,
                    activity_status=activity.status,
                    scheduled_start_at=activity.scheduled_start_at,
                    scheduled_end_at=activity.scheduled_end_at,
                    proposed_start_at=draft.proposed_start_at if draft else None,
                    proposed_end_at=draft.proposed_end_at if draft else None,
                    planning_state=state,
                )
            )
        return items

    async def list_annual_plan(
        self,
        *,
        year: int,
        subsystem: str | None,
        query: str | None,
    ) -> PCONAnnualPlanDTO:
        annual_plan = (
            await self.session.execute(
                select(PCONAnnualPlanRecord).where(PCONAnnualPlanRecord.year == year)
            )
        ).scalar_one_or_none()
        is_virtual = annual_plan is None
        copied_from_year: int | None = None
        imported_scope_year, imported_scope_ids = (
            await self._scope_ids_from_imported_entries(year)
        )
        if annual_plan is None:
            source_plan = (
                await self.session.execute(
                    select(PCONAnnualPlanRecord)
                    .where(PCONAnnualPlanRecord.year < year)
                    .order_by(PCONAnnualPlanRecord.year.desc())
                    .limit(1)
                )
            ).scalar_one_or_none()
            if source_plan is None:
                # Imported annual activities predate the PCON administration
                # tables. They remain the source of truth until an admin
                # explicitly manages the year from the app.
                scope_ids = imported_scope_ids
            else:
                copied_from_year = source_plan.year
                scope_ids = self._unique_scope_ids(
                    await self._annual_scope_ids(source_plan.id),
                    imported_scope_ids,
                )
            plan_status = "DRAFT"
        else:
            copied_from_year = annual_plan.copied_from_year
            # Keep imported rows visible after the first administration
            # action. Membership records augment the imported plan rather
            # than replacing its already-existing scopes.
            scope_ids = self._unique_scope_ids(
                await self._annual_scope_ids(annual_plan.id),
                imported_scope_ids,
            )
            plan_status = annual_plan.status

        if copied_from_year is None and imported_scope_year != year:
            copied_from_year = imported_scope_year

        catalog_rows = await self._scope_catalog_rows(
            scope_ids=scope_ids,
            subsystem=subsystem,
            query=query,
        )
        items = await self.list_plan(
            year=year,
            month=None,
            subsystem=None,
            query=None,
        )
        grouped: dict[UUID, list[PCONPlanItemDTO]] = {
            scope_id: [] for scope_id in scope_ids
        }
        for item in items:
            if item.maintenance_template_scope_id in grouped:
                grouped[item.maintenance_template_scope_id].append(item)

        rows: list[PCONAnnualRowDTO] = []
        for scope, template, subsystem_row, asset, category, location in catalog_rows:
            occurrences = grouped.get(scope.id, [])
            month_dtos: list[PCONAnnualMonthDTO] = []
            for month in range(1, 13):
                monthly = [item for item in occurrences if item.month == month]
                month_dtos.append(
                    PCONAnnualMonthDTO(
                        month=month,
                        count=len(monthly),
                        month_only_count=sum(
                            item.planning_state == PlanningState.MONTH_ONLY
                            for item in monthly
                        ),
                        proposed_count=sum(
                            item.planning_state
                            in {
                                PlanningState.PROPOSED,
                                PlanningState.RESCHEDULE_PENDING,
                            }
                            for item in monthly
                        ),
                        confirmed_count=sum(
                            item.planning_state == PlanningState.CONFIRMED
                            for item in monthly
                        ),
                        executed_count=sum(
                            item.planning_state == PlanningState.EXECUTED
                            for item in monthly
                        ),
                        occurrences=monthly,
                    )
                )
            rows.append(
                PCONAnnualRowDTO(
                    id=scope.id,
                    maintenance_template_scope_id=scope.id,
                    maintenance_template_id=template.id,
                    subsystem_code=subsystem_row.code,
                    subsystem_name=subsystem_row.name,
                    equipment_category=self._category_name(category, asset),
                    location_name=self._location_name(location, asset),
                    equipment_id=scope.asset_id,
                    equipment_name=asset.name if asset else scope.display_name,
                    maintenance_name=self._maintenance_name(template),
                    frequency=template.frequency,
                    annual_count=len(occurrences),
                    months=month_dtos,
                )
            )
        rows.sort(
            key=lambda row: (
                row.subsystem_code.casefold(),
                row.equipment_category.casefold(),
                row.location_name.casefold(),
                row.equipment_name.casefold(),
                row.maintenance_name.casefold(),
            )
        )
        return PCONAnnualPlanDTO(
            year=year,
            status=plan_status,
            copied_from_year=copied_from_year,
            is_virtual=is_virtual,
            rows=rows,
            total_rows=len(rows),
            total_executions=sum(row.annual_count for row in rows),
        )

    async def set_annual_count(
        self,
        *,
        scope_id: UUID,
        year: int,
        month: int,
        target_count: int,
        user_id: str,
    ) -> tuple[int, int, int]:
        await self._ensure_editable_year(year)
        scope = await self.session.get(MaintenanceTemplateScopeRecord, scope_id)
        if scope is None:
            raise PlanningNotFoundError("Mantenimiento del equipo no encontrado")
        template = await self.session.get(
            MaintenanceTemplateRecord,
            scope.maintenance_template_id,
        )
        if template is None:
            raise PlanningNotFoundError("Plantilla de mantenimiento no encontrada")

        annual_plan = await self._get_or_create_annual_plan(year, user_id)
        await self._ensure_annual_membership(annual_plan.id, scope_id, user_id)
        rows = await self._occurrence_rows(
            scope_id=scope_id,
            year=year,
            month=month,
            lock=True,
        )
        previous_count = len(rows)
        if target_count == previous_count:
            return previous_count, 0, 0
        if target_count > previous_count:
            created = target_count - previous_count
            await self._create_occurrences(
                scope=scope,
                template=template,
                year=year,
                month=month,
                quantity=created,
                user_id=user_id,
            )
            self._add_change(
                action="SET_COUNT",
                year=year,
                month=month,
                scope_id=scope_id,
                user_id=user_id,
                quantity_delta=created,
                details={"previous_count": previous_count, "count": target_count},
            )
            return previous_count, created, 0

        remove_count = previous_count - target_count
        removable: list[
            tuple[
                MaintenancePlanEntryRecord,
                PreventiveScheduleRecord,
                MaintenanceActivityRecord,
            ]
        ] = []
        for row in rows:
            plan, schedule, activity = row
            has_revision = await self.session.scalar(
                select(func.count(MaintenanceScheduleRevisionRecord.id)).where(
                    MaintenanceScheduleRevisionRecord.maintenance_activity_id
                    == activity.id
                )
            )
            has_report = await self.session.scalar(
                select(func.count(MaintenanceReportRecord.id)).where(
                    MaintenanceReportRecord.maintenance_activity_id == activity.id
                )
            )
            if (
                activity.status == "SCHEDULED"
                and activity.scheduled_start_at is None
                and not has_revision
                and not has_report
                and schedule.report_version_count == 0
            ):
                removable.append((plan, schedule, activity))
        if len(removable) < remove_count:
            raise PlanningValidationError(
                "No se puede reducir esa cantidad: algunas ocurrencias ya tienen "
                "fecha, propuesta, ejecución o reporte"
            )
        for plan, schedule, _ in removable[:remove_count]:
            self._cancel_plan_entry(
                plan=plan,
                schedule=schedule,
                user_id=user_id,
                reason="Reducción de cantidad mensual",
            )
        self._add_change(
            action="SET_COUNT",
            year=year,
            month=month,
            scope_id=scope_id,
            user_id=user_id,
            quantity_delta=-remove_count,
            details={"previous_count": previous_count, "count": target_count},
        )
        return previous_count, 0, remove_count

    async def create_occurrences(
        self,
        *,
        scope_id: UUID,
        year: int,
        month: int,
        quantity: int,
        user_id: str,
        reason: str | None,
    ) -> int:
        await self._ensure_editable_year(year)
        scope = await self.session.get(MaintenanceTemplateScopeRecord, scope_id)
        if scope is None:
            raise PlanningNotFoundError("Mantenimiento del equipo no encontrado")
        template = await self.session.get(
            MaintenanceTemplateRecord,
            scope.maintenance_template_id,
        )
        if template is None:
            raise PlanningNotFoundError("Plantilla de mantenimiento no encontrada")
        annual_plan = await self._get_or_create_annual_plan(year, user_id)
        await self._ensure_annual_membership(annual_plan.id, scope.id, user_id)
        await self._create_occurrences(
            scope=scope,
            template=template,
            year=year,
            month=month,
            quantity=quantity,
            user_id=user_id,
        )
        self._add_change(
            action="CREATE_OCCURRENCES",
            year=year,
            month=month,
            scope_id=scope.id,
            user_id=user_id,
            quantity_delta=quantity,
            reason=reason,
        )
        return quantity

    async def move_occurrence(
        self,
        *,
        plan_entry_id: UUID,
        year: int,
        month: int,
        user_id: str,
        reason: str | None,
    ) -> None:
        await self._ensure_editable_year(year)
        row = await self._occurrence_by_id(plan_entry_id, lock=True)
        if row is None:
            raise PlanningNotFoundError("Ocurrencia PCON no encontrada")
        plan, _, activity = row
        if plan.planning_status != "PLANNED":
            raise PlanningValidationError("La ocurrencia ya fue eliminada del plan")
        if activity.status != "SCHEDULED" or activity.scheduled_start_at:
            raise PlanningValidationError(
                "Una ocurrencia iniciada o con fecha confirmada se reprograma desde la semana"
            )
        # A tentative weekly proposal is only a planning window. Moving an
        # annual occurrence invalidates that draft proposal; it is not a
        # confirmed execution and must not block the annual-plan editor.
        await self._remove_draft_schedule_revisions(activity.id)
        previous_year, previous_month = plan.year, plan.month
        annual_plan = await self._get_or_create_annual_plan(year, user_id)
        await self._ensure_annual_membership(
            annual_plan.id,
            plan.maintenance_template_scope_id,
            user_id,
        )
        plan.year = year
        plan.month = month
        self._add_change(
            action="MOVE_OCCURRENCE",
            year=year,
            month=month,
            scope_id=plan.maintenance_template_scope_id,
            plan_entry_id=plan.id,
            user_id=user_id,
            reason=reason,
            details={"previous_year": previous_year, "previous_month": previous_month},
        )

    async def remove_occurrence(
        self,
        *,
        plan_entry_id: UUID,
        user_id: str,
        reason: str,
        allow_confirmed_future: bool,
    ) -> None:
        row = await self._occurrence_by_id(plan_entry_id, lock=True)
        if row is None:
            raise PlanningNotFoundError("Ocurrencia PCON no encontrada")
        plan, schedule, activity = row
        await self._ensure_editable_year(plan.year)
        if plan.planning_status != "PLANNED":
            raise PlanningValidationError("La ocurrencia ya fue eliminada del plan")
        if activity.status in {"IN_PROGRESS", "COMPLETED", "CLOSED"}:
            raise PlanningValidationError(
                "No se puede eliminar una actividad iniciada, completada o cerrada"
            )
        if await self._has_report(activity.id):
            raise PlanningValidationError("No se puede eliminar una actividad con reporte")
        # Deleting an unconfirmed annual occurrence also removes its pending
        # tentative proposal, so users do not have to visit another screen.
        await self._remove_draft_schedule_revisions(activity.id)
        if activity.scheduled_start_at:
            if not allow_confirmed_future:
                raise PlanningValidationError(
                    "La actividad tiene fecha confirmada; usa la acción Cancelar"
                )
            if activity.scheduled_start_at <= datetime.now(timezone.utc):
                raise PlanningValidationError(
                    "Solo se pueden cancelar actividades confirmadas futuras"
                )
        self._cancel_plan_entry(
            plan=plan,
            schedule=schedule,
            user_id=user_id,
            reason=reason,
        )
        self._add_change(
            action="CANCEL_OCCURRENCE" if allow_confirmed_future else "REMOVE_OCCURRENCE",
            year=plan.year,
            month=plan.month,
            scope_id=plan.maintenance_template_scope_id,
            plan_entry_id=plan.id,
            user_id=user_id,
            quantity_delta=-1,
            reason=reason,
        )

    async def copy_annual_plan(
        self,
        *,
        source_year: int,
        target_year: int,
        user_id: str,
    ) -> CopyAnnualPlanResponse:
        if source_year == target_year:
            raise PlanningValidationError("El año de origen y destino deben ser distintos")
        await self._ensure_editable_year(target_year)
        source_plan = await self._annual_plan_by_year(source_year)
        if source_plan is None:
            raise PlanningNotFoundError("El plan de origen no existe")
        target_plan = await self._get_or_create_annual_plan(
            target_year,
            user_id,
            copied_from_year=source_year,
        )
        source_scope_ids = await self._annual_scope_ids(source_plan.id)
        target_scope_ids = set(await self._annual_scope_ids(target_plan.id))
        scopes_added = 0
        for scope_id in source_scope_ids:
            if scope_id not in target_scope_ids:
                await self._ensure_annual_membership(target_plan.id, scope_id, user_id)
                scopes_added += 1

        source_counts = await self._counts_by_scope_month(source_year)
        target_counts = await self._counts_by_scope_month(target_year)
        created = 0
        preserved = 0
        for (scope_id, month), source_count in source_counts.items():
            target_count = target_counts.get((scope_id, month), 0)
            if target_count:
                preserved += 1
                continue
            scope = await self.session.get(MaintenanceTemplateScopeRecord, scope_id)
            if scope is None:
                continue
            template = await self.session.get(
                MaintenanceTemplateRecord,
                scope.maintenance_template_id,
            )
            if template is None:
                continue
            await self._create_occurrences(
                scope=scope,
                template=template,
                year=target_year,
                month=month,
                quantity=source_count,
                user_id=user_id,
            )
            created += source_count
        target_plan.copied_from_year = source_year
        self._add_change(
            action="COPY_YEAR",
            year=target_year,
            month=None,
            scope_id=None,
            user_id=user_id,
            quantity_delta=created,
            details={
                "source_year": source_year,
                "scopes_added": scopes_added,
                "preserved_cells": preserved,
            },
        )
        return CopyAnnualPlanResponse(
            source_year=source_year,
            target_year=target_year,
            scopes_added=scopes_added,
            occurrences_created=created,
            preserved_cells=preserved,
        )

    async def get_catalog(self) -> PCONCatalogDTO:
        asset_rows = (
            await self.session.execute(
                select(AssetRecord)
                .where(AssetRecord.is_business_anchor.is_(True))
                .order_by(AssetRecord.subsystem, AssetRecord.name)
            )
        ).scalars()
        template_rows = (
            await self.session.execute(
                select(MaintenanceTemplateRecord, SubsystemRecord)
                .join(
                    SubsystemRecord,
                    SubsystemRecord.id == MaintenanceTemplateRecord.subsystem_id,
                )
                .where(MaintenanceTemplateRecord.is_active.is_(True))
                .order_by(SubsystemRecord.code, MaintenanceTemplateRecord.activity_n1)
            )
        ).all()
        return PCONCatalogDTO(
            assets=[
                PCONCatalogAssetDTO(
                    id=asset.id,
                    name=asset.name,
                    subsystem=asset.subsystem,
                    category=asset.category,
                    location_name=asset.physical_location,
                )
                for asset in asset_rows
            ],
            templates=[
                PCONCatalogTemplateDTO(
                    id=template.id,
                    name=self._maintenance_name(template),
                    subsystem_code=subsystem.code,
                    frequency=template.frequency,
                    estimated_minutes=template.estimated_minutes,
                    required_workers=template.required_personnel,
                )
                for template, subsystem in template_rows
            ],
        )

    async def add_plan_scope(
        self,
        *,
        year: int,
        asset_id: str,
        template_id: UUID,
        month: int,
        quantity: int,
        user_id: str,
        reason: str | None,
    ) -> AddPlanScopeResponse:
        await self._ensure_editable_year(year)
        asset = await self.session.get(AssetRecord, asset_id)
        template = await self.session.get(MaintenanceTemplateRecord, template_id)
        if asset is None or not asset.is_business_anchor:
            raise PlanningNotFoundError("Equipo grande no encontrado")
        if template is None or not template.is_active:
            raise PlanningNotFoundError("Definición de mantenimiento no encontrada")
        subsystem = await self.session.get(SubsystemRecord, template.subsystem_id)
        if subsystem is None or asset.subsystem.casefold() not in {
            subsystem.code.casefold(),
            subsystem.name.casefold(),
        }:
            raise PlanningValidationError(
                "El equipo y el mantenimiento deben pertenecer al mismo subsistema"
            )
        scope = (
            await self.session.execute(
                select(MaintenanceTemplateScopeRecord).where(
                    MaintenanceTemplateScopeRecord.maintenance_template_id == template.id,
                    MaintenanceTemplateScopeRecord.asset_id == asset.id,
                )
            )
        ).scalar_one_or_none()
        created_scope = scope is None
        if scope is None:
            scope = MaintenanceTemplateScopeRecord(
                maintenance_template_id=template.id,
                asset_id=asset.id,
                equipment_category_id=asset.equipment_category_id,
                geographic_location_id=asset.current_geographic_location_id,
                display_name=self._maintenance_name(template),
                notes="Creado desde el administrador PCON",
            )
            self.session.add(scope)
            await self.session.flush()
        annual_plan = await self._get_or_create_annual_plan(year, user_id)
        created_membership = await self._ensure_annual_membership(
            annual_plan.id,
            scope.id,
            user_id,
        )
        await self._create_occurrences(
            scope=scope,
            template=template,
            year=year,
            month=month,
            quantity=quantity,
            user_id=user_id,
        )
        self._add_change(
            action="ADD_PLAN_SCOPE",
            year=year,
            month=month,
            scope_id=scope.id,
            user_id=user_id,
            quantity_delta=quantity,
            reason=reason,
            details={"created_scope": created_scope},
        )
        return AddPlanScopeResponse(
            maintenance_template_scope_id=scope.id,
            created_scope=created_scope,
            created_membership=created_membership,
            occurrences_created=quantity,
        )

    async def list_plan_changes(self, *, year: int, limit: int) -> list[PCONPlanChangeDTO]:
        rows = (
            await self.session.execute(
                select(
                    PCONPlanChangeRecord,
                    MaintenanceTemplateScopeRecord,
                    MaintenanceTemplateRecord,
                    AssetRecord,
                    UserRecord,
                )
                .outerjoin(
                    MaintenanceTemplateScopeRecord,
                    MaintenanceTemplateScopeRecord.id
                    == PCONPlanChangeRecord.maintenance_template_scope_id,
                )
                .outerjoin(
                    MaintenanceTemplateRecord,
                    MaintenanceTemplateRecord.id
                    == MaintenanceTemplateScopeRecord.maintenance_template_id,
                )
                .outerjoin(AssetRecord, AssetRecord.id == MaintenanceTemplateScopeRecord.asset_id)
                .join(UserRecord, UserRecord.id == PCONPlanChangeRecord.changed_by_user_id)
                .where(PCONPlanChangeRecord.year == year)
                .order_by(PCONPlanChangeRecord.created_at.desc())
                .limit(limit)
            )
        ).all()
        return [
            PCONPlanChangeDTO(
                id=change.id,
                action=change.action,
                year=change.year,
                month=change.month,
                equipment_name=asset.name if asset else None,
                maintenance_name=(
                    self._maintenance_name(template) if template else None
                ),
                quantity_delta=change.quantity_delta,
                reason=change.reason,
                changed_by_name=user.name,
                changed_at=change.created_at,
            )
            for change, _, template, asset, user in rows
        ]

    async def _create_occurrences(
        self,
        *,
        scope: MaintenanceTemplateScopeRecord,
        template: MaintenanceTemplateRecord,
        year: int,
        month: int,
        quantity: int,
        user_id: str,
    ) -> None:
        source = await self._base_occurrence(scope.id)
        for _ in range(quantity):
            await self._clone_plan_occurrence(
                scope=scope,
                template=template,
                year=year,
                month=month,
                source=source,
                user_id=user_id,
            )

    async def _clone_plan_occurrence(
        self,
        *,
        scope: MaintenanceTemplateScopeRecord,
        template: MaintenanceTemplateRecord,
        year: int,
        month: int,
        source: tuple[
            MaintenancePlanEntryRecord,
            PreventiveScheduleRecord,
            MaintenanceActivityRecord,
        ]
        | None,
        user_id: str,
    ) -> MaintenancePlanEntryRecord:
        source_plan = source[0] if source else None
        source_schedule = source[1] if source else None
        source_activity = source[2] if source else None
        asset = await self.session.get(AssetRecord, scope.asset_id) if scope.asset_id else None
        subsystem = await self.session.get(SubsystemRecord, template.subsystem_id)
        project_id = source_activity.project_id if source_activity else await self.session.scalar(
            select(SystemRecord.project_id)
            .join(SubsystemRecord, SubsystemRecord.system_id == SystemRecord.id)
            .where(SubsystemRecord.id == template.subsystem_id)
        )
        geographic_location_id = (
            scope.geographic_location_id
            or (asset.current_geographic_location_id if asset else None)
        )
        location_path = (
            source_activity.location_path_snapshot
            if source_activity
            else asset.physical_location
            if asset
            else ""
        )
        plan = MaintenancePlanEntryRecord(
            maintenance_template_scope_id=scope.id,
            year=year,
            month=month,
            item_number=source_plan.item_number if source_plan else None,
            planned_hours=source_plan.planned_hours if source_plan else None,
            required_workers=(
                source_plan.required_workers
                if source_plan
                else template.required_personnel
            ),
            source_reference="PCON_NATIVE",
            planning_status="PLANNED",
        )
        activity = MaintenanceActivityRecord(
            activity_type="PREVENTIVE",
            status="SCHEDULED",
            project_id=project_id,
            primary_stage_id=source_activity.primary_stage_id if source_activity else None,
            subsystem_id=template.subsystem_id,
            geographic_location_id=geographic_location_id,
            maintenance_template_id=template.id,
            title=self._maintenance_name(template),
            internal_code=f"PCON-{year}-{month:02d}-{uuid4().hex[:12].upper()}",
            location_path_snapshot=location_path,
            created_by_user_id=user_id,
        )
        if activity.project_id is None:
            raise PlanningValidationError(
                "No existe una ocurrencia base con proyecto para crear otra ejecución"
            )
        self.session.add_all([plan, activity])
        await self.session.flush()
        schedule_id = f"pcon-{uuid4()}"
        schedule = PreventiveScheduleRecord(
            id=schedule_id,
            name=self._maintenance_name(template),
            template_name=(
                template.activity_n3_summary
                or template.activity_n2
                or template.activity_n1
            ),
            asset_ids=(
                source_schedule.asset_ids
                if source_schedule
                else [scope.asset_id]
                if scope.asset_id
                else []
            ),
            asset_names=(
                source_schedule.asset_names
                if source_schedule
                else [asset.name if asset else scope.display_name]
            ),
            subsystem=(
                source_schedule.subsystem
                if source_schedule
                else subsystem.name
                if subsystem
                else ""
            ),
            scheduled_at="",
            status="SCHEDULED",
            physical_location=location_path,
            report_version_count=0,
            maintenance_activity_id=activity.id,
            maintenance_template_id=template.id,
            maintenance_plan_entry_id=plan.id,
        )
        self.session.add(schedule)
        if source_activity:
            assets = (
                await self.session.execute(
                    select(MaintenanceActivityAssetRecord).where(
                        MaintenanceActivityAssetRecord.maintenance_activity_id
                        == source_activity.id
                    )
                )
            ).scalars()
            for asset in assets:
                self.session.add(
                    MaintenanceActivityAssetRecord(
                        maintenance_activity_id=activity.id,
                        asset_id=asset.asset_id,
                        role=asset.role,
                        include_descendants=asset.include_descendants,
                        notes=asset.notes,
                    )
                )
        elif scope.asset_id:
            self.session.add(
                MaintenanceActivityAssetRecord(
                    maintenance_activity_id=activity.id,
                    asset_id=scope.asset_id,
                    role="PRIMARY_TARGET",
                    include_descendants=True,
                )
            )
        return plan

    async def _scope_catalog_rows(
        self,
        *,
        scope_ids: list[UUID],
        subsystem: str | None,
        query: str | None,
    ) -> list[tuple]:
        if not scope_ids:
            return []
        statement = (
            select(
                MaintenanceTemplateScopeRecord,
                MaintenanceTemplateRecord,
                SubsystemRecord,
                AssetRecord,
                EquipmentCategoryRecord,
                GeographicLocationRecord,
            )
            .join(
                MaintenanceTemplateRecord,
                MaintenanceTemplateRecord.id
                == MaintenanceTemplateScopeRecord.maintenance_template_id,
            )
            .join(
                SubsystemRecord,
                SubsystemRecord.id == MaintenanceTemplateRecord.subsystem_id,
            )
            .outerjoin(AssetRecord, AssetRecord.id == MaintenanceTemplateScopeRecord.asset_id)
            .outerjoin(
                EquipmentCategoryRecord,
                EquipmentCategoryRecord.id
                == func.coalesce(
                    MaintenanceTemplateScopeRecord.equipment_category_id,
                    AssetRecord.equipment_category_id,
                ),
            )
            .outerjoin(
                GeographicLocationRecord,
                GeographicLocationRecord.id
                == func.coalesce(
                    MaintenanceTemplateScopeRecord.geographic_location_id,
                    AssetRecord.current_geographic_location_id,
                ),
            )
            .where(MaintenanceTemplateScopeRecord.id.in_(scope_ids))
        )
        if subsystem:
            statement = statement.where(
                or_(
                    func.lower(SubsystemRecord.code) == subsystem.casefold(),
                    func.lower(SubsystemRecord.name) == subsystem.casefold(),
                )
            )
        if query and query.strip():
            pattern = f"%{query.strip()}%"
            statement = statement.where(
                or_(
                    MaintenanceTemplateScopeRecord.display_name.ilike(pattern),
                    MaintenanceTemplateRecord.activity_n1.ilike(pattern),
                    MaintenanceTemplateRecord.activity_n2.ilike(pattern),
                    MaintenanceTemplateRecord.activity_n3_summary.ilike(pattern),
                    AssetRecord.name.ilike(pattern),
                    AssetRecord.category.ilike(pattern),
                    EquipmentCategoryRecord.name_n1.ilike(pattern),
                    EquipmentCategoryRecord.name_n2.ilike(pattern),
                    GeographicLocationRecord.full_path.ilike(pattern),
                    SubsystemRecord.code.ilike(pattern),
                )
            )
        return (await self.session.execute(statement)).all()

    async def _annual_scope_ids(self, annual_plan_id: UUID) -> list[UUID]:
        return list(
            (
                await self.session.execute(
                    select(PCONAnnualPlanScopeRecord.maintenance_template_scope_id)
                    .where(
                        PCONAnnualPlanScopeRecord.annual_plan_id == annual_plan_id,
                        PCONAnnualPlanScopeRecord.is_active.is_(True),
                    )
                    .order_by(PCONAnnualPlanScopeRecord.created_at)
                )
            ).scalars()
        )

    async def _scope_ids_from_imported_entries(
        self,
        year: int,
    ) -> tuple[int | None, list[UUID]]:
        """Return imported PCON scopes for a year, or the closest prior year.

        Legacy imports populate ``maintenance_plan_entries`` but do not have
        rows in ``pcon_annual_plans``. Falling back to the nearest prior year
        also gives a future, still-empty annual plan its complete row skeleton.
        """
        source_year = await self.session.scalar(
            select(MaintenancePlanEntryRecord.year)
            .where(MaintenancePlanEntryRecord.year <= year)
            .order_by(MaintenancePlanEntryRecord.year.desc())
            .limit(1)
        )
        if source_year is None:
            return None, []
        scope_ids = list(
            (
                await self.session.execute(
                    select(MaintenancePlanEntryRecord.maintenance_template_scope_id)
                    .where(MaintenancePlanEntryRecord.year == source_year)
                    .distinct()
                    .order_by(MaintenancePlanEntryRecord.maintenance_template_scope_id)
                )
            ).scalars()
        )
        return source_year, scope_ids

    @staticmethod
    def _unique_scope_ids(*groups: list[UUID]) -> list[UUID]:
        return list(dict.fromkeys(scope_id for group in groups for scope_id in group))

    async def _annual_plan_by_year(self, year: int) -> PCONAnnualPlanRecord | None:
        return (
            await self.session.execute(
                select(PCONAnnualPlanRecord).where(PCONAnnualPlanRecord.year == year)
            )
        ).scalar_one_or_none()

    async def _get_or_create_annual_plan(
        self,
        year: int,
        user_id: str,
        copied_from_year: int | None = None,
    ) -> PCONAnnualPlanRecord:
        existing = await self._annual_plan_by_year(year)
        if existing:
            if existing.status == "CLOSED":
                raise PlanningValidationError("El plan anual está cerrado")
            return existing
        source_plan = (
            await self.session.execute(
                select(PCONAnnualPlanRecord)
                .where(PCONAnnualPlanRecord.year < year)
                .order_by(PCONAnnualPlanRecord.year.desc())
                .limit(1)
            )
        ).scalar_one_or_none()
        plan = PCONAnnualPlanRecord(
            year=year,
            status="ACTIVE" if year == datetime.now(LIMA).year else "DRAFT",
            copied_from_year=(
                copied_from_year
                if copied_from_year is not None
                else source_plan.year
                if source_plan
                else None
            ),
            created_by_user_id=user_id,
        )
        self.session.add(plan)
        await self.session.flush()
        if source_plan:
            for scope_id in await self._annual_scope_ids(source_plan.id):
                self.session.add(
                    PCONAnnualPlanScopeRecord(
                        annual_plan_id=plan.id,
                        maintenance_template_scope_id=scope_id,
                        is_active=True,
                        created_by_user_id=user_id,
                    )
                )
            await self.session.flush()
        return plan

    async def _ensure_annual_membership(
        self,
        annual_plan_id: UUID,
        scope_id: UUID,
        user_id: str,
    ) -> bool:
        membership = (
            await self.session.execute(
                select(PCONAnnualPlanScopeRecord).where(
                    PCONAnnualPlanScopeRecord.annual_plan_id == annual_plan_id,
                    PCONAnnualPlanScopeRecord.maintenance_template_scope_id == scope_id,
                )
            )
        ).scalar_one_or_none()
        if membership:
            membership.is_active = True
            return False
        self.session.add(
            PCONAnnualPlanScopeRecord(
                annual_plan_id=annual_plan_id,
                maintenance_template_scope_id=scope_id,
                is_active=True,
                created_by_user_id=user_id,
            )
        )
        await self.session.flush()
        return True

    async def _ensure_editable_year(self, year: int) -> None:
        annual_plan = await self._annual_plan_by_year(year)
        if annual_plan and annual_plan.status == "CLOSED":
            raise PlanningValidationError("El plan anual está cerrado")
        if annual_plan is None and year < datetime.now(LIMA).year:
            raise PlanningValidationError("No se puede crear un plan para un año cerrado")

    async def _occurrence_rows(
        self,
        *,
        scope_id: UUID,
        year: int,
        month: int,
        lock: bool,
    ) -> list[tuple]:
        statement = (
            select(
                MaintenancePlanEntryRecord,
                PreventiveScheduleRecord,
                MaintenanceActivityRecord,
            )
            .join(
                PreventiveScheduleRecord,
                PreventiveScheduleRecord.maintenance_plan_entry_id
                == MaintenancePlanEntryRecord.id,
            )
            .join(
                MaintenanceActivityRecord,
                MaintenanceActivityRecord.id
                == PreventiveScheduleRecord.maintenance_activity_id,
            )
            .where(
                MaintenancePlanEntryRecord.maintenance_template_scope_id == scope_id,
                MaintenancePlanEntryRecord.year == year,
                MaintenancePlanEntryRecord.month == month,
                MaintenancePlanEntryRecord.planning_status == "PLANNED",
            )
            .order_by(MaintenancePlanEntryRecord.created_at.desc())
        )
        if lock:
            statement = statement.with_for_update()
        return (await self.session.execute(statement)).all()

    async def _occurrence_by_id(self, plan_entry_id: UUID, *, lock: bool) -> tuple | None:
        statement = (
            select(
                MaintenancePlanEntryRecord,
                PreventiveScheduleRecord,
                MaintenanceActivityRecord,
            )
            .join(
                PreventiveScheduleRecord,
                PreventiveScheduleRecord.maintenance_plan_entry_id
                == MaintenancePlanEntryRecord.id,
            )
            .join(
                MaintenanceActivityRecord,
                MaintenanceActivityRecord.id
                == PreventiveScheduleRecord.maintenance_activity_id,
            )
            .where(MaintenancePlanEntryRecord.id == plan_entry_id)
        )
        if lock:
            statement = statement.with_for_update()
        return (await self.session.execute(statement)).one_or_none()

    async def _base_occurrence(self, scope_id: UUID) -> tuple | None:
        return (
            await self.session.execute(
                select(
                    MaintenancePlanEntryRecord,
                    PreventiveScheduleRecord,
                    MaintenanceActivityRecord,
                )
                .join(
                    PreventiveScheduleRecord,
                    PreventiveScheduleRecord.maintenance_plan_entry_id
                    == MaintenancePlanEntryRecord.id,
                )
                .join(
                    MaintenanceActivityRecord,
                    MaintenanceActivityRecord.id
                    == PreventiveScheduleRecord.maintenance_activity_id,
                )
                .where(
                    MaintenancePlanEntryRecord.maintenance_template_scope_id == scope_id
                )
                .order_by(MaintenancePlanEntryRecord.created_at.desc())
                .limit(1)
            )
        ).one_or_none()

    async def _has_schedule_revision(self, activity_id: UUID) -> bool:
        return bool(
            await self.session.scalar(
                select(func.count(MaintenanceScheduleRevisionRecord.id)).where(
                    MaintenanceScheduleRevisionRecord.maintenance_activity_id
                    == activity_id
                )
            )
        )

    async def _has_report(self, activity_id: UUID) -> bool:
        return bool(
            await self.session.scalar(
                select(func.count(MaintenanceReportRecord.id)).where(
                    MaintenanceReportRecord.maintenance_activity_id == activity_id
                )
            )
        )

    async def _counts_by_scope_month(self, year: int) -> dict[tuple[UUID, int], int]:
        rows = (
            await self.session.execute(
                select(
                    MaintenancePlanEntryRecord.maintenance_template_scope_id,
                    MaintenancePlanEntryRecord.month,
                    func.count(MaintenancePlanEntryRecord.id),
                )
                .where(
                    MaintenancePlanEntryRecord.year == year,
                    MaintenancePlanEntryRecord.planning_status == "PLANNED",
                )
                .group_by(
                    MaintenancePlanEntryRecord.maintenance_template_scope_id,
                    MaintenancePlanEntryRecord.month,
                )
            )
        ).all()
        return {(scope_id, month): count for scope_id, month, count in rows}

    def _cancel_plan_entry(
        self,
        *,
        plan: MaintenancePlanEntryRecord,
        schedule: PreventiveScheduleRecord,
        user_id: str,
        reason: str,
    ) -> None:
        plan.planning_status = "CANCELLED"
        plan.cancelled_at = datetime.now(timezone.utc)
        plan.cancelled_by_user_id = user_id
        plan.cancellation_reason = reason
        schedule.status = "CANCELLED"

    def _add_change(
        self,
        *,
        action: str,
        year: int,
        month: int | None,
        scope_id: UUID | None,
        user_id: str,
        quantity_delta: int | None = None,
        plan_entry_id: UUID | None = None,
        reason: str | None = None,
        details: dict | None = None,
    ) -> None:
        self.session.add(
            PCONPlanChangeRecord(
                action=action,
                year=year,
                month=month,
                maintenance_template_scope_id=scope_id,
                maintenance_plan_entry_id=plan_entry_id,
                quantity_delta=quantity_delta,
                reason=reason,
                changed_by_user_id=user_id,
                details=details,
            )
        )

    @staticmethod
    def _maintenance_name(template: MaintenanceTemplateRecord) -> str:
        return (
            template.activity_n3_summary
            or template.activity_n2
            or template.activity_n1
        )

    @staticmethod
    def _category_name(
        category: EquipmentCategoryRecord | None,
        asset: AssetRecord | None,
    ) -> str:
        if category:
            return category.name_n2 or category.name_n1
        return asset.category if asset else "Sin categoría"

    @staticmethod
    def _location_name(
        location: GeographicLocationRecord | None,
        asset: AssetRecord | None,
    ) -> str:
        if location:
            return location.full_path
        return asset.physical_location if asset else "Sin ubicación"

    async def assign_month(
        self,
        *,
        plan_entry_ids: list[UUID],
        year: int,
        month: int,
    ) -> int:
        rows = (
            await self.session.execute(
                select(MaintenancePlanEntryRecord, MaintenanceActivityRecord)
                .join(
                    PreventiveScheduleRecord,
                    PreventiveScheduleRecord.maintenance_plan_entry_id
                    == MaintenancePlanEntryRecord.id,
                )
                .join(
                    MaintenanceActivityRecord,
                    MaintenanceActivityRecord.id
                    == PreventiveScheduleRecord.maintenance_activity_id,
                )
                .where(MaintenancePlanEntryRecord.id.in_(plan_entry_ids))
                .with_for_update()
            )
        ).all()
        if len(rows) != len(set(plan_entry_ids)):
            raise PlanningNotFoundError("Una o más actividades mensuales no existen")
        for plan, activity in rows:
            if activity.status in {"IN_PROGRESS", "COMPLETED", "CLOSED"}:
                raise PlanningValidationError(
                    f"{activity.title} ya inició o fue ejecutada y no puede cambiar de mes"
                )
            if activity.scheduled_start_at:
                raise PlanningValidationError(
                    f"{activity.title} ya tiene fecha confirmada; reprográmala desde la semana"
                )
            plan.year = year
            plan.month = month
        return len(rows)

    async def get_or_create_draft(
        self,
        *,
        week_start: date,
        user_id: str,
        notes: str | None,
    ) -> WeeklyPlanningDetailDTO:
        normalized = self.normalize_week_start(week_start)
        existing = (
            await self.session.execute(
                select(WeeklyPlanningSessionRecord)
                .where(
                    WeeklyPlanningSessionRecord.week_start == normalized,
                    WeeklyPlanningSessionRecord.status == "DRAFT",
                )
                .order_by(WeeklyPlanningSessionRecord.version.desc())
                .limit(1)
            )
        ).scalar_one_or_none()
        if existing is None:
            max_version = (
                await self.session.scalar(
                    select(func.max(WeeklyPlanningSessionRecord.version)).where(
                        WeeklyPlanningSessionRecord.week_start == normalized
                    )
                )
                or 0
            )
            existing = WeeklyPlanningSessionRecord(
                week_start=normalized,
                version=max_version + 1,
                status="DRAFT",
                notes=notes,
                created_by_user_id=user_id,
            )
            self.session.add(existing)
            await self.session.flush()
        elif notes is not None:
            existing.notes = notes
        return await self.get_session_detail(existing.id)

    async def get_session_detail(self, session_id: UUID) -> WeeklyPlanningDetailDTO:
        planning_session = await self.session.get(WeeklyPlanningSessionRecord, session_id)
        if planning_session is None:
            raise PlanningNotFoundError("Sesión semanal no encontrada")
        proposals = await self._proposal_dtos(session_id)
        return WeeklyPlanningDetailDTO(
            session=self._session_dto(planning_session, len(proposals)),
            proposals=proposals,
        )

    async def get_current_week(self, week_start: date) -> WeeklyPlanningDetailDTO:
        normalized = self.normalize_week_start(week_start)
        planning_session = (
            await self.session.execute(
                select(WeeklyPlanningSessionRecord)
                .where(WeeklyPlanningSessionRecord.week_start == normalized)
                .order_by(
                    (WeeklyPlanningSessionRecord.status == "DRAFT").desc(),
                    WeeklyPlanningSessionRecord.version.desc(),
                )
                .limit(1)
            )
        ).scalar_one_or_none()
        if planning_session is None:
            raise PlanningNotFoundError("Aún no existe una sesión para esta semana")
        return await self.get_session_detail(planning_session.id)

    async def upsert_proposal(
        self,
        *,
        session_id: UUID,
        activity_id: UUID,
        payload: ScheduleProposalRequest,
        user_id: str,
    ) -> WeeklyPlanningDetailDTO:
        planning_session = (
            await self.session.execute(
                select(WeeklyPlanningSessionRecord)
                .where(WeeklyPlanningSessionRecord.id == session_id)
                .with_for_update()
            )
        ).scalar_one_or_none()
        if planning_session is None:
            raise PlanningNotFoundError("Sesión semanal no encontrada")
        if planning_session.status != "DRAFT":
            raise PlanningValidationError("La semana confirmada ya no se puede editar")
        self.validate_within_week(
            planning_session.week_start,
            payload.proposed_start_at,
            payload.proposed_end_at,
        )

        activity = (
            await self.session.execute(
                select(MaintenanceActivityRecord)
                .where(MaintenanceActivityRecord.id == activity_id)
                .with_for_update()
            )
        ).scalar_one_or_none()
        if activity is None or activity.activity_type != "PREVENTIVE":
            raise PlanningNotFoundError("Actividad preventiva no encontrada")
        if activity.status != "SCHEDULED":
            raise PlanningValidationError(
                "Solo se pueden programar actividades preventivas en estado programado"
            )
        changed_confirmed_date = (
            activity.scheduled_start_at is not None
            and (
                activity.scheduled_start_at != payload.proposed_start_at
                or activity.scheduled_end_at != payload.proposed_end_at
            )
        )
        if changed_confirmed_date and not (payload.reason or "").strip():
            raise PlanningValidationError("La reprogramación requiere un motivo")

        other_draft = (
            await self.session.execute(
                select(MaintenanceScheduleRevisionRecord)
                .join(
                    WeeklyPlanningSessionRecord,
                    WeeklyPlanningSessionRecord.id
                    == MaintenanceScheduleRevisionRecord.weekly_planning_session_id,
                )
                .where(
                    MaintenanceScheduleRevisionRecord.maintenance_activity_id == activity_id,
                    MaintenanceScheduleRevisionRecord.status == "PROPOSED",
                    WeeklyPlanningSessionRecord.status == "DRAFT",
                    WeeklyPlanningSessionRecord.id != session_id,
                )
            )
        ).scalar_one_or_none()
        if other_draft:
            raise PlanningValidationError(
                "La actividad ya tiene una propuesta pendiente en otra semana"
            )

        revision = (
            await self.session.execute(
                select(MaintenanceScheduleRevisionRecord).where(
                    MaintenanceScheduleRevisionRecord.weekly_planning_session_id == session_id,
                    MaintenanceScheduleRevisionRecord.maintenance_activity_id == activity_id,
                )
            )
        ).scalar_one_or_none()
        if revision is None:
            revision = MaintenanceScheduleRevisionRecord(
                weekly_planning_session_id=session_id,
                maintenance_activity_id=activity_id,
                proposed_start_at=payload.proposed_start_at,
                proposed_end_at=payload.proposed_end_at,
                previous_start_at=activity.scheduled_start_at,
                previous_end_at=activity.scheduled_end_at,
                reason=(payload.reason or "").strip() or None,
                status="PROPOSED",
                created_by_user_id=user_id,
            )
            self.session.add(revision)
        else:
            revision.proposed_start_at = payload.proposed_start_at
            revision.proposed_end_at = payload.proposed_end_at
            revision.reason = (payload.reason or "").strip() or None
            revision.created_by_user_id = user_id
        await self.session.flush()
        return await self.get_session_detail(session_id)

    async def delete_proposal(self, *, session_id: UUID, activity_id: UUID) -> None:
        planning_session = await self.session.get(WeeklyPlanningSessionRecord, session_id)
        if planning_session is None:
            raise PlanningNotFoundError("Sesión semanal no encontrada")
        if planning_session.status != "DRAFT":
            raise PlanningValidationError("La semana confirmada ya no se puede editar")
        revision = (
            await self.session.execute(
                select(MaintenanceScheduleRevisionRecord).where(
                    MaintenanceScheduleRevisionRecord.weekly_planning_session_id == session_id,
                    MaintenanceScheduleRevisionRecord.maintenance_activity_id == activity_id,
                )
            )
        ).scalar_one_or_none()
        if revision is None:
            raise PlanningNotFoundError("Propuesta no encontrada")
        await self.session.delete(revision)

    async def confirm_week(
        self,
        *,
        session_id: UUID,
        user_id: str,
    ) -> WeeklyPlanningDetailDTO:
        planning_session = (
            await self.session.execute(
                select(WeeklyPlanningSessionRecord)
                .where(WeeklyPlanningSessionRecord.id == session_id)
                .with_for_update()
            )
        ).scalar_one_or_none()
        if planning_session is None:
            raise PlanningNotFoundError("Sesión semanal no encontrada")
        if planning_session.status != "DRAFT":
            raise PlanningValidationError("La semana ya fue confirmada")

        revisions = (
            await self.session.execute(
                select(MaintenanceScheduleRevisionRecord)
                .where(
                    MaintenanceScheduleRevisionRecord.weekly_planning_session_id == session_id,
                    MaintenanceScheduleRevisionRecord.status == "PROPOSED",
                )
                .order_by(MaintenanceScheduleRevisionRecord.proposed_start_at)
                .with_for_update()
            )
        ).scalars().all()
        if not revisions:
            raise PlanningValidationError("Agrega al menos una actividad antes de confirmar")

        activity_ids = [revision.maintenance_activity_id for revision in revisions]
        activities = {
            item.id: item
            for item in (
                await self.session.execute(
                    select(MaintenanceActivityRecord)
                    .where(MaintenanceActivityRecord.id.in_(activity_ids))
                    .with_for_update()
                )
            ).scalars()
        }
        for revision in revisions:
            self.validate_within_week(
                planning_session.week_start,
                revision.proposed_start_at,
                revision.proposed_end_at,
            )
            activity = activities.get(revision.maintenance_activity_id)
            if activity is None or activity.activity_type != "PREVENTIVE":
                raise PlanningValidationError("La semana contiene una actividad no preventiva")
            if activity.status != "SCHEDULED":
                raise PlanningValidationError(
                    f"{activity.title} cambió de estado y ya no se puede programar"
                )
            changed_confirmed_date = (
                activity.scheduled_start_at is not None
                and (
                    activity.scheduled_start_at != revision.proposed_start_at
                    or activity.scheduled_end_at != revision.proposed_end_at
                )
            )
            if changed_confirmed_date and not (revision.reason or "").strip():
                raise PlanningValidationError(
                    f"La reprogramación de {activity.title} requiere un motivo"
                )

        # Proposed hours are an availability window agreed in the weekly
        # meeting, not a reservation of a technician or equipment. Several
        # activities may therefore share the same range.
        confirmed_at = datetime.now(timezone.utc)
        for revision in revisions:
            activity = activities[revision.maintenance_activity_id]
            previous_confirmed = (
                await self.session.execute(
                    select(MaintenanceScheduleRevisionRecord).where(
                        MaintenanceScheduleRevisionRecord.maintenance_activity_id == activity.id,
                        MaintenanceScheduleRevisionRecord.status == "CONFIRMED",
                    )
                )
            ).scalars().all()
            for previous in previous_confirmed:
                previous.status = "SUPERSEDED"
            activity.scheduled_start_at = revision.proposed_start_at
            activity.scheduled_end_at = revision.proposed_end_at
            revision.status = "CONFIRMED"
            revision.confirmed_by_user_id = user_id
            revision.confirmed_at = confirmed_at
            legacy_schedule = (
                await self.session.execute(
                    select(PreventiveScheduleRecord).where(
                        PreventiveScheduleRecord.maintenance_activity_id == activity.id
                    )
                )
            ).scalar_one_or_none()
            if legacy_schedule:
                legacy_schedule.assigned_date = revision.proposed_start_at
                legacy_schedule.scheduled_at = revision.proposed_start_at.isoformat()

        planning_session.status = "CONFIRMED"
        planning_session.confirmed_by_user_id = user_id
        planning_session.confirmed_at = confirmed_at
        await self.session.flush()
        return await self.get_session_detail(session_id)

    async def list_history(self, limit: int) -> list[PlanningHistoryItemDTO]:
        rows = (
            await self.session.execute(
                select(
                    MaintenanceScheduleRevisionRecord,
                    WeeklyPlanningSessionRecord,
                    MaintenanceActivityRecord,
                    UserRecord,
                )
                .join(
                    WeeklyPlanningSessionRecord,
                    WeeklyPlanningSessionRecord.id
                    == MaintenanceScheduleRevisionRecord.weekly_planning_session_id,
                )
                .join(
                    MaintenanceActivityRecord,
                    MaintenanceActivityRecord.id
                    == MaintenanceScheduleRevisionRecord.maintenance_activity_id,
                )
                .outerjoin(
                    UserRecord,
                    UserRecord.id == MaintenanceScheduleRevisionRecord.confirmed_by_user_id,
                )
                .where(
                    MaintenanceScheduleRevisionRecord.status.in_(
                        ["CONFIRMED", "SUPERSEDED"]
                    )
                )
                .order_by(MaintenanceScheduleRevisionRecord.confirmed_at.desc())
                .limit(limit)
            )
        ).all()
        equipment = await self._equipment_names([row[0].maintenance_activity_id for row in rows])
        return [
            PlanningHistoryItemDTO(
                revision_id=revision.id,
                session_id=planning_session.id,
                week_start=planning_session.week_start,
                session_version=planning_session.version,
                activity_id=activity.id,
                activity_title=activity.title,
                equipment_name=equipment.get(activity.id, "Equipo no identificado"),
                proposed_start_at=revision.proposed_start_at,
                proposed_end_at=revision.proposed_end_at,
                previous_start_at=revision.previous_start_at,
                previous_end_at=revision.previous_end_at,
                reason=revision.reason,
                status=revision.status,
                confirmed_at=revision.confirmed_at,
                confirmed_by_name=user.name if user else None,
            )
            for revision, planning_session, activity, user in rows
        ]

    async def _proposal_dtos(self, session_id: UUID) -> list[ScheduleProposalDTO]:
        rows = (
            await self.session.execute(
                select(MaintenanceScheduleRevisionRecord, MaintenanceActivityRecord)
                .join(
                    MaintenanceActivityRecord,
                    MaintenanceActivityRecord.id
                    == MaintenanceScheduleRevisionRecord.maintenance_activity_id,
                )
                .where(
                    MaintenanceScheduleRevisionRecord.weekly_planning_session_id == session_id
                )
                .order_by(MaintenanceScheduleRevisionRecord.proposed_start_at)
            )
        ).all()
        equipment = await self._equipment_names([row[1].id for row in rows])
        return [
            ScheduleProposalDTO(
                id=revision.id,
                session_id=session_id,
                activity_id=activity.id,
                activity_title=activity.title,
                equipment_name=equipment.get(activity.id, "Equipo no identificado"),
                proposed_start_at=revision.proposed_start_at,
                proposed_end_at=revision.proposed_end_at,
                previous_start_at=revision.previous_start_at,
                previous_end_at=revision.previous_end_at,
                reason=revision.reason,
                status=revision.status,
            )
            for revision, activity in rows
        ]

    async def _equipment_names(self, activity_ids: list[UUID]) -> dict[UUID, str]:
        if not activity_ids:
            return {}
        rows = (
            await self.session.execute(
                select(
                    MaintenanceActivityAssetRecord.maintenance_activity_id,
                    AssetRecord.name,
                )
                .join(AssetRecord, AssetRecord.id == MaintenanceActivityAssetRecord.asset_id)
                .where(
                    MaintenanceActivityAssetRecord.maintenance_activity_id.in_(activity_ids),
                    MaintenanceActivityAssetRecord.role.in_(
                        ["PRIMARY", "PRIMARY_TARGET"]
                    ),
                )
            )
        ).all()
        return {activity_id: name for activity_id, name in rows}

    async def _draft_revisions_by_activity(
        self,
        activity_ids: list[UUID],
    ) -> dict[UUID, MaintenanceScheduleRevisionRecord]:
        if not activity_ids:
            return {}
        rows = (
            await self.session.execute(
                select(MaintenanceScheduleRevisionRecord)
                .join(
                    WeeklyPlanningSessionRecord,
                    WeeklyPlanningSessionRecord.id
                    == MaintenanceScheduleRevisionRecord.weekly_planning_session_id,
                )
                .where(
                    MaintenanceScheduleRevisionRecord.maintenance_activity_id.in_(activity_ids),
                    MaintenanceScheduleRevisionRecord.status == "PROPOSED",
                    WeeklyPlanningSessionRecord.status == "DRAFT",
                )
                .order_by(MaintenanceScheduleRevisionRecord.updated_at.desc())
            )
        ).scalars()
        result: dict[UUID, MaintenanceScheduleRevisionRecord] = {}
        for row in rows:
            result.setdefault(row.maintenance_activity_id, row)
        return result

    async def _remove_draft_schedule_revisions(self, activity_id: UUID) -> None:
        """Discard unconfirmed scheduling proposals for one annual occurrence."""
        revisions = (
            await self.session.execute(
                select(MaintenanceScheduleRevisionRecord)
                .join(
                    WeeklyPlanningSessionRecord,
                    WeeklyPlanningSessionRecord.id
                    == MaintenanceScheduleRevisionRecord.weekly_planning_session_id,
                )
                .where(
                    MaintenanceScheduleRevisionRecord.maintenance_activity_id == activity_id,
                    MaintenanceScheduleRevisionRecord.status == "PROPOSED",
                    WeeklyPlanningSessionRecord.status == "DRAFT",
                )
            )
        ).scalars().all()
        for revision in revisions:
            await self.session.delete(revision)

    @staticmethod
    def normalize_week_start(value: date) -> date:
        return value - timedelta(days=value.weekday())

    @staticmethod
    def validate_within_week(
        week_start: date,
        start_at: datetime,
        end_at: datetime,
    ) -> None:
        normalized = PostgresPlanningRepository.normalize_week_start(week_start)
        if end_at <= start_at:
            raise PlanningValidationError(
                "La hora fin debe ser posterior a la hora de inicio"
            )
        start_date = start_at.astimezone(LIMA).date()
        end_date = end_at.astimezone(LIMA).date()
        if not (
            normalized <= start_date < normalized + timedelta(days=7)
            and normalized <= end_date < normalized + timedelta(days=7)
        ):
            raise PlanningValidationError(
                "Toda propuesta debe quedar dentro de la semana seleccionada"
            )

    @staticmethod
    def _session_dto(
        item: WeeklyPlanningSessionRecord,
        proposal_count: int,
    ) -> WeeklyPlanningSessionDTO:
        return WeeklyPlanningSessionDTO(
            id=item.id,
            week_start=item.week_start,
            version=item.version,
            status=item.status,
            notes=item.notes,
            created_by_user_id=item.created_by_user_id,
            confirmed_by_user_id=item.confirmed_by_user_id,
            confirmed_at=item.confirmed_at,
            proposal_count=proposal_count,
        )
