#!/usr/bin/env bash
# LAB4: серия прогонов k6 (10→160 VU по умолчанию), экспорт JSON в reports/, опционально график.
# Используется rental-mixed.js (ramping-vus + TARGET_VUS + POST_SHARE), как в референсе с кино-API.
#
# Переменные:
#   NO_CLEAN=1     — не удалять старые отчёты перед стартом
#   NO_PLOT=1      — не ставить matplotlib и не строить график
#   USE_DOCKER_K6=1 — k6 через grafana/k6
#   BASE_URL       — хост API (по умолчанию http://localhost:8083)
#   POST_SHARE     — доля VU на POST (по умолчанию 0.5)
#   VUS_LIST       — пробел-разделённый список точек (по умолчанию "10 20 40 80 160")

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORTS="${SCRIPT_DIR}/reports"
mkdir -p "${REPORTS}"

export BASE_URL="${BASE_URL:-http://localhost:8083}"
export POST_SHARE="${POST_SHARE:-0.5}"

clean_reports() {
  if [[ "${NO_CLEAN:-0}" == "1" ]]; then
    echo "NO_CLEAN=1 — старые отчёты не удаляю."
    return 0
  fi
  echo "Очистка ${REPORTS} (summary-vus-*.json, avg_vs_vus.png)..."
  rm -f "${REPORTS}"/summary-vus-*.json "${REPORTS}"/avg_vs_vus.png 2>/dev/null || true
}

run_k6_native() {
  local v="$1"
  echo "=== TARGET_VUS=${v} (native k6) ==="
  TARGET_VUS="${v}" k6 run \
    --summary-export "${REPORTS}/summary-vus-${v}.json" \
    "${SCRIPT_DIR}/rental-mixed.js"
}

run_k6_docker() {
  local v="$1"
  echo "=== TARGET_VUS=${v} (Docker grafana/k6) ==="
  local extra=()
  if [[ "$(uname -s)" == "Linux" ]]; then
    extra+=(--add-host=host.docker.internal:host-gateway)
  fi
  docker run --rm "${extra[@]}" \
    -e BASE_URL="${BASE_URL}" \
    -e POST_SHARE="${POST_SHARE}" \
    -e TARGET_VUS="${v}" \
    -v "${SCRIPT_DIR}:/scripts" \
    grafana/k6 run \
    --summary-export "/scripts/reports/summary-vus-${v}.json" \
    "/scripts/rental-mixed.js"
}

ensure_matplotlib_and_plot() {
  if [[ "${NO_PLOT:-0}" == "1" ]]; then
    echo "NO_PLOT=1 — график не строю."
    echo "JSON: ${REPORTS}/summary-vus-*.json"
    return 0
  fi
  if ! python3 -c "import matplotlib" 2>/dev/null; then
    echo "matplotlib не найден — устанавливаю: python3 -m pip install --user \"matplotlib>=3.7\""
    python3 -m pip install --user "matplotlib>=3.7"
  fi
  python3 "${SCRIPT_DIR}/plot_avg_vs_vus.py" "${REPORTS}"
}

clean_reports

# Точки по умолчанию как у коллеги; можно переопределить: VUS_LIST="5 10 20" ./run-sweep.sh
if [[ -n "${VUS_LIST:-}" ]]; then
  read -r -a VUS_ARRAY <<< "${VUS_LIST}"
else
  VUS_ARRAY=(10 20 40 80 160)
fi

if [[ "${USE_DOCKER_K6:-0}" == "1" ]]; then
  for v in "${VUS_ARRAY[@]}"; do
    run_k6_docker "${v}"
  done
elif command -v k6 &>/dev/null; then
  for v in "${VUS_ARRAY[@]}"; do
    run_k6_native "${v}"
  done
else
  echo "k6 не найден в PATH. Варианты:"
  echo "  1) Установить: https://k6.io/docs/get-started/installation/"
  echo "  2) Запустить с Docker: USE_DOCKER_K6=1 ./run-sweep.sh"
  echo "     (на Linux для API на хосте: BASE_URL=http://host.docker.internal:8083)"
  exit 1
fi

echo "Готово. JSON: ${REPORTS}/summary-vus-*.json"
ensure_matplotlib_and_plot
