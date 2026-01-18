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
    
    // Polymarket APIs
    this.clobAPI = 'https://clob.polymarket.com';
    this.dataAPI = 'https://gamma-api.polymarket.com';
    this.stratosAPI = 'https://stratos-api.polymarket.com';
    
    // Polygon RPC Endpoints (HTTP + WebSocket)
    this.polygonRPC = process.env.POLYGON_RPC_HTTP || 'https://polygon-rpc.com';
    this.polygonWSRPC = process.env.POLYGON_RPC_WS || 'wss://polygon-bor-rpc.publicnode.com';
    
    // Polymarket WebSocket
    this.polymarketWS = 'wss://ws-subscriptions-clob.polymarket.com/ws/market';
    
    // Contract addresses (Polygon Mainnet)
    this.CTF_EXCHANGE = '0x4bFb41d5B3570DeFd03C39a9A4D8dE6Bd8B8982E';
    this.CONDITIONAL_TOKENS = '0x4D97DCd97eC945f40cF65F87097ACe5EA0476045';
    
    this.balance = 0;
    this.activePositions = new Map();
    this.processingOrders = new Set();
    this.reconnectAttempts = 0;
    this.maxReconnectAttempts = 10;
    this.lastPollTime = 0;
    this.pollingInterval = null;
    this.polygonWS = null;
    this.polymarketWSClient = null;
    
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
    console.log(chalk.gray(`📡 Polygon RPC: ${this.polygonRPC}`));
  }

  // ============================================
  // POLYGON RPC METHODS
  // ============================================
  
  async polygonRPCRequest(method, params = []) {
    try {
      const response = await axios.post(
        this.polygonRPC,
        {
          jsonrpc: '2.0',
          method: method,
          params: params,
          id: Date.now()
        },
        {
          headers: { 'Content-Type': 'application/json' },
          timeout: 10000
        }
      );
      
      return response.data.result;
    } catch (error) {
      console.error(chalk.red(`❌ Polygon RPC Error (${method}):`), error.message);
      throw error;
    }
  }

  async getPolygonBlockNumber() {
    try {
      const blockNumber = await this.polygonRPCRequest('eth_blockNumber');
      this.stats.polygonBlockNumber = parseInt(blockNumber, 16);
      return this.stats.polygonBlockNumber;
    } catch (error) {
      return null;
    }
  }

  async getOnChainBalance(address) {
    try {
      const balance = await this.polygonRPCRequest('eth_getBalance', [
        address,
        'latest'
      ]);
      
      // Convert from Wei to MATIC
      const maticBalance = parseInt(balance, 16) / 1e18;
      return maticBalance;
    } catch (error) {
      console.error(chalk.red('❌ Failed to get on-chain balance'));
      return 0;
    }
  }

  // Connect to Polygon WebSocket RPC
  connectPolygonWebSocket() {
    console.log(chalk.blue('🔌 Connecting to Polygon WebSocket RPC...'));
    
    try {
      this.polygonWS = new WebSocket(this.polygonWSRPC);
      
      this.polygonWS.on('open', () => {
        console.log(chalk.green('✅ Polygon WebSocket Connected!'));
        
        // Subscribe to new block headers
        const subscription = {
          jsonrpc: '2.0',
          id: 1,
          method: 'eth_subscribe',
          params: ['newHeads']
        };
        
        this.polygonWS.send(JSON.stringify(subscription));
      });

      this.polygonWS.on('message', (data) => {
        try {
          const message = JSON.parse(data.toString());
          
          if (message.method === 'eth_subscription') {
            const blockNumber = parseInt(message.params.result.number, 16);
            this.stats.polygonBlockNumber = blockNumber;
            
            // Log every 100 blocks
            if (blockNumber % 100 === 0) {
              console.log(chalk.gray(`⛓️  Polygon Block: ${blockNumber}`));
            }
          }
        } catch (error) {
          // Ignore parse errors
        }
      });

      this.polygonWS.on('error', (error) => {
        console.log(chalk.yellow('⚠️  Polygon WS Error:'), error.message);
      });

      this.polygonWS.on('close', () => {
        console.log(chalk.yellow('⚠️  Polygon WebSocket Disconnected'));
        setTimeout(() => this.connectPolygonWebSocket(), 10000);
      });

    } catch (error) {
      console.error(chalk.red('Failed to connect Polygon WebSocket'));
    }
  }

  // ============================================
  // POLYMARKET API METHODS
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

  async getBalance() {
    try {
      // Try Polymarket API balance
      const response = await axios.get(
        `${this.dataAPI}/balance?address=${this.leadTraderAddress}`,
        { timeout: 5000 }
      );
      
      this.balance = parseFloat(response.data?.balance || response.data?.usdc || 0);
      
      // Fallback: Try on-chain balance
      if (this.balance === 0) {
        console.log(chalk.gray('Checking on-chain balance...'));
        const onChainBalance = await this.getOnChainBalance(this.leadTraderAddress);
        
        if (onChainBalance > 0) {
          console.log(chalk.cyan(`On-chain MATIC: ${onChainBalance.toFixed(4)}`));
        }
      }
      
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

  // ============================================
  // POLLING TRADER ACTIVITY
  // ============================================

  async pollTraderActivity() {
    try {
      const now = Date.now();
      
      if (now - this.lastPollTime < 5000) {
        return;
      }
      
      this.lastPollTime = now;
      
      // Get recent trades from Gamma API
      const response = await axios.get(
        `${this.dataAPI}/trades?address=${this.leadTraderAddress}&limit=10`,
        { timeout: 5000 }
      );
      
      const trades = response.data?.trades || response.data || [];
      
      if (trades.length > 0) {
        const recentTrades = trades.filter(trade => {
          const tradeTime = new Date(trade.timestamp || trade.created_at).getTime();
          return now - tradeTime < 30000; // 30 seconds
        });
        
        for (const trade of recentTrades) {
          await this.copyTradeFromData(trade);
        }
      }
      
    } catch (error) {
      // Silently ignore polling errors
      if (error.code !== 'ECONNABORTED') {
        console.log(chalk.gray('Polling...'));
      }
    }
  }

  async copyTradeFromData(tradeData) {
    const market = tradeData.market || tradeData.market_id;
    const side = tradeData.side || tradeData.order_side;
    const price = parseFloat(tradeData.price || tradeData.fill_price || 0.5);
    
    if (!market || !side) {
      return;
    }
    
    const tradeKey = `${market}-${side}-${price}`;
    if (this.processingOrders.has(tradeKey)) {
      return;
    }
    
    console.log(chalk.magenta('\n🆕 NEW TRADE DETECTED!'));
    console.log(chalk.cyan('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'));
    console.log(chalk.cyan('Market:'), market.substring(0, 40) + '...');
    console.log(chalk.cyan('Side:'), side);
    console.log(chalk.cyan('Price:'), `$${price.toFixed(4)}`);
    console.log(chalk.cyan('Block:'), `#${this.stats.polygonBlockNumber}`);
    
    const tradeAmount = this.balance * this.copyPercentage;
    const shares = tradeAmount / price;
    
    if (shares < 0.01) {
      console.log(chalk.yellow('⚠️  Position too small, skipping'));
      return;
    }
    
    console.log(chalk.cyan('Your Position:'), `${shares.toFixed(2)} shares ($${tradeAmount.toFixed(2)})`);
    
    const yourOrder = {
      market: market,
      side: side,
      type: 'MARKET',
      size: shares.toFixed(4)
    };
    
    const result = await this.placeOrder(yourOrder);
    
    if (result) {
      this.stats.tradesCopied++;
      
      this.activePositions.set(market, {
        orderId: result.orderId || result.id || Date.now(),
        side: side,
        shares: shares,
        entryPrice: price,
        timestamp: Date.now(),
        blockNumber: this.stats.polygonBlockNumber
      });
      
      console.log(chalk.green('✅ Successfully copied trade!'));
      this.displayStats();
    }
    
    console.log(chalk.cyan('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'));
  }

  async placeOrder(orderData) {
    const orderId = `${Date.now()}-${Math.random().toString(36).substring(7)}`;
    const orderKey = `${orderData.market}-${orderData.side}`;
    
    if (this.processingOrders.has(orderKey)) {
      console.log(chalk.yellow('⏭️  Order already processing, skipping duplicate...'));
      return null;
    }
    
    this.processingOrders.add(orderKey);
    
    try {
      if (!orderData.market || !orderData.side || !orderData.size) {
        throw new Error('Invalid order data: missing required fields');
      }

      const order = {
        market: orderData.market,
        side: orderData.side.toUpperCase(),
        type: orderData.type || 'MARKET',
        size: parseFloat(orderData.size).toFixed(4),
        timeInForce: 'IOC',
        clientOrderId: orderId
      };

      if (orderData.price && order.type === 'LIMIT') {
        order.price = parseFloat(orderData.price).toFixed(4);
      }
      
      console.log(chalk.cyan('📤 Placing order...'));
      
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
      setTimeout(() => {
        this.processingOrders.delete(orderKey);
      }, 2000);
    }
  }

  // ============================================
  // POLYMARKET WEBSOCKET
  // ============================================

  connectPolymarketWebSocket() {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.log(chalk.yellow('⚠️  Max reconnection attempts reached for Polymarket WS'));
      return;
    }
    
    console.log(chalk.blue('🔌 Connecting to Polymarket WebSocket...'));
    
    try {
      this.polymarketWSClient = new WebSocket(this.polymarketWS, {
        headers: {
          'User-Agent': 'Mozilla/5.0',
          'Origin': 'https://polymarket.com'
        }
      });
      
      this.polymarketWSClient.on('open', () => {
        console.log(chalk.green('✅ Polymarket WebSocket Connected!'));
        this.reconnectAttempts = 0;
        
        const subscription = {
          type: 'subscribe',
          markets: ['*']
        };
        
        this.polymarketWSClient.send(JSON.stringify(subscription));
      });

      this.polymarketWSClient.on('message', async (data) => {
        try {
          const message = JSON.parse(data.toString());
          if (message.address?.toLowerCase() === this.leadTraderAddress) {
            await this.handleWebSocketMessage(message);
          }
        } catch (error) {
          // Ignore parse errors
        }
      });

      this.polymarketWSClient.on('error', (error) => {
        console.log(chalk.red('❌ Polymarket WebSocket Error:'), error.message);
        this.reconnectAttempts++;
      });

      this.polymarketWSClient.on('close', (code) => {
        console.log(chalk.yellow(`⚠️  Polymarket WebSocket Disconnected (${code})`));
        
        if (this.reconnectAttempts < this.maxReconnectAttempts) {
          this.reconnectAttempts++;
          console.log(chalk.gray(`Reconnect attempt ${this.reconnectAttempts}/${this.maxReconnectAttempts} in 10s...`));
          
          setTimeout(() => {
            this.connectPolymarketWebSocket();
          }, 10000);
        }
      });

    } catch (error) {
      console.error(chalk.red('Failed to create Polymarket WebSocket'));
      this.reconnectAttempts++;
    }
  }

  async handleWebSocketMessage(message) {
    const eventType = message.event || message.type;
    
    if (!eventType) return;

    switch (eventType) {
      case 'order':
      case 'ORDER_CREATED':
      case 'new_order':
        await this.copyTradeFromData(message);
        break;
    }
  }

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
    console.log(chalk.cyan('⛓️  Polygon Block:  '), chalk.white(`#${this.stats.polygonBlockNumber}`));
    console.log(chalk.cyan('⏱️  Runtime:        '), chalk.white(`${runtime} minutes`));
    console.log(chalk.bgBlue.white('╚════════════════════════════════════════════╝\n'));
  }

  async start() {
    console.log(chalk.bgGreen.black('\n╔════════════════════════════════════════════╗'));
    console.log(chalk.bgGreen.black('║     🚀 STARTING COPY TRADING BOT 🚀       ║'));
    console.log(chalk.bgGreen.black('╚════════════════════════════════════════════╝\n'));
    
    if (!this.apiKey || !this.apiSecret || !this.passphrase) {
      console.error(chalk.red('❌ ERROR: API credentials missing!'));
      process.exit(1);
    }
    
    if (!this.leadTraderAddress || this.leadTraderAddress.includes('1234567890')) {
      console.error(chalk.red('❌ ERROR: Invalid lead trader address!'));
      process.exit(1);
    }
    
    console.log(chalk.cyan('🔧 Configuration:'));
    console.log(chalk.gray('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'));
    console.log(chalk.blue('Lead Trader:  '), chalk.white(this.leadTraderAddress));
    console.log(chalk.blue('Copy %:       '), chalk.white(`${(this.copyPercentage * 100).toFixed(0)}%`));
    console.log(chalk.blue('Polygon RPC:  '), chalk.white(this.polygonRPC));
    console.log(chalk.blue('Method:       '), chalk.white('Polling + WebSocket'));
    console.log(chalk.gray('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'));
    
    // Get Polygon block number
    console.log(chalk.yellow('⛓️  Connecting to Polygon...'));
    const blockNumber = await this.getPolygonBlockNumber();
    if (blockNumber) {
      console.log(chalk.green('✅ Polygon connected:'), chalk.white(`Block #${blockNumber}`));
    }
    
    console.log(chalk.yellow('💰 Fetching account balance...'));
    await this.getBalance();
    console.log(chalk.green('✅ Balance loaded:'), chalk.white(`$${this.balance.toFixed(2)}\n`));
    
    // Connect to Polygon WebSocket RPC
    this.connectPolygonWebSocket();
    
    // Try Polymarket WebSocket
    this.connectPolymarketWebSocket();
    
    // Start polling (primary method)
    console.log(chalk.green('✅ Starting polling mode...'));
    this.pollingInterval = setInterval(() => {
      this.pollTraderActivity();
    }, 5000);
    
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

const bot = new PolymarketCopyBot();
bot.start().catch(error => {
  console.error(chalk.red('💥 Fatal Error:'), error);
  process.exit(1);
});
