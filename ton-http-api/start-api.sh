#!/usr/bin/env bash
set -euo pipefail

echo "Initial sleeping"
sleep 120

# Check if the config file has been exported
until [[ -f "${TON_API_TONLIB_LITESERVER_CONFIG}" ]] && python3 -c "import json, sys; json.load(open(sys.argv[1]))" "${TON_API_TONLIB_LITESERVER_CONFIG}" 2>/dev/null; do
  echo "[ton-http-api] Waiting for ${TON_API_TONLIB_LITESERVER_CONFIG} to exist and be valid JSON..."
  sleep 60
done

# The ton container writes the host's public IP into local.config.json, but containers
# cannot reach the host's external IP from inside Docker.
# We resolve the 'ton' service name via Docker DNS and patch the config, writing to /tmp
# so the ton container's 60-second background loop can't overwrite our patched copy.
TON_INTERNAL_IP=$(getent hosts ton | awk '{ print $1 }' | head -1)
echo "[ton-http-api] Resolved 'ton' service to internal IP: ${TON_INTERNAL_IP}"
PATCHED_CONFIG="/tmp/local.config.internal.json"
python3 << EOF
import json, socket, struct
with open("${TON_API_TONLIB_LITESERVER_CONFIG}", 'r') as f:
    config = json.load(f)
ip_addr = "${TON_INTERNAL_IP}"
ip_int = struct.unpack('!i', socket.inet_aton(ip_addr))[0]
config['liteservers'][0]['ip'] = ip_int
with open("${PATCHED_CONFIG}", 'w') as f:
    json.dump(config, f, indent=2)
print(f"[ton-http-api] Patched liteserver IP to {ip_addr} ({ip_int})")
EOF
export TON_API_TONLIB_LITESERVER_CONFIG="${PATCHED_CONFIG}"

echo "[ton-http-api] Starting TON HTTP API..."
echo "[ton-http-api] Configuration provided by ton-http-api-config service (via shared volume)"
echo "[ton-http-api] Monitor node sync status on host with: ./ethd check-sync"
echo "[ton-http-api] API healthcheck will show ready once node is synced and responding"

echo "[ton-http-api] Starting gunicorn server..."
# shellcheck disable=SC2086
exec gunicorn -k uvicorn.workers.UvicornWorker \
  -w "${TON_API_WEBSERVERS_WORKERS:-1}" \
  --bind 0.0.0.0:8081 \
  ${TON_API_GUNICORN_FLAGS} \
  pyTON.main:app              # codespell:ignore 
