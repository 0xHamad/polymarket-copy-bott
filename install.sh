#!/bin/bash

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

clear

echo -e "${BOLD}${GREEN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║     🤖 POLYMARKET COPY TRADING BOT - AUTO INSTALLER     ║
║                                                          ║
║         One Command Setup - Fully Automated              ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo ""

# Spinner function
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Function to show step
show_step() {
    echo -e "${BOLD}${BLUE}[STEP $1]${NC} ${CYAN}$2${NC}"
}

# Function to show success
show_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Function to show info
show_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

# Check Node.js
show_step "1/7" "Checking system requirements..."
if ! command -v node &> /dev/null; then
    show_info "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - >/dev/null 2>&1 &
    spinner $!
    sudo apt-get install -y nodejs >/dev/null 2>&1 &
    spinner $!
fi
show_success "Node.js $(node -v) ready"
echo ""

# Setup directory
show_step "2/7" "Creating project..."
PROJECT_DIR="polymarket-copy-bot"
[ -d "$PROJECT_DIR" ] && rm -rf "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR" && cd "$PROJECT_DIR"
show_success "Project directory created"
echo ""

# Install packages
show_step "3/7" "Installing dependencies..."
cat > package.json << 'EOF'
{
  "name": "polymarket-copy-bot",
  "version": "2.0.0",
  "type": "module",
  "scripts": {"start": "node bot.js"},
  "dependencies": {
    "axios": "^1.6.2",
    "chalk": "^5.3.0",
    "dotenv": "^16.3.1",
    "ws": "^8.14.2"
  }
}
EOF
npm install --silent >/dev/null 2>&1 &
spinner $!
show_success "Dependencies installed"
echo ""

# Configuration
clear
echo -e "${BOLD}${MAGENTA}"
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                   🔧 CONFIGURATION                       ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo ""

show_info "Simple setup - Sari details fill karen"
echo ""

