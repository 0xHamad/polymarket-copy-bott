#!/bin/bash

# ============================================
# POLYMARKET COPY TRADING BOT
# One-Line Quick Installer
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

clear

echo -e "${PURPLE}"
cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║    🤖 POLYMARKET ULTRA FAST COPY TRADING BOT 🤖           ║
║                                                            ║
║    One-Click Installer                                     ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check if Node.js installed
echo -e "${CYAN}🔍 Checking system requirements...${NC}"
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js not found!${NC}"
    echo -e "${YELLOW}Please install Node.js from: https://nodejs.org${NC}"
    echo -e "${YELLOW}After installation, run this command again.${NC}"
    exit 1
fi

NODE_VERSION=$(node -v)
echo -e "${GREEN}✅ Node.js found: $NODE_VERSION${NC}"

# Check if Git installed
if ! command -v git &> /dev/null; then
    echo -e "${RED}❌ Git not found!${NC}"
    echo -e "${YELLOW}Installing Git...${NC}"
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt-get update && sudo apt-get install -y git
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install git
    fi
fi

# Clone repository
echo ""
echo -e "${CYAN}📥 Cloning repository...${NC}"
REPO_DIR="polymarket-copy-bott"

if [ -d "$REPO_DIR" ]; then
    echo -e "${YELLOW}⚠️  Directory exists. Removing...${NC}"
    rm -rf "$REPO_DIR"
fi

git clone https://github.com/0xHamad/polymarket-copy-bott.git
cd "$REPO_DIR"

echo -e "${GREEN}✅ Repository cloned${NC}"

# Install dependencies
echo ""
echo -e "${CYAN}📦 Installing dependencies (this may take 1-2 minutes)...${NC}"
npm install --silent

echo -e "${GREEN}✅ Dependencies installed${NC}"

# Create .env from example
echo ""
echo -e "${CYAN}📝 Creating configuration file...${NC}"
if [ -f ".env.example" ]; then
    cp .env.example .env
    echo -e "${GREEN}✅ .env file created${NC}"
else
    echo -e "${YELLOW}⚠️  .env.example not found, creating basic .env${NC}"
    cat > .env << 'EOF'
# Polymarket API Credentials
POLY_API_KEY=your-api-key-here
POLY_API_SECRET=your-api-secret-here
POLY_PASSPHRASE=your-passphrase-here

# Lead Trader
LEAD_TRADER_ADDRESS=0x1234567890abcdef1234567890abcdef12345678

# Trading Settings
COPY_PERCENTAGE=10
EOF
fi

# Make scripts executable
echo ""
echo -e "${CYAN}🔧 Setting up scripts...${NC}"
if [ -f "start.sh" ]; then
    chmod +x start.sh
fi
if [ -f "install.sh" ]; then
    chmod +x install.sh
fi

# Success message
clear
echo -e "${GREEN}"
cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║            ✅ INSTALLATION SUCCESSFUL! ✅                  ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${CYAN}📁 Installation Location: ${GREEN}$(pwd)${NC}"
echo ""
echo -e "${YELLOW}⚙️  NEXT STEPS:${NC}"
echo ""
echo -e "${GREEN}1. Configure your credentials:${NC}"
echo -e "   ${CYAN}nano .env${NC}"
echo ""
echo -e "   ${YELLOW}You need to add:${NC}"
echo -e "   • Polymarket API Key"
echo -e "   • API Secret"
echo -e "   • Passphrase"
echo -e "   • Lead Trader Address"
echo ""
echo -e "${GREEN}2. Start the bot:${NC}"
echo -e "   ${CYAN}npm start${NC}"
echo -e "   ${GRAY}or${NC}"
echo -e "   ${CYAN}./start.sh${NC}"
echo ""
echo -e "${RED}⚠️  IMPORTANT SECURITY:${NC}"
echo -e "   • Never share your .env file"
echo -e "   • Start with 5-10% copy percentage"
echo -e "   • Monitor bot regularly"
echo ""
echo -e "${BLUE}📚 For help, see: ${CYAN}README.md${NC}"
echo ""
echo -e "${PURPLE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Ask if user wants to edit .env now
read -p "$(echo -e ${YELLOW}Do you want to configure .env now? [y/N]: ${NC})" EDIT_NOW

if [[ $EDIT_NOW =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${CYAN}Opening .env editor...${NC}"
    echo ""
    
    if command -v nano &> /dev/null; then
        nano .env
    elif command -v vim &> /dev/null; then
        vim .env
    elif command -v vi &> /dev/null; then
        vi .env
    else
        echo -e "${YELLOW}No text editor found. Please edit .env manually.${NC}"
    fi
fi

# Ask if user wants to start bot now
echo ""
read -p "$(echo -e ${YELLOW}Start bot now? [y/N]: ${NC})" START_NOW

if [[ $START_NOW =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${GREEN}🚀 Starting bot...${NC}"
    echo ""
    npm start
else
    echo ""
    echo -e "${CYAN}Run '${GREEN}npm start${CYAN}' when ready!${NC}"
    echo ""
fi
