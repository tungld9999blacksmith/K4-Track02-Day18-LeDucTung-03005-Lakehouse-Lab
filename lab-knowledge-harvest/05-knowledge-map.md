# 05 — Knowledge Map

[← README](README.md) · Prev: [04 — Mapping](04-lab-to-lakehouse-mapping.md)

How the concepts and technologies of this lab connect. Click-through links are in the tables below the diagram.

```mermaid
graph TD
    LH[Lakehouse]

    LH --> ST[Storage: Parquet files]
    LH --> TF[Table format]
    LH --> CAT[Catalog]
    LH --> ENG[Query engines]
    LH --> GOVN[Governance & AI]

    TF --> DELTA[Delta Lake / delta-rs]
    TF --> ICE[Apache Iceberg / pyiceberg]

    DELTA --> LOG[Transaction log + checkpoints]
    ICE --> MTREE[metadata.json → manifest list → manifests]
    CAT --> MTREE

    LOG --> ACID[ACID commits]
    MTREE --> ACID
    ACID --> VER[Versions / snapshots]
    VER --> TT[Time travel & RESTORE]
    VER --> PIN[Version pinning]

    LOG --> SCH[Schema enforcement / evolution]
    MTREE --> FID[Field-IDs → metadata-only rename]

    LOG --> STATS[Per-file min/max stats]
    MTREE --> STATS
    STATS --> SKIP[Data skipping / pruning]
    SKIP --> ZO[Z-order clustering]
    SKIP --> PART[Partitioning]
    PART --> HID[Hidden partitioning & spec evolution]

    ST --> SMALL[Small-file problem]
    SMALL --> COMP[Compaction]
    COMP --> MAINT[Table maintenance]
    ZO --> MAINT
    VER --> MAINT
    MAINT --> VAC[VACUUM / snapshot expiry]
    MAINT --> ORPH[Orphan removal]
    MAINT --> CKPT[Checkpoint]

    ENG --> ARROW[Apache Arrow interchange]
    ARROW --> DUCK[DuckDB SQL]
    ARROW --> POL[Polars]

    LH --> MED[Medallion Bronze/Silver/Gold]
    MED --> DEDUP[Dedup & typing in Silver]
    MED --> AGG[Aggregates in Gold]

    GOVN --> VEC[Embeddings as a column]
    GOVN --> LIFE[Lifecycle: DELETE, CDF, erasure]
    GOVN --> PROV[Provenance buckets]
    GOVN --> AGENT[Agent access via catalog]
    VEC --> LIFE
    TT -. conflicts with .-> LIFE
    VAC --> LIFE
    PIN -. conflicts with .-> LIFE
    PROV --> PIN
    CAT --> AGENT
```

## Where each node is documented

| Node(s) | Page |
|---|---|
| Transaction log, ACID, checkpoints | [concepts/transaction-log-and-acid.md](concepts/transaction-log-and-acid.md) |
| Schema enforcement/evolution, field-IDs | [concepts/schema-enforcement-and-evolution.md](concepts/schema-enforcement-and-evolution.md) |
| Versions, time travel, RESTORE | [concepts/time-travel-and-versioning.md](concepts/time-travel-and-versioning.md) |
| Stats, skipping, small files, compaction, Z-order | [concepts/file-layout-and-data-skipping.md](concepts/file-layout-and-data-skipping.md) |
| Partitioning, hidden partitioning, spec evolution | [concepts/partitioning.md](concepts/partitioning.md) |
| Catalog, metadata tree | [concepts/catalog-and-metadata.md](concepts/catalog-and-metadata.md) |
| Maintenance: vacuum, expiry, orphans, checkpoint | [concepts/table-maintenance.md](concepts/table-maintenance.md) |
| Medallion, dedup, aggregates | [concepts/medallion-architecture.md](concepts/medallion-architecture.md) |
| Embeddings, blobs | [concepts/vectors-and-multimodal-data.md](concepts/vectors-and-multimodal-data.md) |
| Lifecycle, CDF, erasure | [concepts/data-lifecycle-and-erasure.md](concepts/data-lifecycle-and-erasure.md) |
| Provenance, version pinning | [concepts/provenance-and-reproducibility.md](concepts/provenance-and-reproducibility.md) |
| Agent access | [concepts/agent-data-access.md](concepts/agent-data-access.md) |
| Delta, Iceberg, DuckDB, Polars, Arrow/Parquet | [technologies/](technologies/) |

## The three tensions worth remembering

| Tension | Sides | Resolved by |
|---|---|---|
| History vs storage cost | Time travel needs old files ↔ old files cost money | Retention window + VACUUM/expiry |
| Reproducibility vs erasure | Pinned versions must stay readable ↔ deleted subjects must disappear | Retention policy, documenting erasures in model cards, retraining |
| Few big files vs prunable files | Compaction wants few files ↔ skipping needs many narrow files | `target_size` + clustering on filter columns |
