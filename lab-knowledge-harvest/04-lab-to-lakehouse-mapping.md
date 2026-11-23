# 04 — Lab → Lakehouse Mapping

[← README](README.md) · Prev: [03 — Data flow](03-data-flow.md) · Next: [05 — Knowledge map](05-knowledge-map.md)

> "What did each lab step teach me about lakehouse architecture?"
> All rows ✅ **Implemented in this lab**; numbers are from my runs (deterministic unless marked *timing*).

## Foundations (NB1–NB4)

| Lab step | Actual technology | Concept | Lakehouse role | Measured | Why it matters |
|---|---|---|---|---|---|
| NB1 write + read `_delta_log/000…0.json` | `write_deltalake`, JSON log | [Transaction log](concepts/transaction-log-and-acid.md) | Table format | 4 actions: `commitInfo`, `protocol`, `metaData`, `add`(+stats) | Table = files + log; stats enable skipping |
| NB1 append `age="thirty"` | delta-rs cast check | [Schema enforcement](concepts/schema-enforcement-and-evolution.md) | Data quality at write | `Cast error`, no new commit; `"30"` **accepted** (castable) | Enforcement is cast-based, not semantic |
| NB1 append with `tier`, `schema_mode="merge"` | delta-rs | [Schema evolution](concepts/schema-enforcement-and-evolution.md) | Schema management | v1 has new `metaData`; old rows `tier=null`, no rewrite | Evolution is opt-in and cheap |
| NB2 200 appends | delta-rs | [Small files](concepts/file-layout-and-data-skipping.md) | Storage layout | 200 files × ~66 KB | Streaming creates file explosion |
| NB2 `compact()` then `z_order(["user_id"])` | delta-rs OPTIMIZE | [Compaction vs clustering](concepts/file-layout-and-data-skipping.md) | Performance | 200 → 67 → 55 files; files containing 4242: 200 → 67 → **1** | Only clustering produces pruning (55×) |
| NB2 benchmark | `to_pyarrow_table(filters=…)` | Predicate pushdown | Query | 311 → 30 ms (*timing*: 10.3×; another run 14.8×) | Wall-clock is noisy; pruning ratio is not |
| NB3 MERGE 100K | `dt.merge(...).when_matched_update_all().when_not_matched_insert_all()` | [Upsert / copy-on-write](concepts/time-travel-and-versioning.md) | Write semantics | 50K updated, 50K inserted, 50K copied | Idempotent writes; Parquet is immutable |
| NB3 time travel | `DeltaTable(path, version=N)` | [Time travel](concepts/time-travel-and-versioning.md) | Versioning | v0 = 100K rows after 4 more commits | Old files kept → old versions readable |
| NB3 `restore(2)` | delta-rs | [RESTORE](concepts/time-travel-and-versioning.md) | Recovery | New v4 = 1 `remove`; `score<0`: 50 → 0; 0.02 s | Rollback is a new, auditable commit |
| NB4 Bronze → Silver | DuckDB JSON + `ROW_NUMBER` | [Medallion](concepts/medallion-architecture.md) | Refinement | 200,000 → 190,052 (9,948 retries removed) | Silver = typed, deduplicated truth |
| NB4 Silver → Gold | DuckDB `QUANTILE_CONT`, cost join | [Medallion](concepts/medallion-architecture.md) | Serving | 24 rows; p50 ≤ p95, cost > 0, error_rate 0.042–0.062 | Gold answers business questions |
| NB4 date derivation | `CAST(ts AS DATE)` | Determinism | Data quality | 8 dates (UTC+7) vs 7 (UTC) | Pipelines must not depend on host time zone |

## Lakehouse for AI (NB5–NB8)

