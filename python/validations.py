from __future__ import annotations

from collections import Counter
from datetime import date
from typing import Iterable, Mapping


def duplicate_values(rows: Iterable[Mapping[str, str]], field: str) -> set[str]:
    counts = Counter(row.get(field) for row in rows)
    return {value for value, count in counts.items() if value and count > 1}


def missing_fields(row: Mapping[str, object], fields: Iterable[str]) -> set[str]:
    return {
        field
        for field in fields
        if row.get(field) is None or str(row.get(field)).strip() == ""
    }


def invalid_date(value: date | None, as_of: date) -> bool:
    return value is None or value > as_of


def unexpected_country(country: str | None, expected: set[str]) -> bool:
    return country is None or country not in expected
