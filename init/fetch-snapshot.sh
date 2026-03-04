#!/usr/bin/env bash
set -euo pipefail

TON_WORK_DIR="/var/ton-work"
DB_DIR="${TON_WORK_DIR}/db"
GLOBAL_CONFIG_URL="${GLOBAL_CONFIG_URL:-https://ton.org/global.config.json}"
SNAPSHOT="${SNAPSHOT:-}"

mkdir -p "${DB_DIR}"

if [[ -z "${SNAPSHOT}" ]]; then
  echo "[ton-init] SNAPSHOT not set; skipping snapshot download (will sync from network)."
  touch "${DB_DIR}/dump_done"
  exit 0
fi

if [[ -f "${DB_DIR}/dump_done" ]]; then
  echo "[ton-init] Snapshot already present (${DB_DIR}/dump_done)."
  exit 0
fi

# parse snapshot: full url or dump name
if [[ "${SNAPSHOT}" == http* ]]; then
  URL_DUMP="${SNAPSHOT}"
  DUMP_BASE_URL="${SNAPSHOT%/dumps/*}"
  DUMP_NAME="${SNAPSHOT##*/}"
  DUMP_NAME="${DUMP_NAME%.tar.lz}"
else
  DUMP_BASE_URL="https://dump.ton.org"
  DUMP_NAME="${SNAPSHOT}"
  URL_DUMP="${DUMP_BASE_URL}/dumps/${DUMP_NAME}.tar.lz"
fi

URL_SIZE="${DUMP_BASE_URL}/dumps/${DUMP_NAME}.tar.size.archive.txt"

echo "[ton-init] Snapshot: ${DUMP_NAME}"
echo "[ton-init] Size URL: ${URL_SIZE}"
echo "[ton-init] Dump URL: ${URL_DUMP}"

DUMPSIZE="$(aria2c --max-tries=5 --retry-wait=5 --console-log-level=error --summary-interval=0 --allow-overwrite=true -d /tmp -o dump_size.txt "${URL_SIZE}" >/dev/null 2>&1 && cat /tmp/dump_size.txt && rm -f /tmp/dump_size.txt || true)"
if [[ -z "${DUMPSIZE}" ]]; then
  echo "[ton-init] Could not fetch dump size from ${URL_SIZE}"
  exit 1
fi

DISKSPACE="$(df -B1 --output=avail "${TON_WORK_DIR}" | tail -n1 | tr -d ' ')"
NEEDSPACE="$(( 3 * DUMPSIZE ))"

echo "[ton-init] Available bytes: ${DISKSPACE}"
echo "[ton-init] Required bytes : ${NEEDSPACE}"

if (( DISKSPACE <= NEEDSPACE )); then
  echo "[ton-init] Not enough free space. Need at least ${NEEDSPACE} bytes free on ${TON_WORK_DIR}."
  exit 1
fi

THREADS="$(nproc || echo 4)"
echo "[ton-init] Using ${THREADS} threads for plzip"

aria2c \
  --max-tries=10 \
  --retry-wait=5 \
  --max-connection-per-server=4 \
  --split=4 \
  --min-split-size=10M \
  --console-log-level=warn \
  --summary-interval=10 \
  --allow-overwrite=true \
  -d /tmp \
  -o dump.tar.lz \
  "${URL_DUMP}"

echo "[ton-init] Download complete. Extracting..."
pv /tmp/dump.tar.lz | plzip -d -n"${THREADS}" | tar -xC "${DB_DIR}"
rm -f /tmp/dump.tar.lz

mkdir -p "${DB_DIR}/static" "${DB_DIR}/import"
touch "${DB_DIR}/dump_done"

chown -R 1000:1000 "${TON_WORK_DIR}" || true

echo "[ton-init] Dump download + extract complete."
