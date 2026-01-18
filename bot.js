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
    this.leadTraderAddress = process.env.LEAD_TRADER_ADDRESS;
    this.copyPercentage = parseFloat(process.env.COPY_PERCENTAGE) / 100 || 0.10;
    
    // FIXED: Correct Polymarket endpoints
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
      startTime: Date.now()
    };
    
    console.log(chalk.green('🤖 Ultra Fast Copy Trading Bot Initialized'));
  }

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
      'POLY-ADDRESS': this.leadTraderAddress,
      'POLY-SIGNATURE': signature,
      'POLY-TIMESTAMP': timestamp,
      'POLY-PASSPHRASE': this.passphrase,
      'POLY-API-KEY': this.apiKey,
      'Content-Type': 'application/json'
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
        timeout: 5000
      });
      return response.data;
    } catch (error) {
      if (error.response?.status === 404) {
        console.error(chalk.red('❌ API Endpoint not found. Check Polymarket API documentation.'));
      } else {
        console.error(chalk.red('❌ API Error:'), error.response?.data || error.message);
      }
      throw error;
    }
  }

  // FIXED: Get balance from correct endpoint
  async getBalance() {
    try {
      // Try different balance endpoint
      const walletAddress = this.leadTraderAddress;
      const response = await axios.get(
        `${this.dataAPI}/balance?address=${walletAddress}`,
        { timeout: 5000 }
      );
      
      this.balance = parseFloat(response.data?.balance || 0);
      return this.balance;
    } catch (error) {
      console.warn(chalk.yellow('⚠️  Could not fetch balance, using default: $1000'));
      this.balance = 1000; // Default balance for testing
      return this.balance;
    }
  }

  async placeOrder(orderData) {
    const orderId = `${Date.now()}-${Math.random()}`;
    
    if (this.processingOrders.has(orderData.market + orderData.side)) {
      console.log(chalk.yellow('⏭️  Order already processing, skipping...'));
      return null;
    }
    
    this.processingOrders.add(orderData.market + orderData.side);
    
    try {
      const order = {
        market: orderData.market,
        side: orderData.side,
        type: orderData.type || 'MARKET',
        size: orderData.size.toString(),
        price: orderData.price?.toString(),
        timeInForce: 'IOC',
        clientOrderId: orderId
      };
      
      const result = await this.apiRequest('POST', '/order', order);
      
      console.log(chalk.green('✅ Order Placed:'), {
        market: orderData.market,
        side: orderData.side,
        size: orderData.size
      });
      
      this.stats.successfulTrades++;
      return result;
    } catch (error) {
      console.error(chalk.red('❌ Order Failed'));
      this.stats.failedTrades++;
      return null;
    } finally {
      this.processingOrders.delete(orderData.market + orderData.side);
    }
  }

  // FIXED: WebSocket connection with proper error handling
  connectWebSocket() {
    console.log(chalk.blue('🔌 Connecting to Polymarket WebSocket...'));
    
    this.ws = new WebSocket(this.wsURL);
    
    this.ws.on('open', () => {
      console.log(chalk.green('✅ WebSocket Connected!'));
      
      // Subscribe to user trades
      const subscription = {
        type: 'subscribe',
        channel: 'user',
        auth: {
          apiKey: this.apiKey,
          secret: this.apiSecret,
          passphrase: this.passphrase
        },
        markets: ['*'] // Subscribe to all markets
      };
      
      this.ws.send(JSON.stringify(subscription));
      
      console.log(chalk.cyan(`👀 Monitoring Lead Trader: ${this.leadTraderAddress}`));
    });

    this.ws.on('message', async (data) => {
      try {
        const dataStr = data.toString();
        
        // Ignore non-JSON messages
        if (!dataStr.startsWith('{')) {
          return;
        }
        
        const message = JSON.parse(dataStr);
        await this.handleWebSocketMessage(message);
      } catch (error) {
        // Silently ignore JSON parse errors for non-JSON messages
        if (error.message && !error.message.includes('JSON')) {
          console.error(chalk.red('WebSocket error:'), error.message);
        }
      }
    });

    this.ws.on('error', (error) => {
      console.error(chalk.red('❌ WebSocket Error:'), error.message);
    });

    this.ws.on('close', () => {
      console.log(chalk.yellow('⚠️  WebSocket Disconnected. Reconnecting...'));
      setTimeout(() => {
        this.connectWebSocket();
      }, 5000);
    });
  }

  async handleWebSocketMessage(message) {
    // Filter messages for lead trader only
    if (message.address && message.address.toLowerCase() !== this.leadTraderAddress.toLowerCase()) {
      return;
    }

    console.log(chalk.gray('📨 Received:'), message.type || message.event);

    switch (message.event || message.type) {
      case 'order':
      case 'ORDER_CREATED':
        await this.copyNewOrder(message);
        break;
      case 'fill':
      case 'ORDER_FILLED':
        await this.copyFilledOrder(message);
        break;
      case 'close':
      case 'POSITION_CLOSED':
        await this.closePosition(message);
        break;
    }
  }

  async copyNewOrder(orderData) {
    console.log(chalk.magenta('🆕 Lead Trader Order Detected!'));
    console.log(chalk.cyan('Market:'), orderData.market);
    console.log(chalk.cyan('Side:'), orderData.side);
    
    const price = parseFloat(orderData.price || orderData.fillPrice || 0.5);
    const tradeAmount = this.balance * this.copyPercentage;
    const shares = tradeAmount / price;
    
    if (shares < 0.01) {
      console.log(chalk.yellow('⚠️  Position too small, skipping'));
      return;
    }
    
    console.log(chalk.cyan('Your Trade:'), `${shares.toFixed(2)} shares @ $${price}`);
    
    const yourOrder = {
      market: orderData.market,
      side: orderData.side,
      type: 'MARKET',
      size: shares.toFixed(4),
      price: null
    };
    
    const result = await this.placeOrder(yourOrder);
    
    if (result) {
      this.stats.tradesCopied++;
      
      this.activePositions.set(orderData.market, {
        orderId: result.orderId || Date.now(),
        side: orderData.side,
        shares: shares,
        entryPrice: price,
        timestamp: Date.now()
      });
      
      this.displayStats();
    }
  }

  async copyFilledOrder(fillData) {
    console.log(chalk.green('✅ Order FILLED'));
  }

  async closePosition(positionData) {
    console.log(chalk.red('🔴 Closing Position'));
    
    const position = this.activePositions.get(positionData.market);
    
    if (!position) {
      return;
    }
    
    const closeSide = position.side === 'BUY' ? 'SELL' : 'BUY';
    
    const closeOrder = {
      market: positionData.market,
      side: closeSide,
      type: 'MARKET',
      size: position.shares.toFixed(4)
    };
    
    await this.placeOrder(closeOrder);
    this.activePositions.delete(positionData.market);
  }

  displayStats() {
    console.log(chalk.bgBlue.white('\n===== BOT STATS ====='));
    console.log(chalk.cyan('💰 Balance:'), chalk.white('$' + this.balance.toFixed(2)));
    console.log(chalk.cyan('📊 Trades:'), chalk.white(this.stats.tradesCopied));
    console.log(chalk.cyan('✅ Success:'), chalk.green(this.stats.successfulTrades));
    console.log(chalk.cyan('❌ Failed:'), chalk.red(this.stats.failedTrades));
    console.log(chalk.cyan('🎯 Active:'), chalk.white(this.activePositions.size));
    console.log(chalk.bgBlue.white('=====================\n'));
  }

  async start() {
    console.log(chalk.bgGreen.black('\n🚀 STARTING BOT 🚀\n'));
    
    if (!this.apiKey || !this.apiSecret || !this.passphrase) {
      console.error(chalk.red('❌ API credentials missing in .env!'));
      console.log(chalk.yellow('\nEdit .env file and add your Polymarket API credentials.'));
      process.exit(1);
    }
    
    if (!this.leadTraderAddress || this.leadTraderAddress.includes('1234567890')) {
      console.error(chalk.red('❌ Please update LEAD_TRADER_ADDRESS in .env!'));
      console.log(chalk.yellow('Replace with actual trader wallet address.'));
      process.exit(1);
    }
    
    console.log(chalk.cyan('🔧 Configuration:'));
    console.log(chalk.gray('Lead Trader:'), chalk.white(this.leadTraderAddress));
    console.log(chalk.gray('Copy %:'), chalk.white((this.copyPercentage * 100).toFixed(0) + '%'));
    console.log();
    
    console.log(chalk.yellow('💰 Fetching balance...'));
    await this.getBalance();
    console.log(chalk.green('✅ Balance:'), chalk.white('$' + this.balance.toFixed(2)));
    console.log();
    
    this.connectWebSocket();
    
    // Update balance every 30 seconds
    setInterval(async () => {
      await this.getBalance();
    }, 30000);
    
    // Display stats every minute
    setInterval(() => {
      this.displayStats();
    }, 60000);
    
    console.log(chalk.green('✅ Bot Running! Monitoring for trades...\n'));
  }
}

const bot = new PolymarketCopyBot();
bot.start().catch(error => {
  console.error(chalk.red('💥 Fatal Error:'), error);
  process.exit(1);
});
