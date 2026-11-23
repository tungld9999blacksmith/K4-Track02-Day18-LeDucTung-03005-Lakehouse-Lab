# Lakehouse vs Alternatives

[← README](../README.md) · Mostly 📘 **Context / Not implemented in this lab** — only the lakehouse column was practiced; the others explain why it exists. Rows grounded in lab evidence are marked ✅.

## Data Lake vs Data Warehouse vs Lakehouse

| Aspect | Data Lake | Data Warehouse | Lakehouse |
|---|---|---|---|
| Storage | Open files on object storage, cheap | Proprietary managed storage | Open files (Parquet) on cheap storage ✅ |
| Processing | Any engine, no coordination | Built-in SQL engine | Any engine via table format (DuckDB, Polars, Spark) ✅ |
| Transactions | None — partial writes visible, orphans | Full ACID | ACID via log/metadata ✅ NB1, NB3 |
| Schema | On read; bad data lands silently | Enforced | Enforced, opt-in evolution, field-IDs ✅ NB1, NB5 |
| History | None | Usually limited | Versions, time travel, RESTORE ✅ NB3 |
| Performance | Depends on file layout; small-file problem | Engine-managed | Stats + compaction + clustering; **needs maintenance** ✅ NB2, NB6 |
| Analytics / BI | Possible but slow/unsafe | Excellent | Good (Gold tables) ✅ NB4 |
| ML / AI | Direct file access | Export required | Same tables for SQL, Python, vectors, agents ✅ NB7, NB8 |
| Governance | Weak | Strong, centralized | Catalog + columns/partitions for provenance ✅ NB5, NB8 |
| Cost | Lowest storage; hidden request/garbage costs | Highest | Low storage; pay in maintenance jobs ✅ NB6 ($4/day vs $0.08/day requests) |
| Best fit | Raw archival, exploratory | Curated BI, strict SLAs | One platform for BI + ML/AI on open data |

## ETL vs ELT

| | ETL | ELT (what the lab did) |
|---|---|---|
| Order | Transform before loading into target | Load raw first, transform inside the platform |
| Raw data kept? | Often not | Yes — Bronze ✅ |
| Reprocessing | Re-extract from source | Re-run Silver/Gold from Bronze ✅ |
| Lab example | — | NB4: raw JSON in Bronze → DuckDB transforms → Silver/Gold |

## Lambda vs Kappa (📘 context only)

| | Lambda | Kappa |
|---|---|---|
| Idea | Separate batch layer + speed (stream) layer, merged at serving | One streaming pipeline; reprocess by replaying the log |
| Pain | Two codebases, reconciliation | Needs replayable stream & stateful streaming |
| Lakehouse relation | A lakehouse table can serve both batch and streaming writers (micro-batches) — the lab simulated micro-batch appends (NB2, NB6) but no streaming engine | CDF (✅ NB7) is the table-level change stream a Kappa-style consumer would read |

## Separate vector DB vs vectors in the lakehouse

| | External vector DB as source of truth | Lakehouse as system of record |
|---|---|---|
| Deletes | Lost unless sync carries them (lab: 8 erased docs still retrievable) | Enforced by table; propagate via CDF |
| Governance filters | Separate system → sync or post-filter | Same row: `WHERE consent_train AND license <> 'unknown'` |
| Latency at scale | ANN indexes, ms-level | Brute force O(n) (~14 s at 1M extrapolated) |
| Best use | Derived, rebuildable serving index | Truth, analytics, offline evaluation |

## Key Takeaways

- Lakehouse wins on "one copy for BI + AI" — but only if you run the maintenance jobs.
- ELT + Bronze keeps raw truth replayable.
- Vector DBs and warehouses can still exist, as **derived** stores fed by change events.