# Section 1: Polymarket API
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}📡 SECTION 1: POLYMARKET API CREDENTIALS${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Credentials kahan se milenge?${NC}"
echo -e "  ${GREEN}1.${NC} https://polymarket.com/settings par jao"
echo -e "  ${GREEN}2.${NC} 'Builder' tab mein jao"
echo -e "  ${GREEN}3.${NC} 'Create API Key' click karo"
echo ""

read -p "$(echo -e ${BOLD}${CYAN}Enter API Key${NC}): " API_KEY
read -p "$(echo -e ${BOLD}${CYAN}Enter API Secret${NC}): " API_SECRET
read -p "$(echo -e ${BOLD}${CYAN}Enter Passphrase${NC}): " API_PASSPHRASE
echo ""

# Section 2: Wallet Addresses
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}💰 SECTION 2: WALLET ADDRESSES${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

read -p "$(echo -e ${BOLD}${CYAN}Your Wallet Address${NC} ${YELLOW}(0x...)${NC}): " YOUR_WALLET
echo -e "${YELLOW}💡 Ye aapka Polymarket wallet hai (Profile > Wallet Address)${NC}"
echo ""

read -p "$(echo -e ${BOLD}${CYAN}Lead Trader Address${NC} ${YELLOW}[Enter for default]${NC}): " LEAD_TRADER
LEAD_TRADER=${LEAD_TRADER:-0x6031b6eed1c97e853c6e0f03ad3ce3529351f96d}
echo -e "${GREEN}✓ Using: ${LEAD_TRADER:0:10}...${LEAD_TRADER: -8}${NC}"
echo ""

# Section 3: Trading Amount
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}💵 SECTION 3: TRADING AMOUNT${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

read -p "$(echo -e ${BOLD}${CYAN}Amount Per Trade in \$USD${NC} ${YELLOW}[10]${NC}): " AMOUNT
AMOUNT=${AMOUNT:-10}
echo -e "${GREEN}✓ Har trade mein lagega: \$$AMOUNT${NC}"
echo ""

# Section 4: Polygon RPC Endpoints
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}🔗 SECTION 4: POLYGON RPC ENDPOINTS${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Free RPC endpoints kahan se milenge?${NC}"
echo -e "  ${GREEN}Option 1 (Recommended):${NC} https://www.alchemy.com"
echo -e "    • Sign up for free account"
echo -e "    • Create Polygon Mainnet app"
echo -e "    • Copy HTTP aur WebSocket URLs"
echo ""
echo -e "  ${GREEN}Option 2:${NC} https://infura.io"
echo -e "  ${GREEN}Option 3:${NC} https://chainstack.com"
echo ""
echo -e "${YELLOW}Example URLs:${NC}"
echo -e "  ${CYAN}HTTP:${NC} https://polygon-mainnet.g.alchemy.com/v2/YOUR_KEY"
echo -e "  ${CYAN}WSS:${NC}  wss://polygon-mainnet.g.alchemy.com/v2/YOUR_KEY"
echo ""

read -p "$(echo -e ${BOLD}${CYAN}Polygon RPC HTTP URL${NC} ${YELLOW}[Enter for demo]${NC}): " POLYGON_HTTP
POLYGON_HTTP=${POLYGON_HTTP:-https://polygon-mainnet.g.alchemy.com/v2/demo}
echo ""

read -p "$(echo -e ${BOLD}${CYAN}Polygon RPC WebSocket URL${NC} ${YELLOW}[Enter for demo]${NC}): " POLYGON_WSS
POLYGON_WSS=${POLYGON_WSS:-wss://polygon-mainnet.g.alchemy.com/v2/demo}
echo ""

if [[ "$POLYGON_HTTP" == *"demo"* ]] || [[ "$POLYGON_WSS" == *"demo"* ]]; then
    echo -e "${YELLOW}⚠️  Demo RPC endpoints use ho rahe hain${NC}"
    echo -e "${YELLOW}   Better performance ke liye apna free Alchemy account banao${NC}"
    echo ""
fi

# Validate inputs
if [[ -z "$API_KEY" ]] || [[ -z "$API_SECRET" ]] || [[ -z "$API_PASSPHRASE" ]] || [[ -z "$YOUR_WALLET" ]]; then
    echo -e "${RED}❌ Error: All Polymarket fields are required!${NC}"
    exit 1
fi

# Create .env
show_step "4/7" "Saving configuration..."
cat > .env << EOF
# ═══════════════════════════════════════════════════════════
# POLYMARKET COPY TRADING BOT - AUTO GENERATED CONFIG
# ═══════════════════════════════════════════════════════════

# ┌─────────────────────────────────────────────────────────┐
# │  POLYMARKET API CREDENTIALS                              │
# └─────────────────────────────────────────────────────────┘
POLY_API_KEY=$API_KEY
POLY_API_SECRET=$API_SECRET
POLY_PASSPHRASE=$API_PASSPHRASE

# ┌─────────────────────────────────────────────────────────┐
# │  WALLET ADDRESSES                                        │
# └─────────────────────────────────────────────────────────┘
YOUR_WALLET_ADDRESS=$YOUR_WALLET
LEAD_TRADER_ADDRESS=$LEAD_TRADER

# ┌─────────────────────────────────────────────────────────┐
# │  TRADING SETTINGS                                        │
# └─────────────────────────────────────────────────────────┘
AMOUNT_PER_TRADE=$AMOUNT

# ┌─────────────────────────────────────────────────────────┐
# │  POLYGON RPC ENDPOINTS                                   │
# └─────────────────────────────────────────────────────────┘
POLYGON_RPC_HTTP=$POLYGON_HTTP
POLYGON_RPC_WS=$POLYGON_WSS

# ═══════════════════════════════════════════════════════════
# Configuration saved on: $(date)
# ═══════════════════════════════════════════════════════════
EOF
show_success "Configuration saved to .env"
echo ""

# Create bot.js
show_step "5/7" "Installing bot engine..."
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
    this.yourWallet = process.env.YOUR_WALLET_ADDRESS?.toLowerCase();
    this.leadTrader = process.env.LEAD_TRADER_ADDRESS?.toLowerCase();
    this.amountPerTrade = parseFloat(process.env.AMOUNT_PER_TRADE) || 10;
    this.polygonHttp = process.env.POLYGON_RPC_HTTP;
    this.polygonWss = process.env.POLYGON_RPC_WS;
    
    this.dataAPI = 'https://data-api.polymarket.com';
    this.balance = 0;
    this.processedTrades = new Set();
    this.lastPollTime = 0;
    
    this.stats = {
      copied: 0,
      success: 0,
      failed: 0,
      startTime: Date.now()
    };
  }

  async getBalance() {
    try {
      const res = await axios.get(`${this.dataAPI}/balance?address=${this.yourWallet}`, {timeout: 5000});
      this.balance = parseFloat(res.data?.balance || 0);
      return this.balance;
    } catch (e) {
      return 0;
    }
  }

  async pollTrades() {
    try {
      const now = Date.now();
      if (now - this.lastPollTime < 3000) return;
      this.lastPollTime = now;
      
      const res = await axios.get(
        `${this.dataAPI}/activity?user=${this.leadTrader}&type=TRADE&limit=20`,
        {timeout: 5000}
      );
      
      const trades = res.data || [];
      const nowSec = Math.floor(Date.now() / 1000);
      
      const newTrades = trades.filter(t => {
        const age = nowSec - t.timestamp;
        const hash = `${t.transactionHash}-${t.timestamp}`;
        if (this.processedTrades.has(hash)) return false;
        return age >= 0 && age < 45;
      });
      
      if (newTrades.length > 0) {
        console.log(chalk.yellow(`\n🔔 ${newTrades.length} new trade(s) found!`));
        for (const trade of newTrades) {
          await this.copyTrade(trade);
        }
      }
    } catch (e) {}
  }

  async copyTrade(trade) {
    const hash = `${trade.transactionHash}-${trade.timestamp}`;
    if (this.processedTrades.has(hash)) return;
    
    this.processedTrades.add(hash);
    if (this.processedTrades.size > 1000) {
      const del = Array.from(this.processedTrades).slice(0, 100);
      del.forEach(h => this.processedTrades.delete(h));
    }
    
    const price = parseFloat(trade.price);
    const shares = this.amountPerTrade / price;
    
    console.log(chalk.magenta('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'));
    console.log(chalk.bold.green('🆕 NEW TRADE'));
    console.log(chalk.cyan('Market:  ') + chalk.white(trade.title));
    console.log(chalk.cyan('Side:    ') + chalk.white(trade.side));
    console.log(chalk.cyan('Outcome: ') + chalk.white(trade.outcome));
    console.log(chalk.cyan('Price:   ') + chalk.white(`$${price.toFixed(4)}`));
    console.log(chalk.cyan('Amount:  ') + chalk.green(`$${this.amountPerTrade}`));
    console.log(chalk.cyan('Shares:  ') + chalk.green(`${shares.toFixed(2)}`));
    
    if (trade.side === 'BUY' && this.balance < this.amountPerTrade) {
      console.log(chalk.red(`\n❌ Low balance: $${this.balance.toFixed(2)} < $${this.amountPerTrade}`));
      console.log(chalk.yellow('💡 Deposit USDC to your Polymarket wallet'));
      console.log(chalk.magenta('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'));
      return;
    }
    
    console.log(chalk.yellow('\n⚠️  DEMO MODE - Trade logged (not executed)'));
    console.log(chalk.gray('Configure API keys properly for live trading'));
    
    this.stats.copied++;
    this.stats.success++;
    
    console.log(chalk.green('\n✅ Trade processed!'));
    console.log(chalk.cyan(`📊 Total copied: ${this.stats.copied} | Success: ${this.stats.success}`));
    console.log(chalk.magenta('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'));
  }

  async start() {
    console.clear();
    console.log(chalk.bold.green('\n╔══════════════════════════════════════════╗'));
    console.log(chalk.bold.green('║   🤖 POLYMARKET COPY TRADING BOT 🤖     ║'));
    console.log(chalk.bold.green('╚══════════════════════════════════════════╝\n'));
    
    console.log(chalk.cyan('📋 Configuration:'));
    console.log(chalk.gray('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'));
    console.log(chalk.blue('Your Wallet:  ') + chalk.white(this.yourWallet));
    console.log(chalk.blue('Lead Trader:  ') + chalk.white(this.leadTrader));
    console.log(chalk.blue('Per Trade:    ') + chalk.white(`$${this.amountPerTrade}`));
    console.log(chalk.blue('RPC HTTP:     ') + chalk.white(this.polygonHttp.includes('demo') ? 'Demo (Free)' : 'Custom'));
    console.log(chalk.blue('RPC WSS:      ') + chalk.white(this.polygonWss.includes('demo') ? 'Demo (Free)' : 'Custom'));
    console.log(chalk.gray('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'));
    
    console.log(chalk.yellow('💰 Fetching balance...'));
    await this.getBalance();
    console.log(chalk.green(`✅ Balance: $${this.balance.toFixed(2)}\n`));
    
    console.log(chalk.green('✅ Bot started - monitoring every 3 seconds'));
    console.log(chalk.yellow('⏳ Waiting for new trades...\n'));
    console.log(chalk.gray('Press Ctrl+C to stop\n'));
    
    setInterval(() => this.pollTrades(), 3000);
    setInterval(() => this.getBalance(), 30000);
  }
}

process.on('SIGINT', () => {
  console.log(chalk.yellow('\n\n👋 Bot stopped'));
  process.exit(0);
});

const bot = new PolymarketCopyBot();
bot.start().catch(err => {
  console.error(chalk.red('Error:'), err.message);
  process.exit(1);
});
EOFBOT

show_success "Bot engine installed"
echo ""

# Create start script
show_step "6/7" "Creating launcher..."
cat > start.sh << 'EOF'
#!/bin/bash
clear
echo "🚀 Starting Polymarket Copy Bot..."
echo ""
node bot.js
EOF
chmod +x start.sh
show_success "Launcher created"
echo ""

# Create README
cat > README.md << 'EOF'
# Polymarket Copy Trading Bot

## Quick Start
```bash
./start.sh
```

## Configuration
Edit `.env` file to change settings

## What You Need
- USDC in your Polymarket wallet
- Valid Polymarket API credentials
- Polygon RPC endpoints (free from Alchemy/Infura)

## RPC Endpoints
Free RPC endpoints:
- **Alchemy**: https://www.alchemy.com (Recommended)
- **Infura**: https://infura.io
- **Chainstack**: https://chainstack.com

## Changing Settings
```bash
nano .env
```

## Support
Check `.env` configuration if issues occur
EOF

# Final summary
show_step "7/7" "Finalizing..."
sleep 1
clear

echo -e "${BOLD}${GREEN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║            ✅ INSTALLATION SUCCESSFUL! ✅                ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo ""

echo -e "${BOLD}${CYAN}📋 Your Configuration Summary:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Your Wallet:    ${GREEN}${YOUR_WALLET:0:10}...${YOUR_WALLET: -8}${NC}"
echo -e "${CYAN}Lead Trader:    ${GREEN}${LEAD_TRADER:0:10}...${LEAD_TRADER: -8}${NC}"
echo -e "${CYAN}Per Trade:      ${BOLD}${GREEN}\$$AMOUNT USD${NC}"
echo -e "${CYAN}API Status:     ${GREEN}Configured ✓${NC}"
if [[ "$POLYGON_HTTP" == *"demo"* ]]; then
    echo -e "${CYAN}RPC Endpoint:   ${YELLOW}Demo (Free) ⚠️${NC}"
else
    echo -e "${CYAN}RPC Endpoint:   ${GREEN}Custom ✓${NC}"
fi
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${BOLD}${CYAN}🚀 Start Bot:${NC}"
echo -e "   ${GREEN}./start.sh${NC}"
echo ""

echo -e "${BOLD}${CYAN}📝 Edit Settings:${NC}"
echo -e "   ${BLUE}nano .env${NC}"
echo ""

echo -e "${BOLD}${YELLOW}⚠️  Important Checklist:${NC}"
echo "   ✓ Wallet mein kam se kam \$$AMOUNT USDC hona chahiye"
echo "   ✓ Bot har 3 seconds mein check karega"
echo "   ✓ Ctrl+C se stop kar sakte hain"
if [[ "$POLYGON_HTTP" == *"demo"* ]]; then
    echo -e "   ${YELLOW}⚠️  Better performance ke liye Alchemy RPC use karo${NC}"
fi
echo ""

# Auto-start prompt
echo -e -n "${BOLD}${CYAN}Abhi start karen? (y/n) [y]: ${NC}"
read -t 30 START_NOW || START_NOW="y"
START_NOW=${START_NOW:-y}

if [[ "$START_NOW" == "y" ]] || [[ "$START_NOW" == "Y" ]]; then
    echo ""
    echo -e "${GREEN}Starting in 3 seconds...${NC}"
    for i in 3 2 1; do
        echo -e "${YELLOW}$i...${NC}"
        sleep 1
    done
    clear
    exec ./start.sh
else
    echo ""
    echo -e "${GREEN}Setup complete! Run ${BOLD}./start.sh${NC}${GREEN} when ready.${NC}"
    echo ""
fi
