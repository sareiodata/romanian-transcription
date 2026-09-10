#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
node="$root/bin/node"
[[ -x "$node" ]] || node="$(command -v node)"
exec "$node" "$root/web-server.js" "$@"
