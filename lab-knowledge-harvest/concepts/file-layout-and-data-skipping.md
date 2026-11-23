# File Layout: Small Files, Compaction, Z-order & Data Skipping

[← README](../README.md) · ✅ **Implemented in this lab** (NB2, NB6)

## Definition

- **Data skipping / file pruning:** the engine compares a filter with per-file min/max stats and never opens files that cannot match.
- **Small-file problem:** many tiny files from frequent writes; per-file overhead dominates.
- **Compaction (bin-packing):** rewrite many small files into fewer files near `target_size`.
- **Z-order (clustering):** rewrite data sorted along a space-filling curve so each file covers a narrow value range.

## Why It Matters

Object stores bill per request; each file = at least one GET + footer read + planning metadata. NB6 estimate: 200 files × 50K scans/day = 10M GETs ≈ **$4/day** vs **$0.08/day** with 4 files.

## Role in the Lakehouse

Performance/storage-layout layer; stats live in the table format (Delta `add.stats`, Iceberg manifests).

## How It Works

```text
Before Z-order (streamed data)          After Z-order
file1 [1 ............ 100000]           file1 [1    – 1851]
file2 [3 ............  99998]           file2 [1851 – 3696]
file3 [1 ............ 100000]           file3 [3696 – 5534]  ← only file with 4242
→ every file "may contain" 4242         → 54/55 files skipped
```

- Compaction changes **cost per file**; it does not sort → ranges stay wide.
- Z-order changes **which files** a query must read.
- Too-large `target_size` → one file → nothing left to skip.

## How It Was Used in This Lab

| NB2 (1M rows, `user_id` 1–100K) | Files | Files whose range contains 4242 | Avg range width | MB |
|---|---:|---:|---:|---:|
| v199 after 200 appends | 200 | 200 | ~99,960 | 13.19 |
| v200 after `compact(256 KB)` | 67 | **67** | ~99,987 | 8.17 |
| v201 after `z_order(["user_id"])` | 55 | **1** | ~1,818 | 6.77 |

- Pruning ratio **55×** (deterministic). Speedup 10.3× / 14.8× in two runs (*timing*, noisy).
- Query result identical (`count=5`) → OPTIMIZE has `dataChange: false`.
- 322 Parquet files on disk vs 55 referenced (tombstones until VACUUM).
- NB6 repeat: 200 → 11 files (18×), then 11/11 → 1/10 files for `user_id=12345` (90% skip).
- Iceberg equivalent (NB5): metadata 294% of data size with 500-row files → small files also bloat metadata.

## Important Commands / Code

```python
dt.optimize.compact(target_size=256 * 1024)
dt.optimize.z_order(["user_id"], target_size=256 * 1024)
dt.to_pyarrow_table(filters=[("user_id", "=", 4242), ("kind", "=", "purchase")])  # pushdown

# Deterministic skipping metric
aa = pa.table(DeltaTable(path).get_add_actions(flatten=True)).to_pylist()
hits = sum(f["min.user_id"] <= 4242 <= f["max.user_id"] for f in aa)
```

## Common Pitfalls

- Judging by wall-clock on a laptop; use files-pruned instead.
- Expecting compaction alone to speed up point lookups.
- Z-ordering tiny tables (NB4 Gold: 3 rows/partition) — no benefit.
- Disk usage temporarily **rises** after OPTIMIZE (NB6: 10.1 → 16.1 MB) until VACUUM.

## Related Concepts

[partitioning](partitioning.md) · [table-maintenance](table-maintenance.md) · [transaction-log-and-acid](transaction-log-and-acid.md) · [design trade-offs](../comparisons/design-trade-offs.md)

## Key Takeaways

- Stats exist from day one; clustering makes them useful.
- Compaction = fewer files; clustering = fewer files *read*.
- Measure pruning by stats, not stopwatch.
- Fix the writer's batch size first; compaction is cleanup.
