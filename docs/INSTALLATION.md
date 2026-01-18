# Installation Guide

## Quick Installation

### Method 1: One-Click Installer (Recommended)

#### Linux/Mac
```bash
curl -sSL https://raw.githubusercontent.com/0xhamad/polymarket-copy-bott/main/install.sh | bash
```

#### Windows
Download and run [install.bat](../install.bat)

### Method 2: Manual Installation
```bash
# 1. Clone repository
git clone https://github.com/0xhamad/polymarket-copy-bott.git
cd polymarket-copy-bot

# 2. Install Node.js dependencies
npm install

# 3. Configure environment
cp .env.example .env
nano .env  # Edit with your credentials

# 4. Start bot
npm start
```

## System Requirements

- Node.js ≥ 18.0.0
- NPM ≥ 9.0.0
- 512MB RAM minimum
- Stable internet connection

## Platform-Specific Instructions

### Ubuntu/Debian
```bash
# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Clone and setup
git clone https://github.com/0xhamad/polymarket-copy-bott.git
cd polymarket-copy-bot
npm install
```

### macOS
```bash
# Install Node.js via Homebrew
brew install node

# Clone and setup
git clone https://github.com/0xhamad/polymarket-copy-bott.git
cd polymarket-copy-bot
npm install
```

### Windows
1. Download Node.js from https://nodejs.org
2. Install Node.js
3. Download repository as ZIP
4. Extract and open folder in Command Prompt
5. Run: `npm install`

## Verification

Check installation:
```bash
node -v  # Should show v18.0.0 or higher
npm -v   # Should show v9.0.0 or higher
```

## Next Steps

After installation, proceed to [Configuration Guide](CONFIGURATION.md)
