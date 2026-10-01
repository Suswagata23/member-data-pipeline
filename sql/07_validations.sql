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

-- 10. Current-state uniqueness: exactly one selected record per business ID.
SELECT 'DUPLICATE_CURRENT_MEMBER' AS check_name, member_id, COUNT(*) AS record_count
FROM TARGET.CURRENT_MEMBER_RECORDS
GROUP BY member_id
HAVING COUNT(*) > 1;

-- 11. Cross-country target duplication. A non-empty result means the same
-- business member was routed to more than one country target.
WITH target_members AS (
   SELECT member_id, 'IND' AS target_country FROM TARGET.IND_MEMBERS
   UNION ALL
   SELECT member_id, 'USA' AS target_country FROM TARGET.USA_MEMBERS
   UNION ALL
   SELECT member_id, 'AUS' AS target_country FROM TARGET.AUS_MEMBERS
)
SELECT 'MEMBER_IN_MULTIPLE_COUNTRY_TARGETS' AS check_name,
      member_id, COUNT(*) AS target_count,
      LISTAGG(target_country, ',') WITHIN GROUP (ORDER BY target_country) AS target_countries
FROM target_members
GROUP BY member_id
HAVING COUNT(*) > 1;

-- 12. Every target row must agree with its table's country.
SELECT 'TARGET_COUNTRY_MISMATCH' AS check_name, member_id, source_country, 'IND' AS expected_country
FROM TARGET.IND_MEMBERS WHERE source_country <> 'IND'
UNION ALL
SELECT 'TARGET_COUNTRY_MISMATCH', member_id, source_country, 'USA'
FROM TARGET.USA_MEMBERS WHERE source_country <> 'USA'
UNION ALL
SELECT 'TARGET_COUNTRY_MISMATCH', member_id, source_country, 'AUS'
FROM TARGET.AUS_MEMBERS WHERE source_country <> 'AUS';

-- 13. Target IDs must be unique within each country table.
SELECT 'DUPLICATE_TARGET_MEMBER' AS check_name, 'IND' AS target_country, member_id, COUNT(*) AS record_count
FROM TARGET.IND_MEMBERS GROUP BY member_id HAVING COUNT(*) > 1
UNION ALL
SELECT 'DUPLICATE_TARGET_MEMBER', 'USA', member_id, COUNT(*)
FROM TARGET.USA_MEMBERS GROUP BY member_id HAVING COUNT(*) > 1
UNION ALL
SELECT 'DUPLICATE_TARGET_MEMBER', 'AUS', member_id, COUNT(*)
FROM TARGET.AUS_MEMBERS GROUP BY member_id HAVING COUNT(*) > 1;

-- 14. Target coverage must equal the current-member dataset.
WITH target_members AS (
   SELECT member_id FROM TARGET.IND_MEMBERS
   UNION ALL SELECT member_id FROM TARGET.USA_MEMBERS
   UNION ALL SELECT member_id FROM TARGET.AUS_MEMBERS
)
SELECT 'CURRENT_MEMBER_MISSING_FROM_TARGETS' AS check_name, c.member_id
FROM TARGET.CURRENT_MEMBER_RECORDS c
LEFT JOIN target_members t ON t.member_id = c.member_id
WHERE t.member_id IS NULL;

SELECT 'TARGET_MEMBER_WITHOUT_CURRENT_RECORD' AS check_name, t.member_id
FROM (
   SELECT member_id FROM TARGET.IND_MEMBERS
   UNION ALL SELECT member_id FROM TARGET.USA_MEMBERS
   UNION ALL SELECT member_id FROM TARGET.AUS_MEMBERS
) t
LEFT JOIN TARGET.CURRENT_MEMBER_RECORDS c ON c.member_id = t.member_id
WHERE c.member_id IS NULL;

-- 15. The assessment flat-file format can contain H| header rows and D| detail
-- rows. Headers are metadata, never member records.
SELECT 'HEADER_LOADED_AS_MEMBER' AS check_name, source_file, source_row_number, source_member_id
FROM RAW.MEMBER_RECORDS
WHERE source_record_type = 'H';

