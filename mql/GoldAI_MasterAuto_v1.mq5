//+------------------------------------------------------------------+
//|                                     GoldAI_MasterAuto_v1.mq5      |
//|                          Copyright 2024, GoldAI Mentor Pro        |
//|                                       https://goldai.pro          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, GoldAI Mentor Pro"
#property link      "https://goldai.pro"
#property version   "1.00"
#property strict
#property description "Gold signal execution & management EA (MT5)"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input string   API_URL = "https://goldai-bridge-is7d.onrender.com/api/v1";  // Bridge API URL
input string   License_Key = "GOLDAI-TEST-XXXX";                      // License Key (Required)
input int      Poll_Interval = 60;                                    // Poll Bridge every X seconds
input int      Magic_Number = 112233;                                 // Magic Number
input int      Max_Trades_Per_Day = 5;                               // Risk Control: Max trades/day
input double   Max_Daily_Drawdown_Percent = 5.0;                      // Risk Control: Max daily loss %
input double   TP1_Ratio = 0.40;                                      // TP1 target (40% of signal TP distance)
input int      Safety_Close_Minutes = 120;                            // Move to BE after X minutes
//--- DEBUG SETTINGS ---
input bool     Enable_Debug_Mode = true;                             // Enable detailed debug prints
input int      Max_Account_Info_Retries = 50;                        // Max retries for account data (50 ticks)
input int      Retry_Delay_MS = 100;                                 // Delay between retries (ms)

// Session Hours (GMT)
input int      London_Start = 8;                                      // London Start Hour
input int      London_End = 17;                                       // London End Hour
input int      NY_Start = 13;                                         // NY Start Hour
input int      NY_End = 22;                                           // NY End Hour

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
CTrade         trade;
CPositionInfo  pos;
datetime       last_poll_time = 0;
string         last_signal_id = "";
string         current_signal_type = ""; // To track opposite signals
int            trades_today = 0;
datetime       last_trade_day = 0;
double         starting_balance_today = 0;
bool           is_license_valid = false;
datetime       last_license_check = 0;
string         license_status_msg = "Checking License...";
//--- DEBUG VARIABLES ---
bool           account_info_loaded = false;
int            account_info_retries = 0;

//+------------------------------------------------------------------+
//| STRUCTURES                                                        |
//+------------------------------------------------------------------+
struct SignalData
{
    string id;
    string symbol;
    string type;
    double entry;
    double sl;
    double tp;
    double tp2;
    double tp3;
    double tp4;
    double confidence;
    string grade;
    datetime timestamp;
};

//+------------------------------------------------------------------+
//| DEBUG HELPER FUNCTIONS                                            |
//+------------------------------------------------------------------+
void DebugPrint(string message)
{
    if(Enable_Debug_Mode)
    {
        Print(TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), " [DEBUG] ", message);
    }
}

string ErrorDescription(int error_code)
{
    switch(error_code)
    {
        case 0:   return "No error";
        case 1:   return "No error, but result unknown";
        case 2:   return "Common error";
        case 3:   return "Invalid trade parameters";
        case 4:   return "Trade server is busy";
        case 5:   return "Old version of the client terminal";
        case 6:   return "No connection with trade server";
        case 4014:return "WebRequest not allowed (add URL to Options > Expert Advisors)";
        case 4016:return "WebRequest timeout";
        case 4017:return "WebRequest failed";
        default:  return "Unknown error " + IntegerToString(error_code);
    }
}

void PrintAccountInfo()
{
    if(!Enable_Debug_Mode) return;
    
    DebugPrint("=== ACCOUNT INFO ===");
    DebugPrint("Login: " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)));
    DebugPrint("Name: " + AccountInfoString(ACCOUNT_NAME));
    DebugPrint("Company: " + AccountInfoString(ACCOUNT_COMPANY));
    DebugPrint("Balance: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
    DebugPrint("Equity: " + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2));
    DebugPrint("Free Margin: " + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 2));
    DebugPrint("Margin: " + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN), 2));
    DebugPrint("Leverage: 1:" + IntegerToString(AccountInfoInteger(ACCOUNT_LEVERAGE)));
    DebugPrint("Profit: " + DoubleToString(AccountInfoDouble(ACCOUNT_PROFIT), 2));
    DebugPrint("=== END ACCOUNT INFO ===");
}

