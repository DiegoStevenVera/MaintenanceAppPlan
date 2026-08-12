import pytest
import asyncio
import base64
import re
from unittest.mock import AsyncMock

from modules.maintenance_execution.infrastructure.pdf_service import (
    PreventivePDFService,
)
from modules.maintenance_execution.infrastructure.postgres.repository import (
    PostgresMaintenanceRepository,
)
from modules.maintenance_execution.infrastructure.postgres.report_writer import (
    PostgresReportWriter,
    ReportNotEditableError,
    ReportValidationError,
)
from modules.maintenance_execution.interfaces.schemas import (
    CalibrationReceiverWriteDTO,
    CalibrationReportWriteDTO,
    CorrectiveReportWriteDTO,
    PreventiveReportWriteDTO,
    ReportParticipantWriteDTO,
    ReportDraftWriteRequest,
)


def test_final_preventive_requires_signature() -> None:
    payload = PreventiveReportWriteDTO(
        final_result="Equipo operativo",
        steps=[],
        participants=[ReportParticipantWriteDTO(user_id="engineer")],
    )
    with pytest.raises(ReportValidationError, match="firma"):
        PostgresReportWriter._validate_final(payload)


def test_final_preventive_requires_steps_and_result() -> None:
    participant = ReportParticipantWriteDTO(
        user_id="engineer",
        signature_strokes=[[{"x": 1, "y": 2}]],
    )
    with pytest.raises(ReportValidationError, match="estado final"):
        PostgresReportWriter._validate_final(
            PreventiveReportWriteDTO(participants=[participant])
        )
    with pytest.raises(ReportValidationError, match="pasos"):
        PostgresReportWriter._validate_final(
            PreventiveReportWriteDTO(
                final_result="Equipo operativo",
                participants=[participant],
            )
        )


def test_final_corrective_requires_activity() -> None:
    payload = CorrectiveReportWriteDTO(
        symptom="Sin comunicación",
        technical_status="Operativo",
        participants=[
            ReportParticipantWriteDTO(
                user_id="engineer",
                signature_strokes=[[{"x": 1, "y": 2}]],
            )
        ],
    )
    with pytest.raises(ReportValidationError, match="actividad"):
        PostgresReportWriter._validate_final(payload)


def test_calibration_requires_complete_transmitter_and_receiver_values() -> None:
    with pytest.raises(ReportValidationError, match="frecuencia"):
        PostgresReportWriter._validate_calibration(
            CalibrationReportWriteDTO(
                transmitter_jumpers="J1-J2",
                receivers=[
                    CalibrationReceiverWriteDTO(
                        sequence=1,
                        jumpers="J3-J4",
                        tca9="8.2",
                        rail_current="1.4",
                    )
                ],
            )
        )

    with pytest.raises(ReportValidationError, match="receptor 2"):
        PostgresReportWriter._validate_calibration(
            CalibrationReportWriteDTO(
                frequency="1700",
                transmitter_jumpers="J1-J2",
                receivers=[
                    CalibrationReceiverWriteDTO(
                        sequence=2,
                        jumpers="J3-J4",
                        tca9="",
                        rail_current="1.4",
                    )
                ],
            )
        )


def test_calibration_accepts_multiple_complete_receivers() -> None:
    PostgresReportWriter._validate_calibration(
        CalibrationReportWriteDTO(
            frequency="1700",
            transmitter_jumpers="J1-J2",
            receivers=[
                CalibrationReceiverWriteDTO(
                    sequence=1,
                    jumpers="J3-J4",
                    tca9="8.2",
                    rail_current="1.4",
                ),
                CalibrationReceiverWriteDTO(
                    sequence=2,
                    jumpers="J5-J6",
                    tca9="8.4",
                    rail_current="1.6",
                ),
            ],
        )
    )


def test_offline_draft_detects_a_newer_server_version() -> None:
    current = type("Version", (), {"id": "server-version-2"})()
    payload = ReportDraftWriteRequest(
        base_report_version_id="server-version-1",
        enforce_base_version=True,
    )

    with pytest.raises(ReportNotEditableError, match="cambió en el servidor"):
        PostgresReportWriter._validate_base_version(payload, current)


def test_legacy_clients_can_save_without_version_enforcement() -> None:
    current = type("Version", (), {"id": "server-version-2"})()
    PostgresReportWriter._validate_base_version(
        ReportDraftWriteRequest(),
        current,
    )


def test_legacy_event_datetime_is_parsed() -> None:
    parsed = PostgresReportWriter._parse_datetime("2026-07-27T10:30:00-05:00")
    assert parsed is not None
    assert parsed.isoformat() == "2026-07-27T10:30:00-05:00"


def test_component_replacement_detail_uses_saved_asset_snapshots() -> None:
    repository = PostgresMaintenanceRepository(None)
    repository._asset_snapshot = AsyncMock(
        side_effect=lambda _asset_id, snapshot: snapshot or {}
    )
    replacement = asyncio.run(
        repository._replacement_dto(
            {
                "parent_asset_id": "rack",
                "removed_asset_id": "removed",
                "installed_asset_id": "installed",
                "source_description": "Almacén SPV",
                "destination_description": "Almacén de mantenimiento",
                "reason": "Falla de comunicación",
                "parent_asset_snapshot": {"name": "Rack principal"},
                "removed_asset_snapshot": {
                    "name": "Tarjeta retirada",
                    "path": "ZC4 > PCSG 1 > Tarjeta retirada",
                    "part_number": "PN-OLD",
                    "serial_number": "SN-OLD",
                    "model": "CALS",
                    "manufacturer": "Hitachi",
                },
                "installed_asset_snapshot": {
                    "name": "Tarjeta instalada",
                    "path": "Almacén SPV",
                    "part_number": "PN-NEW",
                    "serial_number": "SN-NEW",
                    "model": "CALS",
                    "manufacturer": "Hitachi",
                },
            },
        )
    )

    assert replacement.parent_asset_name == "Rack principal"
    assert replacement.removed_asset_path == "ZC4 > PCSG 1 > Tarjeta retirada"
    assert replacement.removed_serial_number == "SN-OLD"
    assert replacement.installed_asset_name == "Tarjeta instalada"
    assert replacement.installed_serial_number == "SN-NEW"


def test_pdf_signature_is_scaled_into_the_complete_canvas() -> None:
    data_uri = PreventivePDFService._signature_data_uri(
        [[{"x": 800, "y": 500}, {"x": 1200, "y": 900}]]
    )
    svg = base64.b64decode(data_uri.split(",", maxsplit=1)[1]).decode()
    points = re.search(r'points="([^"]+)"', svg)

    assert points is not None
    coordinates = [
        tuple(float(value) for value in pair.split(","))
        for pair in points.group(1).split()
    ]
    assert all(0 <= x <= 260 and 0 <= y <= 90 for x, y in coordinates)
