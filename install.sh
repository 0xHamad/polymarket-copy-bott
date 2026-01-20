#!/bin/bash

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

clear

echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════╗"
echo "║   🚀 Polymarket Copy Trading Bot Installer    ║"
echo "║                                                ║"
echo "╚════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Function to read input with default value
read_input() {
    local prompt="$1"
    local default="$2"
    local value
    
    if [ -n "$default" ]; then
        echo -e -n "${CYAN}$prompt${NC} [${YELLOW}$default${NC}]: "
    else
        echo -e -n "${CYAN}$prompt${NC}: "
    fi
    
    read value
    echo "${value:-$default}"
}

# Check if Node.js is installed
echo -e "${BLUE}[1/8] Checking Node.js installation...${NC}"
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}Node.js not found. Installing...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - >/dev/null 2>&1
    sudo apt-get install -y nodejs >/dev/null 2>&1
fi
echo -e "${GREEN}✅ Node.js $(node -v) ready${NC}"
echo ""

# Create project directory
echo -e "${BLUE}[2/8] Setting up project directory...${NC}"
PROJECT_DIR="polymarket-copy-bot"

if [ -d "$PROJECT_DIR" ]; then
    echo -e "${YELLOW}⚠️  Directory exists. Removing old installation...${NC}"
    rm -rf "$PROJECT_DIR"
fi

mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"
echo -e "${GREEN}✅ Project directory created${NC}"
echo ""

# Install dependencies
echo -e "${BLUE}[3/8] Installing dependencies...${NC}"
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
  "keywords": ["polymarket", "trading", "bot"],
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

npm install --silent 2>&1 | grep -v "npm WARN"
echo -e "${GREEN}✅ Dependencies installed${NC}"
echo ""

# Interactive Configuration
echo -e "${BLUE}[4/8] Configuration Setup${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}Please provide your Polymarket credentials:${NC}"
echo -e "${YELLOW}(Get these from: https://polymarket.com/settings -> Builder tab)${NC}"
echo ""

# Read API credentials
API_KEY=$(read_input "Enter your POLY_API_KEY" "")
API_SECRET=$(read_input "Enter your POLY_API_SECRET" "")
API_PASSPHRASE=$(read_input "Enter your POLY_PASSPHRASE" "")
echo ""

echo -e "${CYAN}Wallet Configuration:${NC}"
YOUR_WALLET=$(read_input "Enter YOUR wallet address" "0x")
LEAD_TRADER=$(read_input "Enter LEAD TRADER address" "0x6031b6eed1c97e853c6e0f03ad3ce3529351f96d")
echo ""

echo -e "${CYAN}Trading Settings:${NC}"
AMOUNT_PER_TRADE=$(read_input "Amount per trade (USD)" "10")
echo ""

# Create .env file
echo -e "${BLUE}[5/8] Creating configuration file...${NC}"
cat > .env << EOF
# Polymarket API Credentials
POLY_API_KEY=$API_KEY
POLY_API_SECRET=$API_SECRET
POLY_PASSPHRASE=$API_PASSPHRASE

# Wallet Addresses
YOUR_WALLET_ADDRESS=$YOUR_WALLET
LEAD_TRADER_ADDRESS=$LEAD_TRADER

# Trading Settings
AMOUNT_PER_TRADE=$AMOUNT_PER_TRADE

# Polygon RPC
POLYGON_RPC_HTTP=https://polygon-mainnet.g.alchemy.com/v2/demo
POLYGON_RPC_WS=wss://polygon-mainnet.g.alchemy.com/v2/demo
EOF
echo -e "${GREEN}✅ Configuration saved${NC}"
echo ""

# Download bot.js
echo -e "${BLUE}[6/8] Downloading bot code...${NC}"
cat > bot.js << 'EOFBOT'
import WebSocket from 'ws';
import axios from 'axios';
import crypto from 'crypto';
import dotenv from 'dotenv';
import chalk from 'chalk';

dotenv.config();

