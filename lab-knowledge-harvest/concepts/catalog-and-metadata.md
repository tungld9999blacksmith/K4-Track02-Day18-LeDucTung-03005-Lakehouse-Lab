# Catalog & Metadata Tree

[← README](../README.md) · ✅ **Implemented in this lab** (NB5, NB6, NB8 — PyIceberg `SqlCatalog` on SQLite)

## Definition

A **catalog** maps table names to their current metadata and is where commits become visible. Iceberg's **metadata tree** (metadata.json → manifest list → manifests → data files) describes each snapshot.

## Why It Matters

Users and agents address tables by **name**, never by path. The catalog is the single point to register, discover, commit, and (in production) secure tables — the lakehouse "control plane".

## Role in the Lakehouse

Sits above the table format. Delta in this lab used paths only (no catalog); Iceberg cannot work without one.

## How It Works

```text
catalog (SQLite row) ──► metadata/00011-<uuid>.metadata.json   schema(s), spec(s), snapshot list, current snapshot
                              └─► metadata/snap-<id>-0-<uuid>.avro   manifest list (1 per snapshot)
                                       └─► metadata/<uuid>-m0.avro    manifest: data files + partition values + stats
                                                └─► data/ts_day=…/*.parquet
```

- Commit = write new metadata.json, then atomically swap the catalog pointer.
- Each tier lets the planner skip the tier below (manifest list holds partition ranges per manifest).
- Every schema/spec change also writes a new metadata.json (no snapshot).

## How It Was Used in This Lab

- `create_table("lake.llm_events", schema=…)` — no path given; catalog chose `warehouse/lake/llm_events`.
- NB5 tree after 10 appends: 12 metadata.json, 10 manifest lists, 10 manifests, 10 data files; **metadata 139.1 KB vs data 47.3 KB (294%)**.
- At the end of NB5: 16 metadata.json, 11 snapshots.
- One catalog **per notebook** (`nb5`, `nb6`, `nb8`) so resets don't collide (`scripts/lakehouse.py:_catalog_dir`).
- NB8: an agent discovered tables through `cat.list_tables(ns)` via [LakehouseMCP](agent-data-access.md).

## Important Commands / Code

```python
from lakehouse import catalog, namespace, reset_catalog
reset_catalog("nb5"); cat = catalog("nb5"); ns = namespace(cat, "lake")
tbl = cat.create_table(f"{ns}.llm_events", schema=SCHEMA)
tbl = cat.load_table(f"{ns}.llm_events")          # refresh after every metadata change
tbl.inspect.snapshots(); tbl.inspect.manifests(); tbl.inspect.files()
tbl.inspect.metadata_log_entries(); tbl.inspect.partitions(); tbl.inspect.history()
```

📘 **Context / Not implemented in this lab:** production REST catalogs (Polaris, Unity, Lakekeeper, Glue) — same `load_catalog(type="rest", uri=…)` API, plus credential vending, access control and server-side planning.

## Common Pitfalls

- Forgetting `cat.load_table(...)` after `update_spec`/`update_schema` → stale object.
- On Windows a running Jupyter kernel keeps `catalog.db` open → `reset_catalog` fails with `WinError 32` ([troubleshooting](../techniques/troubleshooting.md#winerror-32-catalogdb-locked)).
- Metadata grows with commits and files, not rows — small frequent commits bloat it.
- Old metadata.json files accumulate (22 left in NB6) unless metadata cleanup properties are set.

## Related Concepts

[partitioning](partitioning.md) · [schema-enforcement-and-evolution](schema-enforcement-and-evolution.md) · [table-maintenance](table-maintenance.md) · [agent-data-access](agent-data-access.md) · [Iceberg](../technologies/apache-iceberg.md)

## Key Takeaways

- Name → catalog → metadata pointer → files.
- The catalog is the commit point and the discovery point.
- Metadata is real storage with real cost.
