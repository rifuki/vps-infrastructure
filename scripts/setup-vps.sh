#!/bin/bash
#
# VPS Setup Script
# Run this on fresh Ubuntu 24.04 VPS
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[SETUP]${NC} $1"; }
ok()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $1"; }
error(){ echo -e "${RED}[ERROR]${NC} $1"; }

if [ "$EUID" -ne 0 ]; then
  error "Please run as root or with sudo"
  exit 1
fi

log "=== VPS Infrastructure Setup ==="
echo ""

# 1. Update system
log "Updating system packages..."
apt-get update && apt-get upgrade -y
ok "System updated"

# 2. Install essential packages
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

# 3. Install Docker
if ! command -v docker &>/dev/null; then
  log "Installing Docker..."
  curl -fsSL https://get.docker.com | bash
  
  # Add current user to docker group
  usermod -aG docker ${SUDO_USER:-$USER}
  
  # Start Docker
  systemctl enable docker
  systemctl start docker
  ok "Docker installed"
else
  ok "Docker already installed ($(docker --version))"
fi

# 4. Install Docker Compose plugin
if ! docker compose version &>/dev/null; then
  log "Installing Docker Compose..."
  apt-get install -y docker-compose-plugin
  ok "Docker Compose installed"
else
  ok "Docker Compose already installed"
fi

# 5. Install Caddy
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

# 6. Setup Caddy configuration
log "Setting up Caddy configuration..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

mkdir -p /etc/caddy/conf.d

# Backup existing Caddyfile
if [ -f /etc/caddy/Caddyfile ]; then
  cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup.$(date +%Y%m%d_%H%M%S)
fi

# Copy new configuration
if [ -d "$REPO_DIR/caddy-configs" ]; then
  cp "$REPO_DIR/caddy-configs/Caddyfile" /etc/caddy/Caddyfile
  cp "$REPO_DIR/caddy-configs"/*.caddy /etc/caddy/conf.d/ 2>/dev/null || true
  systemctl reload caddy
  ok "Caddy configured"
else
  warn "Caddy configs not found in repo. Skipping Caddy setup."
fi

# 7. Setup projects directory
log "Setting up projects directory..."
mkdir -p /home/${SUDO_USER:-$USER}/projects
chown ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} /home/${SUDO_USER:-$USER}/projects

# Copy projects from repo if exists
if [ -d "$REPO_DIR/projects" ]; then
  cp -r "$REPO_DIR/projects"/* /home/${SUDO_USER:-$USER}/projects/ 2>/dev/null || true
  chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} /home/${SUDO_USER:-$USER}/projects
  ok "Projects directory setup"
fi

# 8. Spin up infrastructure (Dockge, etc.)
log "Starting infrastructure services..."
mkdir -p /opt/stacks

if [ -f "$REPO_DIR/infrastructure/docker-compose.yml" ]; then
  docker compose -f "$REPO_DIR/infrastructure/docker-compose.yml" up -d
  ok "Infrastructure services started (Dockge at dockge.rifuki.dev)"
else
  warn "infrastructure/docker-compose.yml not found, skipping."
fi

# 9. Create deploy script symlink
if [ -f "$REPO_DIR/deploy.sh" ]; then
  ln -sf "$REPO_DIR/deploy.sh" /usr/local/bin/vps-deploy
  chmod +x "$REPO_DIR/deploy.sh"
  ok "Deploy script linked to /usr/local/bin/vps-deploy"
fi

# 10. Setup firewall (optional)
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

echo ""
ok "=== VPS Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Logout and login again (for Docker group)"
echo "  2. Test Docker: docker ps"
echo "  3. Test Caddy: sudo systemctl status caddy"
echo "  4. Deploy project: vps-deploy <project-name>"
echo ""
echo "Available commands:"
echo "  vps-deploy <project>     - Deploy a project"
echo "  vps-deploy all           - Deploy all projects"
echo "  docker ps                - List containers"
echo "  sudo systemctl reload caddy  - Reload Caddy"
echo ""
echo "Infrastructure:"
echo "  Dockge UI: https://dockge.rifuki.dev"
echo ""
