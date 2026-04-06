# server

VPS infrastructure — Traefik + Portainer.

## Setup

```bash
curl -fsSL https://raw.githubusercontent.com/rifuki/server/main/setup.sh | bash
```

## Services

| Service   | URL                              |
|-----------|----------------------------------|
| Traefik   | `http://localhost:8081` (SSH tunnel) |
| Portainer | `https://portainer.rifuki.dev`   |

## Structure

```
server/
├── docker-compose.yml   # Traefik + Portainer
├── traefik.yml          # Traefik static config
└── setup.sh             # One-command bootstrap
```

## Deploy project baru

```bash
# 1. DNS: tambah A record → IP VPS
# 2. VPS: clone project dan setup .env
git clone https://github.com/rifuki/<project> ~/apps/<project>
cd ~/apps/<project>
cp <service>/.env.example <service>/.env && nano <service>/.env
docker compose up -d
```
