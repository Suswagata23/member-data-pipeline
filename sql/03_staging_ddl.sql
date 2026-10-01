USE DATABASE INCUBYTE_DE_ASSESSMENT;

CREATE TABLE IF NOT EXISTS STAGING.MEMBER_RECORDS (
    member_key VARCHAR NOT NULL,
    source_country VARCHAR NOT NULL,
    source_file VARCHAR NOT NULL,
    source_row_number NUMBER,
    source_member_id VARCHAR,
    member_name VARCHAR,
    tier_code VARCHAR,
    individual_or_corporate VARCHAR,
    dob_raw VARCHAR,
    dob DATE,
    enrollment_date_raw VARCHAR,
    enrollment_date DATE,
    flight_date_raw VARCHAR,
    flight_date DATE,
    dob_is_valid BOOLEAN,
    enrollment_date_is_valid BOOLEAN,
    flight_date_is_valid BOOLEAN,
    calculation_date DATE NOT NULL,
    age NUMBER,
    stale_member BOOLEAN,
    load_timestamp TIMESTAMP_NTZ
);

COMMENT ON TABLE STAGING.MEMBER_RECORDS IS
    'Typed member records with source-quality flags and assessment-derived fields.';
COMMENT ON COLUMN STAGING.MEMBER_RECORDS.member_key IS
    'Technical key source_country:source_member_id; source IDs repeat across country files.';
COMMENT ON COLUMN STAGING.MEMBER_RECORDS.stale_member IS
    'TRUE only when flight_date is more than 90 days before calculation_date; NULL for null/future dates.';