bool WaitForAccountInfo(int max_retries = 50, int delay_ms = 100)
{
    for(int i = 0; i < max_retries; i++)
    {
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        if(balance > 0)
        {
            DebugPrint("Account info loaded successfully on attempt " + IntegerToString(i+1));
            PrintAccountInfo();
            return true;
        }
        
        if(i == 0)
        {
            DebugPrint("Waiting for account information... (This is normal on EA startup)");
            DebugPrint("Tip: Account data is often not available in OnInit(). Wait for OnTick().");
        }
        
        // Replace Sleep with MT5 compatible delay
        int startTime = GetTickCount();
        while(GetTickCount() - startTime < delay_ms && !IsStopped())
        {
            // Wait without blocking other experts
        }
        
        // Force refresh of symbol data
        MqlTick last_tick;
        SymbolInfoTick(_Symbol, last_tick);
    }
    
    DebugPrint("WARNING: Failed to load account information after " + IntegerToString(max_retries) + " retries");
    DebugPrint("Check terminal connection and ensure you're logged into a valid account.");
    return false;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    trade.SetExpertMagicNumber(Magic_Number);
    
    DebugPrint("🚀 GoldAI Master EA v1.0 Initializing...");
    DebugPrint("Terminal Build: " + IntegerToString(TerminalInfoInteger(TERMINAL_BUILD)));
    DebugPrint("Terminal Connected: " + (TerminalInfoInteger(TERMINAL_CONNECTED) ? "Yes" : "No"));
    DebugPrint("Symbol: " + _Symbol);
    DebugPrint("Chart Period: " + IntegerToString(_Period));
    
    // Initial attempt to get account info (may fail)
    starting_balance_today = AccountInfoDouble(ACCOUNT_BALANCE);
    DebugPrint("Initial balance check in OnInit: " + DoubleToString(starting_balance_today, 2));
    
    last_trade_day = iTime(_Symbol, PERIOD_D1, 0);
    
    Print("🔑 Verifying License Key: ", License_Key);
    
    // Initial License Check
    CheckLicense();
    
    if(!is_license_valid)
    {
        Print("❌ LICENSE INVALID: ", license_status_msg);
        return(INIT_FAILED);
    }
    
    Print("✅ License Valid! Expires: ", license_status_msg);
    Print("Magic Number: ", Magic_Number);
    
    // Note: We'll wait for account info in OnTick()
    DebugPrint("OnInit completed. Account info will be loaded in OnTick().");
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    DebugPrint("🛑 GoldAI Master EA Stopped. Reason: " + IntegerToString(reason));
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // 0. Ensure account info is loaded (critical for first tick)
    if(!account_info_loaded)
    {
        if(WaitForAccountInfo(Max_Account_Info_Retries, Retry_Delay_MS))
        {
            account_info_loaded = true;
            starting_balance_today = AccountInfoDouble(ACCOUNT_BALANCE);
            DebugPrint("💰 Current Balance: " + DoubleToString(starting_balance_today, 2));
            DebugPrint("📊 Current Equity: " + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2));
            DebugPrint("📅 Starting Daily Balance: " + DoubleToString(starting_balance_today, 2));
        }
        else
        {
            // Continue anyway but log warning
            DebugPrint("⚠️ Trading with unconfirmed account info. Trades may fail.");
        }
    }

    // 1. Periodic License Check (Every 1 hour)
    if(TimeCurrent() - last_license_check > 3600)
    {
        CheckLicense();
        if(!is_license_valid)
        {
            DebugPrint("🛑 LICENSE EXPIRED/INVALID. Stopping trading.");
            return;
        }
    }

    if(!is_license_valid) return;

    // 2. Manage existing positions
    ManagePositions();

    // 3. Poll for new signals
    if(TimeCurrent() - last_poll_time >= Poll_Interval)
    {
        PollForSignal();
        last_poll_time = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Poll for signals from Bridge                                      |
//+------------------------------------------------------------------+
void PollForSignal()
{
    string url = API_URL + "/watchlist";
    string headers = "Content-Type: application/json\r\n";
    char postData[], result[];
    string resultHeaders;

    DebugPrint("Polling API: " + url);
    
    // IMPORTANT: Ensure URL is in allow list: Tools → Options → Expert Advisors[reference:1]
    int res = WebRequest("GET", url, headers, 5000, postData, result, resultHeaders);

    if(res == 200)
    {
        DebugPrint("API response OK (200)");
        string response = CharArrayToString(result);
        DebugPrint("Response length: " + IntegerToString(StringLen(response)));
        ProcessSignal(response);
    }
    else
    {
        int lastError = GetLastError();
        DebugPrint("WebRequest failed. HTTP Code: " + IntegerToString(res) + 
                  ", Error: " + ErrorDescription(lastError));
        
        if(lastError == 4014)
        {
            DebugPrint("⚠️ Add '" + API_URL + "' to: Tools → Options → Expert Advisors → Allow WebRequest for listed URL");
        }
    }
}

//+------------------------------------------------------------------+
//| Process JSON signal response                                     |
//+------------------------------------------------------------------+
void ProcessSignal(string json)
{
    // Basic JSON parsing (simplified for the example)
    if(StringFind(json, "\"signalId\"") == -1) 
    {
        DebugPrint("No signalId in JSON response");
        return;
    }

    SignalData sig;
    sig.id = GetJsonValue(json, "signalId");
    sig.symbol = GetJsonValue(json, "symbol");
    sig.type = GetJsonValue(json, "type");
    sig.entry = StringToDouble(GetJsonValue(json, "entry"));
    sig.sl = StringToDouble(GetJsonValue(json, "sl"));
    sig.tp = StringToDouble(GetJsonValue(json, "tp"));
    sig.tp2 = StringToDouble(GetJsonValue(json, "tp2"));
    sig.tp3 = StringToDouble(GetJsonValue(json, "tp3"));
    sig.tp4 = StringToDouble(GetJsonValue(json, "tp4"));
    sig.confidence = StringToDouble(GetJsonValue(json, "confidence"));
    sig.grade = GetJsonValue(json, "grade");

    DebugPrint("Parsed Signal: " + sig.symbol + " " + sig.type + 
              " Entry:" + DoubleToString(sig.entry, 2) +
              " SL:" + DoubleToString(sig.sl, 2) +
              " TP1:" + DoubleToString(sig.tp, 2) +
              " TP2:" + DoubleToString(sig.tp2, 2) +
              " TP3:" + DoubleToString(sig.tp3, 2) +
              " TP4:" + DoubleToString(sig.tp4, 2));

    // Skip if it's the same signal we already processed
    if(sig.id == last_signal_id && last_signal_id != "") 
    {
        DebugPrint("Duplicate signal ID: " + sig.id + " - skipping");
        return;
    }
    
    // Skip if not XAUUSD
    if(sig.symbol != "XAUUSD") 
    {
        DebugPrint("Signal symbol mismatch: " + sig.symbol + " (expected XAUUSD)");
        return;
    }

    Print("📥 [MATCH] New Gold Signal: ", sig.type, " | ID: ", sig.id, " | Entry: ", sig.entry);

    // Check for opposite signal
    if(current_signal_type != "" && sig.type != current_signal_type)
    {
        Print("⚠️ Opposite signal detected! Closing current trades...");
        CloseAllTrades();
    }

    // Validate execution
    if(CanTrade(sig))
    {
        ExecuteSplitTrade(sig);
    }
    else
    {
        DebugPrint("CanTrade() returned false - signal not executed");
    }
}

//+------------------------------------------------------------------+
//| Check if trade conditions are met                                |
//+------------------------------------------------------------------+
bool CanTrade(SignalData &sig)
{
    DebugPrint("=== CanTrade() Validation ===");
    
    // 0. Reset daily stats if new day
    datetime currentDay = iTime(_Symbol, PERIOD_D1, 0);
    if(currentDay != last_trade_day)
    {
        trades_today = 0;
        starting_balance_today = AccountInfoDouble(ACCOUNT_BALANCE);
        last_trade_day = currentDay;
        DebugPrint("🌅 New Day Started. Resetting daily stats.");
        DebugPrint("New starting balance: " + DoubleToString(starting_balance_today, 2));
    }

    // 1. Session Check (GMT)
    MqlDateTime gmt;
    TimeGMT(gmt);
    
    bool isLondon = (gmt.hour >= London_Start && gmt.hour < London_End);
    bool isNY = (gmt.hour >= NY_Start && gmt.hour < NY_End);
    
    DebugPrint("GMT Time: " + IntegerToString(gmt.hour) + ":" + IntegerToString(gmt.min));
    DebugPrint("London Session: " + (isLondon ? "Open" : "Closed"));
    DebugPrint("NY Session: " + (isNY ? "Open" : "Closed"));
    
    if(!isLondon && !isNY)
    {
        DebugPrint("❌ Outside trading sessions. London/NY only.");
        return false;
    }

    // 2. Already open check
    int openPositions = CountOpenPositions();
    DebugPrint("Open positions: " + IntegerToString(openPositions));
    if(openPositions > 0)
    {
        DebugPrint("❌ Already have open positions. One signal at a time.");
        return false;
    }

    // 3. Daily Trade Limit Check
    DebugPrint("Trades today: " + IntegerToString(trades_today) + 
              " (Max: " + IntegerToString(Max_Trades_Per_Day) + ")");
    if(trades_today >= Max_Trades_Per_Day)
    {
        DebugPrint("❌ Daily trade limit reached (" + IntegerToString(Max_Trades_Per_Day) + ")");
        return false;
    }

    // 4. Daily Drawdown Check
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    double dailyLoss = starting_balance_today - currentEquity;
    double maxLossAmount = starting_balance_today * (Max_Daily_Drawdown_Percent / 100.0);
    
    DebugPrint("Daily Loss: " + DoubleToString(dailyLoss, 2) + 
              " (Limit: " + DoubleToString(maxLossAmount, 2) + ")");
    
    if(dailyLoss >= maxLossAmount)
    {
        DebugPrint("❌ Daily drawdown limit reached (" + DoubleToString(Max_Daily_Drawdown_Percent) + "%)");
        return false;
    }

    // 5. Margin Check
    double lotSize = CalculateTierLotSize();
    DebugPrint("Calculated lot size: " + DoubleToString(lotSize, 2));
    
    if(lotSize <= 0)
    {
        DebugPrint("❌ Invalid lot size calculated: " + DoubleToString(lotSize));
        return false;
    }

    double requiredMargin = 0.0;
    ENUM_ORDER_TYPE marginOrderType = (sig.type == "BUY") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    double marginPrice = (sig.type == "BUY") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    if(!OrderCalcMargin(marginOrderType, _Symbol, lotSize * 2, marginPrice, requiredMargin))
    {
        int error = GetLastError();
        DebugPrint("❌ Failed to calculate margin. Error: " + ErrorDescription(error));
        return false;
    }
    
    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    DebugPrint("Required margin: " + DoubleToString(requiredMargin, 2) + 
              ", Free margin: " + DoubleToString(freeMargin, 2));
    
    if(requiredMargin > freeMargin)
    {
        DebugPrint("❌ Insufficient free margin for 2 positions");
        return false;
    }

    DebugPrint("✅ All trade conditions met");
    return true;
}

//+------------------------------------------------------------------+
//| Calculate Lot Size based on Tier logic                           |
//+------------------------------------------------------------------+
double CalculateTierLotSize()
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    DebugPrint("CalculateTierLotSize() - Balance: " + DoubleToString(balance, 2));
    
    double lotPerTrade = 0.01;

    if(balance < 500)       lotPerTrade = 0.01;
    else if(balance < 1000) lotPerTrade = 0.02;
    else if(balance < 2000) lotPerTrade = 0.05;
    else if(balance < 5000) lotPerTrade = 0.10;
    else 
    {
        // 2% Risk calculation for $5000+
        double riskAmount = balance * 0.02;
        // Simplified pip value for XAUUSD (approx $10 per lot per pip)
        // This is a simplification - adjust based on your risk management
        lotPerTrade = 0.20; // Default for scaling
        DebugPrint("Tier 5000+ - Risk amount: " + DoubleToString(riskAmount, 2));
    }

    DebugPrint("Calculated lot size: " + DoubleToString(lotPerTrade, 2));
    return NormalizeDouble(lotPerTrade, 2);
}

