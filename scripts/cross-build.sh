#!/bin/bash
#
# Cross-Compilation Script (Mac → Linux VPS)
# Build Rust projects on Mac for deployment to Linux VPS
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[BUILD]${NC} $1"; }
ok()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $1"; }
error(){ echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
PROJECTS_DIR="$REPO_DIR/projects"
BUILD_DIR="$REPO_DIR/builds"
VPS_USER="${VPS_USER:-rifuki}"
VPS_HOST="${VPS_HOST:-}"

# Get project name
PROJECT="$1"

if [ -z "$PROJECT" ]; then
  error "Usage: $0 <project-name> [vps-host]"
  echo ""
  echo "Available projects:"
  ls -1 "$PROJECTS_DIR" 2>/dev/null | grep -v "^template$" || echo "  (none found)"
  exit 1
fi

if [ -z "$VPS_HOST" ] && [ -n "$2" ]; then
  VPS_HOST="$2"
fi

if [ -z "$VPS_HOST" ]; then
  error "VPS_HOST not set. Either:"
  echo "  1. Set VPS_HOST environment variable"
  echo "  2. Pass as second argument: $0 $PROJECT user@vps-ip"
  exit 1
fi

PROJECT_DIR="$PROJECTS_DIR/$PROJECT"

if [ ! -d "$PROJECT_DIR" ]; then
  error "Project '$PROJECT' not found at $PROJECT_DIR"
  exit 1
fi

# Create build directory
mkdir -p "$BUILD_DIR"

log "=== Cross-Building $PROJECT ==="
echo "Target: Linux x86_64"
echo "VPS: $VPS_USER@$VPS_HOST"
echo ""

# Check if Rust project
if [ -f "$PROJECT_DIR/Cargo.toml" ]; then
  log "Detected Rust project"
  
  # Check if Cargo.lock exists
  if [ ! -f "$PROJECT_DIR/Cargo.lock" ]; then
    warn "Cargo.lock not found. Run 'cargo generate-lockfile' first."
    exit 1
  fi
  
  # Method 1: Using Docker (Recommended)
  log "Building with Docker cross-compilation..."
  
  cd "$PROJECT_DIR"
  
  # Create temporary build container
  docker run --rm \
    -v "$(pwd):/app" \
    -w /app \
    rust:1.88-slim-bookworm \
    bash -c "
      apt-get update && apt-get install -y pkg-config libssl-dev
      cargo build --release
    "
  
  # Get binary name from Cargo.toml
  BINARY_NAME=$(grep '^name' Cargo.toml | head -1 | cut -d'"' -f2)
  
  if [ ! -f "target/release/$BINARY_NAME" ]; then
    error "Build failed. Binary not found: target/release/$BINARY_NAME"
    exit 1
  fi
  
  # Copy binary to build dir
  cp "target/release/$BINARY_NAME" "$BUILD_DIR/${PROJECT}-${BINARY_NAME}"
  ok "Built: $BUILD_DIR/${PROJECT}-${BINARY_NAME}"
  
  # Deploy
  log "Deploying to VPS..."
  scp "$BUILD_DIR/${PROJECT}-${BINARY_NAME}" "$VPS_USER@$VPS_HOST:~/apps/$PROJECT/"
  
  # Restart service
  ssh "$VPS_USER@$VPS_HOST" "cd ~/projects/$PROJECT && docker compose restart" || {
    warn "Could not restart service. You may need to restart manually."
  }
  
  ok "Deployed successfully!"

# Check if Node.js project
elif [ -f "$PROJECT_DIR/package.json" ]; then
  log "Detected Node.js project"
  
  cd "$PROJECT_DIR"
  
  # Build Docker image for Linux
  log "Building Docker image for Linux..."
  docker buildx build \
    --platform linux/amd64 \
    -t "$PROJECT:latest" \
    --load \
    . 2>&1
  
  # Save image
  log "Exporting Docker image..."
  docker save "$PROJECT:latest" | gzip > "$BUILD_DIR/${PROJECT}.tar.gz"
  
  ok "Built: $BUILD_DIR/${PROJECT}.tar.gz"
  
  # Deploy
  log "Deploying to VPS..."
  scp "$BUILD_DIR/${PROJECT}.tar.gz" "$VPS_USER@$VPS_HOST:~/"
  
  # Load and run on VPS
  ssh "$VPS_USER@$VPS_HOST" "
    cd ~/projects/$PROJECT
    docker load < ~/${PROJECT}.tar.gz
    docker compose up -d
    rm ~/${PROJECT}.tar.gz
  "
  
  ok "Deployed successfully!"

else
  error "Unknown project type. Expected Cargo.toml (Rust) or package.json (Node.js)"
  exit 1
fi

echo ""
ok "=== Build & Deploy Complete ==="
echo ""
echo "Test with:"
echo "  curl http://localhost:<port>/health"
echo "  curl https://<domain>/health"
