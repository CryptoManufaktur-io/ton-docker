#!/usr/bin/env bash
set -euo pipefail

TON_CONTAINER="${TON_CONTAINER:-ton}"
CHECK_INTERVAL=60
MAX_WAIT=86400

echo "[ton-http-api] Waiting for TON node to complete initial sync before starting API..."
echo "[ton-http-api] This may take several hours if syncing from scratch."
echo "[ton-http-api] You can monitor sync progress with: ./ethd check-sync"

check_sync() {
  SYNC_OUTPUT=$(/scripts/check-sync.sh 2>&1)
  SYNC_EXIT_CODE=$?

  # exit code 0 = synced, 1 = syncing, 2 = error
  if [ $SYNC_EXIT_CODE -eq 0 ]; then
    return 0
  else
    return 1
  fi
}

# wait for sync
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
  if check_sync; then
    echo "[ton-http-api] TON node is synced! Starting ton-http-api..."
    break
  fi

  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${TON_CONTAINER}$"; then
    SYNC_STATUS=$(/scripts/check-sync.sh 2>&1 || echo "Checking sync status...")
    echo "[ton-http-api] ${SYNC_STATUS} (${ELAPSED}s elapsed)"
  else
    echo "[ton-http-api] Waiting for TON container to be ready..."
  fi

  sleep $CHECK_INTERVAL
  ELAPSED=$((ELAPSED + CHECK_INTERVAL))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
  echo "[ton-http-api] WARNING: Max wait time reached. Starting anyway..."
  echo "[ton-http-api] API may experience errors until sync completes."
fi

# start the actual ton-http-api server
echo "[ton-http-api] Starting gunicorn server..."
# shellcheck disable=SC2086  
exec gunicorn -k uvicorn.workers.UvicornWorker \
  -w "${TON_API_WEBSERVERS_WORKERS:-1}" \
  --bind 0.0.0.0:8081 \
  ${TON_API_GUNICORN_FLAGS} \
  pyTON.main:app
