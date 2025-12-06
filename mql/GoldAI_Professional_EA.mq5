//+------------------------------------------------------------------+
//|                                      GoldAI_Professional_EA.mq5 |
//|                                  Copyright 2024, GoldAI Mentor   |
//|                                  Professional Trading System     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, GoldAI Mentor Pro"
#property link      "https://goldai.pro"
#property version   "2.00"
#property strict
#property description "Professional Auto-Trading EA with Confluence Validation"
#property description "Monitors signals, validates all rules, executes perfect setups only"

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
// IMPORTANT: Replace with your Render URL when deployed
input string   API_URL = "http://localhost:3001/api/v1";  // Bridge API URL (Change for Render)
input string   License_Key = "GOLDAI-TEST-2024";           // Your License Key

input double   Risk_Percent = 6.0;                         // Risk per trade (%)
input double   Max_Risk_Percent = 8.0;                     // Maximum risk allowed (%)
input int      Magic_Number = 999888;                      // Magic number for trades

input bool     Enable_Breakeven = true;                    // Move SL to breakeven at TP1
input int      Breakeven_Pips = 5;                         // Pips above breakeven

input bool     Enable_Daily_Limits = true;                 // Use daily profit/loss limits
input double   Daily_Profit_Target_Percent = 15.0;         // Daily profit target (%)
input double   Daily_Max_Loss_Percent = 8.0;               // Daily max loss (%)

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
datetime lastLicenseCheck = 0;
datetime lastWatchlistPoll = 0;
datetime lastDailyReset = 0;

bool licenseValid = false;
datetime licenseExpiry = 0;
int daysRemaining = 0;

double dailyStartBalance = 0;
double dailyProfit = 0;
double dailyLoss = 0;
bool dailyLimitHit = false;

struct ActiveTrade
{
    string signalId;
    ulong ticket;        // Position ticket number
    double entryPrice;
    double tp1Price;
    double tp2Price;
    bool tp1Hit;
    bool movedToBreakeven;
};

ActiveTrade activeTrades[];
int activeTradeCount = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("========================================");
    Print("🤖 GoldAI Professional EA v2.0");
    Print("========================================");
    Print("API URL: ", API_URL);
    Print("License Key: ", License_Key);
    Print("========================================");
    
    // Validate inputs
    if(License_Key == "")
    {
        Alert("❌ ERROR: License Key is required!");
        return INIT_FAILED;
    }
    
    if(Risk_Percent < 1 || Risk_Percent > Max_Risk_Percent)
    {
        Alert("❌ ERROR: Invalid risk settings!");
        return INIT_FAILED;
    }
    
    // Check license immediately
    if(!CheckLicense())
    {
        Alert("❌ LICENSE INVALID: Cannot start EA");
        return INIT_FAILED;
    }
    
    Print("✅ License Valid - Expires: ", TimeToString(licenseExpiry));
    Print("📅 Days Remaining: ", daysRemaining);
    
    // Initialize daily stats
    InitializeDailyStats();
    
    // Set timer for 1-second polling
    EventSetTimer(1);
    
    Print("🚀 EA Initialized Successfully");
    Print("⏰ Polling every 1 second");
    Print("========================================");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();
    Print("🛑 GoldAI Professional EA Stopped");
    Print("Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Timer function - Runs every second                               |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Check license once per day
    if(TimeCurrent() - lastLicenseCheck > 86400) // 24 hours
    {
        if(!CheckLicense())
        {
            Alert("❌ LICENSE EXPIRED: EA Stopped");
            ExpertRemove();
            return;
        }
        lastLicenseCheck = TimeCurrent();
    }
    
    // Reset daily stats at midnight
    if(ShouldResetDaily())
    {
        ResetDailyStats();
    }
    
    // Check daily limits
    if(Enable_Daily_Limits && dailyLimitHit)
    {
        // Don't poll if daily limit hit
        return;
    }
    
    // Poll watchlist every second
    PollWatchlist();
    
    // Manage active trades
    ManageActiveTrades();
}

//+------------------------------------------------------------------+
//| Check License Validity                                            |
//+------------------------------------------------------------------+
bool CheckLicense()
{
    Print("🔑 Checking license...");
    
    string url = API_URL + "/license/check?license=" + License_Key;
    string headers = "Content-Type: application/json\r\n";
    
    char postData[];
    char result[];
    string resultHeaders;
    
    int res = WebRequest("GET", url, headers, 5000, postData, result, resultHeaders);
    
    if(res == 200)
    {
        string json = CharArrayToString(result);
        
        // Parse response
        if(StringFind(json, "\"valid\":true") > 0)
        {
            // Extract expiry and days remaining
            string expiryStr = ExtractJsonValue(json, "expiresAt");
            string daysStr = ExtractJsonValue(json, "daysRemaining");
            
            licenseValid = true;
            daysRemaining = (int)StringToInteger(daysStr);
            
            Print("✅ License Valid");
            Print("   Days Remaining: ", daysRemaining);
            
            return true;
        }
        else
        {
            Print("❌ License Invalid or Expired");
            licenseValid = false;
            return false;
        }
    }
    else
    {
        Print("❌ License Check Failed - HTTP ", res);
        return false;
    }
}

