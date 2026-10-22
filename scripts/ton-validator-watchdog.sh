#!/usr/bin/env bash
# ton-validator-watchdog: recover TON when validator-engine dies to a <defunct>
# zombie (for example after the kernel OOM killer took it) and the
# docker-systemctl-replacement PID 1 inside the container fails to honor Restart=always.
#
# Safe: only restarts after FAILS_REQUIRED consecutive failed checks, with a COOLDOWN between
# restarts, and only when the LIVE main validator-engine process is absent (a zombie has no
# cmdline, so it is not matched and is correctly treated as down). A slow-but-alive validator
# (for example one that is catching up) stays "healthy" because the process is checked, not its sync state.
#
# The check matches the validator-engine binary path followed by a space or the end of the command
# line, so it does not depend on which flags (for example --exporter-address) are present or in
# what order they appear.
#
# Run it from cron on the host that runs the ton container, for example every 3 minutes:
#   */3 * * * * /path/to/ton/scripts/ton-validator-watchdog.sh
#
# Overridable environment: TON_DIR, TON_WATCHDOG_CONTAINER, TON_WATCHDOG_STATE_DIR,
# TON_WATCHDOG_COOLDOWN, TON_WATCHDOG_FAILS_REQUIRED
set -u

TON_DIR="${TON_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CONTAINER="${TON_WATCHDOG_CONTAINER:-ton-ton-1}"
STATE_DIR="${TON_WATCHDOG_STATE_DIR:-${HOME}}"
STATE="${STATE_DIR}/.ton-watchdog.state"
LOCK="${STATE_DIR}/.ton-watchdog.lock"
LOG="${STATE_DIR}/ton-watchdog.log"
COOLDOWN="${TON_WATCHDOG_COOLDOWN:-900}"              # min seconds between restarts
FAILS_REQUIRED="${TON_WATCHDOG_FAILS_REQUIRED:-2}"    # consecutive failed checks before acting

exec 9>"$LOCK"
flock -n 9 || exit 0
now=$(date +%s)
log() { echo "$(date -u '+%FT%TZ') $*" >> "$LOG" 2>/dev/null; }

fails=0
last=0
if [ -r "$STATE" ]; then read -r fails last < "$STATE" 2>/dev/null || true; fi
[ -z "${fails:-}" ] && fails=0
[ -z "${last:-}" ] && last=0

# Live main validator-engine present? (defunct/zombie has empty cmdline -> not matched)
alive=$(docker exec "$CONTAINER" pgrep -f "ton/validator-engine/validator-engine( |$)" 2>/dev/null | head -1)

if [ -n "$alive" ]; then
  echo "0 $last" > "$STATE"
  exit 0
fi

fails=$((fails + 1))
log "validator-engine main process not alive (consecutive fails=$fails)"

if [ "$fails" -ge "$FAILS_REQUIRED" ] && [ $((now - last)) -ge "$COOLDOWN" ]; then
  log "restarting ton stack (docker compose restart ton)"
  ( cd "$TON_DIR" && docker compose restart ton ) >> "$LOG" 2>&1
  echo "0 $now" > "$STATE"
  log "restart issued"
else
  echo "$fails $last" > "$STATE"
  if [ $((now - last)) -lt "$COOLDOWN" ]; then log "within cooldown; not restarting"; fi
fi
