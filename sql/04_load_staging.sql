USE DATABASE INCUBYTE_DE_ASSESSMENT;

-- Reloadable staging build. The delete makes reruns idempotent for the raw snapshot.
TRUNCATE TABLE STAGING.MEMBER_RECORDS;

INSERT INTO STAGING.MEMBER_RECORDS (
    member_key,
    source_country,
    source_file,
    source_row_number,
    source_member_id,
    member_name,
    tier_code,
    individual_or_corporate,
    dob_raw,
    dob,
    enrollment_date_raw,
    enrollment_date,
    flight_date_raw,
    flight_date,
    dob_is_valid,
    enrollment_date_is_valid,
    flight_date_is_valid,
    calculation_date,
    age,
    stale_member,
    load_timestamp
)
WITH normalized AS (
    SELECT
        source_country,
        source_file,
        source_row_number,
        NULLIF(TRIM(source_member_id), '') AS source_member_id,
        NULLIF(TRIM(member_name), '') AS member_name,
        NULLIF(TRIM(dob_raw), '') AS dob_raw,
        NULLIF(TRIM(tier_code), '') AS tier_code,
        NULLIF(TRIM(enrollment_date_raw), '') AS enrollment_date_raw,
        NULLIF(TRIM(individual_or_corporate), '') AS individual_or_corporate,
        NULLIF(TRIM(flight_date_raw), '') AS flight_date_raw,
        load_timestamp
    FROM RAW.MEMBER_RECORDS
), typed AS (
    SELECT
        normalized.*,
        CASE source_country
            WHEN 'IND' THEN TRY_TO_DATE(NULLIF(UPPER(dob_raw), 'NULL'), 'MM/DD/YYYY')
            WHEN 'USA' THEN TRY_TO_DATE(LPAD(NULLIF(UPPER(dob_raw), 'NULL'), 8, '0'), 'MMDDYYYY')
            WHEN 'AUS' THEN TRY_TO_DATE(NULLIF(UPPER(dob_raw), 'NULL'), 'YYYY-MM-DD')
        END AS dob,
        CASE source_country
            WHEN 'IND' THEN TRY_TO_DATE(NULLIF(UPPER(enrollment_date_raw), 'NULL'), 'MM/DD/YYYY')
            WHEN 'USA' THEN TRY_TO_DATE(LPAD(NULLIF(UPPER(enrollment_date_raw), 'NULL'), 8, '0'), 'MMDDYYYY')
            WHEN 'AUS' THEN TRY_TO_DATE(NULLIF(UPPER(enrollment_date_raw), 'NULL'), 'YYYY-MM-DD')
        END AS enrollment_date,
        CASE source_country
            WHEN 'IND' THEN TRY_TO_DATE(NULLIF(UPPER(flight_date_raw), 'NULL'), 'MM/DD/YYYY')
            WHEN 'USA' THEN TRY_TO_DATE(LPAD(NULLIF(UPPER(flight_date_raw), 'NULL'), 8, '0'), 'MMDDYYYY')
            WHEN 'AUS' THEN TRY_TO_DATE(NULLIF(UPPER(flight_date_raw), 'NULL'), 'YYYY-MM-DD')
        END AS flight_date
    FROM normalized
), derived AS (
    SELECT
        typed.*,
        CURRENT_DATE() AS calculation_date
    FROM typed
)
SELECT
    source_country || ':' || COALESCE(source_member_id, '<NULL>') AS member_key,
    source_country,
    source_file,
    source_row_number,
    source_member_id,
    member_name,
    tier_code,
    individual_or_corporate,
    dob_raw,
    dob,
    enrollment_date_raw,
    enrollment_date,
    flight_date_raw,
    flight_date,
    dob IS NOT NULL AS dob_is_valid,
    enrollment_date IS NOT NULL AS enrollment_date_is_valid,
    flight_date IS NOT NULL AS flight_date_is_valid,
    calculation_date,
    CASE
        WHEN dob IS NULL OR dob > calculation_date THEN NULL
        ELSE DATEDIFF(year, dob, calculation_date)
             - IFF(
                 DATE_FROM_PARTS(
                     YEAR(calculation_date),
                     MONTH(dob),
                     LEAST(DAY(dob), DAY(LAST_DAY(DATE_FROM_PARTS(YEAR(calculation_date), MONTH(dob), 1))))
                 ) > calculation_date,
                 1,
                 0
             )
    END AS age,
    CASE
        WHEN flight_date IS NULL OR flight_date > calculation_date THEN NULL
        ELSE DATEDIFF(day, flight_date, calculation_date) > 90
    END AS stale_member,
    load_timestamp
FROM derived;
