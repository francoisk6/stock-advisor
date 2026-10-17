# Stock Adviser — Runbook

Copy-paste commands for running, building and setting up the project. All paths are relative to
`~/stock-advisor/stock-advisor-dev` unless shown otherwise.

> **Shared server.** The evolution project runs in production on this machine and has priority.
> Our ports are 8200–8299, heavy builds run with `nice`, and system changes go through the
> scripts in `infra/` (they say what they change).

| What | Address |
|---|---|
| Backend API | `http://localhost:8200/api/v1` (docs: `/docs`) |
| Web app (dev) | `http://localhost:8210` — or `http://192.168.150.101:8210` on the LAN |
| Ollama (AI model) | `http://127.0.0.1:11434` (server only) |
| SearXNG (web search, Phase 5) | `http://127.0.0.1:8220` (server only) |
| Production (planned, Phase 8) | web `https://universal-stock-advisor.trade`, API `https://api.universal-stock-advisor.trade/api/v1` |

---

## 1. Run the API and the web app (daily development)

Open two terminals.

**Terminal 1 — backend API** (restarts itself when code changes):
```bash
cd ~/stock-advisor/stock-advisor-dev/backend
.venv/bin/uvicorn app.main:app --reload --host 0.0.0.0 --port 8200
```
Use `--host 127.0.0.1` instead if you don't need access from other devices (phone, LAN PC).

**Terminal 2 — Flutter web app:**
```bash
cd ~/stock-advisor/stock-advisor-dev/frontend
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8210 \
  --dart-define=GOOGLE_WEB_CLIENT_ID=501047197481-o8mpb5ijn6ih0r3739amn1imvlb68sik.apps.googleusercontent.com
```
In this terminal: `r` = hot reload, `R` = restart the app (use after pulling new code), `q` = quit.

**Open the app**
- On the server / through VS Code port forwarding: **`http://localhost:8210`**
  (not `127.0.0.1` — Google sign-in only accepts `localhost`).
