# VPS Infrastructure

Modular, scalable VPS infrastructure with **Caddy reverse proxy on host** and hybrid deployment (Docker + Native).

## 🏗️ Architecture

```
Internet
    ↓
Caddy (Host:80/443) ← Auto SSL + Reverse Proxy
    ↓
┌──────────┬──────────┐
│  Docker  │  Native  │
│ Projects │ Projects │
│:4040     │:8080     │
└──────────┴──────────┘
```

**Why Caddy on Host?**
- ✅ Simple & reliable (systemd)
- ✅ Low resource usage
- ✅ Easy debugging
- ✅ Works with both Docker & native projects

## 🚀 Quick Start

### Setup New VPS

```bash
# 1. Clone repo
git clone https://github.com/rifuki/vps-infrastructure.git
cd vps-infrastructure

# 2. Setup VPS (installs Docker & Caddy)
sudo ./scripts/setup-vps.sh

# 3. Deploy project
./deploy.sh portfolio-terminal
# or
vps-deploy portfolio-terminal
```

## 📁 Repository Structure

```
vps-infrastructure/
├── README.md                 # This file
├── deploy.sh                 # Main deployment script
├── infrastructure/
│   └── docker-compose.yml   # Infra tools (Dockge, etc.)
├── scripts/
│   ├── setup-vps.sh         # VPS initialization (includes infra)
│   ├── new-project.sh       # Scaffold new project from template
│   └── cross-build.sh       # Mac → VPS build helper
├── projects/                 # Project deployment configs
│   ├── template/            # Template for new projects
│   ├── portfolio-terminal/  # Docker-based
│   ├── naisu-one/           # Docker-based  
│   └── simpasar/            # Docker-based
├── caddy-configs/           # Caddy reverse proxy
│   ├── Caddyfile           # Main config
│   └── *.caddy             # Per-project configs
└── apps/                    # (On VPS) Source code
```

## 🛠️ Infrastructure Tools

Disetup otomatis saat `setup-vps.sh` dijalankan.

| Tool | URL | Fungsi |
|------|-----|--------|
| Dockge | https://dockge.rifuki.dev | Manage docker-compose stacks via UI |

> Dockge membutuhkan akun saat pertama kali dibuka di browser.

---

## 🔄 Project Types

### Type 1: Docker Project (Recommended)

**Structure:**
```yaml
# projects/myapp/docker-compose.yml
services:
  app:
    build: .
    ports:
      - "127.0.0.1:9000:9000"  # Bind to localhost only
    restart: unless-stopped
```

**Caddy Config:**
```caddy
# caddy-configs/myapp.caddy
myapp.rifuki.dev {
    reverse_proxy localhost:9000
    encode gzip
}
```

**Deploy:**
```bash
vps-deploy myapp
```

### Type 2: Native Project (For existing apps)

**Example: Aksara (already running on port 8080)**

**Caddy Config:**
```caddy
# caddy-configs/aksara.caddy
api.aksara.rifuki.dev {
    reverse_proxy localhost:8080
    encode gzip
}
```

**Reload Caddy:**
```bash
sudo systemctl reload caddy
```

**No Docker needed!** Caddy routes to `localhost:8080`

## 🛠️ Setup New Project

### Option A: Docker-based (Recommended for new projects)

```bash
# 1. Scaffold from template (auto-creates project + Caddy config)
./scripts/new-project.sh my-new-project 9001 my-new-project.rifuki.dev my-binary

# 2. Copy your source code into projects/my-new-project/
# 3. Setup env
cp projects/my-new-project/.env.example projects/my-new-project/.env
vim projects/my-new-project/.env

# 4. Deploy
vps-deploy my-new-project

# 5. Reload Caddy & commit
sudo systemctl reload caddy
git add . && git commit -m "Add my-new-project" && git push
```

### Option B: Native (For existing projects)

```bash
# 1. Just create Caddy config
cat > caddy-configs/existing-app.caddy << 'EOF'
existing-app.rifuki.dev {
    reverse_proxy localhost:8080
    encode gzip
}
EOF

# 2. Reload Caddy
sudo systemctl reload caddy

# 3. Done! Your native app (port 8080) now has SSL
```

## 📊 Port Allocation

| Project | Type | Port | Domain | Status |
|---------|------|------|--------|--------|
| portfolio-terminal | Docker | 4040 | terminal.rifuki.dev | ✅ |
| naisu-one backend | Docker | 3939 | api.naisu.one | ⏳ |
| naisu-one agent | Docker | 8787 | agent.naisu.one | ⏳ |
| aksara | Native | 8080 | api.aksara.rifuki.dev | ✅ |
| simpasar | Docker | 3001 | api.simpasar.rifuki.dev | ⏳ |

**New projects:** Use ports 9000+

## 🍎 Cross-Compilation (Mac → VPS)

### Prerequisites (Mac)
```bash
# Install Rust target
rustup target add x86_64-unknown-linux-gnu

# Install linker
brew install x86_64-linux-gnu-gcc
```

### Build & Deploy Script
```bash
# scripts/cross-build.sh <project> <vps-host>
./scripts/cross-build.sh naisu-one rifuki@your-vps-ip
```

**What it does:**
1. Build on Mac for Linux (x86_64)
2. Transfer binary to VPS
3. Deploy with Docker

## 🔧 Manual Setup (Without Scripts)

### 1. Install Docker
```bash
curl -fsSL https://get.docker.com | bash
sudo usermod -aG docker $USER
```

### 2. Install Caddy
```bash
sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt-get update && sudo apt-get install -y caddy
```

### 3. Configure Caddy
```bash
sudo mkdir -p /etc/caddy/conf.d
sudo cp caddy-configs/Caddyfile /etc/caddy/Caddyfile
sudo cp caddy-configs/*.caddy /etc/caddy/conf.d/
sudo systemctl reload caddy
```

### 4. Deploy Docker Project
```bash
cd projects/your-project
docker compose up -d
```

## 📝 Environment Variables

Create `.env` in each project directory (auto-loaded by docker-compose):

```bash
# projects/naisu-one/.env
DATABASE_URL=sqlite:///app/data/db.sqlite
BACKEND_PORT=3939
AGENT_PORT=8787
```

## 🔍 Troubleshooting

### Check service status
```bash
# Docker containers
docker ps

# Project logs
docker compose -f projects/<name>/docker-compose.yml logs

# Caddy status
sudo systemctl status caddy
sudo journalctl -u caddy -f

# Test endpoint
curl http://localhost:<port>/health
curl https://<domain>/health
```

### Port already in use
```bash
# Find process
sudo lsof -i :<port>

# Change port in:
# 1. projects/<name>/docker-compose.yml
# 2. caddy-configs/<name>.caddy
# 3. Reload: sudo systemctl reload caddy
```

### SSL issues
```bash
# Force certificate renewal
sudo rm -rf /var/lib/caddy/.local/share/caddy/certificates
sudo systemctl restart caddy
```

## 📦 Backup & Restore

### Backup
```bash
tar -czf vps-backup-$(date +%Y%m%d).tar.gz \
  caddy-configs/ \
  projects/*/docker-compose.yml \
  projects/*/.env
```

### Restore
```bash
tar -xzf vps-backup-*.tar.gz
sudo ./scripts/setup-vps.sh
```

## 🤝 Contributing

1. Add project to `projects/`
2. Create Caddy config in `caddy-configs/`
3. Update port allocation table
4. Test on VPS
5. Commit & push

## 📄 License

MIT - Free to use and modify

## 🆘 Support

- Issues: [GitHub Issues](https://github.com/rifuki/vps-infrastructure/issues)
