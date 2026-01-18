#!/bin/bash

# ============================================
# GITHUB UPLOAD SCRIPT
# Polymarket Copy Trading Bot
# ============================================

clear

echo "🚀 GitHub Repository Setup Script"
echo "=================================="
echo ""

# Get GitHub username
read -p "Enter your GitHub username: " GITHUB_USER
read -p "Enter repository name (default: polymarket-copy-trading-bot): " REPO_NAME
REPO_NAME=${REPO_NAME:-polymarket-copy-trading-bot}

echo ""
echo "📁 Creating project structure..."
echo ""

# Create main directory
mkdir -p $REPO_NAME
cd $REPO_NAME

# Create subdirectories
mkdir -p docs
mkdir -p assets

echo "✅ Directories created"
echo ""
echo "📝 Creating files..."

# ============================================
# 1. .gitignore
# ============================================
cat > .gitignore << 'EOF'
# Dependencies
node_modules/
package-lock.json

# Environment
.env
.env.local
.env.*.local

# Logs
*.log

# OS
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
*.swp

# Build
dist/
build/

# Custom
trades.log
bot-stats.csv
EOF

echo "✅ .gitignore created"

# ============================================
# 2. LICENSE
# ============================================
cat > LICENSE << EOF
MIT License

Copyright (c) $(date +%Y) $GITHUB_USER

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

echo "✅ LICENSE created"

# ============================================
# 3. README.md
# ============================================
cat > README.md << 'READMEEOF'
# 🤖 Polymarket Ultra Fast Copy Trading Bot

