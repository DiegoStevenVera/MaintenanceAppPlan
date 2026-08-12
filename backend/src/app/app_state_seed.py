from __future__ import annotations

from datetime import UTC, datetime, timedelta


BASE_NOW = datetime(2026, 7, 6, 9, 0, tzinfo=UTC)


def iso(offset_days: int = 0, hours: int = 0, minutes: int = 0) -> str:
    return (BASE_NOW + timedelta(days=offset_days, hours=hours, minutes=minutes)).isoformat()


def uuid(key: str) -> str:
    import uuid as uuid_lib

    return str(uuid_lib.uuid5(uuid_lib.NAMESPACE_DNS, f"maintenance-app:{key}"))


def user(
    user_id: str,
    name: str,
    role: str,
    email: str = "",
    avatar: str = "person.crop.circle.fill",
) -> dict:
    return {
        "id": user_id,
        "name": name,
        "role": role,
        "email": email,
        "avatarSystemImage": avatar,
    }


USERS = [
    user("user-diego", "Diego Vera", "maintenanceEngineer", "diego@maintenance.local"),
    user("user-joab", "Joab Apaza", "maintenanceEngineer", "joab@maintenance.local", "person.crop.circle"),
    user("user-fredy", "Fredy Navarrete", "coordinator", "fredy@maintenance.local", "person.crop.square.fill"),
    user("user-jefe", "Jefe de mantenimiento", "boss", "jefe@maintenance.local", "person.crop.rectangle.fill"),
    user("user-admin", "Administrador", "administrator", "admin@maintenance.local", "person.badge.key.fill"),
]


def step_test(key: str, name: str, options: list[str] | None = None, selected: str | None = None) -> dict:
    result_options = options or ["Conforme", "No conforme", "No aplica"]
    return {
        "id": uuid(f"test:{key}:{name}"),
        "name": name,
        "resultOptions": result_options,
        "selectedResult": selected or result_options[0],
        "notes": "",
    }


def step(key: str, title: str, manual_page: int, tests: list[dict], comment: str = "") -> dict:
    return {
        "id": uuid(f"step:{key}:{title}"),
        "title": title,
        "manualPage": manual_page,
        "isCompleted": True,
        "comment": comment,
        "tests": tests,
    }


def report_version(key: str, number: int, created_by: str, created_at: str, summary: str = "PDF disponible") -> dict:
    return {
        "id": uuid(f"version:{key}:{number}"),
        "versionNumber": number,
        "createdBy": created_by,
        "createdAt": created_at,
        "summary": summary,
    }


def timeline(key: str, timestamp: str, text: str) -> dict:
    return {"id": uuid(f"timeline:{key}:{timestamp}:{text}"), "timestamp": timestamp, "text": text}


def signature(user_payload: dict, key: str, offset: float = 0) -> dict:
    strokes = [
        [
            {"x": 24 + offset, "y": 66},
            {"x": 58 + offset, "y": 34},
            {"x": 92 + offset, "y": 70},
            {"x": 132 + offset, "y": 38},
            {"x": 182 + offset, "y": 62},
            {"x": 232 + offset, "y": 48},
        ],
        [
            {"x": 52 + offset, "y": 84},
            {"x": 112 + offset, "y": 78},
            {"x": 178 + offset, "y": 82},
            {"x": 248 + offset, "y": 76},
        ],
    ]
    return {
        "id": uuid(f"signature:{key}:{user_payload['id']}"),
        "user": user_payload,
        "strokes": strokes,
        "signedAt": iso(hours=-1),
    }


def historical_steps(prefix: str) -> list[dict]:
    return [
        step(
            f"hist-{prefix}-1",
            f"{prefix}: inspeccion inicial",
            8,
            [
                step_test(f"hist-{prefix}-visual", "Condicion visual"),
                step_test(f"hist-{prefix}-alarmas", "Alarmas activas", ["Sin alarmas", "Alarmas menores", "Alarmas criticas"]),
            ],
            "Sin observaciones criticas.",
        ),
        step(
            f"hist-{prefix}-2",
            f"{prefix}: pruebas funcionales",
            14,
            [
                step_test(f"hist-{prefix}-respuesta", "Respuesta del equipo"),
                step_test(f"hist-{prefix}-eventos", "Registro de eventos"),
            ],
            "Pruebas completadas.",
        ),
    ]


