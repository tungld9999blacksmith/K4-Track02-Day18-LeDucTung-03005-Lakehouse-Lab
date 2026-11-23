# Jupyter Lab & Jupytext (+ test harness)

[← README](../README.md) · ✅ **Implemented in this lab** — `jupyterlab` 4.6.4, `jupytext` 1.19.5, `pytest` 9.1.1; notebooks run in VS Code and headless via `nbclient`

## What Is It?

- **Jupytext:** stores notebooks as `.py` "percent" files (`# %%` code, `# %% [markdown]`) and converts to/from `.ipynb`.
- **Jupyter Lab:** interactive notebook UI.

## Why Did We Use It?

`.py` notebooks are diffable and reviewable; `.ipynb` holds the executed outputs required for submission.

## Role in This Lab

Source of truth: `notebooks/0X_*.py` (+ helper `_setup.py`, which adds `scripts/` to `sys.path` file-relatively). Generated: `notebooks/*.ipynb` (git-ignored). Submitted: executed copies in `submission/notebooks/`.

## Commands

```powershell
# convert only the 8 numbered notebooks (skip _setup.py)
Get-ChildItem notebooks/[0-9]*.py | ForEach-Object { .\.venv\Scripts\python.exe -m jupytext --to notebook $_.FullName }
.\.venv\Scripts\python.exe -m jupytext --to notebook --update notebooks/01_delta_basics.py   # refresh, keep outputs
.\.venv\Scripts\python.exe -m jupyter lab --notebook-dir=notebooks --no-browser
```

Headless execution that **saves outputs** (what I used to produce submission notebooks):

```python
import nbformat
from nbclient import NotebookClient
nb = nbformat.read(path, as_version=4)
NotebookClient(nb, timeout=600, kernel_name="python3",
               resources={"metadata": {"path": "notebooks"}}).execute()
nbformat.write(nb, path)
```

`scripts/run_all.py` runs the `.py` files with `subprocess` → checks assertions but **does not save outputs**.

## Test harness

| Tool | What it checks |
|---|---|
| `scripts/verify_lite.py` | 9 smoke checks (Delta write/time travel/maintenance/CDF, Iceberg catalog + pruning + maintenance API, DuckDB vectors, DuckDB↔Delta via Arrow) |
| `pytest` (`tests/test_lab18.py`, 24 tests) | Library invariants + **canaries**: vacuum ignores uncommitted orphans; Iceberg expiry strands manifest lists; field-ID rename; hidden partition pruning; catalog isolation |
| `scripts/run_all.py` | All 8 notebooks end-to-end (8/8 in ~63 s on a clean root) |

## Limitations / Pitfalls

- `jupytext --update` **overwrites the cells** of an `.ipynb` from the `.py` → cells added only in the notebook are lost.
- Editing a notebook on disk while VS Code has it open → use "File: Revert File" before saving.
- VS Code truncates long outputs → raise `notebook.output.textLineLimit`.

## Related

[techniques/commands.md](../techniques/commands.md) · [techniques/troubleshooting.md](../techniques/troubleshooting.md)

## Key Takeaways

- `.py` = source, `.ipynb` = evidence.
- `run_all.py` validates; `nbclient` (or Run All + save) produces outputs.
- Canary tests turn library behaviour changes into red tests.
