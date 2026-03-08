#!/usr/bin/env bash
set -euo pipefail

DOCKER_SERVICE="${DOCKER_SERVICE:-ton}"
TON_CONTAINER="${TON_CONTAINER:-}"
CHECK_INTERVAL=60
MAX_WAIT=86400

resolve_ton_container() {
  if [[ -n "$TON_CONTAINER" ]]; then
    return 0
  fi

  TON_CONTAINER="$(docker ps --filter "label=com.docker.compose.service=${DOCKER_SERVICE}" --format '{{.Names}}' | head -1)"

  if [[ -z "$TON_CONTAINER" ]]; then
    if docker compose version >/dev/null 2>&1; then
      local container_id
      container_id="$(docker compose ps -q "$DOCKER_SERVICE" 2>/dev/null | head -n 1)"
      if [[ -n "$container_id" ]]; then
        TON_CONTAINER="$(docker inspect --format '{{.Name}}' "$container_id" 2>/dev/null | sed 's/^\///')"
      fi
    fi
  fi
}

echo "[ton-http-api] Waiting for TON node to complete initial sync before starting API..."
echo "[ton-http-api] This may take several hours if syncing from scratch."
echo "[ton-http-api] You can monitor sync progress with: ./ethd check-sync"

check_sync() {
  /scripts/check-sync.sh >/dev/null 2>&1
  # exit code 0 = synced, 1 = syncing, 2 = error
  return $?
}

# wait for sync
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
  resolve_ton_container

  if [[ -n "$TON_CONTAINER" ]] && check_sync; then
    echo "[ton-http-api] TON node is synced! Starting ton-http-api..."
    break
  fi

  if [[ -n "$TON_CONTAINER" ]]; then
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

echo "[ton-http-api] Starting gunicorn server..."
# shellcheck disable=SC2086
exec gunicorn -k uvicorn.workers.UvicornWorker \
  -w "${TON_API_WEBSERVERS_WORKERS:-1}" \
  --bind 0.0.0.0:8081 \
  ${TON_API_GUNICORN_FLAGS} \
  pyTON.main:app
