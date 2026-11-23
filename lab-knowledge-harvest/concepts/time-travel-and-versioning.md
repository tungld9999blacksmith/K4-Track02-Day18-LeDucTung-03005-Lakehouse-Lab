# Time Travel, Versioning, MERGE & RESTORE

[← README](../README.md) · ✅ **Implemented in this lab** (NB3 Delta, NB5 Iceberg, NB7/NB8 after DELETE)

## Definition

Every commit creates an immutable **version** (Delta) or **snapshot** (Iceberg). **Time travel** reads the table as of an older version; **RESTORE** makes an old state current again via a new commit.

## Why It Matters

Audit ("what did the table look like?"), reproducibility (train on a fixed version), and recovery from bad writes — without backups.

## Role in the Lakehouse

Provided by the table format. Works only while old files physically exist → bounded by [table maintenance](table-maintenance.md) retention.

## How It Works

- Parquet files are **immutable**. Updates/deletes use **copy-on-write**: read affected files, write new files, `remove` old ones.
- Reading version N = replay the log up to N → that version's file list → read those files.
- RESTORE(N) = new commit that `add`s/`remove`s files so the current state equals version N.

## How It Was Used in This Lab (NB3 timeline)

| Version | Operation | Rows | Files | `score<0` |
|---|---|---:|---:|---:|
| v0 | WRITE overwrite | 100,000 | 1 | 0 |
| v1 | WRITE overwrite + `schema_mode="overwrite"` (add `tier`) | 100,000 | 1 | 0 |
| v2 | **MERGE** (50K update + 50K insert, 50K copied) | 150,000 | 1 | 0 |
| v3 | append 50 bad rows | 150,050 | 2 | 50 |
| v4 | **RESTORE → v2** (1 `remove`, 0.02 s) | 150,000 | 1 | 0 |

- 4 Parquet files stayed on disk, 1 referenced → all versions still readable.
- NB5: `tbl.scan(snapshot_id=first)` → 500 rows; latest → 5,000. Schema/spec changes created new `metadata.json` but **no snapshot**.
- NB7/NB8: after `DELETE`, `DeltaTable(path, version=0)` still returned the deleted subject's rows.

## Example

```python
# MERGE (upsert)
(DeltaTable(path).merge(source=updates.to_arrow(),
                        predicate="t.customer_id = s.customer_id",
                        source_alias="s", target_alias="t")
   .when_matched_update_all()
   .when_not_matched_insert_all()
   .execute())

DeltaTable(path, version=0).to_pyarrow_table()   # time travel
DeltaTable(path).restore(2)                      # rollback = new version
tbl.scan(snapshot_id=sid).to_arrow()             # Iceberg time travel
```

## Common Pitfalls

- MERGE cost scales with **files touched**, not rows changed (it re-copied 50K unchanged rows).
- RESTORE resets the **whole table** — good writes after the bad one are lost too (unlike `git revert`).
- `vacuum(retention_hours=0)` destroys time travel (NB6).
- Append is not idempotent; MERGE on a key is.

## Related Concepts

[transaction-log-and-acid](transaction-log-and-acid.md) · [table-maintenance](table-maintenance.md) · [data-lifecycle-and-erasure](data-lifecycle-and-erasure.md) · [provenance-and-reproducibility](provenance-and-reproducibility.md)

## Key Takeaways

- Versions are free to create, not free to keep.
- RESTORE is fast because it only edits the file list.
- Retention window = recovery window.
- MERGE = idempotent upsert via copy-on-write.
