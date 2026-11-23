# Table Maintenance (Compaction, Clustering, Expiry, Orphans, Checkpoints)

[← README](../README.md) · ✅ **Implemented in this lab** (NB6; also NB2)

## Definition

Recurring jobs that keep a lakehouse fast and cheap. Without them every guarantee (versions, atomic writes) leaves growing garbage.

| # | Job | If skipped | Delta (delta-rs) | Iceberg (pyiceberg) |
|---|---|---|---|---|
| 1 | Compaction | Slow queries, request cost | `optimize.compact()` | 📘 `rewrite_data_files` (Spark/Java) |
| 2 | Clustering | Stats can't skip | `optimize.z_order()` | 📘 sort/zorder (Spark/Java) |
| 3 | Version/snapshot expiry | Old files billed forever | `vacuum()` | `maintenance.expire_snapshots()` |
| 4 | Orphan removal | Files from crashed writers billed, invisible | **manual set difference** | **manual set difference** (📘 `remove_orphan_files` in Spark) |
| 5 | Log checkpoint | Slow cold reads | `create_checkpoint()` | — |

## Why It Matters

Small files are "the most common production failure mode" — caused by normal ingestion plus no cron job.

## Role in the Lakehouse

Operations layer over the table format; trades storage cost against time-travel window.

## How It Works — the key distinction

```text
referenced ──(remove / expire)──► unreferenced ──(vacuum / sweep)──► physically deleted
                                    still on disk, still billed
orphan (never committed) ─────────────────────────(set difference + age guard)──► deleted
```

## How It Was Used in This Lab (NB6 numbers)

| Step | Result |
|---|---|
| Baseline | 200 files, 10.1 MB, avg 51.5 KB, 200 JSON commits |
| Job 1 compact (1 MB) | 200 → 11 files (18×); disk **10.1 → 16.1 MB** (old files tombstoned) |
| Job 2 z_order | files possibly containing `user_id=12345`: 11/11 → 1/10 (90% skip) |
| Job 3 vacuum (`retention_hours=0`) | 211 files deleted (200 + 11), **16.1 MB** reclaimed; data 6.2 MB (smaller than start: zstd + bigger files) |
| Job 4 orphans | 3 planted 30-day-old files; VACUUM dry-run listed **none** of them; set difference found 3 (21.2 KB) |
| Job 5 checkpoint | `_last_checkpoint` → v203; auto-checkpoints already at v99, v199 |
| Iceberg expiry | snapshots 20 → 3, **avro 40 → 40** (nothing deleted), metadata grew |
| Iceberg sweep | 17 stranded manifest lists deleted → avro 23; 2,000 rows intact |
| Managed compaction model | $990/mo for 500 GB / 2M files; 24% driven by object count |

## Important Commands / Code

```python
dt.optimize.compact(target_size=1024 * 1024)
dt.optimize.z_order(["user_id"], target_size=1024 * 1024)
dt.vacuum(retention_hours=0, dry_run=True,  enforce_retention_duration=False)  # lab only!
dt.vacuum(retention_hours=0, dry_run=False, enforce_retention_duration=False)
dt.create_checkpoint()
ice.maintenance.expire_snapshots().by_ids(doomed_ids).commit()
```

Orphan finders (Delta + Iceberg): [techniques/code-patterns.md#find-orphan-files](../techniques/code-patterns.md#find-orphan-files)

## Common Pitfalls

- `retention_hours=0` kills time travel and can break in-flight readers; production ≥ 168 h.
- delta-rs VACUUM only reclaims **tombstoned** files; never-committed orphans are invisible to it (Spark VACUUM also lists the directory — verify your engine).
- Orphan sweep **must** have an age guard, or you delete files a concurrent writer hasn't committed yet.
- PyIceberg expiry is metadata-only (in the lab's version); chain it with a sweep.
- Misleading NB6 prints: `(0 B)` (relative paths), "5 files" (3 orphans + 2 checkpoints), `…099.checkpoint` (old auto checkpoint) → [troubleshooting](../techniques/troubleshooting.md#misleading-nb6-output-lines).

## Related Concepts

[file-layout-and-data-skipping](file-layout-and-data-skipping.md) · [time-travel-and-versioning](time-travel-and-versioning.md) · [data-lifecycle-and-erasure](data-lifecycle-and-erasure.md) · [catalog-and-metadata](catalog-and-metadata.md)

## Key Takeaways

- Unreferenced ≠ deleted. Expiry and orphan removal are a **pair**.
- Compaction temporarily *increases* storage.
- Retention window = time-travel/RESTORE window.
- Verify engine behaviour; canary tests in `tests/test_lab18.py` pin the two library behaviours.
