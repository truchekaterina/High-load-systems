# Поднять postgres + app (образ app из Docker Hub / ZIL_APP_IMAGE, см. docker-compose.yml) и открыть Swagger.
# Запуск:  cd zil  ;  .\open-swagger.ps1
#
# Для локального стека задаём DBHOST=postgres (имя сервиса в сети compose), как раньше JDBC на postgres:5432 в LAB6.

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$env:DBHOST = "postgres"
$env:DBPORT = "5432"
$env:DBNAME = "car_rental"
$env:SCHEMANAME = "public"
$env:SPRING_DATASOURCE_USERNAME = "rental"
$env:SPRING_DATASOURCE_PASSWORD = "rental_pass"

Write-Host "docker compose --profile local-db up -d (pull image if needed, postgres + app)..." -ForegroundColor Cyan
docker compose --profile local-db up -d
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
