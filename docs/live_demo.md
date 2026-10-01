# Live Demo Guide

This sequence is designed for a 5-10 minute interview demonstration. Snowflake execution requires a configured connection and loaded source data; the repository currently validates SQL statically and runs the Python tests locally.

## 1. Show the source data

**Show/run:** Open `IND(in).csv`, `USA(in).csv`, and `AUS.xlsx`. Point out the different headers, date formats, missing USA DOB, and the Australia invalid enrollment date.

**Expected result:** The sources contain three rows each. Country is inferred from the filenames because there is no country column.

**Explain:** Raw ingestion preserves source values and adds source country, filename, row number, and load metadata. It does not silently repair bad input.

## 2. Show the raw table design

**Run/show:** `sql/02_raw_ddl.sql`, then:

```sql
SELECT * FROM RAW.MEMBER_RECORDS;
SELECT batch_id, source_file, raw_payload, raw_payload_text
FROM RAW.REDEMPTION_FEEDS;
```

**Expected result:** Member raw dates remain text. Redemption payloads are retained as VARIANT plus original text.

**Explain:** RAW is the replay and audit boundary. Malformed JSON remains available through `raw_payload_text`.

## 3. Show the staging transformation

**Run/show:** `sql/03_staging_ddl.sql` and `sql/04_load_staging.sql`.

```sql
SELECT source_country, source_member_id, dob, enrollment_date,
       flight_date, dob_is_valid, enrollment_date_is_valid,
       flight_date_is_valid
FROM STAGING.MEMBER_RECORDS
ORDER BY source_country, source_member_id;
```

**Expected result:** Country-specific source dates are typed; invalid or missing values become NULL while raw values remain available.

**Explain:** `TRY_TO_DATE` prevents a bad source value from aborting the whole batch.

## 4. Demonstrate Age

**Run/show:**

```sql
SELECT source_member_id, dob, calculation_date, age
FROM STAGING.MEMBER_RECORDS
WHERE dob IS NOT NULL;
```

**Expected result:** Age is birthday-aware, so a member whose birthday has not occurred yet is not over-counted by one year.

**Explain:** The SQL subtracts one when the current month/day is before the DOB month/day.

## 5. Demonstrate Stale_Member

**Run/show:**

```sql
SELECT source_member_id, flight_date, calculation_date, stale_member
FROM STAGING.MEMBER_RECORDS;
```

**Expected result:** More than 90 days is TRUE; exactly 90 days and fewer is FALSE. NULL or future flight dates produce NULL.

**Explain:** The rule is strictly `DATEDIFF(day, flight_date, calculation_date) > 90`.

## 6. Demonstrate latest-record-wins

**Run/show:** `sql/05_member_transformation.sql`, then:

```sql
SELECT member_id, source_country, flight_date, selection_reason
FROM TARGET.CURRENT_MEMBER_RECORDS
ORDER BY member_id;
```

**Expected result:** One row per `source_member_id`. If a member has IND and USA records, only the record with the latest flight date remains.

**Explain:** `ROW_NUMBER()` partitions by the business ID and orders by flight date descending. Equal dates use load timestamp and source metadata as deterministic fallbacks. `DISTINCT` would not select a current country.

## 7. Demonstrate country targets

**Run/show:**

```sql
SELECT 'IND' AS target_country, COUNT(*) AS members FROM TARGET.IND_MEMBERS
UNION ALL SELECT 'USA', COUNT(*) FROM TARGET.USA_MEMBERS
UNION ALL SELECT 'AUS', COUNT(*) FROM TARGET.AUS_MEMBERS;
```

**Expected result:** Current members appear in the target matching their selected current country and nowhere else.

**Explain:** Targets are populated from `TARGET.CURRENT_MEMBER_RECORDS`, never directly from RAW.

## 8. Demonstrate JSON flattening

**Run/show:** `sql/06_redemption_flattening.sql`, then:

```sql
SELECT member_id, feed_date, txn_id, txn_date,
       partner, miles_redeemed, status
FROM TARGET.REDEMPTIONS
ORDER BY member_id, txn_date, txn_id;
```

**Expected result:** One row per object in `redemptions[]`; `YYYYMMDD` strings are DATE values and miles are NUMBER values.

**Explain:** `LATERAL FLATTEN(INPUT => raw_payload:redemptions)` expands only the transaction array, avoiding a Cartesian product.

## 9. Demonstrate the redemption/member join

**Run/show:**

```sql
SELECT member_id, member_name, country, tier,
       txn_id, txn_date, partner, miles_redeemed, status
FROM TARGET.REDEMPTIONS_WITH_MEMBER
ORDER BY member_id, txn_date;
```

**Expected result:** Known members are enriched with current profile data. Unknown members remain with NULL profile columns.

**Explain:** The view joins on `member_id` to the existing current-member table and does not recreate country movement logic.

## 10. Demonstrate data-quality validations

**Run/show:** `sql/07_validations.sql`.

**Expected result:** Diagnostic result sets identify missing mandatory fields, invalid dates, duplicate IDs, unexpected member ID formats, malformed JSON, duplicate transactions, invalid status/amounts, header rows, and orphan redemptions.

**Explain:** Bad records are reported and retained for investigation rather than silently deleted.

## 11. Explain scale to billions of records

**Explain:** Use cloud storage with COPY INTO or Snowpipe, append-only RAW batches, stable batch IDs, incremental transformations, and idempotent batch-scoped MERGE or rebuilds. Let Snowflake micro-partition naturally and add clustering only when query history demonstrates a pruning need. Scale warehouses for batch volume, separate workloads, monitor rejects/orphans/duplicates/latency, and retry from immutable RAW data.

## Closing points

- `sql/01_database_schema.sql` through `sql/07_validations.sql` are the execution path.
- `python/` contains small reference functions used by pytest, not a duplicate production pipeline.
- Run local tests with `C:/Python39/python.exe -m pytest -q`.
- The repository has no configured Snowflake connection, so SQL syntax and consistency were reviewed statically; no database execution result is claimed.
