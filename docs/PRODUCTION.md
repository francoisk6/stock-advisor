# Production — closed web beta (same setup as evolution's production)

```
Internet ─80/443─▶ VPS 164.92.140.58: nginx + certbot (HTTPS, http→https redirect)
                     │  WireGuard 10.0.0.1 → 10.0.0.2 (this server)
                     ├─ universal-stock-advisor.trade (+ www) → Apache :8000, our vhost
                     │                                          → ~/stock-advisor/prod-web (Flutter build)
                     └─ api.universal-stock-advisor.trade     → 10.0.0.2:8250 API (REST + WebSocket)
                                                                systemd stock-advisor-api, user evo,
                                                                Nice 10, ≤1.5 CPU, ≤1.5 GB
API ─▶ MySQL stock_advisor_prod (own user)   ·   Ollama 127.0.0.1:11434 (shared with dev)
```

Nothing of ours listens publicly on this server: the API binds only to the WireGuard address,
like evolution's sites, which the VPS reaches over the tunnel.

Code: `~/stock-advisor/stock-advisor-prod` is a clone of the dev repository; each deploy checks
out a **tag**. Secrets: `stock-advisor-prod/backend/.env` (chmod 600, never committed).

## What you need first

1. **DNS** (at your domain registrar): `A` records for `universal-stock-advisor.trade`,
   `www.universal-stock-advisor.trade` and `api.universal-stock-advisor.trade` → **164.92.140.58**
   (the VPS). No router changes at home.
2. **Email:** an address + Gmail app password to send from (the dev one works for the beta),
   and an address for operations alerts.
3. **Legal texts:** fill every `[TO FILL: …]` in `frontend/assets/legal/en/*.md` (operator
   name, contact email, dates, minimum age, email provider, jurisdiction). Have them reviewed.
   Deploys refuse while placeholders remain.
4. Optional, **Google sign-in:** in Google Cloud → Credentials → the web client, add the origin
   `https://universal-stock-advisor.trade`, then put the client id in `GOOGLE_CLIENT_IDS`.

## One-time setup — home server (in this order)

| # | Command (from `~/stock-advisor/stock-advisor-dev`) | What it changes |
|---|---|---|
| 1 | `bash infra/prod/setup_prod.sh` | Clones the code into `~/stock-advisor/stock-advisor-prod` (+ venv), creates its `.env` with a generated JWT secret, `~/stock-advisor/prod-web`, `~/backups/stock-advisor`. No sudo. |
| 2 | edit `~/stock-advisor/stock-advisor-prod/backend/.env` | `DB_PASSWORD`, `SMTP_*`, `EMAIL_FROM`, `OPS_ALERT_EMAIL` (template: `infra/prod/env.prod.example`). |
| 3 | `bash infra/prod/create_prod_db.sh` | **`sudo mysql`**: creates database `stock_advisor_prod` and user `stock_advisor_prod` (localhost/127.0.0.1, max 20 connections) with rights on that database only. Nothing else in MySQL. |
| 4 | `sudo bash infra/prod/install_service.sh` | **sudo**: adds `/etc/systemd/system/stock-advisor-api.service`, `daemon-reload`, `enable`. Doesn't start it. No other service touched. |
| 5 | `sudo bash infra/apache/install_vhost.sh` | **sudo, evolution's Apache**: adds `/etc/apache2/sites-available/universal-stock-advisor.conf` (a `*:8000` vhost for our domain only), `a2ensite`, then **tests the whole config first** — reloads Apache gracefully only if the test passes, otherwise disables the vhost again and leaves Apache alone. |
| 6 | fill legal texts → `git commit` → `git tag v0.1.0-beta` → `bash infra/deploy.sh v0.1.0-beta` | Checks out the tag in prod, migrates the prod DB, builds the web app (low priority), publishes it to `prod-web`, **sudo** restarts `stock-advisor-api` only, waits until healthy. |
| 7 | `cd ~/stock-advisor/stock-advisor-prod/backend && .venv/bin/python -m app.admin invite add you@example.com` | Lets you create the first account. |
| 8 | `(crontab -l 2>/dev/null; cat infra/prod/crontab.txt) \| crontab -` | Health check every 5 min (direct + the full public path; emails on down/up), nightly DB backup at 03:30 (keeps 14). |

Quick checks on the home server: `curl -s http://10.0.0.2:8250/api/v1/health` and
`curl -sI -H 'Host: universal-stock-advisor.trade' http://10.0.0.2:8000/` (200, our index.html).
If a firewall (ufw) is active here, allow 10.0.0.1 → port 8250 on `wg0` (8000 already works for evolution).

## One-time setup — VPS (as for evolution-portal.com)

```bash
# copy infra/nginx/universal-stock-advisor.trade.conf to the VPS, then on the VPS:
sudo cp universal-stock-advisor.trade.conf /etc/nginx/sites-available/universal-stock-advisor.trade
sudo ln -s /etc/nginx/sites-available/universal-stock-advisor.trade /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx          # nginx -t first: evolution's sites live here too

curl -sI http://api.universal-stock-advisor.trade/api/v1/health    # once DNS points here
sudo certbot --nginx -d universal-stock-advisor.trade -d www.universal-stock-advisor.trade \
  -d api.universal-stock-advisor.trade                # choose "redirect" (http → https)
```

Certbot adds the HTTPS blocks and renews automatically (like evolution's certificates). The
WebSocket settings (Upgrade header, 1-hour timeouts) are in the `location` blocks certbot copies.

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
tail -n 50 /var/log/apache2/universal_stock_advisor_error.log

# Restore a backup (overwrites the prod DB!)
gunzip -c ~/backups/stock-advisor/prod-YYYYMMDD-HHMM.sql.gz | mysql -u stock_advisor_prod -p -h 127.0.0.1 stock_advisor_prod
```

## Not covered by the closed beta (needed before a public launch)

- Licensed market data and news (yfinance and Google News RSS forbid commercial use).
- A transactional email provider with SPF/DKIM for the domain.
- Payments (Stripe, store billing), mobile apps, an outside uptime monitor.
- Capacity: public traffic and the CPU-only AI share this server with evolution.
