#!/usr/bin/env bash
set -euo pipefail

TON_CONTAINER="${TON_CONTAINER:-ton}"
CHECK_INTERVAL=60
MAX_WAIT=86400

echo "[ton-http-api] Waiting for TON node to complete initial sync before starting API..."
echo "[ton-http-api] This may take several hours if syncing from scratch."
echo "[ton-http-api] You can monitor sync progress with: ./ethd check-sync"

check_sync() {
  if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${TON_CONTAINER}$"; then
    return 1
  fi

  STATUS_OUTPUT=$(docker exec "${TON_CONTAINER}" bash -c "echo 'status' | /usr/bin/mytonctrl 2>/dev/null" || echo "ERROR")

  if [[ "${STATUS_OUTPUT}" == "ERROR" ]]; then
    return 1
  fi

  # check if synced
  if echo "${STATUS_OUTPUT}" | grep -qi "synchronization complete\|in sync"; then
    return 0
  fi

  # check if validator is active (also means synced)
  if echo "${STATUS_OUTPUT}" | grep -q "Local validator status"; then
    return 0
  fi

  # check if "out of sync" shows 0-2 blocks/seconds (essentially synced)
  if echo "${STATUS_OUTPUT}" | grep -q "Masterchain out of sync"; then
    OUT_OF_SYNC=$(echo "${STATUS_OUTPUT}" | grep "Masterchain out of sync" | grep -oE '[0-9]+' | head -1)
    if [ -n "${OUT_OF_SYNC}" ] && [ "${OUT_OF_SYNC}" -le 2 ]; then
      return 0
    fi
  fi

  return 1
}

# wait for sync
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
  if check_sync; then
    echo "[ton-http-api] TON node is synced! Starting ton-http-api..."
    break
  fi

  # get sync status for logging
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${TON_CONTAINER}$"; then
    STATUS_OUTPUT=$(docker exec "${TON_CONTAINER}" bash -c "echo 'status' | /usr/bin/mytonctrl 2>/dev/null" || echo "")

    if echo "${STATUS_OUTPUT}" | grep -qi "out of sync"; then
      BLOCKS_BEHIND=$(echo "${STATUS_OUTPUT}" | grep -oE '[0-9]+ blocks' | head -1 | grep -oE '[0-9]+' || echo "unknown")
      echo "[ton-http-api] Still syncing: ${BLOCKS_BEHIND} blocks behind..."
    elif echo "${STATUS_OUTPUT}" | grep -qi "Initial Node sync is not completed"; then
      echo "[ton-http-api] Initial sync in progress..."
    else
      echo "[ton-http-api] Waiting for sync... (${ELAPSED}s elapsed)"
    fi
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
exec gunicorn -k uvicorn.workers.UvicornWorker \
  -w "${TON_API_WEBSERVERS_WORKERS:-1}" \
  --bind 0.0.0.0:8081 \
  ${TON_API_GUNICORN_FLAGS} \
  pyTON.main:app
