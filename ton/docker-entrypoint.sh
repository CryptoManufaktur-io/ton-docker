#!/usr/bin/env bash
set -euo pipefail

# auto-detect public ip (override via PUBLIC_IP env var)
if [[ -z "${PUBLIC_IP:-}" ]]; then
  echo "[ton] PUBLIC_IP not set, attempting auto-detection..."
  PUBLIC_IP=$(curl -s --max-time 10 ifconfig.me || curl -s --max-time 10 icanhazip.com || curl -s --max-time 10 ipinfo.io/ip || echo "")
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

exec /scripts/entrypoint.sh "$@"
