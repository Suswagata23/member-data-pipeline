USE DATABASE INCUBYTE_DE_ASSESSMENT;

-- The supplied files repeat IDs across IND, USA, and AUS. The assessment's
-- movement rule therefore treats source_member_id as the business member ID.
-- This assumption must be replaced if a global member identifier is supplied.
TRUNCATE TABLE TARGET.IND_MEMBERS;
TRUNCATE TABLE TARGET.USA_MEMBERS;
TRUNCATE TABLE TARGET.AUS_MEMBERS;
TRUNCATE TABLE TARGET.CURRENT_MEMBER_RECORDS;

INSERT INTO TARGET.CURRENT_MEMBER_RECORDS (
    member_id,
    source_country,
    source_file,
    source_row_number,
    source_member_id,
    member_name,
    tier_code,
    individual_or_corporate,
    dob,
    enrollment_date,
    flight_date,
    age,
    stale_member,
    calculation_date,
    load_timestamp,
    selection_reason
)
WITH ranked AS (
    SELECT
        source_member_id AS member_id,
        source_country,
        source_file,
        source_row_number,
        source_member_id,
        member_name,
        tier_code,
        individual_or_corporate,
        dob,
        enrollment_date,
        flight_date,
        age,
        stale_member,
        calculation_date,
        load_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY source_member_id
            ORDER BY
                flight_date DESC NULLS LAST,
                load_timestamp DESC NULLS LAST,
                source_file ASC,
                source_row_number ASC,
                source_country ASC
        ) AS record_rank
    FROM STAGING.MEMBER_RECORDS
    WHERE source_member_id IS NOT NULL
)
SELECT
    member_id,
    source_country,
    source_file,
    source_row_number,
    source_member_id,
    member_name,
    tier_code,
    individual_or_corporate,
    dob,
    enrollment_date,
    flight_date,
    age,
    stale_member,
    calculation_date,
    load_timestamp,
    'LATEST_FLIGHT_DATE; METADATA_ORDER_FOR_TIES' AS selection_reason
FROM ranked
WHERE record_rank = 1;

-- Route only the already-selected current rows. No target reads RAW directly.
INSERT INTO TARGET.IND_MEMBERS SELECT * FROM TARGET.CURRENT_MEMBER_RECORDS WHERE source_country = 'IND';
INSERT INTO TARGET.USA_MEMBERS SELECT * FROM TARGET.CURRENT_MEMBER_RECORDS WHERE source_country = 'USA';
INSERT INTO TARGET.AUS_MEMBERS SELECT * FROM TARGET.CURRENT_MEMBER_RECORDS WHERE source_country = 'AUS';
