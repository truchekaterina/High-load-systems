#!/usr/bin/env bash
# ВМ приложения SSH -p 2307 (hlssh.zil.digital). Запуск из каталога, где docker-compose.yml.
# После первого успешного push образов см. también ../registry-tags-lab8-hl7.env

set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -f registry-tags-lab8-hl7.env ]]; then
  echo "Скопируйте registry-tags-lab8-hl7.env рядом с compose или экспортируйте теги вручную."
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
docker compose up -d --force-recreate

echo "--- smoke (локально на ВМ ---"
curl -sS -o /dev/null -w "%{http_code}\n" "http://127.0.0.1:8083/stats" || true
curl -sS -o /dev/null -w "%{http_code}\n" "http://127.0.0.1:8084/additional/health" || curl -sS -o /dev/null -w "%{http_code}\n" "http://127.0.0.1:8084/additional/stats" || true
