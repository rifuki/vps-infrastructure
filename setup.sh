#!/bin/bash
#
# Setup server dari nol
# Usage: curl -fsSL https://raw.githubusercontent.com/rifuki/server/main/setup.sh | bash
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log()   { echo -e "${BLUE}[server]${NC} $1"; }
ok()    { echo -e "${GREEN}[ok]${NC} $1"; }
error() { echo -e "${RED}[error]${NC} $1"; exit 1; }

REPO="https://github.com/rifuki/server.git"
INSTALL_DIR="$HOME/server"

# ── 1. Install Docker ────────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
    log "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER"
    ok "Docker installed"
else
    ok "Docker already installed ($(docker --version | cut -d' ' -f3 | tr -d ','))"
fi

# ── 2. Clone repo ────────────────────────────────────────────────────────────
if [ -d "$INSTALL_DIR" ]; then
    log "Updating existing repo..."
    git -C "$INSTALL_DIR" pull
else
    log "Cloning rifuki/server..."
    git clone "$REPO" "$INSTALL_DIR"
fi
ok "Repo ready at $INSTALL_DIR"

# ── 3. Start Traefik + Portainer ─────────────────────────────────────────────
log "Starting Traefik + Portainer..."
cd "$INSTALL_DIR"

# Aktifkan docker group tanpa logout (kalau baru install)
if ! docker info &>/dev/null 2>&1; then
    sg docker -c "docker compose up -d"
else
    docker compose up -d
fi

ok "Traefik + Portainer running"

# ── 4. Summary ───────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN} Setup complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Traefik dashboard : http://localhost:8081 (via SSH tunnel)"
echo "  Portainer         : https://portainer.rifuki.dev"
echo ""
echo "Next steps:"
echo "  1. Pastikan DNS *.rifuki.dev sudah pointing ke IP VPS ini"
echo "  2. Buka https://portainer.rifuki.dev dan buat admin account"
echo "  3. Deploy project: cd ~/apps/<project> && docker compose up -d"
echo ""
