#!/usr/bin/env bash
set -euo pipefail

echo "Initial sleeping"
sleep 120

# Check if the config file has been exported
until [[ -f "${TON_API_TONLIB_LITESERVER_CONFIG}" ]] && python3 -c "import json, sys; json.load(open(sys.argv[1]))" "${TON_API_TONLIB_LITESERVER_CONFIG}" 2>/dev/null; do
  echo "[ton-http-api] Waiting for ${TON_API_TONLIB_LITESERVER_CONFIG} to exist and be valid JSON..."
  sleep 60
done
# Check if the config file has been exported

echo "[ton-http-api] Starting TON HTTP API..."
echo "[ton-http-api] Configuration provided by ton-http-api-config service (via shared volume)"
echo "[ton-http-api] Monitor node sync status on host with: ./ethd check-sync"
echo "[ton-http-api] API healthcheck will show ready once node is synced and responding"

echo "[ton-http-api] Starting gunicorn server..."
# shellcheck disable=SC2086
exec gunicorn -k uvicorn.workers.UvicornWorker \
  -w "${TON_API_WEBSERVERS_WORKERS:-1}" \
  --bind 0.0.0.0:8081 \
  ${TON_API_GUNICORN_FLAGS} \
  pyTON.main:app
