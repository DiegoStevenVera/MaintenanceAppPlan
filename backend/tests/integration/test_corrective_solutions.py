"""Run only on disposable PostgreSQL; source documents remain authoritative."""

import asyncio
import os
from datetime import UTC, datetime
from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select, text

pytestmark = pytest.mark.skipif(os.getenv("TEST_SOLUTIONS_DB") != "1", reason="Requires disposable PostgreSQL")


def test_solution_history_sources_filters_permissions_and_refresh():
    asyncio.run(workflow())


async def workflow():
    import app.models  # noqa: F401
    from app.database import async_session_factory, engine
    from app.main import create_app
    from modules.asset_management.infrastructure.postgres.models import AssetRecord
    from modules.identity_access.application.security import create_access_token
    from modules.identity_access.infrastructure.postgres.models import RoleModulePermissionRecord, UserRecord
    from modules.identity_access.interfaces.schemas import UserDTO
    from modules.maintenance_execution.infrastructure.postgres.models import CorrectiveEventRecord
    from modules.maintenance_execution.infrastructure.postgres.report_models import (
        CorrectiveEventCommentRecord, CorrectiveReportDetailRecord, MaintenanceActivityRecord,
        MaintenanceReportRecord, ReportVersionRecord,
    )
    from modules.organizational_context.infrastructure.postgres.models import ProjectRecord, SiteRecord, SubsystemRecord, SystemRecord
    from shared_kernel.schemas import UserRole

    suffix = uuid4().hex
    user = UserDTO(id=suffix, name="Ingeniero", email=f"{suffix}@test.local",
                   role=UserRole.MAINTENANCE_ENGINEER, role_label="Ingeniero")
    try:
        async with async_session_factory() as session:
            await session.merge(RoleModulePermissionRecord(role=user.role.value, module="CORRECTIVE", permission_level="READ"))
            session.add(UserRecord(id=user.id, name=user.name, email=user.email, role=user.role.value,
                role_label=user.role_label, password_hash="disabled"))
            site = SiteRecord(id=uuid4(), name=suffix)
            session.add(site)
            await session.flush()
            project = ProjectRecord(id=uuid4(), name=suffix, site_id=site.id)
            session.add(project)
            await session.flush()
            system = SystemRecord(id=uuid4(), name=suffix, project_id=project.id)
            session.add(system)
            await session.flush()
            sub = SubsystemRecord(id=uuid4(), name=suffix, code=suffix, system_id=system.id)
            session.add(sub)
            a, b = uuid4().hex, uuid4().hex
            for identifier in (a, b):
                session.add(AssetRecord(id=identifier, name="Equipo", category="Equipo", asset_type="Servidor",
                    subsystem=suffix, serial_or_code=identifier, status="Operativo", physical_location="Patio",
                    is_business_anchor=True, children=[]))
            await session.flush()
            events = []
            for i in range(35):
                activity = MaintenanceActivityRecord(id=uuid4(), activity_type="CORRECTIVE", status="COMPLETED",
                    project_id=project.id, subsystem_id=sub.id, title=f"Caso {i}", internal_code=f"{suffix}-{i}")
                session.add(activity)
                await session.flush()
                event = CorrectiveEventRecord(id=uuid4().hex, code=f"C-{i}", sap_code=f"SAP-{i}", name=f"Caso {i}",
                    affected_asset_id=a if i < 2 else b, primary_asset_id=a if i < 2 else b,
                    affected_asset_path="Patio / Equipo", subsystem=suffix, severity="MEDIUM", status="COMPLETED",
                    notice_created_at=f"2026-11-{min(i + 1, 28):02d}", response_at="2026-11-01",
                    physical_location="Patio", timeline=[], maintenance_activity_id=activity.id,
                    failure_description="Intermitencia de comunicación" if i < 2 else "Batería descargada")
                session.add(event)
                events.append(event)
            await session.flush()
            version_ids = []
            for index, event in enumerate(events[:2]):
                for report_number in range(1, 3):
                    report = MaintenanceReportRecord(id=uuid4(), maintenance_activity_id=event.maintenance_activity_id,
                        report_kind="CORRECTIVE", report_number=report_number, status="FINALIZED",
                        created_by_user_id=user.id, shift_label=f"Turno {report_number}")
                    session.add(report)
                    await session.flush()
                    for number in range(1, 3):
                        draft = index == 0 and report_number == 2 and number == 2
                        data = {"symptom": "BORRADORUNICOTEXTO" if draft else "Intermitencia de comunicación",
                            "activities": [{"name": "Revisar", "description": "INTENTOOBSOLETO" if number == 1 and report_number == 1
                                else "Revisar conectores y reiniciar interfaz"}],
                            "functional_tests": "Prueba de enlace de 30 minutos", "validation_result": "Conforme",
                            "technical_status": "Operativo" if index == 1 else "Inoperativo",
                            "service_released": True, "conclusion": "Intervención documentada"}
                        version = ReportVersionRecord(id=uuid4(), maintenance_report_id=report.id, version_number=number,
                            document_status="DRAFT" if draft else "FINALIZED", created_by_user_id=user.id,
                            finalized_at=None if draft else datetime.now(UTC), data_snapshot=data)
                        session.add(version)
                        await session.flush()
                        session.add(CorrectiveReportDetailRecord(report_version_id=version.id, corrective_event_id=event.id))
                        version_ids.append(version.id)
            session.add(CorrectiveEventCommentRecord(id=uuid4(), corrective_event_id=events[0].id,
                author_user_id=user.id, message="COMENTARIOPROVISIONALUNICO"))
            await session.commit()
            event_id, activity_id = events[0].id, str(events[0].maintenance_activity_id)
            second_id = events[1].id
        app = create_app()
        token, _ = create_access_token(user)
        headers = {"Authorization": f"Bearer {token}"}
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test", headers=headers) as client:
            result = await client.get("/api/v1/corrective-solutions/search", params={"subsystem": suffix, "q": "pierde enlace por ratos"})
            assert result.status_code == 200, result.text
            payload = result.json()
            assert payload["total"] == 2 and payload["engine"] == "textual_contextual"
            core = next(c for c in payload["items"] if c["id"] == event_id)
            assert len(core["sources"]) == 4 and core["outcome"] != "VALIDATED"
            assert next(c for c in payload["items"] if c["id"] == second_id)["outcome"] == "VALIDATED"
            assert len([s for s in core["sources"] if s["principal"]]) == 2
            assert core["has_provisional"]
            for params, count in [
                ({"q": "INTENTOOBSOLETO"}, 0),
                ({"q": "BORRADORUNICOTEXTO"}, 1),
                ({"q": "BORRADORUNICOTEXTO", "include_provisional": "false"}, 0),
                ({"q": "COMENTARIOPROVISIONALUNICO", "include_provisional": "false"}, 0),
                ({"asset_id": a}, 2), ({"asset_id": "inexistente"}, 0),
                ({"q": "bateria", "asset_id": a}, 0),
            ]:
                result = await client.get("/api/v1/corrective-solutions/search", params={"subsystem": suffix, **params})
                assert result.json()["total"] == count, (params, result.text)
            page = (await client.get("/api/v1/corrective-solutions/search", params={
                "subsystem": suffix, "limit": 5, "offset": 25,
            })).json()
            assert page["total"] == 35 and len(page["items"]) == 5
            similar = (await client.get("/api/v1/corrective-solutions/search", params={"similar_to": activity_id})).json()
            assert all(c["id"] != event_id for c in similar["items"])
            assert second_id in {c["id"] for c in similar["items"]}
            assert (await client.get("/api/v1/corrective-solutions/search", params={"similar_to": "missing"})).status_code == 404
            assert (await client.get("/api/v1/corrective-solutions/bundle")).status_code == 422
            bundle = (await client.get("/api/v1/corrective-solutions/bundle", params={"asset_id": a})).json()
            assert bundle["total"] == 2
            assert (await client.get("/api/v1/corrective-solutions/bundle", params={
                "asset_id": a, "revision": "outdated",
            })).status_code == 409
            async with async_session_factory() as session:
                activity = await session.get(MaintenanceActivityRecord, events[1].maintenance_activity_id)
                activity.status = "IN_PROGRESS"
                await session.commit()
            refreshed = (await client.get(f"/api/v1/corrective-solutions/cases/{second_id}")).json()
            assert refreshed["outcome"] == "PENDING"
            async with async_session_factory() as session:
                permission = await session.get(RoleModulePermissionRecord, (user.role.value, "CORRECTIVE"))
                if permission is None:
                    session.add(RoleModulePermissionRecord(role=user.role.value, module="CORRECTIVE", permission_level="NONE"))
                else:
                    permission.permission_level = "NONE"
                await session.commit()
            for path in ("search", f"cases/{event_id}", "bundle?asset_id=" + a, f"evidence/{uuid4()}"):
                assert (await client.get("/api/v1/corrective-solutions/" + path)).status_code == 403
            assert (await client.get("/api/v1/corrective-solutions/search", headers={"Authorization": ""})).status_code == 401
        async with async_session_factory() as session:
            assert await session.scalar(select(ReportVersionRecord.id).where(ReportVersionRecord.id == version_ids[0])) is not None
            assert (await session.execute(text("SELECT count(*) FROM corrective_solution_cases"))).scalar() >= 35
    finally:
        await engine.dispose()