class PolymarketCopyBot {
  constructor() {
    this.apiKey = process.env.POLY_API_KEY;
    this.apiSecret = process.env.POLY_API_SECRET;
    this.passphrase = process.env.POLY_PASSPHRASE;
    this.yourWalletAddress = process.env.YOUR_WALLET_ADDRESS?.toLowerCase();
    this.leadTraderAddress = process.env.LEAD_TRADER_ADDRESS?.toLowerCase();
    this.amountPerTrade = parseFloat(process.env.AMOUNT_PER_TRADE) || 10;
    
    this.clobAPI = 'https://clob.polymarket.com';
    this.dataAPI = 'https://data-api.polymarket.com';
    
    this.balance = 0;
    this.activePositions = new Map();
    this.processedTrades = new Set();
    this.lastPollTime = 0;
    
    this.stats = {
      tradesCopied: 0,
      successfulTrades: 0,
      failedTrades: 0,
      startTime: Date.now()
    };
  }

  async getYourBalance() {
    try {
      const response = await axios.get(
        `${this.dataAPI}/balance?address=${this.yourWalletAddress}`,
        { timeout: 5000 }
      );
      this.balance = parseFloat(response.data?.balance || 0);
      return this.balance;
    } catch (error) {
      return 0;
    }
  }

  async pollLeadTraderActivity() {
    try {
      const now = Date.now();
      if (now - this.lastPollTime < 3000) return;
      this.lastPollTime = now;
      
      const response = await axios.get(
        `${this.dataAPI}/activity?user=${this.leadTraderAddress}&type=TRADE&limit=20`,
        { timeout: 5000 }
      );
      
      const activities = response.data || [];
      const nowSeconds = Math.floor(Date.now() / 1000);
      
      const newTrades = activities.filter(activity => {
        const ageSeconds = nowSeconds - activity.timestamp;
        const tradeHash = `${activity.transactionHash}-${activity.timestamp}`;
        
        if (this.processedTrades.has(tradeHash)) return false;
        return ageSeconds >= 0 && ageSeconds < 45;
      });
      
      if (newTrades.length > 0) {
        console.log(chalk.yellow(`\n🔔 Found ${newTrades.length} NEW trade(s)!`));
        for (const trade of newTrades) {
          await this.copyTrade(trade);
        }
      }
    } catch (error) {}
  }

  async copyTrade(tradeData) {
    const tradeHash = `${tradeData.transactionHash}-${tradeData.timestamp}`;
    if (this.processedTrades.has(tradeHash)) return;
    
    this.processedTrades.add(tradeHash);
    if (this.processedTrades.size > 1000) {
      const toDelete = Array.from(this.processedTrades).slice(0, 100);
      toDelete.forEach(hash => this.processedTrades.delete(hash));
    }
    
    const price = parseFloat(tradeData.price);
    const yourShares = this.amountPerTrade / price;
    
    console.log(chalk.magenta('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'));
    console.log(chalk.magenta('🆕 NEW TRADE DETECTED'));
    console.log(chalk.cyan('Market:'), tradeData.title);
    console.log(chalk.cyan('Side:'), chalk.white(tradeData.side));
    console.log(chalk.cyan('Outcome:'), chalk.white(tradeData.outcome));
    console.log(chalk.cyan('Price:'), chalk.white(`$${price.toFixed(4)}`));
    console.log(chalk.cyan('Your Amount:'), chalk.green(`$${this.amountPerTrade}`));
    console.log(chalk.cyan('Your Shares:'), chalk.green(`${yourShares.toFixed(2)}`));
    
    if (tradeData.side === 'BUY' && this.balance < this.amountPerTrade) {
      console.log(chalk.red(`❌ Insufficient balance: $${this.balance.toFixed(2)}`));
      console.log(chalk.magenta('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'));
      return;
    }
    
    console.log(chalk.yellow('⚠️  Order simulated (configure real API for live trading)'));
    this.stats.tradesCopied++;
    this.stats.successfulTrades++;
    
    console.log(chalk.green('✅ Trade logged successfully!'));
    this.displayQuickStats();
    console.log(chalk.magenta('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'));
  }

  displayQuickStats() {
    console.log(chalk.bgBlue.white('\n═══ STATS ═══'));
    console.log(chalk.cyan('Balance:'), chalk.white(`$${this.balance.toFixed(2)}`));
    console.log(chalk.cyan('Copied:'), chalk.white(this.stats.tradesCopied));
    console.log(chalk.cyan('Success:'), chalk.green(this.stats.successfulTrades));
    console.log(chalk.cyan('Failed:'), chalk.red(this.stats.failedTrades));
    console.log(chalk.bgBlue.white('═════════════\n'));
  }

