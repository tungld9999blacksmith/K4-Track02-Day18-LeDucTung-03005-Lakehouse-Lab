# 02 — Architecture of the Lab

[← README](README.md) · Prev: [01 — Overview](01-lakehouse-overview.md) · Next: [03 — Data flow](03-data-flow.md)

✅ **Implemented in this lab** (lightweight path). The Spark path is 📘 context only — see [spark-minio-docker](technologies/spark-minio-docker.md).

## Component diagram (actual implementation)

```mermaid
flowchart LR
    subgraph Sources["Synthetic sources (scripts/)"]
        G1["generate_data_lite.py<br/>200K LLM call logs"]
        G2["generate_ai_data.py<br/>2,000 docs + emb + 200 blobs<br/>agent traces"]
        NB["In-notebook generators<br/>(NB1–3, NB5, NB6)"]
    end

    subgraph Storage["_lakehouse/ (local filesystem)"]
        BR["bronze/<br/>llm_calls_raw · docs_multimodal · agent_traces"]
        SI["silver/<br/>llm_calls · agent_trajectories · training_corpus_governed"]
        GO["gold/<br/>llm_daily_metrics · agent_performance"]
        SC["scratch/<br/>per-notebook experiment tables"]
        BL["blobs/*.bin<br/>(pointer targets)"]
        IC["iceberg/nb5|nb6|nb8/<br/>catalog.db + warehouse/"]
    end

    subgraph Formats["Table formats"]
        DL["Delta Lake<br/>_delta_log/*.json + checkpoints"]
        IB["Apache Iceberg<br/>metadata.json → manifest list → manifests"]
    end

    CAT["PyIceberg SqlCatalog<br/>(SQLite)"]

    subgraph Engines["Compute / query"]
        DD["DuckDB SQL"]
        PL["Polars"]
        PA["PyArrow / NumPy"]
    end

    subgraph Consumers
        DASH["Gold metrics<br/>(dashboards)"]
        RAG["Semantic search / RAG"]
        AG["Agent via LakehouseMCP<br/>(simulated)"]
        TR["Training run<br/>(version pin)"]
    end

    G1 --> BR
    G2 --> BR
    G2 --> BL
    NB --> SC
    BR -->|DuckDB parse/dedup| SI --> GO
    BR & SI & GO & SC --- DL
    IC --- IB
    CAT --> IC
    DL -->|to_pyarrow_table| PA --> DD & PL
    IB -->|scan / plan_files| PA
    GO --> DASH
    BR --> RAG
    CAT --> AG
    SI --> TR
```

## Components

| Component | Technology | Role | Why it exists |
|---|---|---|---|
| Storage | Local disk under `_lakehouse/` (root overridable via `LAKEHOUSE_ROOT`) | Holds every file of every table | Lightweight, offline; same layout an object store would hold |
| File format | Parquet (snappy; delta-rs OPTIMIZE wrote zstd) | Columnar data files with footer stats | Column pruning, compression, per-file min/max |
| Table format A | Delta Lake via `deltalake` 1.6.6 | ACID log, versions, MERGE/DELETE, OPTIMIZE, VACUUM, CDF | Turns Parquet folders into tables (NB1–4, 6–8) |
| Table format B | Apache Iceberg via `pyiceberg` 0.12.0 | Snapshots, hidden partitioning, field-IDs, spec evolution | Second format; catalog-centric design (NB5, 6, 8) |
| Catalog | `SqlCatalog` on SQLite, **one per notebook** (`nb5`, `nb6`, `nb8`) | Registers tables, owns location + current-metadata pointer | Catalog = control plane; isolation avoids cross-notebook resets |
| SQL engine | DuckDB 1.5.6 | JSON parsing, dedup, quantiles, joins, `array_cosine_similarity` | In-process SQL over Arrow, no server, no extension download |
| DataFrames | Polars 1.44.2 | Build/print frames, row hashing | Fast, Arrow-native |
| Interchange | Apache Arrow (pyarrow 25.0.1) | Zero-copy hand-off Delta/Iceberg ↔ DuckDB/Polars | Avoids DuckDB `delta_scan()` network extension |
| Helpers | `scripts/lakehouse.py` | `path()`, `reset()`, `catalog()`, `reset_catalog()`, `du()`, `count_files()`, `to_arrow()` | Consistent paths + idempotent reruns |
| Agent surface | `LakehouseMCP` class (NB8) | Cached list, confirmation, tasks, per-tool metering | Models the agent ↔ catalog boundary (simulation, not a server) |
| Notebooks | Jupyter Lab + Jupytext | `.py` percent files → `.ipynb` | Reviewable diffs |
| Validation | `verify_lite.py` (9 checks), `pytest` (24 tests), `run_all.py` | Smoke, invariants/canaries, end-to-end | Reproducibility gate |

## Storage layout on disk (as created)

```text
_lakehouse/
├── bronze/   llm_calls_raw/ · docs_multimodal/ · agent_traces/        (Delta)
├── silver/   llm_calls/date=…/ · agent_trajectories/agent_version=…/ ·
│             training_corpus_governed/provenance_bucket=…/            (Delta, partitioned)
├── gold/     llm_daily_metrics/date=…/ · agent_performance/            (Delta)
├── scratch/  users_delta · events_smallfiles · customers_tt · maint_events ·
│             media_inline · media_pointer · emb_f32 · emb_int8 · docs_cdf · …
├── blobs/    *.bin   (200 × 64 KB media frames)
└── iceberg/  nb5/ · nb6/ · nb8/   → catalog.db + warehouse/lake/<table>/{data,metadata}
```

## Delta vs Iceberg internals (side by side)

```mermaid
flowchart TB
    subgraph Delta["Delta table directory"]
        D1["part-*.parquet"]
        D2["_delta_log/000…N.json<br/>commitInfo · protocol · metaData · add · remove"]
        D3["_delta_log/…checkpoint.parquet + _last_checkpoint"]
        D2 --> D1
        D3 --> D2
    end
    subgraph Iceberg["Iceberg table"]
        C["Catalog (SQLite)<br/>pointer → current metadata.json"]
        M["metadata/NNNNN-uuid.metadata.json<br/>schemas · specs · snapshots"]
        L["metadata/snap-*.avro<br/>manifest list (1 per snapshot)"]
        F["metadata/*-m0.avro<br/>manifests: file stats + partition values"]
        DF["data/ts_day=…/*.parquet"]
        C --> M --> L --> F --> DF
    end
```

Read more: [transaction-log-and-acid](concepts/transaction-log-and-acid.md) · [catalog-and-metadata](concepts/catalog-and-metadata.md)

## Key Takeaways

- Everything is files on disk; the **table format** and **catalog** are what make them tables.
- Engines are interchangeable because they meet at **Arrow** and **Parquet**.
- Each notebook owns its catalog and scratch tables → reruns are idempotent and isolated.
