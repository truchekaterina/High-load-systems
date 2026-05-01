# Поднимает app + additional в Docker против удалённой БД (hl12 через registry-tags-lab8-hl7.env) и открывает Swagger в браузере.
# Первый pull образов может занять минуты. Если Docker демон падает — перезапустите Docker Desktop.
# Запуск:  cd zil  ;  .\open-swagger.ps1

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$registryEnv = Join-Path $PSScriptRoot "registry-tags-lab8-hl7.env"
if (-not (Test-Path $registryEnv)) {
    Write-Host "Не найден $registryEnv — скопируйте шаблон с ВМ или из репозитория и укажите DBHOST/JDBC-пароли." -ForegroundColor Red
    Write-Host "Локальный PostgreSQL в этом проекте не используется." -ForegroundColor Yellow
    exit 1
}

Write-Host "docker compose --env-file registry-tags-lab8-hl7.env: pull + up app (Hub), additional (Harbor)..." -ForegroundColor Cyan
docker compose --env-file $registryEnv pull app additional
docker compose --env-file $registryEnv up -d app additional
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
    Write-Host "App did not respond in time. Check: docker compose --env-file $($registryEnv) logs app --tail 80" -ForegroundColor Yellow
}

$swagger = "http://127.0.0.1:8083/swagger-ui/index.html"
Write-Host "Opening $swagger" -ForegroundColor Green
Start-Process $swagger
