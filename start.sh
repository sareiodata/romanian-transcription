#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
web_pid_file="$root/.web-server.pid"
api_pid_file="$root/.transcription-server.pid"
web_log="$root/web-server.log"
api_log="$root/transcription-server.log"
export TRANSCRIPT_PORT="${TRANSCRIPT_PORT:-8124}"
export TRANSCRIPT_HOST="${TRANSCRIPT_HOST:-0.0.0.0}"
export TRANSCRIPT_API_HOST="${TRANSCRIPT_API_HOST:-0.0.0.0}"
export TRANSCRIPT_API_PORT="${TRANSCRIPT_API_PORT:-8322}"

running_pid() {
  local file="$1" pid
  [[ -f "$file" ]] || return 1
  pid="$(<"$file")"
  [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null
}

clean_stale() {
  local file="$1"
  running_pid "$file" || rm -f -- "$file"
}

clean_stale "$web_pid_file"
clean_stale "$api_pid_file"
if running_pid "$web_pid_file" || running_pid "$api_pid_file"; then
  echo 'One or more transcript services are already running. Run ./stop.sh first.' >&2
  exit 1
fi

cd "$root"
nohup setsid "$root/start-web.sh" >>"$web_log" 2>&1 </dev/null &
web_pid=$!
printf '%s\n' "$web_pid" >"$web_pid_file"

nohup setsid "$root/start-transcription-server.sh" >>"$api_log" 2>&1 </dev/null &
api_pid=$!
printf '%s\n' "$api_pid" >"$api_pid_file"
sleep 1

failed=0
kill -0 "$web_pid" 2>/dev/null || { printf 'Web server failed to start. See %s\n' "$web_log" >&2; failed=1; }
kill -0 "$api_pid" 2>/dev/null || { printf 'Transcription API failed to start. See %s\n' "$api_log" >&2; failed=1; }
if (( failed )); then
  kill -TERM "$web_pid" "$api_pid" 2>/dev/null || true
  rm -f -- "$web_pid_file" "$api_pid_file"
  exit 1
fi

printf 'Web server started (PID %s): http://127.0.0.1:%s\n' "$web_pid" "$TRANSCRIPT_PORT"
printf '  Also available through this machine’s Tailscale IP or hostname.\n'
printf 'Transcription API started (PID %s), listening on %s:%s\n' "$api_pid" "$TRANSCRIPT_API_HOST" "$TRANSCRIPT_API_PORT"
printf 'Logs: %s and %s\n' "$web_log" "$api_log"
