import os

os.environ["REPOSITORY_BACKEND"] = "seed"

from fastapi.testclient import TestClient

from app.main import create_app


client = TestClient(create_app())


def test_healthcheck() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_login_accepts_seed_user_password() -> None:
    response = client.post(
        "/api/v1/auth/login",
        json={"email": "diego@maintenance.local", "password": "123456"},
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["token_type"] == "bearer"
    assert payload["user"]["role"] == "TECHNICIAN"


def test_login_rejects_invalid_password() -> None:
    response = client.post(
        "/api/v1/auth/login",
        json={"email": "diego@maintenance.local", "password": "wrong"},
    )
    assert response.status_code == 401


def test_assets_are_filtered_to_business_anchors_by_default() -> None:
    response = client.get("/api/v1/assets")
    assert response.status_code == 200
    payload = response.json()
    assert payload["total"] >= 1
    assert all(item["is_business_anchor"] for item in payload["items"])


def test_asset_history_is_specific_to_equipment() -> None:
    response = client.get("/api/v1/assets/asset-crk-1/history")
    assert response.status_code == 200
    history = response.json()
    assert len(history) == 1
    assert history[0]["title"] == "Inspeccion de CRK 1"


def test_corrective_event_creation_returns_scheduled_event() -> None:
    response = client.post(
        "/api/v1/corrective-events",
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
