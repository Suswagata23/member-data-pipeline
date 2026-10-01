# Incubyte Data Engineering Assessment

## Project Overview

This project prepares member data from the supplied India, USA, and Australia files for a Snowflake pipeline. Phase 2 establishes a source-preserving raw layer, a typed staging layer, derived age and stale-member fields, and diagnostic data-quality checks.

The source files are intentionally heterogeneous. The pipeline keeps source values in raw form so invalid data can be investigated and reprocessed instead of silently discarded.

## Architecture

```text
country member files
        |
        v
RAW.MEMBER_RECORDS
        |
        v
STAGING.MEMBER_RECORDS
        |
        v
TARGET.CURRENT_MEMBER_RECORDS
        |
        +--> TARGET.IND_MEMBERS
        +--> TARGET.USA_MEMBERS
        +--> TARGET.AUS_MEMBERS
```

The assessment also requires:

```text
redemption JSON -> flattened redemptions -> member profile join
```

That redemption path is deliberately deferred until the actual JSON feed is supplied.

## Technology

- Snowflake SQL for schemas, tables, transformations, and validations
- Python for small deterministic reference functions and pytest tests
- pytest for focused business-rule tests

## Data Model

### `RAW.MEMBER_RECORDS`

A unified landing table for the three observed member feeds. Source date values remain `VARCHAR`, and source-specific missing columns remain null. `source_country`, `source_file`, and `source_row_number` provide ingestion context.

### `STAGING.MEMBER_RECORDS`

Contains typed dates, source-quality flags, `age`, and `stale_member`. The technical `member_key` is `source_country:source_member_id` because numeric IDs repeat across country files.

`TARGET.CURRENT_MEMBER_RECORDS` contains one selected row per `source_member_id`. The country target tables are populated only from this current-state table.

## Transformation Logic

- India dates are parsed as `M/D/YYYY`.
- USA dates are zero-padded and parsed as `MMDDYYYY`.
- Australia dates are parsed as `YYYY-MM-DD`.
- Invalid and literal `NULL` values become null typed dates while their raw values remain available.
- Age uses a birthday-aware calculation.
- `stale_member` is `TRUE` only when the flight date is more than 90 days before the calculation date.
- Null or future flight dates produce `NULL` for `stale_member`, making the data issue visible.

Latest-record-wins and country routing are implemented in Phase 3 using the explicit business-key assumption documented below.

## Latest Record Wins

Phase 3 applies the movement rule using `flight_date` as the business recency date:

```text
source_member_id = 101, IND, flight_date = 2024-01-10
source_member_id = 101, USA, flight_date = 2025-06-20
current state    = 101, USA
```

`ROW_NUMBER()` partitions by `source_member_id` and retains rank `1`. `DISTINCT` is insufficient because records for the same member can have different countries and dates.

Equal flight dates are ordered by `load_timestamp`, then `source_file`, `source_row_number`, and `source_country`. The latter fields are ingestion metadata, not a claim that one country is business-preferred. They make a batch reproducible when no source sequence is provided. A future authoritative sequence should replace these fallback fields.

The source files repeat IDs across countries, so this phase assumes the repeated numeric ID represents the same business member for the assessment's movement scenario. That assumption is visible in `sql/05_member_transformation.sql` and must be revisited if a global member identifier is supplied.

## Data Quality

`sql/07_validations.sql` returns diagnostic rows for:

- missing source IDs and member attributes
- invalid dates
- future DOB and flight dates
- unreasonable ages
- unexpected countries
- duplicate technical keys and exact source records
- source IDs reused across countries

Observed issues are documented in [docs/data_profiling.md](docs/data_profiling.md). The USA DOB absence and Australia invalid/missing values are reported rather than hidden.

## Snowflake Execution

Run the SQL scripts in this order:

1. `sql/01_database_schema.sql`
2. `sql/02_raw_ddl.sql`
3. `sql/03_staging_ddl.sql`
4. Load the supplied files into `RAW.MEMBER_RECORDS`, mapping country and source metadata while preserving source text.
5. `sql/04_load_staging.sql`
6. `sql/07_validations.sql`

The raw load step is intentionally kept separate because the inputs use CSV and XLSX formats with different headers and no Snowflake stage or credentials were supplied.

## Testing

From the repository root:

```powershell
C:/Python39/python.exe -m pytest -q
```

The tests cover birthday-aware age, the strict stale threshold, null/future flights, source date formats, duplicate detection, mandatory fields, invalid dates, and country validation.

## Assumptions

- `IND`, `USA`, and `AUS` are derived from the supplied filenames because no source country column exists.
- Numeric source IDs repeat across country files. Phase 2 uses a country-qualified technical staging key; Phase 3 uses `source_member_id` as the business key for the assessment's latest-record rule.
- The assessment's required DOB field is treated as mandatory, so USA rows are surfaced as data-quality failures because their source has no DOB column.
- The calculation date is Snowflake `CURRENT_DATE()` in the staging build.
- Invalid and missing dates remain visible through raw columns and staging validity flags.

## Design Decisions

A single unified raw table was selected over one raw table per country because the feeds represent the same business entity with schema drift. Separate raw tables would preserve headers more literally but would duplicate downstream logic. Keeping source text in the unified table preserves auditability while allowing one staging contract.

Snowflake SQL remains the primary implementation because the assessment is Snowflake-focused. Python is limited to small reference functions that make date-boundary behavior testable without duplicating the pipeline.

## Deferred Work

The next phase should establish a defensible global member identity, implement deterministic latest-record-wins handling, and create country-specific target tables. A later phase can flatten the missing redemption JSON after its actual structure is provided.
