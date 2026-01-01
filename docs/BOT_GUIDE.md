# Bridge Telegram Bot Guide

## 🤖 Bot Features

### For ADMIN (You):
- 👑 Create test licenses (5 days)
- 💎 Create monthly licenses (30 days)
- 📋 View all licenses
- 📊 Monitor user stats

### For USERS:
- 🔑 Activate license with key
- 📊 View their trading stats
- 📡 See their watchlist
- 🔑 Check license status

---

## 🔧 Setup

### 1. Create New Telegram Bot
1. Open Telegram, message [@BotFather](https://t.me/BotFather)
2. Send `/newbot`
3. Name: `GoldAI Bridge Bot`
4. Username: `goldai_bridge_bot` (or similar)
5. **Copy the token** you receive

### 2. Update .env
Add to `gold-ai-auto-bridge/.env`:
```env
BRIDGE_BOT_TOKEN=your_bot_token_here
ADMIN_TELEGRAM_ID=your_telegram_id
```

**To get your Telegram ID:**
- Message [@userinfobot](https://t.me/userinfobot)
- Copy the ID number

### 3. Restart Bridge API
```powershell
# Stop current server (Ctrl+C)
npm start
```

---

## 📱 How to Use (Admin)

### Create Test License
1. Start bot: `/start`
2. Click: `👑 Create License`
3. Choose: `🧪 Test License (5 days)`
4. Get: `GOLDAI-TEST-2024`
5. Give this key to users

### Create Monthly License
1. Click: `👑 Create License`
2. Choose: `💎 Monthly License (30 days)`
3. Get unique key: `GOLDAI-ABC123XYZ`
4. Give to customer

---

## 👤 How to Use (User)

### Activate License
```
/activate GOLDAI-TEST-2024
```

Bot responds with:
```
✅ License Activated!
License: GOLDAI-TEST-2024
Expires: Dec 11, 2025
Days Remaining: 5

Next Steps:
1. Open MT5
2. Attach GoldAI EA
3. Settings:
   • License_Key = GOLDAI-TEST-2024
```

### Check Stats
Click: `📊 My Stats`

Shows:
- Current balance
- Today's profit/loss
- Win rate
- Trade count

### View Watchlist
Click: `📡 My Watchlist`

Shows:
- Active signals being monitored
- Entry zones
- TP/SL levels

### Check License
Click: `🔑 My License`

Shows:
- License key
- Expiry date
- Days remaining
- Status

---

## 🔄 User Flow

```
1. User gets license key from you (admin)
   ↓
2. User activates in Telegram: /activate KEY
   ↓
3. User configures MT5 EA with same key
   ↓
4. EA validates license with Bridge API
   ↓
5. EA receives signals → trades
   ↓
6. User monitors stats in Telegram bot
```

---

## 🎯 Complete Example

**Admin creates license:**
```
Admin in Telegram:
/start
👑 Create License
🧪 Test License
→ Gets: GOLDAI-TEST-2024

Admin gives to User
```

**User activates:**
```
User in Telegram:
/activate GOLDAI-TEST-2024
→ ✅ License Activated!
```

**User sets up EA:**
```
MT5 EA Settings:
License_Key = GOLDAI-TEST-2024
API_URL = https://goldai-bridge-is7d.onrender.com/api/v1
```

**User monitors:**
```
Telegram bot:
📊 My Stats → See balance, profit, trades
📡 My Watchlist → See active signals
🔑 My License → Check days remaining
```

---

## ✅ Benefits

✅ User never sees API directly
✅ Easy license management
✅ Real-time stats monitoring
✅ Admin can create unlimited licenses
✅ Users self-serve activation
✅ Telegram notifications for trades (can add)

Perfect! 🎉
