# Provenance & Reproducibility (Version Pinning)

[← README](../README.md) · ✅ **Implemented in this lab** (NB8)

## Definition

- **Provenance:** recorded origin of each row (source, license, consent, generator), stored as columns from ingest.
- **Reproducibility:** a training run records the exact table **version** (and ideally a content fingerprint) it consumed, so it can be replayed later.

## Why It Matters

"Which data did this model learn from, and were we allowed to use it?" must be answerable months later. Provenance cannot be reconstructed after data is mixed.

## Role in the Lakehouse

Governance + lineage layer, built from ordinary features: columns, partitions, versions, history.

## How It Works

| Mechanism | Lab implementation |
|---|---|
| Classification as one column expression | `CASE license … END AS provenance_bucket` |
| Partition by bucket | `partition_by=["provenance_bucket"]` |
| Exclude unknown origin | trainable = `provenance_bucket <> 'UNCLASSIFIED'` |
| Pin version into run / model card | `DeltaTable(path).version()` stored in a dict |
| Replay | `DeltaTable(path, version=pinned).count()` |
| Content check (my addition) | order-independent row-hash fingerprint |

## How It Was Used in This Lab

| Item | Result |
|---|---|
| Buckets | licensed 675 (33.8%) · public_domain 333 · synthetic 331 · scraped_optout_checked 327 · **UNCLASSIFIED 334** |
| Trainable set | 1,666 / 2,000; model card `corpus_version=0`, `excluded_rows=334` |
| Training run pin | `table_version=0`, `n_steps_seen=1578` |
| After more appends | v1, 1,978 steps; replay v0 = 1,578 ✅ |
| Fingerprint | training == replay(v0) ✅; current differs; **400 "new" rows were duplicates** (`silver.slice(0, 400)`) |

## Example

```python
training_run = {"trajectory_table": SILVER,
                "table_version": DeltaTable(SILVER).version(),   # the pin
                "n_steps_seen": DeltaTable(SILVER).count()}
pinned = DeltaTable(SILVER, version=training_run["table_version"])
assert pinned.count() == training_run["n_steps_seen"]

def fingerprint(tbl):                      # content, not just count
    return int(pl.from_arrow(tbl).sort(["trajectory_id", "step"]).hash_rows(seed=0).sum())
```

## Common Pitfalls

- Lab mapping is **illustrative**: CC BY 4.0 is an attribution license, *not* public domain; `user-owned + consent` does not prove a scraping opt-out check. Not legal evidence.
- UNCLASSIFIED is an audit finding — never default it into a bucket.
- Row-count replay can't detect changed or duplicated content → store a fingerprint too.
- A pinned version may contain data later subject to erasure → [data-lifecycle-and-erasure](data-lifecycle-and-erasure.md).

📘 **Context / Not implemented in this lab:** EU AI Act Art. 10 governs data quality for high-risk systems but does not define these four buckets; MLflow ↔ Delta version linking.

## Related Concepts

[time-travel-and-versioning](time-travel-and-versioning.md) · [partitioning](partitioning.md) · [agent-data-access](agent-data-access.md) · [medallion-architecture](medallion-architecture.md)

## Key Takeaways

- One integer (version) makes a run reproducible; a fingerprint makes it verifiable.
- Provenance = columns captured at ingest + partitioned for exclusion.
- Governance rules belong in queryable SQL, not in documents.
