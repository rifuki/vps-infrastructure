# VPS Infrastructure

Modular, scalable VPS infrastructure setup with Docker, Caddy reverse proxy, and automated deployment.

## 🚀 Quick Start

### New VPS Setup

```bash
# 1. Clone this repo
git clone https://github.com/rifuki/vps-infrastructure.git
cd vps-infrastructure

# 2. Run setup
./scripts/setup-vps.sh

# 3. Deploy your first project
./deploy.sh portfolio-terminal
```

## 📁 Repository Structure

```
vps-infrastructure/
├── README.md
├── deploy.sh                 # Main deployment script
├── scripts/
│   ├── setup-vps.sh         # VPS initialization
│   └── cross-build.sh       # Mac → VPS build helper
├── infrastructure/
│   ├── docker-compose.yml   # Traefik/Caddy configs (optional)
│   └── README.md
├── projects/
│   ├── template/            # Project template
│   ├── naisu-one/
│   ├── aksara/
│   ├── simpasar/
│   └── portfolio-terminal/
└── caddy-configs/           # Caddy reverse proxy configs
    ├── Caddyfile
    └── *.caddy
```

## 🛠️ Setup New Project

```bash
# 1. Copy template
cp -r projects/template projects/my-new-project

# 2. Edit configuration
vim projects/my-new-project/docker-compose.yml
vim caddy-configs/my-new-project.caddy

# 3. Deploy
./deploy.sh my-new-project
```

## 🔄 Cross-Compilation (Mac → VPS)

### Prerequisites (Mac)
```bash
# Install Rust target
rustup target add x86_64-unknown-linux-gnu

# Install cross-compilation toolchain
brew install FiloSottile/musl-cross/musl-cross
```

### Build & Deploy
```bash
# Build for Linux
./scripts/cross-build.sh my-project

# Deploy to VPS
./scripts/deploy-from-mac.sh my-project
```

## 📊 Port Allocation

| Project | Service | Port | Domain |
|---------|---------|------|--------|
| portfolio-terminal | terminal | 4040 | terminal.rifuki.dev |
| naisu-one | backend | 3939 | api.naisu.one |
| naisu-one | agent | 8787 | agent.naisu.one |
| aksara | api | 8080 | api.aksara.rifuki.dev |
| simpasar | api | 3001 | api.simpasar.rifuki.dev |

**New projects**: Use ports 9000+

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

### 4. Deploy Project
```bash
cd projects/your-project
docker compose up -d
```

## 📝 Environment Variables

Create `.env` file in each project directory:

```bash
# projects/naisu-one/.env
DATABASE_URL=sqlite:///app/data/db.sqlite
BACKEND_PORT=3939
AGENT_PORT=8787
```

## 🔍 Troubleshooting

### Check service status
```bash
docker ps
docker compose -f projects/<name>/docker-compose.yml logs
sudo systemctl status caddy
```

### Port already in use
```bash
sudo lsof -i :<port>
# Change port in docker-compose.yml and caddy config
```

### SSL issues
```bash
sudo rm -rf /var/lib/caddy/.local/share/caddy/certificates
sudo systemctl restart caddy
```

## 🏗️ Architecture

```
Internet
    ↓
Caddy (80/443) ← SSL Auto
    ↓
Project Containers (localhost ports)
    ↓
Services (Databases, etc.)
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
./scripts/setup-vps.sh
```

## 🤝 Contributing

1. Add new project to `projects/`
2. Create Caddy config in `caddy-configs/`
3. Update port allocation table
4. Test on VPS
5. Commit & push

## 📄 License

MIT - Free to use and modify

## 🆘 Support

- Issues: [GitHub Issues](https://github.com/rifuki/vps-infrastructure/issues)
- Wiki: [Documentation](https://github.com/rifuki/vps-infrastructure/wiki)
