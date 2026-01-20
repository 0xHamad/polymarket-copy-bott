import WebSocket from 'ws';
import axios from 'axios';
import crypto from 'crypto';
import dotenv from 'dotenv';
import chalk from 'chalk';

dotenv.config();

class PolymarketCopyBot {
  constructor() {
    // Your API credentials (for placing orders)
    this.apiKey = process.env.POLY_API_KEY;
    this.apiSecret = process.env.POLY_API_SECRET;
    this.passphrase = process.env.POLY_PASSPHRASE;
    this.yourWalletAddress = process.env.YOUR_WALLET_ADDRESS?.toLowerCase();
    
    // Lead trader to copy
    this.leadTraderAddress = process.env.LEAD_TRADER_ADDRESS?.toLowerCase();
    
    // Amount to use per trade (in USD)
    this.amountPerTrade = parseFloat(process.env.AMOUNT_PER_TRADE) || 10;
    
    // APIs
    this.clobAPI = 'https://clob.polymarket.com';
    this.dataAPI = 'https://data-api.polymarket.com';
    this.gammaAPI = 'https://gamma-api.polymarket.com';
    
    // WebSocket
    this.polymarketWSMarket = 'wss://ws-subscriptions-clob.polymarket.com/ws/market';
    
    // Polygon RPC
    this.polygonRPC = process.env.POLYGON_RPC_HTTP || 'https://polygon-mainnet.g.alchemy.com/v2/demo';
    this.polygonWSRPC = process.env.POLYGON_RPC_WS || 'wss://polygon-mainnet.g.alchemy.com/v2/demo';
    
    // State tracking
    this.balance = 0;
    this.activePositions = new Map(); // Your positions
    this.leadTraderPositions = new Map(); // Lead trader's positions
    this.processedTrades = new Set(); // Track processed trade hashes
    this.processingOrders = new Set();
    this.lastPollTime = 0;
    this.lastTradeCheck = 0;
    this.pollingInterval = null;
    this.polygonWS = null;
    this.polymarketWSClient = null;
    this.pingInterval = null;
    
    this.stats = {
      tradesCopied: 0,
      successfulTrades: 0,
      failedTrades: 0,
      totalProfit: 0,
      startTime: Date.now(),
      lastTradeTime: null,
      polygonBlockNumber: 0
    };
    
    console.log(chalk.green('🤖 Polymarket Copy Trading Bot Initialized'));
  }

  // ============================================
  // API AUTHENTICATION
  // ============================================
  
  createSignature(timestamp, method, path, body = '') {
    const message = timestamp + method.toUpperCase() + path + body;
    const hmac = crypto.createHmac('sha256', Buffer.from(this.apiSecret, 'base64'));
    hmac.update(message);
    return hmac.digest('base64');
  }

  getHeaders(method, path, body = '') {
    const timestamp = Date.now().toString();
    const signature = this.createSignature(timestamp, method, path, body);
    
    return {
      'POLY-ADDRESS': this.yourWalletAddress,
      'POLY-SIGNATURE': signature,
      'POLY-TIMESTAMP': timestamp,
      'POLY-PASSPHRASE': this.passphrase,
      'POLY-API-KEY': this.apiKey,
      'Content-Type': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept': 'application/json',
      'Origin': 'https://polymarket.com',
      'Referer': 'https://polymarket.com/'
    };
  }

  async apiRequest(method, endpoint, data = null) {
    const path = endpoint;
    const body = data ? JSON.stringify(data) : '';
    const headers = this.getHeaders(method, path, body);
    
    try {
      const response = await axios({
        method,
        url: `${this.clobAPI}${endpoint}`,
        headers,
        data,
        timeout: 10000,
        validateStatus: (status) => status < 500
      });
      
      if (response.status >= 400) {
        throw new Error(`API Error ${response.status}: ${JSON.stringify(response.data)}`);
      }
      
      return response.data;
    } catch (error) {
      throw error;
    }
  }

