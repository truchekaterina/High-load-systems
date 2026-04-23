# =============================================================================
# LAB4 — one script: run k6 at several VU levels, then draw a chart with Python.
# Usage (from zil\k6):  .\run-lab4.ps1
#
# Why user-visible strings are English only:
#   Windows PowerShell 5.1 may mis-read UTF-8 *without* BOM; Cyrillic inside "quotes"
#   can break the parser. Comments (# ...) are usually fine; to stay safe, comments here are English.
# =============================================================================

# Stop on first error (typical for small automation scripts).
$ErrorActionPreference = "Stop"

# Directory where this .ps1 file lives (zil\k6).
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
# k6 json summaries + png go here (created if missing).
$outDir = Join-Path $here "reports"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# PLOT_ONLY=1: you already have summary-vus-*.json and only need avg_vs_vus.png (saves a lot of time).
$plotOnly = ($env:PLOT_ONLY -eq "1")

# These are read by k6 as __ENV in load.js. Defaults match docker-compose on host.
if (-not $env:BASE_URL) { $env:BASE_URL = "http://localhost:8083" }
if (-not $env:POST_SHARE) { $env:POST_SHARE = "0.5" }
# VUS_LIST e.g. "10 20 40" — split on whitespace. Default: sweep used for the lab table/graph.
$steps = if ($env:VUS_LIST) { $env:VUS_LIST -split '\s+' } else { @(10, 20, 40, 80, 160) }

# Optional cleanup so old json/png from a previous run do not mix with a new one.
# Skip when PLOT_ONLY (we need existing files) or NO_CLEAN=1.
if (-not $plotOnly -and $env:NO_CLEAN -ne "1") {
  Remove-Item (Join-Path $outDir "summary-vus-*.json") -ErrorAction SilentlyContinue
  Remove-Item (Join-Path $outDir "avg_vs_vus.png") -ErrorAction SilentlyContinue
}

# --- k6 phase (skipped if PLOT_ONLY) ---
if (-not $plotOnly) {
  if (-not (Get-Command k6 -ErrorAction SilentlyContinue)) {
    Write-Error "k6 not in PATH. Install: winget install grafana.k6"
    exit 1
  }

  $loadJs = Join-Path $here "load.js"
  foreach ($n in $steps) {
    Write-Host "=== TARGET_VUS=$n ==="
    # k6 load.js uses this to set total VU and scenario split.
    $env:TARGET_VUS = "$n"
    # --summary-export writes machine-readable json for the Python plotter below.
    & k6 run --summary-export (Join-Path $outDir "summary-vus-$n.json") $loadJs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
}

if ($plotOnly) { Write-Host "PLOT_ONLY=1: skipping k6; chart from reports\summary-vus-*.json" }

# User may want only json from k6, no matplotlib step.
if ($env:NO_PLOT -eq "1") { Write-Host "Done (NO_PLOT=1, no chart)."; exit 0 }

# Python launcher: prefer "py" (Windows), then "python", then "python3".
$py = (Get-Command py -ErrorAction SilentlyContinue)
if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }
if (-not $py) { $py = Get-Command python3 -ErrorAction SilentlyContinue }
if (-not $py) {
  Write-Warning "Python not found; chart skipped. Install: pip install matplotlib"
  exit 0
}

# plot_k6_reports.py reads this env var; comments in the .py file are in Russian
$env:K6_REPORTS_DIR = $outDir
$plotScript = Join-Path $here "plot_k6_reports.py"
& $py.Path $plotScript
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
