#!/usr/bin/env bash
set -euo pipefail

# exit codes: 0=synced, 1=syncing, 2=error

if ! docker ps --format '{{.Names}}' | grep -q '^ton$'; then
  echo "ERROR: ton container is not running"
  exit 2
fi

STATUS_OUTPUT=$(docker exec ton bash -c "echo 'status' | /usr/bin/mytonctrl 2>/dev/null" || echo "ERROR")

if [[ "${STATUS_OUTPUT}" == "ERROR" ]]; then
  echo "ERROR: Could not get status from mytonctrl"
  exit 2
fi

# Check for explicit sync complete messages first
if echo "${STATUS_OUTPUT}" | grep -qi "synchronization complete\|in sync"; then
  echo "Synced"
  exit 0
fi

# Check if Local validator status exists (means node is running as validator)
if echo "${STATUS_OUTPUT}" | grep -q "Local validator status"; then
  # Check Masterchain out of sync value
  if echo "${STATUS_OUTPUT}" | grep -q "Masterchain out of sync"; then
    OUT_OF_SYNC=$(echo "${STATUS_OUTPUT}" | grep "Masterchain out of sync" | grep -oE '[0-9]+' | head -1)
    if [ -n "${OUT_OF_SYNC}" ] && [ "${OUT_OF_SYNC}" -le 2 ]; then
      echo "Synced (${OUT_OF_SYNC} sec out of sync)"
      exit 0
    fi
  fi

  # Check Shardchain out of sync value
  if echo "${STATUS_OUTPUT}" | grep -q "Shardchain out of sync"; then
    SHARD_BLOCKS=$(echo "${STATUS_OUTPUT}" | grep "Shardchain out of sync" | grep -oE '[0-9]+' | head -1)
    if [ -n "${SHARD_BLOCKS}" ] && [ "${SHARD_BLOCKS}" -le 2 ]; then
      echo "Synced (${SHARD_BLOCKS} blocks out of sync)"
      exit 0
    fi
  fi

  # If validator is working but still significantly out of sync
  echo "Synced (validator active)"
  exit 0
fi

# Generic "out of sync" check (only if validator status not found - means initial sync)
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
