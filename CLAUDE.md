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
  backend API `8200`, Flutter web dev `8210`, SearXNG `8220`. Ollama stays on `127.0.0.1:11434`.
  Bind dev services to `127.0.0.1` only.
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
  - Default dev model: a ~4–8B tool-calling model (e.g. `qwen3:8b`, fall back to `qwen3:4b`).
    Model name comes from config (`OLLAMA_MODEL`), never hard-coded.
  - **Daily insights are precomputed in batch jobs** and stored in DB; users read cached
    results instantly. Chat is the only synchronous LLM path — stream responses.
  - Keep the `LLMProvider` interface swappable (Ollama now; bigger GPU server or hosted API
    later for Pro) without touching business logic.
- **Numbers come from data APIs, never from the model's memory.** The LLM explains and
  summarizes; prices/figures shown to users must be traceable to a data source + timestamp.
- AI answers that reference news/web content must **cite sources**.
- Web search: self-hosted **SearXNG** (free, no API key) behind the `web_search` tool.

### Market data sources (free tiers first, behind adapters)

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
- [ ] **Phase 1 — Users:** registration, login, JWT refresh, profile, onboarding quiz.
- [ ] **Phase 2 — Market data:** adapters (crypto + stocks), asset catalog, search, quotes,
      history, caching; asset detail screen with charts.
- [ ] **Phase 3 — Watchlists & live:** watchlists, subscriptions, WebSocket live prices, alerts.
- [ ] **Phase 4 — AI copilot v1:** Ollama provider, tool calling, agent loop, streaming chat,
      app-action tools, guardrails + disclaimer.
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
├── frontend/           Flutter app — web + android (lib/core, lib/features, lib/l10n, test/)
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
  migration — add a new one.

### Frontend (Flutter)
- Feature-first folders (`lib/features/<feature>/{data,domain,presentation}`); shared code in
  `lib/core/` (config, network, router, theme).
- State management: Riverpod. Routing: go_router. HTTP: dio. Charts: candlestick-capable lib
  (e.g. `fl_chart` / `syncfusion_flutter_charts` — decide in Phase 2).
- All user-facing strings via localization files (`lib/l10n/app_en.arb`); no hard-coded text.
- API base URL via `--dart-define=API_BASE_URL=...` (default `http://localhost:8200/api/v1`).
- Package id / org: `com.universalstockadvisor` (Dart package `stock_adviser`).
- `flutter analyze` must be clean.

## Environment (dev machine)
- Ubuntu 22.04, Python 3.10, Flutter 3.41 at `/opt/flutter`, MySQL 8.0 (shared with evolution).
- `python3-venv` is not installed (no passwordless sudo) — create venvs with `virtualenv`
  (`~/.local/bin/virtualenv`), not `python3 -m venv`.
- Not yet installed: Ollama (plan: native systemd install with resource limits), Docker
  (approved; for SearXNG and dev tooling).
- Note: Docker modifies iptables — publish container ports on 127.0.0.1 only and verify
  evolution's networking (Apache, WireGuard vhosts) is unaffected after install.

## Commands

```bash
# --- one-time setup ---
bash infra/mysql/create_dev_db.sh                 # DB + restricted user (uses sudo mysql; idempotent)
cd backend && virtualenv .venv && .venv/bin/pip install -e ".[dev]"

# --- backend (from backend/) ---
.venv/bin/uvicorn app.main:app --reload --host 127.0.0.1 --port 8200   # docs: /docs
.venv/bin/pytest -q
.venv/bin/ruff check . && .venv/bin/ruff format .
.venv/bin/alembic revision --autogenerate -m "describe change"        # then REVIEW the file
.venv/bin/alembic upgrade head

# --- frontend (from frontend/) ---
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8210
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
