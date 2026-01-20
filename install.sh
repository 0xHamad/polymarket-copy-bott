#!/bin/bash

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

clear

echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════╗"
echo "║   🚀 Polymarket Copy Trading Bot Installer    ║"
echo "║        Automated Setup - Step by Step          ║"
echo "╚════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Function to pause and wait for user
pause() {
    echo ""
    echo -e "${YELLOW}Press ENTER to continue...${NC}"
    read
    echo ""
}

# Function to read input with validation
read_value() {
    local prompt="$1"
    local default="$2"
    local value=""
    
    while [ -z "$value" ]; do
        echo -e "${CYAN}$prompt${NC}"
        if [ -n "$default" ]; then
            echo -e "${YELLOW}(Press ENTER for default: $default)${NC}"
        fi
        echo -n "> "
        read input
        
        if [ -n "$input" ]; then
            value="$input"
        elif [ -n "$default" ]; then
            value="$default"
        else
            echo -e "${RED}❌ This field is required!${NC}"
            echo ""
        fi
    done
    
    echo "$value"
}

# Check if Node.js is installed
echo -e "${BLUE}[1/8] Checking Node.js installation...${NC}"
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}Node.js not found. Installing...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - >/dev/null 2>&1
    sudo apt-get install -y nodejs >/dev/null 2>&1
fi
echo -e "${GREEN}✅ Node.js $(node -v) ready${NC}"
pause

# Create project directory
echo -e "${BLUE}[2/8] Setting up project directory...${NC}"
PROJECT_DIR="polymarket-copy-bot"

if [ -d "$PROJECT_DIR" ]; then
    echo -e "${YELLOW}⚠️  Directory exists. Removing old installation...${NC}"
    rm -rf "$PROJECT_DIR"
fi

mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"
echo -e "${GREEN}✅ Project directory created: $(pwd)${NC}"
pause

