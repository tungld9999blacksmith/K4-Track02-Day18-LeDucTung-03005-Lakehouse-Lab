# SQL Patterns (DuckDB)

[← README](../README.md) · ✅ **Implemented in this lab** — all patterns ran in DuckDB 1.5.6 over Arrow-registered Delta/Iceberg tables.

Setup for every pattern:
```python
con = duckdb.connect()
con.register("bronze", DeltaTable(BRONZE).to_pyarrow_table())
```

## Parse JSON payloads into typed columns

**Purpose:** Bronze → Silver typing. **When:** raw events stored as JSON strings.
```sql
SELECT request_id, ts, CAST(ts AS DATE) AS date,
       json_extract_string(raw_json, '$.model')                  AS model,
       CAST(json_extract(raw_json, '$.usage.input')  AS INTEGER) AS prompt_tokens,
       CAST(json_extract(raw_json, '$.latency_ms')   AS INTEGER) AS latency_ms,
       json_extract_string(raw_json, '$.status')                 AS status
FROM bronze;
```
`json_extract_string` → VARCHAR; `json_extract` → JSON (then CAST). ⚠️ `CAST(timestamptz AS DATE)` uses the session `TimeZone` → run `SET TimeZone = 'UTC';` first.

## Dedup: keep one row per key

**Purpose:** remove retries/duplicates in Silver.
```sql
WITH parsed AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY request_id ORDER BY ts) AS rn
  FROM bronze)
SELECT * EXCLUDE (rn) FROM parsed WHERE rn = 1 AND model IS NOT NULL;
```
`ORDER BY ts` keeps the first attempt; `ORDER BY ts DESC` keeps the last — a business choice.
📘 `EXCLUDE` is shorthand; the lab listed columns explicitly.

## Find duplicate keys (diagnostics)

```sql
WITH c AS (SELECT request_id, count(*) AS attempts FROM bronze GROUP BY 1)
SELECT count(*) FILTER (WHERE attempts > 1) AS dup_ids,
       sum(attempts - 1)                     AS rows_removed_by_dedup,
       max(attempts)                         AS max_attempts
FROM c;          -- lab: 9687 · 9948 · 4
```

## Percentiles, error rate and cost per group

**Purpose:** Gold metrics.
```sql
WITH cost(model, c_in, c_out) AS (
  VALUES ('claude-haiku-4-5', 0.80, 4.00), ('claude-sonnet-4-6', 3.00, 15.00), ('claude-opus-4-7', 15.00, 75.00))
SELECT s.date, s.model,
       QUANTILE_CONT(s.latency_ms, 0.50) AS p50_latency_ms,
       QUANTILE_CONT(s.latency_ms, 0.95) AS p95_latency_ms,
       AVG(CASE WHEN s.status <> 'ok' THEN 1.0 ELSE 0.0 END) AS error_rate,
       SUM(s.prompt_tokens) * c.c_in / 1e6 + SUM(s.completion_tokens) * c.c_out / 1e6 AS cost_usd
FROM silver s JOIN cost c USING (model)
GROUP BY s.date, s.model, c.c_in, c.c_out
ORDER BY s.date, s.model;
```
Prices are the lab's illustrative values, not real pricing. Inline `VALUES` CTE = lookup table without a file.

## Validate Gold with FILTER aggregates

```sql
SELECT count(*) AS n_rows, count(DISTINCT date) AS dates, count(DISTINCT model) AS models,
       min(k) AS min_models_per_date,
       count(*) FILTER (WHERE p50_latency_ms > p95_latency_ms) AS p50_gt_p95,
       count(*) FILTER (WHERE cost_usd <= 0)                   AS nonpos_cost,
       count(*) FILTER (WHERE error_rate NOT BETWEEN 0 AND 1)  AS bad_error_rate
FROM (SELECT *, count(*) OVER (PARTITION BY date) AS k FROM gold);
```
Rule: every check column should be 0 (or the expected count).

## Two-level aggregation (per entity → per group)

**Purpose:** NB8 trajectory → policy rollup.
```sql
WITH per_traj AS (
  SELECT trajectory_id, agent_version, max(reward) AS success, count(*) AS steps,
         sum(cost_usd) AS cost_usd, max(status = 'error') AS had_error
  FROM silver GROUP BY 1, 2)
SELECT agent_version, count(*) AS trajectories, round(avg(success), 3) AS success_rate,
       round(avg(steps), 2) AS avg_steps
FROM per_traj GROUP BY 1 ORDER BY 1;
```
Derive a label from an id: `CASE WHEN CAST(substr(session_id, 6) AS INT) < 150 THEN 'policy-v2' ELSE 'policy-v3' END`.

## Vector similarity search (+ governance filter)

```sql
SELECT doc_id, topic, license,
       array_cosine_similarity(emb::FLOAT[256], ?::FLOAT[256]) AS sim
FROM docs
WHERE consent_train AND license <> 'unknown'
ORDER BY sim DESC
LIMIT 5;
```
The lab inlined the vector as a Python list literal in an f-string. `emb::FLOAT[256]` is required because Delta returns `list<float>`.

## Classification as a single CASE (provenance)

```sql
CASE
  WHEN license IN ('proprietary', 'commercial')          THEN 'licensed'
  WHEN license = 'cc-by-4.0'                             THEN 'public_domain'   -- lab rule; CC BY ≠ public domain
  WHEN license = 'user-owned'  AND consent_train         THEN 'scraped_optout_checked'
  WHEN license = 'synthetic'   AND generator IS NOT NULL THEN 'synthetic'
  ELSE 'UNCLASSIFIED'
END AS provenance_bucket
```
Share-of-total: `round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct`.

## One row per key without GROUP BY

```sql
SELECT DISTINCT ON (trajectory_id) agent_version FROM silver ORDER BY trajectory_id;
```

## Session settings

```sql
SELECT current_setting('TimeZone');   -- was Asia/Bangkok on my machine
SET TimeZone = 'UTC';
```

## Pitfalls

- Use `AS` for aliases (`count(*) AS rows`); `count(*) rows` gave me a parser error.
- Registered Arrow tables are in-memory copies of the current version — no table-format pruning, no time travel inside SQL (time travel = register `DeltaTable(path, version=N)` under another name).
