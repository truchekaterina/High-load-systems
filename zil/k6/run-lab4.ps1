# Один скрипт: прогон k6 несколько раз + PNG-график (Python встроен внизу, не отдельный файл).
# Из папки zil\k6:  .\run-lab4.ps1
# Нужны: k6, Python,  pip install matplotlib, поднятое API (docker compose в zil).

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$outDir = Join-Path $here "reports"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

if (-not $env:BASE_URL) { $env:BASE_URL = "http://localhost:8083" }
if (-not $env:POST_SHARE) { $env:POST_SHARE = "0.5" }
$steps = if ($env:VUS_LIST) { $env:VUS_LIST -split '\s+' } else { @(10, 20, 40, 80, 160) }

if ($env:NO_CLEAN -ne "1") {
  Remove-Item (Join-Path $outDir "summary-vus-*.json") -ErrorAction SilentlyContinue
  Remove-Item (Join-Path $outDir "avg_vs_vus.png") -ErrorAction SilentlyContinue
}

if (-not (Get-Command k6 -ErrorAction SilentlyContinue)) {
  Write-Error "Нет k6. Поставь: winget install grafana.k6"
  exit 1
}

$loadJs = Join-Path $here "load.js"
foreach ($n in $steps) {
  Write-Host "=== TARGET_VUS=$n ==="
  $env:TARGET_VUS = "$n"
  & k6 run --summary-export (Join-Path $outDir "summary-vus-$n.json") $loadJs
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if ($env:NO_PLOT -eq "1") { Write-Host "Готово (без картинки)."; exit 0 }

$py = (Get-Command py -ErrorAction SilentlyContinue)
if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }
if (-not $py) { $py = Get-Command python3 -ErrorAction SilentlyContinue }
if (-not $py) {
  Write-Warning "Python не найден — картинка не рисуется. Нужен: pip install matplotlib"
  exit 0
}

$env:K6_REPORTS_DIR = $outDir
$draw = @'
import json, os, re, sys
from pathlib import Path
try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
except ImportError:
    print("pip install matplotlib", file=sys.stderr)
    sys.exit(1)

def get_avg(m):
    if not m:
        return None
    val = m.get("values")
    if isinstance(val, dict) and val.get("avg") is not None:
        return float(val["avg"])
    if m.get("avg") is not None:
        return float(m["avg"])
    return None

root = Path(os.environ["K6_REPORTS_DIR"])
pat = re.compile(r"^summary-vus-(\d+)\.json$")
post_pts, get_pts = [], []
for f in sorted(root.glob("summary-vus-*.json")):
    m = pat.match(f.name)
    if not m:
        continue
    v = int(m.group(1))
    data = json.loads(f.read_text(encoding="utf-8"))
    met = data.get("metrics") or {}
    a = get_avg(met.get("post_ms") or {})
    b = get_avg(met.get("get_ms") or {})
    if a is not None:
        post_pts.append((v, a))
    if b is not None:
        get_pts.append((v, b))

if len(post_pts) < 1 or len(get_pts) < 1:
    print("Нужны метрики post_ms и get_ms в json", file=sys.stderr)
    sys.exit(1)

post_pts.sort(key=lambda t: t[0])
get_pts.sort(key=lambda t: t[0])
vp = [a[0] for a in post_pts]
yp = [a[1] for a in post_pts]
vg = [a[0] for a in get_pts]
yg = [a[1] for a in get_pts]
plt.figure(figsize=(9, 5.5))
plt.plot(vp, yp, "o-", label="POST /clients", color="#1f77b4", linewidth=2, markersize=7)
plt.plot(vg, yg, "s-", label="GET /stats", color="#ff7f0e", linewidth=2, markersize=7)
plt.legend()
plt.xlabel("TARGET_VUS")
plt.ylabel("Среднее время, мс")
plt.title("k6: задержка vs число VU")
plt.grid(True, alpha=0.3)
plt.tight_layout()
out = root / "avg_vs_vus.png"
plt.savefig(out, dpi=150)
print("Сохранено:", out)
'@

$draw | & $py.Path -
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
