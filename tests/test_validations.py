from datetime import date

from python.validations import duplicate_values, invalid_date, missing_fields, unexpected_country


def test_duplicate_member_ids_are_reported():
    rows = [{"member_id": "1"}, {"member_id": "1"}, {"member_id": "2"}]

    assert duplicate_values(rows, "member_id") == {"1"}


def test_missing_mandatory_fields_are_reported():
    row = {"member_id": "1", "dob": None, "country": "IND", "flight_date": "2022-06-15"}

    assert missing_fields(row, ("member_id", "dob", "country", "flight_date")) == {"dob"}


def test_invalid_dates_include_null_and_future_values():
    as_of = date(2026, 10, 1)

    assert invalid_date(None, as_of) is True
    assert invalid_date(date(2026, 10, 2), as_of) is True
    assert invalid_date(date(2026, 9, 30), as_of) is False


def test_unexpected_countries_are_reported():
    expected = {"IND", "USA", "AUS"}

    assert unexpected_country("GBR", expected) is True
    assert unexpected_country(None, expected) is True
    assert unexpected_country("IND", expected) is False
