# Transaction Log & ACID Commits

[← README](../README.md) · ✅ **Implemented in this lab** (NB1, NB2, NB3, NB6)

## Definition

A **transaction log** is an ordered list of commit files describing which data files belong to a table at each version. Readers reconstruct the table by replaying the log — never by listing the directory.

## Why It Matters

Plain Parquet folders have no atomicity: a crashed job leaves partial files that readers see. The log makes each write **all-or-nothing** and gives every table a version history.

## Role in the Lakehouse

Core of the **table format** layer. Delta uses `_delta_log/`; Iceberg uses a catalog pointer + metadata tree ([catalog-and-metadata](catalog-and-metadata.md)).

## How It Works (Delta)

```text
_delta_log/
  00000000000000000000.json   ← version 0
  00000000000000000001.json   ← version 1
  …
  00000000000000000099.checkpoint.parquet   ← state snapshot (auto every 100 commits in delta-rs)
  _last_checkpoint                          ← pointer to newest checkpoint
```

Each JSON line is one **action**:

| Action | Meaning |
|---|---|
| `commitInfo` | operation (`WRITE`, `MERGE`, `DELETE`, `OPTIMIZE`, `RESTORE`, `VACUUM START/END`), parameters, metrics |
| `protocol` | min reader/writer version (here `1`/`2`) |
| `metaData` | table id, `schemaString`, `partitionColumns`, `configuration` |
| `add` | data file joins the table; carries `size`, `partitionValues`, **`stats`** (numRecords, min/max, nullCount), `dataChange` |
| `remove` | data file leaves the table (**tombstone** — file stays on disk) |

A commit succeeds only when the next numbered JSON is written. No file → no version.

## How It Was Used in This Lab

- NB1: inspected `000…0.json` (4 actions) and `000…1.json` (new `metaData` with `tier`). The rejected `age="thirty"` write produced **no** JSON → atomicity.
- NB2/NB6: OPTIMIZE commits contain only `add`/`remove` with `"dataChange": false` (v200: 67 add + 200 remove; v201: 55 add + 67 remove).
- NB3: RESTORE commit = `commitInfo` + `protocol` + one `remove` + `metaData` — no data rewritten.
- NB6: delta-rs auto-wrote checkpoints at v99 and v199; `create_checkpoint()` wrote v203.

## Example

```text
00000000000000000001.json (NB1)
{"commitInfo":{"operation":"WRITE","operationParameters":{"mode":"Append"}, … "num_added_rows":1}}
{"metaData":{… "schemaString":"…id,name,age,city,tier…"}}
{"add":{"path":"part-00000-….snappy.parquet","size":1548,"dataChange":true,
        "stats":"{\"numRecords\":1,\"minValues\":{…},\"maxValues\":{…},\"nullCount\":{…}}"}}
```

## Important Commands / Code

```python
dt = DeltaTable(path)
dt.version(); dt.history()            # versions + commitInfo metrics
dt.file_uris()                        # files in CURRENT version (not on disk!)
pa.table(dt.get_add_actions(flatten=True))   # add actions incl. min.<col>/max.<col>
```

Log-reading cell: [techniques/code-patterns.md#read-the-delta-log](../techniques/code-patterns.md#read-the-delta-log)

## Common Pitfalls

- Counting `*.parquet` on disk ≠ files in the table (tombstoned files, orphans, checkpoints in `_delta_log/`).
- Re-running an `append` cell creates another version with duplicate rows — the log does not dedupe.
- delta-rs already checkpoints every 100 commits; "replay all N JSON files" is not literally true.

## Related Concepts

[time-travel-and-versioning](time-travel-and-versioning.md) · [schema-enforcement-and-evolution](schema-enforcement-and-evolution.md) · [file-layout-and-data-skipping](file-layout-and-data-skipping.md) · [table-maintenance](table-maintenance.md) · [Delta Lake](../technologies/delta-lake.md)

## Key Takeaways

- Table = Parquet files **+ log**; the log decides membership.
- `remove` is a tombstone, not a delete.
- `add.stats` are what make data skipping possible.
- Atomic commit = "next JSON file written or nothing happened".
