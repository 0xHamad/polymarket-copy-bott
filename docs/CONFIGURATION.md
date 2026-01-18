# Configuration Guide

## Getting API Credentials

### Step 1: Create Polymarket Account
1. Visit https://polymarket.com
2. Sign up or login

### Step 2: Generate API Keys
1. Navigate to **Settings**
2. Click **API** tab
3. Click **Create API Key**
4. Save credentials securely:
   - API Key
   - API Secret
   - Passphrase

⚠️ **IMPORTANT:** Save these credentials immediately. Polymarket won't show them again!

## Configuration File

### Create .env File
```bash
cp .env.example .env
```

### Edit Configuration
```bash
nano .env  # Linux/Mac
notepad .env  # Windows
```

### Required Settings
```bash
# Your Polymarket API credentials
POLY_API_KEY=pk_live_abc123...
POLY_API_SECRET=sk_live_xyz789...
POLY_PASSPHRASE=your-secure-passphrase

# Lead trader wallet address
LEAD_TRADER_ADDRESS=0x1234567890abcdef...

# Trading percentage (5-20% recommended)
COPY_PERCENTAGE=10
```

## Finding Lead Trader Address

### Method 1: Polymarket Profile