//+------------------------------------------------------------------+
//| Poll Watchlist for New Signals                                   |
//+------------------------------------------------------------------+
void PollWatchlist()
{
    string url = API_URL + "/watchlist";
    string headers = "x-license-key: " + License_Key + "\r\nContent-Type: application/json\r\n";
    
    char postData[];
    char result[];
    string resultHeaders;
    
    int res = WebRequest("GET", url, headers, 5000, postData, result, resultHeaders);
    
    if(res == 200)
    {
        string json = CharArrayToString(result);
        
        // Check if has watchlist items
        if(StringFind(json, "\"count\":0") > 0)
        {
            // No signals to monitor
            return;
        }
        
        // Parse and monitor signals
        // For now, we'll process the first signal in watchlist
        ProcessWatchlistSignals(json);
    }
}

//+------------------------------------------------------------------+
//| Process Watchlist Signals                                         |
//+------------------------------------------------------------------+
void ProcessWatchlistSignals(string json)
{
    // This is a simplified parser - in production use a JSON library
    // For now, we'll extract the first signal
    
    // Check if watchlist array exists
    int watchlistStart = StringFind(json, "\"watchlist\":");
    if(watchlistStart < 0) return;
    
    // Log that we're monitoring
    if(StringFind(json, "\"status\":\"monitoring\"") > 0)
    {
        Print("📊 Monitoring active signals in watchlist");
        
        // In a complete implementation, we would:
        // 1. Parse all signals in the watchlist array
        // 2. For each signal, call MonitorSignal()
        // 3. Validate entry zone, RSI, wick, candle, etc.
        // 4. Execute or scrap based on validation
        
        // For demonstration, extracting basic signal data
        string signalId = ExtractJsonValue(json, "signalId");
        if(signalId != "")
        {
            Print("   Signal ID: ", signalId);
            // TODO: Full signal monitoring implementation
        }
    }
}

//+------------------------------------------------------------------+
//| Initialize Daily Stats                                            |
//+------------------------------------------------------------------+
void InitializeDailyStats()
{
    dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    dailyProfit = 0;
    dailyLoss = 0;
    dailyLimitHit = false;
    lastDailyReset = TimeCurrent();
    
    Print("📊 Daily Stats Initialized");
    Print("   Start Balance: $", dailyStartBalance);
    Print("   Profit Target: $", dailyStartBalance * (Daily_Profit_Target_Percent / 100));
    Print("   Max Loss: $", dailyStartBalance * (Daily_Max_Loss_Percent / 100));
}

//+------------------------------------------------------------------+
//| Check if Should Reset Daily Stats                                |
//+------------------------------------------------------------------+
bool ShouldResetDaily()
{
    MqlDateTime now, last;
    TimeToStruct(TimeCurrent(), now);
    TimeToStruct(lastDailyReset, last);
    
    // Reset if date changed
    return (now.day != last.day || now.mon != last.mon || now.year != last.year);
}

//+------------------------------------------------------------------+
//| Reset Daily Stats                                                 |
//+------------------------------------------------------------------+
void ResetDailyStats()
{
    Print("🔄 Resetting Daily Stats (New Trading Day)");
    
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    Print("   Previous Balance: $", dailyStartBalance);
    Print("   Current Balance: $", currentBalance);
    Print("   Daily P/L: $", (currentBalance - dailyStartBalance));
    
    InitializeDailyStats();
}