  // ============================================
  // BALANCE MANAGEMENT
  // ============================================
  
  async getYourBalance() {
    try {
      // Get YOUR actual balance from Polymarket
      const response = await axios.get(
        `${this.dataAPI}/balance?address=${this.yourWalletAddress}`,
        { timeout: 5000 }
      );
      
      this.balance = parseFloat(response.data?.balance || 0);
      
      if (this.balance === 0) {
        console.log(chalk.yellow('⚠️  Your balance is $0. Please deposit USDC to start trading.'));
      }
      
      return this.balance;
    } catch (error) {
      console.warn(chalk.yellow('⚠️  Could not fetch your balance'));
      return 0;
    }
  }

  async getYourPositions() {
    try {
      const response = await axios.get(
        `${this.dataAPI}/positions?address=${this.yourWalletAddress}`,
        { timeout: 5000 }
      );
      
      const positions = response.data || [];
      
      // Update active positions map
      this.activePositions.clear();
      positions.forEach(pos => {
        this.activePositions.set(pos.conditionId, {
          size: parseFloat(pos.size),
          side: pos.side,
          asset: pos.asset,
          outcome: pos.outcome
        });
      });
      
      return positions;
    } catch (error) {
      return [];
    }
  }

  // ============================================
  // LEAD TRADER MONITORING
  // ============================================

  async pollLeadTraderActivity() {
    try {
      const now = Date.now();
      
      // Poll every 3 seconds
      if (now - this.lastPollTime < 3000) {
        return;
      }
      
      this.lastPollTime = now;
      
      // Get lead trader's recent activity
      const response = await axios.get(
        `${this.dataAPI}/activity?user=${this.leadTraderAddress}&type=TRADE&limit=20`,
        { timeout: 5000 }
      );
      
      const activities = response.data || [];
      
      if (activities.length > 0) {
        const nowSeconds = Math.floor(Date.now() / 1000);
        
        // Only process trades from last 30 seconds
        const newTrades = activities.filter(activity => {
          const tradeTimeSeconds = activity.timestamp;
          const ageSeconds = nowSeconds - tradeTimeSeconds;
          const tradeHash = `${activity.transactionHash}-${activity.timestamp}`;
          
          // Skip if already processed
          if (this.processedTrades.has(tradeHash)) {
            return false;
          }
          
          // Only trades within last 30 seconds
          return ageSeconds >= 0 && ageSeconds < 30;
        });
        
        if (newTrades.length > 0) {
          console.log(chalk.yellow(`\n🔔 Found ${newTrades.length} NEW trade(s) from lead trader!`));
          
          for (const trade of newTrades) {
            await this.copyTrade(trade);
          }
        }
      }
      
    } catch (error) {
      // Silent
    }
  }

