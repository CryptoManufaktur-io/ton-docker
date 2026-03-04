#!/usr/bin/env bash
set -euo pipefail

# exit codes: 0=synced, 1=syncing, 2=error

if ! docker ps --format '{{.Names}}' | grep -q '^ton$'; then
  echo "ERROR: ton container is not running"
  exit 2
fi

STATUS_OUTPUT=$(docker exec ton bash -c "mytonctrl status 2>/dev/null" || echo "ERROR")

if [[ "${STATUS_OUTPUT}" == "ERROR" ]]; then
  echo "ERROR: Could not get status from mytonctrl"
  exit 2
fi

if echo "${STATUS_OUTPUT}" | grep -qi "out of sync"; then
  BLOCKS_BEHIND=$(echo "${STATUS_OUTPUT}" | grep -oE '[0-9]+ blocks' | head -1 | grep -oE '[0-9]+' || echo "unknown")
  echo "Syncing: ${BLOCKS_BEHIND} blocks behind"
  exit 1
fi

if echo "${STATUS_OUTPUT}" | grep -qi "synchronization complete\|in sync"; then
  echo "Synced"
  exit 0
fi

if echo "${STATUS_OUTPUT}" | grep -q "Local validator status"; then
  echo "Synced (validator active)"
  exit 0
fi

echo "Status output:"
echo "${STATUS_OUTPUT}"
echo ""
echo "Unable to determine sync status definitively. Check logs with: ./ethd logs -f ton"
exit 1
