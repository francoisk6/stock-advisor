#!/usr/bin/env bash
# One-time: create the production copy next to the dev workspace. No sudo; prints the few
# steps that need you (secrets, `sudo mysql`, linger).
#   bash infra/prod/setup_prod.sh
set -euo pipefail

DEV="$HOME/stock-advisor/stock-advisor-dev"
PROD="$HOME/stock-advisor/stock-advisor-prod"

if [[ ! -d "$PROD/.git" ]]; then
  git clone --quiet "$DEV" "$PROD"   # deploys check out tags from the dev repository
  echo "Cloned the code to $PROD"
fi

cd "$PROD/backend"
[[ -d .venv ]] || "$HOME/.local/bin/virtualenv" -q .venv
nice -n 19 .venv/bin/pip install -q -e .

if [[ ! -f .env ]]; then
  sed "s|^JWT_SECRET=.*|JWT_SECRET=$(.venv/bin/python -c 'import secrets; print(secrets.token_urlsafe(48))')|" \
    "$DEV/infra/prod/env.prod.example" > .env
  chmod 600 .env
  echo "Created $PROD/backend/.env (JWT secret generated). Fill DB_PASSWORD, SMTP_*, EMAIL_FROM, OPS_ALERT_EMAIL."
fi

mkdir -p "$HOME/stock-advisor/prod-web" "$HOME/backups/stock-advisor"

cat <<NEXT

Next (see docs/PRODUCTION.md):
  1. Edit $PROD/backend/.env
  2. bash $DEV/infra/prod/create_prod_db.sh        # uses sudo mysql; own DB + user only
  3. sudo bash $DEV/infra/prod/install_service.sh   # the API service (one systemd file)
  4. Fill the [TO FILL] parts of frontend/assets/legal/en/*.md, commit, tag, deploy.
NEXT
