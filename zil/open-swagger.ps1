# Поднять postgres + app. Образ по умолчанию — Harbor (см. docker-compose.yml): hlssh.zil.digital:2313/.../zil-app:lab6
# Логин: docker login hlssh.zil.digital:2313  (учётка/пароль из таблицы курса, см. LAB8_PLAN_RU.md)
# Если pull не удался (образа ещё нет / не залогинена) — локальная сборка с тем же тегом, затем push в Harbor.
# Запуск:  cd zil  ;  .\open-swagger.ps1

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$defaultTag = "hlssh.zil.digital:2313/truchekaterina/zil-app:lab6"
if (-not $env:ZIL_APP_IMAGE) { $env:ZIL_APP_IMAGE = $defaultTag }

Write-Host "docker compose pull app (реестр)..." -ForegroundColor Cyan
docker compose pull app
if ($LASTEXITCODE -ne 0) {
    Write-Host "Pull не вышел — локальная сборка: docker build -t $($env:ZIL_APP_IMAGE) . (может занять несколько минут)..." -ForegroundColor Yellow
    docker build -t $env:ZIL_APP_IMAGE .
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
Write-Host "docker compose up -d (postgres + app)..." -ForegroundColor Cyan
docker compose up -d
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
