#!/usr/bin/env bash
set -euo pipefail

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
