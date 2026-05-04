#!/usr/bin/env bash
# LAB10 / LAB8–9 S2S: два лимита CPU (0.5 и 1.0) × три смеси STATS_SHARE (5%, 50%, 95%),
# сохранение summary JSON и логов docker compose (app + additional), затем plot_lab8_reports.py.
#
# Запуск одной командой с ВМ, где доступны **docker compose** и **k6** (часто та же машина, что и стенд):
#   chmod +x run-lab10-full-matrix.sh
#   ./run-lab10-full-matrix.sh
#
# Если additional доступен через **SSH-туннель** (порт 8084 на этой ВМ проброшен на стенд):
#   export BASE_URL="http://127.0.0.1:8084"
#
# Если k6 на другой машине, а compose локально — по умолчанию скрипт не подходит; задайте REMOTE только
# для docker (не реализовано) или запускайте скрипт на ВМ с compose и укажите BASE_URL на внутренний IP,
# доступный с этой же ВМ для k6 (или туннель на localhost).
#
# Переменные окружения (опционально):
#   ZIL_ROOT          — каталог zil (по умолчанию родитель этого скрипта)
#   ENV_FILE          — env для compose (по умолчанию ZIL_ROOT/registry-tags-lab8-hl7.env)
#   BASE_URL          — URL additional без завершающего / (по умолчанию http://127.0.0.1:8084)
#   OUT_DIR           — куда писать JSON и PNG (по умолчанию ./reports-lab10-s2s)
#   LOG_DIR           — куда писать логи compose (по умолчанию OUT_DIR/lab10-run-logs)
#   TARGET_VUS        — по умолчанию 20
#   DURATION          — по умолчанию 3m
#   WARMUP_SEC        — пауза после recreate контейнеров, по умолчанию 45
#   SKIP_PLOT         — если 1: не вызывать plot_lab8_reports.py
#   APP_CHECK_URL     — проверка основного app после up (по умолчанию http://127.0.0.1:8083/stats);
#                       при туннеле только на 8084 задайте пусто: APP_CHECK_URL=

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZIL_ROOT="${ZIL_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
ENV_FILE="${ENV_FILE:-$ZIL_ROOT/registry-tags-lab8-hl7.env}"
BASE_URL="${BASE_URL:-http://127.0.0.1:8084}"
BASE_URL="${BASE_URL%/}"
OUT_DIR="${OUT_DIR:-$SCRIPT_DIR/reports-lab10-s2s}"
LOG_DIR="${LOG_DIR:-$OUT_DIR/lab10-run-logs}"
TARGET_VUS="${TARGET_VUS:-20}"
DURATION="${DURATION:-3m}"
WARMUP_SEC="${WARMUP_SEC:-45}"
SKIP_PLOT="${SKIP_PLOT:-0}"
APP_CHECK_URL="${APP_CHECK_URL:-http://127.0.0.1:8083/stats}"

export BASE_URL
export TARGET_VUS
export DURATION

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Нужна команда: $1" >&2
    exit 1
  }
}

require k6
require docker

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Нет файла: $ENV_FILE" >&2
  exit 1
fi

mkdir -p "$OUT_DIR" "$LOG_DIR"

compose() {
  docker compose --project-directory "$ZIL_ROOT" --env-file "$ENV_FILE" "$@"
}

run_k6_and_logs() {
  local cpu_tag="$1"
  local mix_tag="$2"
  local share="$3"
  local json_path="$OUT_DIR/s2s_cpu${cpu_tag}_mix${mix_tag}.json"
  local log_path="$LOG_DIR/run_cpu${cpu_tag}_mix${mix_tag}_app_additional.log"

  echo ">>> k6 cpu=${cpu_tag} mix=${mix_tag} STATS_SHARE=${share} -> ${json_path##*/}"
  export STATS_SHARE="$share"
  k6 run --summary-export "$json_path" "$SCRIPT_DIR/load-lab8-s2s.js"

  echo ">>> logs -> ${log_path##*/}"
  compose logs --no-color app additional >"$log_path" || true
}

set_cpu_and_up() {
  local cpus="$1"
  export APP_CPUS="$cpus"
  export ADDITIONAL_CPUS="$cpus"
  echo ">>> docker compose up APP_CPUS=${cpus} ADDITIONAL_CPUS=${cpus}"
  compose up -d --force-recreate app additional
  echo ">>> ожидание прогрева ${WARMUP_SEC}s..."
  sleep "$WARMUP_SEC"

  if [[ -n "${APP_CHECK_URL}" ]]; then
    echo -n ">>> check app: "
    curl -sS -o /dev/null -w "%{http_code}\n" "$APP_CHECK_URL" || true
  fi
  echo -n ">>> check additional: "
  curl -sS -o /dev/null -w "%{http_code}\n" "${BASE_URL}/additional/stats" || true
}

set_cpu_and_up "0.5"
run_k6_and_logs "05" "05" "0.05"
run_k6_and_logs "05" "50" "0.5"
run_k6_and_logs "05" "95" "0.95"

set_cpu_and_up "1.0"
run_k6_and_logs "10" "05" "0.05"
run_k6_and_logs "10" "50" "0.5"
run_k6_and_logs "10" "95" "0.95"

if [[ "$SKIP_PLOT" != "1" ]]; then
  echo ">>> plot_lab8_reports.py $OUT_DIR"
  if command -v python3 >/dev/null 2>&1; then
    python3 "$SCRIPT_DIR/plot_lab8_reports.py" "$OUT_DIR" || {
      echo "Предупреждение: не удалось построить PNG (нужен matplotlib?). JSON и логи уже сохранены." >&2
    }
  else
    echo "python3 не найден — пропуск графиков." >&2
  fi
else
  echo ">>> SKIP_PLOT=1 — графики не строились."
fi

echo "Готово. JSON: $OUT_DIR ; логи: $LOG_DIR ; PNG: $OUT_DIR/lab8_latency_vs_cpu.png (при успехе plot)"
