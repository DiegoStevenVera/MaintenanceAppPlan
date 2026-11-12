from __future__ import annotations

import copy
import heapq
import json
import sqlite3
from contextlib import closing
from functools import cached_property
from pathlib import Path
from typing import Any


class ATSLineRepository:
    """Reads the portable ATS line snapshot without depending on LineV2."""

    def __init__(self, database_path: Path):
        self.database_path = database_path
        if not database_path.is_file():
            raise FileNotFoundError(
                f"No se encontro la base portable de la linea ATS: {database_path}"
            )
        with closing(self._connect()) as database:
            version = database.execute("PRAGMA user_version").fetchone()[0]
        if version != 1:
            raise ValueError(f"Version de datos ATS incompatible: {version}")

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(
            self.database_path.resolve().as_uri() + "?mode=ro",
            uri=True,
        )
        connection.row_factory = sqlite3.Row
        return connection

    @cached_property
    def dataset(self) -> dict[str, Any]:
        with closing(self._connect()) as database:
            row = database.execute(
                "SELECT payload FROM dataset WHERE id = 1"
            ).fetchone()
        if row is None:
            raise ValueError("La base portable no contiene la linea ATS")
        return json.loads(row["payload"])

    @cached_property
    def segments(self) -> dict[str, dict[str, Any]]:
        return {item["id"]: item for item in self.dataset["segments"]}

    @cached_property
    def track_definitions(self) -> list[dict[str, Any]]:
        return self._definitions("track_definitions")

    @cached_property
    def platform_definitions(self) -> dict[str, dict[str, Any]]:
        return {item["id"]: item for item in self._definitions("platform_definitions")}

    @cached_property
    def calibration_links(self) -> list[dict[str, Any]]:
        balises = {
            str(item.get("id")): item
            for item in self.dataset["catalog"]
            if item.get("category") == "balise" and item.get("id")
        }
        links: list[dict[str, Any]] = []
        for calibration in self.dataset["calibrations"]:
            start = balises.get(str(calibration.get("start_balise_id", "")))
            end = balises.get(str(calibration.get("end_balise_id", "")))
            result: dict[str, Any]
            if not start or not end:
                result = {
                    "possible": False,
                    "distance": None,
                    "direction": None,
                    "traversed": [],
                    "reason": "Falta una baliza de la base de calibracion",
                }
            else:
                try:
                    result = self.distance_between(
                        str(start.get("segment_id", "")),
                        float(start.get("x", 0)),
                        str(end.get("segment_id", "")),
                        float(end.get("x", 0)),
                    )
                except (TypeError, ValueError) as error:
                    result = {
                        "possible": False,
                        "distance": None,
                        "direction": None,
                        "traversed": [],
                        "reason": str(error),
                    }
            links.append(
                {
                    **calibration,
                    "calculated_distance": result.get("distance"),
                    "calculated_direction": result.get("direction"),
                    "traversed": result.get("traversed", []),
                    "valid": bool(result.get("possible")),
                    "errors": [] if result.get("possible") else [result.get("reason")],
                }
            )
        return links

    def line_payload(self) -> dict[str, Any]:
        geometry = copy.deepcopy(self.dataset["geometry"])
        geometry["segments"] = [
            {**item, **self.segments.get(str(item["id"]), {})}
            for item in geometry["segments"]
        ]
        geometry["platforms"] = [
            {
                **item,
                **self.platform_definitions.get(
                    str(item["id"]),
                    {
                        "name": item["id"],
                        "physical_length_m": None,
                        "first_pk": None,
                        "second_pk": None,
                    },
                ),
            }
            for item in geometry["platforms"]
        ]
        object_context = {
            str(item["geometry_id"]): {
                "category": item.get("category"),
                "segment_id": item.get("segment_id"),
                "track": item.get("track")
                or self.segments.get(str(item.get("segment_id")), {}).get("track"),
                "x": item.get("x"),
                "pk": item.get("pk"),
            }
            for item in self.dataset["catalog"]
            if item.get("geometry_id")
        }
        for tag in geometry["tags"]:
            tag_id = str(tag["id"])
            if tag_id in object_context:
                continue
            track_id = next(
                (
                    segment["track"]
                    for segment in self.segments.values()
                    if tag_id.startswith(f"TAG_{segment['track']}_")
                ),
                None,
            )
            if track_id:
                object_context[tag_id] = {
                    "category": "balise",
                    "segment_id": None,
                    "track": track_id,
                    "x": None,
                    "pk": None,
                }
        return {
            **geometry,
            "stopping_points": self.dataset["stopping_points"],
            "calibration_links": self.calibration_links,
            "track_definitions": self.track_definitions,
            "object_context": object_context,
            "mode": "portable",
        }

    def object_detail(self, object_id: str) -> dict[str, Any]:
        normalized = object_id.casefold()
        items = [
            item
            for item in self.dataset["catalog"]
            if str(item.get("id", "")).casefold() == normalized
            or str(item.get("geometry_id", "")).casefold() == normalized
        ]
        if not items:
            calibration = next(
                (
                    item
                    for item in self.calibration_links
                    if str(item.get("id", "")).casefold() == normalized
                ),
                None,
            )
            if calibration:
                items = [
                    {
                        "id": calibration["id"],
                        "category": "calibration",
                        "source_sheet": calibration.get("source_sheet"),
                        "source_row": calibration.get("source_row"),
                        "attributes": calibration,
                    }
                ]
        if not items:
            track = next(
                (
                    item
                    for item in self.track_definitions
                    if str(item.get("id", "")).casefold() == normalized
                ),
                None,
            )
            if track:
                items = [
                    {
                        "id": track["id"],
                        "category": "track",
                        "source_sheet": track.get("source_sheet"),
                        "source_row": track.get("source_row"),
                        "attributes": track,
                    }
                ]
        result = []
        for item in items:
            sheet = item.get("source_sheet")
            row = item.get("source_row")
            result.append(
                {
                    **item,
                    "source_fields": self._source_fields(str(sheet), int(row))
                    if sheet and row
                    else [],
                }
            )
        return {"id": object_id, "items": result}

    def distance_between(
        self,
        origin_segment_id: str,
        origin_x: float,
        destination_segment_id: str,
        destination_x: float,
    ) -> dict[str, Any]:
        origin = self._segment(origin_segment_id)
        destination = self._segment(destination_segment_id)
        self._validate_x(origin, origin_x)
        self._validate_x(destination, destination_x)
        if origin_segment_id == destination_segment_id:
            direction = "CROISSANT" if destination_x >= origin_x else "DECROISSANT"
            distance = abs(destination_x - origin_x)
            return {
                "possible": True,
                "distance": round(distance, 6),
                "direction": direction,
                "traversed": [
                    self._traversal(origin_segment_id, origin_x, destination_x)
                ],
                "reason": None,
            }

        candidates: list[tuple[float, str, list[str]]] = []
        forward = self._shortest_path(origin_segment_id, destination_segment_id, "next_ids")
        if forward:
            candidates.append(
                (self._path_distance(forward, origin_x, destination_x, True), "CROISSANT", forward)
            )
        reverse = self._shortest_path(
            origin_segment_id, destination_segment_id, "previous_ids"
        )
        if reverse:
            candidates.append(
                (self._path_distance(reverse, origin_x, destination_x, False), "DECROISSANT", reverse)
            )
        if not candidates:
            return {
                "possible": False,
                "distance": None,
                "direction": None,
                "traversed": [],
                "reason": (
                    f"No existe una ruta entre {origin_segment_id} "
                    f"y {destination_segment_id}"
                ),
            }
        distance, direction, path = min(candidates, key=lambda item: item[0])
        traversed: list[dict[str, Any]] = []
        increasing = direction == "CROISSANT"
        for index, segment_id in enumerate(path):
            segment = self._segment(segment_id)
            start = origin_x if index == 0 else (0.0 if increasing else segment["length"])
            end = destination_x if index == len(path) - 1 else (
                segment["length"] if increasing else 0.0
            )
            traversed.append(self._traversal(segment_id, start, end))
        return {
            "possible": True,
            "distance": round(distance, 6),
            "direction": direction,
            "traversed": traversed,
            "reason": None,
        }

    def _definitions(self, table: str) -> list[dict[str, Any]]:
        if table not in {"track_definitions", "platform_definitions"}:
            raise ValueError(table)
        with closing(self._connect()) as database:
            rows = database.execute(
                f"SELECT id, payload FROM {table} ORDER BY rowid"
            ).fetchall()
        return [{"id": row["id"], **json.loads(row["payload"])} for row in rows]

    def _source_fields(self, sheet: str, row_number: int) -> list[dict[str, Any]]:
        with closing(self._connect()) as database:
            rows = database.execute(
                """
                SELECT row_number, values_json
                FROM sheet_rows
                WHERE sheet_name = ? AND row_number IN (1, 2, ?)
                ORDER BY row_number
                """,
                (sheet, row_number),
            ).fetchall()
        values = {row["row_number"]: json.loads(row["values_json"]) for row in rows}
        if row_number < 3 or row_number not in values:
            return []
        first, second = values.get(1, []), values.get(2, [])
        result = []
        for index, value in enumerate(values[row_number]):
            if value in (None, ""):
                continue
            labels = [
                str(header[index])
                for header in (first, second)
                if index < len(header) and header[index] not in (None, "")
            ]
            result.append(
                {
                    "column": index + 1,
                    "label": " / ".join(labels) or f"Columna {index + 1}",
                    "value": value,
                }
            )
        return result

    def _segment(self, segment_id: str) -> dict[str, Any]:
        try:
            return self.segments[segment_id]
        except KeyError as error:
            raise ValueError(f"Segmento desconocido: {segment_id}") from error

    @staticmethod
    def _validate_x(segment: dict[str, Any], value: float) -> None:
        if value < 0 or value > float(segment["length"]):
            raise ValueError(
                f"x={value} esta fuera de {segment['id']}; "
                f"rango permitido: 0..{segment['length']}"
            )

    def _shortest_path(
        self, origin_id: str, destination_id: str, neighbor_key: str
    ) -> list[str] | None:
        queue: list[tuple[float, str, tuple[str, ...]]] = [(0.0, origin_id, (origin_id,))]
        best = {origin_id: 0.0}
        while queue:
            cost, current_id, path = heapq.heappop(queue)
            if current_id == destination_id:
                return list(path)
            if cost > best.get(current_id, float("inf")):
                continue
            current = self._segment(current_id)
            for next_id in current.get(neighbor_key, []):
                if next_id in path:
                    continue
                next_cost = cost + float(current["length"])
                if next_cost < best.get(next_id, float("inf")):
                    best[next_id] = next_cost
                    heapq.heappush(queue, (next_cost, next_id, path + (next_id,)))
        return None

    def _path_distance(
        self, path: list[str], origin_x: float, destination_x: float, increasing: bool
    ) -> float:
        middle = sum(float(self._segment(item)["length"]) for item in path[1:-1])
        if increasing:
            return float(self._segment(path[0])["length"]) - origin_x + middle + destination_x
        return origin_x + middle + float(self._segment(path[-1])["length"]) - destination_x

    @staticmethod
    def _traversal(segment_id: str, start: float, end: float) -> dict[str, Any]:
        return {
            "segment_id": segment_id,
            "x_start": round(start, 6),
            "x_end": round(end, 6),
            "distance": round(abs(end - start), 6),
        }
