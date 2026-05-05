#!/usr/bin/env bash
# LAB10 / LAB9-стиль: только ВМ с docker compose (hl07). На ВМ k6 используйте lab10-hl11-k6-matrix.sh.
#
# Примеры:
#   ./lab10-hl07-docker.sh up 0.5
#   ./lab10-hl07-docker.sh up 1.0
#   ./lab10-hl07-docker.sh logs   # вывод в stdout (перенаправьте в файл при необходимости)
#
# Переменные (опционально): ZIL_ROOT, ENV_FILE, WARMUP_SEC
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZIL_ROOT="${ZIL_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
ENV_FILE="${ENV_FILE:-$ZIL_ROOT/registry-tags-lab8-hl7.env}"
WARMUP_SEC="${WARMUP_SEC:-45}"

usage() {
  echo "Usage: $0 up <0.5|1.0>   — APP_CPUS/ADDITIONAL_CPUS, compose up app+additional, прогрев, curl" >&2
  echo "       $0 logs          — docker compose logs --no-color app additional (stdout)" >&2
  exit 1
}

[[ "${1:-}" ]] || usage
cmd="$1"

if [[ "$cmd" == "up" ]]; then
  cpu="${2:-}"
  if [[ "$cpu" != "0.5" && "$cpu" != "1.0" ]]; then
    echo "Аргумент CPU должен быть 0.5 или 1.0, получено: ${cpu:-пусто}" >&2
    usage
  fi
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "Нет env-файла: $ENV_FILE" >&2
    exit 1
  fi
  export APP_CPUS="$cpu"
  export ADDITIONAL_CPUS="$cpu"
  echo ">>> compose up APP_CPUS=${cpu} ADDITIONAL_CPUS=${cpu} (каталог: $ZIL_ROOT)"
  (cd "$ZIL_ROOT" && docker compose --env-file "$ENV_FILE" up -d --force-recreate app additional)
  echo ">>> прогрев ${WARMUP_SEC}s..."
  sleep "$WARMUP_SEC"
  echo -n ">>> app 8083 /stats: "
  curl -sS -o /dev/null -w "%{http_code}\n" "http://127.0.0.1:8083/stats" || true
  echo -n ">>> additional 8084 /additional/stats: "
  curl -sS -o /dev/null -w "%{http_code}\n" "http://127.0.0.1:8084/additional/stats" || true
elif [[ "$cmd" == "logs" ]]; then
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "Нет env-файла: $ENV_FILE" >&2
    exit 1
  fi
  (cd "$ZIL_ROOT" && docker compose --env-file "$ENV_FILE" logs --no-color app additional)
else
  usage
fi
