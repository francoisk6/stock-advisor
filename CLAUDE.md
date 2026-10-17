# CLAUDE.md — Stock Adviser (future brand: Universal Stock Advisor, "USA")

Guidance for Claude Code when working in this repository.

## Product in one paragraph

An AI copilot that helps **beginner and intermediate** users follow stock markets and crypto.
Users pick the markets/assets they care about and get **daily insights**, **live charts**, and
an **AI chat assistant** that answers in plain language, fetches fresh data from external
sources, uses app features on the user's behalf ("add BTC to my watchlist", "alert me if AAPL
drops 5%") and generates reports. Freemium: everything starts free; Pro tier comes later.

**Guiding principle:** user-friendly first. Every number shown to a user should be explainable
in one plain sentence. Avoid jargon or explain it inline.

## How we work

- Long-running project, delivered in **phases, step by step**. Do not jump ahead of the current
  phase or build speculative abstractions for later phases.
- Before a non-trivial feature: short plan → agree → implement → test → update this file
  (phase checklist / decisions log) if something changed.
- `stock-advisor-dev/` is the development workspace; `../stock-advisor-prod/` is reserved for
  production deployment. Never write to prod from here unless explicitly asked.

## Shared server — the evolution project has PRIORITY

This server also runs the **evolution** project in production (`/home/evo/evolution`, served by
Apache on ports 80/8000/8008/8080/8100, shared MySQL on 3306, plus systemd bot workers:
cyberia/idm/sodetel/terranet bot workers, mailbot). Stock Adviser must never degrade it:

- **Never** stop/restart/reconfigure Apache, MySQL, or any evolution/bot service; never edit
  `/etc/apache2`, `/etc/mysql`, or anything under `/home/evo/evolution` without explicit ask.
- MySQL: use **own databases only** (`stock_advisor_dev`, later `stock_advisor_prod`) with a
  **dedicated MySQL user** granted on those DBs only. Never touch other schemas or global config.
- Ports: never use 80, 8000, 8008, 8080, 8100, 3306. Our range is **8200–8299**:
  backend API `8200`, Flutter web dev `8210`, SearXNG `8220`, e2e API/web `8290`/`8291`.
  Ollama stays on `127.0.0.1:11434`.
  Dev services bind to `127.0.0.1` by default; use `0.0.0.0` only for LAN testing (see
  "LAN access"). `0.0.0.0` also exposes them on the WireGuard interface (10.0.0.2).
- Resource limits (14 GB RAM, 8 cores, shared):
  - Ollama: `OLLAMA_MAX_LOADED_MODELS=1`, `OLLAMA_NUM_PARALLEL=1`, short `OLLAMA_KEEP_ALIVE`
    (e.g. 5m) so the model unloads when idle, limited threads (≤4), run at low priority
    (systemd `Nice=`/`CPUQuota=`/`MemoryMax=`). Prefer the smaller model by default.
  - Docker containers: explicit `mem_limit`/`cpus`; publish ports on `127.0.0.1` only.
  - Heavy batch jobs (digest generation, bulk ingestion) are rate-limited, sequential, and
    their schedule is configurable so they can run off-peak.
- Before installing system packages or creating services, say what will change and confirm.

## Tech stack

| Layer          | Choice                                                        |
|----------------|---------------------------------------------------------------|
| Web/Mobile app | Flutter (Dart) — **Web first → Android → iOS** (mobile + web is the goal) |
| Backend API    | FastAPI (Python 3.10+), Pydantic v2, async                    |
| Database       | MySQL 8 via SQLAlchemy 2.x (async, `asyncmy`/`aiomysql`)      |
| Migrations     | Alembic — every schema change goes through a migration        |
| AI runtime     | Ollama (local LLM), accessed via a provider abstraction       |
| Background jobs| APScheduler to start (daily digests, data refresh); Celery/RQ later if needed |
| Realtime       | WebSockets (FastAPI) for live prices → Flutter charts         |
| Auth           | JWT access + refresh tokens, passwords hashed with argon2/bcrypt |

## Architecture

```
Flutter app ──HTTPS/WS──▶ FastAPI
                            ├── api/        REST + WebSocket routers (thin)
                            ├── services/   business logic
                            ├── market_data/ provider adapters (stocks, crypto, news)
                            ├── ai/         LLM provider, tools, agent loop, prompts
                            ├── jobs/       scheduled tasks (ingest, digests, alerts)
                            └── db/         SQLAlchemy models, repositories
                                    │
                                  MySQL  ◀── Alembic migrations
```

