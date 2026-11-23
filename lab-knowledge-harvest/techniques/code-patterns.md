# Python Code Patterns

[← README](../README.md) · ✅ **Implemented in this lab** (`deltalake` 1.6.6, `pyiceberg` 0.12.0, `pyarrow` 25)

## Lab helpers (`scripts/lakehouse.py`)

| Helper | Does |
|---|---|
| `path(layer, table)` | `ROOT/<layer>/<table>`; `ROOT` = `$LAKEHOUSE_ROOT` or `<repo>/_lakehouse` |
| `reset(*paths)` | `shutil.rmtree(..., ignore_errors=True)` → idempotent reruns |
| `catalog(name)` / `reset_catalog(name)` / `namespace(cat, ns)` | Isolated SQLite Iceberg catalog per name |
| `du(path)`, `human(n)`, `count_files(path, suffix)` | Bytes, pretty sizes, recursive file count (includes `_delta_log/*.parquet`!) |
| `to_arrow(duckdb_relation)` | Normalizes DuckDB result to `pa.Table` |

Notebooks import them via `import _setup` (adds `scripts/` to `sys.path` relative to the file, not the CWD).

## Write / read / time travel (Delta)

```python
write_deltalake(path, df.to_arrow(), mode="overwrite")                 # v0
write_deltalake(path, new.to_arrow(), mode="append", schema_mode="merge")
dt = DeltaTable(path)
dt.to_pyarrow_table(filters=[("user_id", "=", 4242)])                  # stats pushdown
DeltaTable(path, version=0).to_pyarrow_table()                          # time travel
for h in dt.history(): print(h["version"], h["operation"], h.get("operationMetrics", {}))
```

## Expect a write to fail (enforcement test)

```python
try:
    write_deltalake(path, bad.to_arrow(), mode="append")
    print("UNEXPECTED: accepted")
except Exception as e:
    print("BLOCKED:", type(e).__name__, str(e).splitlines()[0][:120])
```

## Read the Delta log

```python
import json
from pathlib import Path
for f in sorted((Path(path) / "_delta_log").glob("*.json")):
    for line in f.read_text().splitlines():
        action = json.loads(line); kind = next(iter(action))
        if kind == "metaData":
            print(kind, [x["name"] for x in json.loads(action[kind]["schemaString"])["fields"]])
        elif kind in ("add", "remove"):
            print(kind, action[kind]["path"][:40], action[kind].get("stats", ""))
        else:
            print(kind, json.dumps(action[kind])[:120])
```

## Per-file stats → files a point query must read

```python
import pyarrow as pa
def files_touched(path, col, value):
    aa = pa.table(DeltaTable(path).get_add_actions(flatten=True)).to_pylist()
    return sum(1 for f in aa if f[f"min.{col}"] <= value <= f[f"max.{col}"])
```
Works per version too: `DeltaTable(path, version=v).get_add_actions(flatten=True)`.

## MERGE / DELETE / RESTORE / CDF

```python
(DeltaTable(path).merge(source=src, predicate="t.id = s.id", source_alias="s", target_alias="t")
   .when_matched_update_all().when_not_matched_insert_all().execute())
DeltaTable(path).delete("subject_id = 'user_042'")
DeltaTable(path).restore(2)
write_deltalake(p, tbl, mode="overwrite", configuration={"delta.enableChangeDataFeed": "true"})
DeltaTable(p).load_cdf(starting_version=1).read_all()      # has _change_type
```

## Maintenance (Delta)

```python
dt.optimize.compact(target_size=1024 * 1024)
dt.optimize.z_order(["user_id"], target_size=1024 * 1024)
dt.vacuum(retention_hours=0, dry_run=True, enforce_retention_duration=False)   # returns RELATIVE paths
dt.create_checkpoint()
```

## Find orphan files

```python
import os, time
def find_orphans(table_path, min_age_hours=24):           # Delta
    referenced = {os.path.realpath(u.replace("file://", "")) for u in DeltaTable(table_path).file_uris()}
    cutoff = time.time() - min_age_hours * 3600
    return [str(f) for f in Path(table_path).rglob("*.parquet")
            if "_delta_log" not in f.parts
            and os.path.realpath(f) not in referenced
            and f.stat().st_mtime < cutoff]                 # age guard is mandatory

def find_iceberg_orphans(table, meta_dir):                  # stranded manifest lists
    live = {Path(s.manifest_list).name for s in table.snapshots()}
    return [f for f in meta_dir.glob("snap-*.avro") if f.name not in live]
```

## Iceberg essentials

```python
cat = catalog("nb5"); ns = namespace(cat, "lake")
tbl = cat.create_table(f"{ns}.llm_events", schema=pa_schema)
with tbl.update_spec() as spec: spec.add_field("ts", DayTransform(), "ts_day")
tbl = cat.load_table(f"{ns}.llm_events")                   # refresh!
tbl.append(arrow_tbl)                                       # 1 snapshot
len(list(tbl.scan(row_filter="ts >= '…' and ts < '…'").plan_files()))
with tbl.update_schema() as u: u.add_column("tier", StringType())
with tbl.update_schema() as u: u.rename_column("latency_ms", "latency_millis")
tbl.scan(snapshot_id=sid).to_arrow()
tbl.maintenance.expire_snapshots().by_ids(ids).commit()
```

## Parquet footer measurements

```python
md = pq.ParquetFile(file).metadata
bytes_per_col = {}
for rg in range(md.num_row_groups):
    for c in range(md.row_group(rg).num_columns):
        col = md.row_group(rg).column(c)
        bytes_per_col[col.path_in_schema] = bytes_per_col.get(col.path_in_schema, 0) + col.total_compressed_size
```

## Content fingerprint for replay checks

```python
def fingerprint(tbl, key=("trajectory_id", "step")) -> int:
    return int(pl.from_arrow(tbl).sort(list(key)).hash_rows(seed=0).sum())
```

## int8 quantization + recall

```python
emb_i8 = np.clip(np.round(emb * 127.0), -127, 127).astype("int8")
deq = emb_i8.astype("float32") / 127.0; deq /= np.linalg.norm(deq, axis=1, keepdims=True)
topk = lambda M, Q, k=10: np.argsort(-(Q @ M.T), axis=1)[:, :k]
recall = np.mean([len(set(g) & set(c)) / 10 for g, c in zip(topk(emb, emb[q]), topk(deq, deq[q]))])
```
