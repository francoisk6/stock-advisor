#!/usr/bin/env bash
# Installs Ollama as a CPU-only, low-priority, resource-limited systemd service.
#
# Shared server: the evolution project has priority. Differences from the official installer:
#   - pinned version, no GPU add-ons (the AMD iGPU here isn't supported; NVIDIA libs removed)
#   - listens on 127.0.0.1 only; one model, one request at a time; unloads after 5 min idle
#   - systemd limits: low CPU/IO priority, at most 4 cores, memory capped
# Idempotent: re-running upgrades/repairs the install and restarts the service.
#
# Usage:  sudo bash infra/ollama/install.sh
#         sudo OLLAMA_ARCHIVE=/path/to/ollama-linux-amd64.tar.zst bash infra/ollama/install.sh
set -euo pipefail

OLLAMA_VERSION="${OLLAMA_VERSION:-0.35.1}"
MODEL="${OLLAMA_MODEL:-qwen3:4b-instruct}"
PREFIX=/usr/local
UNIT=/etc/systemd/system/ollama.service

[[ $EUID -eq 0 ]] || { echo "Please run with sudo."; exit 1; }
say() { printf '\n>>> %s\n' "$*"; }

# 1. Binary -------------------------------------------------------------------------------
archive="${OLLAMA_ARCHIVE:-}"
tmp=""
if [[ -z "$archive" ]]; then
  tmp="$(mktemp -d)"
  trap '[[ -n "$tmp" ]] && rm -rf "$tmp"' EXIT
  archive="$tmp/ollama.tar.zst"
  say "Downloading Ollama $OLLAMA_VERSION (rate-limited to spare the shared connection)"
  nice -n 19 curl -fL --retry 3 --limit-rate 10M -o "$archive" \
    "https://ollama.com/download/ollama-linux-amd64.tar.zst?version=${OLLAMA_VERSION}"
fi

if systemctl is-active --quiet ollama 2>/dev/null; then
  say "Stopping running Ollama service for the upgrade"
  systemctl stop ollama
fi

say "Installing to $PREFIX (bin/ollama, lib/ollama)"
rm -rf "$PREFIX/lib/ollama"
nice -n 19 tar --use-compress-program=unzstd -xf "$archive" -C "$PREFIX"
# No NVIDIA GPU on this server: drop the CUDA runtimes (~1 GB).
find "$PREFIX/lib/ollama" -maxdepth 1 -type d -name 'cuda_*' -exec rm -rf {} +
"$PREFIX/bin/ollama" --version || true

# 2. Service user (no render/video groups: CPU only) --------------------------------------
if ! id ollama >/dev/null 2>&1; then
  say "Creating system user 'ollama' (home /usr/share/ollama holds the models)"
  useradd -r -s /bin/false -U -m -d /usr/share/ollama ollama
fi

# 3. systemd unit with limits --------------------------------------------------------------
say "Writing $UNIT"
cat >"$UNIT" <<'EOF'
[Unit]
Description=Ollama (Stock Adviser; CPU-only, low priority, shared server)
After=network-online.target

[Service]
ExecStart=/usr/local/bin/ollama serve
User=ollama
Group=ollama
Restart=on-failure
RestartSec=5

# Local only; one model and one request at a time; free memory after 5 idle minutes.
Environment=OLLAMA_HOST=127.0.0.1:11434
Environment=OLLAMA_MAX_LOADED_MODELS=1
Environment=OLLAMA_NUM_PARALLEL=1
Environment=OLLAMA_MAX_QUEUE=8
Environment=OLLAMA_KEEP_ALIVE=5m
Environment=OLLAMA_CONTEXT_LENGTH=8192

# The evolution project has priority: low CPU/IO priority, max 4 cores, capped memory.
Nice=10
CPUWeight=20
CPUQuota=400%
IOWeight=20
MemoryHigh=5G
MemoryMax=6G

# Hardening. ProtectSystem=full makes /usr read-only, but the models live in the service
# user's home under /usr/share, so that one directory stays writable.
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=full
ProtectHome=yes
ReadWritePaths=/usr/share/ollama

[Install]
WantedBy=multi-user.target
EOF

say "Starting the service"
systemctl daemon-reload
systemctl enable --now ollama

for _ in $(seq 1 30); do
  curl -sf http://127.0.0.1:11434/api/version >/dev/null && break
  sleep 1
done
curl -sf http://127.0.0.1:11434/api/version || {
  echo "Ollama did not start. Last log lines:"
  journalctl -u ollama -n 15 --no-pager
  systemctl stop ollama  # don't leave it restarting in a loop
  exit 1
}

# 4. Model ---------------------------------------------------------------------------------
say "Downloading model $MODEL (a few GB, one-time)"
OLLAMA_HOST=127.0.0.1:11434 nice -n 19 "$PREFIX/bin/ollama" pull "$MODEL"

say "Done. Service status:"
systemctl --no-pager --lines=0 status ollama || true
echo
echo "Listening:  $(ss -tlnp 2>/dev/null | grep ':11434 ' | awk '{print $4}')"
echo "Models:     $(OLLAMA_HOST=127.0.0.1:11434 "$PREFIX/bin/ollama" list | tail -n +2 | awk '{print $1, $3 $4}' | paste -sd ',')"
