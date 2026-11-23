# DuckDB

[← README](../README.md) · ✅ **Implemented in this lab** — `duckdb` **1.5.6**

## What Is It?

An in-process analytical SQL engine (like SQLite for analytics) that reads Arrow tables zero-copy.

## Why Did We Use It?

Expressive SQL (JSON extraction, window functions, `QUANTILE_CONT`, `FILTER`, vector functions) with no server and **no network** — the lab registers Arrow tables instead of using `delta_scan()`, which would download an extension.

## Role in This Lab

NB1 tier counts, NB2 (imported), NB4 Silver/Gold transformations, NB7 vector search + lifecycle checks, NB8 trajectories, provenance, audits.

## Role in the Lakehouse

Query/compute engine reading table-format data via Arrow.

## How It Works

```python
con = duckdb.connect()
con.register("bronze", DeltaTable(BRONZE).to_pyarrow_table())   # zero-copy view
con.sql("SELECT …").arrow() / .fetchall() / .fetchone()
```
`to_arrow()` helper in `scripts/lakehouse.py` normalizes DuckDB ≥ 1.3 results (RecordBatchReader → Table).

## Important Configuration

| Setting | Why it matters |
|---|---|
| `SET TimeZone = 'UTC'` | Default session TZ is the host's (`Asia/Bangkok` on my machine) → `CAST(timestamptz AS DATE)` shifts days |
| `current_setting('TimeZone')` | Check before deriving dates |

## Commands / SQL

See [techniques/sql.md](../techniques/sql.md): JSON parsing, `ROW_NUMBER` dedup, `QUANTILE_CONT`, `count(*) FILTER (WHERE …)`, `array_cosine_similarity(emb::FLOAT[256], …)`, `DISTINCT ON`.

## Example from the Lab

NB4: one query parsed 200,000 JSON payloads and deduplicated to 190,052 rows.

## Trade-offs

- ✅ Zero infra, fast, SQL on Arrow/Polars objects.
- ⚠️ Registering a whole table as Arrow loads it in memory and bypasses table-format pruning (noted in NB8).

## Limitations (observed)

- Fixed-size array functions need explicit `::FLOAT[dim]` casts on Delta-read lists.
- Aliases: write `count(*) AS rows` — `count(*) rows` without `AS` raised a parser error for me.
- Brute-force vector search is O(n): ~28 ms at 2,000 vectors → not for online serving at scale.

## When I Would Use It Again

Local analytics, notebooks, pipeline transforms, offline evaluation (recall), embedded SQL in apps.

## Related Technologies

[Polars](polars.md) · [Arrow & Parquet](apache-arrow-and-parquet.md) · [Delta](delta-lake.md)

## Key Takeaways

- Register Arrow tables to stay offline.
- Set the time zone explicitly when deriving dates.
- Cast list → `FLOAT[dim]` for vector functions.
