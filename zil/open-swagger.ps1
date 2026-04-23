# Swagger: поднять postgres + app и открыть UI в браузере.
# По умолчанию: bootJar на Windows + тонкий Docker-образ (без Gradle в контейнере) — стабильнее при обрывах Docker (rpc EOF).
# Полная сборка в Docker (долго):  docker compose up --build -d
#
# Запуск:  cd zil  ;  .\open-swagger.ps1

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "Gradle: bootJar (fat JAR на хосте)..." -ForegroundColor Cyan
.\gradlew.bat bootJar -x test --no-daemon
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$bootJar = Get-ChildItem -Path "build\libs" -Filter "*.jar" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch '-plain\.jar$' } |
    Select-Object -First 1
if (-not $bootJar) {
    Write-Error "Не найден fat JAR в build\libs (нужен bootJar без -plain)."
    exit 1
}

New-Item -ItemType Directory -Force -Path "docker-staging" | Out-Null
Copy-Item -Path $bootJar.FullName -Destination "docker-staging\app.jar" -Force
Write-Host "Copied: $($bootJar.Name) -> docker-staging\app.jar" -ForegroundColor Cyan

Write-Host "docker compose (postgres + app, Dockerfile.prebuilt)..." -ForegroundColor Cyan
docker compose -f docker-compose.yml -f docker-compose.prebuilt.yml up --build -d
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
