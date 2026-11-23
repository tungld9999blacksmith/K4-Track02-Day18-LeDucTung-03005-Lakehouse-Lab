# Vectors & Multimodal Data in Tables

[← README](../README.md) · ✅ **Implemented in this lab** (NB7)

## Definition

Storing AI artefacts — **blobs** (images/clips) and **embeddings** — in lakehouse tables, either inline (bytes/vectors in a column) or by pointer (URI to an object), and querying them with SQL.

## Why It Matters

Parquet assumes KB rows read sequentially in batches. Multimodal AI brings MB rows, random access and GPUs that must stay fed. The right layout depends on the **access pattern**, not on size alone.

## Role in the Lakehouse

Lakehouse = **system of record** for vectors and blobs; a vector DB = rebuildable **derived index**.

## How It Works

- **Column pruning:** a query not mentioning `blob` never reads its column chunks.
- **Row-group granularity:** to read one row you read (and decompress) its whole row group → random-read amplification ≈ rows per row group (for equal-size blobs).
- **int8 quantization:** `int8 = clip(round(x · 127))`, valid because embeddings are unit vectors (components ∈ [−1, 1]).
- **Vector search in SQL:** DuckDB `array_cosine_similarity` (core, no extension) over `FLOAT[dim]` arrays.

## How It Was Used in This Lab

| Measurement | Result |
|---|---|
| Inline table vs pointer table | 12.5 MB vs 4.7 KB (+12.5 MB objects) — same total bytes |
| `SELECT topic, count(*)` bytes (footer) | **1.2 KB of 12.5 MB** inline; same as pointer |
| Fetch one 64 KB frame | Inline: 1 row group of 200 rows = 12.5 MB → **200× amplification** |
| float32 vs int8 on disk | 2.6 MB → 451.9 KB (**5.8×**, > theoretical 4×) |
| Why > 4× | Encoding, not snappy: int8 had **71** distinct values (dictionary works); float32 510,244 distinct (PLAIN) |
| recall@10 int8 vs float32 (100 queries) | **0.904** (≈0.89 excluding the query itself) |
| Topic fidelity of int8 top-10 | **1.000** |
| Top-5 for doc 7 (`storage`) | 5/5 `storage`, sims 0.77–1.00 |
| Same query + `consent_train AND license <> 'unknown'` | Doc 7 itself excluded (license unknown); 334/2,000 docs excluded |
| Brute force 2,000 × 256 | ~27–29 ms → ~14 s extrapolated at 1M (*timing*) → not a serving path |

## Important SQL / Code

```sql
SELECT doc_id, title, topic,
       array_cosine_similarity(emb::FLOAT[256], [/* query vector */]::FLOAT[256]) AS sim
FROM docs
WHERE consent_train AND license <> 'unknown'
ORDER BY sim DESC LIMIT 5;
```

```python
emb_i8 = np.clip(np.round(emb * 127.0), -127, 127).astype("int8")
pa.FixedSizeListArray.from_arrays(pa.array(emb_i8.ravel(), pa.int8()), dim)
```

## Common Pitfalls

- Delta has no fixed-size vector type: `fixed_size_list<float>[256]` reads back as `list<float>` → cast `emb::FLOAT[256]` or DuckDB can't bind the function.
- Exact-ID recall understates quantization quality for RAG; also measure topic fidelity — on *your* corpus (the synthetic one is well separated).
- "Never put blobs in tables" is wrong for scans, right for random reads.
- First query timing includes warm-up; brute-force cost is O(n).

📘 **Context / Not implemented in this lab:** Lance format (row-level random access), ANN indexes (HNSW/IVF), real encoders.

## Related Concepts

[data-lifecycle-and-erasure](data-lifecycle-and-erasure.md) · [provenance-and-reproducibility](provenance-and-reproducibility.md) · [DuckDB](../technologies/duckdb.md) · [Arrow & Parquet](../technologies/apache-arrow-and-parquet.md) · [design trade-offs](../comparisons/design-trade-offs.md)

## Key Takeaways

- Inline blobs: fine for analytics, bad for random access (row group = I/O unit).
- int8 ≈ 4–6× smaller with ~0.9 recall, ~1.0 topic fidelity here.
- Vectors + governance columns in one row = filtered search in one query.
- Lakehouse holds the truth; vector DBs are disposable indexes.
