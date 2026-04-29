#!/usr/bin/env bash
# LAB7: k6 «сервер → сервер» при лимите CPU контейнера приложения 2.0 (файлы s2s_cpu20_*).
#
# 1) На ВМ приложения (ssh -p 2307 hl@hlssh.zil.digital):
#      export APP_CPUS=2.0
#      cd ~/work/Labs_hls/zil   # свой путь к репозиторию
#      git checkout lab7 && git pull
#      docker compose pull app && docker compose up -d --force-recreate app
#    Подожди 1–2 мин после старта.
#
# 2) Узнай внутренний IP ВМ приложения (на той же ВМ): ip -4 -br a | grep UP
#    Обычно сеть 10.60.3.0/24 — этот адрес укажешь ниже (k6 ходит на :8083).
#
# 3) На ВМ k6 (ssh -p 2311 hl@hlssh.zil.digital), установи k6 при необходимости,
#    склонируй репозиторий или скопируй каталог zil/k6, затем:
#      chmod +x run-lab7-s2s-2cpu.sh
#      ./run-lab7-s2s-2cpu.sh 10.60.3.XX
#
# Опционально: TARGET_VUS=20 DURATION=3m OUT_DIR=reports-lab6-s2s
#
# Построение lab6_latency_vs_cpu.png требует JSON для всех CPU (05,10,15,20) и всех смесей.
# Для только точки 2.0: либо оставь остальные cpu* из прошлых прогонов LAB6, либо прогони весь ряд.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_HOST="${1:-${APP_HOST:-}}"
if [[ -z "$APP_HOST" ]]; then
  echo "Usage: $0 <app-vm-internal-ip>"
  echo "Example: $0 10.60.3.12"
  exit 1
fi

export BASE_URL="http://${APP_HOST}:8083"
OUT_DIR="${OUT_DIR:-reports-lab6-s2s}"
mkdir -p "$OUT_DIR"
TARGET_VUS="${TARGET_VUS:-20}"
DURATION="${DURATION:-3m}"

run_one() {
  local share=$1
  local mixtag=$2
  local out="${OUT_DIR}/s2s_cpu20_mix${mixtag}.json"
  echo ">>> BASE_URL=$BASE_URL POST_SHARE=$share -> $out"
  LAB6_CONST=1 TARGET_VUS="$TARGET_VUS" POST_SHARE="$share" DURATION="$DURATION" \
    k6 run --summary-export="$out" load.js
}

run_one 0.05 05
run_one 0.5 50
run_one 0.95 95

echo "Готово: $OUT_DIR/s2s_cpu20_mix05.json, ...mix50.json, ...mix95.json"