### Important AI design facts

- **The LLM does not crawl the internet by itself.** The backend gives it *tools* (function
  calling): `get_quote`, `get_history`, `search_news`, `web_search`, `fetch_page`,
  `add_to_watchlist`, `create_alert`, `generate_report`, … The agent loop executes tools and
  feeds results back. Only use Ollama models that support tool calling.
- **Hardware constraint (dev machine):** 14 GB RAM, CPU-only (AMD iGPU, no CUDA). Expect
  ~5–10 tokens/s on a 7–8B Q4 model. Therefore:
  - Model: **`qwen3:4b-instruct`** (config `OLLAMA_MODEL`). Measured 2026-10-17 on this CPU:
    ~11 tokens/s, tool calls in 3–5 s, plain explanations ~13 s, model load ~15 s after 5 idle
    minutes; 6/6 correct tool choices. Do **not** use `qwen3:4b`: that tag is the
    always-thinking edition (30–130 s per answer, reasoning leaks into the reply).
  - **Daily insights are precomputed in batch jobs** and stored in DB; users read cached
    results instantly. Chat is the only synchronous LLM path — stream responses.
  - Keep the `LLMProvider` interface swappable (Ollama now; bigger GPU server or hosted API
    later for Pro) without touching business logic.
- **Numbers come from data APIs, never from the model's memory.** The LLM explains and
  summarizes; prices/figures shown to users must be traceable to a data source + timestamp.
- AI answers that reference news/web content must **cite sources**.
- Web search: self-hosted **SearXNG** (free, no API key) behind the `web_search` tool.

### Market data sources (free tiers first, behind adapters)

Implemented (Phase 2) in `backend/app/market_data/`:
- `providers/yahoo.py` (yfinance) for stocks, ETFs, indices, forex, commodities;
  `providers/coingecko.py` (keyless) for crypto. Both implement `providers/base.py`.
  **yfinance is unofficial and Yahoo's terms forbid commercial use — replace with a licensed
  provider (Twelve Data / Finnhub / …) before Pro launches.**
- Keyless CoinGecko: ≤365 days of history → crypto offers 1D–1Y only; calls are spaced 1.5 s.
  Search keeps only ranked coins (drops "tokenized stock" junk).
- `assets` table = catalog. `catalog.json` is the curated list (`popularity` set), loaded by
  `python -m app.market_data.seed` (idempotent; run after migrations on every environment).
  Provider search hits are upserted with `popularity = NULL`.
- No prices in the DB yet: `TTLCache` in `service.py` (quotes 60 s, history 2 min–1 h, search
  10 min), one fetch per key at a time, last good value served for 6 h if a source fails.
  Persisted daily bars come with the Phase 5 ingest jobs.
- Yahoo calls are blocking → `asyncio.to_thread` behind a semaphore of 2 (shared server).
- CoinGecko keyless is the tightest limit: after a 429 the provider stops calling for ~60 s
  (cooldown) and stale cache is served; a coin's market data from any batch call answers its
  detail page for 60 s; details fall back to the last known price instead of a 503.

### AI copilot (Phase 4)
- `app/ai/`: `provider.py` (LLMProvider protocol) · `ollama.py` (streaming `/api/chat` + tools)
  · `tools.py` (registry: lookups + app actions returning UI cards; errors go back to the model)
  · `prompts.py` (system prompt from the user's profile + rules) · `agent.py` (≤5 tool rounds,
  one request at a time with a queue position message).
- Transport: the existing WebSocket (`chat.send` / `chat.cancel` → `chat` events), because
  Flutter web's HTTP client can't stream responses. `app/services/copilot.py` is
  transport-independent (checks, daily limit, storage).
- Stored: user questions and final answers + action cards (`chat_messages`), not tool traffic.
  Daily limit counts answered questions (`ai_messages_per_day`); failed answers don't count.
- Tests use `ScriptedLLM` (tests/test_copilot.py) — never the real model in unit tests.
  `e2e/test_copilot_flow.py` uses the real model (needs Ollama running; slow).
- Asset names in tools resolve: exact symbol → **curated catalog** → provider search (Yahoo's
  ranking put "Saudi Aramco Base Oil" above Aramco). Curated names use what people call
  companies, e.g. "Saudi Aramco (Saudi Arabian Oil Company)", "Alphabet (Google)".
