# Поднять postgres + app (сборка JAR в Docker по zil/Dockerfile) и открыть Swagger в браузере.
# Первая сборка может идти несколько минут (Gradle внутри образа). При обрыве демона Docker — перезапустите Docker Desktop и повторите.
# Запуск:  cd zil  ;  .\open-swagger.ps1

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "docker compose up --build -d (postgres + app)..." -ForegroundColor Cyan
docker compose up --build -d
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Waiting for http://127.0.0.1:8083/cars (up to 90s)..." -ForegroundColor Cyan
$ok = $false
for ($i = 0; $i -lt 90; $i++) {
    try {
        $r = Invoke-WebRequest -Uri "http://127.0.0.1:8083/cars" -TimeoutSec 2 -UseBasicParsing
        if ($r.StatusCode -eq 200) { $ok = $true; break }
    } catch { }
    Start-Sleep -Seconds 1
}

if (-not $ok) {
    Write-Host "App did not respond in time. Check: docker compose logs app --tail 80" -ForegroundColor Yellow
}

$swagger = "http://127.0.0.1:8083/swagger-ui/index.html"
Write-Host "Opening $swagger" -ForegroundColor Green
Start-Process $swagger