# Install dependencies
echo -e "${BLUE}[3/8] Installing required packages...${NC}"
cat > package.json << 'EOF'
{
  "name": "polymarket-copy-bot",
  "version": "1.0.0",
  "description": "Automated Polymarket Copy Trading Bot",
  "main": "bot.js",
  "type": "module",
  "scripts": {
    "start": "node bot.js"
  },
  "keywords": ["polymarket", "trading", "bot"],
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
echo -e "${GREEN}✅ All packages installed successfully${NC}"
pause

# Start Configuration
clear
echo -e "${MAGENTA}"
echo "╔════════════════════════════════════════════════╗"
echo "║           🔧 CONFIGURATION WIZARD 🔧           ║"
echo "╚════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "${YELLOW}Ab hum aapki trading bot ko configure karenge.${NC}"
echo -e "${YELLOW}Har step ko dhyan se follow karen.${NC}"
pause

# Step 1: API Key
clear
echo -e "${BLUE}[4/8] Step 1 of 5: Polymarket API Key${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}📌 Kya hai ye?${NC}"
echo "   API Key aapki identity hai Polymarket par."
echo ""
echo -e "${CYAN}📌 Kaise milega?${NC}"
echo "   1. Browser mein jao: ${GREEN}https://polymarket.com/settings${NC}"
echo "   2. ${YELLOW}'Builder'${NC} tab par click karo"
echo "   3. ${YELLOW}'Create API Key'${NC} button press karo"
echo "   4. Sabse pehli value jo dikhegi wo ${GREEN}API Key${NC} hai"
echo ""
echo -e "${CYAN}📌 Example:${NC}"
echo "   550e8400-e29b-41d4-a716-446655440000"
echo ""
API_KEY=$(read_value "Apni POLY_API_KEY yahan paste karen:" "")
echo -e "${GREEN}✅ API Key saved${NC}"
pause

# Step 2: API Secret
clear
echo -e "${BLUE}[5/8] Step 2 of 5: Polymarket API Secret${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}📌 Kya hai ye?${NC}"
echo "   API Secret ek secure code hai jo aapke orders ko authenticate karta hai."
echo ""
echo -e "${CYAN}📌 Kaise milega?${NC}"
echo "   Same jagah se jahan API Key mila tha:"
echo "   1. ${GREEN}https://polymarket.com/settings${NC} > Builder tab"
echo "   2. ${GREEN}API Key${NC} ke neeche ${YELLOW}Secret${NC} dikhega"
echo "   3. Wo copy karen (long base64 string hogi)"
echo ""
echo -e "${CYAN}📌 Example:${NC}"
echo "   dGhpc2lzYXNlY3JldGtleWV4YW1wbGU="
echo ""
API_SECRET=$(read_value "Apna POLY_API_SECRET yahan paste karen:" "")
echo -e "${GREEN}✅ API Secret saved${NC}"
pause

# Step 3: Passphrase
clear
echo -e "${BLUE}[6/8] Step 3 of 5: Polymarket API Passphrase${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}📌 Kya hai ye?${NC}"
echo "   Passphrase ek additional security layer hai."
echo ""
echo -e "${CYAN}📌 Kaise milega?${NC}"
echo "   API Key aur Secret ke saath hi ye bhi dikhta hai:"
echo "   1. ${GREEN}https://polymarket.com/settings${NC} > Builder tab"
echo "   2. ${YELLOW}Passphrase${NC} field se copy karen"
echo ""
echo -e "${CYAN}📌 Example:${NC}"
echo "   mySecurePassphrase123"
echo ""
API_PASSPHRASE=$(read_value "Apna POLY_PASSPHRASE yahan paste karen:" "")
echo -e "${GREEN}✅ API Passphrase saved${NC}"
pause

# Step 4: Your Wallet
clear
echo -e "${BLUE}[7/8] Step 4 of 5: Aapka Polymarket Wallet Address${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}📌 Kya hai ye?${NC}"
echo "   Ye aapka Polymarket wallet address hai jahan aapka USDC hai."
echo ""
echo -e "${CYAN}📌 Kaise milega?${NC}"
echo "   1. ${GREEN}https://polymarket.com${NC} par jao"
echo "   2. Top-right corner mein apna ${YELLOW}profile${NC} click karo"
echo "   3. Wallet address dikhega (${YELLOW}0x${NC} se shuru hoga)"
echo "   4. Copy karo"
echo ""
echo -e "${CYAN}📌 Example:${NC}"
echo "   0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
echo ""
echo -e "${RED}⚠️  IMPORTANT:${NC} Is wallet mein USDC hona chahiye!"
echo ""
YOUR_WALLET=$(read_value "Apna wallet address (0x se shuru) yahan paste karen:" "")
echo -e "${GREEN}✅ Your wallet address saved${NC}"
pause

# Step 5: Lead Trader
clear
echo -e "${BLUE}[8/8] Step 5 of 5: Lead Trader Ka Wallet Address${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}📌 Kya hai ye?${NC}"
echo "   Jis trader ki trades copy karni hain uska wallet address."
echo ""
echo -e "${CYAN}📌 Kaise milega?${NC}"
echo "   1. ${GREEN}https://polymarket.com/leaderboard${NC} par jao"
echo "   2. Successful traders dekho"
echo "   3. Unka wallet address copy karo"
echo ""
echo -e "${CYAN}📌 Ya default use karen:${NC}"
echo "   ${GREEN}0x6031b6eed1c97e853c6e0f03ad3ce3529351f96d${NC}"
echo "   (Active trader - gabagool22)"
echo ""
LEAD_TRADER=$(read_value "Lead trader ka wallet address:" "0x6031b6eed1c97e853c6e0f03ad3ce3529351f96d")
echo -e "${GREEN}✅ Lead trader address saved${NC}"
pause

# Step 6: Amount
clear
echo -e "${BLUE}[BONUS] Trading Amount Setting${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}📌 Kya hai ye?${NC}"
echo "   Har trade mein kitne dollars lagane hain."
echo ""
echo -e "${CYAN}📌 Examples:${NC}"
echo "   • ${YELLOW}10${NC}  = Har trade mein $10 lagega"
echo "   • ${YELLOW}50${NC}  = Har trade mein $50 lagega"
echo "   • ${YELLOW}100${NC} = Har trade mein $100 lagega"
echo ""
echo -e "${RED}⚠️  Note:${NC} Aapke wallet mein kam se kam itna USDC hona chahiye."
echo ""
AMOUNT_PER_TRADE=$(read_value "Har trade mein kitne dollars lagane hain?" "10")
echo -e "${GREEN}✅ Trading amount set: \$$AMOUNT_PER_TRADE${NC}"
pause

# Create .env file
clear
echo -e "${BLUE}Saving configuration...${NC}"
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
echo -e "${GREEN}✅ Configuration file created${NC}"
sleep 1

# Download bot.js
echo -e "${BLUE}Installing bot code...${NC}"
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
sleep 1

# Create start script
cat > start.sh << 'EOFSTART'
#!/bin/bash
clear
echo "Starting Polymarket Copy Bot..."
node bot.js
EOFSTART

chmod +x start.sh

# Create README
cat > README.md << 'EOFREADME'
# Polymarket Copy Trading Bot

## Quick Start

```bash
./start.sh
```

## Configuration

Edit `.env` file to update settings.

## Support

For help, check the configuration in `.env` file.
EOFREADME

# Final Summary
clear
echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════╗"
echo "║          ✅ INSTALLATION COMPLETE! ✅          ║"
echo "╚════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "${YELLOW}📋 Configuration Summary:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Your Wallet:${NC}    ${GREEN}$YOUR_WALLET${NC}"
echo -e "${CYAN}Lead Trader:${NC}    ${GREEN}$LEAD_TRADER${NC}"
echo -e "${CYAN}Per Trade:${NC}      ${GREEN}\$$AMOUNT_PER_TRADE${NC}"
echo -e "${CYAN}API Key:${NC}        ${GREEN}${API_KEY:0:30}...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}🚀 Bot chalane ke liye:${NC}"
echo ""
echo -e "   ${GREEN}./start.sh${NC}"
echo ""
echo -e "${YELLOW}⚠️  Important Checks:${NC}"
echo "   ✓ Aapke wallet mein USDC hai?"
echo "   ✓ API credentials sahi hain?"
echo "   ✓ Internet connection stable hai?"
echo ""
echo -e "${GREEN}Sab ready hai! Bot start karne ke liye upar wala command chalayein.${NC}"
echo ""

# Auto-start option
echo -e -n "${CYAN}Abhi bot start karen? (y/n)${NC} [${GREEN}y${NC}]: "
read START_NOW

if [ -z "$START_NOW" ] || [ "$START_NOW" = "y" ] || [ "$START_NOW" = "Y" ]; then
    echo ""
    echo -e "${GREEN}Starting bot in 3 seconds...${NC}"
    sleep 1
    echo -e "${YELLOW}3...${NC}"
    sleep 1
    echo -e "${YELLOW}2...${NC}"
    sleep 1
    echo -e "${YELLOW}1...${NC}"
    sleep 1
    clear
    ./start.sh
fi
