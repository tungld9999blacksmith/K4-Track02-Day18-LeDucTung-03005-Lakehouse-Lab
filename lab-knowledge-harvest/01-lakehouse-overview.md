# 01 — Lakehouse Overview

[← README](README.md) · Next: [02 — Architecture](02-architecture.md)

## What is a Lakehouse?

A **lakehouse** stores data as open files (Parquet) in cheap storage — like a data lake — and adds an
**open table format** (Delta Lake, Apache Iceberg) plus a **catalog** so those files behave like
warehouse tables: ACID commits, schemas, versions, statistics for skipping, and governance.
Any engine (DuckDB, Polars, Spark, Trino…) can read the same tables.

```text
Lakehouse = open files (Parquet)  +  table format (log / metadata)  +  catalog  +  any engine
```

## What problem does it solve?

| Problem (without lakehouse) | Lakehouse answer | Seen in lab |
|---|---|---|
| Lake: half-written jobs leave garbage, readers see partial data | Atomic commits via log / metadata pointer | ✅ NB1 (failed write left no commit), NB6 (orphans) |
| Lake: no schema → bad data silently lands | Schema enforcement; opt-in evolution | ✅ NB1 |
| Lake: no history, no rollback | Versions/snapshots, time travel, RESTORE | ✅ NB3, NB5 |
| Lake: slow queries over many files | Per-file stats + compaction + clustering → data skipping | ✅ NB2, NB6 |
| Warehouse: proprietary storage, data copied out for ML/AI | One copy of open files read by SQL *and* Python/ML | ✅ NB4 (DuckDB + Polars on same Delta), NB7 (vectors in table) |
| Separate ETL into a warehouse duplicates data and logic | Medallion layers in the same storage | ✅ NB4, NB8 |

## Lakehouse vs Data Lake vs Data Warehouse (short)

| | Data Lake | Data Warehouse | Lakehouse |
|---|---|---|---|
| Storage | Open files, cheap | Proprietary, managed | Open files, cheap |
| Transactions | None | Yes | Yes (via table format) |
| Schema | On read | Enforced | Enforced + evolvable |
| ML/AI access | Direct files | Export needed | Direct files, same tables |

Full comparison: [comparisons/lakehouse-vs-alternatives.md](comparisons/lakehouse-vs-alternatives.md)

## Core characteristics (as practiced)

1. **Transaction log / metadata tree** — [transaction-log-and-acid](concepts/transaction-log-and-acid.md)
2. **Schema management** — [schema-enforcement-and-evolution](concepts/schema-enforcement-and-evolution.md)
3. **Versioning** — [time-travel-and-versioning](concepts/time-travel-and-versioning.md)
4. **Stats-driven performance** — [file-layout-and-data-skipping](concepts/file-layout-and-data-skipping.md), [partitioning](concepts/partitioning.md)
5. **Catalog as control plane** — [catalog-and-metadata](concepts/catalog-and-metadata.md)
6. **Mandatory maintenance** — [table-maintenance](concepts/table-maintenance.md)
7. **AI workloads on the same tables** — [vectors-and-multimodal-data](concepts/vectors-and-multimodal-data.md), [agent-data-access](concepts/agent-data-access.md), [provenance-and-reproducibility](concepts/provenance-and-reproducibility.md)

## How the technologies in this lab fit together

| Layer | Technology in this lab |
|---|---|
| Storage | Local filesystem `_lakehouse/` (📘 MinIO/S3 on the Spark path) |
| File format | Parquet (written via Arrow) |
| Table format | Delta Lake via `deltalake` (delta-rs); Apache Iceberg via `pyiceberg` |
| Catalog | PyIceberg `SqlCatalog` on SQLite (one per notebook) |
| Compute / query | DuckDB (SQL), Polars (DataFrames), PyArrow, NumPy |
| Interface | Jupyter notebooks (Jupytext `.py`) |

## What the lab demonstrates

- The lakehouse guarantees **and** their costs: every guarantee leaves extra files/metadata that need maintenance.
- Two table formats solving the same problems differently (Delta log vs Iceberg catalog + metadata tree).
- The lakehouse as **system of record for AI**: embeddings, agent trajectories, provenance and version pins.
- Engine-specific behaviour that must be verified (delta-rs VACUUM ignores uncommitted orphans; PyIceberg expiry does not delete files).

### Key Takeaways

- Lakehouse = lake economics + warehouse guarantees, via a table format and a catalog.
- Guarantees come from **metadata**, so metadata must be maintained like data.
- One copy of data serves BI, ML and agents — if lifecycle and governance live in the table.
