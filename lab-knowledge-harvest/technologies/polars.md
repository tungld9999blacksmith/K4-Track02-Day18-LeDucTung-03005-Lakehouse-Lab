# Polars

[← README](../README.md) · ✅ **Implemented in this lab** — `polars` **1.44.2** (requirements pin `>=1.13.2` because 1.13.1 was yanked)

## What Is It?

A fast, Arrow-native DataFrame library (Rust core).

## Why Did We Use It?

Build test data, convert to Arrow for writing, pretty-print tables, small analyses.

## Role in This Lab

NB1/NB3 build DataFrames → `.to_arrow()` → `write_deltalake`; `pl.from_arrow(...)` to display results; NB4/NB8 printing Gold; my NB8 fingerprint used `hash_rows`.

## Role in the Lakehouse

Compute engine (DataFrame API) on Arrow data — interchangeable with DuckDB.

## Commands / APIs

```python
df = pl.DataFrame({"id": [1, 2, 3], "age": [30, 25, 35]})
write_deltalake(path, df.to_arrow(), mode="overwrite")
pl.from_arrow(DeltaTable(path).to_pyarrow_table()).sort("id")
df.with_columns(pl.when(pl.col("score") > 800).then(pl.lit("gold")).otherwise(pl.lit("silver")).alias("tier"))
df.group_by("status").len()
int(df.sort(["trajectory_id", "step"]).hash_rows(seed=0).sum())     # content fingerprint
with pl.Config(tbl_rows=30, tbl_cols=8): print(df)                   # show more rows
```

## Example from the Lab

NB3 v1: added `tier` with `pl.when/then/otherwise`, then overwrote the table with `schema_mode="overwrite"`.

## Trade-offs / Limitations

- ✅ Zero-copy with Arrow, expressive.
- ⚠️ Default printing truncates rows/columns (use `pl.Config`).
- ⚠️ Specify `schema=` when a column is all `None` (NB3 bad rows) or the dtype is inferred as Null.

## When I Would Use It Again

DataFrame-style transforms and quick inspection next to DuckDB SQL.

## Related Technologies

[DuckDB](duckdb.md) · [Arrow & Parquet](apache-arrow-and-parquet.md)

## Key Takeaways

- `.to_arrow()` / `pl.from_arrow()` is the bridge to Delta.
- Use `pl.Config` for screenshots of full tables.
