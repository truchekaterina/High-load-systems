@echo off
REM Только PostgreSQL (для запуска приложения из IntelliJ / gradlew bootRun)
cd /d "%~dp0"
echo Starting PostgreSQL...
docker compose up -d postgres
if errorlevel 1 (
  echo.
  echo ERROR: Docker did not start. Open Docker Desktop and wait until it is fully running, then run this file again.
  pause
  exit /b 1
)
echo.
docker compose ps
echo.
docker exec zil-postgres pg_isready -U rental -d car_rental
echo.
echo DB: localhost:5433  user rental  database car_rental
echo Полный стенд app+DB: docker compose up --build -d
pause
