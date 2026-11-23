# Agents as Data Consumers (MCP-style Access Surface)

[← README](../README.md) · ✅ **Implemented in this lab as a local simulation** (NB8 `LakehouseMCP` class) · 📘 not a real MCP server

## Definition

An agent reads and acts on lakehouse data through a tool surface exposed over the **catalog**. NB8 models ideas from the MCP revision 2026-07-28 in a plain Python class (no transport, simplified fields).

## Why It Matters

Agents call tools every turn, may trigger destructive actions, and run long jobs. The data platform must cache, gate, track and meter that traffic.

## Role in the Lakehouse

Serving/consumption boundary between AI agents and catalog-managed tables.

## How It Works (and what the lab measured)

| Idea | Lab implementation | Result |
|---|---|---|
| Stateless requests | Each `call(name, args, _meta)` self-describes; no session | Can sit behind a load balancer |
| Cacheable lists | `list_tables` cached with TTL 60 s, scope session | **5 turns → 1 catalog read** |
| Human-in-the-loop | Destructive tools (`delete_rows`, `drop_table`) without `_meta.confirmed` | `resultType: input_required` + prompt |
| Tasks | `submit_scan` returns `taskId` + `pollAfterMs: 50`; `tasks_get` polls | `working → working → completed`, 300 rows |
| Header routing / metering | `Mcp-Method`, `Mcp-Name`; `meter[name]` calls + ms | Per-tool counts (`list_tables` 5, others 1) |
| Guardrail | `query` limit capped at 100 rows | No unbounded scans |

## Example

```python
mcp = LakehouseMCP(cat, ns)
mcp.call("list_tables")                                        # cached after first call
mcp.call("delete_rows", {"table": "lake.trajectories", "where": "reward = 0"})
# → {"resultType": "input_required", "prompt": "Confirm delete_rows(...)"}
mcp.call("delete_rows", {...}, _meta={"confirmed": True})      # → "ok" (no-op in lab)
task = mcp.call("submit_scan", {"table": "lake.trajectories"})["result"]["taskId"]
mcp.tasks_get(task)                                            # poll until completed
```

## Common Pitfalls

- `confirmed` is supplied by the **caller** → an agent can self-confirm. Not an authorization boundary; real systems need out-of-band approval (separate UI, signed token, IAM).
- Cache was measured on `list_tables`, **not** `tools/list` (which only advertises `ttlMs`).
- TTL cache hides tables created within the TTL.
- Task completion is simulated by a 50 ms delay; no background job runs. `delete_rows` is a no-op.

## Related Concepts

[catalog-and-metadata](catalog-and-metadata.md) · [provenance-and-reproducibility](provenance-and-reproducibility.md) · [data-lifecycle-and-erasure](data-lifecycle-and-erasure.md)

## Key Takeaways

- Expose tables to agents through the catalog, with caching, limits and metering.
- Destructive operations need confirmation the agent cannot forge.
- Long scans → task handles + polling, not blocking calls.
