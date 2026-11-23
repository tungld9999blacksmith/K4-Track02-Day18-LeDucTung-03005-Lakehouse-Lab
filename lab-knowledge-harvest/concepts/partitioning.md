# Partitioning: Directory, Hidden & Evolving

[← README](../README.md) · ✅ **Implemented in this lab** (NB4, NB8 Delta `partition_by`; NB5 Iceberg hidden partitioning + spec evolution)

## Definition

Partitioning groups rows into separate files/directories by a key so queries filtering on that key skip whole partitions.

| Style | How the key is defined | Used in lab |
|---|---|---|
| Directory (Hive-style) | A real column; folders like `date=2026-04-01/` | ✅ Delta `partition_by=[...]` |
| Hidden | A **transform** of a source column stored in metadata (e.g. `day(ts)`) | ✅ Iceberg |
| Evolution | Change the partition spec; old files keep old spec | ✅ Iceberg |

## Why It Matters

Partition pruning is the cheapest skipping (whole directories). Hidden partitioning removes the classic Hive failure: users forgetting the partition predicate and full-scanning.

## Role in the Lakehouse

Physical layout decision recorded in table metadata (`partitionColumns` in Delta `metaData`; partition specs in Iceberg metadata).

## How It Works

- **Delta:** partition column values are written as folder names and in `add.partitionValues`.
- **Iceberg:** spec `1000: ts_day: day(2)` = partition field 1000 is `day()` of field-id 2 (`ts`). Writer computes `ts_day`; planner applies the transform to your `ts` filter.
- **Spec evolution:** `update_spec()` creates a new spec id; each data file records the spec that wrote it.

## How It Was Used in This Lab

| Table | Key | Result |
|---|---|---|
| NB4 Silver/Gold LLM metrics | `date` | 8 folders (time-zone issue, see [troubleshooting](../techniques/troubleshooting.md#timezone-dependent-date-partitions)) |
| NB8 Silver trajectories | `agent_version` | `policy-v2`, `policy-v3` |
| NB8 governed corpus | `provenance_bucket` | 5 folders; DELETE of one subject rewrote only 4/5 partition files |
| NB5 Iceberg `llm_events` | `day(ts)` | Filter on `ts` → 10 → 1 files (**10×**); $220/day modeled saving |
| NB5 + `identity(model)` | spec 0 → 1 → 2 | 10 old files spec 1, 3 new files spec 2; `ts ≥ 08-11 AND model=opus` → 1/13 files, `model=opus` alone → **11/13** |

## Important Commands / Code

```python
write_deltalake(path, tbl, mode="overwrite", partition_by=["date"])

from pyiceberg.transforms import DayTransform, IdentityTransform
with tbl.update_spec() as spec:
    spec.add_field("ts", DayTransform(), "ts_day")
with tbl.update_spec() as spec:
    spec.add_field("model", IdentityTransform(), "model_id")

len(list(tbl.scan(row_filter="ts >= '2026-08-05T00:00:00' and ts < '2026-08-06T00:00:00'").plan_files()))
```

## Common Pitfalls

- Partitioning a high-cardinality column (100K `user_id`s) recreates the small-file problem → use Z-order instead.
- Old data does **not** benefit from a new spec until rewritten.
- Date partitions derived with a session time zone are non-deterministic across machines.
- DuckDB reading a registered Arrow table does not measure partition pruning (NB8 note).

## Related Concepts

[file-layout-and-data-skipping](file-layout-and-data-skipping.md) · [catalog-and-metadata](catalog-and-metadata.md) · [Iceberg](../technologies/apache-iceberg.md) · [design trade-offs](../comparisons/design-trade-offs.md#partition-vs-z-order)

## Key Takeaways

- Low-cardinality filter column → partition; high-cardinality → cluster.
- Hidden partitioning: filter on the real column, the engine derives the partition.
- Spec evolution is metadata-only; old files keep their layout.
