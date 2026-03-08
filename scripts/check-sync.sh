#!/usr/bin/env bash
set -euo pipefail

DOCKER_SERVICE="${DOCKER_SERVICE:-ton}"
CONTAINER="${CONTAINER:-}"

if [[ -z "$CONTAINER" ]]; then
  if docker compose version >/dev/null 2>&1; then
    CONTAINER="$(docker compose ps -q "$DOCKER_SERVICE" 2>/dev/null | head -n 1)"
    if [[ -n "$CONTAINER" ]]; then
      CONTAINER="$(docker inspect --format '{{.Name}}' "$CONTAINER" 2>/dev/null | sed 's/^\///')"
    fi
  fi

  if [[ -z "$CONTAINER" ]]; then
    CONTAINER="$(docker ps --filter "label=com.docker.compose.service=${DOCKER_SERVICE}" --format '{{.Names}}' | head -1)"
  fi
fi

if [[ -z "$CONTAINER" ]]; then
  echo "ERROR: ${DOCKER_SERVICE} service container is not running"
  exit 2
fi

STATUS_OUTPUT=$(docker exec "$CONTAINER" bash -c "echo 'status' | /usr/bin/mytonctrl 2>/dev/null" || echo "ERROR")

if [[ "${STATUS_OUTPUT}" == "ERROR" ]]; then
  echo "ERROR: Could not get status from mytonctrl"
  exit 2
fi

if echo "${STATUS_OUTPUT}" | grep -qi "synchronization complete\|in sync"; then
  echo "Synced"
  exit 0
fi

# check local validator status
if echo "${STATUS_OUTPUT}" | grep -q "Local validator status"; then
  if echo "${STATUS_OUTPUT}" | grep -q "Local validator initial sync status"; then
    SECONDS_BEHIND=$(echo "${STATUS_OUTPUT}" | grep "Local validator initial sync status" | grep -oE '[0-9]+ s ago' | tail -1 | grep -oE '[0-9]+')
    if [ -n "${SECONDS_BEHIND}" ]; then
      if [ "${SECONDS_BEHIND}" -le 60 ]; then
        echo "Synced (${SECONDS_BEHIND}s behind)"
        exit 0
      else
        DAYS_BEHIND=$((SECONDS_BEHIND / 86400))
        HOURS_BEHIND=$(((SECONDS_BEHIND % 86400) / 3600))
        MINUTES_BEHIND=$(((SECONDS_BEHIND % 3600) / 60))
        echo "Syncing: ${SECONDS_BEHIND}s (${DAYS_BEHIND}d ${HOURS_BEHIND}h ${MINUTES_BEHIND}m) behind"
        exit 1
      fi
    fi
  fi

  # check masterchain out of sync value
  if echo "${STATUS_OUTPUT}" | grep -q "Masterchain out of sync"; then
    OUT_OF_SYNC=$(echo "${STATUS_OUTPUT}" | grep "Masterchain out of sync" | grep -oE '[0-9]+' | head -1)
    if [ -n "${OUT_OF_SYNC}" ] && [ "${OUT_OF_SYNC}" -le 60 ]; then
      echo "Synced (${OUT_OF_SYNC}s out of sync on masterchain)"
      exit 0
    else
      echo "Syncing: ${OUT_OF_SYNC}s out of sync on masterchain"
      exit 1
    fi
  fi

  # check shardchain out of sync value
  if echo "${STATUS_OUTPUT}" | grep -q "Shardchain out of sync"; then
    SHARD_BLOCKS=$(echo "${STATUS_OUTPUT}" | grep "Shardchain out of sync" | grep -oE '[0-9]+' | head -1)
    if [ -n "${SHARD_BLOCKS}" ] && [ "${SHARD_BLOCKS}" -le 10 ]; then
      echo "Synced (${SHARD_BLOCKS} blocks out of sync on shardchain)"
      exit 0
    else
      echo "Syncing: ${SHARD_BLOCKS} blocks out of sync on shardchain"
      exit 1
    fi
  fi
  echo "Synced"
  exit 0
fi

# generic sync check
if echo "${STATUS_OUTPUT}" | grep -qi "out of sync"; then
  BLOCKS_BEHIND=$(echo "${STATUS_OUTPUT}" | grep -oE '[0-9]+ blocks' | head -1 | grep -oE '[0-9]+' || echo "unknown")
  if [ "${BLOCKS_BEHIND}" = "0" ]; then
    echo "Synced (0 blocks behind)"
    exit 0
  fi
  echo "Syncing: ${BLOCKS_BEHIND} blocks behind"
  exit 1
fi

echo "Status output:"
echo "${STATUS_OUTPUT}"
echo ""
echo "Unable to determine sync status definitively. Check logs with: ./ethd logs -f ton"
exit 1
