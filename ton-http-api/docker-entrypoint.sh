#!/usr/bin/env bash
set -euo pipefail

SOURCE_CONFIG="/ton-source-config/local.config.json"
CONFIG_DEST="/shared-config/local.config.json"
MAX_WAIT=3600  # 1 hour - safe timeout for config generation
CHECK_INTERVAL=10

echo "[ton-http-api-config] Waiting for TON config to be exported..."

ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
  if [[ -f "${SOURCE_CONFIG}" ]]; then
    if jq empty "${SOURCE_CONFIG}" 2>/dev/null; then
      echo "[ton-http-api-config] Config file found and validated"
      cp "${SOURCE_CONFIG}" "${CONFIG_DEST}"

      TON_SERVICE_NAME="ton"
      TON_INTERNAL_IP=$(getent hosts ${TON_SERVICE_NAME} | awk '{ print $1 }' | head -1)

      if [[ -z "${TON_INTERNAL_IP}" ]]; then
        echo "[ton-http-api-config] WARNING: Could not resolve ton service IP, using service name"
        TON_INTERNAL_IP="${TON_SERVICE_NAME}"
      else
        echo "[ton-http-api-config] TON service IP: ${TON_INTERNAL_IP}"
      fi

      # Replace the public IP with internal IP in the config
      # IP is stored as a signed 32-bit integer
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
      echo "[ton-http-api-config] Config processed successfully"
      echo "[ton-http-api-config] Liteserver configuration:"
      cat "${CONFIG_DEST}"
      exit 0
    else
      echo "[ton-http-api-config] Config file found but invalid JSON, waiting..."
    fi
  fi

  sleep $CHECK_INTERVAL
  ELAPSED=$((ELAPSED + CHECK_INTERVAL))

  if [ $((ELAPSED % 60)) -eq 0 ]; then
    echo "[ton-http-api-config] Still waiting for config... (${ELAPSED}s elapsed)"
  fi
done

echo "[ton-http-api-config] ERROR: Config file not found after ${MAX_WAIT}s"
echo "[ton-http-api-config] Check ton container logs for issues with config generation"
exit 1
