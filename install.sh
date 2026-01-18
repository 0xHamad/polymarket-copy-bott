#!/bin/bash

# ============================================
# POLYMARKET COPY TRADING BOT
# Fully Automated Interactive Installer
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m'

clear

echo -e "${PURPLE}"
cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║    🤖 POLYMARKET ULTRA FAST COPY TRADING BOT 🤖           ║
║                                                            ║
║    Fully Automated One-Click Installer                     ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check Node.js
echo -e "${CYAN}🔍 Checking system requirements...${NC}"
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js not found!${NC}"
    echo -e "${YELLOW}Installing Node.js...${NC}"
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install node
    fi
fi

NODE_VERSION=$(node -v)
echo -e "${GREEN}✅ Node.js: $NODE_VERSION${NC}"

# Check Git
if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}Installing Git...${NC}"
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt-get install -y git
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install git
    fi
fi

# Clone repository
echo ""
echo -e "${CYAN}📥 Downloading bot...${NC}"
REPO_DIR="polymarket-copy-bott"

if [ -d "$REPO_DIR" ]; then
    rm -rf "$REPO_DIR"
fi

git clone https://github.com/0xHamad/polymarket-copy-bott.git > /dev/null 2>&1
cd "$REPO_DIR"

echo -e "${GREEN}✅ Downloaded${NC}"

# Install dependencies
echo -e "${CYAN}📦 Installing dependencies...${NC}"
npm install --silent > /dev/null 2>&1
echo -e "${GREEN}✅ Installed${NC}"

# Interactive Configuration
clear
echo -e "${PURPLE}"
cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║              CONFIGURATION SETUP                           ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo ""
echo -e "${YELLOW}Please provide your Polymarket credentials:${NC}"
echo -e "${BLUE}(Get them from: https://polymarket.com → Settings → API)${NC}"
echo ""

# Get API credentials
echo -e "${GREEN}Enter API Key: ${NC}"
read API_KEY
while [[ -z "$API_KEY" ]]; do
    echo -e "${RED}API Key cannot be empty!${NC}"
    echo -e "${GREEN}Enter API Key: ${NC}"
    read API_KEY
done

echo ""
echo -e "${GREEN}Enter API Secret: ${NC}"
read -s API_SECRET
echo ""
while [[ -z "$API_SECRET" ]]; do
    echo -e "${RED}API Secret cannot be empty!${NC}"
    echo -e "${GREEN}Enter API Secret: ${NC}"
    read -s API_SECRET
    echo ""
done

echo ""
echo -e "${GREEN}Enter Passphrase: ${NC}"
read -s PASSPHRASE
echo ""
while [[ -z "$PASSPHRASE" ]]; do
    echo -e "${RED}Passphrase cannot be empty!${NC}"
    echo -e "${GREEN}Enter Passphrase: ${NC}"
    read -s PASSPHRASE
    echo ""
done

# Lead Trader Address
echo ""
echo -e "${YELLOW}Lead Trader Configuration:${NC}"
echo -e "${BLUE}Enter the wallet address of the trader you want to copy${NC}"
echo ""
echo -e "${GREEN}Lead Trader Address (0x...): ${NC}"
read LEAD_TRADER

while [[ -z "$LEAD_TRADER" ]] || [[ ! "$LEAD_TRADER" =~ ^0x[a-fA-F0-9]{40}$ ]]; do
    echo -e "${RED}Invalid address! Must start with 0x and be 42 characters${NC}"
    echo -e "${GREEN}Lead Trader Address (0x...): ${NC}"
    read LEAD_TRADER
done

# Copy Percentage
echo ""
echo -e "${YELLOW}Trading Settings:${NC}"
echo -e "${BLUE}What % of your balance to use per trade?${NC}"
echo -e "${GRAY}Recommended: 5-10% for beginners, 10-15% for experienced${NC}"
echo ""
echo -e "${GREEN}Copy Percentage (1-25): ${NC}"
read COPY_PCT

# Validate percentage
while [[ ! "$COPY_PCT" =~ ^[0-9]+$ ]] || [[ "$COPY_PCT" -lt 1 ]] || [[ "$COPY_PCT" -gt 25 ]]; do
    echo -e "${RED}Please enter a number between 1 and 25${NC}"
    echo -e "${GREEN}Copy Percentage (1-25): ${NC}"
    read COPY_PCT
done

# Create .env file
echo ""
echo -e "${CYAN}📝 Saving configuration...${NC}"

cat > .env << EOF
# Polymarket API Credentials
POLY_API_KEY=$API_KEY
POLY_API_SECRET=$API_SECRET
POLY_PASSPHRASE=$PASSPHRASE

# Lead Trader to Copy
LEAD_TRADER_ADDRESS=$LEAD_TRADER

# Trading Settings
COPY_PERCENTAGE=$COPY_PCT
EOF

echo -e "${GREEN}✅ Configuration saved to .env${NC}"

# Make scripts executable
if [ -f "start.sh" ]; then
    chmod +x start.sh
fi

# Success screen
clear
echo -e "${GREEN}"
cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║            ✅ INSTALLATION COMPLETE! ✅                    ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${CYAN}📊 Your Configuration:${NC}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Lead Trader:${NC} ${GREEN}$LEAD_TRADER${NC}"
echo -e "${BLUE}Copy Percentage:${NC} ${GREEN}$COPY_PCT%${NC}"
echo -e "${BLUE}Location:${NC} ${GREEN}$(pwd)${NC}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${YELLOW}🚀 QUICK START COMMANDS:${NC}"
echo ""
echo -e "  ${CYAN}Start Bot:${NC}     ${GREEN}npm start${NC}"
echo -e "  ${CYAN}Or:${NC}            ${GREEN}./start.sh${NC}"
echo -e "  ${CYAN}Edit Config:${NC}   ${GREEN}nano .env${NC}"
echo ""

echo -e "${RED}⚠️  SECURITY REMINDERS:${NC}"
echo -e "  • Your API credentials are stored in .env"
echo -e "  • Never share the .env file"
echo -e "  • Never commit .env to GitHub"
echo -e "  • Monitor the bot regularly"
echo -e "  • Start with small amounts"
echo ""

echo -e "${BLUE}📚 Need help? Check README.md${NC}"
echo ""
echo -e "${PURPLE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Auto-start option
echo -e "${YELLOW}Start the bot now? [Y/n]: ${NC}"
read START_NOW
START_NOW=${START_NOW:-Y}

if [[ $START_NOW =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${GREEN}🚀 Starting Polymarket Copy Trading Bot...${NC}"
    echo ""
    echo -e "${YELLOW}Press Ctrl+C to stop the bot${NC}"
    echo ""
    sleep 2
    npm start
else
    echo ""
    echo -e "${CYAN}Run '${GREEN}npm start${CYAN}' when you're ready!${NC}"
    echo ""
fi
