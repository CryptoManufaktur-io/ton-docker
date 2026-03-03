#!/usr/bin/env bash
set -euo pipefail

: "${PUBLIC_IP:?PUBLIC_IP must be set (public IPv4) for TON node to start}"

TON_WORK_DIR="${TON_WORK_DIR:-/var/ton-work}"

if [[ "${WAIT_FOR_DUMP:-false}" == "true" && "${USE_TON_DUMP:-false}" == "true" ]]; then
  if [[ -f "${TON_WORK_DIR}/db/dump_done" ]]; then
    echo "[ton] dump_done already present."
  else
    echo "[ton] Waiting for ${TON_WORK_DIR}/db/dump_done (WAIT_FOR_DUMP=true)..."
    for ((n=0; n<720; n++)); do
      [[ -f "${TON_WORK_DIR}/db/dump_done" ]] && \
        echo "[ton] dump_done found." && break
      sleep 10
    done
  fi
fi

export DUMP="${DUMP:-false}"
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