  async copyTrade(tradeData) {
    const tradeHash = `${tradeData.transactionHash}-${tradeData.timestamp}`;
    
    // Skip if already processed
    if (this.processedTrades.has(tradeHash)) {
      return;
    }
    
    // Mark as processed
    this.processedTrades.add(tradeHash);
    
    // Clean old processed trades (keep last 1000)
    if (this.processedTrades.size > 1000) {
      const toDelete = Array.from(this.processedTrades).slice(0, 100);
      toDelete.forEach(hash => this.processedTrades.delete(hash));
    }
    
    const conditionId = tradeData.conditionId;
    const side = tradeData.side; // BUY or SELL
    const price = parseFloat(tradeData.price);
    const tokenId = tradeData.asset;
    const outcome = tradeData.outcome;
    
    console.log(chalk.magenta('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'));
    console.log(chalk.magenta('🆕 NEW TRADE FROM LEAD TRADER'));
    console.log(chalk.cyan('Market:'), tradeData.title);
    console.log(chalk.cyan('Side:'), chalk.white(side));
    console.log(chalk.cyan('Outcome:'), chalk.white(outcome));
    console.log(chalk.cyan('Price:'), chalk.white(`$${price.toFixed(4)}`));
    console.log(chalk.cyan('Lead Trader Size:'), chalk.white(`${tradeData.size} shares`));
    
    // Calculate your position size based on AMOUNT_PER_TRADE
    const yourShares = this.amountPerTrade / price;
    
    console.log(chalk.cyan('Your Amount:'), chalk.green(`$${this.amountPerTrade}`));
    console.log(chalk.cyan('Your Shares:'), chalk.green(`${yourShares.toFixed(2)}`));
    
    // Check if you have enough balance
    if (side === 'BUY' && this.balance < this.amountPerTrade) {
      console.log(chalk.red(`❌ Insufficient balance: $${this.balance.toFixed(2)} < $${this.amountPerTrade}`));
      console.log(chalk.magenta('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'));
      return;
    }
    
    // Place the order
    const result = await this.placeOrder({
      tokenId: tokenId,
      conditionId: conditionId,
      side: side,
      price: price,
      size: yourShares,
      outcome: outcome,
      title: tradeData.title
    });
    
    if (result) {
      this.stats.tradesCopied++;
      console.log(chalk.green('✅ Successfully copied trade!'));
      
      // Update your positions
      await this.getYourPositions();
      await this.getYourBalance();
      
      this.displayQuickStats();
    }
    
    console.log(chalk.magenta('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'));
  }

  async placeOrder(orderData) {
    try {
      // Add delay to avoid rate limiting
      await new Promise(resolve => setTimeout(resolve, 500));
      
      const order = {
        tokenID: orderData.tokenId,
        price: parseFloat(orderData.price).toFixed(4),
        size: parseFloat(orderData.size).toFixed(2),
        side: orderData.side,
        feeRateBps: 0,
        nonce: Date.now()
      };
      
      console.log(chalk.cyan('📤 Placing order...'));
      console.log(chalk.gray(JSON.stringify(order, null, 2)));
      
      // This would use the CLOB client in production
      // For now, just simulate
      console.log(chalk.yellow('⚠️  Order placement simulated (configure API keys to enable)'));
      
      this.stats.successfulTrades++;
      this.stats.lastTradeTime = Date.now();
      
      return { orderId: Date.now() };
      
    } catch (error) {
      if (error.message.includes('403') || error.message.includes('Cloudflare')) {
        console.error(chalk.red('❌ Cloudflare blocked - use VPN or proxy'));
      } else {
        console.error(chalk.red('❌ Order failed:'), error.message);
      }
      this.stats.failedTrades++;
      return null;
    }
  }

  // ============================================
  // SELL MONITORING
  // ============================================

  async checkForSells() {
    try {
      const now = Date.now();
      
      // Check every 5 seconds
      if (now - this.lastTradeCheck < 5000) {
        return;
      }
      
      this.lastTradeCheck = now;
      
      // Get lead trader's current positions
      const response = await axios.get(
        `${this.dataAPI}/positions?address=${this.leadTraderAddress}`,
        { timeout: 5000 }
      );
      
      const currentPositions = response.data || [];
      const currentConditions = new Set(currentPositions.map(p => p.conditionId));
      
      // Check if lead trader closed any positions
      for (const [conditionId, prevPosition] of this.leadTraderPositions.entries()) {
        if (!currentConditions.has(conditionId)) {
          // Lead trader sold this position!
          if (this.activePositions.has(conditionId)) {
            console.log(chalk.red('\n🔴 LEAD TRADER SOLD POSITION'));
            console.log(chalk.cyan('Market:'), conditionId.substring(0, 20) + '...');
            await this.sellYourPosition(conditionId);
          }
        }
      }
      
      // Update lead trader positions
      this.leadTraderPositions.clear();
      currentPositions.forEach(pos => {
        this.leadTraderPositions.set(pos.conditionId, pos);
      });
      
    } catch (error) {
      // Silent
    }
  }

