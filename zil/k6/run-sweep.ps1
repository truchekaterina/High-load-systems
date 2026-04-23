# LAB4: серия прогонов k6 (Windows / PowerShell)
# Точки VU: по умолчанию 10 20 40 80 160; JSON в k6\reports\
#
# Примеры:
#   cd zil\k6
#   .\run-sweep.ps1
#   $env:BASE_URL = "http://localhost:8083"; .\run-sweep.ps1
#   $env:NO_PLOT = "1"     # только JSON
#   $env:NO_CLEAN = "1"   # не чистить reports перед прогоном

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Reports = Join-Path $ScriptDir "reports"
New-Item -ItemType Directory -Force -Path $Reports | Out-Null

if (-not $env:BASE_URL) { $env:BASE_URL = "http://localhost:8083" }
if (-not $env:POST_SHARE) { $env:POST_SHARE = "0.5" }

$vusList = if ($env:VUS_LIST) { $env:VUS_LIST -split '\s+' } else { @(10, 20, 40, 80, 160) }

if ($env:NO_CLEAN -ne "1") {
  Write-Host "Очистка $Reports (summary-vus-*.json, avg_vs_vus.png)..."
  Remove-Item (Join-Path $Reports "summary-vus-*.json") -ErrorAction SilentlyContinue
  Remove-Item (Join-Path $Reports "avg_vs_vus.png") -ErrorAction SilentlyContinue
} else {
  Write-Host "NO_CLEAN=1 — старые отчёты не удаляю."
}

$k6 = Get-Command k6 -ErrorAction SilentlyContinue
if (-not $k6) {
  Write-Error "k6 не найден в PATH. Установите: winget install grafana.k6 либо MSI с https://k6.io/docs/get-started/installation/ — и перезапустите терминал."
  exit 1
}

$rental = Join-Path $ScriptDir "rental-mixed.js"
foreach ($v in $vusList) {
  Write-Host "=== TARGET_VUS=$v (native k6) ==="
  $out = Join-Path $Reports "summary-vus-$v.json"
  $env:TARGET_VUS = "$v"
  & k6 run --summary-export $out $rental
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host "Готово. JSON: $Reports\summary-vus-*.json"

if ($env:NO_PLOT -eq "1") {
  Write-Host "NO_PLOT=1 — график не строю."
  exit 0
}

$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) { $py = Get-Command python3 -ErrorAction SilentlyContinue }
if (-not $py) {
  Write-Warning "Python не найден — график пропущен. Установите Python и: pip install matplotlib"
  exit 0
}
& $py.Path (Join-Path $ScriptDir "plot_avg_vs_vus.py") $Reports
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
