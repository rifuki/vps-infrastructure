#!/bin/bash
#
# New Project Script
# Usage: ./scripts/new-project.sh <project-name> <port> <domain> <binary-name>
#
# Examples:
#   ./scripts/new-project.sh my-api 9001 api.my-app.dev my-api
#   ./scripts/new-project.sh notes 9002 notes.rifuki.dev notes-server
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${BLUE}[NEW-PROJECT]${NC} $1"; }
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error(){ echo -e "${RED}[ERROR]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE_DIR="$REPO_DIR/projects/template"
PROJECTS_DIR="$REPO_DIR/projects"
CADDY_DIR="$REPO_DIR/caddy-configs"

PROJECT_NAME="$1"
PORT="$2"
DOMAIN="$3"
BINARY_NAME="$4"

# Validate arguments
if [ -z "$PROJECT_NAME" ] || [ -z "$PORT" ] || [ -z "$DOMAIN" ] || [ -z "$BINARY_NAME" ]; then
  error "Usage: $0 <project-name> <port> <domain> <binary-name>"
  echo ""
  echo "Example:"
  echo "  $0 my-api 9001 api.my-app.dev my-api"
  echo ""
  echo "Currently used ports:"
  grep -h "127.0.0.1:" "$PROJECTS_DIR"/*/docker-compose.yml 2>/dev/null | \
    grep -oP '127\.0\.0\.1:\K[0-9]+' | sort -n | \
    sed 's/^/  /' || echo "  (none found)"
  exit 1
fi

# Check port is numeric
if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
  error "Port must be a number, got: $PORT"
  exit 1
fi

# Check project doesn't already exist
if [ -d "$PROJECTS_DIR/$PROJECT_NAME" ]; then
  error "Project '$PROJECT_NAME' already exists at $PROJECTS_DIR/$PROJECT_NAME"
  exit 1
fi

# Check port not already in use
EXISTING_PORT=$(grep -rh "127.0.0.1:$PORT:" "$PROJECTS_DIR"/*/docker-compose.yml 2>/dev/null | head -1)
if [ -n "$EXISTING_PORT" ]; then
  error "Port $PORT is already in use by another project"
  echo ""
  echo "Currently used ports:"
  grep -h "127.0.0.1:" "$PROJECTS_DIR"/*/docker-compose.yml 2>/dev/null | \
    grep -oP '127\.0\.0\.1:\K[0-9]+' | sort -n | sed 's/^/  /'
  exit 1
fi

log "Creating project '$PROJECT_NAME'..."
log "  Port:        $PORT"
log "  Domain:      $DOMAIN"
log "  Binary name: $BINARY_NAME"
echo ""

# Copy template
PROJECT_DIR="$PROJECTS_DIR/$PROJECT_NAME"
cp -r "$TEMPLATE_DIR" "$PROJECT_DIR"

# Replace placeholders in all files
find "$PROJECT_DIR" -type f | while read -r file; do
  sed -i.bak \
    -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
    -e "s/{{PORT}}/$PORT/g" \
    -e "s/{{BINARY_NAME}}/$BINARY_NAME/g" \
    "$file" && rm -f "${file}.bak"
done

ok "Project files created at $PROJECT_DIR"

# Create Caddy config
CADDY_FILE="$CADDY_DIR/$PROJECT_NAME.caddy"
cat > "$CADDY_FILE" <<EOF
$DOMAIN {
	reverse_proxy localhost:$PORT
	encode gzip
}
EOF

ok "Caddy config created at $CADDY_FILE"

# Auto-create DNS record kalau CF_API_TOKEN tersedia
if [ -z "$CF_API_TOKEN" ] && [ -f /etc/vps-infra.env ]; then
  source /etc/vps-infra.env
fi

if [ -n "$CF_API_TOKEN" ]; then
  log "Creating DNS record for $DOMAIN..."
  bash "$SCRIPT_DIR/dns.sh" "$DOMAIN" && echo "" || warn "DNS setup gagal, lakukan manual."
else
  warn "CF_API_TOKEN tidak ditemukan, skip DNS setup."
  echo "  Jalankan manual: ./scripts/dns.sh $DOMAIN"
fi

echo ""
ok "=== Project '$PROJECT_NAME' created! ==="
echo ""
echo "Next steps:"
echo "  1. Copy your source code into: $PROJECT_DIR"
echo "  2. Setup environment: cp $PROJECT_DIR/.env.example $PROJECT_DIR/.env && vim $PROJECT_DIR/.env"
echo "  3. Deploy: ./deploy.sh $PROJECT_NAME"
echo "  4. Reload Caddy: sudo systemctl reload caddy"
echo ""
echo "Live at: https://$DOMAIN"