- Prompt rules live in `app/ai/prompts.py`; period questions must use `get_price_history`.

### Live updates & background jobs (Phase 3)
- `app/realtime/hub.py`: one WebSocket per open app at `/api/v1/ws` (protocol in the module
  docstring): first message authenticates, then `subscribe` to asset ids; server pushes changed
  quotes (`LIVE_PRICE_SECONDS`, provider TTL 15 s Yahoo / 30 s CoinGecko) and notifications.
- `app/jobs/runner.py`: in-process loops started in the FastAPI lifespan — alert check every
  `ALERT_CHECK_SECONDS` (60) and live price push. **Requires a single API worker**; move to a
  separate worker process (and a shared pub/sub) before scaling out. `BACKGROUND_JOBS=false`
  in tests (they call `run_alert_check()` directly).
- Alerts (`app/services/alerts.py`): price_above/below fire once then switch off; move_up/down
  at most once per UTC day. In-app notification always; email only to confirmed addresses.

Markets are **global and driven by user interest** — no hard-coded exchange list. The asset
catalog stores exchange, country, currency, and asset type; adapters are chosen per asset.
Handle multiple currencies, exchange time zones, and trading hours/holidays (crypto is 24/7).

- Crypto: CoinGecko (free API), Binance public REST/WebSocket for live ticks.
- Stocks: yfinance (unofficial, dev/prototype only), Finnhub / Alpha Vantage / Twelve Data free
  tiers. Respect rate limits; cache aggressively (DB + in-memory TTL).
- News: provider news endpoints + RSS feeds.
- Every adapter implements a common interface so providers can be swapped per license/cost.

## Compliance & safety (non-negotiable)

- Show a clear **"educational information, not financial advice"** disclaimer in onboarding,
  AI chat, and reports. The AI must not promise returns or give guaranteed buy/sell calls;
  it frames insights as information, risks, and scenarios, adapted to the user's risk profile.
- Never log passwords, tokens, or API keys. Secrets only via `.env` (never committed);
  maintain `.env.example`.
- Check data-provider terms before redistributing data to end users, especially for Pro.
- Paid subscriptions inside mobile apps must use App Store / Google Play billing for digital
  goods; Stripe for web. Design the `subscription` model to be provider-agnostic.

## Feature scope

### Core (requested)
- Registration, login, profile, password reset.
- Subscribe to markets / sectors / individual stocks & crypto → daily updates.
- Live charts (line + candlestick, ranges 1D/1W/1M/1Y/5Y).
- AI copilot chat: understands prompts, uses app actions, gathers external data, produces
  reports and insights.
- Free tier now, Pro tier later.

### Proposed additions (beginner-friendly)
- **Onboarding quiz** → experience level + risk profile + interests; personalizes tone and
  insights.
- **Watchlists & price alerts** (threshold, % move, AI "unusual activity") with push
  notifications.
- **Daily digest**: "Your 2-minute morning brief" — what moved, why, what to watch today.
- **"Explain this" everywhere**: tap any metric (P/E, market cap, RSI, volatility) for a
  plain-language explanation; built-in glossary.
- **"Why did it move?"**: AI explanation of a price move linked to news, with sources.
- **Paper trading / virtual portfolio**: practice without real money; track performance.
- **Portfolio tracker** (manual holdings entry) with allocation & risk overview.
- **Learning hub**: short lessons/quizzes tied to assets the user follows.
- **Sentiment snapshot** per asset (news tone summarized by AI).
- **Comparison tool**: "Compare TSLA vs RIVN" side by side, explained.
- i18n from day one (including RTL support), light/dark theme.

### Free vs Pro (draft — to refine)
| Free                                   | Pro                                              |
|----------------------------------------|--------------------------------------------------|
| Limited watchlist size (e.g. 10 assets)| Unlimited watchlists                             |
| Daily digest                           | Intraday digests + custom report scheduling      |
| Limited AI chat messages / day         | Higher/unlimited AI usage, deeper reports (PDF)  |
| Basic alerts                           | Advanced/AI alerts, technical indicators         |
| Delayed data where providers require   | Faster data (if licensed), ad-free               |

## Roadmap (phases)

- [x] **Phase 0 — Foundation:** monorepo layout, git, FastAPI skeleton, MySQL + Alembic,
      config/.env, Flutter skeleton (routing, state mgmt, theming, i18n), health check, lint/test
      tooling.