- From another device on the LAN: `http://192.168.150.101:8210` (email + password only; Google
  doesn't allow sign-in on IP addresses).

**Stop:** `Ctrl+C` in each terminal.

**After pulling new code** (once per update):
```bash
cd ~/stock-advisor/stock-advisor-dev/backend
.venv/bin/pip install -q -e ".[dev]"            # new Python packages, if any
.venv/bin/alembic upgrade head                   # database changes
.venv/bin/python -m app.market_data.seed         # asset catalog updates
cd ../frontend && flutter pub get                # new Flutter packages, if any
```

**Health checks**
```bash
curl -s localhost:8200/api/v1/health/db          # API + database
systemctl status ollama --no-pager               # AI model service
curl -s 127.0.0.1:11434/api/tags                 # installed AI models
docker ps --format '{{.Names}} {{.Status}}'       # SearXNG (web search)
```

**Daily jobs** (run inside the API process; times in UTC, set in `backend/.env`):
`DAILY_PRICES_HOUR_UTC=2` stores daily prices, `DIGEST_HOUR_UTC=3` writes everyone's morning
brief (06:00 Beirut). Each runs once per day; check what ran:
```bash
cd ~/stock-advisor/stock-advisor-dev/backend && .venv/bin/python -c "
import pymysql; from app.core.config import settings as s
c=pymysql.connect(host=s.db_host,user=s.db_user,password=s.db_password,database=s.db_name)
cur=c.cursor(); cur.execute('select * from job_runs order by day desc, name limit 10')
[print(r) for r in cur.fetchall()]"
```

---

## 2. Tests

```bash
cd ~/stock-advisor/stock-advisor-dev/backend && .venv/bin/pytest -q && .venv/bin/ruff check .
cd ~/stock-advisor/stock-advisor-dev/frontend && flutter analyze && flutter test
cd ~/stock-advisor/stock-advisor-dev && bash e2e/run.sh     # browser tests, ~10 min
```
The browser tests use their own ports (8290/8291) and a temporary email outbox, so they can run
while your dev servers are up. `E2E_TESTS=test_market_flow.py bash e2e/run.sh` runs one flow.

---

## 3. Android test APK (install on your phone)

For testing on a phone on the same Wi-Fi, talking to the dev API on this server.

1. Start the backend with `--host 0.0.0.0` (section 1).
2. Build:
   ```bash
   cd ~/stock-advisor/stock-advisor-dev/frontend
   nice -n 19 flutter build apk --release \
     --dart-define=API_BASE_URL=http://192.168.150.101:8200/api/v1 \
     -P allowCleartext=true
   ```
   Output: `build/app/outputs/flutter-apk/app-release.apk` (~57 MB, works on every phone).
   Smaller file for a modern phone: add `--split-per-abi` and install
   `app-arm64-v8a-release.apk` (about a third of the size).
3. Install: copy the APK to the phone and open it (allow "install unknown apps"), or with USB
   debugging: `adb install -r build/app/outputs/flutter-apk/app-release.apk`.

Notes
- `-P allowCleartext=true` lets this test build use plain `http://`. **Never** use it for
  Google Play builds.
- The very first build took 25+ minutes (Gradle and dependencies download); later builds take
  about 4 minutes. Gradle memory is capped at 3 GB for the shared server.
- Check what you built: `~/Android/Sdk/build-tools/35.0.0/apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk | grep SHA-1`
  should show the upload key (`d079087886abe989…`).
- Google sign-in on Android needs an *Android* OAuth client (section 4, step 6). Until then,
  use email + password in the APK.

---

## 4. Google Play release (App Bundle)

### One-time preparation
1. **Google Play Console** account (one-time $25) → *Create app* → name "Universal Stock
   Advisor", app (not game), free.
2. **Before the first public release** (Play requires these):
   - Production API over HTTPS at `https://api.universal-stock-advisor.trade` (Phase 8).
   - App icon (still Flutter's default) and store screenshots.
   - Privacy policy URL, e.g. `https://universal-stock-advisor.trade/privacy`.
   - *Data safety* form (we store email, name, investing profile, watchlist/alerts, chats).
   - *Account deletion*: in-app (Profile → Delete account) **plus** a web page/URL explaining how
     to delete the account.
   - Content: finance app with "educational information only — not financial advice".
3. **Upload key** (already created on this server, 2026-10-17):
   - Keystore: `~/keys/stock-adviser/upload-keystore.jks`, alias `upload`
   - Passwords: `frontend/android/key.properties` (gitignored)
   - **Back up both files** somewhere safe (password manager / encrypted drive). With Play App
     Signing a lost upload key can be reset by Google support, but it takes days.
   - Show its fingerprints:
     ```bash
     keytool -list -v -keystore ~/keys/stock-adviser/upload-keystore.jks -alias upload \
       -storepass "$(grep storePassword ~/stock-advisor/stock-advisor-dev/frontend/android/key.properties | cut -d= -f2)" \
       | grep -E "SHA1|SHA256"
     ```
     (SHA-1 today: `D0:79:08:78:86:AB:E9:89:F8:CB:DD:11:DD:79:C1:C0:48:18:85:C4`)

### Each release
4. **Bump the version** in `frontend/pubspec.yaml` — `version: 1.0.0+1` means name `1.0.0`,
   build number `1`. The build number (after `+`) must increase with every upload:
   `1.0.0+2`, `1.0.1+3`, …
5. **Build the bundle:**
   ```bash
   cd ~/stock-advisor/stock-advisor-dev/frontend
   nice -n 19 flutter build appbundle --release \
     --dart-define=API_BASE_URL=https://api.universal-stock-advisor.trade/api/v1 \
     --dart-define=GOOGLE_WEB_CLIENT_ID=501047197481-o8mpb5ijn6ih0r3739amn1imvlb68sik.apps.googleusercontent.com
   ```
   Output: `build/app/outputs/bundle/release/app-release.aab` (signed with the upload key).
   Check the signature: `jarsigner -verify -verbose:summary build/app/outputs/bundle/release/app-release.aab | tail -3`
6. **Upload** in Play Console → *Testing → Internal testing* → *Create release* → upload the
   `.aab` → add testers → roll out. Accept **Play App Signing** on the first upload.
7. **Google sign-in on Android** (once): Google Cloud Console → Credentials → *Create OAuth
   client ID → Android*, package `com.universalstockadvisor.stock_adviser`, with:
   - the **upload key SHA-1** (above) — for APKs you build yourself, and
   - the **app signing key SHA-1** from Play Console → *Setup → App signing* — for installs
     from Google Play.
   Then add that Android client id to `GOOGLE_CLIENT_IDS` in `backend/.env` (JSON list).

---

## 5. One-time server setup (already done here — for a new machine)

```bash
cd ~/stock-advisor/stock-advisor-dev
bash infra/mysql/create_dev_db.sh                       # databases + restricted MySQL user
cd backend && virtualenv .venv && .venv/bin/pip install -e ".[dev]"
cp .env.example .env                                    # then fill in secrets
.venv/bin/alembic upgrade head && .venv/bin/python -m app.market_data.seed
cd .. && sudo bash infra/ollama/install.sh              # AI model service (CPU-only, limited)
```

---

## 6. Docker + SearXNG (web search for the copilot) — done 2026-10-17

**Step 1 — install Docker** (asks for your sudo password):
```bash
cd ~/stock-advisor/stock-advisor-dev
sudo ADD_USER=evo bash infra/docker/install.sh
```
What it does: Docker Engine + Compose from Docker's official repository; container ports bind to
`127.0.0.1` by default; container networks use `172.30.0.0/16` (no clash with the LAN or
WireGuard); logs capped; at the end it checks that Apache and MySQL ports are still listening.
`ADD_USER=evo` lets your account run `docker` without sudo (the docker group is effectively
root — leave it out if you prefer typing `sudo docker …`). **Log out and back in** (or reconnect
VS Code) afterwards for the group to apply.

**Step 2 — start SearXNG:**
```bash
cd ~/stock-advisor/stock-advisor-dev/infra/searxng
grep -q SEARXNG_SECRET .env 2>/dev/null || echo "SEARXNG_SECRET=$(openssl rand -hex 32)" > .env
docker compose up -d
curl -s "http://127.0.0.1:8220/search?q=aramco&format=json" | head -c 300   # should print JSON
```
Stop: `docker compose down` · Logs: `docker compose logs -f` · Limits: 512 MB RAM, half a core.

---

## 7. Troubleshooting

| Symptom | Fix |
|---|---|
| App shows "This feature isn't available on the server yet" | Backend runs old code → restart it with `--reload` (section 1). |
| Google sign-in: `Error 400: origin_mismatch` | Open `http://localhost:8210`, not `127.0.0.1`. |
| Copilot: "unavailable right now" | `systemctl status ollama --no-pager`; restart with `sudo systemctl restart ollama`. |
| First copilot answer is slow (~15 s extra) | Normal: the model loads after 5 idle minutes. |
| Prices missing / "temporarily unavailable" | Free data sources are rate-limiting; cached prices return within ~1 minute. |
| Copilot says web search is unavailable | `cd infra/searxng && docker compose ps` — start with `docker compose up -d`. |
| No morning brief today | Check `job_runs` (section 1). A brief needs an onboarded user; "Get today's brief now" on Home writes one on demand. |
| Port 8200/8210 "already in use" | An old server is still running: `ss -tlnp \| grep -E ':(8200\|8210) '` then stop that process. |
