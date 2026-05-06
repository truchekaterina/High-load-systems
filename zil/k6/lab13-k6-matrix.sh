#!/usr/bin/env bash
# LAB13: матрица по ТЗ §0.8 — **4 прогона k6** (без смесей *_mix*).
#
# Для графиков LAB8-стиля запускайте рядом: ./lab13-k6-matrix-graphs.sh
#
# Нужны: lab13-stand.env (из примера), отдельный терминал с uvicorn в lab13-kafka-proxy.
#
set -euo pipefail
export LAB13_MATRIX_UI=tz
export LAB13_USE_STAND_ENV=1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run-lab13-kafka-proxy-matrix.sh" "$@"
