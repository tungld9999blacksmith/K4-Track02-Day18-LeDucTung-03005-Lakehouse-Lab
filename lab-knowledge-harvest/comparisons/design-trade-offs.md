# Design Trade-offs Inside the Lakehouse

[← README](../README.md) · ✅ every comparison below was exercised in the lab (with measured evidence) unless marked 📘

## Delta Lake vs Apache Iceberg

| Aspect | Delta (delta-rs) | Iceberg (pyiceberg) |
|---|---|---|
| Commit mechanism | Next JSON in `_delta_log/` | Catalog swaps pointer to new metadata.json |
| Catalog needed? | No (path-addressed in lab) | Yes (SQLite `SqlCatalog`) |
| Partitioning | Directory columns (`partition_by`) | Hidden transforms (`day(ts)`), evolvable specs |
| Rename column | Needs column mapping (📘 not used) | Metadata-only via field-IDs ✅ |
| Change feed | `load_cdf()` ✅ | 📘 not used |
| Python maintenance | compact, z_order, vacuum, checkpoint ✅ | expire_snapshots only; compaction/orphans need Spark/Java |
| Expiry deletes files? | VACUUM deletes tombstoned files (not orphans) | PyIceberg expiry deletes **nothing** (lab version) |
| Metadata overhead | Log + checkpoints | 3-tier tree; 294% of data for tiny files (NB5) |
| **Pick when** | Python/Rust pipelines, MERGE/CDF-heavy, simple ops | Multi-engine, central catalog, evolving layouts |

## Partition vs Z-order

| | Partition | Z-order (clustering) |
|---|---|---|
| Granularity | Whole directories | Files within the table |
| Column cardinality | Low (date, policy, bucket) | High (`user_id`: 100K values) |
| Cost of mistakes | Too many partitions → small files | Needs periodic rewrite |
| Lab evidence | NB5 day(ts): 10 → 1 files | NB2: 55 → 1 file; NB6: 90% skip |

Use both: partition by date, cluster by the high-cardinality filter column.

## Compaction vs clustering

| | Compaction | Clustering |
|---|---|---|
| Changes | File count/size | Value ranges per file |
| Speeds up | Full scans, listing, planning | Point/range lookups (skipping) |
| Lab | 200 → 67 files, still 67/67 read | 67 → 55 files, 1/55 read |

## Inline blobs vs pointers (NB7)

| | Inline `binary` column | `blob_uri` pointer |
|---|---|---|
| Analytical scan (`GROUP BY topic`) | 1.2 KB read — column pruning protects it | 1.2 KB |
| Fetch one 64 KB frame | 12.5 MB row group (200×) | 64 KB GET |
| Lifecycle | Deleted with the row | Object must be deleted separately |
| **Pick when** | Mostly analytics, small blobs | Random access / GPU feeding |

📘 Lance-style formats aim for row-level random reads inside a table.

## float32 vs int8 embeddings (NB7)

| | float32 | int8 |
|---|---|---|
| Size on disk | 2.6 MB | 451.9 KB (5.8×) |
| recall@10 vs float32 | 1.0 (ground truth) | 0.904 |
| Topic fidelity | — | 1.000 |
| **Pick when** | Exact ranking matters | Storage/memory bound, RAG topical retrieval (measure on your corpus) |

## In-table vectors vs external index (NB7)

See [lakehouse-vs-alternatives](lakehouse-vs-alternatives.md#separate-vector-db-vs-vectors-in-the-lakehouse). Rule: lakehouse = truth, index = derived + subscribed to deletes.

## Retention length (NB3, NB6)

| Short retention | Long retention |
|---|---|
| Cheaper storage, fast erasure | Longer RESTORE/time-travel window, reproducible runs |
| `retention_hours=0` killed time travel in NB6 | Pinned versions (NB8) stay replayable — but keep erased data |

## Dedup rule (NB4)

| Keep first attempt | Keep last attempt | No dedup |
|---|---|---|
| Lab choice; often the failed try | What the user actually received | Measures true API load |

## Wall-clock vs metadata metrics

| Wall-clock speedup | Files pruned / stats |
|---|---|
| 10.3× and 14.8× on the same machine | 55× every run |
| Includes cache/CPU noise | Deterministic, explains *why* |
