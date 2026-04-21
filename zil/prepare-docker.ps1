$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
& .\gradlew.bat bootJar -x test --no-daemon
Copy-Item -Force "build\libs\module1-1.0-SNAPSHOT.jar" "docker\app.jar"
Write-Host "OK: docker/app.jar готов. Дальше: docker compose up --build -d"
