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

echo "[ton-http-api-config] Waiting for TON services to be ready..."

# Wait for validator and mytoncore services to start (2-3 minutes)
for i in $(seq 1 20); do
  if docker exec "${TON_CONTAINER}" systemctl is-active validator >/dev/null 2>&1 && \
     docker exec "${TON_CONTAINER}" systemctl is-active mytoncore >/dev/null 2>&1; then
    echo "[ton-http-api-config] TON services are running"
    break
  fi
  echo "[ton-http-api-config] Waiting for services... (${i}/20)"
  sleep 10
done

# Check if config already exists
if docker exec "${TON_CONTAINER}" test -f /usr/bin/ton/local.config.json 2>/dev/null; then
  echo "[ton-http-api-config] Config already exists, extracting..."
else
  echo "[ton-http-api-config] Generating liteserver config..."
  # Generate the config - this works even while node is still syncing
  if docker exec "${TON_CONTAINER}" bash -c "echo 'installer clcf' | mytonctrl" 2>&1 | tee /tmp/clcf.log | grep -i "created"; then
    echo "[ton-http-api-config] Config generated successfully"
  else
    echo "[ton-http-api-config] Config generation output:"
    cat /tmp/clcf.log || true
  fi
  sleep 5  # Give it a moment to write the file
fi

# Verify and extract config
echo "[ton-http-api-config] Extracting config file..."
if docker exec "${TON_CONTAINER}" test -f /usr/bin/ton/local.config.json 2>/dev/null; then
  # Verify it's valid JSON
  if docker exec "${TON_CONTAINER}" cat /usr/bin/ton/local.config.json | grep -q "liteservers"; then
    docker cp "${TON_CONTAINER}:/usr/bin/ton/local.config.json" "${CONFIG_DEST}"
    chmod 644 "${CONFIG_DEST}"

    echo "[ton-http-api-config] Config exported successfully to ${CONFIG_DEST}"
    echo "[ton-http-api-config] Liteserver configuration:"
    cat "${CONFIG_DEST}"
    exit 0
  else
    echo "[ton-http-api-config] ERROR: Config file exists but is not valid JSON"
    exit 1
  fi
else
  echo "[ton-http-api-config] ERROR: Config file not found after generation attempt"
  echo "[ton-http-api-config] Check TON container logs: docker logs ${TON_CONTAINER}"
  exit 1
fi
