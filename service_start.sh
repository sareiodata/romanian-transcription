#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
unit='romanian-transcription.service'
unit_path="/etc/systemd/system/$unit"

usage() {
  cat <<EOF
Usage: $0 [--install|--uninstall]
  (no arguments)  Start the services via start.sh (this is what systemd runs at boot).
  --install       Install and enable the systemd service that starts them on every boot.
  --uninstall     Disable and remove the systemd service (leaves files and models alone).
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

[Service]
Type=oneshot
RemainAfterExit=yes
User=$user
WorkingDirectory=$root
ExecStart=$root/service_start.sh
ExecStop=$root/stop.sh

[Install]
WantedBy=multi-user.target
EOF
}

case "${1:-}" in
  '')
    # Take over cleanly: stop any manually started instances so systemd owns the processes.
    "$root/stop.sh" >/dev/null || true
    exec "$root/start.sh"
    ;;
  --install)
    if [[ $EUID -ne 0 ]]; then exec sudo "$0" --install; fi
    write_unit
    systemctl daemon-reload
    systemctl enable "$unit"
    echo "Installed $unit; the services now start at boot as user $(stat -c '%U' "$root")."
    echo "Start them now: sudo systemctl start $unit"
    ;;
  --uninstall)
    if [[ $EUID -ne 0 ]]; then exec sudo "$0" --uninstall; fi
    systemctl disable --now "$unit" 2>/dev/null || true
    rm -f -- "$unit_path"
    systemctl daemon-reload
    echo "Removed $unit; the services no longer start at boot."
    ;;
  -h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
