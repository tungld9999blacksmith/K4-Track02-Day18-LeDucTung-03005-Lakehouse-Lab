# Lakehouse Lab Knowledge Base

> Personal knowledge harvested from **K4-Track02-Day18 — Data Lakehouse Architecture** (lightweight Python path).
> Open this folder instead of re-running the lab.

## Purpose

Preserve what the lab taught — concepts, tools, commands, measured numbers and pitfalls —
organized by **Lakehouse concept**, not by notebook order, so a specific topic can be found in seconds.

**Status markers used everywhere:**

| Marker | Meaning |
|---|---|
| ✅ **Implemented in this lab** | I ran it; numbers come from my own runs (Windows 11, Python 3.13.3) |
| 📘 **Context / Not implemented in this lab** | Background needed to understand the ecosystem; not practiced |

## Lab Summary

Eight notebooks built and *measured* a local lakehouse with no JVM, Docker or cloud:

| NB | Topic | Headline result (my run) |
|---|---|---|
| 1 | Delta transaction log, schema enforcement/evolution | Bad-type write blocked, `tier` added via opt-in merge |
| 2 | Small files, OPTIMIZE + Z-order | 200 → 55 files, 1/55 files read → **55× pruning** |
| 3 | MERGE, time travel, RESTORE | 50K update + 50K insert; RESTORE = 1 `remove` action |
| 4 | Medallion Bronze → Silver → Gold (LLM observability) | 200,000 → 190,052 rows (dedup) → 24 Gold rows |
| 5 | Iceberg + catalog, hidden partitioning, evolution | **10× pruning** filtering on `ts`; rename keeps field-id 4 |
| 6 | Table maintenance (5 jobs) | 200 → 11 files; 90% skip; 16.1 MB reclaimed; 3 orphans |
| 7 | Blobs & embeddings in tables, lifecycle bug | 200× random-read amplification; int8 5.8× smaller |
| 8 | Agent trajectories, MCP-style access, provenance | Version pin replays 1,578 steps; 4 provenance buckets |

## Lakehouse Mental Model

```text
 raw events / docs / blobs ──► Bronze (raw Delta)          ┐
                                   │ parse · dedup · type   │  open files (Parquet)
                                   ▼                        │  + table format
                               Silver (clean Delta/Iceberg) │  (Delta log / Iceberg metadata)
                                   │ aggregate              │  + catalog
                                   ▼                        │
                               Gold (metrics)               ┘
                                   │
        DuckDB / Polars SQL ◄──────┴──────► agents · RAG · training runs
        (any engine reads the same files)    (version-pinned, governed)
```

Details: [02-architecture.md](02-architecture.md) · [03-data-flow.md](03-data-flow.md) · [05-knowledge-map.md](05-knowledge-map.md)

## Big Picture

| Page | Answers |
|---|---|
| [01 — Lakehouse overview](01-lakehouse-overview.md) | What is a lakehouse, why, what this lab demonstrates |
| [02 — Architecture](02-architecture.md) | Components, technologies, why each exists |
| [03 — Data flow](03-data-flow.md) | Step-by-step movement of data, in → out |
| [04 — Lab → Lakehouse mapping](04-lab-to-lakehouse-mapping.md) | Which lab step taught which lakehouse idea |
| [05 — Knowledge map](05-knowledge-map.md) | How all concepts connect |

## Core Concepts

| Concept | Page |
|---|---|
| Transaction log & ACID commits | [concepts/transaction-log-and-acid.md](concepts/transaction-log-and-acid.md) |
| Schema enforcement, evolution, field-IDs | [concepts/schema-enforcement-and-evolution.md](concepts/schema-enforcement-and-evolution.md) |
| Time travel, versions, snapshots, RESTORE | [concepts/time-travel-and-versioning.md](concepts/time-travel-and-versioning.md) |
| Small files, compaction, Z-order, data skipping | [concepts/file-layout-and-data-skipping.md](concepts/file-layout-and-data-skipping.md) |
| Partitioning (Hive-style, hidden, evolution) | [concepts/partitioning.md](concepts/partitioning.md) |
| Medallion architecture | [concepts/medallion-architecture.md](concepts/medallion-architecture.md) |
| Catalog & metadata tree | [concepts/catalog-and-metadata.md](concepts/catalog-and-metadata.md) |
| Table maintenance (vacuum, expiry, orphans, checkpoints) | [concepts/table-maintenance.md](concepts/table-maintenance.md) |
| Vectors & multimodal data in tables | [concepts/vectors-and-multimodal-data.md](concepts/vectors-and-multimodal-data.md) |
| Data lifecycle, deletes, CDF, erasure | [concepts/data-lifecycle-and-erasure.md](concepts/data-lifecycle-and-erasure.md) |
| Provenance & reproducibility (version pinning) | [concepts/provenance-and-reproducibility.md](concepts/provenance-and-reproducibility.md) |
| Agents as data consumers (MCP-style surface) | [concepts/agent-data-access.md](concepts/agent-data-access.md) |

