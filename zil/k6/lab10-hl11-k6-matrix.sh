#!/usr/bin/env bash
# LAB10: ВМ с k6 (hl11). Полная матрица CPU × смеси — docker по SSH на hl07, k6 локально.
# Один раз при необходимости отредактируйте lab10-stand.env (файл в репозитории), затем:
#   ./lab10-hl11-k6-matrix.sh
#
# Нужны: k6, ssh на HL07, python3+matplotlib для графиков (или SKIP_PLOT=1).
#
set -euo pipefail
export LAB10_USE_STAND_ENV=1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run-lab10-full-matrix.sh" "$@"
