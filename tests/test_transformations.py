from datetime import date

from python.transformations import calculate_age, calculate_stale_member, parse_source_date


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