def historical_report(
    key: str,
    equipment: str,
    activity: str,
    engineer: str,
    days_ago: int,
    result: str,
    participants: list[dict],
) -> dict:
    return {
        "id": uuid(f"historical:{key}"),
        "equipmentName": equipment,
        "activityName": activity,
        "engineerName": engineer,
        "performedAt": iso(offset_days=-days_ago),
        "result": result,
        "steps": historical_steps(key),
        "participants": participants,
    }


def preventive_activity(
    key: str,
    name: str,
    template: str,
    assets: list[str],
    location: str,
    location_path: str,
    subsystem: str,
    status: str,
    scheduled_at: str,
    manual: str,
    frequency: str,
    tools: list[str],
    steps: list[dict],
    versions: list[dict] | None = None,
    started_at: str | None = None,
    ended_at: str | None = None,
) -> dict:
    return {
        "id": key,
        "name": name,
        "templateName": template,
        "assets": assets,
        "site": "Metro Lima",
        "project": "Linea 2",
        "stage": "Etapa 1A",
        "system": "Senalizacion",
        "location": location,
        "locationPath": location_path,
        "subsystem": subsystem,
        "scheduledDate": scheduled_at,
        "startedAt": started_at,
        "endedAt": ended_at,
        "status": status,
        "manualReference": manual,
        "frequency": frequency,
        "estimatedMinutes": 90,
        "requiredPersonnel": 2,
        "requiredTools": tools,
        "steps": steps,
        "reportVersions": versions or [],
    }


def corrective_event(
    key: str,
    code: str,
    sap_code: str,
    name: str,
    asset: str,
    location: str,
    subsystem: str,
    severity: str,
    status: str,
    notice_at: str,
    response_at: str,
    failure: str,
    impact: str,
    event_timeline: list[dict],
    activities: list[dict] | None = None,
    versions: list[dict] | None = None,
) -> dict:
    return {
        "id": key,
        "code": code,
        "sapCode": sap_code,
        "name": name,
        "site": "Metro Lima",
        "project": "Linea 2",
        "stage": "Etapa 1A",
        "system": "Senalizacion",
        "affectedAsset": asset,
        "location": location,
        "subsystem": subsystem,
        "noticeCreatedAt": notice_at,
        "responseAt": response_at,
        "severity": severity,
        "status": status,
        "failureDescription": failure,
        "operationalImpact": impact,
        "symptom": "",
        "technicalDescription": "",
        "impactSelection": "degraded",
        "failureAnalysis": "hardware",
        "functionalTests": "",
        "validationResult": "compliant",
        "serviceRelease": False,
        "serviceReleaseAt": response_at,
        "validationResponsible": "",
        "technicalStatus": "operational",
        "observations": "",
        "timeline": event_timeline,
        "activities": activities or [],
        "reportVersions": versions or [],
    }


def replacement(key: str) -> dict:
    return {
        "id": uuid(f"replacement:{key}"),
        "parentAsset": "Frontam Colectora",
        "removedAsset": "Servidor Frontam Aplicacion 1 / CZJ5470N75",
        "installedAsset": "Servidor Frontam repuesto 01 / CZ3909PF9W-SPARE",
        "source": "Almacen SPV",
        "destination": "Almacenamiento Mantto Hitachi",
        "reason": "Falla de hardware",
        "removedPartNumber": "SRV-FRONTAM-001",
        "removedSerialNumber": "CZJ5470N75",
        "removedModel": "Frontam Server App",
        "removedManufacturer": "Hitachi Rail",
        "removedCondition": "inoperative",
        "removedDestination": "Almacenamiento Mantto Hitachi",
        "removedNotes": "Equipo retirado para diagnostico.",
        "installedPartNumber": "SRV-FRONTAM-001",
        "installedSerialNumber": "CZ3909PF9W-SPARE",
        "installedModel": "Frontam Server App",
        "installedManufacturer": "Hitachi Rail",
        "installedCondition": "operational",
        "installedNotes": "Repuesto instalado desde stock SPV.",
    }


