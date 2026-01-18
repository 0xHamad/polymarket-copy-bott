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
    
    this.clobAPI = 'https://clob.polymarket.com';
    this.dataAPI = 'https://data-api.polymarket.com';
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
        timeout: 3000
      });
      return response.data;
    } catch (error) {
      console.error(chalk.red('❌ API Error:'), error.response?.data || error.message);
      throw error;
    }
  }

  async getBalance() {
    try {
      const data = await this.apiRequest('GET', '/balance');
      this.balance = parseFloat(data.balance || 0);
      return this.balance;
    } catch (error) {
      console.error(chalk.red('Failed to get balance'));
      return 0;
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
        size: orderData.size,
        orderId: result.orderId
      });
      
      return result;
    } catch (error) {
      console.error(chalk.red('❌ Order Failed:'), error.message);
      this.stats.failedTrades++;
      return null;
    } finally {
      this.processingOrders.delete(orderData.market + orderData.side);
    }
  }

  connectWebSocket() {
    console.log(chalk.blue('🔌 Connecting to Polymarket WebSocket...'));
    
    this.ws = new WebSocket(this.wsURL);
    
    this.ws.on('open', () => {
      console.log(chalk.green('✅ WebSocket Connected!'));
      
      this.ws.send(JSON.stringify({
        type: 'subscribe',
        channel: 'user',
        market: 'all',
        address: this.leadTraderAddress
      }));
      
      this.ws.send(JSON.stringify({
        type: 'subscribe',
        channel: 'market',
        market: 'all'
      }));
      
      console.log(chalk.cyan(`👀 Monitoring Lead Trader: ${this.leadTraderAddress}`));
    });

    this.ws.on('message', async (data) => {
      try {
        const message = JSON.parse(data);
        await this.handleWebSocketMessage(message);
      } catch (error) {
        console.error(chalk.red('WebSocket message error:'), error);
      }
    });

    this.ws.on('error', (error) => {
      console.error(chalk.red('❌ WebSocket Error:'), error.message);
      this.reconnectWebSocket();
    });

    this.ws.on('close', () => {
      console.log(chalk.yellow('⚠️  WebSocket Disconnected'));
      this.reconnectWebSocket();
    });
  }

  reconnectWebSocket() {
    console.log(chalk.yellow('🔄 Reconnecting in 2 seconds...'));
    setTimeout(() => {
      this.connectWebSocket();
    }, 2000);
  }

  async handleWebSocketMessage(message) {
    if (message.address && message.address.toLowerCase() !== this.leadTraderAddress.toLowerCase()) {
      return;
    }

    switch (message.event) {
      case 'ORDER_CREATED':
        await this.copyNewOrder(message);
        break;
      case 'ORDER_FILLED':
        await this.copyFilledOrder(message);
        break;
      case 'ORDER_CANCELLED':
        await this.handleCancelledOrder(message);
        break;
      case 'POSITION_CLOSED':
        await this.closePosition(message);
        break;
    }
  }

  async copyNewOrder(orderData) {
    console.log(chalk.magenta('🆕 Lead Trader Placed Order!'));
    console.log(chalk.cyan('Market:'), orderData.market);
    console.log(chalk.cyan('Side:'), orderData.side);
    console.log(chalk.cyan('Price:'), orderData.price);
    
    const tradeAmount = this.balance * this.copyPercentage;
    const shares = tradeAmount / parseFloat(orderData.price);
    
    if (shares < 0.01) {
      console.log(chalk.yellow('⚠️  Position too small, skipping...'));
      return;
    }
    
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
      this.stats.successfulTrades++;
      
      this.activePositions.set(orderData.market, {
        orderId: result.orderId,
        side: orderData.side,
        shares: shares,
        entryPrice: parseFloat(orderData.price),
        timestamp: Date.now()
      });
      
      this.displayStats();
    }
  }

  async copyFilledOrder(fillData) {
    console.log(chalk.green('✅ Lead Trader Order FILLED!'));
    
    if (this.activePositions.has(fillData.market)) {
      const position = this.activePositions.get(fillData.market);
      console.log(chalk.cyan('📊 Position Updated:'), position);
    }
  }

  async closePosition(positionData) {
    console.log(chalk.red('🔴 Lead Trader CLOSED Position - SELLING IMMEDIATELY!'));
    
    const position = this.activePositions.get(positionData.market);
    
    if (!position) {
      console.log(chalk.yellow('⚠️  No position found to close'));
      return;
    }
    
    const closeSide = position.side === 'BUY' ? 'SELL' : 'BUY';
    
    const closeOrder = {
      market: positionData.market,
      side: closeSide,
      type: 'MARKET',
      size: position.shares.toFixed(4),
      price: null
    };
    
    const result = await this.placeOrder(closeOrder);
    
    if (result) {
      const exitPrice = parseFloat(positionData.price || position.entryPrice);
      const pnl = (exitPrice - position.entryPrice) * position.shares * (position.side === 'BUY' ? 1 : -1);
      
      this.stats.totalProfit += pnl;
      
      console.log(chalk.green('💰 Position Closed:'));
      console.log(chalk.cyan('Entry Price:'), position.entryPrice);
      console.log(chalk.cyan('Exit Price:'), exitPrice);
      console.log(pnl > 0 ? chalk.green('Profit: +$' + pnl.toFixed(2)) : chalk.red('Loss: -$' + Math.abs(pnl).toFixed(2)));
      
      this.activePositions.delete(positionData.market);
      
      this.displayStats();
    }
  }

  async handleCancelledOrder(cancelData) {
    console.log(chalk.yellow('🚫 Lead Trader Cancelled Order'));
    
    if (this.activePositions.has(cancelData.market)) {
      const position = this.activePositions.get(cancelData.market);
      await this.cancelOrder(position.orderId);
      this.activePositions.delete(cancelData.market);
    }
  }

  async cancelOrder(orderId) {
    try {
      await this.apiRequest('DELETE', `/order/${orderId}`);
      console.log(chalk.yellow('🚫 Order Cancelled:'), orderId);
    } catch (error) {
      console.error(chalk.red('Failed to cancel order'));
    }
  }

  displayStats() {
    console.log(chalk.bgBlue.white('\n========== BOT STATISTICS =========='));
    console.log(chalk.cyan('💰 Current Balance:'), chalk.white('$' + this.balance.toFixed(2)));
    console.log(chalk.cyan('📊 Trades Copied:'), chalk.white(this.stats.tradesCopied));
    console.log(chalk.cyan('✅ Successful:'), chalk.green(this.stats.successfulTrades));
    console.log(chalk.cyan('❌ Failed:'), chalk.red(this.stats.failedTrades));
    console.log(chalk.cyan('📈 Total P&L:'), this.stats.totalProfit > 0 ? 
      chalk.green('+$' + this.stats.totalProfit.toFixed(2)) : 
      chalk.red('-$' + Math.abs(this.stats.totalProfit).toFixed(2))
    );
    console.log(chalk.cyan('⏱️  Uptime:'), chalk.white(this.getUptime()));
    console.log(chalk.cyan('🎯 Active Positions:'), chalk.white(this.activePositions.size));
    console.log(chalk.bgBlue.white('====================================\n'));
  }

  getUptime() {
    const uptime = Date.now() - this.stats.startTime;
    const hours = Math.floor(uptime / 3600000);
    const minutes = Math.floor((uptime % 3600000) / 60000);
    return `${hours}h ${minutes}m`;
  }

  async monitorBalance() {
    setInterval(async () => {
      await this.getBalance();
    }, 10000);
  }

  displayLivePositions() {
    setInterval(() => {
      if (this.activePositions.size > 0) {
        console.log(chalk.bgCyan.black('\n--- ACTIVE POSITIONS ---'));
        this.activePositions.forEach((position, market) => {
          console.log(chalk.white(`📍 ${market}`));
          console.log(chalk.gray(`   Side: ${position.side} | Shares: ${position.shares} | Entry: $${position.entryPrice}`));
        });
        console.log(chalk.bgCyan.black('------------------------\n'));
      }
    }, 30000);
  }

  async start() {
    console.log(chalk.bgGreen.black('\n🚀 STARTING ULTRA FAST COPY TRADING BOT 🚀\n'));
    
    if (!this.apiKey || !this.apiSecret || !this.passphrase) {
      console.error(chalk.red('❌ ERROR: API credentials missing in .env file!'));
      process.exit(1);
    }
    
    if (!this.leadTraderAddress) {
      console.error(chalk.red('❌ ERROR: Lead trader address missing!'));
      process.exit(1);
    }
    
    console.log(chalk.cyan('🔧 Configuration:'));
    console.log(chalk.gray('Lead Trader:'), chalk.white(this.leadTraderAddress));
    console.log(chalk.gray('Copy Percentage:'), chalk.white((this.copyPercentage * 100).toFixed(0) + '%'));
    console.log();
    
    console.log(chalk.yellow('💰 Fetching account balance...'));
    await this.getBalance();
    console.log(chalk.green('✅ Balance:'), chalk.white('$' + this.balance.toFixed(2)));
    console.log();
    
    this.connectWebSocket();
    
    this.monitorBalance();
    this.displayLivePositions();
    
    setInterval(() => {
      this.displayStats();
    }, 60000);
    
    console.log(chalk.green('✅ Bot is now running! Waiting for trades...\n'));
  }
}

const bot = new PolymarketCopyBot();
bot.start().catch(error => {
  console.error(chalk.red('💥 Fatal Error:'), error);
  process.exit(1);
});
