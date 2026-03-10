#!/usr/bin/env bash
set -euo pipefail

# auto-detect public ip
if [[ -z "${PUBLIC_IP:-}" ]]; then
  echo "[ton] PUBLIC_IP not set, attempting auto-detection..."
  PUBLIC_IP=$(curl -4 -s --max-time 10 http://ifconfig.me || curl -4 -s --max-time 10 http://icanhazip.com || curl -4 -s --max-time 10 http://ipinfo.io/ip || echo "")
  if [[ -z "${PUBLIC_IP}" ]]; then
    echo "[ton] ERROR: Could not auto-detect public IP. Please set PUBLIC_IP environment variable manually."
    exit 1
  fi
  echo "[ton] Detected public IP: ${PUBLIC_IP}"
else
  echo "[ton] Using provided PUBLIC_IP: ${PUBLIC_IP}"
fi
export PUBLIC_IP

TON_WORK_DIR="/var/ton-work"

export VALIDATOR_PORT="${VALIDATOR_PORT:-}"
export LITESERVER_PORT="${LITESERVER_PORT:-}"
export VALIDATOR_CONSOLE_PORT="${VALIDATOR_CONSOLE_PORT:-}"

if [[ -f "${TON_WORK_DIR}/db/mtc_done" ]]; then
  if [[ ! -f /etc/systemd/system/validator.service || ! -f /etc/systemd/system/mytoncore.service ]]; then
    echo "[ton] mtc_done exists but systemd unit files are missing; forcing reinstall"
    rm -f "${TON_WORK_DIR}/db/mtc_done"
    rm -rf /usr/src/mytonctrl || true
  fi
fi

# Export config for ton-http-api if export directory is mounted
if [[ -d "/ton-config-export" ]]; then
  (
    SOURCE_CONFIG="/usr/bin/ton/local.config.json"
    EXPORT_CONFIG="/ton-config-export/local.config.json"

    echo "[ton] Waiting for mytonctrl to be ready..."

    for _ in {1..60}; do
      if bash -c "echo 'exit' | timeout 10 /usr/bin/mytonctrl" >/dev/null 2>&1; then
        echo "[ton] mytonctrl is ready"
        break
      fi
      sleep 10
    done

    if [[ ! -f "${SOURCE_CONFIG}" ]]; then
      echo "[ton] Generating liteserver config..."
      if bash -c "echo 'installer clcf' | /usr/bin/mytonctrl" 2>&1 | tee /tmp/clcf.log | grep -i "created"; then
        echo "[ton] Config generated successfully"
      else
        echo "[ton] Config generation output:"
        cat /tmp/clcf.log 2>/dev/null || true
      fi
      sleep 5
    else
      echo "[ton] Config already exists"
    fi

    for _ in {1..360}; do
      if [[ -f "${SOURCE_CONFIG}" ]] && jq empty "${SOURCE_CONFIG}" 2>/dev/null; then
        cp "${SOURCE_CONFIG}" "${EXPORT_CONFIG}"
        chmod 644 "${EXPORT_CONFIG}"
        echo "[ton] Config exported to ${EXPORT_CONFIG}"

        while true; do
          sleep 60
          if [[ "${SOURCE_CONFIG}" -nt "${EXPORT_CONFIG}" ]] && jq empty "${SOURCE_CONFIG}" 2>/dev/null; then
            cp "${SOURCE_CONFIG}" "${EXPORT_CONFIG}"
            echo "[ton] Config updated"
          fi
        done
        exit 0
      fi
      sleep 10
    done
    echo "[ton] WARNING: Config not found after 1 hour"
  ) &
fi

exec /scripts/entrypoint.sh "$@"