def corrective_activity(key: str, activity_type: str, description: str, notes: str, with_replacement: bool = False) -> dict:
    return {
        "id": uuid(f"corrective-activity:{key}"),
        "type": activity_type,
        "description": description,
        "notes": notes,
        "startedAt": iso(hours=-2),
        "endedAt": iso(hours=-1),
        "replacement": replacement(key) if with_replacement else None,
    }


def physical_location(category: str, item_type: str, name: str) -> str:
    folded = f"{category} {item_type} {name}".lower()
    if "colectora" in folded:
        return "Estacion Colectora Industrial -> Sala tecnica -> Sala 2.21"
    if "patio" in folded:
        return "Patio Santa Anita -> Sala tecnica -> Sala 2.21"
    if "tren" in folded:
        return f"Material rodante -> {name} -> Coche principal"
    if "cbdac" in folded or "circuito" in folded:
        return "Via principal -> Sector Etapa 1A -> Caja de circuito de via"
    if "conmutacion" in folded:
        return "Via principal -> Sector Etapa 1A -> Zona de aguja"
    if "zc" in folded or "zone controller" in folded:
        return "Estacion asignada -> Sala tecnica CBTC -> Gabinete ZC"
    if any(token in folded for token in ["limsys", "limdbc", "limcom", "limcws", "limovw", "crk", "erk", "simulador"]):
        return "Patio Santa Anita -> Sala tecnica ATS -> Gabinetes ATS"
    if any(token in folded for token in ["pp tipo", "rc tipo", "vhmi", "wsp", "sir"]):
        return "Estacion asignada -> Sala tecnica IXL -> Gabinete IXL"
    return "Ubicacion fisica por confirmar"


