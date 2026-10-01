USE DATABASE INCUBYTE_DE_ASSESSMENT;

-- Current state is materialized once before routing to country targets.
CREATE TABLE IF NOT EXISTS TARGET.CURRENT_MEMBER_RECORDS (
    member_id VARCHAR NOT NULL,
    source_country VARCHAR NOT NULL,
    source_file VARCHAR NOT NULL,
    source_row_number NUMBER,
    source_member_id VARCHAR NOT NULL,
    member_name VARCHAR,
    tier_code VARCHAR,
    individual_or_corporate VARCHAR,
    dob DATE,
    enrollment_date DATE,
    flight_date DATE,
    age NUMBER,
    stale_member BOOLEAN,
    calculation_date DATE NOT NULL,
    load_timestamp TIMESTAMP_NTZ,
    selection_reason VARCHAR NOT NULL
);

-- These are the only countries observed in the supplied inputs.
CREATE TABLE IF NOT EXISTS TARGET.IND_MEMBERS LIKE TARGET.CURRENT_MEMBER_RECORDS;
CREATE TABLE IF NOT EXISTS TARGET.USA_MEMBERS LIKE TARGET.CURRENT_MEMBER_RECORDS;
CREATE TABLE IF NOT EXISTS TARGET.AUS_MEMBERS LIKE TARGET.CURRENT_MEMBER_RECORDS;

COMMENT ON TABLE TARGET.CURRENT_MEMBER_RECORDS IS
    'One latest member record per source_member_id, before country routing.';
COMMENT ON COLUMN TARGET.CURRENT_MEMBER_RECORDS.selection_reason IS
    'Latest flight date; ingestion/source metadata resolves equal-date records.';

CREATE TABLE IF NOT EXISTS TARGET.REDEMPTIONS (
    batch_id VARCHAR NOT NULL,
    member_id VARCHAR,
    feed_date DATE,
    txn_id VARCHAR,
    txn_date DATE,
    partner VARCHAR,
    miles_redeemed NUMBER,
    status VARCHAR,
    raw_feed_load_timestamp TIMESTAMP_NTZ,
    flattened_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

COMMENT ON TABLE TARGET.REDEMPTIONS IS
    'One typed relational row per element of the redemption JSON redemptions array.';
