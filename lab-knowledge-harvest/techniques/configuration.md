# Configuration Reference

[← README](../README.md) · ✅ lightweight path configs I used · 📘 Spark/Docker configs read from repo only

## Environment variables

| Variable | Used by | Effect | Why it matters |
|---|---|---|---|
| `PYTHONUTF8=1` | Python on Windows | UTF-8 stdout | Lab prints `✓ → ×`; without it `cp1252` raises `UnicodeEncodeError` |
| `LAKEHOUSE_ROOT` | `scripts/lakehouse.py` | Moves `_lakehouse/` (local path or 📘 `s3://bucket/prefix`) | Clean, isolated runs (I used it to run `run_all` while kernels held files) |
| 📘 `MINIO_ENDPOINT` | `spark_session.py` | S3A endpoint (default `http://minio:9000`) | Compose DNS vs Apple container IP |
| 📘 `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` | Spark S3A | Credentials → use `YOUR_ACCESS_KEY` / `YOUR_SECRET_KEY` outside the lab | Lab defaults are sandbox-only |
| 📘 `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` | Spark container | S3 client config | — |
| 📘 `SPARK_IVY_DIR` | Spark | Writable Maven/Ivy cache | JVM dies if Ivy can't write |
| `SIM_FAST=1` | 📘 `tests/simulate_students.py` | Skip venv-building scenarios | Unix only |

## Dependency pins (`requirements.txt`)

| Package | Range | Installed | Reason |
|---|---|---|---|
| deltalake | `>=1.0,<2.0` | 1.6.6 | 1.x API: `file_uris()`, `load_cdf()`, `repair()`, `compact_logs()` |
| pyiceberg[sql-sqlite,pyarrow,pyiceberg-core] | `>=0.9,<1.0` | 0.12.0 | SQLite catalog + transforms |
| duckdb | `>=1.1,<2.0` | 1.5.6 | Core `array_cosine_similarity` (no extension download) |
| polars | `>=1.13.2,<2.0` | 1.44.2 | 1.13.1 was yanked |
| pyarrow | `>=17,<26` | 25.0.1 | — |
| numpy | `>=1.26,<3.0` | 2.5.3 | NB7 embeddings |
| jupyterlab / jupytext / pytest | 4.x / 1.x / 8–9 | 4.6.4 / 1.19.5 / 9.1.1 | — |

Ranges are not a lockfile → record installed versions with `pip list` when results matter.

## Table-level settings

| Setting | Value in lab | Production guidance | Why |
|---|---|---|---|
| Delta `delta.enableChangeDataFeed` | `"true"` on CDF table | Enable for tables with downstream copies | Deletes propagate as events |
| Delta `partition_by` | `date`, `agent_version`, `provenance_bucket` | Low-cardinality filter columns only | Directory pruning |
| `target_size` (compact/z_order) | 256 KB (NB2), 1 MB (NB6) | 128–512 MB | Lab keeps many files to show pruning |
| `vacuum(retention_hours=…)` | 0 + `enforce_retention_duration=False` | ≥ 168 h, guard on | 0 destroys time travel / breaks readers |
| Orphan `min_age_hours` | 24 | > longest writer runtime | Prevent deleting in-flight files |
| Iceberg spec | `day(ts)` → + `identity(model)` | Transform on the filtered source column | Hidden partitioning |
| Iceberg `nullable=False` | `event_id`, `ts` | Mark truly required fields | Required fields can't be dropped silently |
| 📘 `write.metadata.delete-after-commit.enabled`, `write.metadata.previous-versions-max` | not set | Set to cap old metadata.json | 22 old metadata.json remained in NB6 |
| Iceberg expiry `KEEP_LAST` | 3 | Time-based retention | — |

## Catalog configuration

```python
SqlCatalog(name,
           uri=f"sqlite:///{ROOT}/iceberg/{name}/catalog.db",
           warehouse=f"file://{ROOT}/iceberg/{name}/warehouse")
# 📘 production
load_catalog("prod", type="rest", uri="https://YOUR_ENDPOINT/api/catalog",
             credential="YOUR_CLIENT_ID:YOUR_CLIENT_SECRET")
```

## Query-engine settings

| Setting | Value | Why |
|---|---|---|
| DuckDB `TimeZone` | default = host (`Asia/Bangkok`) | Set `UTC` before `CAST(ts AS DATE)` |
| MCP-sim `list_ttl_ms` | 60,000 | Cache vs freshness |
| MCP-sim `query` limit cap | 100 rows | Agent guardrail |

## Tooling settings

| Setting | Value | Why |
|---|---|---|
| VS Code `notebook.output.textLineLimit` | raise from 30 → 200 | Full outputs for screenshots |
| `pytest.ini` | `testpaths = tests`, `addopts = -q --tb=short` | — |
| `.gitignore` | `_lakehouse/`, `.venv/`, `notebooks/*.ipynb` | Submit executed copies under `submission/` instead |

## 📘 Spark session (from `scripts/spark_session.py`)

Key properties: `spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension`, `spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog`, `fs.s3a.endpoint`, `fs.s3a.path.style.access=true`, `spark.sql.shuffle.partitions=8`, package `org.apache.hadoop:hadoop-aws:3.3.4`. Details: [spark-minio-docker](../technologies/spark-minio-docker.md).