def equipment_payload() -> list[dict]:
    rows: list[tuple[str, str, str]] = []
    rows.extend(
        ("Servidor", "Servidor ATS", name)
        for name in [
            "LIMSYS001", "LIMSYS002", "LIMDBC001", "LIMCOM001", "LIMCOM002",
            "LIMCWS001", "LIMCWS002", "LIMCWS003", "LIMCWS004", "LIMCWS005",
            "LIMOVW001", "LIMOVW002", "LIMSYS101", "LIMSYS102", "LIMDBC101",
            "LIMCOM101", "LIMCOM102", "LIMCWS101", "LIMCWS102", "LIMCWS103",
            "LIMCWS104", "LIMCWS105", "LIMOVW101", "LIMOVW102",
        ]
    )
    rows.extend(
        [
            ("Estacion de trabajo", "Simulador", "Simulador"),
            ("Gabinetes", "ATS", "CRK 1"),
            ("Gabinetes", "ATS", "CRK 2"),
            ("Gabinetes", "ATS", "ERK 1"),
            ("Gabinetes", "ATS", "ERK 2"),
            ("Vehiculo", "Tren", "Tren 14"),
            ("Vehiculo", "Tren", "Tren 26"),
            ("Vehiculo", "Tren", "Tren 27"),
            ("Vehiculo", "Tren", "Tren 28"),
            ("Vehiculo", "Tren", "Tren 29"),
            ("Gabinetes", "Zone Controller", "ZC4"),
            ("Gabinetes", "Zone Controller", "ZC2"),
            ("Gabinetes", "Zone Controller", "ZC5"),
            ("Gabinetes", "Zone Controller", "ZC3"),
            ("Gabinetes", "Frontam", "CUBICULO EQUIPADO DEL FRONTAM - PATIO"),
            ("Estacion de trabajo", "Frontam", "ESTACION DE TRABAJO FRONTAM (PSAUME) - PATIO"),
            ("Gabinetes", "Puesto central IXL", "VHMI - PATIO"),
            ("Gabinetes", "Puesto central IXL", "WSP - PATIO"),
            ("Gabinetes", "Puesto central IXL", "SIR - PATIO"),
            ("Gabinetes", "Frontam", "CUBICULO EQUIPADO DEL FRONTAM - COLECTORA"),
            ("Estacion de trabajo", "Frontam", "ESTACION DE TRABAJO FRONTAM (PSAUME) - COLECTORA"),
            ("Gabinetes", "Puesto central IXL", "VHMI - COLECTORA"),
            ("Gabinetes", "Puesto central IXL", "WSP - COLECTORA"),
            ("Gabinetes", "Puesto central IXL", "SIR - COLECTORA"),
        ]
    )
    rows.extend(("Gabinetes", "Puestos perifericos", f"PP TIPO 24 PTSA PP 01-04-{n:02d}") for n in range(1, 7))
    rows.extend(("Gabinetes", "Puestos perifericos Rele", name) for name in [
        "RC TIPO RC SERVER", "RC TIPO RC EMSA 24-01", "RC TIPO RC EHVA 23-01",
        "RC TIPO RC ECIN 22-01", "RC TIPO RC ECIN 22-02", "RC TIPO RC EOSA 21-01",
        "RC TIPO RC EEVI 20-01",
    ])
    rows.extend(("Equipo de via", "Maquinas de conmutacion", f"MAQUINAS DE CONMUTACION {n}") for n in list(range(101, 127)) + [265, 263, 262, 261, 260, 259, 258, 257, 256, 255, 254, 253, 252, 251, 250])
    rows.extend(("Equipo de via", "Circuito de via", f"CBDAC {n}") for n in list(range(1002, 1038)) + [2407, 2413, 2405, 2403, 2402, 2401, 2308, 2307, 2306, 2305, 2304, 2303, 2302, 2301, 2206, 2205, 2204, 2203, 2202, 2201, 2108, 2107, 2106, 2105, 2104, 2103, 2102, 2101, 2008, 2006, 2005, 2004, 2003, 2002, 2001])

    assets = []
    for idx, (category, item_type, name) in enumerate(rows, start=1):
        children = []
        part_number = "-"
        if name == "CUBICULO EQUIPADO DEL FRONTAM - COLECTORA":
            children = ["Gabinete / conjunto principal", "Modulo interno", "Tarjeta de comunicacion"]
            part_number = "FRONTAM-CAB-001"
        assets.append(
            {
                "id": f"stage-1a-equipment-{idx}",
                "name": name,
                "type": item_type,
                "category": category,
                "businessLabel": "Equipo",
                "isBusinessAnchor": True,
                "serialOrCode": f"EQ-1A-{idx:03d}",
                "partNumber": part_number,
                "status": "Activo",
                "location": physical_location(category, item_type, name),
                "parent": None,
                "children": children,
                "history": ["Equipo grande registrado en etapa 1A"],
            }
        )
    return assets


def stock_assets() -> list[dict]:
    return [
        {"id": "stock-frontam-server-01", "name": "Servidor Frontam repuesto 01", "type": "Servidor Frontam", "serialOrCode": "CZ3909PF9W-SPARE", "partNumber": "SRV-FRONTAM-001", "status": "En stock", "location": "Almacen SPV", "subsystem": "CBTC"},
        {"id": "stock-frontam-server-02", "name": "Servidor Frontam repuesto 02", "type": "Servidor Frontam", "serialOrCode": "CZ3909PF9W-SPARE-02", "partNumber": "SRV-FRONTAM-001", "status": "En stock", "location": "Almacenamiento Mantto Hitachi", "subsystem": "CBTC"},
        {"id": "stock-frontam-comm-01", "name": "Tarjeta de comunicacion Frontam repuesto 01", "type": "Modulo de comunicacion Frontam", "serialOrCode": "FTM-COMM-SPV-01", "partNumber": "COMM-FRONTAM-001", "status": "En stock", "location": "Almacen SPV", "subsystem": "CBTC"},
        {"id": "stock-frontam-comm-02", "name": "Tarjeta de comunicacion Frontam repuesto 02", "type": "Modulo de comunicacion Frontam", "serialOrCode": "FTM-COMM-HIT-02", "partNumber": "COMM-FRONTAM-001", "status": "En stock", "location": "Almacenamiento Mantto Hitachi", "subsystem": "CBTC"},
        {"id": "stock-cier-01", "name": "Tarjeta CIER repuesto 01", "type": "Tarjeta CIER", "serialOrCode": "CIER-SPARE-001", "partNumber": "CIER-001", "status": "En stock", "location": "Almacen SPV", "subsystem": "CBTC"},
        {"id": "stock-pcsg-01", "name": "PCSG repuesto 01", "type": "Servidor PCSG", "serialOrCode": "PCSG-SPARE-001", "partNumber": "PCSG-001", "status": "En stock", "location": "Almacenamiento Mantto Hitachi", "subsystem": "CBTC"},
    ]


