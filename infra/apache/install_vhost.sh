#!/usr/bin/env bash
# Adds the Universal Stock Advisor vhost to Apache (evolution's web server) — carefully:
# the whole Apache config is tested BEFORE reloading; if the test fails the vhost is
# disabled again and Apache is not touched. Reload is graceful (open connections finish).
#   sudo bash infra/apache/install_vhost.sh
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo."; exit 1; }

NAME=universal-stock-advisor
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$NAME.conf"
apache2ctl configtest 2>/dev/null || { echo "Apache's config is already failing its test — not touching it."; exit 1; }
mkdir -p /home/evo/stock-advisor/prod-web && chown evo:evo /home/evo/stock-advisor/prod-web
install -m 644 "$SRC" "/etc/apache2/sites-available/$NAME.conf"
a2ensite -q "$NAME"
if apache2ctl configtest; then
  systemctl reload apache2
  echo "OK: $NAME enabled on :8000 and Apache reloaded gracefully."
else
  a2dissite -q "$NAME"
  echo "Config test failed — vhost disabled again, Apache NOT reloaded."
  exit 1
fi
