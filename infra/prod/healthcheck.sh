#!/usr/bin/env bash
# Every 5 minutes (cron): is production up — the API directly (WireGuard address), then the
# whole public path (VPS nginx → WireGuard → API + database, and the web app via Apache)?
# Emails OPS_ALERT_EMAIL after 2 failed checks in a row, and again when it's back.
set -uo pipefail

PROD="$HOME/stock-advisor/stock-advisor-prod"
STATE="$HOME/.cache/stock-advisor-health"
API="https://universal-stock-advisor.trade/api/v1"
WEB="https://universal-stock-advisor.trade/"
mkdir -p "$(dirname "$STATE")"

problem=""
curl -fsS -m 10 "http://10.0.0.2:8250/api/v1/health" >/dev/null \
  || problem="API not answering on 10.0.0.2:8250 (service or WireGuard down)"
if [[ -z "$problem" ]]; then
  curl -fsS -m 15 "$API/health/db" >/dev/null \
    || problem="Public API path failing (VPS nginx, certificate, WireGuard or database)"
fi
if [[ -z "$problem" ]]; then
  curl -fsS -m 10 -o /dev/null "http://127.0.0.1:8251/" || problem="Web app not served by Apache on 8251"
fi
if [[ -z "$problem" ]]; then
  curl -fsS -m 15 -o /dev/null "$WEB" || problem="Web app not reachable through the VPS (nginx or WireGuard)"
fi

failures=$(cat "$STATE" 2>/dev/null || echo 0)
alert() { (cd "$PROD/backend" && .venv/bin/python -m app.ops alert "$1" "$2"); }
if [[ -n "$problem" ]]; then
  failures=$((failures + 1))
  echo "$failures" > "$STATE"
  if (( failures == 2 )); then
    alert "Site DOWN" "$problem (checked $(date -u '+%F %T') UTC). journalctl -u stock-advisor-api"
  fi
else
  if (( failures >= 2 )); then
    alert "Site back up" "Healthy again at $(date -u '+%F %T') UTC after $failures failed checks."
  fi
  echo 0 > "$STATE"
fi
