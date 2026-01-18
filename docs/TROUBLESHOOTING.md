# Troubleshooting Guide

## Common Issues

### Installation Problems

#### "Node.js not found"
```bash
# Solution: Install Node.js
# Download from: https://nodejs.org
```

#### "Permission denied"
```bash
# Linux/Mac solution:
chmod +x install.sh
sudo ./install.sh
```

#### "Dependencies failed to install"
```bash
# Clear npm cache
npm cache clean --force

# Reinstall
rm -rf node_modules
npm install
```

### Connection Issues

#### "WebSocket disconnected"
**Causes:**
- Network instability
- Firewall blocking WebSocket
- Polymarket server maintenance

**Solutions:**
```bash
# Bot auto-reconnects, but you can:
# 1. Check internet connection
# 2. Disable VPN temporarily
# 3. Check firewall settings
# 4. Wait for Polymarket servers
```

#### "API request timeout"
```bash
# Increase timeout in bot.js:
timeout: 5000  # Change from 3000 to 5000
```

### Trading Issues

#### "No trades being copied"
**Checklist:**
- [ ] WebSocket connected (check logs)
- [ ] Lead trader is actively trading
- [ ] Correct wallet address in .env
- [ ] Sufficient balance in account
- [ ] No API rate limits hit

#### "Insufficient balance"
**Solutions:**
- Deposit more USDC to Polymarket
- Reduce COPY_PERCENTAGE
- Check minimum balance requirements

#### "Order failed to place"
**Causes:**
- Insufficient balance
- Market closed/paused
- API rate limit
- Invalid order parameters

**Debug:**
```bash
# Check detailed error logs
node bot.js 2>&1 | tee bot.log
```

### Performance Issues

#### "Bot is slow"
```bash
# Reduce API timeout
timeout: 1000

# Use VPS closer to servers
# Recommended: AWS US-East
```

#### "High CPU usage"
```bash
# Reduce update frequency
setInterval(() => {
  this.displayStats();
}, 120000); // Every 2 minutes instead of 1
```

## Error Messages

### "ECONNREFUSED"
**Meaning:** Cannot connect to Polymarket API

**Solution:**
1. Check internet connection
2. Verify Polymarket.com is accessible
3. Check if API endpoint changed

### "401 Unauthorized"
**Meaning:** Invalid API credentials

**Solution:**
1. Verify .env file has correct credentials
2. Check for extra spaces
3. Regenerate API keys

### "429 Too Many Requests"
**Meaning:** API rate limit exceeded

**Solution:**
1. Reduce trading frequency
2. Implement request throttling
3. Wait before retrying

### "ETIMEDOUT"
**Meaning:** Request took too long

**Solution:**
1. Check internet speed
2. Increase timeout value
3. Use wired connection

## Debugging

### Enable Verbose Logging
```javascript
// Add to bot.js
const DEBUG = true;

if (DEBUG) {
  console.log('Debug info:', data);
}
```

### Check WebSocket Status
```javascript
// Monitor connection
this.ws.on('ping', () => {
  console.log('WebSocket alive');
});
```

### Log All Trades
```javascript
// Add logging
import fs from 'fs';

logTrade(trade) {
  fs.appendFileSync('trades.log', JSON.stringify(trade) + '\n');
}
```

## Getting Help

If issues persist:

1. **Check Logs:**
```bash
   tail -f bot.log
```

2. **GitHub Issues:**
   - Search existing issues
   - Create new issue with logs

3. **Community:**
   - GitHub Discussions
   - Discord support channel

4. **Contact:**
   - Email: your.email@example.com
   - Twitter: @yourhandle

## Preventive Measures

### Regular Maintenance
```bash
# Weekly:
- Update dependencies: npm update
- Check logs: cat bot.log
- Verify balance
- Review performance

# Monthly:
- Rotate API keys
- Update Node.js
- Review security
```

### Monitoring Script
```bash
#!/bin/bash
# monitor.sh - Check bot health

while true; do
  if ! pgrep -f "node bot.js" > /dev/null; then
    echo "Bot crashed! Restarting..."
    npm start &
  fi
  sleep 60
done
```

## Recovery Procedures

### Bot Crashed
```bash
# 1. Check what caused crash
tail -100 bot.log

# 2. Fix issue

# 3. Restart
npm start
```

### Lost API Access
```bash
# 1. Revoke old keys
# 2. Generate new keys
# 3. Update .env
# 4. Restart bot
```

### Database Corrupted (if using)
```bash
# 1. Backup current DB
cp data.db data.db.backup

# 2. Restore from last good backup
cp data.db.old data.db

# 3. Restart
```

## Still Need Help?

Create a GitHub issue with:
- Error message
- Full logs
- System info (OS, Node version)
- Steps to reproduce
