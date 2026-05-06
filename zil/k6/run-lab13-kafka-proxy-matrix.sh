#!/usr/bin/env bash
# LAB13: матрица CPU 0.5|1.0 (app + additional) × KAFKA_LISTENER_CONCURRENCY 1|2.
# По SSH пересоздаём контейнеры на ВМ приложений (типично **2307**), локально запускаем **k6** → прокси → Kafka.
#
# Прокси (**uvicorn** на этом же узле что и k6) должен быть уже запущен с нужными KAFKA_*.
#
# Способ как в LAB10:
#   1) На ВМ с k6: скопируйте lab13-stand.env.example → lab13-stand.env, подставьте SSH/пути/BASE_URL.
#   2) ./lab13-k6-matrix.sh
#
# Или только переменные окружения (см. lab13-stand.env.example):
#   DOCKER_SSH / HL07_SSH, REMOTE_ZIL, REMOTE_ENV_FILE, PROXY_URL, BASE_URL, APP_CHECK_URL ...
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${LAB13_USE_STAND_ENV:-}" == 1 ]]; then
  if [[ ! -f "$SCRIPT_DIR/lab13-stand.env" ]]; then
    echo "Нет файла $SCRIPT_DIR/lab13-stand.env — скопируйте lab13-stand.env.example и заполните." >&2
    exit 1
  fi
  set -a
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/lab13-stand.env"
  set +a
fi

ZIL_ROOT="${ZIL_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
ENV_FILE="${ENV_FILE:-$ZIL_ROOT/registry-tags-lab8-hl7.env}"
DOCKER_SSH="${DOCKER_SSH:-${HL07_SSH:-}}"
REMOTE_ZIL="${REMOTE_ZIL:-/home/hl/work/Labs_hls/zil}"
REMOTE_ENV_FILE="${REMOTE_ENV_FILE:-registry-tags-lab8-hl7.env}"

PROXY_URL="${PROXY_URL:-http://127.0.0.1:18080/publish}"
export PROXY_URL

BASE_URL="${BASE_URL:-http://127.0.0.1:8084}"
BASE_URL="${BASE_URL%/}"
OUT_DIR="${OUT_DIR:-$SCRIPT_DIR/reports-lab13}"
LOG_DIR="${LOG_DIR:-$OUT_DIR/lab13-run-logs}"
TARGET_VUS="${TARGET_VUS:-20}"
DURATION="${DURATION:-3m}"
WARMUP_SEC="${WARMUP_SEC:-45}"
SKIP_PLOT="${SKIP_PLOT:-0}"
SKIP_PROXY_CHECK="${SKIP_PROXY_CHECK:-0}"
APP_CHECK_URL="${APP_CHECK_URL:-http://127.0.0.1:8083/stats}"

export TARGET_VUS
export DURATION
export BASE_URL

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Нужна команда: $1" >&2
    exit 1
  }
}

derive_proxy_health_url() {
  local u="$PROXY_URL"
  if [[ "$u" == */publish ]]; then
    echo "${u%/publish}/health"
  else
    echo "${PROXY_HEALTH_URL:-http://127.0.0.1:18080/health}"
  fi
}

require_k6_or_hint() {
  if command -v k6 >/dev/null 2>&1; then
    return 0
  fi
  echo "Нужна команда: **k6** на этой машине. docker compose через DOCKER_SSH уходит по SSH на ВМ приложений." >&2
  if [[ -z "${DOCKER_SSH}" ]] && command -v docker >/dev/null 2>&1; then
    echo "Запускайте матрицу с ВМ нагрузки (k6): задайте DOCKER_SSH (или HL07_SSH из lab13-stand.env)." >&2
  fi
  exit 1
}

require_k6_or_hint
require curl

if [[ -z "${DOCKER_SSH}" ]]; then
  require docker
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "Нет файла env: $ENV_FILE" >&2
    exit 1
  fi
else
  require ssh
fi

mkdir -p "$OUT_DIR" "$LOG_DIR"

