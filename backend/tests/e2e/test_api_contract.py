import os

os.environ["REPOSITORY_BACKEND"] = "seed"

from fastapi.testclient import TestClient

from app.main import create_app


client = TestClient(create_app())


def login(email: str = "diego@maintenance.local", password: str = "123456") -> dict:
    response = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": password},
    )
    assert response.status_code == 200
    return response.json()


def authorization_headers(email: str = "diego@maintenance.local") -> dict[str, str]:
    token = login(email=email)["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_healthcheck() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_pcon_requires_authentication() -> None:
    response = client.get("/api/v1/pcon/plan", params={"year": 2026, "month": 7})
    assert response.status_code == 401


def test_pcon_seed_backend_reports_that_postgres_is_required() -> None:
    response = client.get(
        "/api/v1/pcon/plan",
        params={"year": 2026, "month": 7},
        headers=authorization_headers(),
    )
    assert response.status_code == 503


def test_only_coordinator_or_administrator_can_edit_pcon() -> None:
    engineer = client.put(
        "/api/v1/pcon/plan/month",
        json={
            "plan_entry_ids": ["00000000-0000-0000-0000-000000000001"],
            "year": 2026,
            "month": 8,
        },
        headers=authorization_headers(),
    )
    assert engineer.status_code == 403

    coordinator = client.put(
        "/api/v1/pcon/plan/month",
        json={
            "plan_entry_ids": ["00000000-0000-0000-0000-000000000001"],
            "year": 2026,
            "month": 8,
        },
        headers=authorization_headers(email="fredy@maintenance.local"),
    )
    assert coordinator.status_code == 503


def test_login_accepts_seed_user_password() -> None:
    payload = login()
    assert payload["token_type"] == "bearer"
    assert payload["expires_in"] > 0
    assert payload["access_token"].count(".") == 2
    assert payload["refresh_token"].count(".") == 2
    assert payload["user"]["role"] == "MAINTENANCE_ENGINEER"


def test_login_rejects_invalid_password() -> None:
    response = client.post(
        "/api/v1/auth/login",
        json={"email": "diego@maintenance.local", "password": "wrong"},
    )
    assert response.status_code == 401


def test_me_requires_and_resolves_access_token() -> None:
    unauthorized = client.get("/api/v1/auth/me")
    assert unauthorized.status_code == 401

    response = client.get("/api/v1/auth/me", headers=authorization_headers())
    assert response.status_code == 200
    assert response.json()["email"] == "diego@maintenance.local"


def test_refresh_rotates_token_and_logout_revokes_session() -> None:
    original = login()
    refreshed_response = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": original["refresh_token"]},
    )
    assert refreshed_response.status_code == 200
    refreshed = refreshed_response.json()
    assert refreshed["refresh_token"] != original["refresh_token"]

    replay = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": original["refresh_token"]},
    )
    assert replay.status_code == 401

    logout = client.post(
        "/api/v1/auth/logout",
        json={"refresh_token": refreshed["refresh_token"]},
    )
    assert logout.status_code == 204

    after_logout = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": refreshed["refresh_token"]},
    )
    assert after_logout.status_code == 401


def test_only_administrator_can_open_a_real_role_preview_session() -> None:
    forbidden = client.post(
        "/api/v1/auth/impersonate-role",
        headers=authorization_headers(),
        json={"role": "COORDINATOR"},
    )
    assert forbidden.status_code == 403

    administrator = login(email="admin@maintenance.local")
    response = client.post(
        "/api/v1/auth/impersonate-role",
        headers={"Authorization": f"Bearer {administrator['access_token']}"},
        json={"role": "COORDINATOR"},
    )
    assert response.status_code == 200
    preview = response.json()
    assert preview["user"]["role"] == "COORDINATOR"

    current_user = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {preview['access_token']}"},
    )
    assert current_user.status_code == 200
    assert current_user.json()["role"] == "COORDINATOR"


def test_administrator_sees_only_roles_with_active_users() -> None:
    administrator = login(email="admin@maintenance.local")
    response = client.get(
        "/api/v1/auth/impersonation-roles",
        headers={"Authorization": f"Bearer {administrator['access_token']}"},
    )
    assert response.status_code == 200
    roles = {item["role"] for item in response.json()}
    assert roles == {"MAINTENANCE_ENGINEER", "COORDINATOR", "BOSS"}


def test_assets_are_filtered_to_business_anchors_by_default() -> None:
    response = client.get("/api/v1/assets", headers=authorization_headers())
    assert response.status_code == 200
    payload = response.json()
    assert payload["total"] >= 1
    assert all(item["is_business_anchor"] for item in payload["items"])


