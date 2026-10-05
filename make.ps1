<#
.SYNOPSIS
  PowerShell equivalent of the Makefile for Windows (no GNU Make / WSL needed).

.EXAMPLE
  .\make.ps1 setup
  .\make.ps1 smoke
  .\make.ps1 run-all

  If scripts are blocked:  powershell -ExecutionPolicy Bypass -File .\make.ps1 <target>
#>
param(
    [Parameter(Position = 0)]
    [string]$Target = 'help'
)

$ErrorActionPreference = 'Stop'
Set-Location -Path $PSScriptRoot
$env:PYTHONUTF8 = '1'

$Venv     = '.venv'
$Py       = Join-Path $Venv 'Scripts\python.exe'
$Compose  = @('compose', '-f', 'infra/docker-compose.yml')

function Invoke-Native {
    param([string]$Exe, [string[]]$Arguments)
    & $Exe @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Command failed (exit $LASTEXITCODE): $Exe $($Arguments -join ' ')" }
}

function Assert-Venv {
    if (-not (Test-Path $Py)) { throw "Missing $Py. Run '.\make.ps1 setup' first." }
}

function Get-NotebookSources {
    # Only the 8 numbered notebooks; skip the _setup.py helper
    Get-ChildItem notebooks -Filter '*.py' | Where-Object { $_.Name -match '^[0-9]' } |
        ForEach-Object { $_.FullName }
}

function Sync-Notebooks {
    foreach ($nb in Get-NotebookSources) {
        $ipynb = [IO.Path]::ChangeExtension($nb, '.ipynb')
        if (Test-Path $ipynb) {
            Invoke-Native $Py @('-m', 'jupytext', '--to', 'notebook', '--update', $nb)
        } else {
            Invoke-Native $Py @('-m', 'jupytext', '--to', 'notebook', $nb)
        }
    }
}

$Targets = [ordered]@{
    # ---- Lightweight path (default) ----
    'help'     = @{ Desc = 'Show this help'; Run = {
        Write-Host "`nUsage:`n  .\make.ps1 <target>`n"
        foreach ($k in $Targets.Keys) {
            Write-Host ('  {0,-14} {1}' -f $k, $Targets[$k].Desc)
        }
        Write-Host ''
    } }
    'setup'    = @{ Desc = '[lite] Create venv + install deps + build .ipynb'; Run = {
        $uv = Get-Command uv -ErrorAction SilentlyContinue
        if (-not (Test-Path $Py)) {
            if ($uv) { Invoke-Native 'uv' @('venv', $Venv, '--python', '>=3.10,<3.15') }
            else     { Invoke-Native 'python' @('-m', 'venv', $Venv) }
        }
        & $Py -c 'import sys; raise SystemExit(0 if (3,10)<=sys.version_info[:2]<(3,15) else 1)'
        if ($LASTEXITCODE -ne 0) { throw 'Need Python 3.10-3.14. Install uv or run: py -3.11 -m venv .venv' }
        if ($uv) { Invoke-Native 'uv' @('pip', 'install', '--python', $Py, '-r', 'requirements.txt') }
        else     { Invoke-Native $Py @('-m', 'pip', 'install', '-q', '-r', 'requirements.txt') }
        Sync-Notebooks
        Write-Host "`n  Setup complete. Run '.\make.ps1 smoke' then '.\make.ps1 lab'."
    } }
    'smoke'    = @{ Desc = '[lite] Offline smoke test (9 checks)'; Run = {
        Assert-Venv; Invoke-Native $Py @('scripts/verify_lite.py')
    } }
    'test'     = @{ Desc = '[lite] Run the pytest suite (24 tests)'; Run = {
        Assert-Venv; Invoke-Native $Py @('-m', 'pytest', '-q')
    } }
    'lab'      = @{ Desc = '[lite] Open Jupyter Lab on http://localhost:8888'; Run = {
        Assert-Venv; Sync-Notebooks
        Invoke-Native $Py @('-m', 'jupyter', 'lab', '--notebook-dir=notebooks', "--ServerApp.token=", '--no-browser')
    } }
    'data'     = @{ Desc = '[lite] Generate 200K-row Bronze sample for NB4'; Run = {
        Assert-Venv; Invoke-Native $Py @('scripts/generate_data_lite.py')
    } }
    'data-ai'  = @{ Desc = '[lite] Generate multimodal + agent traces for NB7/NB8'; Run = {
        Assert-Venv; Invoke-Native $Py @('scripts/generate_ai_data.py')
    } }
    'run-all'  = @{ Desc = '[lite] Execute all 8 notebooks + assertions headlessly'; Run = {
        Assert-Venv; Invoke-Native $Py @('scripts/run_all.py')
    } }
    'simulate' = @{ Desc = '[lite] 12 student scenarios (needs Unix tools: rsync, uv)'; Run = {
        Assert-Venv; Invoke-Native $Py @('tests/simulate_students.py')
    } }
    'clean'    = @{ Desc = '[lite] Wipe venv + lakehouse data'; Run = {
        foreach ($p in @($Venv, '_lakehouse', 'notebooks/.ipynb_checkpoints', '.pytest_cache')) {
            if (Test-Path $p) { Remove-Item -Recurse -Force $p; Write-Host "  removed $p" }
        }
    } }

    # ---- Spark + Docker path (optional) ----
    'spark-up'    = @{ Desc = '[spark] Start MinIO + Spark/Jupyter (Docker)'; Run = {
        Invoke-Native 'docker' ($Compose + @('up', '-d'))
        Write-Host '  Jupyter -> http://localhost:8888 (token: lakehouse)'
        Write-Host '  MinIO   -> http://localhost:9001 (minioadmin / minioadmin)'
    } }
    'spark-smoke' = @{ Desc = '[spark] Smoke test inside Spark container'; Run = {
        Invoke-Native 'docker' ($Compose + @('exec', '-T', 'spark', 'python', '/workspace/scripts/verify.py'))
    } }
    'spark-data'  = @{ Desc = '[spark] Generate 1M-row Bronze (Spark version)'; Run = {
        Invoke-Native 'docker' ($Compose + @('exec', '-T', 'spark', 'python', '/workspace/scripts/generate_data.py'))
    } }
    'spark-down'  = @{ Desc = '[spark] Stop Docker stack (data persists)'; Run = {
        Invoke-Native 'docker' ($Compose + @('down'))
    } }
    'spark-clean' = @{ Desc = '[spark] Stop AND wipe MinIO + ivy cache'; Run = {
        Invoke-Native 'docker' ($Compose + @('down', '-v'))
    } }
}

if (-not $Targets.Contains($Target)) {
    if ($Target -like 'apple-*') {
        Write-Error "'$Target' needs macOS + Apple 'container'; not available on Windows."
    } else {
        Write-Error "Unknown target '$Target'. Run '.\make.ps1 help'."
    }
    exit 1
}

try {
    & $Targets[$Target].Run
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
