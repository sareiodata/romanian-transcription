#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
unit='romanian-transcription.service'
unit_path="/etc/systemd/system/$unit"
web_pid_file="$root/.web-server.pid"
api_pid_file="$root/.transcription-server.pid"

usage() {
  cat <<EOF
Usage: $0 [--install|--uninstall|--status]
  (no arguments)  Start the services via start.sh and supervise them (what systemd runs at boot).
  --install       Install, enable and start the systemd service so they run on every boot.
  --uninstall     Disable and remove the systemd service (leaves files and models alone).
  --status        Show the systemd service state.
EOF
}

write_unit() {
  local destination="${1:-$unit_path}" user
  user="$(stat -c '%U' "$root")"
  [[ "$user" != unknown* ]] || { echo "Cannot determine the owner of $root." >&2; exit 1; }
  cat >"$destination" <<EOF
[Unit]
Description=Romanian transcription web and API services
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=300
StartLimitBurst=5

[Service]
Type=exec
User=$user
WorkingDirectory=$root
ExecStart=$root/service_start.sh
ExecStop=$root/stop.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}

pid_alive() {
  local file="$1" pid
  [[ -f "$file" ]] || return 1
  pid="$(<"$file")"
  [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null
}

supervise() {
  # Stay in the foreground so systemd sees a running main process. Exit 0 when the
  # PID files disappear (stop.sh ran), exit 1 when a process died unexpectedly so
  # Restart=on-failure brings both services back.
  while sleep 5; do
    for file in "$web_pid_file" "$api_pid_file"; do
      [[ -f "$file" ]] || { echo 'Services were stopped.'; exit 0; }
      pid_alive "$file" || { echo "Process from $file died unexpectedly." >&2; exit 1; }
    done
  done
}

case "${1:-}" in
  '')
    # Take over cleanly: stop any manually started instances so systemd owns the processes.
    "$root/stop.sh" >/dev/null || true
    "$root/start.sh"
    supervise
    ;;
  --install)
    if [[ $EUID -ne 0 ]]; then exec sudo "$0" --install; fi
    write_unit
    systemctl daemon-reload
    systemctl enable "$unit"
    systemctl restart "$unit"
    echo "Installed and started $unit; the services now start at boot as user $(stat -c '%U' "$root")."
    systemctl --no-pager --lines=0 status "$unit" || true
    ;;
  --uninstall)
    if [[ $EUID -ne 0 ]]; then exec sudo "$0" --uninstall; fi
    systemctl disable --now "$unit" 2>/dev/null || true
    rm -f -- "$unit_path"
    systemctl daemon-reload
    echo "Removed $unit; the services no longer start at boot."
    ;;
  --status)
    systemctl --no-pager status "$unit"
    ;;
  -h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
