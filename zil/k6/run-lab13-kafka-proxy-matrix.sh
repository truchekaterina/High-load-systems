#!/usr/bin/env bash
# LAB13: матрица измерений CPU × KAFKA_LISTENER_CONCURRENCY на **2307** + **k6** на **2311**.
#
# Запуск на ВМ k6 (рядом с прокси uvicorn):
#   • Только ТЗ §0.8 (4 прогона): ./lab13-k6-matrix.sh
#   • Графики LAB8-стиля (12 прогонов): ./lab13-k6-matrix-graphs.sh
# Файл lab13-stand.env — один раз из lab13-stand.env.example (SSH, IP, топик).
#
# Три смеси STATS_SHARE на ячейку и файлы *_mix*.json включаются скриптом ./lab13-k6-matrix-graphs.sh
# (или LAB13_MIX_PANELS=1 вручную при вызове run-lab13-kafka-proxy-matrix.sh).
#
# На **2307** compose вызывается с **двумя** env-файлами (registry + **registry-tags-lab13-topic.env** → топик **hl07-lab13**).
# Две партиции топика скрипт **не создаёт** — см. zil/scripts/kafka_lab13_create_topic_2_partitions.sh и §0.5 мануала.
#
# Прокси (**uvicorn**) должен быть уже запущен с **тем же KAFKA_TOPIC**, что и app (обычно **hl07-lab13** из lab13-stand.env).
#
# Сеть: при **DOCKER_SSH** по умолчанию **LAB13_STAND_ACCESS=auto** — если с ВМ k6 не достучаться до IP в BASE_URL,
# матрица сама поднимает SSH LocalForward на **127.0.0.1:28083** (app) и **:28084** (additional).
#
# Или напрямую этот скрипт с экспортом переменных (без lab13-stand.env — см. пример в репозитории).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LAB13_TUNNEL_PID=""
LAB13_TUNNEL_STARTED=0

cleanup_lab13_tunnel() {
  if [[ "${LAB13_TUNNEL_STARTED}" == "1" ]] && [[ -n "${LAB13_TUNNEL_PID}" ]] && kill -0 "${LAB13_TUNNEL_PID}" 2>/dev/null; then
    kill "${LAB13_TUNNEL_PID}" 2>/dev/null || true
    wait "${LAB13_TUNNEL_PID}" 2>/dev/null || true
  fi
  LAB13_TUNNEL_STARTED=0
  LAB13_TUNNEL_PID=""
}

trap cleanup_lab13_tunnel EXIT

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

# Имя запущенной обёртки перебивает LAB13_MIX_PANELS из lab13-stand.env (предсказуемый режим).
case "${LAB13_MATRIX_UI:-}" in
  tz)
    LAB13_MIX_PANELS=0
    ;;
  graphs)
    LAB13_MIX_PANELS=1
    ;;
esac

ZIL_ROOT="${ZIL_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
ENV_FILE="${ENV_FILE:-$ZIL_ROOT/registry-tags-lab8-hl7.env}"
# LAB13 ТЗ: топик с 2 партициями — см. registry-tags-lab13-topic.env (hl07-lab13)
LAB13_TOPIC_ENV="${LAB13_TOPIC_ENV:-$ZIL_ROOT/registry-tags-lab13-topic.env}"
DOCKER_SSH="${DOCKER_SSH:-${HL07_SSH:-}}"
REMOTE_ZIL="${REMOTE_ZIL:-/home/hl/work/Labs_hls/zil}"
REMOTE_ENV_FILE="${REMOTE_ENV_FILE:-registry-tags-lab8-hl7.env}"
REMOTE_ENV_TOPIC_FILE="${REMOTE_ENV_TOPIC_FILE:-registry-tags-lab13-topic.env}"

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
LAB13_PANEL_CONC="${LAB13_PANEL_CONC:-2}"
# 0 = только 4 ячейки ТЗ (§0.8); 1 = ещё три STATS_SHARE на ячейку (графики как LAB8).
LAB13_MIX_PANELS="${LAB13_MIX_PANELS:-0}"

# Доступ к стенду с ВМ k6: auto = сначала прямой BASE_URL, иначе SSH LocalForward на 127.0.0.1.
LAB13_TUNNEL_APP_PORT="${LAB13_TUNNEL_APP_PORT:-28083}"
LAB13_TUNNEL_ADD_PORT="${LAB13_TUNNEL_ADD_PORT:-28084}"
LAB13_REMOTE_READY_SEC="${LAB13_REMOTE_READY_SEC:-180}"
LAB13_REQUIRE_STAND_HEALTH="${LAB13_REQUIRE_STAND_HEALTH:-1}"

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
  if [[ ! -f "${LAB13_TOPIC_ENV}" ]]; then
    echo "LAB13: нет файла ${LAB13_TOPIC_ENV} — добавьте registry-tags-lab13-topic.env (топик 2 партиции)." >&2
    exit 1
  fi
