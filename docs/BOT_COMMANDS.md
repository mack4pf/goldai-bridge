# 🤖 Gold AI Bridge Bot Commands

Here is the complete list of commands available in your **Gold AI Auto-Trading Bridge Bot**.

## 🚀 **User Commands**

### 1. Start & Setup
- **/start**  
  Initializes the bot and shows the welcome menu.

- **/activate <LICENSE_KEY>**  
  Activates your license to start receiving signals.  
  **Usage:** `/activate GOLDAI-TEST-XXXX`

### 2. Main Menu Actions
(Accessible via the custom keyboard buttons)

- **📊 My Stats**  
  View your daily trading performance, including:
  - Balance
  - Total Profit/Loss
  - Win Rate
  - Total Trades

- **📡 My Watchlist**  
  Shows the list of active signals your EA is currently monitoring. Displays entry prices, stop loss, and take profit targets.

- **🔑 My License**  
  Checks your current license status, type (Test/Monthly), and days remaining until expiration.

- **❓ Help**  
  Shows a quick guide on how to use the bot and set up the EA.

---

## 👑 **Admin Commands**
*(Visible only to the Admin User set in `.env`)*

- **👑 Create License**  
  Opens a menu to generate new licenses:
  - **🧪 Test License:** Generates a unique 5-day key (`GOLDAI-TEST-XXXX`).
  - **💎 Monthly License:** Generates a unique 30-day key.

- **📋 List Licenses**  
  Shows the last 20 generated licenses and their status (Active/Expired).

- **📊 User Stats**  
  Displays trading statistics (Balance, P/L) for all active users.