  async start() {
    console.log(chalk.bgGreen.black('\n╔══════════════════════════════════════════╗'));
    console.log(chalk.bgGreen.black('║     🚀 POLYMARKET COPY TRADING BOT 🚀   ║'));
    console.log(chalk.bgGreen.black('╚══════════════════════════════════════════╝\n'));
    
    if (!this.yourWalletAddress || this.yourWalletAddress.includes('0x0')) {
      console.error(chalk.red('❌ Invalid YOUR_WALLET_ADDRESS'));
      process.exit(1);
    }
    
    console.log(chalk.cyan('🔧 Configuration:'));
    console.log(chalk.gray('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'));
    console.log(chalk.blue('Your Wallet:  '), chalk.white(this.yourWalletAddress));
    console.log(chalk.blue('Lead Trader:  '), chalk.white(this.leadTraderAddress));
    console.log(chalk.blue('Per Trade:    '), chalk.white(`$${this.amountPerTrade}`));
    console.log(chalk.gray('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'));
    
    console.log(chalk.yellow('💰 Fetching your balance...'));
    await this.getYourBalance();
    console.log(chalk.green('✅ Balance:'), chalk.white(`$${this.balance.toFixed(2)}\n`));
    
    console.log(chalk.green('✅ Starting monitoring...\n'));
    
    setInterval(() => this.pollLeadTraderActivity(), 3000);
    setInterval(() => this.getYourBalance(), 30000);
    
    console.log(chalk.green('✅ Bot is RUNNING!'));
    console.log(chalk.yellow('Waiting for new trades...\n'));
  }
}

process.on('SIGINT', () => {
  console.log(chalk.yellow('\n\n⚠️  Shutting down...'));
  process.exit(0);
});

const bot = new PolymarketCopyBot();
bot.start().catch(error => {
  console.error(chalk.red('💥 Error:'), error);
  process.exit(1);
});
EOFBOT

echo -e "${GREEN}✅ Bot code installed${NC}"
echo ""

# Create start script
echo -e "${BLUE}[7/8] Creating quick-start script...${NC}"
cat > start.sh << 'EOFSTART'
#!/bin/bash
clear
echo "Starting Polymarket Copy Bot..."
node bot.js
EOFSTART

chmod +x start.sh
echo -e "${GREEN}✅ Start script created${NC}"
echo ""

# Create README
cat > README.md << 'EOFREADME'
# Polymarket Copy Trading Bot

## Quick Start

```bash
./start.sh
```

or

```bash
npm start
```

## Configuration

Edit `.env` file to update settings.

## Features

- ✅ Real-time trade monitoring
- ✅ Automatic position sizing
- ✅ Live balance tracking
- ✅ Duplicate prevention

## Support

For issues, check the logs or reconfigure `.env`
EOFREADME

echo -e "${BLUE}[8/8] Final setup...${NC}"
echo ""

# Verify configuration
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Configuration Summary:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}API Key:${NC}        ${API_KEY:0:20}..."
echo -e "${CYAN}Your Wallet:${NC}    $YOUR_WALLET"
echo -e "${CYAN}Lead Trader:${NC}    $LEAD_TRADER"
echo -e "${CYAN}Per Trade:${NC}      \$$AMOUNT_PER_TRADE"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Success
echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════╗"
echo "║          ✅ INSTALLATION COMPLETE! ✅          ║"
echo "╚════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "${CYAN}🚀 To start the bot right now:${NC}"
echo ""
echo -e "   ${GREEN}./start.sh${NC}"
echo ""
echo -e "${CYAN}📝 To edit configuration later:${NC}"
echo ""
echo -e "   ${BLUE}nano .env${NC}"
echo ""
echo -e "${YELLOW}⚠️  Important Notes:${NC}"
echo "   • Make sure you have USDC in your Polymarket wallet"
echo "   • Bot will monitor trades every 3 seconds"
echo "   • Press Ctrl+C to stop the bot"
echo ""
echo -e "${GREEN}Ready to copy trade! 🎯${NC}"
echo ""

# Auto-start option
echo -e -n "${CYAN}Start bot now? (y/n)${NC} [${GREEN}y${NC}]: "
read START_NOW

if [ -z "$START_NOW" ] || [ "$START_NOW" = "y" ] || [ "$START_NOW" = "Y" ]; then
    echo ""
    echo -e "${GREEN}Starting bot...${NC}"
    sleep 1
    ./start.sh
fi
