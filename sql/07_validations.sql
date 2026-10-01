USE DATABASE INCUBYTE_DE_ASSESSMENT;

-- Each query returns failing records or diagnostic counts. A zero-row result means no failures.

-- 1. Missing source identity and required landing metadata.
SELECT 'MISSING_SOURCE_ID' AS check_name, source_country, source_file, source_row_number, source_member_id
FROM RAW.MEMBER_RECORDS
WHERE source_country IS NULL OR source_member_id IS NULL;

-- 2. Missing member attributes. DOB is required by the assessment, so the USA feed
-- intentionally appears here because it does not contain a DOB column.
SELECT 'MISSING_MEMBER_ATTRIBUTE' AS check_name, member_key, source_country,
       source_member_id, member_name, tier_code, dob, flight_date
FROM STAGING.MEMBER_RECORDS
WHERE member_name IS NULL
   OR tier_code IS NULL
   OR dob IS NULL
   OR flight_date IS NULL;

-- 3. Invalid source dates retained by the staging validity flags.
SELECT 'INVALID_DATE' AS check_name, member_key, source_country,
       dob_raw, enrollment_date_raw, flight_date_raw,
       dob_is_valid, enrollment_date_is_valid, flight_date_is_valid
FROM STAGING.MEMBER_RECORDS
WHERE NOT dob_is_valid
   OR NOT enrollment_date_is_valid
   OR NOT flight_date_is_valid;

-- 4. Business date rules.
SELECT 'FUTURE_DOB' AS check_name, member_key, dob, calculation_date
FROM STAGING.MEMBER_RECORDS
WHERE dob > calculation_date;

SELECT 'FUTURE_FLIGHT_DATE' AS check_name, member_key, flight_date, calculation_date
FROM STAGING.MEMBER_RECORDS
WHERE flight_date > calculation_date;

-- 5. Unreasonable ages. This is preventive because no such issue is present
-- in the supplied valid DOB values.
SELECT 'UNREASONABLE_AGE' AS check_name, member_key, dob, age
FROM STAGING.MEMBER_RECORDS
WHERE age IS NOT NULL
  AND (age < 0 OR age > 120);

-- 6. Country values are derived from filenames and must remain within the
-- observed assessment set until a reference-country table exists.
SELECT 'UNEXPECTED_COUNTRY' AS check_name, member_key, source_country
FROM STAGING.MEMBER_RECORDS
WHERE source_country IS NULL
   OR source_country NOT IN ('IND', 'USA', 'AUS');

-- 7. Duplicate technical keys within the raw/staging load.
SELECT 'DUPLICATE_MEMBER_KEY' AS check_name, member_key, COUNT(*) AS record_count
FROM STAGING.MEMBER_RECORDS
GROUP BY member_key
HAVING COUNT(*) > 1;

-- 8. Exact duplicate source records, checked separately from duplicate IDs.
SELECT 'DUPLICATE_SOURCE_RECORD' AS check_name,
       source_country, source_member_id, member_name, dob_raw,
       tier_code, enrollment_date_raw, individual_or_corporate, flight_date_raw,
       COUNT(*) AS record_count
FROM RAW.MEMBER_RECORDS
GROUP BY source_country, source_member_id, member_name, dob_raw,
         tier_code, enrollment_date_raw, individual_or_corporate, flight_date_raw
HAVING COUNT(*) > 1;

-- 9. Numeric IDs repeat across countries in the supplied files. This is a
-- diagnostic, not a failure, until a global member identity is provided.
SELECT 'CROSS_COUNTRY_SOURCE_ID_REUSE' AS check_name,
       source_member_id, COUNT(DISTINCT source_country) AS country_count
FROM RAW.MEMBER_RECORDS
WHERE source_member_id IS NOT NULL
GROUP BY source_member_id
HAVING COUNT(DISTINCT source_country) > 1;

-- 10. Current-state/latest-record validation is intentionally deferred until
-- the country movement and target-table phase.
