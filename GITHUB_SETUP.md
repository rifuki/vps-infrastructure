# VPS Infrastructure Setup Guide

## 🚀 Create GitHub Repository

1. Go to https://github.com/new
2. Repository name: `vps-infrastructure`
3. Description: `Modular VPS infrastructure with Docker and Caddy`
4. Make it **Private** (recommended)
5. Click "Create repository"

## 📤 Push This Repository

```bash
# Add remote (replace with your GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/vps-infrastructure.git

# Push
git branch -M main
git push -u origin main
```

## 🎯 Usage

### Setup New VPS

```bash
# On fresh Ubuntu 24.04 VPS:
git clone https://github.com/YOUR_USERNAME/vps-infrastructure.git
cd vps-infrastructure
sudo ./scripts/setup-vps.sh
```

### Deploy Project

```bash
# On VPS:
./deploy.sh portfolio-terminal

# Or use the global command:
vps-deploy portfolio-terminal
```

### Cross-Build from Mac

```bash
# Set environment variables
export VPS_USER=rifuki
export VPS_HOST=your-vps-ip

# Build and deploy
./scripts/cross-build.sh naisu-one
```

## 📁 Repository Structure

```
vps-infrastructure/
├── README.md                    # Main documentation
├── deploy.sh                    # Deployment script
├── scripts/
│   ├── setup-vps.sh            # VPS initialization
│   └── cross-build.sh          # Mac → VPS builder
├── projects/                    # Project configurations
│   ├── template/               # Template for new projects
│   ├── naisu-one/              # Naisu-One project
│   ├── aksara/                 # Aksara project
│   ├── simpasar/               # Simpasar project
│   └── portfolio-terminal/     # Portfolio terminal
└── caddy-configs/              # Caddy reverse proxy
    ├── Caddyfile
    └── *.caddy
```

## 🔧 Adding New Project

```bash
# 1. Copy template
cp -r projects/template projects/my-new-project

# 2. Edit files
vim projects/my-new-project/docker-compose.yml
vim projects/my-new-project/Dockerfile

# 3. Create Caddy config
cat > caddy-configs/my-new-project.caddy << 'EOF'
my-project.rifuki.dev {
    reverse_proxy localhost:9000
    encode gzip
}
EOF

# 4. Commit and push
git add .
git commit -m "Add my-new-project"
git push

# 5. Deploy
./deploy.sh my-new-project
```

## 🆘 Troubleshooting

### Permission Denied
```bash
chmod +x deploy.sh scripts/*.sh
```

### Docker Not Found
```bash
# Run setup again
sudo ./scripts/setup-vps.sh
```

### Port Already in Use
```bash
# Check what's using the port
sudo lsof -i :<port>

# Change port in docker-compose.yml
# Update caddy-configs/<project>.caddy
# Reload: sudo systemctl reload caddy
```

## 📚 Documentation

- Main README: [README.md](README.md)
- Cross-compilation guide in [scripts/cross-build.sh](scripts/cross-build.sh)

## 🔒 Security Notes

- Keep this repo **private** if it contains sensitive configs
- Use `.env` files for secrets (already in .gitignore)
- Never commit SSH keys or passwords
- Use GitHub Secrets for CI/CD

## 🎉 Done!

Your VPS infrastructure is now version controlled and portable!
