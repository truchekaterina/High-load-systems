#!/usr/bin/env bash
# ВМ k6 SSH -p 2311. Перед запуском задайте IP ВМ приложения (2307) или DNS в сети курса.
# Пример:
#   export APP_VM_APP_IP_OR_HOST="10.60.3.xx"
#   ./vm2311-run-lab8-example.sh

set -euo pipefail

if [[ -z "${APP_VM_APP_IP_OR_HOST:-}" ]]; then
  echo "Установите APP_VM_APP_IP_OR_HOST до вызова (IP/DNS узла где слушает порт Additional 8084)."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

export BASE_URL="${BASE_URL:-http://${APP_VM_APP_IP_OR_HOST}:8084}"
echo "BASE_URL=${BASE_URL}"
k6 run load-lab8-s2s.js
