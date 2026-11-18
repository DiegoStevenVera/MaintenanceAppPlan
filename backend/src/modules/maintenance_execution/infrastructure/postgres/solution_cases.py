"""Consolidate all turns and versions without modifying source reports.

The read projection is refreshed on consultation. Only changed fingerprints are written;
failures are retried on the next consultation and cannot block maintenance report writes.
"""

import hashlib
import json
import re
from collections import defaultdict
from datetime import UTC, datetime

from sqlalchemy import select, text

from modules.asset_management.infrastructure.postgres.domain_models import AssetReplacementRecord
from modules.asset_management.infrastructure.postgres.models import AssetRecord
from modules.maintenance_execution.application.solution_matching import normalized, rank_case
from modules.maintenance_execution.infrastructure.postgres.models import CorrectiveEventRecord
from modules.maintenance_execution.infrastructure.postgres.report_models import (
    AttachmentRecord, CorrectiveActivityRecord, CorrectiveEventAffectedAssetRecord,
    CorrectiveEventCommentRecord, CorrectiveReportDetailRecord, MaintenanceActivityAssetRecord,
    MaintenanceActivityRecord, MaintenanceReportRecord, ReportVersionRecord,
)


def documentary_outcome(status: str, sources: list[dict]) -> str:
    final = [s for s in sources if s["principal"] and s["finalized"]]
    if status not in {"COMPLETED", "CLOSED"}:
        return "PENDING"
    if not final:
        return "UNDOCUMENTED"
    if any(not s["finalized"] and s["searchable"] for s in sources):
        return "UNVALIDATED"
    last = final[-1]
    passed = normalized(last["validation"] or "") in {"conforme", "satisfactorio", "aprobado", "correcto", "ok"}
    operational = normalized(last["technical_status"] or "") in {"operativo", "operativa", "normal"}
    contradictory = re.search(r"no se (?:realiz|pudo|valid)|sin pruebas|pruebas? pendientes?|pruebas? fallidas?|"
        r"sin solucion|problema persiste|no se resolvi", normalized(
            (last["tests"] or "") + " " + (last.get("conclusion") or "")))
    return ("VALIDATED" if passed and operational and last["service_released"] and last["tests"] and not contradictory
            else "UNVALIDATED")


