# Medallion Architecture (Bronze → Silver → Gold)

[← README](../README.md) · ✅ **Implemented in this lab** (NB4 LLM observability, NB8 agent trajectories)

## Definition

Refining data in layers inside the same lakehouse: **Bronze** = raw as received, **Silver** = cleaned/typed/deduplicated, **Gold** = aggregated for a specific question.

## Why It Matters

Raw data stays reprocessable; cleaning logic is separated from business aggregates; each layer is a versioned table.

## Role in the Lakehouse

The transformation/processing pattern on top of the table format. Replaces "ETL into a separate warehouse".

## How It Works

| Layer | Contract | NB4 | NB8 |
|---|---|---|---|
| Bronze | Append raw, never edit | `llm_calls_raw`: `request_id`, `ts`, `raw_json` (200,000) | `agent_traces` (1,578 steps) |
| Silver | Typed, validated, deduped, partitioned | `llm_calls`: 9 typed cols, 190,052 rows, `date` partitions | `agent_trajectories`: `trajectory_id`, cost, `agent_version` partitions |
| Gold | Business aggregates | `llm_daily_metrics`: date × model, p50/p95, error_rate, cost_usd (24 rows) | `agent_performance`: per policy success/steps/cost (2 rows) |

## How It Was Used in This Lab

- **Dedup:** 9,687 retried `request_id`s (up to 4 attempts) → 9,948 rows dropped with `ROW_NUMBER() … ORDER BY ts` keeping the **earliest** attempt.
- **Validation:** `model IS NOT NULL` dropped 0 rows.
- **Gold checks I ran manually** (notebook did not assert them): 24 rows, ≥ 7 dates × 3 models, `p50 ≤ p95` (0 violations), `cost_usd > 0`, `error_rate ∈ [0, 1]` (0.042–0.062), total ≈ $4,754.78 (illustrative prices).
- Insight: opus ≈ 10% of calls but cost ≈ sonnet (≈ $290 vs $345/day) because of 5× price.
- NB8 Gold: policy-v2 0.760 vs v3 0.753 success — synthetic split, not a real difference.

## Example

SQL in [techniques/sql.md#dedup-keep-one-row-per-key](../techniques/sql.md#dedup-keep-one-row-per-key) and [#percentiles-error-rate-and-cost-per-group](../techniques/sql.md#percentiles-error-rate-and-cost-per-group).

## Common Pitfalls

- Dedup rule is a **business decision**: first attempt (often failed) vs last attempt (what the user got) vs no dedup (load on the API).
- Gold quality must be checked **semantically**, not just by row thresholds (8 dates passed the "≥ 7" rule but two were partial days).
- Silver must not depend on host settings (time zone).
- Comparing Gold groups needs sample-size sense (0.007 difference on 150 samples is noise).

## Related Concepts

[partitioning](partitioning.md) · [schema-enforcement-and-evolution](schema-enforcement-and-evolution.md) · [DuckDB](../technologies/duckdb.md) · [03 — Data flow](../03-data-flow.md)

## Key Takeaways

- Bronze = replayable truth; Silver = event truth; Gold = answers.
- Every layer is a Delta table with history.
- Validate Gold by meaning, not only by counts.
