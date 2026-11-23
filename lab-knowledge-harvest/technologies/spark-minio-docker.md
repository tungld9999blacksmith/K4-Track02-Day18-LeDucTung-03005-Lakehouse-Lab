# Spark + delta-spark + MinIO (Docker Compose) — optional path

[← README](../README.md) · 📘 **Context / Not implemented in this lab** — the repo ships this path (`infra/`, `notebooks-spark/`), but I used the lightweight path for all 8 notebooks. Contents below are read from the config files, not from a run.

## What Is It?

A production-fidelity variant of NB1–NB4: PySpark 3.5 + `delta-spark` 3.2.0 writing Delta tables to **MinIO** (S3-compatible object storage) via `s3a://`.

## Role in the Lakehouse

Distributed compute engine (Spark) + object storage (MinIO) — the "real" deployment shape of what the lab did locally.

## Components (from `infra/docker-compose.yml`)

| Service | Image | Ports | Purpose |
|---|---|---|---|
| `minio` | `minio/minio:latest` | 9000 (S3 API), 9001 (console) | Object storage |
| `minio-init` | `minio/mc:latest` | — | Creates buckets `lakehouse`, `bronze`, `silver`, `gold` |
| `spark` | `quay.io/jupyter/pyspark-notebook:spark-3.5.0` | 8888 (Jupyter), 4040 (Spark UI) | Spark + Jupyter; pip-installs delta-spark, jupytext, deltalake, pyiceberg, duckdb, polars |

## Important Configuration (`scripts/spark_session.py`)

```python
.config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
.config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog")
.config("spark.hadoop.fs.s3a.endpoint", os.environ.get("MINIO_ENDPOINT", "http://minio:9000"))
.config("spark.hadoop.fs.s3a.access.key", os.environ.get("MINIO_ROOT_USER", "YOUR_ACCESS_KEY"))
.config("spark.hadoop.fs.s3a.secret.key", os.environ.get("MINIO_ROOT_PASSWORD", "YOUR_SECRET_KEY"))
.config("spark.hadoop.fs.s3a.path.style.access", "true")
.config("spark.sql.shuffle.partitions", "8")
# + extra package org.apache.hadoop:hadoop-aws:3.3.4, Ivy dir from SPARK_IVY_DIR
```
(The lab uses local-only default MinIO credentials; never reuse them outside a sandbox.)

## Spark ↔ delta-rs equivalents

| Spark SQL / API | delta-rs (what I ran) |
|---|---|
| `df.write.format("delta").save("s3a://lakehouse/users_delta")` | `write_deltalake(path, arrow_tbl)` |
| `.option("mergeSchema", "true")` | `schema_mode="merge"` |
| `.option("overwriteSchema", "true")` | `schema_mode="overwrite"` |
| `spark.read.format("delta").option("versionAsOf", 0)` | `DeltaTable(path, version=0)` |
| `DESCRIBE HISTORY delta.\`path\`` | `DeltaTable(path).history()` |
| `OPTIMIZE delta.\`path\` ZORDER BY (user_id)` | `dt.optimize.compact()` + `dt.optimize.z_order(["user_id"])` |
| `MERGE INTO` / `DeltaTable.forPath(spark, p).merge(...)` | `dt.merge(...).execute()` |
| `RESTORE` | `dt.restore(N)` |
| `DESCRIBE DETAIL` → `numFiles` | `len(dt.file_uris())` |

## Commands (not run by me)

```bash
make spark-up      # docker compose -f infra/docker-compose.yml up -d
make spark-smoke   # … exec -T spark python /workspace/scripts/verify.py
make spark-data    # 1M-row Bronze with Spark
make spark-down    # stop (data kept) · make spark-clean = down -v
```
Jupyter http://localhost:8888 (token configured in compose), MinIO console http://localhost:9001. Apple `container` variant: `make apple-*` via `infra/apple_container.sh` (macOS only).

## Gotchas documented in the config

- `PYTHONPATH` must *extend* the image's Spark paths or `import pyspark` breaks.
- Ivy cache must be writable (`~/.cache/ivy`), else the JVM dies before Py4J starts.
- Compose interpolates `$` → literal dollars must be doubled `$$`.
- Readers can't always cross-read between paths (protocol/table-feature versions differ).

## Key Takeaways

- Same Delta format, different binding; the lightweight path teaches the same concepts at ~600 MB RAM vs ~6 GB.
- Object storage + Spark is where request costs and small files hurt most.