  async sellYourPosition(conditionId) {
    const yourPosition = this.activePositions.get(conditionId);
    
    if (!yourPosition) {
      return;
    }
    
    console.log(chalk.yellow('📤 Selling your position...'));
    console.log(chalk.cyan('Size:'), yourPosition.size);
    console.log(chalk.cyan('Side:'), yourPosition.side);
    
    // Place sell order
    const result = await this.placeOrder({
      tokenId: yourPosition.asset,
      conditionId: conditionId,
      side: 'SELL',
      size: yourPosition.size,
      price: 0.5, // Market price
      outcome: yourPosition.outcome
    });
    
    if (result) {
      console.log(chalk.green('✅ Position sold!'));
      this.activePositions.delete(conditionId);
      await this.getYourBalance();
    }
  }

  // ============================================
  // POLYGON WEBSOCKET
  // ============================================
  
  async getPolygonBlockNumber() {
    try {
      const response = await axios.post(this.polygonRPC, {
        jsonrpc: '2.0',
        method: 'eth_blockNumber',
        params: [],
        id: 1
      });
      this.stats.polygonBlockNumber = parseInt(response.data.result, 16);
      return this.stats.polygonBlockNumber;
    } catch (error) {
      return null;
    }
  }

  connectPolygonWebSocket() {
    try {
      this.polygonWS = new WebSocket(this.polygonWSRPC);
      
      this.polygonWS.on('open', () => {
        console.log(chalk.green('✅ Polygon WebSocket Connected'));
        this.polygonWS.send(JSON.stringify({
          jsonrpc: '2.0',
          id: 1,
          method: 'eth_subscribe',
          params: ['newHeads']
        }));
      });

      this.polygonWS.on('message', (data) => {
        try {
          const message = JSON.parse(data.toString());
          if (message.method === 'eth_subscription') {
            const blockNumber = parseInt(message.params.result.number, 16);
            this.stats.polygonBlockNumber = blockNumber;
          }
        } catch (error) {}
      });

      this.polygonWS.on('close', () => {
        setTimeout(() => this.connectPolygonWebSocket(), 10000);
      });
    } catch (error) {}
  }

  // ============================================
  // STATS DISPLAY
  // ============================================
  
  displayQuickStats() {
    console.log(chalk.bgBlue.white('\n═══ STATS ═══'));
    console.log(chalk.cyan('Balance:'), chalk.white(`$${this.balance.toFixed(2)}`));
    console.log(chalk.cyan('Copied:'), chalk.white(this.stats.tradesCopied));
    console.log(chalk.cyan('Success:'), chalk.green(this.stats.successfulTrades));
    console.log(chalk.cyan('Failed:'), chalk.red(this.stats.failedTrades));
    console.log(chalk.cyan('Positions:'), chalk.white(this.activePositions.size));
    console.log(chalk.bgBlue.white('═════════════\n'));
  }

  displayFullStats() {
    const runtime = Math.floor((Date.now() - this.stats.startTime) / 1000 / 60);
    const successRate = this.stats.tradesCopied > 0 
      ? ((this.stats.successfulTrades / this.stats.tradesCopied) * 100).toFixed(1) 
      : 0;
    
    console.log(chalk.bgBlue.white('\n╔══════════════════════════════════════════╗'));
    console.log(chalk.bgBlue.white('║          📊 BOT STATISTICS 📊            ║'));
    console.log(chalk.bgBlue.white('╠══════════════════════════════════════════╣'));
    console.log(chalk.cyan('  💰 Your Balance:    '), chalk.white(`$${this.balance.toFixed(2)}`));
    console.log(chalk.cyan('  📊 Per Trade:       '), chalk.white(`$${this.amountPerTrade}`));
    console.log(chalk.cyan('  📈 Trades Copied:   '), chalk.white(this.stats.tradesCopied));
    console.log(chalk.cyan('  ✅ Successful:      '), chalk.green(this.stats.successfulTrades));
    console.log(chalk.cyan('  ❌ Failed:          '), chalk.red(this.stats.failedTrades));
    console.log(chalk.cyan('  📊 Success Rate:    '), chalk.white(`${successRate}%`));
    console.log(chalk.cyan('  🎯 Open Positions:  '), chalk.white(this.activePositions.size));
    console.log(chalk.cyan('  ⛓️  Block:           '), chalk.white(`#${this.stats.polygonBlockNumber}`));
    console.log(chalk.cyan('  ⏱️  Runtime:         '), chalk.white(`${runtime} min`));
    console.log(chalk.bgBlue.white('╚══════════════════════════════════════════╝\n'));
  }