//+------------------------------------------------------------------+
//| Execute Split Trades                                              |
//+------------------------------------------------------------------+
void ExecuteSplitTrade(SignalData &sig)
{
    double lot = CalculateTierLotSize();
    
    // Split into 4 parts
    double splitLot = NormalizeDouble(lot / 4.0, 2);
    if(splitLot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) splitLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

    double price = (sig.type == "BUY") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Validate entry price (within 10 pips of signal)
    if(MathAbs(price - sig.entry) > 1.00) // 10 pips = $1.00 on XAUUSD
    {
        Print("⚠️ Price deviated too much from signal entry. Price: ", price, " Signal Entry: ", sig.entry);
        return;
    }

    DebugPrint("Executing 4-Way Split Trade. Total Lot: " + DoubleToString(lot, 2) + " Split Lot: " + DoubleToString(splitLot, 2));

    // Open 4 positions
    if(sig.type == "BUY") {
        trade.Buy(splitLot, _Symbol, price, sig.sl, sig.tp, "T1:" + sig.id);
        trade.Buy(splitLot, _Symbol, price, sig.sl, sig.tp2, "T2:" + sig.id);
        trade.Buy(splitLot, _Symbol, price, sig.sl, sig.tp3, "T3:" + sig.id);
        trade.Buy(splitLot, _Symbol, price, sig.sl, sig.tp4, "T4:" + sig.id);
    } else {
        trade.Sell(splitLot, _Symbol, price, sig.sl, sig.tp, "T1:" + sig.id);
        trade.Sell(splitLot, _Symbol, price, sig.sl, sig.tp2, "T2:" + sig.id);
        trade.Sell(splitLot, _Symbol, price, sig.sl, sig.tp3, "T3:" + sig.id);
        trade.Sell(splitLot, _Symbol, price, sig.sl, sig.tp4, "T4:" + sig.id);
    }

    last_signal_id = sig.id;
    current_signal_type = sig.type;
    trades_today++;
    
    DebugPrint("✅ Successfully opened 4 split positions for Signal " + sig.id);
    BroadcastTradeEvent("OPEN", price, splitLot * 4, sig.sl, sig.id);
}

