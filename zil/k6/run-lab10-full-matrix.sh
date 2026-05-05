#!/usr/bin/env bash
# LAB10 / LAB8–9 S2S: CPU 0.5 и 1.0 × смеси STATS_SHARE 5% / 50% / 95%,
# summary JSON, логи docker compose (app + additional), plot_lab8_reports.py.
#
# Как в LAB9 (Docker на hl07, k6 на hl11):
#   1) На hl11: скопируйте lab10-stand.env.example → lab10-stand.env, подставьте IP/пути/SSH.
#   2) ./lab10-hl11-k6-matrix.sh
# На hl07 вручную (если без авто-матрицы): ./lab10-hl07-docker.sh up 0.5|1.0
#
# Либо без файла — экспорт DOCKER_SSH / BASE_URL и этот скрипт (см. LAB10_MANUAL_FULL_RU.md).
#
# **Редко:** docker и k6 на одной ВМ — DOCKER_SSH не задавайте.
#
# Переменные окружения (опционально):
#   DOCKER_SSH, HL07_SSH — удалённый docker (достаточно одного; в lab10-stand.env задаётся HL07_SSH)
#   REMOTE_ZIL      — каталог zil **на удалённой** ВМ (по умолчанию /home/hl/work/Labs_hls/zil)
#   REMOTE_ENV_FILE — имя env-файла внутри REMOTE_ZIL (по умолчанию registry-tags-lab8-hl7.env)
#   ZIL_ROOT        — при локальном docker: каталог zil (по умолчанию родитель этого скрипта)
#   ENV_FILE        — при локальном docker: полный путь к env
#   BASE_URL        — URL additional для k6 (на hl11 → http://<IP_hl07>:8084)
#   OUT_DIR, LOG_DIR, TARGET_VUS, DURATION, WARMUP_SEC, SKIP_PLOT, APP_CHECK_URL — см. ниже

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${LAB10_USE_STAND_ENV:-}" == 1 ]]; then
  if [[ ! -f "$SCRIPT_DIR/lab10-stand.env" ]]; then
    echo "Нет файла $SCRIPT_DIR/lab10-stand.env — скопируйте из lab10-stand.env.example и заполните." >&2
    exit 1
  fi
  set -a
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/lab10-stand.env"
  set +a
fi

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

DOCKER_SSH="${DOCKER_SSH:-${HL07_SSH:-}}"
REMOTE_ZIL="${REMOTE_ZIL:-/home/hl/work/Labs_hls/zil}"
REMOTE_ENV_FILE="${REMOTE_ENV_FILE:-registry-tags-lab8-hl7.env}"

export BASE_URL
export TARGET_VUS
export DURATION

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Нужна команда: $1" >&2
    exit 1
  }
}

require_k6_or_hint() {
  if command -v k6 >/dev/null 2>&1; then
    return 0
  fi
  echo "Нужна команда: k6 — нагрузку запускает **эта** машина; docker compose при DOCKER_SSH уходит по SSH на hl07." >&2
  if [[ -z "${DOCKER_SSH}" ]] && command -v docker >/dev/null 2>&1; then
    echo "На ВМ с Docker (hl07) k6 не нужен. Запустите скрипт на **ВМ с k6** (hl11 и т.п.), с ssh на hl07, например:" >&2
    echo '  export DOCKER_SSH="hl@10.60.3.2" REMOTE_ZIL="/home/hl/work/Labs_hls/zil"' >&2
    echo '  export BASE_URL="http://10.60.3.2:8084" APP_CHECK_URL="http://10.60.3.2:8083/stats"' >&2
    echo '  cd ~/work/Labs_hls/zil/k6  # или ~/Labs_hls/zil/k6' >&2
    echo "Либо: cp lab10-stand.env.example lab10-stand.env, заполните, ./lab10-hl11-k6-matrix.sh" >&2
  fi
  exit 1
}

require_k6_or_hint
if [[ -z "${DOCKER_SSH}" ]]; then
  require docker
else
  require ssh
fi

if [[ -z "${DOCKER_SSH}" ]]; then
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "Нет файла: $ENV_FILE" >&2
    exit 1
  fi
fi

mkdir -p "$OUT_DIR" "$LOG_DIR"

compose() {
  if [[ -n "${DOCKER_SSH}" ]]; then
    local remote_cmd
    remote_cmd=$(printf '%q ' "$@")
    ssh "$DOCKER_SSH" \
      "export APP_CPUS=$(printf '%q' "${APP_CPUS:-}") ADDITIONAL_CPUS=$(printf '%q' "${ADDITIONAL_CPUS:-}"); cd $(printf '%q' "$REMOTE_ZIL") && docker compose --env-file $(printf '%q' "$REMOTE_ENV_FILE") $remote_cmd"
  else
    docker compose --project-directory "$ZIL_ROOT" --env-file "$ENV_FILE" "$@"
  fi
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
  echo ">>> docker compose up APP_CPUS=${cpus} ADDITIONAL_CPUS=${cpus} ($([[ -n "${DOCKER_SSH}" ]] && echo "SSH ${DOCKER_SSH}" || echo "локально"))"
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
