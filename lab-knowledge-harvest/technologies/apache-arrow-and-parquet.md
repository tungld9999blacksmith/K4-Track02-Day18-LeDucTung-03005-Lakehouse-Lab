# Apache Arrow (pyarrow) & Apache Parquet

[← README](../README.md) · ✅ **Implemented in this lab** — `pyarrow` **25.0.1**

## What Is It?

- **Parquet:** on-disk **columnar** file format. File → row groups → column chunks; footer holds schema, encodings, sizes and min/max stats.
- **Arrow:** in-memory columnar format and the zero-copy interchange between Delta/Iceberg readers, DuckDB, Polars and NumPy.

## Why Did We Use It?

Every table format in the lab stores Parquet; every engine hand-off is an Arrow table. The Parquet footer was also a **measurement tool** (bytes per column, row groups).

## Role in This Lab

- Data files for all Delta/Iceberg tables.
- NB6 orphans written directly with `pq.write_table`.
- NB7: footer metadata proved column pruning (1.2 KB of 12.5 MB) and row-group amplification (1 row group = 200 rows = 12.5 MB).
- NB5: `PARQUET:field_id` metadata on each column (Iceberg field-IDs).

## Role in the Lakehouse

Storage file format (Parquet) + engine interoperability layer (Arrow).

## How It Works (what to remember)

| Fact | Consequence |
|---|---|
| Columnar layout | Queries read only referenced columns (projection pushdown) |
| Row group = I/O unit | Random single-row reads pay for the whole row group |
| Footer stats | Engines/table formats skip files/row groups |
| Encodings (`PLAIN`, `RLE`, `RLE_DICTIONARY`) before codec (`SNAPPY`, `ZSTD`) | Low-cardinality data (int8: 71 distinct) shrinks far more than random floats |
| Files are immutable | Updates = rewrite (copy-on-write) |

## Commands / APIs

```python
import pyarrow as pa, pyarrow.parquet as pq
md = pq.ParquetFile(file).metadata
md.num_row_groups; rg = md.row_group(0); rg.num_rows; rg.total_byte_size
col = rg.column(i); col.path_in_schema; col.compression; col.encodings
col.total_compressed_size; col.total_uncompressed_size
pq.read_schema(file).field("latency_ms").metadata   # {b'PARQUET:field_id': b'4'}
pa.table(arro3_table)                                # adopt delta-rs arro3 tables
pa.FixedSizeListArray.from_arrays(values, dim)       # vector column
```

## Example from the Lab

NB7 footer: float32 `emb` 2.6 MB uncompressed / 2.5 MB compressed; int8 448.6 KB / 439.3 KB → the 5.8× gain came from encoding, not snappy.

## Trade-offs / Limitations

- ✅ Universal, compact, analytics-friendly.
- ⚠️ Poor random access for wide rows (blobs) → 📘 Lance-style formats address this (not implemented).
- ⚠️ Arrow `fixed_size_list` not preserved through Delta (comes back as `list`).

## When I Would Use It Again

Always — it is the substrate. Read the footer whenever I need *byte-exact* evidence instead of timings.

## Related Technologies

[Delta](delta-lake.md) · [Iceberg](apache-iceberg.md) · [DuckDB](duckdb.md) · [Polars](polars.md)

## Key Takeaways

- Parquet: columns + row groups + footer stats.
- Arrow: the common language between engines.
- Footer metadata = deterministic measurements.