def test_assets_support_search_and_subsystem_filters() -> None:
    response = client.get(
        "/api/v1/assets",
        headers=authorization_headers(),
        params={"q": "frontam", "subsystem": "CBTC"},
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["total"] == 1
    assert payload["items"][0]["id"] == "asset-frontam-colectora"


def test_stock_contract_requires_authentication() -> None:
    unauthorized = client.get("/api/v1/assets/stock")
    assert unauthorized.status_code == 401

    response = client.get(
        "/api/v1/assets/stock",
        headers=authorization_headers(),
    )
    assert response.status_code == 200
    assert response.json() == {
        "items": [],
        "total": 0,
        "limit": 100,
        "offset": 0,
    }


def test_asset_tree_returns_components_without_physical_locations() -> None:
    response = client.get(
        "/api/v1/assets/asset-frontam-colectora/tree",
        headers=authorization_headers(),
    )
    assert response.status_code == 200
    tree = response.json()
    assert len(tree) == 3
    assert all(item["category"] == "Componente" for item in tree)
    assert all("Ubicacion fisica" not in item["name"] for item in tree)


def test_asset_history_is_specific_to_equipment() -> None:
    response = client.get(
        "/api/v1/assets/asset-crk-1/history",
        headers=authorization_headers(),
    )
    assert response.status_code == 200
    history = response.json()
    assert len(history) == 1
    assert history[0]["title"] == "Inspeccion de CRK 1"


def test_normalized_maintenance_read_contract_requires_authentication() -> None:
    unauthorized = client.get("/api/v1/maintenance-activities")
    assert unauthorized.status_code == 401

    response = client.get(
        "/api/v1/maintenance-activities",
        headers=authorization_headers(),
        params={
            "activity_type": "PREVENTIVE",
            "date_from": "2026-01-01T00:00:00Z",
            "date_to": "2027-01-01T00:00:00Z",
            "q": "ATS",
        },
    )
    assert response.status_code == 200
    payload = response.json()
    assert {"items", "total", "limit", "offset"}.issubset(payload)


def test_normalized_maintenance_detail_uses_uuid_resource_ids() -> None:
    response = client.get(
        "/api/v1/maintenance-activities/not-in-seed",
        headers=authorization_headers(),
    )
    assert response.status_code == 404


def test_maintenance_dashboard_requires_authentication() -> None:
    unauthorized = client.get(
        "/api/v1/maintenance-dashboard",
        params={
            "day_from": "2026-07-27T00:00:00-05:00",
            "day_to": "2026-07-28T00:00:00-05:00",
        },
    )
    assert unauthorized.status_code == 401

    response = client.get(
        "/api/v1/maintenance-dashboard",
        headers=authorization_headers(),
        params={
            "day_from": "2026-07-27T00:00:00-05:00",
            "day_to": "2026-07-28T00:00:00-05:00",
        },
    )
    assert response.status_code == 200
    assert {
        "preventive_today_count",
        "active_corrective_count",
        "pending_closure_count",
        "preventive_today",
        "active_correctives",
        "pending_closure",
    }.issubset(response.json())


def test_lifecycle_commands_enforce_role_and_request_contracts() -> None:
    unauthenticated = client.post(
        "/api/v1/maintenance-activities/not-in-seed/start"
    )
    assert unauthenticated.status_code == 401

    boss_start = client.post(
        "/api/v1/maintenance-activities/not-in-seed/start",
        headers=authorization_headers("jefe@maintenance.local"),
    )
    assert boss_start.status_code == 403

    engineer_close = client.post(
        "/api/v1/maintenance-activities/not-in-seed/close",
        headers=authorization_headers(),
    )
    assert engineer_close.status_code == 403

    missing_reason = client.post(
        "/api/v1/maintenance-activities/not-in-seed/reopen",
        headers=authorization_headers(),
        json={"reason": "  "},
    )
    assert missing_reason.status_code == 422

    missing_activity = client.post(
        "/api/v1/maintenance-activities/not-in-seed/start",
        headers=authorization_headers(),
    )
    assert missing_activity.status_code == 404


def test_report_write_endpoints_require_authentication_and_operational_role() -> None:
    payload = {"preventive": {"participants": [], "steps": []}}
    unauthenticated = client.put(
        "/api/v1/maintenance-activities/not-in-seed/report-draft",
        json=payload,
    )
    assert unauthenticated.status_code == 401

    boss = client.put(
        "/api/v1/maintenance-activities/not-in-seed/report-draft",
        headers=authorization_headers("jefe@maintenance.local"),
        json=payload,
    )
    assert boss.status_code == 403

    missing_activity = client.put(
        "/api/v1/maintenance-activities/not-in-seed/report-draft",
        headers=authorization_headers(),
        json=payload,
    )
    assert missing_activity.status_code == 404


def test_comment_and_attachment_endpoints_require_authentication() -> None:
    assert (
        client.post(
            "/api/v1/maintenance-activities/not-in-seed/comments",
            json={"message": "Comentario"},
        ).status_code
        == 401
    )
    assert client.get("/api/v1/attachments/missing/content").status_code == 401


def test_corrective_event_creation_returns_scheduled_event() -> None:
    response = client.post(
        "/api/v1/corrective-events",
        headers=authorization_headers(),
        json={
            "sap_event_name": "Falla de comunicacion Frontam",
            "sap_notification": "110099999",
            "affected_asset_path": (
                "CUBICULO EQUIPADO DEL FRONTAM - COLECTORA > "
                "Gabinete / conjunto principal > Modulo interno > Tarjeta de comunicacion"
            ),
            "subsystem": "CBTC",
            "severity": "HIGH",
            "notice_created_at": "2026-06-21T12:00:00-05:00",
            "response_at": "2026-06-21T12:08:00-05:00",
            "physical_location": "Estacion Colectora Industrial -> Sala tecnica -> Sala 2.21",
        },
    )
    assert response.status_code == 201
    assert response.json()["status"] == "SCHEDULED"


def test_boss_cannot_create_corrective_event() -> None:
    response = client.post(
        "/api/v1/corrective-events",
        headers=authorization_headers("jefe@maintenance.local"),
        json={
            "sap_event_name": "Evento solo lectura",
            "sap_notification": "110000000",
            "affected_asset_path": "ZC4",
            "subsystem": "CBTC",
            "severity": "LOW",
            "notice_created_at": "2026-06-21T12:00:00-05:00",
            "response_at": "2026-06-21T12:08:00-05:00",
            "physical_location": "Patio Santa Anita",
        },
    )
    assert response.status_code == 403