else
  require ssh
  LAB13_STAND_ACCESS="${LAB13_STAND_ACCESS:-auto}"
fi

if [[ -z "${DOCKER_SSH}" ]]; then
  LAB13_STAND_ACCESS="${LAB13_STAND_ACCESS:-direct}"
fi

mkdir -p "$OUT_DIR" "$LOG_DIR"

verify_remote_zil_dir() {
  [[ -z "${DOCKER_SSH}" ]] && return 0
  ssh -o BatchMode=yes -o ConnectTimeout=15 "$DOCKER_SSH" "test -d $(printf '%q' "$REMOTE_ZIL")" || {
    echo "LAB13: на ${DOCKER_SSH} нет каталога REMOTE_ZIL=${REMOTE_ZIL} (git clone или поправьте путь)." >&2
    exit 1
  }
}

verify_remote_zil_dir

echo ""
echo "═══════════════════════════════════════════════════════════════════"
if [[ "${LAB13_MIX_PANELS}" == "1" ]]; then
  echo "  LAB13 — режим: ГРАФИКИ LAB8 (12 прогонов k6, файлы *_mix*.json)"
else
  echo "  LAB13 — режим: ТЗ §0.8 (4 прогона k6)"
fi
echo "  Папка отчётов: ${OUT_DIR}"
echo "  Топик Kafka (прокси uvicorn должен совпадать): ${KAFKA_TOPIC:-hl07-lab13}"
if [[ -n "${DOCKER_SSH:-}" ]]; then
  echo "  Доступ к app/additional с этой ВМ: LAB13_STAND_ACCESS=${LAB13_STAND_ACCESS} (auto=tunnel при недоступном IP)"
fi
echo "═══════════════════════════════════════════════════════════════════"
echo ""

if [[ -n "${KAFKA_TOPIC:-}" ]]; then
  echo ">>> LAB13: ожидается прокси с KAFKA_TOPIC=${KAFKA_TOPIC} (в другом терминале: export и uvicorn)."
fi