- [x] **Phase 1 — Users:** email+password and Google sign-in, JWT access + rotating refresh
      tokens, email verification, password reset/change, profile, 5-step onboarding quiz,
      account deletion, Free plan on signup. Verified: unit + browser e2e, Gmail SMTP, real
      Google sign-in by the owner (2026-10-14).
- [x] **Phase 2 — Market data:** Yahoo (stocks/ETFs/indices/forex/commodities) + CoinGecko
      (crypto) adapters, curated catalog (78 assets, all regions), search, quotes, details, history
      (1D–5Y), shared cache with stale fallback; home "Popular in your markets", search screen,
      asset page with line/candle charts and explained key figures. Verified unit + live e2e.
- [x] **Phase 3 — Watchlists & live:** watchlist (☆ on asset page, Home section), price alerts
      (above/below one-shot, daily move once/day) delivered in-app + email (confirmed emails
      only), notifications inbox + bell badge, WebSocket for live prices + instant alert
      pop-ups, Free-plan limits enforced. Verified unit + live e2e. Push notifications: Android phase.
- [x] **Phase 4 — AI copilot v1:** Ollama (qwen3:4b-instruct, CPU) with tool calling, agent
      loop, streamed chat over the WebSocket, app actions with undo cards, past chats, daily
      limit, guardrails + disclaimer. Verified: unit (scripted model) + live e2e (real model).
- [ ] **Phase 5 — Daily insights:** news ingestion, SearXNG web search, batch digest
      generation, push notifications, "why did it move?".
- [ ] **Phase 6 — Learning & practice:** glossary, explain-this, paper trading, portfolio.
- [ ] **Phase 7 — Monetization:** plans, quotas, Stripe + in-app purchases, Pro features.
- [ ] **Phase 8 — Launch:** production deploy, domain (universal-stock-advisor), monitoring,
      store releases.

## Repository layout

```
stock-advisor-dev/
├── CLAUDE.md
├── backend/            FastAPI app (app/, alembic/, tests/, pyproject.toml, .env)
│   └── app/            api/v1/ (routers) · core/ (config) · db/ (base, session, models/) · services/
│                       · market_data/ (providers/, cache, catalog.json, seed, service)
├── frontend/           Flutter app — web + android (lib/core, lib/features, lib/l10n, test/)
├── e2e/                Playwright browser flows (run.sh starts backend + web build, cleans up)
├── infra/              mysql/ setup script; later docker-compose (SearXNG), Ollama service
└── docs/               ADRs / decision log, API notes
```

## Conventions

### Backend (Python)
- Type hints everywhere; Pydantic schemas for all request/response bodies.
- Routers stay thin → services → repositories. No SQL in routers.
- Async all the way (DB, HTTP via `httpx.AsyncClient`).
- Format/lint with `ruff`; tests with `pytest` + `pytest-asyncio`.
- Money/prices: use `Decimal` / MySQL `DECIMAL`, never float for stored financial values.
  Store timestamps in UTC.
- Alembic: autogenerate, then **review** every migration before applying; never edit an applied
  migration — add a new one. Check `upgrade → downgrade base → upgrade` by hand on the dev DB
  (tests only upgrade). Autogenerated downgrades must drop **tables**, not FK-backing indexes
  (MySQL refuses).
- MySQL column defaults that are expressions need parentheses: use `UTC_NOW_DEFAULT` from
  `app.db.base`. `app.core.time.utcnow()` returns naive UTC truncated to seconds (= DATETIME).
- Enumerated values are stored as `VARCHAR` and validated by Pydantic enums (`app/schemas/`),
  not MySQL `ENUM` (easier migrations).
- User-facing errors: raise `AppError` subclasses (`app/core/errors.py`) with a plain-language
  message; the frontend shows `detail` as-is.
- Auth: access JWT (15 min) + opaque refresh token stored hashed, rotated on each use; reuse
  after a 10 s grace revokes the whole family. Email tokens are single-use and hashed.
  Login errors never reveal whether an email exists. Rate limits are in-memory (one worker).
