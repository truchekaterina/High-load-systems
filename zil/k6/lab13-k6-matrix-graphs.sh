#!/usr/bin/env bash
# LAB13: матрица + **12 прогонов k6** (смеси POST/GET как LAB8) → PNG lab13_latency_vs_cpu*.png
#
# То же, что ./lab13-k6-matrix.sh, но для отчётных графиков. Нужен запущенный прокси и lab13-stand.env.
#
set -euo pipefail
export LAB13_MATRIX_UI=graphs
export LAB13_USE_STAND_ENV=1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run-lab13-kafka-proxy-matrix.sh" "$@"
