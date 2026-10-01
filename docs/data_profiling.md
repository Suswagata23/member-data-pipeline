# Source Data Profile

This profile records the inputs inspected before implementation. The original files remain unchanged.

## Files

- `IND(in).csv`: 3 rows, headers `ID`, `Name`, `DOB`, `TierCode`, `EnrollmentDate`, `Individual or Corporate`, `Flight Date`.
- `USA(in).csv`: 3 rows, headers `ID`, `Name`, `TierCode`, `EnrollmentDate`, `FlightDate`.
- `AUS.xlsx`: one sheet with 3 rows and headers `Unique ID`, `Member Name`, `Tier Type`, `Date of Birth`, `Date of Enrollment`, `Date of Flight`.
- `DE_Assessment_file.pdf`: assessment instructions.

No redemption JSON file was supplied.

## Observed Data Types and Formats

The source values are text-like at ingestion time. Dates use three formats:

- India: `M/D/YYYY`, for example `12/1/1998`.
- USA: compact `MDDYYYY` or `MMDDYYYY`, for example `6152022`.
- Australia: ISO-like `YYYY-MM-DD` values in the workbook.

The raw table therefore stores source values as text. Staging applies country-specific `TRY_TO_DATE` parsing.

## Keys and Duplicates

Each individual file has three unique IDs and no duplicate complete rows. The numeric IDs `1`, `2`, and `3` repeat across all three country files, and names differ. A globally unique member identity is not present in the supplied inputs. Phase 2 uses `source_country:source_member_id` as a technical staging key and reports cross-country source-ID reuse diagnostically.

## Data Quality Findings

- India: no nulls or duplicate IDs observed.
- USA: DOB is not supplied at all; no duplicate IDs observed.
- Australia: member `1` has a literal `NULL` DOB.
- Australia: member `2` has invalid enrollment date `2021-13-13`.
- Australia: `Jonnathan` may be a spelling anomaly, but no reference data supports correcting it.
- No supplied valid flight date is in the future relative to `2026-10-01`.
- All supplied valid flight dates are more than 90 days before `2026-10-01`.

Because the redemption feed is missing, redemption schema, malformed JSON, duplicate redemption IDs, and unknown-member checks cannot yet be profiled.
