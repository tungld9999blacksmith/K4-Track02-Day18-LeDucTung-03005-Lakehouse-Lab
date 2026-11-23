# Schema Enforcement, Evolution & Field-IDs

[← README](../README.md) · ✅ **Implemented in this lab** (NB1 Delta, NB3 Delta, NB5 Iceberg)

## Definition

- **Enforcement:** a write whose data does not fit the table schema is rejected.
- **Evolution:** the schema changes (add / rename columns) deliberately, recorded as a commit.
- **Field-ID (Iceberg):** every column has a permanent integer id; names are labels.

## Why It Matters

Without enforcement, one bad producer silently corrupts every consumer. Without evolution, any schema change means rewriting the table.

## Role in the Lakehouse

Data-quality gate in the **table format**; schema lives in Delta `metaData` / Iceberg `metadata.json`.

## How It Works

| | Delta (delta-rs) | Iceberg (pyiceberg) |
|---|---|---|
| Enforcement | Incoming Arrow data is **cast** to the table schema; uncastable → error; extra column → error | Schema in metadata; writes must match |
| Add column | `write_deltalake(..., schema_mode="merge")` | `with tbl.update_schema() as u: u.add_column(...)` |
| Replace schema | `schema_mode="overwrite"` + `mode="overwrite"` (rewrites all data) | — |
| Rename | Needs column mapping (📘 not used in lab) | `u.rename_column(old, new)` — metadata-only |
| Old rows, new column | Read as `null`, files untouched | Read as `null`, files untouched |
| Column matching | By name | **By field-ID** (`PARQUET:field_id` in each file) |

## How It Was Used in This Lab

| Experiment | Result |
|---|---|
| NB1 append `age="thirty"` to Int64 column | `Cast error: Cannot cast string 'thirty' to value of Int64 type`; no commit |
| My extra test: append `age="30"` | **Accepted** (castable) |
| My extra test: extra column `x` without merge | `Cannot cast schema, number of fields does not match: 3 vs 2` |
| NB1 append with `tier`, `schema_mode="merge"` | v1 `metaData` has `tier`; 3 old rows `tier=null` |
| NB3 add `tier` with `schema_mode="overwrite"` | Whole table rewritten (`num_removed_files: 1`) |
| NB5 rename `latency_ms` → `latency_millis`, add `tier` | field-id **4** kept, `tier` got id **6**; an old data file still physically contains `('latency_ms', field_id '4')` |

## Example

```python
# Delta: opt-in evolution
write_deltalake(path, new.to_arrow(), mode="append", schema_mode="merge")

# Iceberg: metadata-only rename
with tbl.update_schema() as upd:
    upd.rename_column("latency_ms", "latency_millis")
```

## Common Pitfalls

- Enforcement checks **types, not business rules**: `score=-1`, `status=null` passed in NB3 → you still need validation + rollback.
- Castable wrong data (`"30"`) slips through delta-rs enforcement.
- Hive matches by name (rename ⇒ old data reads null); plain Parquet/CSV by position (reorder ⇒ shifted columns).
- `schema_mode="overwrite"` is a full rewrite, not an evolution.

## Related Concepts

[transaction-log-and-acid](transaction-log-and-acid.md) · [catalog-and-metadata](catalog-and-metadata.md) · [medallion-architecture](medallion-architecture.md) · [Delta](../technologies/delta-lake.md) · [Iceberg](../technologies/apache-iceberg.md)

## Key Takeaways

- Enforcement = default; evolution = explicit.
- Adding a column never rewrites old files.
- Iceberg field-IDs make rename safe and metadata-only.
- Type checks ≠ data quality.
