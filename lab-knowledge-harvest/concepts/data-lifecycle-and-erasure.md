# Data Lifecycle: DELETE, Change Data Feed & Erasure

[← README](../README.md) · ✅ **Implemented in this lab** (NB7, NB8; links to NB6 VACUUM)

## Definition

When a row is deleted, edited or expires, every copy and derivative (embeddings, indexes, aggregates, pinned versions) must follow. **Change Data Feed (CDF)** publishes row-level changes, including deletes, as events.

## Why It Matters

A deleted subject that is still retrievable from a RAG index is a **compliance bug**, not just a stale cache. One-way upsert sync pipelines never carry deletes.

## Role in the Lakehouse

Governance layer: the lakehouse is the system of record; derived stores subscribe to its changes.

## How It Works

```text
DELETE (current version)  →  copy-on-write: survivors rewritten, old file tombstoned
                           →  old versions still readable (time travel)  ← not erased yet
VACUUM after retention    →  old files physically removed                ← erased from this table
CDF delete events         →  downstream index evicts the same ids       ← erased from copies
```

## How It Was Used in This Lab

| Step | Result |
|---|---|
| NB7: external index = copy of 2,000 vectors | Two sources of truth from now on |
| `dt.delete("subject_id = 'user_042'")` | 8 docs; table 2,000 → 1,992 (`deleted_rows=8`, `copied_rows=1992`) |
| Query both | **Table 0 hits, external index 8 hits** → violation |
| Time travel `version=0` (my added check) | Still **8** rows readable; 2 files on disk, 1 referenced |
| CDF table (`delta.enableChangeDataFeed=true`), delete, `load_cdf(starting_version=1)` | 8 rows, all `_change_type = delete`, ids 42, 292, 542, 792, 1042… |
| NB8: delete `user_007` from governed corpus | 8 → 0 current; rewrote only **4/5** partition files |
| NB8 pinned `corpus_version=0` | Still 8 rows, **3 of them in the trainable set** used by the model card |

## Important Commands / Code

```python
write_deltalake(path, tbl, mode="overwrite",
                configuration={"delta.enableChangeDataFeed": "true"})
DeltaTable(path).delete("subject_id = 'user_042'")
cdf = DeltaTable(path).load_cdf(starting_version=1).read_all()
deletes = [t for t in cdf.column("_change_type").to_pylist() if t == "delete"]
DeltaTable(path, version=0).to_pyarrow_table()   # proves history still holds it
```

## Common Pitfalls

- "0 rows in current version" ≠ erased: history, backups, indexes, Gold aggregates and **trained models** may still hold it.
- Full re-sync / upsert jobs silently drop deletes.
- Version pinning for reproducibility conflicts with erasure — decide policy explicitly (retention, model-card notes, retraining).
- The lab test only proves removal from the current table version; it is not a legal compliance test.

## Related Concepts

[time-travel-and-versioning](time-travel-and-versioning.md) · [table-maintenance](table-maintenance.md) · [vectors-and-multimodal-data](vectors-and-multimodal-data.md) · [provenance-and-reproducibility](provenance-and-reproducibility.md)

## Key Takeaways

- DELETE + VACUUM (after retention) + propagate to every derivative.
- Subscribe to deletes (CDF) instead of re-syncing.
- Best: keep the vector in the row so the table enforces its lifecycle.
