# Gold AI Auto-Trading Bridge - Setup Guide

## 1. Server Setup
The bridge server manages users and signals.

1.  **Navigate to the folder**:
    ```bash
    cd gold-ai-auto-bridge
    ```
2.  **Install Dependencies** (if not done):
    ```bash
    npm install
    ```
3.  **Configure Environment**:
    *   Create a `.env` file in `gold-ai-auto-bridge/`.
    *   Add your new Bot Token:
        ```env
        BRIDGE_BOT_TOKEN=your_telegram_bot_token_here
        PORT=3001
        ```
4.  **Start the Server**:
    ```bash
    npm start
    ```

## 2. MT5 Setup (Expert Advisor)
1.  **Copy the EA**:
    *   Copy `mql/GoldAI_Execution_Bridge.mq5` to your MT5 Data Folder: `MQL5/Experts/`.
2.  **Compile**:
    *   Open MetaEditor, open the file, and click **Compile**.
3.  **Allow WebRequests**:
    *   In MT5, go to **Tools > Options > Expert Advisors**.
    *   Check **"Allow WebRequest for listed URL"**.
    *   Add: `http://localhost:3001`
4.  **Run the EA**:
    *   Drag the EA onto a chart (e.g., XAUUSD).
    *   **Inputs**:
        *   `API_URL`: `http://localhost:3001/api/v1`
        *   `Bridge_Token`: Get this from the Telegram Bot.

## 3. How to Use
1.  **Start the Bot**: Open your new Telegram bot and click `/start`.
2.  **Get Token**: Type `/connect` to get your unique Bridge Token.
3.  **Paste Token**: Enter this token into the EA settings in MT5.
4.  **Set Risk**: Type `/risk` to choose Conservative (1%) or Aggressive (3%).
5.  **Send Signals**:
    *   Your main system should send POST requests to `http://localhost:3001/api/v1/signals`.
    *   Example Payload:
        ```json
        {
          "symbol": "XAUUSD",
          "type": "BUY",
          "entry": 2050.50,
          "sl": 2045.00,
          "tp": 2060.00,
          "timeframe": "1h"
        }
        ```
