#!/usr/bin/env bash
# One-command installer for neko-browser.
#   bash setup.sh                 -> HTTP on port 8080
#   bash setup.sh my.domain.com   -> HTTPS via Caddy (ports 80/443)
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"
DOMAIN_ARG="${1:-}"

SUDO=""
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi

log() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }

# 1. Docker ------------------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  log "Installing Docker..."
  curl -fsSL https://get.docker.com | $SUDO sh
  if [ -n "$SUDO" ]; then $SUDO usermod -aG docker "$USER" || true; fi
fi

DOCKER="docker"
if ! docker info >/dev/null 2>&1; then
  DOCKER="$SUDO docker"
fi
if ! $DOCKER compose version >/dev/null 2>&1; then
  echo "Docker Compose plugin not found. Install docker-compose-plugin and retry." >&2
  exit 1
fi

# 2. .env --------------------------------------------------------------------
set_env() { # key value
  local key="$1" val="$2"
  if grep -q "^${key}=" .env; then
    sed -i "s|^${key}=.*|${key}=${val}|" .env
  else
    printf '%s=%s\n' "$key" "$val" >> .env
  fi
}
get_env() { grep -E "^$1=" .env | tail -n1 | cut -d= -f2- || true; }
randpw() { LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 12 || true; }

if [ ! -f .env ]; then
  log "Creating .env..."
  cp .env.example .env
  IP="$(curl -fsS --max-time 5 https://api.ipify.org || curl -fsS --max-time 5 https://ifconfig.me || true)"
  set_env PUBLIC_IP "$IP"
  set_env USER_PASSWORD "$(randpw)"
  set_env ADMIN_PASSWORD "$(randpw)"
fi

# 3. Domain ------------------------------------------------------------------
if [ -n "$DOMAIN_ARG" ]; then
  set_env DOMAIN "$DOMAIN_ARG"
fi
DOMAIN="$(get_env DOMAIN)"

# 4. Firewall ----------------------------------------------------------------
log "Opening firewall ports..."
TCP_PORTS="8080 52000 80 443"
UDP_PORTS="52000"

if command -v ufw >/dev/null 2>&1 && $SUDO ufw status 2>/dev/null | grep -q "Status: active"; then
  for p in $TCP_PORTS; do $SUDO ufw allow "$p/tcp" >/dev/null; done
  for p in $UDP_PORTS; do $SUDO ufw allow "$p/udp" >/dev/null; done
fi

if command -v iptables >/dev/null 2>&1; then
  add_rule() { # proto port
    if ! $SUDO iptables -C INPUT -p "$1" -m state --state NEW -m "$1" --dport "$2" -j ACCEPT 2>/dev/null; then
      # -I inserts at the top so it wins over Oracle Cloud's default REJECT rule
      $SUDO iptables -I INPUT -p "$1" -m state --state NEW -m "$1" --dport "$2" -j ACCEPT
    fi
  }
  for p in $TCP_PORTS; do add_rule tcp "$p"; done
  for p in $UDP_PORTS; do add_rule udp "$p"; done
  if command -v netfilter-persistent >/dev/null 2>&1; then
    $SUDO netfilter-persistent save >/dev/null 2>&1 || true
  fi
fi

# 5. Start -------------------------------------------------------------------
if [ -n "$DOMAIN" ]; then
  log "Starting neko + caddy (HTTPS for $DOMAIN)..."
  $DOCKER compose --profile https up -d
  URL="https://$DOMAIN"
else
  log "Starting neko..."
  $DOCKER compose up -d
  URL="http://$(get_env PUBLIC_IP):8080"
fi

# 6. Summary -----------------------------------------------------------------
cat <<MSG

  neko-browser is running!

  URL:            $URL
  User password:  $(get_env USER_PASSWORD)
  Admin password: $(get_env ADMIN_PASSWORD)

  IMPORTANT: also open these ports in your cloud provider's firewall
  (Oracle Cloud security list, AWS security group, GCP firewall, ...):
    TCP 8080, 52000, 80, 443   and   UDP 52000

MSG
