from __future__ import annotations

from datetime import date, datetime


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
