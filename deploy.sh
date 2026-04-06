#!/bin/bash
#
# Unified Deployment Script for VPS
# Usage: ./deploy.sh [project-name|all] [--skip-build] [--logs]
#
# Examples:
#   ./deploy.sh naisu-one              # Deploy only naisu-one
#   ./deploy.sh all                    # Deploy all projects
#   ./deploy.sh naisu-one --logs       # Deploy and show logs
#   ./deploy.sh all --skip-build       # Deploy without rebuilding
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() { echo -e "${BLUE}[DEPLOY]${NC} $1"; }
ok()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $1"; }
error(){ echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_DIR="$SCRIPT_DIR/projects"
SKIP_BUILD=false
SHOW_LOGS=false
PROJECT=""

# Parse arguments
for arg in "$@"; do
  case $arg in
    --skip-build)
      SKIP_BUILD=true
      shift
      ;;
    --logs)
      SHOW_LOGS=true
      shift
      ;;
    -*)
      error "Unknown option: $arg"
      exit 1
      ;;
    *)
      if [ -z "$PROJECT" ]; then
        PROJECT="$arg"
      fi
      shift
      ;;
  esac
done

# Validate project argument
if [ -z "$PROJECT" ]; then
  error "Usage: $0 [project-name|all] [--skip-build] [--logs]"
  echo ""
  echo "Available projects:"
  ls -1 "$PROJECTS_DIR" 2>/dev/null | grep -v "^template$" || echo "  (none found)"
  exit 1
fi

# Function to deploy a single project
deploy_project() {
  local project_name="$1"
  local project_dir="$PROJECTS_DIR/$project_name"
  
  if [ ! -d "$project_dir" ]; then
    error "Project '$project_name' not found at $project_dir"
    return 1
  fi
  
  if [ ! -f "$project_dir/docker-compose.yml" ]; then
    warn "No docker-compose.yml found for $project_name, skipping..."
    return 0
  fi
  
  log "Deploying $project_name..."
  cd "$project_dir"
  
  if [ "$SKIP_BUILD" = false ]; then
    log "Building $project_name..."
    docker compose build --no-cache
  fi
  
  log "Starting $project_name..."
  docker compose up -d --remove-orphans
  
  # Wait for health check
  log "Waiting for health check..."
  sleep 5
  
  # Check if containers are healthy
  local failed=0
  for container in $(docker compose ps -q 2>/dev/null); do
    local name=$(docker inspect --format='{{.Name}}' "$container" | sed 's/\///')
    local status=$(docker inspect --format='{{.State.Status}}' "$container")
    local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "N/A")
    
    if [ "$status" != "running" ]; then
      error "Container $name is not running (status: $status)"
      failed=1
    else
      ok "Container $name is running (health: $health)"
    fi
  done
  
  if [ "$SHOW_LOGS" = true ]; then
    log "Showing logs for $project_name (Ctrl+C to exit)..."
    docker compose logs -f
  fi
  
  return $failed
}

# Main deployment logic
main() {
  log "Starting deployment..."
  
  # Check if Docker is installed
  if ! command -v docker &>/dev/null; then
    error "Docker is not installed. Please run ./scripts/setup-vps.sh first."
    exit 1
  fi
  
  if [ "$PROJECT" = "all" ]; then
    log "Deploying all projects..."
    
    for project_dir in "$PROJECTS_DIR"/*; do
      if [ -d "$project_dir" ]; then
        project_name=$(basename "$project_dir")
        # Skip template directory
        if [ "$project_name" = "template" ]; then
          continue
        fi
        deploy_project "$project_name"
        echo ""
      fi
    done
    
    ok "All projects deployed!"
  else
    deploy_project "$PROJECT"
  fi
  
  log "Deployment complete!"
  echo ""
  echo "Useful commands:"
  echo "  View all containers: docker ps"
  echo "  View project logs:   docker compose -f $PROJECTS_DIR/<project>/docker-compose.yml logs -f"
  echo "  Restart project:     docker compose -f $PROJECTS_DIR/<project>/docker-compose.yml restart"
  echo "  Caddy reload:        sudo systemctl reload caddy"
}

main
