#!/usr/bin/env bash
set -euo pipefail

# Fail fast so missing config is obvious in container logs.
: "${PUBLIC_IP:?PUBLIC_IP must be set (public IPv4) for TON node to start}"

TON_WORK_DIR="${TON_WORK_DIR:-/var/ton-work}"

# If using init dump, optionally wait for marker so node doesn't start too early
if [[ "${WAIT_FOR_DUMP:-true}" == "true" ]]; then
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

# Hand off to upstream entrypoint (ton-docker-ctrl image)
exec /scripts/entrypoint.sh "$@"