#!/usr/bin/env bash
set -euo pipefail
BASE_URL="${1:-http://localhost:8080}"
status="$(curl --silent --show-error --output /tmp/taskflow-health.json --write-out '%{http_code}' "${BASE_URL}/health")"
if [[ "$status" != "200" ]]; then
  echo "Health check failed: HTTP ${status}"
  cat /tmp/taskflow-health.json || true
  exit 1
fi
cat /tmp/taskflow-health.json
echo
echo "TaskFlow health check passed."