- Emails: `EMAIL_BACKEND=outbox` (dev) writes `.eml` files to `backend/var/outbox/`;
  `smtp` sends; `memory` is used by tests. Dev sends real mail via Gmail (`SMTP_SSL=true`,
  port 465 — same as evolution's `EMAIL_USE_SSL=True`); `e2e/run.sh` forces the outbox.
  Gmail app passwords must be pasted without spaces.
  Never turn on smtplib debug output — it prints the AUTH credentials.
- Tests run against `stock_advisor_test` (forced in `tests/conftest.py`); rows are cleared with
  `DELETE`, never `TRUNCATE` (DDL is slow on the shared server). The catalog is seeded once per
  session. Market tests use `tests/fakes.py` providers — never call real APIs in unit tests.

### Frontend (Flutter)
- Feature-first folders (`lib/features/<feature>/{data,domain,presentation}`); shared code in
  `lib/core/` (config, network, router, theme).
- State management: Riverpod. Routing: go_router. HTTP: dio. Charts: candlestick-capable lib
  (e.g. `fl_chart` / `syncfusion_flutter_charts` — decide in Phase 2).
- All user-facing strings via localization files (`lib/l10n/app_en.arb`); no hard-coded text.
- API base URL via `--dart-define=API_BASE_URL=...` (default `http://localhost:8200/api/v1`).
- Package id / org: `com.universalstockadvisor` (Dart package `stock_adviser`).
- `flutter analyze` must be clean; run `dart format lib test`.
- Auth flow: `AuthController` (Riverpod Notifier) is the single source of truth; go_router
  redirects from it (`authRedirect` in `core/router/app_router.dart`, unit-tested). `dioProvider`
  adds the bearer token and refreshes once on 401 (queued); `publicDioProvider` is unauthenticated.
- Web uses path URLs (`usePathUrlStrategy`) so email links like `/verify-email?token=` work;
  production hosting must fall back to `index.html` for unknown paths.
- Google button: `google_sign_in_button.dart` conditionally exports the web version (Google's
  rendered button) or the mobile version — never import `google_sign_in_web` elsewhere.
- Up/down prices: always arrow + sign + color (`PriceChange`, `changeColor`) — never color only.
  Currencies: `$ € £ ¥ ₹` symbols, otherwise the code ("SAR 25.78") via `core/format/numbers.dart`.
- Every key figure needs a plain-language explanation (`statText` in `market/presentation/labels.dart`).
- Section titles use `Semantics(header: true, container: true)` — without `container` Flutter
  merges the heading with the text next to it. Decorative avatars use `ExcludeSemantics`.
- Live prices: wrap screens in `LiveInterest(name, assetIds)` and read prices with
  `liveQuote(ref, asset)`; `LiveController` owns the socket (reconnect + token refresh).
- Messages: `showSnack(messenger, text)` replaces the current SnackBar (no queueing).
- Copilot: `CopilotController` (kept alive across screens) sends via
  `LiveController.sendChat`; answers render with `RichAnswer` (bullets, **bold**, headings).

## Environment (dev machine)
- Ubuntu 22.04, Python 3.10, Flutter 3.41 at `/opt/flutter`, MySQL 8.0 (shared with evolution).
- `python3-venv` is not installed (no passwordless sudo) — create venvs with `virtualenv`
  (`~/.local/bin/virtualenv`), not `python3 -m venv`.
- Ollama v0.35.1 installed 2026-10-17 via `sudo bash infra/ollama/install.sh` (CPU-only, no GPU
  add-ons, systemd limits: Nice 10, ≤4 cores, MemoryMax 6G; models in /usr/share/ollama,
  writable via ReadWritePaths). Manage models via the local API (`/api/pull`, `/api/delete`),
  no sudo needed. Not yet installed: Docker (approved; for SearXNG).
- Note: Docker modifies iptables — publish container ports on 127.0.0.1 only and verify
  evolution's networking (Apache, WireGuard vhosts) is unaffected after install.

## Google Sign-In setup

Status: web client id is in `backend/.env`; origins `http://localhost` + `http://localhost:8210`
are allowed and the button renders (verified 2026-10-14).

1. Google Cloud Console → create project → *OAuth consent screen* (External, app name
   "Stock Adviser", support email).
2. *Credentials → Create OAuth client ID → Web application*. Authorized JavaScript origins:
   `http://localhost` **and** `http://localhost:8210` (dev), later the production domain.
   Dev is opened via VS Code port forwarding of 8210 + 8200. **Open `http://localhost:8210`,
   not `127.0.0.1:8210`** (VS Code's "Open in Browser" uses 127.0.0.1) — otherwise Google
   answers `Error 400: origin_mismatch`.
3. Later for Android: another OAuth client of type *Android* with package
   `com.universalstockadvisor.stock_adviser` and the signing key's SHA-1.
4. Backend `.env`: `GOOGLE_CLIENT_IDS=["<web-client-id>"]` (add the Android id later).
   Frontend: `--dart-define=GOOGLE_WEB_CLIENT_ID=<web-client-id>`. Without it the Google button
   is hidden and everything else works.

## LAN access (open the dev app by IP, e.g. http://192.168.150.101:8210)

- Start both servers with `--host 0.0.0.0` / `--web-hostname 0.0.0.0` (commands below).
- Web builds without `API_BASE_URL` call port 8200 on the host the page came from.
- Backend accepts LAN origins via `CORS_ORIGIN_REGEX` in `.env` (dev only).
- Plain `http://IP` is not a browser "secure context": tokens fall back from secure storage to
  normal browser storage (`TokenStore`), and the Google button is hidden (Google rejects IP
  origins). Email links still use `FRONTEND_URL` (localhost).

## Commands

```bash
# --- one-time setup ---
bash infra/mysql/create_dev_db.sh                 # DB + restricted user (uses sudo mysql; idempotent)
cd backend && virtualenv .venv && .venv/bin/pip install -e ".[dev]"

# --- backend (from backend/) ---
.venv/bin/uvicorn app.main:app --reload --host 127.0.0.1 --port 8200   # docs: /docs
.venv/bin/uvicorn app.main:app --reload --host 0.0.0.0 --port 8200     # + LAN access
.venv/bin/pytest -q
.venv/bin/ruff check . && .venv/bin/ruff format .
.venv/bin/alembic revision --autogenerate -m "describe change"        # then REVIEW the file
.venv/bin/alembic upgrade head
.venv/bin/python -m app.market_data.seed                               # after migrations

# --- frontend (from frontend/) ---
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8210 \
  --dart-define=GOOGLE_WEB_CLIENT_ID=<id>   # optional; same id as GOOGLE_CLIENT_IDS
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8210 \
  --dart-define=GOOGLE_WEB_CLIENT_ID=<id>   # + LAN access (Google only via localhost)
flutter build web --dart-define=GOOGLE_WEB_CLIENT_ID=<id>

# --- end-to-end (from repo root; own ports 8290/8291, safe while dev servers run) ---
bash e2e/run.sh            # SKIP_BUILD=1 reuses the build; E2E_TESTS=test_market_flow.py
                           # (backend runs with ALERT_CHECK_SECONDS=3 for the alerts flow)
# e2e text checks: use helpers.wait_for_text — Flutter merges neighbouring texts into one label;
# while the mouse hovers a button its tooltip text is appended to the button's name.
flutter analyze && flutter test
nice -n 19 flutter build web        # low priority: shared server
```

## Decisions log
- 2026-10-13 — Stack fixed: Flutter / FastAPI / MySQL / Alembic / Ollama. Batch-precomputed
  insights due to CPU-only inference. Free-first data providers behind adapters.
- 2026-10-13 — All proposed features accepted. Platforms: Web → Android → iOS. Markets: global,
  user-interest driven. Docker approved. Evolution production project on same server has
  priority (see "Shared server").
- 2026-10-13 — Launch fully free; quota/plan system built early (Phase 1 data model) but limits
  set generously; Pro activated in Phase 7.
- 2026-10-13 — Phase 1: sign-in methods = email+password and Google. Email verification is not
  required to use the app (reminder banner instead). Account deletion in-app (store policy).
  Signing in with Google onto an unverified password account drops that password
  (anti account-pre-hijacking). Seeded Free limits: 25 watchlist assets, 30 AI msgs/day,
  10 alerts, 1 digest/day.
- 2026-10-14 — Phase 2: Yahoo (yfinance) for non-crypto in dev despite ToS (swap before Pro);
  CoinGecko keyless for crypto (1Y max history). Prices cached in memory, not stored yet.
  Market endpoints require sign-in (protects free API quotas).
- 2026-10-15 — Phase 3: alerts in-app + email now; phone push with Firebase in the Android
  phase. Background jobs run inside the API process (single worker) for now.
- 2026-10-17 — Phase 4: copilot on qwen3:4b-instruct (non-thinking) for speed on CPU; chat
  streamed over the existing WebSocket; app actions run immediately with undo cards; web and
  news search deferred to Phase 5.
