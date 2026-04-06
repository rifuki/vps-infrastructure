#!/bin/bash
#
# VPS Setup Script
# Run this on fresh Ubuntu 24.04 VPS
#
# Usage:
#   sudo ./scripts/setup-vps.sh                          # interactive
#   sudo CF_API_TOKEN=xxx ./scripts/setup-vps.sh         # env var
#   sudo ./scripts/setup-vps.sh --cf-token=xxx           # cli flag
#   sudo ./scripts/setup-vps.sh --skip-dns               # skip DNS setup
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log()   { echo -e "${BLUE}[SETUP]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
ask()   { echo -e "${BOLD}$1${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")

if [ "$EUID" -ne 0 ]; then
  error "Please run as root or with sudo"
  exit 1
fi

# ── Parse CLI flags ───────────────────────────────────────────────────────────
SKIP_DNS=false
CF_TOKEN_FLAG=""

for arg in "$@"; do
  case $arg in
    --cf-token=*)
      CF_TOKEN_FLAG="${arg#*=}"
      ;;
    --skip-dns)
      SKIP_DNS=true
      ;;
    --help|-h)
      echo "Usage: sudo $0 [options]"
      echo ""
      echo "Options:"
      echo "  --cf-token=TOKEN   Cloudflare API token (DNS automation)"
      echo "  --skip-dns         Skip DNS setup"
      echo ""
      echo "Alternatively via env var:"
      echo "  sudo CF_API_TOKEN=TOKEN $0"
      exit 0
      ;;
  esac
done

echo ""
echo -e "${BOLD}================================================${NC}"
echo -e "${BOLD}       VPS Infrastructure Setup                 ${NC}"
echo -e "${BOLD}================================================${NC}"
echo ""

# ── Resolve CF_API_TOKEN: flag → env → file → interactive ────────────────────
if [ "$SKIP_DNS" = false ]; then
  # 1. CLI flag
  if [ -n "$CF_TOKEN_FLAG" ]; then
    CF_API_TOKEN="$CF_TOKEN_FLAG"
    log "Using Cloudflare token from --cf-token flag"

  # 2. Env var (sudah di-set sebelum script dijalankan)
  elif [ -n "$CF_API_TOKEN" ]; then
    log "Using Cloudflare token from environment variable"

  # 3. File yang sudah ada
  elif [ -f /etc/vps-infra.env ]; then
    source /etc/vps-infra.env
    [ -n "$CF_API_TOKEN" ] && log "Using Cloudflare token from /etc/vps-infra.env"

  elif [ -f "$REAL_HOME/.vps-infra.env" ]; then
    source "$REAL_HOME/.vps-infra.env"
    [ -n "$CF_API_TOKEN" ] && log "Using Cloudflare token from ~/.vps-infra.env"
  fi

  # 4. Interactive prompt (fallback)
  if [ -z "$CF_API_TOKEN" ]; then
    ask "Cloudflare API Token untuk auto DNS setup:"
    ask "  (kosongkan untuk skip, atau gunakan --skip-dns)"
    read -rsp "  CF_API_TOKEN: " CF_API_TOKEN
    echo ""
  fi

  # Validasi dan simpan token
  if [ -n "$CF_API_TOKEN" ]; then
    log "Validating Cloudflare token..."
    CF_CHECK=$(curl -sf "https://api.cloudflare.com/client/v4/user/tokens/verify" \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      -H "Content-Type: application/json" || echo '{"success":false}')
    CF_VALID=$(echo "$CF_CHECK" | grep -o '"success":[^,}]*' | cut -d: -f2 | tr -d ' ')

    if [ "$CF_VALID" = "true" ]; then
      ok "Cloudflare token valid"
      echo "CF_API_TOKEN=$CF_API_TOKEN" > /etc/vps-infra.env
      chmod 600 /etc/vps-infra.env
      echo "CF_API_TOKEN=$CF_API_TOKEN" > "$REAL_HOME/.vps-infra.env"
      chmod 600 "$REAL_HOME/.vps-infra.env"
      chown "$REAL_USER:$REAL_USER" "$REAL_HOME/.vps-infra.env"
      ok "Token saved"
    else
      warn "Token tidak valid, skip DNS automation."
      CF_API_TOKEN=""
    fi
  else
    warn "Skip Cloudflare setup. Jalankan manual: ./scripts/dns.sh <domain>"
  fi
fi

echo ""

# ── 1. Update system ─────────────────────────────────────────────────────────
log "Updating system packages..."
apt-get update && apt-get upgrade -y
ok "System updated"

# ── 2. Install essential packages ────────────────────────────────────────────
log "Installing essential packages..."
apt-get install -y \
  curl \
  wget \
  git \
  vim \
  htop \
  net-tools \
  apt-transport-https \
  ca-certificates \
  gnupg \
  lsb-release \
  software-properties-common
ok "Essential packages installed"

# ── 3. Install Docker ─────────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
  log "Installing Docker..."
  curl -fsSL https://get.docker.com | bash
  systemctl enable docker
  systemctl start docker
  ok "Docker installed"
else
  ok "Docker already installed ($(docker --version))"
fi

