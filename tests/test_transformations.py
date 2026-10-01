from datetime import date, datetime

from python.transformations import (
    calculate_age,
    calculate_stale_member,
    parse_source_date,
    route_current_records,
    select_latest_records,
)


def test_age_is_birthday_aware_before_and_on_birthday():
    dob = date(1998, 10, 2)

    assert calculate_age(dob, date(2026, 10, 1)) == 27
    assert calculate_age(dob, date(2026, 10, 2)) == 28


def test_stale_member_requires_more_than_90_days():
    as_of = date(2026, 10, 1)

    assert calculate_stale_member(date(2026, 7, 3), as_of) is False
    assert calculate_stale_member(date(2026, 7, 2), as_of) is True


def test_null_and_future_flight_dates_are_not_classified_as_stale():
    as_of = date(2026, 10, 1)

    assert calculate_stale_member(None, as_of) is None
    assert calculate_stale_member(date(2026, 10, 2), as_of) is None


def test_source_date_formats_match_the_actual_files():
    assert parse_source_date("12/1/1998", "IND") == date(1998, 12, 1)
    assert parse_source_date("6152022", "USA") == date(2022, 6, 15)
    assert parse_source_date("2022-08-01", "AUS") == date(2022, 8, 1)
    assert parse_source_date("2021-13-13", "AUS") is None
    assert parse_source_date("NULL", "AUS") is None


def test_latest_record_wins_for_one_member_and_same_country_duplicates():
    rows = [
        {"source_member_id": "1", "source_country": "IND", "flight_date": date(2022, 1, 1)},
        {"source_member_id": "1", "source_country": "IND", "flight_date": date(2022, 6, 15)},
    ]

    assert select_latest_records(rows) == [rows[1]]


def test_latest_record_wins_when_member_moves_through_three_countries():
    rows = [
        {"source_member_id": "1", "source_country": "IND", "flight_date": date(2022, 6, 15)},
        {"source_member_id": "1", "source_country": "AUS", "flight_date": date(2022, 8, 1)},
        {"source_member_id": "1", "source_country": "USA", "flight_date": date(2022, 8, 20)},
    ]

    assert select_latest_records(rows)[0]["source_country"] == "USA"


def test_equal_business_dates_use_ingestion_and_source_metadata_tie_breakers():
    rows = [
        {
            "source_member_id": "1",
            "source_country": "IND",
            "source_file": "IND(in).csv",
            "source_row_number": 2,
            "flight_date": date(2022, 8, 20),
            "load_timestamp": datetime(2026, 10, 1, 10),
        },
        {
            "source_member_id": "1",
            "source_country": "USA",
            "source_file": "USA(in).csv",
            "source_row_number": 2,
            "flight_date": date(2022, 8, 20),
            "load_timestamp": datetime(2026, 10, 1, 10),
        },
    ]

    assert select_latest_records(rows)[0]["source_country"] == "IND"


def test_equal_dates_without_source_sequence_use_documented_country_fallback():
    rows = [
        {"source_member_id": "1", "source_country": "USA", "flight_date": date(2022, 8, 20)},
        {"source_member_id": "1", "source_country": "IND", "flight_date": date(2022, 8, 20)},
    ]

    assert select_latest_records(rows)[0]["source_country"] == "IND"


def test_current_member_is_routed_to_one_country_target():
    current = select_latest_records(
        [
            {"source_member_id": "1", "source_country": "IND", "flight_date": date(2022, 1, 1)},
            {"source_member_id": "1", "source_country": "USA", "flight_date": date(2022, 8, 20)},
        ]
    )

    targets = route_current_records(current)
    populated_targets = [country for country, records in targets.items() if records]

    assert populated_targets == ["USA"]


def test_null_flight_date_loses_to_a_valid_date_and_null_only_is_retained():
    dated = {"source_member_id": "1", "flight_date": date(2022, 1, 1)}
    undated = {"source_member_id": "2", "flight_date": None}

    selected = select_latest_records([dated, undated])

    assert dated in selected
    assert undated in selected
