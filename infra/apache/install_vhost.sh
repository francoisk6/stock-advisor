#!/usr/bin/env bash
# Adds (or updates) the Universal Stock Advisor site in Apache (evolution's web server) on our
# own port 8251 — carefully: the port must be free, the whole Apache config is tested BEFORE
# reloading (if the test fails the site is disabled again and Apache is not touched), and
# Apache is checked afterwards. Reload is graceful (open connections finish).
#   sudo bash infra/apache/install_vhost.sh
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo."; exit 1; }

NAME=universal-stock-advisor
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$NAME.conf"
apache2ctl configtest 2>/dev/null || { echo "Apache's config is already failing its test — not touching it."; exit 1; }
# A taken port would make the reload fail (configtest can't see that). Apache itself holding
# 8251 means our site is already enabled — that's fine.
if ss -tlnp | grep -E ':8251 ' | grep -vq apache2; then
  echo "Port 8251 is used by another program — not touching Apache."; exit 1
fi
mkdir -p /home/evo/stock-advisor/prod-web && chown evo:evo /home/evo/stock-advisor/prod-web
install -m 644 "$SRC" "/etc/apache2/sites-available/$NAME.conf"
a2ensite -q "$NAME"
if apache2ctl configtest; then
  systemctl reload apache2
  sleep 2
  if systemctl is-active --quiet apache2 && ss -tln | grep -q ':8251 '; then
    echo "OK: $NAME enabled on our port 8251 and Apache reloaded gracefully."
  else
    echo "WARNING: check Apache now (systemctl status apache2) — it isn't listening as expected."
    exit 1
  fi
else
  a2dissite -q "$NAME"
  echo "Config test failed — vhost disabled again, Apache NOT reloaded."
  exit 1
fi
