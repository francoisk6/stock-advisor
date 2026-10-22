# Production — closed web beta on this server

```
Internet ──443──▶ Caddy (Docker, host network)      Apache/evolution keeps port 80, untouched
                    ├─ universal-stock-advisor.trade      → web app (~/stock-advisor/prod-web)
                    └─ api.universal-stock-advisor.trade  → API 127.0.0.1:8250
                                                            (systemd: stock-advisor-api, user evo,
                                                             Nice 10, ≤1.5 CPU, ≤1.5 GB)
API ─▶ MySQL: stock_advisor_prod (own user)   ·   Ollama 127.0.0.1:11434 (shared with dev)
```

Code: `~/stock-advisor/stock-advisor-prod` is a clone of the dev repository; each deploy checks
out a **tag**. Secrets: `stock-advisor-prod/backend/.env` (chmod 600, never committed).

## What you need first

1. **Network:** forward **TCP 443** from your router/public IP to `192.168.150.101:443`.
   Nothing else needs to be opened.
2. **DNS** (at your domain registrar): `A` records for `universal-stock-advisor.trade` and
   `api.universal-stock-advisor.trade` → your public IP.
3. **Email:** an address + Gmail app password to send from (the dev one works for the beta),
   and an address for operations alerts.
4. **Legal texts:** fill every `[TO FILL: …]` in `frontend/assets/legal/en/*.md` (operator
   name, contact email, dates, minimum age, email provider, jurisdiction). Have them reviewed.
   Deploys refuse while placeholders remain.
5. Optional, **Google sign-in:** in Google Cloud → Credentials → the web client, add the origin
   `https://universal-stock-advisor.trade`, then put the client id in `GOOGLE_CLIENT_IDS`.

## One-time setup (in this order)

| # | Command (from `~/stock-advisor/stock-advisor-dev`) | What it changes |
|---|---|---|
| 1 | `bash infra/prod/setup_prod.sh` | Creates `~/stock-advisor/stock-advisor-prod` (clone + venv), its `.env` with a generated JWT secret, `~/stock-advisor/prod-web`, `~/backups/stock-advisor`. No sudo. |
| 2 | edit `~/stock-advisor/stock-advisor-prod/backend/.env` | `DB_PASSWORD`, `SMTP_*`, `EMAIL_FROM`, `OPS_ALERT_EMAIL` (template: `infra/prod/env.prod.example`). |
| 3 | `bash infra/prod/create_prod_db.sh` | **`sudo mysql`**: creates database `stock_advisor_prod` and user `stock_advisor_prod` (localhost/127.0.0.1, max 20 connections) with rights on that database only. Nothing else in MySQL. |
| 4 | `sudo bash infra/prod/install_service.sh` | **sudo**: adds `/etc/systemd/system/stock-advisor-api.service`, `daemon-reload`, `enable`. Doesn't start it. No other service touched. |
| 5 | fill legal texts → `git commit` → `git tag v0.1.0-beta` → `bash infra/deploy.sh v0.1.0-beta` | Checks out the tag in prod, migrates the prod DB, builds the web app (low priority), publishes it, **sudo** restarts `stock-advisor-api` only, waits for it to be healthy. |
| 6 | `cd infra/caddy && ACME_EMAIL=you@example.com sg docker -c "docker compose up -d"` | Starts the Caddy container: listens on **0.0.0.0:443** (public) and gets certificates once DNS + port 443 work (it retries by itself). Memory ≤256 MB, ≤0.5 CPU. |
| 7 | `cd ~/stock-advisor/stock-advisor-prod/backend && .venv/bin/python -m app.admin invite add you@example.com` | Lets you create the first account at `https://universal-stock-advisor.trade`. |
| 8 | `(crontab -l 2>/dev/null; cat infra/prod/crontab.txt) \| crontab -` | Health check every 5 min (emails on down/up), nightly DB backup at 03:30 (keeps 14). |

Check after step 6: `ss -tlnp | grep -E ':443|:8298'` (443 public; Caddy shouldn't need
8298, it's set only so it never tries port 80), and `curl -I https://universal-stock-advisor.trade`
from a phone on mobile data.

**Always share `https://` links.** Typing the bare domain makes browsers try `http://` first,
which is port 80 = evolution's Apache. Fixing that needs a one-line redirect in Apache (your
explicit OK) or another machine — before any public launch.

## Day to day

```bash
# Deploy a new version (from the dev workspace, after tests pass)
git tag v0.1.1-beta && bash infra/deploy.sh v0.1.1-beta
# Roll back: deploy the previous tag (database migrations are NOT undone automatically)
bash infra/deploy.sh v0.1.0-beta

# Invites (from ~/stock-advisor/stock-advisor-prod/backend)
.venv/bin/python -m app.admin invite add friend@example.com --note "from Ana"
.venv/bin/python -m app.admin invite list
.venv/bin/python -m app.admin grant-pro friend@example.com --days 30

# Logs / status
journalctl -u stock-advisor-api -n 100 --no-pager
sudo systemctl status stock-advisor-api
sg docker -c "docker logs --tail 50 caddy-caddy-1"

# Restore a backup (stops nothing else; overwrites the prod DB!)
gunzip -c ~/backups/stock-advisor/prod-YYYYMMDD-HHMM.sql.gz | mysql -u stock_advisor_prod -p -h 127.0.0.1 stock_advisor_prod
```

## Not covered by the closed beta (needed before a public launch)

- `http://` on the bare domain reaches evolution (see above).
- Licensed market data and news (yfinance and Google News RSS forbid commercial use).
- A transactional email provider with SPF/DKIM for the domain.
- Payments (Stripe, store billing), mobile apps, an outside uptime monitor.