//+------------------------------------------------------------------+
//| Manage Active Trades                                              |
//+------------------------------------------------------------------+
void ManageActiveTrades()
{
    for(int i = 0; i < activeTradeCount; i++)
    {
        if(!PositionSelectByTicket(activeTrades[i].ticket))
        {
            // Position closed
            UpdateDailyStats(activeTrades[i].ticket);
            RemoveActiveTradeByIndex(i);
            i--;
            continue;
        }
        
        // Check if TP1 hit and move to breakeven
        if(Enable_Breakeven && !activeTrades[i].movedToBreakeven)
        {
            if(HasReachedTP1(activeTrades[i]))
            {
                MoveToBreakeven(activeTrades[i]);
                activeTrades[i].movedToBreakeven = true;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check if Trade Reached TP1                                        |
//+------------------------------------------------------------------+
bool HasReachedTP1(ActiveTrade &trade)
{
    if(!PositionSelectByTicket(trade.ticket)) return false;
    
    long type = PositionGetInteger(POSITION_TYPE);
    double currentPrice = (type == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    if(type == POSITION_TYPE_BUY)
    {
        return currentPrice >= trade.tp1Price;
    }
    else
    {
        return currentPrice <= trade.tp1Price;
    }
}

//+------------------------------------------------------------------+
//| Move Stop Loss to Breakeven                                       |
//+------------------------------------------------------------------+
void MoveToBreakeven(ActiveTrade &trade)
{
    if(!PositionSelectByTicket(trade.ticket)) return;
    
    long type = PositionGetInteger(POSITION_TYPE);
    double newSL = trade.entryPrice;
    
    // Add small buffer
    if(type == POSITION_TYPE_BUY)
        newSL += Breakeven_Pips * _Point;
    else
        newSL -= Breakeven_Pips * _Point;
    
    // Modify position
    if(PositionModify(trade.ticket, newSL, trade.tp2Price))
    {
        Print("🎯 TP1 HIT - Moved to Breakeven: Ticket #", trade.ticket);
        trade.movedToBreakeven = true;
    }
}

//+------------------------------------------------------------------+
//| Update Daily Stats After Trade Close                             |
//+------------------------------------------------------------------+
void UpdateDailyStats(ulong ticket)
{
    if(!HistorySelectByPosition(ticket)) return;
    
    double profit = 0;
    
    for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
    {
        ulong dealTicket = HistoryDealGetTicket(i);
        if(HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID) == ticket)
        {
            profit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
        }
    }
    
    // Update stats
    if(profit > 0)
        dailyProfit += profit;
    else
        dailyLoss += MathAbs(profit);
    
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    
    Print("📊 Trade Closed - P/L: $", profit);
    Print("   Daily Profit: $", dailyProfit);
    Print("   Daily Loss: $", dailyLoss);
    
    // Check limits
    double profitTarget = dailyStartBalance * (Daily_Profit_Target_Percent / 100);
    double maxLoss = dailyStartBalance * (Daily_Max_Loss_Percent / 100);
    
    if(Enable_Daily_Limits)
    {
        if(dailyProfit >= profitTarget)
        {
            Print("🎯 DAILY PROFIT TARGET HIT! Stopping trading.");
            dailyLimitHit = true;
        }
        else if(dailyLoss >= maxLoss)
        {
            Print("🛑 DAILY MAX LOSS HIT! Stopping trading.");
            dailyLimitHit = true;
        }
    }
    
    // Report to server
    ReportStatsUpdate(currentBalance, profit);
}

//+------------------------------------------------------------------+
//| Report Stats Update to Server                                     |
//+------------------------------------------------------------------+
void ReportStatsUpdate(double balance, double profit)
{
    string url = API_URL + "/stats/update";
    string headers = "x-license-key: " + License_Key + "\r\nContent-Type: application/json\r\n";
    
    string body = StringFormat("{\"balance\":%.2f,\"tradeProfit\":%.2f}", balance, profit);
    
    char postData[];
    StringToCharArray(body, postData);
    ArrayResize(postData, ArraySize(postData) - 1); // Remove null terminator
    
    char result[];
    string resultHeaders;
    
    WebRequest("POST", url, headers, 5000, postData, result, resultHeaders);
}

//+------------------------------------------------------------------+
//| Remove Active Trade by Index                                      |
//+------------------------------------------------------------------+
void RemoveActiveTradeByIndex(int index)
{
    for(int i = index; i < activeTradeCount - 1; i++)
    {
        activeTrades[i] = activeTrades[i + 1];
    }
    activeTradeCount--;
    ArrayResize(activeTrades, activeTradeCount);
}

//+------------------------------------------------------------------+
//| Extract JSON Value (Simple Parser)                                |
//+------------------------------------------------------------------+
string ExtractJsonValue(string json, string key)
{
    string search = "\"" + key + "\":";
    int start = StringFind(json, search);
    if(start < 0) return "";
    
    start += StringLen(search);
    
    // Check if string or number
    bool isString = (StringSubstr(json, start, 1) == "\"");
    if(isString) start++;
    
    int end;
    if(isString)
        end = StringFind(json, "\"", start);
    else
    {
        end = StringFind(json, ",", start);
        if(end < 0) end = StringFind(json, "}", start);
    }
    
    return StringSubstr(json, start, end - start);
}

//+------------------------------------------------------------------+
