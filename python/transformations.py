from __future__ import annotations

from collections import defaultdict
from datetime import date, datetime
from typing import Iterable, Mapping


def calculate_age(date_of_birth: date | None, as_of: date) -> int | None:
    if date_of_birth is None:
        return None
    return as_of.year - date_of_birth.year - (
        (as_of.month, as_of.day) < (date_of_birth.month, date_of_birth.day)
    )


def calculate_stale_member(flight_date: date | None, as_of: date) -> bool | None:
    if flight_date is None or flight_date > as_of:
        return None
    return (as_of - flight_date).days > 90


def parse_source_date(value: str | None, country: str) -> date | None:
    if value is None or value.strip().upper() == "NULL":
        return None

    value = value.strip()
    formats = {
        "IND": ("%m/%d/%Y",),
        "USA": ("%m%d%Y",),
        "AUS": ("%Y-%m-%d",),
    }
    for date_format in formats.get(country, ()):
        try:
            normalized = value.zfill(8) if country == "USA" else value
            return datetime.strptime(normalized, date_format).date()
        except ValueError:
            continue
    return None


def select_latest_records(rows: Iterable[Mapping[str, object]]) -> list[Mapping[str, object]]:
    """Select one current row per source member ID.

    Flight date is the business ordering. Load timestamp, source file, source
    row, and country provide deterministic metadata ordering for equal dates.
    """
    grouped: dict[object, list[Mapping[str, object]]] = defaultdict(list)
    for row in rows:
        member_id = row.get("source_member_id")
        if member_id is not None:
            grouped[member_id].append(row)

    selected = []
    for member_rows in grouped.values():
        ordered = sorted(
            member_rows,
            key=lambda row: (
                -(row.get("flight_date") or date.min).toordinal(),
                -(
                    (row.get("load_timestamp") or datetime.min).toordinal() * 86400
                    + (row.get("load_timestamp") or datetime.min).hour * 3600
                    + (row.get("load_timestamp") or datetime.min).minute * 60
                    + (row.get("load_timestamp") or datetime.min).second
                ),
                str(row.get("source_file") or ""),
                int(row.get("source_row_number") or 0),
                str(row.get("source_country") or ""),
            ),
        )
        selected.append(ordered[0])
    return selected


def route_current_records(rows: Iterable[Mapping[str, object]]) -> dict[str, list[Mapping[str, object]]]:
    targets = {"IND": [], "USA": [], "AUS": []}
    for row in rows:
        country = row.get("source_country")
        if country in targets:
            targets[country].append(row)
    return targets
