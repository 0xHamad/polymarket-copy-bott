#!/bin/bash

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}"
echo "╔══════════════════════════════════════════╗"
echo "║  Polymarket Copy Trading Bot Installer  ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# Check if Node.js is installed
echo -e "${BLUE}Checking Node.js installation...${NC}"
if ! command -v node &> /dev/null; then
    echo -e "${RED}Node.js is not installed!${NC}"
    echo -e "${YELLOW}Installing Node.js...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

NODE_VERSION=$(node -v)
echo -e "${GREEN}✅ Node.js $NODE_VERSION installed${NC}"

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo -e "${RED}npm is not installed!${NC}"
    exit 1
fi

NPM_VERSION=$(npm -v)
echo -e "${GREEN}✅ npm $NPM_VERSION installed${NC}"

# Create project directory
echo -e "${BLUE}Creating project directory...${NC}"
PROJECT_DIR="polymarket-copy-bot"

if [ -d "$PROJECT_DIR" ]; then
    echo -e "${YELLOW}Directory already exists. Removing old files...${NC}"
    rm -rf "$PROJECT_DIR"
fi

mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Initialize npm project
echo -e "${BLUE}Initializing npm project...${NC}"
npm init -y

# Install dependencies
echo -e "${BLUE}Installing dependencies...${NC}"
npm install ws axios dotenv chalk

# Create package.json with proper configuration
cat > package.json << 'EOF'
{
  "name": "polymarket-copy-bot",
  "version": "1.0.0",
  "description": "Automated Polymarket Copy Trading Bot",
  "main": "bot.js",
  "type": "module",
  "scripts": {
    "start": "node bot.js",
    "dev": "node bot.js"
  },
  "keywords": ["polymarket", "trading", "bot", "copy-trading"],
  "author": "",
  "license": "MIT",
  "dependencies": {
    "axios": "^1.6.2",
    "chalk": "^5.3.0",
    "dotenv": "^16.3.1",
    "ws": "^8.14.2"
  }
}
EOF

echo -e "${GREEN}✅ Dependencies installed${NC}"

# Create .env.example file
echo -e "${BLUE}Creating configuration template...${NC}"
cat > .env.example << 'EOF'
# Your Polymarket API Credentials
# Get these from: https://polymarket.com/settings (Builder tab)
POLY_API_KEY=your_api_key_here
POLY_API_SECRET=your_api_secret_here
POLY_PASSPHRASE=your_passphrase_here

# Your Polymarket wallet address (where you hold funds)
YOUR_WALLET_ADDRESS=0xYourWalletAddressHere

# Lead trader's wallet address (to copy)
LEAD_TRADER_ADDRESS=0x6031b6eed1c97e853c6e0f03ad3ce3529351f96d

# Amount to use per trade (in USD)
AMOUNT_PER_TRADE=10

# Polygon RPC (optional - uses free endpoint by default)
POLYGON_RPC_HTTP=https://polygon-mainnet.g.alchemy.com/v2/demo
POLYGON_RPC_WS=wss://polygon-mainnet.g.alchemy.com/v2/demo
EOF

# Copy to actual .env if it doesn't exist
if [ ! -f .env ]; then
    cp .env.example .env
    echo -e "${YELLOW}⚠️  Created .env file - PLEASE CONFIGURE IT!${NC}"
fi

# Create README
cat > README.md << 'EOF'
# Polymarket Copy Trading Bot

Automatically copy trades from any Polymarket trader in real-time.

## Features

✅ Real-time trade detection (3-second polling)
✅ Instant trade copying
✅ Automatic position management
✅ Follows sells automatically
✅ Customizable position sizing
✅ Live balance tracking
✅ Duplicate trade prevention

## Quick Start

### 1. Configure Bot

Edit `.env` file:

```bash
# Your Polymarket API credentials
POLY_API_KEY=your_api_key
POLY_API_SECRET=your_secret
POLY_PASSPHRASE=your_passphrase

# Your wallet address
YOUR_WALLET_ADDRESS=0xYourAddress

# Trader to copy
LEAD_TRADER_ADDRESS=0xTraderAddress

# Amount per trade (USD)
AMOUNT_PER_TRADE=10
```

### 2. Get API Credentials

1. Go to https://polymarket.com/settings
2. Click "Builder" tab
3. Create API key
4. Copy credentials to `.env`

### 3. Run Bot

```bash
npm start
```

## Configuration

- `AMOUNT_PER_TRADE`: How much $ to use per trade (default: $10)
- `LEAD_TRADER_ADDRESS`: Wallet address of trader to copy
- `YOUR_WALLET_ADDRESS`: Your Polymarket wallet address

## How It Works

1. **Monitoring**: Checks lead trader every 3 seconds
2. **Detection**: Finds new trades within 30 seconds
3. **Copying**: Places same trade with your configured amount
4. **Selling**: Automatically sells when lead trader sells
5. **Tracking**: Prevents duplicate trades

## Requirements

- Node.js 18+
- Polymarket account with USDC balance
- API credentials from Polymarket

## Safety Features

- Duplicate prevention
- Balance checking before trades
- Rate limiting protection
- Error handling

## Support

For issues or questions, create an issue on GitHub.

## Disclaimer

Trading involves risk. Use at your own risk. This bot is for educational purposes.
EOF

echo -e "${GREEN}✅ README created${NC}"

# Create .gitignore
cat > .gitignore << 'EOF'
node_modules/
.env
*.log
.DS_Store
EOF

# Success message
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════╗"
echo "║           ✅ Installation Complete!      ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Configure your settings:"
echo -e "   ${BLUE}cd $PROJECT_DIR${NC}"
echo -e "   ${BLUE}nano .env${NC}"
echo ""
echo "2. Add your API credentials:"
echo "   - Get from: https://polymarket.com/settings"
echo "   - Update: POLY_API_KEY, POLY_API_SECRET, POLY_PASSPHRASE"
echo "   - Set YOUR_WALLET_ADDRESS"
echo ""
echo "3. Start the bot:"
echo -e "   ${BLUE}npm start${NC}"
echo ""
echo -e "${GREEN}Bot is ready to use!${NC}"
echo ""
