#!/usr/bin/env bash
# lg-hold.sh — run as the `--run` command of `adi-lg request` so the booted board stays
# reserved for a MATLAB session (labgrid.Session).
#
#   bash lg-hold.sh LEASE_JSON RELEASE_FILE PARENT_PID MAX_HOLD_SECONDS [POLL_SECONDS]
#
# 1. Writes the lease adi-lg exported (IIO_URI, LG_PLACE, LG_CARRIER, HW_DAUGHTER, HW_CARRIER)
#    to LEASE_JSON (atomically), then
# 2. blocks until one of:
#      RELEASE_FILE exists                      -> exit 0  (MATLAB released the board)
#      PARENT_PID (>0) is no longer running     -> exit 2  (MATLAB died; do not leak the board)
#      MAX_HOLD_SECONDS elapsed                 -> exit 3  (backstop)
# When this script exits, adi-lg releases the place.
set -u
if [ $# -lt 4 ]; then
  echo "usage: lg-hold.sh LEASE_JSON RELEASE_FILE PARENT_PID MAX_HOLD_SECONDS [POLL_SECONDS]" >&2
  exit 64
fi
lease=$1; release=$2; parent=$3; max_hold=$4; poll=${5:-1}

json_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
tmp="${lease}.tmp.$$"
{
  printf '{'
  printf '"uri":"%s",' "$(json_escape "${IIO_URI:-}")"
  printf '"place":"%s",' "$(json_escape "${LG_PLACE:-}")"
  printf '"carrier":"%s",' "$(json_escape "${LG_CARRIER:-${HW_CARRIER:-}}")"
  printf '"daughter":"%s",' "$(json_escape "${HW_DAUGHTER:-}")"
  printf '"pid":%d,' "$$"
  printf '"started":%d' "$(date +%s)"
  printf '}\n'
} > "$tmp" && mv -f "$tmp" "$lease"

start=$(date +%s)
while :; do
  [ -e "$release" ] && exit 0
  if [ "$parent" -gt 0 ] 2>/dev/null && ! kill -0 "$parent" 2>/dev/null; then
    echo "lg-hold: parent $parent is gone; releasing" >&2
    exit 2
  fi
  now=$(date +%s)
  if [ $((now - start)) -ge "$max_hold" ]; then
    echo "lg-hold: max hold of ${max_hold}s reached; releasing" >&2
    exit 3
  fi
  sleep "$poll"
done
