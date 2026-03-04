#!/usr/bin/env bash
set -euo pipefail

TON_CONTAINER="${TON_CONTAINER:-ton}"
CONFIG_DEST="/shared-config/local.config.json"
MAX_RETRIES=60

echo "[ton-http-api-config] Waiting for TON container '${TON_CONTAINER}' to start..."

for i in $(seq 1 30); do
  if docker ps --format '{{.Names}}' | grep -q "^${TON_CONTAINER}$"; then
    echo "[ton-http-api-config] TON container is running"
    break
  fi
  echo "[ton-http-api-config] Waiting for TON container... (${i}/30)"
  sleep 10
done

if ! docker ps --format '{{.Names}}' | grep -q "^${TON_CONTAINER}$"; then
  echo "[ton-http-api-config] ERROR: TON container '${TON_CONTAINER}' is not running"
  exit 1
fi

echo "[ton-http-api-config] Waiting for liteserver config to be generated..."

for i in $(seq 1 ${MAX_RETRIES}); do
  if docker exec "${TON_CONTAINER}" test -f /usr/bin/ton/local.config.json 2>/dev/null; then
    echo "[ton-http-api-config] Config found, extracting..."

    docker cp "${TON_CONTAINER}:/usr/bin/ton/local.config.json" "${CONFIG_DEST}"
    chmod 644 "${CONFIG_DEST}"

    echo "[ton-http-api-config] Config exported successfully to ${CONFIG_DEST}"
    echo "[ton-http-api-config] Liteserver configuration:"
    cat "${CONFIG_DEST}"
    exit 0
  fi

  echo "[ton-http-api-config] Waiting for config to be generated... (${i}/${MAX_RETRIES})"
  sleep 10
done

echo "[ton-http-api-config] ERROR: Timeout waiting for liteserver config"
echo "[ton-http-api-config] The config file was not found at /usr/bin/ton/local.config.json"
echo "[ton-http-api-config] You can manually generate it by running:"
echo "[ton-http-api-config]   docker exec ${TON_CONTAINER} bash -c 'mytonctrl' then run 'installer clcf'"
exit 1
