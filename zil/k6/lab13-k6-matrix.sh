#!/usr/bin/env bash
# LAB13: автоматизация матрицы (§0.8: по умолчанию **4** прогона k6).
# Доп. смеси POST/GET для графиков LAB8-стиля: **LAB13_MIX_PANELS=1 ./lab13-k6-matrix.sh**
#
# Подготовка:
#   cp lab13-stand.env.example lab13-stand.env
#   # отредактировать HL07_SSH, REMOTE_ZIL, BASE_URL, APP_CHECK_URL
#   # в другом терминале: uvicorn в lab13-kafka-proxy
#   ./lab13-k6-matrix.sh
#
set -euo pipefail
export LAB13_USE_STAND_ENV=1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run-lab13-kafka-proxy-matrix.sh" "$@"
