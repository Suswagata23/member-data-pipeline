USE DATABASE INCUBYTE_DE_ASSESSMENT;

-- One append-only landing contract for the three observed member feeds.
-- Raw date columns remain VARCHAR so malformed source values remain queryable.
CREATE TABLE IF NOT EXISTS RAW.MEMBER_RECORDS (
    source_country VARCHAR NOT NULL,
    source_file VARCHAR NOT NULL,
    source_row_number NUMBER,
    source_member_id VARCHAR,
    member_name VARCHAR,
    dob_raw VARCHAR,
    tier_code VARCHAR,
    enrollment_date_raw VARCHAR,
    individual_or_corporate VARCHAR,
    flight_date_raw VARCHAR,
    load_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

COMMENT ON TABLE RAW.MEMBER_RECORDS IS
    'Source-preserving member landing table. Country is derived from the input filename.';
COMMENT ON COLUMN RAW.MEMBER_RECORDS.source_country IS
    'Country inferred from the supplied filename: IND, USA, or AUS.';
COMMENT ON COLUMN RAW.MEMBER_RECORDS.source_member_id IS
    'Original ID or Unique ID value, retained as text because source identity is not globally unique.';
