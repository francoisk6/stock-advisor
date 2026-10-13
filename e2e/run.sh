#!/usr/bin/env bash
# End-to-end browser tests: real backend (dev DB) + built Flutter web app + headless Chrome.
# Emails go to a temporary outbox (never real SMTP). Test users are deleted afterwards.
#
# Runs on its own ports (API 8290, web 8291) and build folder, so it never collides with
# the dev servers on 8200/8210.
#
# Usage:  bash e2e/run.sh              # builds the web app first
#         SKIP_BUILD=1 bash e2e/run.sh  # reuse frontend/build/e2e-web
#         E2E_TESTS=test_market_flow.py bash e2e/run.sh   # one flow
# Needs:  Python Playwright (pip install --user playwright) and Google Chrome.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
API_PORT=8290
WEB_PORT=8291
WEB_DIR="$ROOT/frontend/build/e2e-web"
export E2E_OUTBOX="$WORK/outbox" E2E_ARTIFACTS="$WORK"
export E2E_BASE_URL="http://localhost:$WEB_PORT" E2E_API_URL="http://localhost:$API_PORT/api/v1"
PIDS=()

cleanup() {
  for pid in "${PIDS[@]}"; do kill "$pid" 2>/dev/null || true; done
  rm -rf "$E2E_OUTBOX"
}
trap cleanup EXIT

# Never fight other services for the ports (evolution runs on this server).
for port in $API_PORT $WEB_PORT; do
  if ss -tln | grep -q ":$port "; then
    echo "Port $port is busy — is another e2e run still going?"; exit 1
  fi
done

if [[ -z "${SKIP_BUILD:-}" ]]; then
  (cd "$ROOT/frontend" && nice -n 19 flutter build web --output "$WEB_DIR" \
    --dart-define=API_BASE_URL="$E2E_API_URL" >/dev/null)
fi

# exec: the recorded PID is uvicorn itself, so cleanup really stops it.
(cd "$ROOT/backend" && EMAIL_BACKEND=outbox EMAIL_OUTBOX_DIR="$E2E_OUTBOX" \
  FRONTEND_URL="$E2E_BASE_URL" CORS_ORIGINS="[\"$E2E_BASE_URL\"]" \
  exec nice -n 10 .venv/bin/uvicorn app.main:app --host 127.0.0.1 --port $API_PORT \
  >"$WORK/api.log" 2>&1) &
PIDS+=($!)
python3 "$ROOT/e2e/spa_server.py" "$WEB_DIR" $WEB_PORT &
PIDS+=($!)

for _ in $(seq 1 40); do
  curl -sf "$E2E_API_URL/health" >/dev/null \
    && curl -sf -o /dev/null "$E2E_BASE_URL/" && break
  sleep 0.5
done

cd "$ROOT/e2e"
status=0
for test in ${E2E_TESTS:-test_*.py}; do
  echo "== $test"
  nice -n 10 python3 "$test" 2>&1 | grep -v "GL Driver" || status=1
done
[[ $status -eq 0 ]] && echo "All e2e flows passed." || echo "E2E FAILED — screenshots/logs in $WORK"
exit $status
