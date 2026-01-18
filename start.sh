#!/bin/bash

# Polymarket Copy Trading Bot - Start Script
# Linux/Mac

clear

echo "🤖 Starting Polymarket Copy Trading Bot..."
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found!"
    echo "Please copy .env.example to .env and configure it"
    exit 1
fi

# Check if node_modules exists
if [ ! -d node_modules ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

# Start the bot
node bot.js
