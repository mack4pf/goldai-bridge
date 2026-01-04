# Master EA Setup Instructions (GoldAI MasterAuto v1.0)

## 📋 Installation Steps

### 1. Copy EA to MT5
1. Open **MetaEditor** in MT5.
2. File → Open Data Folder.
3. Navigate to `MQL5/Experts/`.
4. Copy the `GoldAI_MasterAuto_v1.mq5` file here.

### 2. Compile the EA
1. Open `GoldAI_MasterAuto_v1.mq5` in MetaEditor.
2. Click **Compile** (F7).
3. Verify "0 error(s), 0 warning(s)" in the toolbox.

### 3. Enable WebRequest
**CRITICAL:** MT5 must allow the EA to connect to the Bridge API.

1. In MT5, go to **Tools → Options**.
2. Click **Expert Advisors** tab.
3. Check ✅ **"Allow WebRequest for listed URLs"**.
4. Add this URL:
   ```
   https://goldai-bridge-is7d.onrender.com
   ```
5. Click **OK**.

### 4. Attach EA to Chart
1. Open an **XAUUSD** chart (H1 timeframe recommended).
2. In **Navigator** → **Expert Advisors**, find `GoldAI_MasterAuto_v1`.
3. Drag it onto the XAUUSD chart.

### 5. Configure EA Settings
When the settings window appears:

**Inputs Tab:**
- `API_URL`: `https://goldai-bridge-is7d.onrender.com/api/v1`
- `License_Key`: Your active license key (e.g., `GOLDAI-TEST-XXXX`).
- `Magic_Number`: Unique ID for this EA (e.g., `112233`).
- `Poll_Interval`: Set to `60` for 1-minute polling.

---

## 📊 Master EA Trading Logic

1. **Signal Input**: Reaches the `/watchlist` endpoint of the Gold Bridge.
2. **Session Filters**: ONLY opens trades during London (08:00–17:00 GMT) and New York (13:00–22:00 GMT).
3. **Split Positions**: Every signal opens **TWO** separate trades:
   - **Trade 1**: High probability, targets 40% of signal TP distance.
   - **Trade 2**: Runner, targets 100% of signal TP distance.
4. **Lot Sizes**: Automatically calculated based on account balance:
   - `< $500`: 0.01 per trade.
   - `$500 - $999`: 0.02 per trade.
   - `$1000 - $1999`: 0.05 per trade.
   - `$2000 - $4999`: 0.10 per trade.
   - `$5000+`: Scaling (0.20 base or 2% risk).
5. **Breakeven**: Once Trade 1 hits TP, Trade 2 SL is moved to **Entry + 25% TP buffer**.
6. **Zone Protection**: Once Trade 2 reaches 90% completion, SL is tightened to 85% TP to lock in gains.
7. **Opposite Signal**: If a SELL signal arrives while BUY trades are open, the EA will close all current buys and execute the sell immediately.
8. **Time Limit**: If a trade stays open > 120 minutes, SL is moved to Breakeven automatically.

## 🔐 Licensing
- The EA requires a valid **License Key** to operate.
- **Trial**: 7-Day Free Trial keys (`GOLDAI-TEST-...`) are available via the Telegram Bot.
- **Premium**: Full 30-day keys (`GOLDAI-XXXX-...`) unlock unlimited trading.
- The EA checks license validity on startup and every hour. If expired, it stops trading immediately.

## 🚀 Verification
Check the **Experts** tab in MT5 to see logs like:
`🔑 Verifying License Key: GOLDAI-TEST-123`
`✅ License Valid! Expires: 2024-05-20`
`📥 New Signal Received: BUY ID: SIG-123`
`🛡️ TP1 Secured: Moving T2 Ticket 123456 to BE + 25% Buffer`