compose() {
  if [[ -n "${DOCKER_SSH}" ]]; then
    local remote_cmd
    remote_cmd=$(printf '%q ' "$@")
    ssh "$DOCKER_SSH" \
      "export APP_CPUS=$(printf '%q' "${APP_CPUS:-}") ADDITIONAL_CPUS=$(printf '%q' "${ADDITIONAL_CPUS:-}") KAFKA_LISTENER_CONCURRENCY=$(printf '%q' "${KAFKA_LISTENER_CONCURRENCY:-}"); cd $(printf '%q' "$REMOTE_ZIL") && docker compose --env-file $(printf '%q' "$REMOTE_ENV_FILE") --env-file $(printf '%q' "$REMOTE_ENV_TOPIC_FILE") $remote_cmd"
  else
    docker compose --project-directory "$ZIL_ROOT" --env-file "$ENV_FILE" --env-file "${LAB13_TOPIC_ENV}" "$@"
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

wait_remote_stack_ready() {
  [[ -z "${DOCKER_SSH}" ]] && return 0
  local max="${LAB13_REMOTE_READY_SEC}"
  local i=0
  echo ">>> Ожидание HTTP 200 на ВМ ${DOCKER_SSH}:8083/stats и :8084/additional/stats (до ${max}s)..."
  while [[ "$i" -lt "$max" ]]; do
    local a d
    a="$(ssh -o BatchMode=yes -o ConnectTimeout=15 "$DOCKER_SSH" "curl -sS -o /dev/null -w '%{http_code}' --max-time 12 'http://127.0.0.1:8083/stats' 2>/dev/null || echo 000")"
    d="$(ssh -o BatchMode=yes -o ConnectTimeout=15 "$DOCKER_SSH" "curl -sS -o /dev/null -w '%{http_code}' --max-time 12 'http://127.0.0.1:8084/additional/stats' 2>/dev/null || echo 000")"
    if [[ "$a" == "200" && "$d" == "200" ]]; then
      echo ">>> удалённый стенд отвечает: app=${a} additional=${d}"
      return 0
    fi
    if [[ $((i % 15)) -eq 0 ]]; then
      echo "    ... ещё не готово: app=${a} additional=${d} (${i}s / ${max}s)"
    fi
    sleep 3
    i=$((i + 3))
  done
  echo "LAB13: за ${max}s на ${DOCKER_SSH} не получили 200 на app/additional." >&2
  echo "    REMOTE_ZIL=${REMOTE_ZIL}; смотрите логи:" >&2
  echo "    ssh ${DOCKER_SSH} 'cd $(printf '%q' "$REMOTE_ZIL") && docker compose --env-file ${REMOTE_ENV_FILE} --env-file ${REMOTE_ENV_TOPIC_FILE} logs app additional --tail 120'" >&2
  exit 1
}

start_stand_tunnel() {
  [[ "${LAB13_TUNNEL_STARTED}" == "1" ]] && return 0
  if command -v ss >/dev/null 2>&1; then
    if ss -tln 2>/dev/null | grep -qE ":${LAB13_TUNNEL_APP_PORT}\\s"; then
      echo "LAB13: порт ${LAB13_TUNNEL_APP_PORT} занят — закройте процесс или задайте LAB13_TUNNEL_APP_PORT." >&2
      exit 1
    fi
    if ss -tln 2>/dev/null | grep -qE ":${LAB13_TUNNEL_ADD_PORT}\\s"; then
      echo "LAB13: порт ${LAB13_TUNNEL_ADD_PORT} занят." >&2
      exit 1
    fi
  fi
  ssh -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o BatchMode=yes \
    -L "127.0.0.1:${LAB13_TUNNEL_APP_PORT}:127.0.0.1:8083" \
    -L "127.0.0.1:${LAB13_TUNNEL_ADD_PORT}:127.0.0.1:8084" \
    -N "$DOCKER_SSH" &
  LAB13_TUNNEL_PID=$!
  LAB13_TUNNEL_STARTED=1
  sleep 1
}

curl_stand_codes() {
  local app_code add_code
  app_code="$(curl -sS -o /dev/null -w "%{http_code}" --max-time 10 "${APP_CHECK_URL}" 2>/dev/null || echo 000)"
  add_code="$(curl -sS -o /dev/null -w "%{http_code}" --max-time 10 "${BASE_URL}/additional/stats" 2>/dev/null || echo 000)"
  echo "${app_code} ${add_code}"
}

ensure_k6_stand_reachable() {
  local mode="${LAB13_STAND_ACCESS}"

  if [[ "$mode" == "tunnel" ]]; then
    start_stand_tunnel
    export BASE_URL="http://127.0.0.1:${LAB13_TUNNEL_ADD_PORT}"
    export APP_CHECK_URL="http://127.0.0.1:${LAB13_TUNNEL_APP_PORT}/stats"
    local tc
    tc="$(curl_stand_codes)"
    if [[ "$tc" != "200 200" ]]; then
      echo "LAB13: туннель поднят, но localhost даёт «${tc}» (ожидалось 200 200)." >&2
      exit 1
    fi
    echo ">>> k6 → стенд только через туннель: BASE_URL=${BASE_URL}"
    return 0
  fi

  if [[ "$mode" == "direct" ]] || [[ -z "${DOCKER_SSH}" ]]; then
    local dc
    dc="$(curl_stand_codes)"
    if [[ "$dc" == "200 200" ]]; then
      echo ">>> k6 видит стенд напрямую (${APP_CHECK_URL})."
      return 0
    fi
    echo "LAB13: прямой доступ к стенду не работает (коды ${dc})." >&2
    echo "    Ожидали: APP_CHECK_URL=${APP_CHECK_URL} и ${BASE_URL}/additional/stats" >&2
    [[ "${LAB13_REQUIRE_STAND_HEALTH}" == "1" ]] && exit 1
    return 0
  fi

  # auto + DOCKER_SSH
  local dc
  dc="$(curl_stand_codes)"
  if [[ "$dc" == "200 200" ]]; then
    echo ">>> k6 видит стенд напрямую (LAB13_STAND_ACCESS=auto, IP из lab13-stand.env)."
    return 0
  fi

  echo ">>> Прямой доступ с ВМ k6 не работает (коды ${dc}); поднимаю SSH-туннель → :${LAB13_TUNNEL_APP_PORT} / :${LAB13_TUNNEL_ADD_PORT}"
  start_stand_tunnel
  export BASE_URL="http://127.0.0.1:${LAB13_TUNNEL_ADD_PORT}"
  export APP_CHECK_URL="http://127.0.0.1:${LAB13_TUNNEL_APP_PORT}/stats"
  dc="$(curl_stand_codes)"
  if [[ "$dc" != "200 200" ]]; then
    echo "LAB13: через туннель всё ещё не 200 200 (коды ${dc}). SSH или контейнеры на ${DOCKER_SSH}." >&2
    exit 1
  fi
  echo ">>> k6 → стенд через туннель: BASE_URL=${BASE_URL}"
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
  wait_remote_stack_ready
  ensure_k6_stand_reachable

  echo -n ">>> check app: "
  curl -sS -o /dev/null -w "%{http_code}\n" --max-time 12 "${APP_CHECK_URL}" || echo "000"
  echo -n ">>> check additional: "
  curl -sS -o /dev/null -w "%{http_code}\n" --max-time 12 "${BASE_URL}/additional/stats" || echo "000"
}

run_k6_mix_export_logs() {
  local cpu_tag="$1"
  local conc="$2"
  local mix_tag="$3"
  local stats_share="$4"
  local json_path="$OUT_DIR/summary_CPU${cpu_tag}_conc${conc}_mix${mix_tag}.json"
  local log_path="$LOG_DIR/run_CPU${cpu_tag}_conc${conc}_mix${mix_tag}_app_additional.log"

  check_proxy
  export STATS_SHARE="$stats_share"
  echo ">>> k6 STATS_SHARE=${stats_share} mix=${mix_tag} summary -> ${json_path##*/}"
  k6 run --summary-export "$json_path" "$SCRIPT_DIR/load-lab13-kafka-proxy.js"

  echo ">>> docker logs -> ${log_path##*/}"
  compose logs --no-color app additional >"$log_path" || true
}

run_k6_tz_export_logs() {
  local cpu_tag="$1"
  local conc="$2"
  local json_path="$OUT_DIR/summary_CPU${cpu_tag}_conc${conc}.json"
  local log_path="$LOG_DIR/run_CPU${cpu_tag}_conc${conc}_app_additional.log"

  check_proxy
  export STATS_SHARE=0
  echo ">>> k6 (ТЗ §0.8, STATS_SHARE=0) summary -> ${json_path##*/}"
  k6 run --summary-export "$json_path" "$SCRIPT_DIR/load-lab13-kafka-proxy.js"

  echo ">>> docker logs -> ${log_path##*/}"
  compose logs --no-color app additional >"$log_path" || true
}

# Порядок как LAB13_MANUAL §0.8: 0.5×conc1, 0.5×conc2, 1.0×conc1, 1.0×conc2.
if [[ "${LAB13_MIX_PANELS}" == "1" ]]; then
  echo ">>> LAB13_MIX_PANELS=1 — 12 прогонов k6 (mix05/50/95 на каждую ячейку CPU×conc)."
  for conc in 1 2; do
    for cpus_pair in "0.5:05" "1.0:10"; do
      cpus="${cpus_pair%%:*}"
      cpu_tag="${cpus_pair##*:}"
      set_cpu_conc_and_up "$cpus" "$conc"
      for mix_pair in "05:0.05" "50:0.5" "95:0.95"; do
        mix_tag="${mix_pair%%:*}"
        share="${mix_pair##*:}"
        run_k6_mix_export_logs "$cpu_tag" "$conc" "$mix_tag" "$share"
      done
    done
  done
else
  echo ">>> LAB13_MIX_PANELS=0 — 4 прогона k6 (минимум ТЗ §0.8)."
  for cpus_pair in "0.5:05" "1.0:10"; do
    cpus="${cpus_pair%%:*}"
    cpu_tag="${cpus_pair##*:}"
    for conc in 1 2; do
      set_cpu_conc_and_up "$cpus" "$conc"
      run_k6_tz_export_logs "$cpu_tag" "$conc"
    done
  done
fi

if [[ "$SKIP_PLOT" != 1 ]]; then
  echo ">>> plot_lab13_reports.py $OUT_DIR (LAB13_PANEL_CONC=${LAB13_PANEL_CONC})"
  if command -v python3 >/dev/null 2>&1; then
    LAB13_PANEL_CONC="$LAB13_PANEL_CONC" python3 "$SCRIPT_DIR/plot_lab13_reports.py" "$OUT_DIR" || {
      echo "Предупреждение: графики LAB13 не построены (matplotlib?). JSON в $OUT_DIR" >&2
    }
  else
    echo "python3 не найден — графики пропущены." >&2
  fi
else
  echo ">>> SKIP_PLOT=1"
fi

echo "Готово. JSON: $OUT_DIR ; логи compose: $LOG_DIR"
