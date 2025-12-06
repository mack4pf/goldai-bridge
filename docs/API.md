# Gold AI Auto-Trading Bridge - Updated API Documentation

## 🚀 New Features in v2.0

- ✅ **Licensing System** with test licenses (5 days) and monthly licenses (30 days)
- ✅ **Advanced Signal Processing** with confluence validation
- ✅ **Signal Quality Scoring** (filters 24 signals → 3-6 quality trades)
- ✅ **Watchlist Management** for monitoring setups
- ✅ **Daily Profit/Loss Tracking** with automatic limits
- ✅ **Compound Growth** - balance updates daily
- ✅ **Backward Compatible** with existing EA

---

## Quick Start

### 1. Install Dependencies
```bash
cd gold-ai-auto-bridge
npm install
```

### 2. Start Server
```bash
npm start
```

### 3. Test License

Use the test license for development:
```
GOLDAI-TEST-2024
```
- Valid for 5 days
- Can be reactivated unlimited times
- Full system access

### 4. Test API
```bash
node test_api.js
```

---

## API Endpoints

### 📋 Licensing

#### Activate License
```http
POST /api/v1/license/activate
Content-Type: application/json

{
  "userId": "telegram_user_id",
  "licenseKey": "GOLDAI-TEST-2024"
}
```

**Response:**
```json
{
  "success": true,
  "licenseId": "abc123",
  "expiresAt": "2023-12-11T10:00:00Z",
  "daysRemaining": 5,
  "isTestLicense": true,
  "message": "🧪 Test license activated (5 days)"
}
```

#### Check License
```http
GET /api/v1/license/check?license=GOLDAI-TEST-2024
```

**Response:**
```json
{
  "valid": true,
  "userId": "telegram_user_id",
  "expiresAt": "2023-12-11T10:00:00Z",
  "daysRemaining": 3,
  "isTestLicense": true
}
```

#### Get User License
```http
GET /api/v1/license/status/:userId
```

---

### ⚡ Signals

#### Send Advanced Signal
```http
POST /api/v1/signals/advanced
Content-Type: application/json

{
  "signalId": "SIG_20231206_1400",
  "timestamp": "2023-12-06T14:00:00Z",
  "timeframe": "1H",
  "symbol": "XAUUSD",
  "direction": "SELL",
  "confidence": 85,
  "entry": {
    "price": 4212,
    "zone": { "min": 4210, "max": 4215 }
  },
  "stopLoss": 4225,
  "takeProfits": [
    { "level": 1, "price": 4190, "percentage": 50 },
    { "level": 2, "price": 4170, "percentage": 50 }
  ],
  "confluence": {
    "rsi": {
      "period": 14,
      "currentValue": 68,
      "condition": "ABOVE_60_TURNING_DOWN",
      "description": "RSI at 68"
    },
    "candlestick": {
      "required": "SHOOTING_STAR_OR_ENGULFING",
      "description": "Wait for shooting star"
    },
    "wickRejection": {
      "required": true,
      "direction": "UPPER_WICK",
      "minSize": 15,
      "description": "Strong rejection"
    },
    "marketContext": {
      "level": "SUPPLY_ZONE",
      "levelPrice": 4215,
      "description": "Key supply zone",
      "confluenceScore": 85
    }
  },
  "riskManagement": {
    "recommendedRisk": 6,
    "maxRisk": 8,
    "slPips": 130,
    "tpPips": [220, 420]
  },
  "validity": {
    "expiresAt": "2023-12-06T16:00:00Z",
    "maxWaitTime": 120
  }
}
```

**Response:**
```json
{
  "success": true,
  "signalId": "SIG_20231206_1400",
  "qualityScore": 85,
  "addedToWatchlist": 12,
  "message": "Signal distributed to 12 active users"
}
```

See [`signal_format.md`](./docs/SIGNAL_FORMAT.md) for complete signal structure.

---

### 📊 Watchlist

#### Get Watchlist
```http
GET /api/v1/watchlist
Headers: x-license-key: GOLDAI-TEST-2024
```

**Response:**
```json
{
  "success": true,
  "count": 3,
  "watchlist": [
    {
      "id": "watch_123",
      "userId": "user_id",
      "signalId": "SIG_20231206_1400",
      "status": "monitoring",
      "addedAt": "2023-12-06T14:00:00Z",
      "signalData": { ... }
    }
  ]
}
```

