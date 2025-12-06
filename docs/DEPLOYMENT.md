# Deployment Configuration Guide

## 🚀 URLs to Replace When Deploying to Render

### Local Development
```env
GOLD_MENTOR_API_URL=http://localhost:3000
BRIDGE_API_URL=http://localhost:3001
```

### Production (Replace with your Render URLs)
```env
# Gold Mentor Pro main server URL
GOLD_MENTOR_API_URL=https://your-goldai-mentor-pro.onrender.com

# Bridge API server URL  
BRIDGE_API_URL=https://your-goldai-bridge.onrender.com
```

## 📋 Deployment Steps

### 1. Deploy Gold Mentor Pro (Main Server)
- Push to GitHub/Render
- Set environment variables
- Get the deployed URL (e.g., `https://goldai-mentor-pro.onrender.com`)

### 2. Deploy Bridge API
- Use the Gold Mentor Pro URL in `GOLD_MENTOR_API_URL`
- Set all environment variables
- Get the deployed URL (e.g., `https://goldai-bridge.onrender.com`)

### 3. Update MT5 EA
- In EA inputs, use the Bridge API URL
- Example: `API_URL = https://goldai-bridge.onrender.com/api/v1`

### 4. Test License
- Activate test license: `GOLDAI-TEST-2024`
- Verify EA connects and receives signals

## 🔑 Required Environment Variables

### Both Servers Need:
- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY`
- `BRIDGE_API_KEY` (same value on both)

### Gold Mentor Pro Only:
- `GEMINI_API_KEY`
- `TELEGRAM_BOT_TOKEN`
- `GOLDAPI_KEY` (1-5)
- `ALPHA_VANTAGE_KEY` (1-2)

### Bridge API Only:
- `GOLD_MENTOR_API_URL` (your Gold Mentor Pro URL)

## 📁 Files to Update

When you get your Render URLs, update these files:

1. **Bridge API `.env`**
   ```env
   GOLD_MENTOR_API_URL=https://your-goldai-mentor-pro.onrender.com
   BRIDGE_API_URL=https://your-goldai-bridge.onrender.com
   ```

2. **MT5 EA Settings**
   ```
   API_URL = https://your-goldai-bridge.onrender.com/api/v1
   License_Key = GOLDAI-TEST-2024
   ```

3. **No code changes needed!** Everything uses environment variables.

## ✅ Testing Checklist

- [ ] Gold Mentor Pro accessible at your-url.onrender.com
- [ ] Bridge API accessible at your-url.onrender.com
- [ ] Bridge API can connect to Gold Mentor Pro
- [ ] Hourly scheduler runs and requests signals
- [ ] MT5 EA connects with license key
- [ ] EA receives signals in watchlist
- [ ] Trades execute correctly

Perfect! 🎉
