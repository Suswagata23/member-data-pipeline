USE DATABASE INCUBYTE_DE_ASSESSMENT;

-- Rebuild the relational projection for the loaded batches. The raw feed is
-- retained, so this operation is rerunnable without losing source evidence.
TRUNCATE TABLE TARGET.REDEMPTIONS;

INSERT INTO TARGET.REDEMPTIONS (
    batch_id,
    member_id,
    feed_date,
    txn_id,
    txn_date,
    partner,
    miles_redeemed,
    status,
    raw_feed_load_timestamp
)
SELECT
    feed.batch_id,
    feed.raw_payload:member_id::VARCHAR AS member_id,
    TRY_TO_DATE(feed.raw_payload:feed_date::VARCHAR, 'YYYYMMDD') AS feed_date,
    redemption.value:txn_id::VARCHAR AS txn_id,
    TRY_TO_DATE(redemption.value:txn_date::VARCHAR, 'YYYYMMDD') AS txn_date,
    redemption.value:partner::VARCHAR AS partner,
    TRY_TO_NUMBER(redemption.value:miles_redeemed::VARCHAR) AS miles_redeemed,
    redemption.value:status::VARCHAR AS status,
    feed.load_timestamp AS raw_feed_load_timestamp
FROM RAW.REDEMPTION_FEEDS AS feed,
LATERAL FLATTEN(INPUT => feed.raw_payload:redemptions) AS redemption
WHERE feed.raw_payload IS NOT NULL;

-- Example raw load statement. COPY INTO or a Snowpipe-fed process should
-- provide batch_id/source_file at scale rather than row-by-row application inserts.
-- INSERT INTO RAW.REDEMPTION_FEEDS (batch_id, source_file, raw_payload, raw_payload_text)
-- SELECT '20240115', 'redemptions.json', TRY_PARSE_JSON($1), $1
-- FROM @RAW.REDEMPTION_STAGE (FILE_FORMAT => RAW.JSON_FILE_FORMAT);

-- For assessment flat files using H|... and D|... records, parse the first
-- token into RAW.MEMBER_RECORDS.source_record_type and load only D rows.

-- Enriched query surface. LEFT JOIN intentionally preserves orphan redemptions
-- for investigation instead of deleting them during enrichment.
CREATE OR REPLACE VIEW TARGET.REDEMPTIONS_WITH_MEMBER AS
SELECT
    redemption.member_id,
    member.member_name,
    member.source_country AS country,
    member.tier_code AS tier,
    redemption.txn_id,
    redemption.feed_date,
    redemption.txn_date,
    redemption.partner,
    redemption.miles_redeemed,
    redemption.status,
    redemption.batch_id
FROM TARGET.REDEMPTIONS AS redemption
LEFT JOIN TARGET.CURRENT_MEMBER_RECORDS AS member
    ON redemption.member_id = member.member_id;
