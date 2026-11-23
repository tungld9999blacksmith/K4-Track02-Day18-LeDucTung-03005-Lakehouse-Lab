# Delta Lake (`deltalake` / delta-rs)

[← README](../README.md) · ✅ **Implemented in this lab** — `deltalake` **1.6.6** (Rust core, Python bindings, no JVM)

## What Is It?

An open table format: Parquet data files + a JSON transaction log (`_delta_log/`) with periodic Parquet checkpoints. `deltalake` is the Rust implementation (delta-rs) — the Spark library is `delta-spark` (📘 Spark path only).

## Why Did We Use It?

ACID, versions, MERGE/DELETE, OPTIMIZE/VACUUM and CDF from pure Python, offline, ~600 MB RAM.

## Role in This Lab

Format for every non-Iceberg table: NB1–NB4, NB6 (Delta half), NB7, NB8 (Bronze/Silver/Gold, governed corpus).

## Role in the Lakehouse

Table-format layer; path-addressed (no catalog used in the lab).

## How It Works

See [transaction-log-and-acid](../concepts/transaction-log-and-acid.md). Copy-on-write for MERGE/DELETE/OPTIMIZE; time travel by replaying the log to version N; checkpoint every 100 commits automatically.

## Important Configuration

| Setting | Where | Effect |
|---|---|---|
| `mode="overwrite" \| "append"` | `write_deltalake` | Replace vs add files |
| `schema_mode="merge" \| "overwrite"` | `write_deltalake` | Opt-in evolution vs full schema replace |
| `partition_by=[...]` | `write_deltalake` | Folder partitions |
| `configuration={"delta.enableChangeDataFeed": "true"}` | table create | Enables `load_cdf()` |
| `target_size` | `optimize.compact` / `z_order` | Output file size (lab: 256 KB / 1 MB; prod 128–512 MB) |
| `retention_hours`, `enforce_retention_duration` | `vacuum` | Retention guard (lab disables it) |

## Commands / APIs

| API | Use |
|---|---|
| `write_deltalake(path, arrow_tbl, mode=..., ...)` | Write |
| `DeltaTable(path[, version=N])` | Open (time travel) |
| `.to_pyarrow_table(filters=[(col, op, val)])` | Read with stats pushdown |
| `.version()`, `.history([n])`, `.count()`, `.schema()` | Inspect |
| `.file_uris()` | Files in current version (1.x; `files()` was 0.x) |
| `.get_add_actions(flatten=True)` | Per-file stats `min.<col>`, `max.<col>` (returns arro3 Table → wrap in `pa.table`) |
| `.merge(...).when_matched_update_all().when_not_matched_insert_all().execute()` | Upsert |
| `.delete("predicate")`, `.restore(N)` | Delete, rollback |
| `.optimize.compact()`, `.optimize.z_order([...])` | Maintenance |
| `.vacuum(...)`, `.create_checkpoint()` | Maintenance |
| `.load_cdf(starting_version=N).read_all()` | Change feed |

Full snippets: [techniques/code-patterns.md](../techniques/code-patterns.md)

## Example from the Lab

NB3: MERGE of 100K rows in 0.15–0.22 s; RESTORE to v2 in 0.02 s by tombstoning one file.

## Trade-offs

- ✅ Simple (log in the table folder), great Python support, CDF built in.
- ⚠️ Path-addressed in this lab → no central discovery/governance (Iceberg used a catalog).
- ⚠️ Rename requires column mapping (not used).

## Limitations (observed)

- No fixed-size vector type: `fixed_size_list<float>[256]` → `list<float>` on read.
- `vacuum()` ignores never-committed orphans; `vacuum(dry_run=True)` returns **relative** paths and still lists already-deleted tombstones.
- OPTIMIZE output used zstd (`*.zstd.parquet`) while appends used snappy — compression changed.

## When I Would Use It Again

Python/Rust pipelines, small-to-mid tables, CDC with CDF, anything needing MERGE without a cluster.

## Related Technologies

[Iceberg](apache-iceberg.md) · [Arrow & Parquet](apache-arrow-and-parquet.md) · [DuckDB](duckdb.md) · [Spark path](spark-minio-docker.md) · [Delta vs Iceberg](../comparisons/design-trade-offs.md#delta-lake-vs-apache-iceberg)

## Key Takeaways

- delta-rs = full Delta features without Spark.
- Wrap `get_add_actions()` with `pa.table(...)`.
- Know which behaviours are engine-specific (vacuum orphans, checkpoints, compression).
