# MQL5 EA Setup Instructions

## 📋 Installation Steps

### 1. Copy EA to MT5
1. Open **MetaEditor** in MT5
2. File → Open Data Folder
3. Navigate to `MQL5/Experts/`
4. Copy the `GoldAI_Professional_EA.mq5` file here

### 2. Compile the EA
1. Open `GoldAI_Professional_EA.mq5` in MetaEditor
2. Click **Compile** (F7)
3. Check for errors in the Toolbox
4. If successful, you'll see "0 error(s), 0 warning(s)"

### 3. Enable WebRequest
**CRITICAL:** MT5 must allow the EA to connect to your API

1. In MT5, go to **Tools → Options**
2. Click **Expert Advisors** tab
3. Check ✅ **"Allow WebRequest for listed URLs"**
4. Add these URLs:
   ```
   http://localhost:3001
   https://goldai-bridge-is7d.onrender.com
   ```
5. Click **OK**

### 4. Attach EA to Chart
1. Open an **XAUUSD** chart (any timeframe)
2. In **Navigator** → **Expert Advisors**
3. Find `GoldAI_Professional_EA`
4. Drag it onto the XAUUSD chart

### 5. Configure EA Settings
When the settings window appears:

**Common Tab:**
- ✅ Allow live trading
- ✅ Allow DLL imports (if using advanced features)
- ✅ Allow WebRequest

**Inputs Tab:**
```
API_URL = http://localhost:3001/api/v1
(or your Render URL: https://goldai-bridge-is7d.onrender.com/api/v1)

License_Key = GOLDAI-TEST-2024
Risk_Percent = 6.0
Max_Risk_Percent = 8.0
Magic_Number = 999888

Enable_Breakeven = true
Breakeven_Pips = 5

Enable_Daily_Limits = true
Daily_Profit_Target_Percent = 15.0
Daily_Max_Loss_Percent = 8.0
```

### 6. Verify EA is Running
Check the **Journal** tab in MT5:
```
🤖 GoldAI Professional EA v2.0
✅ License Valid - Expires: 2023-12-11
📅 Days Remaining: 5
🚀 EA Initialized Successfully
⏰ Polling every 1 second
```

## 🧪 Testing

### Test License
1. Use `GOLDAI-TEST-2024` for testing
2. Valid for 5 days
3. Can be reactivated unlimited times

### Test Connection
If you see:
```
❌ License Check Failed - HTTP 4900
```

**Solution:**
1. Check WebRequest URLs are added
2. Verify Bridge API is running
3. Check API_URL is correct

## 🚀 Production Deployment

When deploying to Render, only change:
```
API_URL = https://goldai-bridge-is7d.onrender.com/api/v1
License_Key = GOLDAI-XXXX-XXXX-XXXX
```

Everything else stays the same!

## 📊 EA Features

✅ License validation (daily check)
✅ Watchlist polling (every second)
✅ Daily profit/loss limits
✅ Automatic breakeven at TP1
✅ Multi-TP management
✅ Professional risk management
✅ Confluence validation (coming in complete version)

Perfect! 🎉