# Tambahkan user ke docker group (berlaku di session berikutnya)
if ! groups "$REAL_USER" | grep -q docker; then
  usermod -aG docker "$REAL_USER"
  ok "User '$REAL_USER' ditambahkan ke docker group"
  # Aktifkan langsung untuk sesi ini tanpa re-login
  # (hanya berlaku untuk proses yang dijalankan via script ini)
  export DOCKER_GROUP_ADDED=true
else
  ok "User '$REAL_USER' sudah di docker group"
fi

# ── 4. Install Docker Compose plugin ─────────────────────────────────────────
if ! docker compose version &>/dev/null; then
  log "Installing Docker Compose..."
  apt-get install -y docker-compose-plugin
  ok "Docker Compose installed"
else
  ok "Docker Compose already installed"
fi

# ── 5. Install Caddy ──────────────────────────────────────────────────────────
if ! command -v caddy &>/dev/null; then
  log "Installing Caddy..."
  apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
  apt-get update
  apt-get install -y caddy
  systemctl enable caddy
  ok "Caddy installed"
else
  ok "Caddy already installed ($(caddy version))"
fi

# ── 6. Setup Caddy configuration ─────────────────────────────────────────────
log "Setting up Caddy configuration..."
mkdir -p /etc/caddy/conf.d

if [ -f /etc/caddy/Caddyfile ]; then
  cp /etc/caddy/Caddyfile "/etc/caddy/Caddyfile.backup.$(date +%Y%m%d_%H%M%S)"
fi

if [ -d "$REPO_DIR/caddy-configs" ]; then
  cp "$REPO_DIR/caddy-configs/Caddyfile" /etc/caddy/Caddyfile
  cp "$REPO_DIR/caddy-configs"/*.caddy /etc/caddy/conf.d/ 2>/dev/null || true
  systemctl reload caddy
  ok "Caddy configured"
else
  warn "Caddy configs not found in repo. Skipping Caddy setup."
fi

# ── 7. Setup projects directory ───────────────────────────────────────────────
log "Setting up projects directory..."
mkdir -p "$REAL_HOME/projects"
chown "$REAL_USER:$REAL_USER" "$REAL_HOME/projects"

if [ -d "$REPO_DIR/projects" ]; then
  cp -r "$REPO_DIR/projects"/* "$REAL_HOME/projects/" 2>/dev/null || true
  chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/projects"
  ok "Projects directory setup"
fi

# ── 8. Spin up infrastructure (Dockge, etc.) ──────────────────────────────────
log "Starting infrastructure services..."
mkdir -p /opt/stacks

if [ -f "$REPO_DIR/infrastructure/docker-compose.yml" ]; then
  docker compose -f "$REPO_DIR/infrastructure/docker-compose.yml" up -d
  ok "Infrastructure services started"

  if [ -n "$CF_API_TOKEN" ]; then
    log "Setting up DNS for dockge.rifuki.dev..."
    sudo -u "$REAL_USER" bash "$SCRIPT_DIR/dns.sh" "dockge.rifuki.dev" \
      || warn "DNS setup untuk dockge gagal, jalankan manual: ./scripts/dns.sh dockge.rifuki.dev"
  else
    warn "Skip DNS setup. Jalankan manual: ./scripts/dns.sh dockge.rifuki.dev"
  fi
else
  warn "infrastructure/docker-compose.yml not found, skipping."
fi

# ── 9. Create deploy script symlink ───────────────────────────────────────────
if [ -f "$REPO_DIR/deploy.sh" ]; then
  ln -sf "$REPO_DIR/deploy.sh" /usr/local/bin/vps-deploy
  chmod +x "$REPO_DIR/deploy.sh"
  ok "Deploy script linked to /usr/local/bin/vps-deploy"
fi

# ── 10. Setup firewall ────────────────────────────────────────────────────────
log "Configuring firewall..."
if command -v ufw &>/dev/null; then
  ufw allow 22/tcp
  ufw allow 80/tcp
  ufw allow 443/tcp
  ufw --force enable
  ok "Firewall configured"
else
  warn "UFW not installed, skipping firewall setup"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
ok "=== VPS Setup Complete ==="
echo ""
if [ "$DOCKER_GROUP_ADDED" = "true" ]; then
  echo -e "${YELLOW}PENTING:${NC} Jalankan perintah ini agar docker group langsung aktif:"
  echo -e "  ${BOLD}newgrp docker${NC}"
  echo ""
fi
echo "Next steps:"
echo "  1. Jalankan: newgrp docker  (aktifkan docker group tanpa re-login)"
echo "  2. Test Docker: docker ps"
echo "  3. Test Caddy: sudo systemctl status caddy"
echo "  4. Deploy project: vps-deploy <project-name>"
echo ""
echo "Available commands:"
echo "  vps-deploy <project>         - Deploy a project"
echo "  vps-deploy all               - Deploy all projects"
echo "  ./scripts/new-project.sh     - Scaffold project baru"
echo "  ./scripts/dns.sh <domain>    - Setup DNS record"
echo "  sudo systemctl reload caddy  - Reload Caddy"
echo ""
echo "Infrastructure:"
echo "  Dockge UI: https://dockge.rifuki.dev"
echo ""
