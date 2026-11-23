# Troubleshooting

[← README](../README.md) · ✅ = encountered during my run · 📘 = from the lab README, not encountered

## Environment

### UnicodeEncodeError (cp1252)
- **Status:** ✅ encountered
- **Problem:** `UnicodeEncodeError: 'charmap' codec can't encode character '✅'` when printing notebook text.
- **Cause:** Windows console default code page.
- **Fix:** `$env:PYTHONUTF8 = '1'` (or `PYTHONUTF8=1` in Git Bash). `make.ps1` sets it.
- **Lesson:** set UTF-8 mode for every Python run on Windows.

### `make` not available on Windows
- **Status:** ✅ encountered
- **Fix:** `make.ps1` port of the Makefile (`.\make.ps1 setup|smoke|test|data|data-ai|run-all|lab|clean|spark-*`).

### WinError 32: catalog.db locked
- **Status:** ✅ encountered
- **Problem:** `PermissionError: [WinError 32] … _lakehouse\iceberg\nb5\catalog.db` (also `nb6`) when running a notebook headless or `run_all.py`.
- **Cause:** a Jupyter/VS Code kernel that ran the same notebook keeps the SQLite file open; Windows can't delete open files; `reset_catalog()` calls `shutil.rmtree`.
- **Diagnosis:** the traceback ends in `reset_catalog` → `rmtree`; only Iceberg notebooks (NB5/6/8) fail.
- **Fix:** restart/shut down that kernel, or run against an isolated root: `$env:LAKEHOUSE_ROOT="$env:TEMP\runall_clean"`.
- **Lesson:** one catalog per notebook avoids cross-notebook races but not same-notebook process locks.

### 📘 Other README items
| Symptom | Fix |
|---|---|
| `'DeltaTable' object has no attribute 'files'` | deltalake 0.x → reinstall 1.x (`file_uris()`) |
| `No function matches array_cosine_similarity(FLOAT[], …)` | Cast `emb::FLOAT[256]` |
| NB2 speedup < 3× | Normal on slow machines; files-pruned ≥ 10× is accepted |
| Missing data | NB4/NB7/NB8 regenerate automatically |

## Notebook workflow

### Re-running a single write cell duplicates data
- **Status:** ✅ encountered
- **Problem:** NB1 log had 3 commits; `dan` appeared twice; DuckDB showed `premium: 2`.
- **Cause:** re-executed the `append` cell; Delta append is not idempotent.
- **Fix:** Restart → Run All (first cell `reset()`s the table).
- **Lesson:** run write notebooks top-to-bottom; use MERGE for idempotent writes.

### Cells added to `.ipynb` disappear
- **Status:** ⚠️ risk identified in this workflow (avoided, not hit)
- **Cause:** `jupytext --to notebook --update` (run by `make lab` / `make.ps1 lab`) rewrites cells from the `.py`.
- **Fix:** copy finished notebooks to `submission/notebooks/` immediately, or add cells to the `.py`.

### Notebook changed on disk while open in VS Code
- **Status:** ✅ encountered
- **Problem:** stale editor content / an unexpected empty cell after an external write.
- **Fix:** `Ctrl+Shift+P` → "File: Revert File" before saving.

### Truncated outputs in VS Code
- **Status:** ✅ encountered
- **Fix:** setting `notebook.output.textLineLimit` → 200, or "scrollable element"; in Polars use `pl.Config(tbl_rows=30)`.

### A code cell with no output
- **Status:** ✅ encountered
- **Cause:** cell never executed (`execution_count: None`) — e.g. NB5 cell after the rename.
- **Fix:** Run All; check `execution_count` of every code cell before submitting.

## Library behaviour

### `get_add_actions()` has no `to_pydict`
- **Status:** ✅ encountered
- **Cause:** delta-rs 1.x returns an `arro3` table.
- **Fix:** `pa.table(dt.get_add_actions(flatten=True)).to_pylist()`.

### DuckDB parser error on alias
- **Status:** ✅ encountered
- **Problem:** `syntax error at or near "rows"`.
- **Fix:** write `count(*) AS rows`.

### Timezone-dependent date partitions
- **Status:** ✅ encountered
- **Problem:** NB4 Gold had **8 dates** although data spans 7 UTC days; first/last day partial (e.g. haiku cost $33 / $13.5 vs ~$46).
- **Cause:** `CAST(ts AS DATE)` on TIMESTAMPTZ uses DuckDB's session TZ = `Asia/Bangkok` (UTC+7).
- **Diagnosis:** `SELECT current_setting('TimeZone')`; `GROUP BY date` showed min/max ts per day starting 07:00.
- **Fix:** `con.sql("SET TimeZone = 'UTC'")` or `CAST(timezone('UTC', ts) AS DATE)`.
- **Lesson:** threshold checks passed (8 ≥ 7) while semantics were wrong — validate meaning.

### Misleading NB6 output lines
- **Status:** ✅ encountered
| Printed | Reality | How I verified |
|---|---|---|
| `VACUUM would reclaim 211 tombstoned files (0 B)` | 0 B is a display bug: dry-run returns **relative** paths, `du()` finds nothing | Listed dry-run paths; real reclaim = `Reclaimed: 16.1 MB` |
| `Parquet files on disk: 15 … → 5 files you pay for` | 3 orphans + **2 auto checkpoints** in `_delta_log/` (counted recursively) | `ls _delta_log` → `…099/…199.checkpoint.parquet` |
| `VACUUM dry-run now finds: 211 files` | Already-deleted tombstones still in the log | 0/211 exist on disk |
| `Checkpoint written: …099.checkpoint.parquet` | First glob match = old auto checkpoint; new one is v203 | `_last_checkpoint` = `{"version":203,…}` |

### VACUUM didn't remove orphans
- **Status:** ✅ encountered (expected, documented)
- **Cause:** delta-rs reclaims only tombstoned files. **Fix:** set-difference sweep with age guard ([code](code-patterns.md#find-orphan-files)).

### Iceberg expiry didn't shrink storage
- **Status:** ✅ encountered (expected, documented)
- **Cause:** PyIceberg expiry only un-references. **Fix:** sweep `snap-*.avro` not referenced by live snapshots.

### Disk usage grew after OPTIMIZE
- **Status:** ✅ encountered
- **Cause:** old files tombstoned, not deleted (10.1 → 16.1 MB). **Fix:** VACUUM after retention.

## Debugging techniques that worked

- Prefer **metadata evidence** over timings: file counts, `get_add_actions` stats, Parquet footer, `_last_checkpoint`.
- Read the log JSON directly when a printed number looks odd.
- Time-travel to the previous version to prove what a DELETE/RESTORE really did.
- Run notebooks in an isolated `LAKEHOUSE_ROOT` to separate environment problems from code problems.