## Technologies Used

| Technology | Role | Page |
|---|---|---|
| Delta Lake (`deltalake` / delta-rs 1.6.6) | Table format #1 (NB1–4, 6–8) | [technologies/delta-lake.md](technologies/delta-lake.md) |
| Apache Iceberg (`pyiceberg` 0.12.0 + SQLite catalog) | Table format #2 + catalog (NB5, 6, 8) | [technologies/apache-iceberg.md](technologies/apache-iceberg.md) |
| DuckDB 1.5.6 | SQL engine, JSON parsing, vector search | [technologies/duckdb.md](technologies/duckdb.md) |
| Polars 1.44.2 | DataFrame building/printing, hashing | [technologies/polars.md](technologies/polars.md) |
| Apache Arrow (pyarrow 25) & Parquet | In-memory interchange + on-disk file format | [technologies/apache-arrow-and-parquet.md](technologies/apache-arrow-and-parquet.md) |
| Jupyter Lab + Jupytext | Notebooks stored as `.py` | [technologies/jupyter-and-jupytext.md](technologies/jupyter-and-jupytext.md) |
| Spark + MinIO + Docker Compose | Optional path 📘 (not run) | [technologies/spark-minio-docker.md](technologies/spark-minio-docker.md) |

## Practical Techniques

| Need | Page |
|---|---|
| Setup / run / test / clean commands | [techniques/commands.md](techniques/commands.md) |
| Reusable SQL (dedup, quantiles, vector search, pruning checks) | [techniques/sql.md](techniques/sql.md) |
| Python API patterns (`deltalake`, `pyiceberg`, Parquet footer) | [techniques/code-patterns.md](techniques/code-patterns.md) |
| Config, env vars, table properties, tuning knobs | [techniques/configuration.md](techniques/configuration.md) |
| Errors I hit and how I fixed them | [techniques/troubleshooting.md](techniques/troubleshooting.md) |

## Comparisons

- [Lakehouse vs Data Lake vs Warehouse, ETL/ELT, Lambda/Kappa](comparisons/lakehouse-vs-alternatives.md)
- [Design trade-offs inside the lakehouse](comparisons/design-trade-offs.md) — Delta vs Iceberg, Z-order vs partition, inline vs pointer blobs, float32 vs int8, in-table vs external vector index

## What I Learned

1. A "table" is **Parquet files + a log/metadata tree**; the log, not the directory listing, decides what is in the table.
2. Old data is **never edited in place** — every write (MERGE, DELETE, OPTIMIZE) is copy-on-write + a new version.
3. **Unreferenced ≠ physically deleted.** Tombstones, expired snapshots and orphans all keep costing storage until a separate job removes them.
4. Compaction reduces *cost per file*; clustering (Z-order) reduces *number of files read*. You need both.
5. Hidden partitioning removes the "forgot the partition predicate" failure mode; field-IDs make rename metadata-only.
6. Stats-based metrics (files pruned) are deterministic; wall-clock speedups are noise on a laptop.
7. A DELETE in the current version does not erase history — time travel still returns it until VACUUM. Reproducibility (version pins) and erasure collide.
8. Embeddings are data with a lifecycle; external indexes must consume **delete** events (CDF) or they leak erased data.
9. Verify engine behaviour yourself — several printed lab outputs were misleading (see [troubleshooting](techniques/troubleshooting.md)).

## Quick Reference

- "What command was it?" → [techniques/commands.md](techniques/commands.md)
- "How did I write that SQL?" → [techniques/sql.md](techniques/sql.md)
- "What's the delta-rs / pyiceberg call?" → [techniques/code-patterns.md](techniques/code-patterns.md)
- "Why did it fail?" → [techniques/troubleshooting.md](techniques/troubleshooting.md)
- "What numbers did I measure?" → [04-lab-to-lakehouse-mapping.md](04-lab-to-lakehouse-mapping.md)
- Source of truth for the lab itself: [`../notebooks/`](../notebooks/), [`../scripts/lakehouse.py`](../scripts/lakehouse.py), [`../docs/`](../docs/)