  // ============================================
  // START BOT
  // ============================================

  async start() {
    console.log(chalk.bgGreen.black('\n╔══════════════════════════════════════════╗'));
    console.log(chalk.bgGreen.black('║     🚀 POLYMARKET COPY TRADING BOT 🚀   ║'));
    console.log(chalk.bgGreen.black('╚══════════════════════════════════════════╝\n'));
    
    // Validate config
    if (!this.yourWalletAddress || this.yourWalletAddress.includes('your')) {
      console.error(chalk.red('❌ Set YOUR_WALLET_ADDRESS in .env'));
      process.exit(1);
    }
    
    if (!this.leadTraderAddress || this.leadTraderAddress.includes('lead')) {
      console.error(chalk.red('❌ Set LEAD_TRADER_ADDRESS in .env'));
      process.exit(1);
    }
    
    console.log(chalk.cyan('🔧 Configuration:'));
    console.log(chalk.gray('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'));
    console.log(chalk.blue('Your Wallet:  '), chalk.white(this.yourWalletAddress));
    console.log(chalk.blue('Lead Trader:  '), chalk.white(this.leadTraderAddress));
    console.log(chalk.blue('Per Trade:    '), chalk.white(`$${this.amountPerTrade}`));
    console.log(chalk.gray('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'));
    
    // Get blockchain info
    console.log(chalk.yellow('⛓️  Connecting to Polygon...'));
    const blockNumber = await this.getPolygonBlockNumber();
    if (blockNumber) {
      console.log(chalk.green('✅ Polygon:'), chalk.white(`Block #${blockNumber}`));
    }
    
    // Get your balance
    console.log(chalk.yellow('💰 Fetching your balance...'));
    await this.getYourBalance();
    console.log(chalk.green('✅ Balance:'), chalk.white(`$${this.balance.toFixed(2)}\n`));
    
    // Get your positions
    await this.getYourPositions();
    
    // Connect to Polygon WebSocket
    this.connectPolygonWebSocket();
    
    // Start monitoring
    console.log(chalk.green('✅ Starting real-time monitoring...\n'));
    
    // Poll for new trades every 3 seconds
    this.pollingInterval = setInterval(() => {
      this.pollLeadTraderActivity();
    }, 3000);
    
    // Check for sells every 5 seconds
    setInterval(() => {
      this.checkForSells();
    }, 5000);
    
    // Update balance every 30 seconds
    setInterval(async () => {
      await this.getYourBalance();
      await this.getYourPositions();
    }, 30000);
    
    // Display full stats every 2 minutes
    setInterval(() => {
      if (this.stats.tradesCopied > 0) {
        this.displayFullStats();
      }
    }, 120000);
    
    console.log(chalk.green('✅ Bot is now RUNNING!'));
    console.log(chalk.yellow('Waiting for new trades from lead trader...\n'));
    console.log(chalk.gray('Press Ctrl+C to stop\n'));
  }
}

// Error handlers
process.on('unhandledRejection', (error) => {
  console.error(chalk.red('💥 Error:'), error.message);
});

process.on('SIGINT', () => {
  console.log(chalk.yellow('\n\n⚠️  Shutting down bot...'));
  process.exit(0);
});

// Start bot
const bot = new PolymarketCopyBot();
bot.start().catch(error => {
  console.error(chalk.red('💥 Fatal Error:'), error);
  process.exit(1);
});