def build_app_state() -> dict:
    diego, joab, fredy = USERS[0], USERS[1], USERS[2]
    activities = [
        preventive_activity(
            "prv-001",
            "Mantenimiento preventivo de software ATS - ECIN",
            "Mantenimiento preventivo de software ATS",
            ["Software ATS Patio", "LIMSYS001", "LIMSYS002"],
            "Sala 2.21",
            "Patio -> Patio Santa Anita -> Sala tecnica -> Sala 2.21",
            "ATS",
            "scheduled",
            iso(),
            "ML2-AST-GEN-G-000-GRAL-SSATS-GEN-MN-3500-0A",
            "Revision periodica diaria",
            ["Laptop de mantenimiento", "Probador de red"],
            [
                step("prv-001-1", "Revision de archivos de registro del sistema", 12, [step_test("prv-001-logs", "Alarmas criticas en logs"), step_test("prv-001-eventos", "Eventos repetitivos pendientes", ["Sin repeticion", "Repeticion menor", "Requiere seguimiento"])]),
                step("prv-001-2", "Verificacion de herramienta de estado del nodo", 15, [step_test("prv-001-nodos", "Estado de nodos ATS"), step_test("prv-001-comunicacion", "Comunicacion entre servidores")]),
                step("prv-001-3", "Verificacion del uso de memoria", 18, [step_test("prv-001-memoria", "Uso de memoria dentro de umbral", ["Normal", "Alto", "Critico"]), step_test("prv-001-cpu", "CPU dentro de umbral", ["Normal", "Alto", "Critico"])]),
            ],
        ),
        preventive_activity(
            "prv-002",
            "Inspeccion de gabinete Frontam - Colectora",
            "Inspeccion de gabinete Frontam",
            ["Frontam Colectora"],
            "Sala 2.21",
            "Estacion -> Colectora Industrial -> Sala tecnica -> Sala 2.21",
            "CBTC",
            "inProgress",
            iso(),
            "ML2-CBTC-FRONTAM-MN-001",
            "Mensual",
            ["Multimetro digital", "Torquimetro"],
            [
                step("prv-002-1", "Inspeccion visual del gabinete", 8, [step_test("prv-002-gabinete", "Estado fisico del gabinete"), step_test("prv-002-limpieza", "Limpieza interna", ["Limpio", "Polvo leve", "Requiere limpieza"])], "Sin observaciones."),
                step("prv-002-2", "Verificacion de ventiladores", 11, [step_test("prv-002-ventiladores", "Ventiladores operativos"), step_test("prv-002-ruido", "Ruido o vibracion", ["Normal", "Ruido leve", "Requiere revision"])]),
                step("prv-002-3", "Verificacion de servidores", 14, [step_test("prv-002-principal", "Servidor principal operativo"), step_test("prv-002-redundante", "Servidor redundante operativo")]),
            ],
            [report_version("prv-002", 1, "Diego Vera", iso(hours=-1))],
            started_at=iso(hours=-1),
        ),
        preventive_activity("prv-003", "Inspeccion de CRK 1 y CRK 2", "Inspeccion de gabinete Frontam", ["CRK 1", "CRK 2"], "Colectora Industrial", "Estacion -> Colectora Industrial -> Sala tecnica -> Gabinetes ATS", "ATS", "completed", iso(-4), "ML2-ATS-CRK-MN-001", "Mensual", ["Laptop de mantenimiento", "Multimetro digital"], [step("prv-003-1", "Inspeccion visual de gabinetes", 6, [step_test("prv-003-puertas", "Puertas y cerraduras"), step_test("prv-003-indicadores", "Indicadores luminosos")], "Gabinetes operativos.")], [report_version("prv-003", 1, "Joab Apaza", iso(-4, hours=2))], started_at=iso(-4, hours=1), ended_at=iso(-4, hours=3)),
        preventive_activity("prv-004", "Inspeccion de Zone Controller ZC4", "Inspeccion de Zone Controller", ["ZC4"], "Sala tecnica CBTC", "Estacion asignada -> Sala tecnica CBTC -> Gabinete ZC", "CBTC", "closed", iso(-18), "ML2-CBTC-ZC-MN-001", "Mensual", ["Laptop de mantenimiento", "Multimetro digital"], [step("prv-004-1", "Revision de estado de controlador", 9, [step_test("prv-004-estado", "Estado de controlador"), step_test("prv-004-red", "Comunicacion con red CBTC")], "Sin alarmas.")], [report_version("prv-004", 1, "Fredy Navarrete", iso(-18), "Equipo operativo")], started_at=iso(-18, hours=1), ended_at=iso(-18, hours=2)),
        preventive_activity("prv-005", "Mantenimiento preventivo de circuito de via CBDAC 1002", "Mantenimiento preventivo de circuito de via", ["CBDAC 1002"], "Via principal", "Via principal -> Sector Etapa 1A -> Caja de circuito de via", "IXL", "closed", iso(-68), "ML2-IXL-CBDAC-MN-001", "Trimestral", ["Multimetro digital", "Herramientas de via"], [step("prv-005-1", "Verificacion de circuito de via", 7, [step_test("prv-005-tension", "Tension de circuito"), step_test("prv-005-ocupacion", "Ocupacion y liberacion")], "Valores dentro de rango.")], [report_version("prv-005", 1, "Joab Apaza", iso(-68), "Equipo operativo")], started_at=iso(-68, hours=1), ended_at=iso(-68, hours=2)),
    ]
    corrective_events = [
        corrective_event(
            "cor-001",
            "COR-2026-001",
            "110010514",
            "E22 Falla de servidor Frontam",
            "Frontam Colectora",
            "Estacion Colectora Industrial -> Sala tecnica -> Sala 2.21",
            "CBTC",
            "high",
            "inProgress",
            iso(minutes=-78),
            iso(minutes=-55),
            "Se reporta falla de servidor de aplicacion en gabinete Frontam.",
            "Degradacion de servicio",
            [timeline("cor-001", "09:12", "Stop Here despues de actividades"), timeline("cor-001", "09:10", "Version 1 del reporte finalizada"), timeline("cor-001", "08:05", "Mantenimiento iniciado"), timeline("cor-001", "07:42", "Evento creado por Diego Vera")],
            [
                corrective_activity("cor-001-inspection", "inspection", "Se verifico el gabinete Frontam y se confirmo falla de servidor.", "Se requiere continuidad en siguiente turno."),
                corrective_activity("cor-001-replacement", "replacement", "Se reemplazo el Servidor Frontam Aplicacion 1.", "Equipo retirado enviado a almacenamiento Mantto Hitachi.", True),
            ],
            [report_version("cor-001", 1, "Diego Vera", iso(), "Servidor restaurado parcialmente")],
        ),
        corrective_event("cor-002", "COR-2026-002", "110013642", "Frontam sin redundancia", "Frontam Patio", "Patio Santa Anita -> Sala tecnica -> Sala 2.21", "CBTC", "medium", "completed", iso(-9), iso(-9, minutes=48), "Operacion sin redundancia en Frontam Patio.", "Operacion degradada", [timeline("cor-002", "11:20", "Version 1 del reporte finalizada"), timeline("cor-002", "10:30", "Evento completado")], versions=[report_version("cor-002", 1, "Fredy Navarrete", iso(-9), "Redundancia validada")]),
        corrective_event("cor-003", "COR-2026-003", "-", "Pantalla TOD intermitente", "TOD Tren 26 M1", "Tren 26 · Coche M1", "CBTC", "low", "scheduled", iso(-42), iso(-42, minutes=30), "Pantalla TOD presenta intermitencia durante inspeccion.", "Sin impacto operacional confirmado", [timeline("cor-003", "06:55", "Evento creado por Joab Apaza")]),
    ]
    historical_reports = [
        historical_report("ats-1", "Software ATS Patio", "Mantenimiento preventivo de software ATS", "Fredy Navarrete", 7, "Equipo operativo", [signature(fredy, "ats-1"), signature(joab, "ats-1", 12)]),
        historical_report("ats-2", "Software ATS Patio", "Mantenimiento preventivo de software ATS", "Joab Apaza", 14, "Equipo operativo", [signature(joab, "ats-2"), signature(diego, "ats-2", 18)]),
        historical_report("frontam", "Frontam Colectora", "Inspeccion de gabinete Frontam", "Diego Vera", 30, "Equipo medio operativo", [signature(diego, "frontam"), signature(fredy, "frontam", 10)]),
        historical_report("crk", "CRK 1", "Inspeccion de CRK 1", "Joab Apaza", 45, "Equipo operativo", [signature(joab, "crk"), signature(fredy, "crk", 16)]),
        historical_report("tren-14", "Tren 14", "Mantenimiento preventivo de equipo a bordo CC - Tren", "Diego Vera", 3, "Equipo operativo", [signature(diego, "tren-14"), signature(joab, "tren-14", 8)]),
        historical_report("zc4", "ZC4", "Inspeccion de Zone Controller", "Fredy Navarrete", 20, "Equipo operativo", [signature(fredy, "zc4"), signature(diego, "zc4", 14)]),
        historical_report("cbdac", "CBDAC 1002", "Mantenimiento preventivo de circuito de via", "Joab Apaza", 62, "Equipo medio operativo", [signature(joab, "cbdac"), signature(diego, "cbdac", 20)]),
        historical_report("maq-101", "MAQUINAS DE CONMUTACION 101", "Mantenimiento preventivo de maquina de conmutacion", "Diego Vera", 96, "Equipo operativo", [signature(diego, "maq-101"), signature(fredy, "maq-101", 6)]),
    ]
    return {
        "loginUsers": USERS,
        "activeMaintainers": [diego, joab, fredy],
        "activities": activities,
        "correctiveEvents": corrective_events,
        "assets": equipment_payload(),
        "stockAssets": stock_assets(),
        "maintenanceComments": [
            {"id": uuid("comment:preventive:ats"), "scopeKey": "preventive:Mantenimiento preventivo de software ATS|equipment:Software ATS Patio", "scopeDescription": "Mantenimiento preventivo de software ATS · Software ATS Patio", "author": fredy, "message": "Validar primero alarmas historicas antes de reiniciar servicios; esta observacion aplica para futuras ejecuciones del mismo mantenimiento.", "createdAt": iso(-1)},
            {"id": uuid("comment:preventive:frontam"), "scopeKey": "preventive:Inspeccion de gabinete Frontam|equipment:Frontam Colectora", "scopeDescription": "Inspeccion de gabinete Frontam · Frontam Colectora", "author": joab, "message": "El ventilador inferior suele acumular polvo; revisar con linterna antes de cerrar gabinete.", "createdAt": iso(hours=-12)},
        ],
        "correctiveComments": [
            {"id": uuid("comment:corrective:1"), "eventID": "cor-001", "author": fredy, "message": "Este comentario queda asociado solo al correctivo COR-2026-001; no debe reutilizarse en futuros eventos.", "createdAt": iso(hours=-2)},
            {"id": uuid("comment:corrective:2"), "eventID": "cor-001", "author": joab, "message": "Se recomienda revisar el intercambio de componente antes del cierre del turno.", "createdAt": iso(hours=-1)},
        ],
        "historicalReports": historical_reports,
        "preventiveReportSignatures": {
            "prev-001": [signature(diego, "prev-001"), signature(joab, "prev-001", 12)],
        },
        "correctiveReportSignatures": {
            "cor-001": [signature(diego, "cor-001"), signature(fredy, "cor-001", 10)],
        },
    }
