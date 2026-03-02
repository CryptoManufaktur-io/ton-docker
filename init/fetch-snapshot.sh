#!/usr/bin/env bash
set -euo pipefail

TON_WORK_DIR="${TON_WORK_DIR:-/var/ton-work}"
DB_DIR="${TON_WORK_DIR}/db"
DUMP_BASE_URL="${DUMP_BASE_URL:-https://dump.ton.org}"
GLOBAL_CONFIG_URL="${GLOBAL_CONFIG_URL:-https://ton.org/global.config.json}"
USE_TON_DUMP="${USE_TON_DUMP:-false}"
DUMP_NAME="${DUMP_NAME:-}"
DUMP_THREADS="${DUMP_THREADS:-}"

mkdir -p "${DB_DIR}"

if [[ "${USE_TON_DUMP}" != "true" ]]; then
  echo "[ton-init] USE_TON_DUMP=false; creating dump_done marker."
  mkdir -p "${DB_DIR}"
  touch "${DB_DIR}/dump_done"
  exit 0
fi

if [[ -f "${DB_DIR}/dump_done" ]]; then
  echo "[ton-init] dump already present (${DB_DIR}/dump_done)."
  exit 0
fi

# Auto-select dump name if not provided
if [[ -z "${DUMP_NAME}" ]]; then
  if [[ "${GLOBAL_CONFIG_URL}" == *"testnet"* ]]; then
    DUMP_NAME="latest_testnet"
  else
    DUMP_NAME="latest"
  fi
fi

URL_SIZE="${DUMP_BASE_URL}/dumps/${DUMP_NAME}.tar.size.archive.txt"
URL_DUMP="${DUMP_BASE_URL}/dumps/${DUMP_NAME}.tar.lz"

echo "[ton-init] Selected dump: ${DUMP_NAME}"
echo "[ton-init] Size URL: ${URL_SIZE}"
echo "[ton-init] Dump URL: ${URL_DUMP}"

DUMPSIZE="$(curl --fail --retry 5 --retry-delay 5 --silent "${URL_SIZE}" || true)"
if [[ -z "${DUMPSIZE}" ]]; then
  echo "[ton-init] Could not fetch dump size from ${URL_SIZE}"
  exit 1
fi

DISKSPACE="$(df -B1 --output=avail "${TON_WORK_DIR}" | tail -n1 | tr -d ' ')"
NEEDSPACE="$(( 3 * DUMPSIZE ))" # 3x safety margin

echo "[ton-init] Available bytes: ${DISKSPACE}"
echo "[ton-init] Required bytes : ${NEEDSPACE}"

if (( DISKSPACE <= NEEDSPACE )); then
  echo "[ton-init] Not enough free space. Need at least ${NEEDSPACE} bytes free on ${TON_WORK_DIR}."
  exit 1
fi

if [[ -z "${DUMP_THREADS}" ]]; then
  DUMP_THREADS="$(nproc || echo 4)"
fi
echo "[ton-init] Using ${DUMP_THREADS} threads for plzip"

curl --fail --retry 5 --retry-delay 10 --silent "${URL_DUMP}" \
  | pv --force \
  | plzip -d -n"${DUMP_THREADS}" \
  | tar -xC "${DB_DIR}"

mkdir -p "${DB_DIR}/static" "${DB_DIR}/import"
touch "${DB_DIR}/dump_done"

chown -R 1000:1000 "${TON_WORK_DIR}" || true

echo "[ton-init] Dump download + extract complete."
