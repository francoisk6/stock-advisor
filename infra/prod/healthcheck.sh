#!/usr/bin/env bash
# Every 5 minutes (cron): is the production API up, directly and through Caddy's HTTPS?
# Emails OPS_ALERT_EMAIL after 2 failed checks in a row, and again when it's back.
# Checks from this machine (Caddy is reached via 127.0.0.1, so no router "hairpin" needed);
# an outside uptime monitor is still worth adding for "is it reachable from the internet".
set -uo pipefail

PROD="$HOME/stock-advisor/stock-advisor-prod"
STATE="$HOME/.cache/stock-advisor-health"
API_HOST="api.universal-stock-advisor.trade"
mkdir -p "$(dirname "$STATE")"

problem=""
curl -fsS -m 10 "http://127.0.0.1:8250/api/v1/health" >/dev/null || problem="API not answering on 127.0.0.1:8250"
if [[ -z "$problem" ]]; then
  curl -fsS -m 10 --resolve "$API_HOST:443:127.0.0.1" "https://$API_HOST/api/v1/health/db" >/dev/null \
    || problem="HTTPS (Caddy) or the database check failing"
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