//+------------------------------------------------------------------+
//| Manage Open Positions Logic                                       |
//+------------------------------------------------------------------+
void ManagePositions()
{
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Scan all open positions for this EA
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(pos.SelectByIndex(i))
        {
            if(pos.Magic() == Magic_Number)
            {
                ulong ticket = pos.Ticket();
                double entry = pos.PriceOpen();
                double sl = pos.StopLoss();
                double tp = pos.TakeProfit();
                long type = pos.PositionType();

                double profitPips = (type == POSITION_TYPE_BUY) ? (currentPrice - entry) : (entry - currentPrice);
                profitPips = profitPips * 10.0; // Assume 0.10 = 1 pip for Gold

                // 1. Profit-based Breakeven: Once 30 pips in profit reached
                if(profitPips >= 30.0)
                {
                    bool alreadyBE = (type == POSITION_TYPE_BUY) ? (sl >= entry) : (sl <= entry);
                    if(!alreadyBE)
                    {
                        if(trade.PositionModify(ticket, entry, tp))
                        {
                            DebugPrint("🛡️ Breakeven triggered (+30 pips): Ticket " + IntegerToString(ticket));
                        }
                    }
                }

                // 2. Trailing/Zone Protection: If close to TP, lock more profit
                double tpDistance = MathAbs(tp - entry);
                if(tpDistance > 0)
                {
                    double completion = MathAbs(currentPrice - entry) / tpDistance;
                    if(completion >= 0.85)
                    {
                        double secureSL = (type == POSITION_TYPE_BUY) ? entry + (tpDistance * 0.75) : entry - (tpDistance * 0.75);
                        bool alreadySecured = (type == POSITION_TYPE_BUY) ? (sl >= secureSL) : (sl <= secureSL);
                        
                        if(!alreadySecured)
                        {
                            trade.PositionModify(ticket, secureSL, tp);
                            DebugPrint("🎯 Zone Protection (85% TP): Secured profit on Ticket " + IntegerToString(ticket));
                        }
                    }
                }
            }
        }
    }

    // Auto-reset signal type if all closed
    if(CountOpenPositions() == 0 && current_signal_type != "")
    {
        current_signal_type = "";
        DebugPrint("🏁 Sequence complete. System ready.");
    }
}

