#!/usr/bin/env bash
# ВМ приложения: SSH hl@hlssh.zil.digital -p 2307 (или свой порт из таблицы курса).
# Запуск на ВМ из каталога first_laba/zil (рядом с docker-compose.yml).
#
# Перед первым деплоем: docker login hl13.zil:8888 ; при необходимости в /etc/docker/daemon.json
# "insecure-registries": ["hl13.zil:8888"] и перезапуск docker.

set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -f registry-tags-lab8-hl7.env ]]; then
  echo "Скопируйте registry-tags-lab8-hl7.env рядом с compose (DBHOST/DBPORT/ZIL_* и пароль БД)."
  exit 1
fi
set -a
# shellcheck source=/dev/null
source ./registry-tags-lab8-hl7.env
set +a

export APP_CPUS="${APP_CPUS:-0.5}"
export ADDITIONAL_CPUS="${ADDITIONAL_CPUS:-0.5}"

git fetch origin
git checkout lab8-ads
git pull origin lab8-ads

docker compose pull
# Без профиля local-db контейнер postgres не стартует; app подключается к DBHOST/DBPORT из env.
docker compose up -d --force-recreate

echo "--- smoke (на ВМ, localhost) ---"
curl -sS -o /dev/null -w "8083/stats -> %{http_code}\n" "http://127.0.0.1:8083/stats" || true
curl -sS -o /dev/null -w "8084/additional/health -> %{http_code}\n" "http://127.0.0.1:8084/additional/health" || true
curl -sS -o /dev/null -w "8084/additional/stats -> %{http_code}\n" "http://127.0.0.1:8084/additional/stats" || true
