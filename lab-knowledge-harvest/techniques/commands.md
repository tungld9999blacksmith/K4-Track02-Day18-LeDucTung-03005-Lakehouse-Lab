# Commands Quick Reference

[← README](../README.md) · ✅ commands I ran on **Windows 11 / PowerShell**, unless marked 📘

Run from the repo root. `make.ps1` is my PowerShell port of the `Makefile` (GNU make isn't available on Windows).
If scripts are blocked: `powershell -ExecutionPolicy Bypass -File .\make.ps1 <target>`.

## Setup

| Task | Command | Purpose | Notes |
|---|---|---|---|
| Create venv | `python -m venv .venv` | Isolated env | Lab range Python 3.10–3.14; I used 3.13.3 |
| Install deps | `.\.venv\Scripts\python.exe -m pip install -r requirements.txt` | deltalake, pyiceberg, duckdb, polars, pyarrow, numpy, jupyter, pytest | Needs network once |
| All-in-one | `.\make.ps1 setup` | venv + deps + build `.ipynb` | Uses `uv` if installed |
| Unicode-safe console | `$env:PYTHONUTF8 = '1'` | Avoid `cp1252` `UnicodeEncodeError` | `make.ps1` sets it |
| Record versions | `.\.venv\Scripts\python.exe -m pip list` | Reproducibility | deltalake 1.6.6, pyiceberg 0.12.0, duckdb 1.5.6 |

## Data generation

| Task | Command | Output |
|---|---|---|
| Bronze for NB4 | `.\make.ps1 data` = `python scripts/generate_data_lite.py` | `bronze/llm_calls_raw`, 200K rows (arg overrides: `… 1000000`) |
| AI corpus for NB7/NB8 | `.\make.ps1 data-ai` = `python scripts/generate_ai_data.py` | `bronze/docs_multimodal`, `bronze/agent_traces`, `blobs/*.bin` |
| Skip it | — | NB4/NB7/NB8 self-generate missing data |

## Running notebooks

| Task | Command | Notes |
|---|---|---|
| Convert `.py` → `.ipynb` | `Get-ChildItem notebooks/[0-9]*.py \| ForEach-Object { .\.venv\Scripts\python.exe -m jupytext --to notebook $_.FullName }` | Skips `_setup.py` |
| Open Jupyter | `.\make.ps1 lab` | `--notebook-dir=notebooks`, http://localhost:8888 ⚠️ syncs `.ipynb` from `.py` |
| Run one notebook headless | `cd notebooks; ..\.venv\Scripts\python.exe 04_medallion.py` | Prints outputs, runs asserts |
| Run all 8 | `.\make.ps1 run-all` = `python scripts/run_all.py` | Does **not** save outputs |
| Run all on a clean, isolated root | `$env:LAKEHOUSE_ROOT="$env:TEMP\runall_clean"; python scripts/run_all.py` | Avoids locked files; 8/8 in 63 s |
| Execute + save `.ipynb` | `nbclient` snippet in [jupyter-and-jupytext](../technologies/jupyter-and-jupytext.md) | Produces submission evidence |

## Validation

| Task | Command | My result |
|---|---|---|
| Smoke | `.\make.ps1 smoke` = `python scripts/verify_lite.py` | 9/9 PASS |
| Tests | `.\make.ps1 test` = `python -m pytest -q` | 24/24 passed |
| End-to-end | `.\make.ps1 run-all` | 8/8 PASS |
| 📘 Student simulation | `make simulate` (`SIM_FAST=1` to skip venv builds) | Needs Unix/WSL + rsync + uv — not run |

## Inspection

| Task | Command |
|---|---|
| List Delta log | `Get-ChildItem _lakehouse/scratch/users_delta/_delta_log` |
| Show one commit | `Get-Content _lakehouse/scratch/users_delta/_delta_log/00000000000000000001.json` |
| Count data files on disk | `Get-ChildItem _lakehouse/scratch/events_smallfiles -Filter *.parquet \| Measure-Object` |
| Checkpoint pointer | `Get-Content <table>/_delta_log/_last_checkpoint` |
| Iceberg layout | `Get-ChildItem -Recurse _lakehouse/iceberg/nb5` |

## Cleanup

| Task | Command | Notes |
|---|---|---|
| Wipe venv + data | `.\make.ps1 clean` | Removes `.venv`, `_lakehouse`, checkpoints, pytest cache |
| Reset one table | `reset(path)` in Python | `shutil.rmtree`, idempotent |
| Reset one catalog | `reset_catalog("nb5")` | Fails if a kernel holds `catalog.db` |

## Submission (git)

```powershell
New-Item -ItemType Directory -Force submission/notebooks | Out-Null
Copy-Item notebooks/[0-9]*.ipynb submission/notebooks/
git add submission/ make.ps1
git commit -m "Complete K4-Track02-Day18 Lakehouse Lab submission"
git push
git remote -v          # origin must be the personal renamed fork
```

## 📘 Optional Spark path (not run)

`make spark-up | spark-smoke | spark-data | spark-down | spark-clean` and `make apple-*` — see [spark-minio-docker](../technologies/spark-minio-docker.md).