| Lab step | Actual technology | Concept | Lakehouse role | Measured | Why it matters |
|---|---|---|---|---|---|
| NB5 `create_table` via catalog | PyIceberg `SqlCatalog` | [Catalog](concepts/catalog-and-metadata.md) | Control plane | Location chosen by catalog | Catalog owns layout + commit pointer |
| NB5 `day(ts)` spec, filter on `ts` | `plan_files()` | [Hidden partitioning](concepts/partitioning.md) | Pruning | 10 → 1 files (**10×**); ≈ $220/day saved at 10K queries | No partition column to forget |
| NB5 metadata tree | `tbl.inspect.*` | [Metadata tree](concepts/catalog-and-metadata.md) | Planning | metadata 139 KB vs data 47 KB (**294%**) | Small files bloat metadata too |
| NB5 rename `latency_ms` → `latency_millis` | `update_schema().rename_column` | [Field-IDs](concepts/schema-enforcement-and-evolution.md) | Schema evolution | field-id 4 kept; old file still physically `latency_ms` | Rename is metadata-only |
| NB5 add `identity(model)` to spec | `update_spec()` | [Partition evolution](concepts/partitioning.md) | Layout evolution | specs [1, 2] coexist; `model=opus` reads 11/13 files | Old data keeps old layout |
| NB6 compaction | `optimize.compact(1 MB)` | [Maintenance job 1](concepts/table-maintenance.md) | Ops | 200 → 11 files (18×); disk temporarily 10.1 → 16.1 MB | You pay twice until vacuum |
| NB6 clustering | `z_order` + stats count | [Job 2](concepts/table-maintenance.md) | Ops | 11/11 → 1/10 files (90% skip) | Stats are useless until clustered |
| NB6 vacuum | `vacuum(retention_hours=0)` | [Job 3](concepts/table-maintenance.md) | Ops | 211 files, 16.1 MB reclaimed; time travel lost | Retention = rollback window |
| NB6 orphans | set difference + age guard | [Job 4](concepts/table-maintenance.md) | Ops | 3 orphans found; VACUUM found **none** of them | delta-rs vacuum ignores never-committed files |
| NB6 checkpoint | `create_checkpoint()` | [Job 5](concepts/table-maintenance.md) | Ops | `_last_checkpoint` → v203 (auto ones at v99, v199) | Faster cold reads |
| NB6 Iceberg expiry | `expire_snapshots().by_ids()` | [Expiry ≠ deletion](concepts/table-maintenance.md) | Ops | 20 → 3 snapshots, avro 40 → 40; sweep 17 → avro 23 | Expiry and orphan removal are a pair |
| NB7 inline vs pointer blobs | Parquet footer | [Multimodal storage](concepts/vectors-and-multimodal-data.md) | Storage design | scan 1.2 KB of 12.5 MB; random read **200×** | Choose layout by access pattern |
| NB7 int8 embeddings | NumPy + delta-rs | [Quantization](concepts/vectors-and-multimodal-data.md) | Storage/AI | 5.8× smaller, recall@10 0.904, topic fidelity 1.000 | Measure both metrics |
| NB7 vector SQL + filter | DuckDB `array_cosine_similarity` | [Vectors in tables](concepts/vectors-and-multimodal-data.md) | Retrieval | Top-5 on-topic; unlicensed query doc filtered out | Governance + similarity in one query |
| NB7 erasure vs external index | `dt.delete`, copy table | [Lifecycle bug](concepts/data-lifecycle-and-erasure.md) | Governance | table 0 hits, external 8 hits | Derived indexes leak deletes |
| NB7 CDF | `load_cdf()` | [CDF](concepts/data-lifecycle-and-erasure.md) | Propagation | 8 delete events | Deletes as first-class events |
| NB8 trajectories by policy | DuckDB + `partition_by=["agent_version"]` | [Medallion for RL](concepts/medallion-architecture.md) | AI data | 2 partitions; 150 trajectories each | Slice/drop data per policy |
| NB8 version pin | `DeltaTable(path, version=0)` | [Reproducibility](concepts/provenance-and-reproducibility.md) | Lineage | 1,578 steps match; content fingerprint match | One integer makes a run reproducible |
| NB8 MCP-style access | `LakehouseMCP` | [Agent access](concepts/agent-data-access.md) | Serving | 5 turns → 1 catalog read; `input_required` | Agent boundary: cache, confirm, tasks, meter |
| NB8 provenance buckets | `CASE` + `partition_by` | [Provenance](concepts/provenance-and-reproducibility.md) | Governance | 1,666 trainable / 334 UNCLASSIFIED | Capture origin at ingest |
| NB8 subject deletion | `dt.delete` + time travel | [Erasure vs pinning](concepts/data-lifecycle-and-erasure.md) | Governance | current 0, pinned v0 still 8 (3 trainable) | Reproducibility conflicts with erasure |

## Key Takeaways

- Every lakehouse feature in the lab was **measured by metadata** (file counts, stats, versions), not just asserted.
- NB1–4 = what a table format guarantees; NB5–6 = what it costs to keep those guarantees; NB7–8 = what AI workloads additionally demand.
