@echo off
cd /d "%~dp0"
echo Starting PostgreSQL + pgAdmin...
docker compose up -d
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
echo pgAdmin: http://localhost:5050  (admin@local.test / admin)
echo DB: localhost:5432  user rental  database car_rental
pause
