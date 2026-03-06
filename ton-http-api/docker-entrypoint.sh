#!/usr/bin/env bash
set -euo pipefail

TON_CONTAINER="${TON_CONTAINER:-ton}"
CONFIG_DEST="/shared-config/local.config.json"

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

# wait for validator and mytoncore services to start
for i in $(seq 1 20); do
  if docker exec "${TON_CONTAINER}" systemctl is-active validator >/dev/null 2>&1 && \
     docker exec "${TON_CONTAINER}" systemctl is-active mytoncore >/dev/null 2>&1; then
    echo "[ton-http-api-config] TON services are running"
    break
  fi
  echo "[ton-http-api-config] Waiting for services... (${i}/20)"
  sleep 10
done

# wait for mytonctrl to be initialized and usable
echo "[ton-http-api-config] Waiting for mytonctrl to be ready..."
for i in $(seq 1 30); do
  if docker exec "${TON_CONTAINER}" bash -c "echo 'exit' | timeout 10 /usr/bin/mytonctrl" >/dev/null 2>&1; then
    echo "[ton-http-api-config] mytonctrl is ready"
    break
  fi
  echo "[ton-http-api-config] Waiting for mytonctrl initialization... (${i}/30)"
  sleep 10
done

# check if config already exists
if docker exec "${TON_CONTAINER}" test -f /usr/bin/ton/local.config.json 2>/dev/null; then
  echo "[ton-http-api-config] Config already exists, extracting..."
else
  echo "[ton-http-api-config] Generating liteserver config..."
  if docker exec "${TON_CONTAINER}" bash -c "echo 'installer clcf' | /usr/bin/mytonctrl" 2>&1 | tee /tmp/clcf.log | grep -i "created"; then
    echo "[ton-http-api-config] Config generated successfully"
  else
    echo "[ton-http-api-config] Config generation output:"
    cat /tmp/clcf.log || true
  fi
  sleep 5
fi

# verify and extract config
echo "[ton-http-api-config] Extracting config file..."
if docker exec "${TON_CONTAINER}" test -f /usr/bin/ton/local.config.json 2>/dev/null; then
  if docker exec "${TON_CONTAINER}" cat /usr/bin/ton/local.config.json | grep -q "liteservers"; then
    docker cp "${TON_CONTAINER}:/usr/bin/ton/local.config.json" "${CONFIG_DEST}"

    # get the TON container's internal IP address
    TON_INTERNAL_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${TON_CONTAINER}")
    echo "[ton-http-api-config] TON container internal IP: ${TON_INTERNAL_IP}"

    # replace the public IP with internal IP in the config
    # IP is stored as a signed 32-bit integer, we need to replace it
    python3 << EOF
import json
import socket
import struct

# Read the config
with open("${CONFIG_DEST}", 'r') as f:
    config = json.load(f)

# Convert internal IP to signed 32-bit integer format
ip_addr = "${TON_INTERNAL_IP}"
ip_int = struct.unpack('!i', socket.inet_aton(ip_addr))[0]

# Update the liteserver IP
config['liteservers'][0]['ip'] = ip_int

# Write back
with open("${CONFIG_DEST}", 'w') as f:
    json.dump(config, f, indent=2)

print(f"Updated liteserver IP to {ip_addr} ({ip_int})")
EOF

    chmod 644 "${CONFIG_DEST}"
    echo "[ton-http-api-config] Config exported successfully"
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
