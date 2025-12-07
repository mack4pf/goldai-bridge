# 🤖 Gold AI Bridge Bot Commands

Here are the commands available for your Telegram Bot:

## 🚀 **Main Commands**

### `/start`
**Description:** Shows the welcome message and setup instructions.
**Usage:** Just type `/start` to verify the bot is online.

### `/connect`
**Description:** Generates your unique **Bridge Token**.
**Usage:**
1. Type `/connect`
2. Bot will reply with a token like `BRIDGE-123456789-xyz...`
3. Copy this token and paste it into the **EA Inputs** in MT5.

### `/risk`
**Description:** Sets your risk management preference.
**Usage:**
1. Type `/risk`
2. Click one of the buttons:
   - **🐢 Conservative:** 1% risk per trade
   - **🚀 Aggressive:** 3% risk per trade

---

## ⚠️ **Troubleshooting**
If the bot doesn't respond:
1. Check if `BRIDGE_BOT_TOKEN` is set in Render.
2. Check if `RENDER_EXTERNAL_URL` is set in Render.
3. Visit `https://your-bridge-url.onrender.com/debug` to check status.
