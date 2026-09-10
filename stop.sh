#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

stop_service() {
  local name="$1" file="$2" needle="$3" pid command_line
  if [[ ! -f "$file" ]]; then
    printf '%s is not running.\n' "$name"
    return
  fi
  pid="$(<"$file")"
  if [[ ! "$pid" =~ ^[0-9]+$ ]] || ! kill -0 "$pid" 2>/dev/null; then
    rm -f -- "$file"
    printf 'Removed stale %s PID file.\n' "$name"
    return
  fi
  command_line="$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null || true)"
  if [[ "$command_line" != *"$needle"* ]]; then
    printf 'Refusing to stop PID %s because it is not the expected %s process.\n' "$pid" "$name" >&2
    return 1
  fi
  kill -TERM "$pid"
  for _ in {1..100}; do
    kill -0 "$pid" 2>/dev/null || break
    sleep .1
  done
  if kill -0 "$pid" 2>/dev/null; then kill -KILL "$pid"; fi
  rm -f -- "$file"
  printf '%s stopped (PID %s).\n' "$name" "$pid"
}

result=0
stop_service 'Web server' "$root/.web-server.pid" "$root/web-server.js" || result=1
stop_service 'Transcription API' "$root/.transcription-server.pid" "$root/api-server.js" || result=1
exit "$result"
