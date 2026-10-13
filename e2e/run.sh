#!/usr/bin/env bash
# End-to-end browser tests: real backend (dev DB) + built Flutter web app + headless Chrome.
# Emails go to a temporary outbox (never real SMTP). Test users are deleted afterwards.
#
# Usage:  bash e2e/run.sh              # builds the web app first
#         SKIP_BUILD=1 bash e2e/run.sh  # reuse frontend/build/web
# Needs:  Python Playwright (pip install --user playwright) and Google Chrome.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
export E2E_OUTBOX="$WORK/outbox" E2E_ARTIFACTS="$WORK"
PIDS=()

cleanup() {
  for pid in "${PIDS[@]}"; do kill "$pid" 2>/dev/null || true; done
  rm -rf "$E2E_OUTBOX"
}
trap cleanup EXIT

# Never fight other services for the ports (evolution runs on this server).
for port in 8200 8210; do
  if ss -tln | grep -q ":$port "; then
    echo "Port $port is busy — stop the dev server first."; exit 1
  fi
done

if [[ -z "${SKIP_BUILD:-}" ]]; then
  (cd "$ROOT/frontend" && nice -n 19 flutter build web >/dev/null)
fi

# exec: the recorded PID is uvicorn itself, so cleanup really stops it.
(cd "$ROOT/backend" && EMAIL_BACKEND=outbox EMAIL_OUTBOX_DIR="$E2E_OUTBOX" \
  exec nice -n 10 .venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8200 \
  >"$WORK/api.log" 2>&1) &
PIDS+=($!)
python3 "$ROOT/e2e/spa_server.py" "$ROOT/frontend/build/web" 8210 &
PIDS+=($!)

for _ in $(seq 1 40); do
  curl -sf http://localhost:8200/api/v1/health >/dev/null \
    && curl -sf -o /dev/null http://localhost:8210/ && break
  sleep 0.5
done

cd "$ROOT/e2e"
status=0
for test in test_*.py; do
  echo "== $test"
  nice -n 10 python3 "$test" 2>&1 | grep -v "GL Driver" || status=1
done
[[ $status -eq 0 ]] && echo "All e2e flows passed." || echo "E2E FAILED — screenshots/logs in $WORK"
exit $status