//+------------------------------------------------------------------+
//| Close all trades with matching magic number                      |
//+------------------------------------------------------------------+
void CloseAllTrades()
{
    DebugPrint("Closing all trades...");
    int closedCount = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(pos.SelectByIndex(i))
        {
            if(pos.Magic() == Magic_Number)
            {
                ulong ticket = pos.Ticket();
                double price = pos.PriceCurrent();
                double vol = pos.Volume();
                string comment = pos.Comment();
                
                DebugPrint("Closing ticket " + IntegerToString(ticket) + 
                          " Comment: " + comment +
                          " Volume: " + DoubleToString(vol, 2));
                
                if(trade.PositionClose(ticket))
                {
                    closedCount++;
                    BroadcastTradeEvent("CLOSE", price, vol, 0, comment);
                }
                else
                {
                    int error = GetLastError();
                    DebugPrint("❌ Failed to close ticket " + IntegerToString(ticket) + 
                              ". Error: " + ErrorDescription(error));
                }
            }
        }
    }
    
    DebugPrint("Closed " + IntegerToString(closedCount) + " positions");
}

//+------------------------------------------------------------------+
//| Count open positions for this EA                                 |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(pos.SelectByIndex(i))
        {
            if(pos.Magic() == Magic_Number) count++;
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Extract value from simple JSON string (internal use only)       |
//+------------------------------------------------------------------+
string GetJsonValue(string json, string key)
{
    string search = "\"" + key + "\":";
    int startIdx = StringFind(json, search);
    if(startIdx == -1) return "";
    
    startIdx += StringLen(search);
    
    // Skip any potential spaces after colon
    while(startIdx < StringLen(json) && 
          (StringSubstr(json, startIdx, 1) == " " || StringSubstr(json, startIdx, 1) == "\t"))
    {
        startIdx++;
    }
    
    // Check if value is string or number
    int endIdx;
    if(StringSubstr(json, startIdx, 1) == "\"")
    {
        startIdx++; // Skip opening quote
        endIdx = StringFind(json, "\"", startIdx);
    }
    else
    {
        // For numbers, find next separator
        endIdx = StringFind(json, ",", startIdx);
        if(endIdx == -1) endIdx = StringFind(json, "}", startIdx);
        if(endIdx == -1) endIdx = StringFind(json, " ", startIdx);
    }
    
    if(endIdx == -1) return "";
    
    string result = StringSubstr(json, startIdx, endIdx - startIdx);
    StringTrimLeft(result);
    StringTrimRight(result);
    
    return result;
}

//+------------------------------------------------------------------+
//| Check License Validity against Bridge API                        |
//+------------------------------------------------------------------+
void CheckLicense()
{
    string url = API_URL + "/license/check?key=" + License_Key + "&account=" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
    string headers = "Content-Type: application/json\r\n";
    char postData[], result[];
    string resultHeaders;
    
    DebugPrint("Checking license: " + url);
    
    int res = WebRequest("GET", url, headers, 5000, postData, result, resultHeaders);
    
    if(res == 200)
    {
        string json = CharArrayToString(result);
        string success = GetJsonValue(json, "success");
        string message = GetJsonValue(json, "message");
        
        DebugPrint("License response: " + json);
        
        if(success == "true")
        {
            is_license_valid = true;
            string expires = GetJsonValue(json, "expiresAt");
            license_status_msg = StringSubstr(expires, 0, 10);
            DebugPrint("✅ License Verification: VALID (Expires: " + license_status_msg + ")");
        }
        else
        {
            is_license_valid = false;
            license_status_msg = message;
            DebugPrint("❌ License Verification: FAILED (" + message + ")");
        }
    }
    else
    {
        int lastError = GetLastError();
        DebugPrint("⚠️ License Check Failed: HTTP " + IntegerToString(res) + 
                  ", Error: " + ErrorDescription(lastError));
        
        // If network error but previously valid, keep valid for now
        if(!is_license_valid)
        {
            license_status_msg = "Network Error " + IntegerToString(res);
        }
    }
    
    last_license_check = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Get volume of an active position                                 |
//+------------------------------------------------------------------+
double activePositionVolume(ulong ticket)
{
    if(PositionSelectByTicket(ticket)) 
    {
        double volume = PositionGetDouble(POSITION_VOLUME);
        DebugPrint("Volume for ticket " + IntegerToString(ticket) + ": " + DoubleToString(volume, 2));
        return volume;
    }
    DebugPrint("Failed to select position with ticket: " + IntegerToString(ticket));
    return 0;
}

//+------------------------------------------------------------------+
//| Broadcast trade event to copier via Bridge                       |
//+------------------------------------------------------------------+
void BroadcastTradeEvent(string operation, double price, double lots, double sl, string signalId)
{
    if(!Enable_Debug_Mode) return;
    
    string url = API_URL + "/copier/master/trade";
    
    string json = "{";
    json += "\"symbol\":\"XAUUSD\",";
    json += "\"type\":\"" + current_signal_type + "\",";
    json += "\"operation\":\"" + operation + "\",";
    json += "\"price\":" + DoubleToString(price, 5) + ",";
    json += "\"sl\":" + DoubleToString(sl, 5) + ",";
    json += "\"lotSize\":" + DoubleToString(lots, 2) + ",";
    json += "\"signalId\":\"" + signalId + "\"";
    json += "}";
    
    char postData[];
    StringToCharArray(json, postData, 0, StringLen(json));
    
    char result[];
    string resultHeaders;
    string headers = "Content-Type: application/json\r\n";
    
    DebugPrint("Broadcasting trade event: " + operation + " for " + signalId);
    
    int res = WebRequest("POST", url, headers, 5000, postData, result, resultHeaders);
    if(res != 200) 
    {
        int lastError = GetLastError();
        DebugPrint("⚠️ Copier Broadcast Failed: HTTP " + IntegerToString(res) + 
                  ", Error: " + ErrorDescription(lastError));
    }
    else
    {
        DebugPrint("✅ Copier broadcast successful");
    }
}
//+------------------------------------------------------------------+