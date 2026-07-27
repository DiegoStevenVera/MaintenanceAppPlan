import math
import re
import unicodedata
from datetime import UTC, date, datetime, time, timedelta
from decimal import Decimal
from typing import Any

DATE_FORMATS = (
    "%d/%m/%Y",
    "%Y-%m-%d",
    "%d-%m-%Y",
    "%m/%y",
)
DATETIME_FORMATS = (
    "%Y-%m-%dT%H:%M:%S",
    "%Y-%m-%d %H:%M:%S",
    "%d/%m/%Y %H:%M:%S",
    "%d/%m/%Y  %H:%M:%S",
    "%d/%m/%Y %H:%M",
    "%d/%m/%Y  %H:%M",
    "%a %b %d %Y %H:%M:%S GMT%z",
)
TIME_FORMATS = ("%H:%M:%S", "%H:%M")


def is_blank(value: Any) -> bool:
    if value is None:
        return True
    if isinstance(value, float) and math.isnan(value):
        return True
    return isinstance(value, str) and not value.strip()


def text(value: Any, *, none_values: tuple[str, ...] = ("-", "NA", "N/A")) -> str | None:
    if is_blank(value):
        return None
    result = str(value).strip()
    if result.casefold() in {item.casefold() for item in none_values}:
        return None
    return result


def required_text(value: Any, field: str) -> str:
    result = text(value, none_values=())
    if result is None:
        raise ValueError(f"{field} is required")
    return result


def identifier(value: Any) -> str:
    if is_blank(value):
        raise ValueError("Source primary key is blank")
    if isinstance(value, bool):
        return "1" if value else "0"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    return str(value).strip()


def integer(value: Any) -> int | None:
    if is_blank(value):
        return None
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, (int, float, Decimal)):
        return int(value)
    cleaned = str(value).strip().replace(",", ".")
    return int(float(cleaned))


def optional_integer(value: Any) -> int | None:
    try:
        return integer(value)
    except (TypeError, ValueError):
        return None


def number(value: Any) -> float | None:
    if is_blank(value):
        return None
    if isinstance(value, (int, float, Decimal)):
        return float(value)
    return float(str(value).strip().replace(",", "."))


def boolean(value: Any, *, default: bool = False) -> bool:
    if is_blank(value):
        return default
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value != 0
    normalized = normalize_key(value)
    if normalized in {"1", "si", "sí", "yes", "true", "verdadero"}:
        return True
    if normalized in {"0", "no", "false", "falso"}:
        return False
    return default


def parse_date(value: Any) -> date | None:
    if is_blank(value):
        return None
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    raw = str(value).strip()
    raw = re.sub(r"\s+\([^)]*\)$", "", raw)
    for date_format in DATE_FORMATS:
        try:
            return datetime.strptime(raw, date_format).date()  # noqa: DTZ007
        except ValueError:
            continue
    for datetime_format in DATETIME_FORMATS:
        try:
            return datetime.strptime(raw, datetime_format).date()  # noqa: DTZ007
        except ValueError:
            continue
    raise ValueError(f"Unsupported date value: {value!r}")


def parse_time(value: Any) -> time | None:
    if is_blank(value):
        return None
    if isinstance(value, datetime):
        return value.time().replace(microsecond=0)
    if isinstance(value, time):
        return value.replace(microsecond=0)
    if isinstance(value, (int, float)) and 0 <= float(value) < 1:
        seconds = round(float(value) * 24 * 60 * 60)
        return (datetime.min.replace(tzinfo=UTC) + timedelta(seconds=seconds)).time()
    raw = str(value).strip()
    raw = re.sub(r"\s+\([^)]*\)$", "", raw)
    for time_format in TIME_FORMATS:
        try:
            return datetime.strptime(raw, time_format).time()  # noqa: DTZ007
        except ValueError:
            continue
    raise ValueError(f"Unsupported time value: {value!r}")


def parse_datetime(value: Any) -> datetime | None:
    if is_blank(value):
        return None
    if isinstance(value, datetime):
        return value
    if isinstance(value, date):
        return datetime.combine(value, time.min)
    raw = str(value).strip()
    raw = re.sub(r"\s+\([^)]*\)$", "", raw)
    for datetime_format in DATETIME_FORMATS:
        try:
            return datetime.strptime(raw, datetime_format)  # noqa: DTZ007
        except ValueError:
            continue
    parsed_date = parse_date(raw)
    return datetime.combine(parsed_date, time.min) if parsed_date else None


def combine_date_time(date_value: Any, time_value: Any) -> datetime | None:
    parsed_date = parse_date(date_value)
    if parsed_date is None:
        return None
    return datetime.combine(parsed_date, parse_time(time_value) or time.min)


def optional_combine_date_time(date_value: Any, time_value: Any) -> datetime | None:
    try:
        return combine_date_time(date_value, time_value)
    except ValueError:
        return None


def duration_hours(value: Any) -> float | None:
    if is_blank(value):
        return None
    if isinstance(value, timedelta):
        return value.total_seconds() / 3600
    if isinstance(value, (int, float)):
        numeric = float(value)
        return numeric * 24 if 0 <= numeric < 1 else numeric
    raw = str(value).strip()
    match = re.fullmatch(r"(\d+):(\d{2})", raw)
    if match:
        return int(match.group(1)) + int(match.group(2)) / 60
    return number(raw)


def normalize_key(value: Any) -> str:
    raw = "" if value is None else str(value).strip().casefold()
    decomposed = unicodedata.normalize("NFKD", raw)
    without_marks = "".join(character for character in decomposed if not unicodedata.combining(character))
    return re.sub(r"\s+", " ", without_marks)


def split_people(value: Any) -> list[str]:
    raw = text(value)
    if raw is None:
        return []
    return [item.strip() for item in raw.split(";") if item.strip()]


def json_value(value: Any) -> Any:
    if isinstance(value, (date, datetime, time)):
        return value.isoformat()
    if isinstance(value, Decimal):
        return str(value)
    if isinstance(value, float) and math.isnan(value):
        return None
    return value