-- 16. Assessment member IDs are expected to be six digits. The source value is
-- preserved; this query only identifies values such as 22345 and 2256.
SELECT 'UNEXPECTED_MEMBER_ID_FORMAT' AS check_name, member_id
FROM TARGET.CURRENT_MEMBER_RECORDS
WHERE NOT REGEXP_LIKE(member_id, '^[0-9]{6}$');

-- 17. Malformed JSON remains queryable through raw_payload_text.
SELECT 'MALFORMED_REDEMPTION_JSON' AS check_name, batch_id, source_file, raw_payload_text
FROM RAW.REDEMPTION_FEEDS
WHERE raw_payload IS NULL;

SELECT 'MISSING_REDEMPTION_ROOT_FIELD' AS check_name, batch_id, source_file, raw_payload_text
FROM RAW.REDEMPTION_FEEDS
WHERE raw_payload IS NOT NULL
   AND (
         raw_payload:member_id IS NULL
         OR raw_payload:feed_date IS NULL
         OR TYPEOF(raw_payload:redemptions) <> 'ARRAY'
   );

-- 18. Required redemption fields and typed conversion checks.
SELECT 'MISSING_REDEMPTION_MEMBER_ID' AS check_name, batch_id, txn_id
FROM TARGET.REDEMPTIONS
WHERE member_id IS NULL;

SELECT 'MISSING_TXN_ID' AS check_name, batch_id, member_id
FROM TARGET.REDEMPTIONS
WHERE txn_id IS NULL;

SELECT 'MISSING_REDEMPTION_PARTNER' AS check_name, batch_id, member_id, txn_id
FROM TARGET.REDEMPTIONS
WHERE partner IS NULL;

SELECT 'INVALID_REDEMPTION_DATE' AS check_name, batch_id, member_id, txn_id
FROM TARGET.REDEMPTIONS
WHERE feed_date IS NULL OR txn_date IS NULL;

SELECT 'TXN_AFTER_FEED_DATE' AS check_name, batch_id, member_id, txn_id, txn_date, feed_date
FROM TARGET.REDEMPTIONS
WHERE txn_date > feed_date;

SELECT 'INVALID_MILES_REDEEMED' AS check_name, batch_id, member_id, txn_id, miles_redeemed
FROM TARGET.REDEMPTIONS
WHERE miles_redeemed IS NULL OR miles_redeemed < 0;

SELECT 'INVALID_REDEMPTION_STATUS' AS check_name, batch_id, member_id, txn_id, status
FROM TARGET.REDEMPTIONS
WHERE status NOT IN ('COMPLETED', 'PENDING') OR status IS NULL;

-- 19. Transaction IDs are the redemption business key in the supplied contract.
SELECT 'DUPLICATE_TXN_ID' AS check_name, txn_id, COUNT(*) AS record_count
FROM TARGET.REDEMPTIONS
WHERE txn_id IS NOT NULL
GROUP BY txn_id
HAVING COUNT(*) > 1;

-- 20. Duplicate logical records are retained and reported separately from
-- duplicate IDs because a feed can repeat the same transaction payload.
SELECT 'DUPLICATE_LOGICAL_REDEMPTION' AS check_name,
      member_id, txn_id, txn_date, partner, miles_redeemed, status,
      COUNT(*) AS record_count
FROM TARGET.REDEMPTIONS
GROUP BY member_id, txn_id, txn_date, partner, miles_redeemed, status
HAVING COUNT(*) > 1;

-- 21. Orphan redemptions remain in TARGET.REDEMPTIONS for investigation.
SELECT 'ORPHAN_REDEMPTION_MEMBER' AS check_name,
      redemption.batch_id, redemption.member_id, redemption.txn_id
FROM TARGET.REDEMPTIONS AS redemption
LEFT JOIN TARGET.CURRENT_MEMBER_RECORDS AS member
   ON redemption.member_id = member.member_id
WHERE member.member_id IS NULL;