<div align="center">

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Node](https://img.shields.io/badge/node-%3E%3D18.0.0-brightgreen)
![Status](https://img.shields.io/badge/status-active-success)

**Automatically copy trades from top Polymarket traders in real-time**

</div>

## 🌟 Features

- ⚡ **Ultra-Fast Execution** - Market orders for instant copying
- 🔄 **Real-Time Monitoring** - WebSocket for zero-delay updates
- 💰 **Smart Position Sizing** - Configurable % of balance per trade
- 📊 **Live Statistics** - Track P&L and performance
- 🔒 **Secure** - All credentials stored locally
- 🎯 **Auto-Close** - Exit when lead trader exits

## 🚀 Quick Start

### One-Click Installation

**Linux/Mac:**
```bash
curl -sSL https://raw.githubusercontent.com/GITHUB_USER/REPO_NAME/main/install.sh | bash
```

**Windows:**
Download and run [install.bat](install.bat)

### Manual Installation

```bash
git clone https://github.com/GITHUB_USER/REPO_NAME.git
cd REPO_NAME
npm install
cp .env.example .env
# Edit .env with your credentials
npm start
```

## ⚙️ Configuration

1. Get Polymarket API credentials from Settings → API
2. Copy `.env.example` to `.env`
3. Fill in your credentials:

```bash
POLY_API_KEY=your-key
POLY_API_SECRET=your-secret
POLY_PASSPHRASE=your-passphrase
LEAD_TRADER_ADDRESS=0x...
COPY_PERCENTAGE=10
```

## 📊 Usage

```bash
# Start bot
npm start

# Or use start scripts
./start.sh        # Linux/Mac
start.bat         # Windows
```

## 🛡️ Security

- ✅ Store credentials in `.env` only
- ✅ Add `.env` to `.gitignore`
- ✅ Start with 5-10% copy percentage
- ✅ Monitor regularly
- ❌ Never share API keys
- ❌ Never commit `.env`

## 📚 Documentation

- [Installation Guide](docs/INSTALLATION.md)
- [Configuration Guide](docs/CONFIGURATION.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

## ⚠️ Disclaimer

**USE AT YOUR OWN RISK**

This bot is for educational purposes. Trading involves financial risk.
Author is not responsible for any losses.

## 📝 License

MIT License - see [LICENSE](LICENSE) file

## 🌟 Support

If this helped you, please ⭐ star the repo!

---

Made with ❤️ for the Polymarket community
READMEEOF

# Replace placeholders in README
sed -i "s/GITHUB_USER/$GITHUB_USER/g" README.md
sed -i "s/REPO_NAME/$REPO_NAME/g" README.md

echo "✅ README.md created"

# ============================================
# 4. package.json
# ============================================
cat > package.json << EOF
{
  "name": "$REPO_NAME",
  "version": "1.0.0",
  "description": "Ultra-fast Polymarket copy trading bot",
  "main": "bot.js",
  "type": "module",
  "scripts": {
    "start": "node bot.js",
    "dev": "node --watch bot.js"
  },
  "keywords": ["polymarket", "trading", "bot", "copy-trading"],
  "author": "$GITHUB_USER",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/$GITHUB_USER/$REPO_NAME.git"
  },
  "dependencies": {
    "axios": "^1.6.2",
    "chalk": "^5.3.0",
    "dotenv": "^16.3.1",
    "ws": "^8.16.0"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF

echo "✅ package.json created"

# ============================================
# 5. .env.example
# ============================================
cat > .env.example << 'EOF'
# Polymarket API Credentials
POLY_API_KEY=your-api-key-here
POLY_API_SECRET=your-api-secret-here
POLY_PASSPHRASE=your-passphrase-here

# Lead Trader
LEAD_TRADER_ADDRESS=0x1234567890abcdef1234567890abcdef12345678

# Trading Settings
COPY_PERCENTAGE=10
EOF

echo "✅ .env.example created"

# ============================================
# 6. bot.js (from previous artifact)
# ============================================
echo "⚠️  Please copy bot.js from the main bot artifact"
echo "   Create bot.js manually or paste the bot code"

# ============================================
# 7. install.sh (from installer artifact)
# ============================================
echo "⚠️  Please copy install.sh from the installer artifact"
echo "   Create install.sh manually or paste the installer code"

# ============================================
# 8. install.bat (from Windows installer)
# ============================================
echo "⚠️  Please copy install.bat from the Windows installer artifact"

# ============================================
# 9. start.sh
# ============================================
cat > start.sh << 'EOF'
#!/bin/bash
clear
echo "🤖 Starting Polymarket Copy Trading Bot..."
echo ""
if [ ! -f .env ]; then
    echo "❌ .env not found! Copy .env.example to .env"
    exit 1
fi
if [ ! -d node_modules ]; then
    echo "📦 Installing dependencies..."
    npm install
fi
node bot.js
EOF

chmod +x start.sh
echo "✅ start.sh created"

# ============================================
# 10. start.bat
# ============================================
cat > start.bat << 'EOF'
@echo off
cls
echo Starting Polymarket Copy Trading Bot...
echo.
if not exist .env (
    echo Error: .env not found!
    pause
    exit /b 1
)
if not exist node_modules (
    echo Installing dependencies...
    call npm install
)
node bot.js
pause
EOF

echo "✅ start.bat created"

# ============================================
# 11. Documentation files
# ============================================

cat > docs/INSTALLATION.md << 'EOF'
# Installation Guide

## Quick Installation

### Linux/Mac
```bash
curl -sSL https://raw.githubusercontent.com/USER/REPO/main/install.sh | bash
```

### Windows
Download and run install.bat

## Manual Installation

```bash
git clone https://github.com/USER/REPO.git
cd REPO
npm install
cp .env.example .env
# Edit .env
npm start
```

## Requirements

- Node.js ≥ 18.0.0
- NPM ≥ 9.0.0
- Polymarket account with API access
EOF

cat > docs/CONFIGURATION.md << 'EOF'
# Configuration Guide

## Getting API Credentials

1. Login to polymarket.com
2. Go to Settings → API
3. Create API Key
4. Save credentials

## Setup .env

```bash
cp .env.example .env
nano .env
```

Fill in:
- POLY_API_KEY
- POLY_API_SECRET
- POLY_PASSPHRASE
- LEAD_TRADER_ADDRESS
- COPY_PERCENTAGE

## Finding Lead Trader

- Check Polymarket profiles
- Use leaderboards
- Get wallet address (0x...)
EOF

cat > docs/TROUBLESHOOTING.md << 'EOF'
# Troubleshooting

## Common Issues

### WebSocket Disconnected
- Bot auto-reconnects
- Check internet connection

### No Trades Copied
- Verify lead trader address
- Check WebSocket connection
- Ensure sufficient balance

### API Errors
- Verify credentials in .env
- Check API key is active
- Ensure no rate limits

## Getting Help

- GitHub Issues
- Email support
- Community Discord
EOF

echo "✅ Documentation created"

# ============================================
# Git initialization
# ============================================
echo ""
echo "📦 Initializing Git repository..."

git init
git add .
git commit -m "Initial commit: Polymarket copy trading bot with one-click installer"

echo "✅ Git initialized"

# ============================================
# GitHub setup instructions
# ============================================
echo ""
echo "=================================="
echo "✅ PROJECT SETUP COMPLETE!"
echo "=================================="
echo ""
echo "📋 Next Steps:"
echo ""
echo "1. Create GitHub repository:"
echo "   - Go to: https://github.com/new"
echo "   - Name: $REPO_NAME"
echo "   - Make it Public"
echo "   - Don't initialize with README"
echo ""
echo "2. Push to GitHub:"
echo "   cd $(pwd)"
echo "   git remote add origin https://github.com/$GITHUB_USER/$REPO_NAME.git"
echo "   git branch -M main"
echo "   git push -u origin main"
echo ""
echo "3. Add these files manually (copy from artifacts):"
echo "   - bot.js (main bot code)"
echo "   - install.sh (Linux/Mac installer)"
echo "   - install.bat (Windows installer)"
echo ""
echo "4. Update README.md:"
echo "   - Replace USER/REPO with your username/repo"
echo "   - Add screenshots if you want"
echo ""
echo "🎉 Your repository will be live at:"
echo "   https://github.com/$GITHUB_USER/$REPO_NAME"
echo ""
echo "=================================="
