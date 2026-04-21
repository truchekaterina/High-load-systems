@echo off
setlocal
cd /d "%~dp0"
call gradlew.bat bootJar -x test --no-daemon
if errorlevel 1 exit /b 1
copy /Y "build\libs\module1-1.0-SNAPSHOT.jar" "docker\app.jar"
if errorlevel 1 exit /b 1
echo OK: docker\app.jar ready. Next: docker compose up --build -d