class SolutionCaseRepository:
    def __init__(self, session):
        self.session = session

    async def refresh(self) -> None:
        await self.session.execute(text("SELECT pg_advisory_xact_lock(20261135)"))
        events = (await self.session.scalars(select(CorrectiveEventRecord))).all()
        if not events:
            return
        reports = (await self.session.execute(
            select(MaintenanceReportRecord, ReportVersionRecord, CorrectiveReportDetailRecord)
            .join(ReportVersionRecord, ReportVersionRecord.maintenance_report_id == MaintenanceReportRecord.id)
            .outerjoin(CorrectiveReportDetailRecord, CorrectiveReportDetailRecord.report_version_id == ReportVersionRecord.id)
            .where(MaintenanceReportRecord.report_kind == "CORRECTIVE")
            .order_by(MaintenanceReportRecord.report_number, ReportVersionRecord.version_number)
        )).all()
        version_ids = [v.id for _, v, _ in reports]
        actions = defaultdict(list)
        evidence = defaultdict(list)
        replacements = defaultdict(list)
        if version_ids:
            for action in (await self.session.scalars(select(CorrectiveActivityRecord).where(
                CorrectiveActivityRecord.report_version_id.in_(version_ids)
            ).order_by(CorrectiveActivityRecord.sequence))).all():
                actions[action.report_version_id].append({"id": str(action.id), "name": action.name, "description": action.description,
                    "notes": action.notes,
                    "started_at": action.started_at.isoformat(), "ended_at": action.ended_at.isoformat() if action.ended_at else None})
            for item in (await self.session.scalars(select(AttachmentRecord).where(
                AttachmentRecord.report_version_id.in_(version_ids)
            ).order_by(AttachmentRecord.captured_at))).all():
                evidence[item.report_version_id].append({"id": str(item.id), "title": item.title or item.original_file_name or "Evidencia",
                    "url": f"/api/v1/corrective-solutions/evidence/{item.id}", "media_type": item.media_type,
                    "size_bytes": item.file_size_bytes})
            for item in (await self.session.scalars(select(AssetReplacementRecord).where(
                AssetReplacementRecord.report_version_id.in_(version_ids)
            ))).all():
                replacements[item.report_version_id].append({"record_id": str(item.id), "removed_asset_id": item.removed_asset_id,
                    "installed_asset_id": item.installed_asset_id, "source_description": item.source_description,
                    "destination_description": item.destination_description, "reason": item.reason})
        by_activity = defaultdict(list)
        by_event = defaultdict(list)
        by_report = defaultdict(list)
        for report, version, detail in reports:
            by_report[report.id].append(version)
            by_activity[report.maintenance_activity_id].append((report, version, detail))
            if detail:
                by_event[detail.corrective_event_id].append((report, version, detail))
        principals = {}
        latest = {}
        for report_id, versions in by_report.items():
            finalized = [v for v in versions if v.document_status == "FINALIZED"]
            principals[report_id] = (finalized or versions)[-1].id
            latest[report_id] = versions[-1].id
        assets = {a.id: a for a in (await self.session.scalars(select(AssetRecord))).all()}
        affected = defaultdict(set)
        for event_id, asset_id in (await self.session.execute(select(
            CorrectiveEventAffectedAssetRecord.corrective_event_id, CorrectiveEventAffectedAssetRecord.asset_id
        ))).all():
            affected[event_id].add(asset_id)
        activity_assets = defaultdict(set)
        for activity_id, asset_id in (await self.session.execute(select(
            MaintenanceActivityAssetRecord.maintenance_activity_id, MaintenanceActivityAssetRecord.asset_id
        ))).all():
            activity_assets[activity_id].add(asset_id)
        comments = defaultdict(list)
        for comment in (await self.session.scalars(select(CorrectiveEventCommentRecord)
                .order_by(CorrectiveEventCommentRecord.created_at))).all():
            comments[comment.corrective_event_id].append({"id": str(comment.id), "text": comment.message,
                "date": comment.created_at.isoformat(), "provisional": True})
        activities = {a.id: a for a in (await self.session.scalars(select(MaintenanceActivityRecord).where(
            MaintenanceActivityRecord.activity_type == "CORRECTIVE"))).all()}
        fingerprints = dict((await self.session.execute(text(
            "SELECT event_id, fingerprint FROM corrective_solution_cases"
        ))).all())
        for event in events:
            sources = []
            relevant = {v.id: (r, v, d) for r, v, d in
                by_activity[event.maintenance_activity_id] + by_event[event.id]
                if d is None or d.corrective_event_id == event.id}
            for report, version, detail in sorted(relevant.values(), key=lambda row: (row[0].report_number, row[1].version_number)):
                snapshot = version.data_snapshot or {}
                if not isinstance(snapshot, dict):
                    snapshot = {}
                data = snapshot.get("corrective", snapshot)
                if not isinstance(data, dict):
                    data = {}

                def value(key):
                    return data[key] if key in data else getattr(detail, key, None) if detail else None

                source_actions = data.get("activities") or actions[version.id]
                source_actions = [{**a, "id": str(a.get("client_id") or a.get("id") or f"{version.id}:{index}")}
                    for index, a in enumerate(source_actions) if isinstance(a, dict)]
                source = {"id": str(version.id), "report_id": str(report.id), "report_number": report.report_number,
                    "version": version.version_number, "shift": report.shift_label,
                    "date": (version.finalized_at or version.created_at).isoformat(),
                    "finalized": version.document_status == "FINALIZED",
                    "principal": version.id == principals[report.id],
                    "searchable": version.id in {principals[report.id], latest[report.id]},
                    "symptom": value("symptom"), "description": value("technical_description"),
                    "impact": value("operational_impact"),
                    "analysis": value("failure_analysis_type"), "actions": source_actions,
                    "tests": value("functional_tests"), "validation": value("validation_result"),
                    "service_released": bool(value("service_released")), "technical_status": value("technical_status"),
                    "conclusion": value("conclusion"), "additional_comments": value("additional_comments"),
                    "evidence": evidence[version.id], "replacements": replacements[version.id]}
                sources.append(source)
            linked = affected[event.id] | activity_assets[event.maintenance_activity_id]
            linked.update(i for i in (event.primary_asset_id, event.affected_asset_id) if i in assets)
            context_assets = [{"id": i, "name": assets[i].name, "code": assets[i].serial_or_code,
                "type_key": str(assets[i].asset_type_id or assets[i].equipment_category_id or assets[i].asset_type),
                "part_number": assets[i].part_number} for i in sorted(linked) if i in assets]
            principal_sources = [s for s in sources if s["principal"]]
            problem = "\n".join(filter(None, [event.failure_description] + [
                s["symptom"] or s["description"] for s in principal_sources])) or "No documentado"
            chosen = principal_sources[-1] if principal_sources else {}
            activity = activities.get(event.maintenance_activity_id)
            status = activity.status if activity else event.status
            case = {"id": event.id, "activity_id": str(event.maintenance_activity_id) if event.maintenance_activity_id else None,
                "code": event.code, "sap_code": event.sap_code, "title": event.name, "status": status,
                "subsystem": event.subsystem, "date": event.notice_created_at,
                "location": event.physical_location, "impact": event.operational_impact,
                "problem": problem, "actions_summary": "\n".join(
                    a.get("description") or a.get("name", "") for s in principal_sources for a in s["actions"]),
                "tests_summary": chosen.get("tests"), "conclusion": chosen.get("conclusion"),
                "outcome": documentary_outcome(status, sources), "assets": context_assets,
                "asset_ids": sorted(linked), "type_keys": sorted({a["type_key"] for a in context_assets}),
                "sources": sources, "comments": comments[event.id], "reasons": [],
                "has_provisional": bool(comments[event.id]) or any(not s["finalized"] and s["searchable"] for s in sources) or status not in {"COMPLETED", "CLOSED"},
                "timeline": event.timeline or []}
            searchable = [s for s in sources if s["searchable"]]
            case["search_text"] = "\n".join(filter(None, [event.name, event.code, event.sap_code,
                event.failure_description, json.dumps(context_assets, ensure_ascii=False),
                json.dumps(searchable, ensure_ascii=False, default=str), json.dumps(case["comments"], ensure_ascii=False)]))
            encoded = json.dumps(case, ensure_ascii=False, sort_keys=True, default=str)
            fingerprint = hashlib.sha256(encoded.encode()).hexdigest()
            if fingerprints.get(event.id) != fingerprint:
                await self.session.execute(text("""INSERT INTO corrective_solution_cases(event_id, fingerprint, payload)
                    VALUES (:id, :fingerprint, CAST(:payload AS jsonb))
                    ON CONFLICT (event_id) DO UPDATE SET fingerprint=EXCLUDED.fingerprint,
                    payload=EXCLUDED.payload, refreshed_at=now()"""),
                    {"id": event.id, "fingerprint": fingerprint, "payload": encoded})
        await self.session.commit()

    async def all_cases(self) -> list[dict]:
        return (await self.snapshot())[0]

    async def snapshot(self) -> tuple[list[dict], str]:
        await self.refresh()
        rows = (await self.session.execute(text(
            "SELECT payload, event_id, fingerprint FROM corrective_solution_cases ORDER BY event_id"
        ))).all()
        revision = hashlib.sha256("".join(row[1] + row[2] for row in rows).encode()).hexdigest()
        return [row[0] for row in rows], revision

    async def search(self, *, query="", subsystem=None, asset_id=None, similar_to=None,
                     include_provisional=True, limit=20, offset=0, bundle=False, revision=None) -> dict:
        cases, current_revision = await self.snapshot()
        if revision and revision != current_revision:
            raise ValueError("El historial cambió durante la descarga. Descárgalo nuevamente.")
        context = next((c for c in cases if c["id"] == similar_to or c["activity_id"] == similar_to), None) if similar_to else None
        if similar_to and context is None:
            raise ValueError("Correctivo de referencia no encontrado.")
        effective_query = query or (context["problem"][:1000] if context and context["problem"] != "No documentado" else "")
        effective_subsystem = subsystem or (context["subsystem"] if context else None)
        ranked = []
        for case in cases:
            if context and case["id"] == context["id"]:
                continue
            if effective_subsystem and case["subsystem"] != effective_subsystem:
                continue
            if asset_id and asset_id not in case["asset_ids"]:
                continue
            if not include_provisional:
                case = finalized_case(case)
                if case is None:
                    continue
            score, reasons = rank_case(case, effective_query, context)
            if score <= 0 and not bundle:
                continue
            ranked.append((score, {**case, "reasons": reasons}))
        ranked.sort(key=lambda row: (row[1]["date"], row[1]["id"]), reverse=True)
        ranked.sort(key=lambda row: -row[0])
        options = {a["id"]: a for case in cases for a in case["assets"]}
        suggestions = sorted({s["symptom"][:160] for c in cases
            if (not effective_subsystem or c["subsystem"] == effective_subsystem)
            and (not asset_id or asset_id in c["asset_ids"])
            for s in c["sources"] if s["principal"] and s["symptom"]
            and (include_provisional or s["finalized"])})[:8]
        return {"items": [row[1] for row in ranked[offset:offset+limit]], "total": len(ranked),
            "limit": limit, "offset": offset, "query": effective_query,
            "engine": "textual_contextual", "context_only": not bool(effective_query.strip()),
            "revision": current_revision,
            "updated_at": datetime.now(UTC).isoformat(),
            "subsystems": sorted({c["subsystem"] for c in cases}),
            "suggestions": suggestions,
            "assets": sorted(options.values(), key=lambda a: (a["name"], a["id"]))}


def finalized_case(case: dict) -> dict | None:
    sources = [s for s in case["sources"] if s["finalized"]]
    if not sources:
        return None
    principals = [s for s in sources if s["principal"]]
    latest = principals[-1] if principals else {}
    return {**case, "sources": sources, "comments": [], "has_provisional": False,
        "problem": "\n".join(s["symptom"] or s["description"] or "" for s in principals) or "No documentado",
        "actions_summary": "\n".join(a.get("description") or a.get("name", "")
            for s in principals for a in s["actions"]),
        "tests_summary": latest.get("tests"), "conclusion": latest.get("conclusion"),
        "search_text": json.dumps({"title": case["title"], "code": case["code"], "sap": case["sap_code"],
            "assets": case["assets"], "reports": principals}, ensure_ascii=False, default=str)}
