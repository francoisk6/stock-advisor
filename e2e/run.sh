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

TEST_PGID=""
cleanup() {
  for pid in "${PIDS[@]}"; do kill "$pid" 2>/dev/null || true; done
  for pid in "${PIDS[@]}"; do wait "$pid" 2>/dev/null || true; done  # ports free on return
  # Each test runs in its own process group (setsid), so its Playwright driver and Chrome
  # can be stopped without touching anything else. NEVER pkill chrome/playwright by name:
  # evolution's bot workers run Playwright browsers as the same user.
  [[ -n "$TEST_PGID" ]] && kill -- "-$TEST_PGID" 2>/dev/null || true
  rm -rf "$E2E_OUTBOX"
}
trap cleanup EXIT INT TERM

# Evolution runs on this server and has priority: don't start when it's busy or memory is
# short (the build, Chrome and the API need ~4 GB), and run every step at the lowest CPU
# priority. (ionice would do nothing: sda uses mq-deadline, which ignores I/O classes.)
load=$(cut -d' ' -f1 /proc/loadavg)
avail_mb=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
if [[ -z "${E2E_FORCE:-}" ]] && { (( ${load%.*} >= 4 )) || (( avail_mb < 6000 )); }; then
  echo "Server busy (load $load, ${avail_mb} MB free memory) — not starting. E2E_FORCE=1 overrides."
  exit 1
fi
LOW="nice -n 19"

# Never fight other services for the ports (evolution runs on this server).
for port in $API_PORT $WEB_PORT; do
  if ss -tln | grep -q ":$port "; then
    echo "Port $port is busy — is another e2e run still going?"; exit 1
  fi
done

if [[ -z "${SKIP_BUILD:-}" ]]; then
  (cd "$ROOT/frontend" && $LOW flutter build web --output "$WEB_DIR" \
    --dart-define=API_BASE_URL="$E2E_API_URL" >/dev/null)
fi

# exec: the recorded PID is uvicorn itself, so cleanup really stops it.
(cd "$ROOT/backend" && EMAIL_BACKEND=outbox EMAIL_OUTBOX_DIR="$E2E_OUTBOX" \
  FRONTEND_URL="$E2E_BASE_URL" CORS_ORIGINS="[\"$E2E_BASE_URL\"]" \
  ALERT_CHECK_SECONDS=3 LIVE_PRICE_SECONDS=5 \
  exec $LOW .venv/bin/uvicorn app.main:app --host 127.0.0.1 --port $API_PORT \
  >"$WORK/api.log" 2>&1) &
PIDS+=($!)
$LOW python3 "$ROOT/e2e/spa_server.py" "$WEB_DIR" $WEB_PORT &
PIDS+=($!)

# Startup reads a lot from the (shared, spinning) disk: allow up to 90 s.
ready=""
for _ in $(seq 1 180); do
  if curl -sf "$E2E_API_URL/health" >/dev/null && curl -sf -o /dev/null "$E2E_BASE_URL/"; then
    ready=1; break
  fi
  sleep 0.5
done
if [[ -z "$ready" ]]; then
  echo "The e2e API/web server didn't start — log: $WORK/api.log"; tail -5 "$WORK/api.log"; exit 1
fi

cd "$ROOT/e2e"
status=0
for test in ${E2E_TESTS:-test_*.py}; do
  echo "== $test"
  setsid $LOW python3 "$test" > "$WORK/$test.log" 2>&1 &
  TEST_PGID=$!  # setsid makes the test the leader of a new group: pgid == pid
  wait "$TEST_PGID" || status=1
  kill -- "-$TEST_PGID" 2>/dev/null || true  # anything the test left running
  TEST_PGID=""
  grep -v "GL Driver" "$WORK/$test.log" || true
done
[[ $status -eq 0 ]] && echo "All e2e flows passed." || echo "E2E FAILED — screenshots/logs in $WORK"
exit $status