compose() {
  if [[ -n "${DOCKER_SSH}" ]]; then
    local remote_cmd
    remote_cmd=$(printf '%q ' "$@")
    ssh "$DOCKER_SSH" \
      "export APP_CPUS=$(printf '%q' "${APP_CPUS:-}") ADDITIONAL_CPUS=$(printf '%q' "${ADDITIONAL_CPUS:-}") KAFKA_LISTENER_CONCURRENCY=$(printf '%q' "${KAFKA_LISTENER_CONCURRENCY:-}"); cd $(printf '%q' "$REMOTE_ZIL") && docker compose --env-file $(printf '%q' "$REMOTE_ENV_FILE") $remote_cmd"
  else
    docker compose --project-directory "$ZIL_ROOT" --env-file "$ENV_FILE" "$@"
  fi
}

check_proxy() {
  if [[ "$SKIP_PROXY_CHECK" == 1 ]]; then
    return 0
  fi
  local h
  h="$(derive_proxy_health_url)"
  echo ">>> проверка прокси GET $h"
  curl -sS -o /dev/null -f "$h" || {
    echo "Прокси не отвечает на $h. Запустите uvicorn в lab13-kafka-proxy (или SKIP_PROXY_CHECK=1)." >&2
    exit 1
  }
}

set_cpu_conc_and_up() {
  local cpus="$1"
  local conc="$2"
  export APP_CPUS="$cpus"
  export ADDITIONAL_CPUS="$cpus"
  export KAFKA_LISTENER_CONCURRENCY="$conc"

  echo ">>> compose up CPUs=${cpus} KAFKA_LISTENER_CONCURRENCY=${conc} ($([[ -n "${DOCKER_SSH}" ]] && echo "SSH ${DOCKER_SSH}" || echo "локально"))"
  compose up -d --force-recreate app additional
  echo ">>> прогрев ${WARMUP_SEC}s..."
  sleep "$WARMUP_SEC"

  if [[ -n "${APP_CHECK_URL}" ]]; then
    echo -n ">>> check app: "
    curl -sS -o /dev/null -w "%{http_code}\n" "$APP_CHECK_URL" || true
  fi
  echo -n ">>> check additional: "
  curl -sS -o /dev/null -w "%{http_code}\n" "${BASE_URL}/additional/stats" || true
}

run_k6_export_logs() {
  local cpu_tag="$1"
  local conc="$2"
  local json_path="$OUT_DIR/summary_CPU${cpu_tag}_conc${conc}.json"
  local log_path="$LOG_DIR/run_CPU${cpu_tag}_conc${conc}_app_additional.log"

  check_proxy
  echo ">>> k6 summary -> ${json_path##*/}"
  k6 run --summary-export "$json_path" "$SCRIPT_DIR/load-lab13-kafka-proxy.js"

  echo ">>> docker logs -> ${log_path##*/}"
  compose logs --no-color app additional >"$log_path" || true
}

# Порядок как в LAB13_MANUAL_FULL_RU.md §0.8: сначала стенд 2307, затем k6 на этой ВМ.
set_cpu_conc_and_up "0.5" 1
run_k6_export_logs "05" 1

set_cpu_conc_and_up "0.5" 2
run_k6_export_logs "05" 2

set_cpu_conc_and_up "1.0" 1
run_k6_export_logs "10" 1

set_cpu_conc_and_up "1.0" 2
run_k6_export_logs "10" 2

if [[ "$SKIP_PLOT" != 1 ]]; then
  echo ">>> plot_lab13_reports.py $OUT_DIR"
  if command -v python3 >/dev/null 2>&1; then
    python3 "$SCRIPT_DIR/plot_lab13_reports.py" "$OUT_DIR" || {
      echo "Предупреждение: графики LAB13 не построены (matplotlib?). JSON в $OUT_DIR" >&2
    }
  else
    echo "python3 не найден — графики пропущены." >&2
  fi
else
  echo ">>> SKIP_PLOT=1"
fi

echo "Готово. JSON: $OUT_DIR ; логи compose: $LOG_DIR"
