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
    this.leadTraderAddress = process.env.LEAD_TRADER_ADDRESS?.toLowerCase();
    this.copyPercentage = parseFloat(process.env.COPY_PERCENTAGE) / 100 || 0.10;
    
    // Polymarket API Endpoints (Updated 2025)
    this.clobAPI = 'https://clob.polymarket.com';
    this.dataAPI = 'https://gamma-api.polymarket.com';
    this.wsURL = 'wss://ws-subscriptions-clob.polymarket.com/ws/market';
    
    this.balance = 0;
    this.activePositions = new Map();
    this.processingOrders = new Set();
    
    this.stats = {
      tradesCopied: 0,
      successfulTrades: 0,
      failedTrades: 0,
      totalProfit: 0,
      startTime: Date.now(),
      lastTradeTime: null
    };
    
    console.log(chalk.green('🤖 Polymarket Copy Trading Bot Initialized'));
  }

  // HMAC-SHA256 signature for API authentication
  createSignature(timestamp, method, path, body = '') {
    const message = timestamp + method.toUpperCase() + path + body;
    const hmac = crypto.createHmac('sha256', Buffer.from(this.apiSecret, 'base64'));
    hmac.update(message);
    return hmac.digest('base64');
  }

  // Generate authentication headers
  getHeaders(method, path, body = '') {
    const timestamp = Date.now().toString();
    const signature = this.createSignature(timestamp, method, path, body);
    
    return {
      'POLY-ADDRESS': this.leadTraderAddress,
      'POLY-SIGNATURE': signature,
      'POLY-TIMESTAMP': timestamp,
      'POLY-PASSPHRASE': this.passphrase,
      'POLY-API-KEY': this.apiKey,
      'Content-Type': 'application/json'
    };
  }

  // Generic API request handler
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
      if (error.code === 'ECONNABORTED') {
        console.error(chalk.red('❌ Request timeout'));
      } else if (error.response) {
        console.error(chalk.red(`❌ API Error ${error.response.status}:`), error.response.data);
      } else {
        console.error(chalk.red('❌ Network Error:'), error.message);
      }
      throw error;
    }
  }

  // Get account balance
  async getBalance() {
    try {
      // Try wallet balance endpoint
      const response = await axios.get(
        `${this.dataAPI}/balance?address=${this.leadTraderAddress}`,
        { timeout: 5000 }
      );
      
      this.balance = parseFloat(response.data?.balance || response.data?.usdc || 0);
      
      if (this.balance === 0) {
        console.warn(chalk.yellow('⚠️  Balance is 0, using default $1000 for testing'));
        this.balance = 1000;
      }
      
      return this.balance;
    } catch (error) {
      console.warn(chalk.yellow('⚠️  Could not fetch balance, using default: $1000'));
      this.balance = 1000;
      return this.balance;
    }
  }

  // Place order on Polymarket
  async placeOrder(orderData) {
    const orderId = `${Date.now()}-${Math.random().toString(36).substring(7)}`;
    const orderKey = `${orderData.market}-${orderData.side}`;
    
    // Prevent duplicate orders
    if (this.processingOrders.has(orderKey)) {
      console.log(chalk.yellow('⏭️  Order already processing, skipping duplicate...'));
      return null;
    }
    
    this.processingOrders.add(orderKey);
    
    try {
      // Validate order data
      if (!orderData.market || !orderData.side || !orderData.size) {
        throw new Error('Invalid order data: missing required fields');
      }

      const order = {
        market: orderData.market,
        side: orderData.side.toUpperCase(),
        type: orderData.type || 'MARKET',
        size: parseFloat(orderData.size).toFixed(4),
        timeInForce: 'IOC', // Immediate or Cancel
        clientOrderId: orderId
      };

      // Add price for limit orders
      if (orderData.price && order.type === 'LIMIT') {
        order.price = parseFloat(orderData.price).toFixed(4);
      }
      
      console.log(chalk.cyan('📤 Placing order:'), {
        market: order.market.substring(0, 20) + '...',
        side: order.side,
        size: order.size,
        type: order.type
      });
      
      const result = await this.apiRequest('POST', '/order', order);
      
      console.log(chalk.green('✅ Order placed successfully!'));
      this.stats.successfulTrades++;
      this.stats.lastTradeTime = Date.now();
      
      return result;
    } catch (error) {
      console.error(chalk.red('❌ Order failed:'), error.message);
      this.stats.failedTrades++;
      return null;
    } finally {
      // Remove from processing after 2 seconds
      setTimeout(() => {
        this.processingOrders.delete(orderKey);
      }, 2000);
    }
  }

  // WebSocket connection handler
  connectWebSocket() {
    console.log(chalk.blue('🔌 Connecting to Polymarket WebSocket...'));
    
    try {
      this.ws = new WebSocket(this.wsURL);
      
      this.ws.on('open', () => {
        console.log(chalk.green('✅ WebSocket Connected!'));
        
        // Subscribe to market updates
        const subscription = {
          type: 'subscribe',
          channel: 'user',
          auth: {
            apiKey: this.apiKey,
            secret: this.apiSecret,
            passphrase: this.passphrase
          },
          markets: ['*']
        };
        
        this.ws.send(JSON.stringify(subscription));
        
        console.log(chalk.cyan(`👀 Monitoring Lead Trader: ${this.leadTraderAddress}`));
        console.log(chalk.gray('Waiting for trades...\n'));
      });

      this.ws.on('message', async (data) => {
        try {
          const message = this.parseWebSocketMessage(data);
          if (message) {
            await this.handleWebSocketMessage(message);
          }
        } catch (error) {
          // Ignore parse errors for binary/non-JSON data
          if (!error.message.includes('JSON')) {
            console.error(chalk.red('WebSocket processing error:'), error.message);
          }
        }
      });

      this.ws.on('error', (error) => {
        console.error(chalk.red('❌ WebSocket Error:'), error.message);
      });

      this.ws.on('close', (code, reason) => {
        console.log(chalk.yellow(`⚠️  WebSocket Disconnected (${code})`));
        console.log(chalk.gray('Reconnecting in 5 seconds...'));
        
        setTimeout(() => {
          this.connectWebSocket();
        }, 5000);
      });

      this.ws.on('ping', () => {
        this.ws.pong();
      });

    } catch (error) {
      console.error(chalk.red('Failed to create WebSocket:'), error.message);
      setTimeout(() => this.connectWebSocket(), 5000);
    }
  }

  // Parse WebSocket messages safely
  parseWebSocketMessage(data) {
    try {
      const dataStr = data.toString();
      
      // Skip non-JSON messages (pings, pongs, etc)
      if (!dataStr.startsWith('{') && !dataStr.startsWith('[')) {
        return null;
      }
      
      return JSON.parse(dataStr);
    } catch (error) {
      return null;
    }
  }

  // Handle WebSocket messages
  async handleWebSocketMessage(message) {
    // Filter: Only process lead trader's messages
    if (message.address && message.address.toLowerCase() !== this.leadTraderAddress) {
      return;
    }

    // Handle different event types
    const eventType = message.event || message.type;
    
    if (!eventType) return;

    console.log(chalk.gray(`📨 Event: ${eventType}`));

    switch (eventType) {
      case 'order':
      case 'ORDER_CREATED':
      case 'new_order':
        await this.copyNewOrder(message);
        break;
        
      case 'fill':
      case 'ORDER_FILLED':
      case 'trade':
        await this.handleOrderFilled(message);
        break;
        
      case 'close':
      case 'POSITION_CLOSED':
      case 'exit':
        await this.closePosition(message);
        break;

      case 'heartbeat':
      case 'subscribed':
        // Ignore system messages
        break;
        
      default:
        // Log unknown events for debugging
        console.log(chalk.gray(`Unknown event type: ${eventType}`));
    }
  }

  // Copy new order from lead trader
  async copyNewOrder(orderData) {
    console.log(chalk.magenta('\n🆕 LEAD TRADER ORDER DETECTED!'));
    console.log(chalk.cyan('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'));
    
    // Extract order details
    const market = orderData.market || orderData.market_id;
    const side = orderData.side || orderData.order_side;
    const price = parseFloat(orderData.price || orderData.fill_price || 0.5);
    
    if (!market || !side) {
      console.log(chalk.red('❌ Invalid order data, skipping'));
      return;
    }

    console.log(chalk.cyan('Market:'), market.substring(0, 40) + '...');
    console.log(chalk.cyan('Side:'), side);
    console.log(chalk.cyan('Price:'), `$${price.toFixed(4)}`);
    
    // Calculate position size
    const tradeAmount = this.balance * this.copyPercentage;
    const shares = tradeAmount / price;
    
    if (shares < 0.01) {
      console.log(chalk.yellow('⚠️  Position too small (< 0.01 shares), skipping'));
      return;
    }
    
    console.log(chalk.cyan('Your Position:'), `${shares.toFixed(2)} shares ($${tradeAmount.toFixed(2)})`);
    
    // Create copy order
    const yourOrder = {
      market: market,
      side: side,
      type: 'MARKET',
      size: shares.toFixed(4)
    };
    
    const result = await this.placeOrder(yourOrder);
    
    if (result) {
      this.stats.tradesCopied++;
      
      // Store active position
      this.activePositions.set(market, {
        orderId: result.orderId || result.id || Date.now(),
        side: side,
        shares: shares,
        entryPrice: price,
        timestamp: Date.now()
      });
      
      console.log(chalk.green('✅ Successfully copied trade!'));
      this.displayStats();
    }
    
    console.log(chalk.cyan('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'));
  }

  // Handle order fill notification
  async handleOrderFilled(fillData) {
    console.log(chalk.green('✅ Order FILLED'));
  }

  // Close position when lead trader exits
  async closePosition(positionData) {
    const market = positionData.market || positionData.market_id;
    
    console.log(chalk.red('\n🔴 CLOSING POSITION'));
    console.log(chalk.cyan('Market:'), market);
    
    const position = this.activePositions.get(market);
    
    if (!position) {
      console.log(chalk.yellow('⚠️  No active position found for this market'));
      return;
    }
    
    // Reverse side for closing
    const closeSide = position.side === 'BUY' ? 'SELL' : 'BUY';
    
    const closeOrder = {
      market: market,
      side: closeSide,
      type: 'MARKET',
      size: position.shares.toFixed(4)
    };
    
    const result = await this.placeOrder(closeOrder);
    
    if (result) {
      this.activePositions.delete(market);
      console.log(chalk.green('✅ Position closed successfully!'));
    }
  }

  // Display bot statistics
  displayStats() {
    const runtime = Math.floor((Date.now() - this.stats.startTime) / 1000 / 60);
    const successRate = this.stats.tradesCopied > 0 
      ? ((this.stats.successfulTrades / this.stats.tradesCopied) * 100).toFixed(1) 
      : 0;
    
    console.log(chalk.bgBlue.white('\n╔══════════════ BOT STATISTICS ══════════════╗'));
    console.log(chalk.cyan('💰 Balance:        '), chalk.white(`$${this.balance.toFixed(2)}`));
    console.log(chalk.cyan('📊 Trades Copied:  '), chalk.white(this.stats.tradesCopied));
    console.log(chalk.cyan('✅ Successful:     '), chalk.green(this.stats.successfulTrades));
    console.log(chalk.cyan('❌ Failed:         '), chalk.red(this.stats.failedTrades));
    console.log(chalk.cyan('📈 Success Rate:   '), chalk.white(`${successRate}%`));
    console.log(chalk.cyan('🎯 Active Positions:'), chalk.white(this.activePositions.size));
    console.log(chalk.cyan('⏱️  Runtime:        '), chalk.white(`${runtime} minutes`));
    console.log(chalk.bgBlue.white('╚════════════════════════════════════════════╝\n'));
  }

  // Start the bot
  async start() {
    console.log(chalk.bgGreen.black('\n╔════════════════════════════════════════════╗'));
    console.log(chalk.bgGreen.black('║     🚀 STARTING COPY TRADING BOT 🚀       ║'));
    console.log(chalk.bgGreen.black('╚════════════════════════════════════════════╝\n'));
    
    // Validate configuration
    if (!this.apiKey || !this.apiSecret || !this.passphrase) {
      console.error(chalk.red('❌ ERROR: API credentials missing!'));
      console.log(chalk.yellow('\nPlease check your .env file and ensure:'));
      console.log(chalk.gray('  - POLY_API_KEY is set'));
      console.log(chalk.gray('  - POLY_API_SECRET is set'));
      console.log(chalk.gray('  - POLY_PASSPHRASE is set'));
      process.exit(1);
    }
    
    if (!this.leadTraderAddress || this.leadTraderAddress.includes('1234567890')) {
      console.error(chalk.red('❌ ERROR: Invalid lead trader address!'));
      console.log(chalk.yellow('Please update LEAD_TRADER_ADDRESS in .env'));
      console.log(chalk.gray('Example: 0xabcdef1234567890abcdef1234567890abcdef12'));
      process.exit(1);
    }
    
    // Display configuration
    console.log(chalk.cyan('🔧 Configuration:'));
    console.log(chalk.gray('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'));
    console.log(chalk.blue('Lead Trader:  '), chalk.white(this.leadTraderAddress));
    console.log(chalk.blue('Copy %:       '), chalk.white(`${(this.copyPercentage * 100).toFixed(0)}%`));
    console.log(chalk.blue('API Endpoint: '), chalk.white(this.clobAPI));
    console.log(chalk.gray('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'));
    
    // Fetch balance
    console.log(chalk.yellow('💰 Fetching account balance...'));
    await this.getBalance();
    console.log(chalk.green('✅ Balance loaded:'), chalk.white(`$${this.balance.toFixed(2)}\n`));
    
    // Connect WebSocket
    this.connectWebSocket();
    
    // Update balance every 30 seconds
    setInterval(async () => {
      await this.getBalance();
    }, 30000);
    
    // Display stats every 2 minutes
    setInterval(() => {
      if (this.stats.tradesCopied > 0) {
        this.displayStats();
      }
    }, 120000);
    
    console.log(chalk.green('✅ Bot is now RUNNING!'));
    console.log(chalk.gray('Monitoring for trades from lead trader...\n'));
    console.log(chalk.yellow('Press Ctrl+C to stop\n'));
  }
}

// Error handlers
process.on('unhandledRejection', (error) => {
  console.error(chalk.red('💥 Unhandled Promise Rejection:'), error);
});

process.on('uncaughtException', (error) => {
  console.error(chalk.red('💥 Uncaught Exception:'), error);
  process.exit(1);
});

process.on('SIGINT', () => {
  console.log(chalk.yellow('\n\n⚠️  Shutting down bot...'));
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log(chalk.yellow('\n\n⚠️  Received termination signal...'));
  process.exit(0);
});

// Start the bot
const bot = new PolymarketCopyBot();
bot.start().catch(error => {
  console.error(chalk.red('💥 Fatal Error:'), error);
  process.exit(1);
});
