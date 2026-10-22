#!/usr/bin/env bash
# Deploy a tagged version to production (closed web beta on this server).
#   cd ~/stock-advisor/stock-advisor-dev && git tag v0.1.0-beta && bash infra/deploy.sh v0.1.0-beta
# Evolution has priority: refuses when the server is busy; builds at the lowest priority;
# restarts only the Stock Adviser API service (asks for your sudo password) — never Apache/MySQL.
set -euo pipefail

TAG="${1:?usage: bash infra/deploy.sh <tag>}"
PROD="$HOME/stock-advisor/stock-advisor-prod"
WEB_DIR="$HOME/stock-advisor/prod-web"
API_URL="https://api.universal-stock-advisor.trade/api/v1"

load=$(cut -d' ' -f1 /proc/loadavg)
if [[ -z "${DEPLOY_FORCE:-}" ]] && (( ${load%.*} >= 4 )); then
  echo "Server busy (load $load) — try later, or DEPLOY_FORCE=1."; exit 1
fi

cd "$PROD"
git fetch --quiet --tags origin
git -c advice.detachedHead=false checkout --quiet --force "$TAG"
echo "== $TAG checked out"

# Guards: production settings and finished legal texts.
grep -q '^ENVIRONMENT=prod' backend/.env || { echo "backend/.env is not ENVIRONMENT=prod"; exit 1; }
if grep -rln "TO FILL" frontend/assets/legal/; then
  echo "Refusing: the legal pages above still contain [TO FILL] placeholders."; exit 1
fi

cd backend
nice -n 19 .venv/bin/pip install -q -e .
.venv/bin/alembic upgrade head
.venv/bin/python -m app.market_data.seed >/dev/null
echo "== database migrated"

cd ../frontend
GOOGLE_ID=$(grep -E '^GOOGLE_CLIENT_IDS=' ../backend/.env | sed -E 's/.*\["([^"]+)".*/\1/;t;d' || true)
nice -n 19 flutter build web --release --output build/prod-web \
  --dart-define=BETA=true --dart-define=API_BASE_URL="$API_URL" \
  ${GOOGLE_ID:+--dart-define=GOOGLE_WEB_CLIENT_ID=$GOOGLE_ID} >/dev/null
mkdir -p "$WEB_DIR"
rsync -a --delete build/prod-web/ "$WEB_DIR/"
echo "== web app built and published"

sudo systemctl restart stock-advisor-api
for _ in $(seq 1 60); do
  if curl -fsS -m 3 http://127.0.0.1:8250/api/v1/health/db >/dev/null 2>&1; then
    echo "== $TAG is live"; exit 0
  fi
  sleep 2
done
echo "The API didn't come back within 2 minutes: journalctl -u stock-advisor-api -n 50"
exit 1
