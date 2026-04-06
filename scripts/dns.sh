#!/bin/bash
#
# Cloudflare DNS Script
# Auto-create/update A record untuk subdomain ke IP VPS
#
# Usage:
#   ./scripts/dns.sh <subdomain.domain.tld> [ip]
#   ./scripts/dns.sh dockge.rifuki.dev
#   ./scripts/dns.sh api.naisu.one 1.2.3.4
#
# Requires: CF_API_TOKEN (dari /etc/vps-infra.env atau env var)
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${BLUE}[DNS]${NC} $1"; }
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error(){ echo -e "${RED}[ERROR]${NC} $1"; }

# Load token — cek home dir dulu, fallback ke /etc
if [ -z "$CF_API_TOKEN" ]; then
  [ -f "$HOME/.vps-infra.env" ] && source "$HOME/.vps-infra.env"
fi
if [ -z "$CF_API_TOKEN" ]; then
  [ -r /etc/vps-infra.env ] && source /etc/vps-infra.env
fi

if [ -z "$CF_API_TOKEN" ]; then
  error "CF_API_TOKEN tidak ditemukan."
  echo "  Set via: export CF_API_TOKEN=your_token"
  echo "  Atau simpan di: /etc/vps-infra.env"
  exit 1
fi

FQDN="$1"
CUSTOM_IP="$2"

if [ -z "$FQDN" ]; then
  error "Usage: $0 <subdomain.domain.tld> [ip]"
  echo "  Contoh: $0 dockge.rifuki.dev"
  exit 1
fi

# Auto-detect IP VPS kalau tidak di-provide
if [ -n "$CUSTOM_IP" ]; then
  VPS_IP="$CUSTOM_IP"
else
  log "Detecting public IP..."
  VPS_IP=$(curl -sf https://api.ipify.org || curl -sf https://ifconfig.me)
  if [ -z "$VPS_IP" ]; then
    error "Tidak bisa detect public IP. Pass manual: $0 $FQDN <ip>"
    exit 1
  fi
fi

# Extract root domain dari FQDN
# dockge.rifuki.dev → rifuki.dev
# api.naisu.one → naisu.one
ROOT_DOMAIN=$(echo "$FQDN" | awk -F. '{print $(NF-1)"."$NF}')

log "FQDN:        $FQDN"
log "Root domain: $ROOT_DOMAIN"
log "Target IP:   $VPS_IP"

# Lookup Zone ID dari Cloudflare
log "Looking up Zone ID untuk $ROOT_DOMAIN..."
ZONE_RESPONSE=$(curl -sf "https://api.cloudflare.com/client/v4/zones?name=$ROOT_DOMAIN" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json")

ZONE_ID=$(echo "$ZONE_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$ZONE_ID" ]; then
  error "Zone tidak ditemukan untuk domain: $ROOT_DOMAIN"
  echo "Pastikan domain ini ada di Cloudflare account kamu."
  exit 1
fi

ok "Zone ID: $ZONE_ID"

# Cek apakah record sudah ada
EXISTING=$(curl -sf "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$FQDN" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json")

RECORD_ID=$(echo "$EXISTING" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -n "$RECORD_ID" ]; then
  # Update record yang sudah ada
  log "Record sudah ada, updating..."
  RESULT=$(curl -sf -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"A\",\"name\":\"$FQDN\",\"content\":\"$VPS_IP\",\"ttl\":1,\"proxied\":false}")
else
  # Buat record baru
  log "Membuat DNS record baru..."
  RESULT=$(curl -sf -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"A\",\"name\":\"$FQDN\",\"content\":\"$VPS_IP\",\"ttl\":1,\"proxied\":false}")
fi

SUCCESS=$(echo "$RESULT" | grep -o '"success":[^,}]*' | cut -d: -f2 | tr -d ' ')

if [ "$SUCCESS" = "true" ]; then
  ok "$FQDN → $VPS_IP (DNS record set)"
else
  error "Gagal set DNS record"
  echo "$RESULT"
  exit 1
fi
