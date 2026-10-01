from __future__ import annotations

import json
from datetime import date, datetime
from typing import Any, Iterable, Mapping


def parse_yyyymmdd(value: Any) -> date | None:
    if value is None:
        return None
    try:
        return datetime.strptime(str(value), "%Y%m%d").date()
    except (TypeError, ValueError):
        return None


def flatten_redemption_payload(payload: str | Mapping[str, Any]) -> list[dict[str, Any]]:
    document = json.loads(payload) if isinstance(payload, str) else payload
    member_id = document.get("member_id")
    feed_date = parse_yyyymmdd(document.get("feed_date"))
    rows = []
    for redemption in document.get("redemptions") or []:
        miles = redemption.get("miles_redeemed")
        try:
            miles = int(miles) if miles is not None else None
        except (TypeError, ValueError):
            miles = None
        rows.append(
            {
                "member_id": member_id,
                "feed_date": feed_date,
                "txn_id": redemption.get("txn_id"),
                "txn_date": parse_yyyymmdd(redemption.get("txn_date")),
                "partner": redemption.get("partner"),
                "miles_redeemed": miles,
                "status": redemption.get("status"),
            }
        )
    return rows


def redemption_validation_errors(row: Mapping[str, Any]) -> set[str]:
    errors = set()
    if not row.get("member_id"):
        errors.add("missing_member_id")
    if not row.get("txn_id"):
        errors.add("missing_txn_id")
    if not row.get("partner"):
        errors.add("missing_partner")
    if row.get("feed_date") is None:
        errors.add("invalid_feed_date")
    if row.get("txn_date") is None:
        errors.add("invalid_txn_date")
    if row.get("miles_redeemed") is None:
        errors.add("invalid_miles_redeemed")
    if row.get("status") not in {"COMPLETED", "PENDING"}:
        errors.add("invalid_status")
    return errors


def orphan_redemptions(
    redemptions: Iterable[Mapping[str, Any]], member_ids: set[str]
) -> list[Mapping[str, Any]]:
    return [row for row in redemptions if row.get("member_id") not in member_ids]


def enrich_redemptions(
    redemptions: Iterable[Mapping[str, Any]], members: Iterable[Mapping[str, Any]]
) -> list[dict[str, Any]]:
    profiles = {member.get("member_id"): member for member in members}
    enriched = []
    for redemption in redemptions:
        profile = profiles.get(redemption.get("member_id"), {})
        enriched.append({**redemption, "member_name": profile.get("member_name"), "country": profile.get("country"), "tier": profile.get("tier")})
    return enriched
