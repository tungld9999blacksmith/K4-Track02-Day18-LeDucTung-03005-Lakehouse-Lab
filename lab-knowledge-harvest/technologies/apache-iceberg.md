# Apache Iceberg (`pyiceberg` + SQLite `SqlCatalog`)

[← README](../README.md) · ✅ **Implemented in this lab** — `pyiceberg` **0.12.0** with extras `sql-sqlite,pyarrow,pyiceberg-core`

## What Is It?

An open table format built around a **catalog** and a metadata tree (metadata.json → manifest list → manifests → data). Columns are tracked by **field-ID**; partitions are **transforms** of source columns.

## Why Did We Use It?

To see the second major format and the "catalog as control plane" design; hidden partitioning, field-ID rename and partition evolution are its signature features.

## Role in This Lab

NB5 (all Iceberg features), NB6 (snapshot expiry + manifest-list sweep), NB8 (catalog-served table for the agent).

## Role in the Lakehouse

Table format **and** the catalog layer.

## How It Works

[catalog-and-metadata](../concepts/catalog-and-metadata.md) · [partitioning](../concepts/partitioning.md) · [schema evolution](../concepts/schema-enforcement-and-evolution.md)

## Important Configuration

```python
from pyiceberg.catalog.sql import SqlCatalog
SqlCatalog(name, uri=f"sqlite:///{dir}/catalog.db", warehouse=f"file://{dir}/warehouse")
```
- One catalog dir per notebook: `_lakehouse/iceberg/<name>/` (`scripts/lakehouse.py`).
- `nullable=False` in the Arrow schema → Iceberg *required* field.
- 📘 Production swap: `load_catalog("prod", type="rest", uri=…, credential="YOUR_CLIENT_ID:YOUR_CLIENT_SECRET")`.

## Commands / APIs

| API | Use |
|---|---|
| `cat.create_namespace(ns)`, `cat.create_table(f"{ns}.t", schema=)`, `cat.load_table()`, `cat.list_tables(ns)` | Catalog |
| `tbl.append(arrow_tbl)` | Commit → new snapshot |
| `tbl.update_spec()` + `DayTransform()` / `IdentityTransform()` | Partitioning / evolution |
| `tbl.update_schema()` → `add_column`, `rename_column` | Schema evolution |
| `tbl.scan(row_filter="…", snapshot_id=…, limit=…)` → `.plan_files()`, `.to_arrow()` | Plan / read / time travel |
| `tbl.inspect.snapshots() / manifests() / files() / partitions() / history() / metadata_log_entries()` | Metadata inspection |
| `tbl.maintenance.expire_snapshots().by_ids(ids).commit()` | Expiry (metadata-only here) |
| `tbl.snapshots()`, `tbl.specs()`, `tbl.schema()`, `tbl.metadata_location` | Introspection |

## Example from the Lab

Filter `ts` for one day → `plan_files()` 10 → 1 (10×). Rename kept field-id 4; old Parquet still has physical column `latency_ms` tagged `PARQUET:field_id=4`.

## Trade-offs

- ✅ Hidden partitioning, field-IDs, spec evolution by default; engine-neutral catalog protocol.
- ⚠️ Needs a catalog (one more component); metadata can exceed data for tiny files (294% in NB5).

## Limitations (observed in this version)

- `expire_snapshots` deleted **no files** (avro 40 → 40) → manual sweep required.
- Compaction (`rewrite_data_files`) and `remove_orphan_files` not available in PyIceberg → Spark/Java procedures.
- SQLite catalog file is held open by a running kernel on Windows.

## When I Would Use It Again

Multi-engine platforms, tables with evolving partitioning/schema, central catalog governance.

## Related Technologies

[Delta Lake](delta-lake.md) · [Arrow & Parquet](apache-arrow-and-parquet.md) · [Delta vs Iceberg](../comparisons/design-trade-offs.md#delta-lake-vs-apache-iceberg)

## Key Takeaways

- Always `load_table` again after metadata changes.
- Filter on the source column; let the transform prune.
- Expiry ≠ deletion in PyIceberg.
