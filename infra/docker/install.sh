#!/usr/bin/env bash
# Installs Docker Engine + Compose plugin (official apt repo) configured for this shared server.
#
# Evolution has priority, so:
#   - published container ports bind to 127.0.0.1 unless a compose file says otherwise
#   - container networks use 172.30.0.0/16 (no clash with the LAN 192.168.x or WireGuard 10.0.0.x)
#   - container logs are capped (10 MB x 3 per container)
#   - after install it checks that Apache and the WireGuard interface are untouched
# Idempotent.
#
# Usage:  sudo bash infra/docker/install.sh                 # docker needs sudo afterwards
#         sudo ADD_USER=evo bash infra/docker/install.sh    # also let 'evo' run docker
#           (the docker group is effectively root; only for a trusted dev account)
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Please run with sudo."; exit 1; }
say() { printf '\n>>> %s\n' "$*"; }

say "Before: listening services (for comparison)"
before="$(ss -tln | awk 'NR>1 {print $4}' | sort -u | tr '\n' ' ')"
echo "$before"

say "Adding Docker's apt repository"
apt-get update -qq
apt-get install -y -qq ca-certificates curl >/dev/null
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" >/etc/apt/sources.list.d/docker.list
apt-get update -qq

say "Writing /etc/docker/daemon.json"
install -m 0755 -d /etc/docker
cat >/etc/docker/daemon.json <<'JSON'
{
  "ip": "127.0.0.1",
  "default-address-pools": [{ "base": "172.30.0.0/16", "size": 24 }],
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
JSON

say "Installing Docker Engine and the Compose plugin"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  docker-ce docker-ce-cli containerd.io docker-compose-plugin >/dev/null
systemctl enable --now docker
systemctl restart docker  # pick up daemon.json if Docker was already installed

if [[ -n "${ADD_USER:-}" ]]; then
  say "Adding $ADD_USER to the docker group (log out and in again to use it)"
  usermod -aG docker "$ADD_USER"
fi

say "Checks"
docker --version
docker compose version
docker run --rm hello-world >/dev/null && echo "hello-world container: OK"
echo "Docker bridge: $(ip -brief addr show docker0 | awk '{print $3}')"
echo "WireGuard:     $(ip -brief addr show wg0 2>/dev/null | awk '{print $2, $3}' || echo 'n/a')"
for port in 80 8000 8008 8080 8100 3306; do
  ss -tln | grep -q ":$port " && echo "port $port still listening: OK" || echo "port $port NOT listening!"
done
curl -s -o /dev/null -w "Apache on :80 answers HTTP %{http_code}\n" http://127.0.0.1/ || true
