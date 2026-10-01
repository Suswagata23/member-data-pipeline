import json
from datetime import date

from python.redemptions import (
    enrich_redemptions,
    flatten_redemption_payload,
    orphan_redemptions,
    redemption_validation_errors,
)


PAYLOAD = {
    "member_id": "223457",
    "feed_date": "20240115",
    "redemptions": [
        {
            "txn_id": "RX10091",
            "txn_date": "20240110",
            "partner": "AeroLink",
            "miles_redeemed": 12000,
            "status": "COMPLETED",
        },
        {
            "txn_id": "RX10092",
            "txn_date": "20240113",
            "partner": "SkyPoints",
            "miles_redeemed": 5000,
            "status": "PENDING",
        },
    ],
}


def test_json_root_and_member_feed_date_are_parsed():
    rows = flatten_redemption_payload(json.dumps(PAYLOAD))

    assert rows[0]["member_id"] == "223457"
    assert rows[0]["feed_date"] == date(2024, 1, 15)


def test_redemption_array_flattens_to_one_row_per_transaction():
    rows = flatten_redemption_payload(PAYLOAD)

    assert len(rows) == 2
    assert {row["txn_id"] for row in rows} == {"RX10091", "RX10092"}


def test_transaction_fields_are_typed_and_status_is_extracted():
    rows = flatten_redemption_payload(PAYLOAD)

    assert rows[0]["txn_date"] == date(2024, 1, 10)
    assert rows[0]["partner"] == "AeroLink"
    assert rows[0]["miles_redeemed"] == 12000
    assert rows[0]["status"] == "COMPLETED"
    assert rows[1]["status"] == "PENDING"


def test_missing_optional_partner_is_preserved_as_null():
    payload = {**PAYLOAD, "redemptions": [{**PAYLOAD["redemptions"][0], "partner": None}]}

    assert flatten_redemption_payload(payload)[0]["partner"] is None


def test_missing_required_fields_are_reported():
    row = flatten_redemption_payload(
        {"member_id": None, "feed_date": "20240115", "redemptions": [{"txn_id": None, "txn_date": "20240110", "partner": "AeroLink", "miles_redeemed": 1, "status": "COMPLETED"}]}
    )[0]

    assert redemption_validation_errors(row) == {"missing_member_id", "missing_txn_id"}


def test_missing_partner_is_reported_as_a_required_transaction_field():
    row = flatten_redemption_payload(
        {"member_id": "223457", "feed_date": "20240115", "redemptions": [{"txn_id": "RX1", "txn_date": "20240110", "partner": None, "miles_redeemed": 1, "status": "COMPLETED"}]}
    )[0]

    assert redemption_validation_errors(row) == {"missing_partner"}


def test_invalid_date_and_numeric_values_are_reported():
    row = flatten_redemption_payload(
        {"member_id": "223457", "feed_date": "20241315", "redemptions": [{"txn_id": "RX1", "txn_date": "bad", "partner": "AeroLink", "miles_redeemed": "not-a-number", "status": "COMPLETED"}]}
    )[0]

    assert redemption_validation_errors(row) == {"invalid_feed_date", "invalid_txn_date", "invalid_miles_redeemed"}


def test_duplicate_transaction_ids_and_orphan_members_can_be_detected():
    rows = flatten_redemption_payload(PAYLOAD)
    duplicate_ids = [row["txn_id"] for row in rows + [rows[0]]]

    assert duplicate_ids.count("RX10091") == 2
    assert orphan_redemptions(rows, {"999999"}) == rows


def test_redemptions_join_to_current_member_profile():
    rows = flatten_redemption_payload(PAYLOAD)
    members = [{"member_id": "223457", "member_name": "Elena", "country": "IND", "tier": "GLD"}]

    enriched = enrich_redemptions(rows, members)

    assert enriched[0]["member_name"] == "Elena"
    assert enriched[0]["country"] == "IND"
    assert enriched[0]["tier"] == "GLD"