#### Update Watchlist
```http
POST /api/v1/watchlist/update
Headers: x-license-key: GOLDAI-TEST-2024
Content-Type: application/json

{
  "signalId": "SIG_20231206_1400",
  "status": "executed",
  "ticket": "12345678"
}
```

#### Scrap Setup
```http
POST /api/v1/watchlist/scrap
Headers: x-license-key: GOLDAI-TEST-2024
Content-Type: application/json

{
  "signalId": "SIG_20231206_1400",
  "reason": "NO_WICK_REJECTION"
}
```

**Scrap Reasons:**
- `RSI_INVALID`
- `NO_WICK_REJECTION`
- `WRONG_CANDLE_PATTERN`
- `MARKET_REACTION_FAILED`
- `EXPIRED`

---

### 📈 Daily Stats

#### Get Daily Stats
```http
GET /api/v1/stats/daily
Headers: x-license-key: GOLDAI-TEST-2024
```

**Response:**
```json
{
  "success": true,
  "date": "2023-12-06",
  "startBalance": 1000,
  "currentBalance": 1070,
  "profitToday": 70,
  "lossToday": 0,
  "profitTarget": 150,
  "maxLoss": 80,
  "tradesExecuted": 3,
  "tradesWon": 3,
  "tradesLost": 0,
  "status": "active",
  "canTrade": true,
  "remainingProfit": 80,
  "remainingLoss": 80
}
```

**Status Values:**
- `active` - Can trade
- `profit_hit` - Profit target reached, stop trading
- `loss_hit` - Max loss reached, stop trading

#### Update Stats
```http
POST /api/v1/stats/update
Headers: x-license-key: GOLDAI-TEST-2024
Content-Type: application/json

{
  "tradeProfit": 50,
  "balance": 1050
}
```

---

## Database Collections

### `licenses`
```javascript
{
  userId: "user_123",
  licenseKey: "GOLDAI-TEST-2024",
  activatedAt: "2023-12-06T10:00:00Z",
  expiresAt: "2023-12-11T10:00:00Z",
  status: "active", // active, expired, deactivated
  isTestLicense: true,
  lastChecked: "2023-12-06T14:00:00Z"
}
```

### `signals`
```javascript
{
  signalId: "SIG_20231206_1400",
  symbol: "XAUUSD",
  direction: "SELL",
  qualityScore: 85,
  receivedAt: "2023-12-06T14:00:00Z",
  status: "active",
  ... // Full signal data
}
```

### `watchlist`
```javascript
{
  userId: "user_123",
  signalId: "SIG_20231206_1400",
  status: "monitoring", // monitoring, executed, scrapped
  addedAt: "2023-12-06T14:00:00Z",
  scrapReason: null,
  executedAt: null,
  ticket: null,
  signalData: { ... }
}
```

### `daily_stats`
```javascript
{
  userId: "user_123",
  date: "2023-12-06",
  startBalance: 1000,
  currentBalance: 1070,
  profitToday: 70,
  lossToday: 0,
  profitTarget: 150,
  maxLoss: 80,
  tradesExecuted: 3,
  tradesWon: 3,
  tradesLost: 0,
  status: "active"
}
```

---

## Testing

### Run API Tests
```bash
node test_api.js
```

### Manual Testing with curl

**Activate Test License:**
```bash
curl -X POST http://localhost:3001/api/v1/license/activate \
  -H "Content-Type: application/json" \
  -d '{"userId":"test_user","licenseKey":"GOLDAI-TEST-2024"}'
```

**Send Test Signal:**
```bash
curl -X POST http://localhost:3001/api/v1/signals/advanced \
  -H "Content-Type: application/json" \
  -d @test_signal.json
```

**Check Watchlist:**
```bash
curl http://localhost:3001/api/v1/watchlist \
  -H "x-license-key: GOLDAI-TEST-2024"
```

---

## Next Steps

1. ✅ Backend API complete
2. 🔄 Build MQL5 EA (Phase 3)
3. 🔄 Update Telegram Bot (Phase 4)
4. 🔄 Integration Testing (Phase 5)

See [`implementation_plan.md`](../../brain/.../implementation_plan.md) for the complete roadmap.
