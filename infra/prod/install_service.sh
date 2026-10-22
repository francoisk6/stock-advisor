#!/usr/bin/env bash
# Installs/updates the production API service. Run with sudo:
#   sudo bash infra/prod/install_service.sh
# Changes exactly one thing: /etc/systemd/system/stock-advisor-api.service (+ daemon-reload,
# enable). It doesn't start the API — the first deploy does. Touches no other service.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo."; exit 1; }
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/stock-advisor-api.service"
install -m 644 "$SRC" /etc/systemd/system/stock-advisor-api.service
systemctl daemon-reload
systemctl enable stock-advisor-api >/dev/null
echo "Installed and enabled stock-advisor-api (not started yet; the first deploy starts it)."
