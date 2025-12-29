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
input string   API_URL = "https://goldai-bridge.onrender.com/api/v1";  // Your Render URL

input double   Risk_Percent = 2.0;                         // Risk per trade (%)
input double   Max_Risk_Percent = 5.0;                     // Maximum risk allowed (%)
input int      Magic_Number = 999888;                      // Magic number for trades

input bool     Enable_Breakeven = true;                    // Move SL to breakeven at TP1
input int      Breakeven_Pips = 5;                         // Pips above breakeven

input bool     Enable_Daily_Limits = true;                 // Use daily profit/loss limits
input double   Daily_Profit_Target_Percent = 15.0;         // Daily profit target (%)
input double   Daily_Max_Loss_Percent = 8.0;               // Daily max loss (%)

input bool     Enable_Email_Alerts = true;                 // Send email alerts
input bool     Enable_Push_Notifications = true;           // Send push notifications

// Price monitoring settings
input bool     Enable_Price_Monitoring = true;             // Wait for price to reach entry
input double   Entry_Zone_Pips = 5.0;                      // Entry zone in pips
input int      Max_Monitoring_Time = 1440;                 // Max minutes to monitor a signal (24h)

// Display settings
input bool     Show_Console_Output = true;                 // Show detailed console output
input bool     Show_Pending_Signals = true;                // Show pending signals info
input int      Console_Update_Interval = 5;                // Console update interval (seconds)

//+------------------------------------------------------------------+
//| STRUCTURES                                                        |
//+------------------------------------------------------------------+
struct SignalData
{
    string signalId;
    string symbol;
    string direction;       // "BUY" or "SELL"
    double entryPrice;
    double stopLoss;
    double takeProfit1;
    double takeProfit2;
    double confidence;
    string timestamp;
    bool validated;
    bool monitoring;        // Is being monitored for entry
    datetime monitoringStartTime;
    string status;          // "PENDING", "EXECUTED", "EXPIRED", "REJECTED"
    string reason;          // Reason for status
};

struct ActiveTrade
{
    string signalId;
    ulong ticket;
    double entryPrice;
    double stopLoss;
    double tp1Price;
    double tp2Price;
    bool tp1Hit;
    bool movedToBreakeven;
    datetime openTime;
    double currentProfit;
    double currentProfitPips;
};

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
datetime lastLicenseCheck = 0;
datetime lastWatchlistPoll = 0;
datetime lastDailyReset = 0;
datetime lastConsoleUpdate = 0;


double dailyStartBalance = 0;
double dailyProfit = 0;
double dailyLoss = 0;
bool dailyLimitHit = false;

// Trade management
int maxActiveTrades = 5;
int totalTradesToday = 0;
int signalsReceivedToday = 0;
int signalsExecutedToday = 0;
int signalsRejectedToday = 0;

// Signal monitoring
SignalData monitoredSignals[];  // Signals being monitored for entry
int monitoredSignalCount = 0;
ActiveTrade activeTrades[];
int activeTradeCount = 0;

// Performance tracking
datetime eaStartTime;
int totalSignalsReceived = 0;
int totalTradesExecuted = 0;
int totalTradesWon = 0;
int totalTradesLost = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    eaStartTime = TimeCurrent();
    
    Print("========================================");
    Print("🤖 GoldAI Professional EA v2.0");
    Print("========================================");
    Print("API URL: ", API_URL);
    Print("========================================");
    
    // Validate inputs
    if(Risk_Percent < 0.1 || Risk_Percent > Max_Risk_Percent)
    {
        Alert("❌ ERROR: Invalid risk settings!");
        return INIT_FAILED;
    }
    
    // Initialize arrays
    ArrayResize(activeTrades, 0);
    ArrayResize(monitoredSignals, 0);
    activeTradeCount = 0;
    monitoredSignalCount = 0;
    

    // Initialize daily stats
    InitializeDailyStats();
    
    // Set timer for 1-second polling
    EventSetTimer(1);
    
    Print("🚀 EA Initialized Successfully");
    Print("⏰ Polling every 1 second");
    Print("========================================");
    
    // Show initial console
    if(Show_Console_Output)
    {
        UpdateConsole();
    }
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();
    
    // Show final stats
    Print("========================================");
    Print("📊 FINAL STATISTICS");
    Print("   Total Signals Received: ", totalSignalsReceived);
    Print("   Total Trades Executed: ", totalTradesExecuted);
    Print("   Winning Trades: ", totalTradesWon);
    Print("   Losing Trades: ", totalTradesLost);
    Print("   Win Rate: ", (totalTradesExecuted > 0 ? DoubleToString((double)totalTradesWon/totalTradesExecuted*100, 1) : "0"), "%");
    Print("   EA Runtime: ", TimeToString(TimeCurrent() - eaStartTime, TIME_MINUTES));
    Print("========================================");
    
    Print("🛑 GoldAI Professional EA Stopped");
    Print("Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Timer function - Runs every second                               |
//+------------------------------------------------------------------+
void OnTimer()
{
    static int counter = 0;
    counter++;
    
    // Update console periodically
    if(Show_Console_Output && TimeCurrent() - lastConsoleUpdate >= Console_Update_Interval)
    {
        UpdateConsole();
        lastConsoleUpdate = TimeCurrent();
    }
    

    
    // Reset daily stats at midnight
    if(ShouldResetDaily())
    {
        ResetDailyStats();
    }
    
    // Check daily limits
    if(Enable_Daily_Limits && dailyLimitHit)
    {
        if(counter % 300 == 0) // Print every 5 minutes when limit hit
            Print("⚠️ Daily limit hit - Trading paused");
        return;
    }
    
    // Check maximum active trades
    if(activeTradeCount >= maxActiveTrades)
    {
        if(counter % 300 == 0) // Print every 5 minutes
            Print("⚠️ Maximum active trades reached: ", maxActiveTrades);
        return;
    }
    
    // Poll watchlist every 30 seconds
    if(counter % 30 == 0)
    {
        PollWatchlist();
    }
    
    // Monitor signals for entry every 2 seconds
    if(counter % 2 == 0 && Enable_Price_Monitoring)
    {
        MonitorSignalsForEntry();
    }
    
    // Manage active trades every 3 seconds
    if(counter % 3 == 0)
    {
        ManageActiveTrades();
    }
    
    // Update active trades profit every 5 seconds
    if(counter % 5 == 0)
    {
        UpdateActiveTradesProfit();
    }
    
    // Reset counter daily to prevent overflow
    if(counter > 86400) counter = 0;
}

//+------------------------------------------------------------------+
//| Update Console Display                                           |
//+------------------------------------------------------------------+
void UpdateConsole()
{
    if(!Show_Console_Output) return;
    
    string consoleText = "";
    
    // Header
    consoleText += "========================================\n";
    consoleText += "🤖 GOLDAI PROFESSIONAL EA - LIVE CONSOLE\n";
    consoleText += "========================================\n";
    
    // License status
    // License status
    consoleText += "📋 SYSTEM: ✅ MASTER S-VPS ONLINE\n";
    
    // Daily stats
    consoleText += "📊 DAILY STATS:\n";
    consoleText += "   Balance: $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\n";
    consoleText += "   Daily P/L: $" + DoubleToString(dailyProfit - dailyLoss, 2);
    if(dailyProfit > 0) consoleText += " (P: $" + DoubleToString(dailyProfit, 2) + ")";
    if(dailyLoss > 0) consoleText += " (L: $" + DoubleToString(dailyLoss, 2) + ")";
    consoleText += "\n";
    consoleText += "   Trades Today: " + IntegerToString(totalTradesToday) + "\n";
    consoleText += "   Daily Limit: " + (dailyLimitHit ? "🔴 HIT" : "🟢 ACTIVE") + "\n";
    
    // Active trades
    consoleText += "📈 ACTIVE TRADES: " + IntegerToString(activeTradeCount) + "/" + IntegerToString(maxActiveTrades) + "\n";
    for(int i = 0; i < activeTradeCount; i++)
    {
        if(PositionSelectByTicket(activeTrades[i].ticket))
        {
            string type = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? "BUY" : "SELL";
            double profit = PositionGetDouble(POSITION_PROFIT);
            string profitColor = profit >= 0 ? "🟢" : "🔴";
            
            consoleText += "   #" + IntegerToString(i+1) + ": " + activeTrades[i].signalId + " | " + type;
            consoleText += " | P/L: " + profitColor + "$" + DoubleToString(profit, 2);
            if(activeTrades[i].movedToBreakeven) consoleText += " | 🛡️ BREAKEVEN";
            if(activeTrades[i].tp1Hit) consoleText += " | 🎯 TP1 HIT";
            consoleText += "\n";
        }
    }
    
    // Pending signals
    if(Show_Pending_Signals && monitoredSignalCount > 0)
    {
        consoleText += "⏳ PENDING SIGNALS: " + IntegerToString(monitoredSignalCount) + "\n";
        for(int i = 0; i < monitoredSignalCount && i < 5; i++) // Show max 5
        {
            if(monitoredSignals[i].monitoring)
            {
                int minutesLeft = Max_Monitoring_Time - (int)((TimeCurrent() - monitoredSignals[i].monitoringStartTime) / 60);
                consoleText += "   " + monitoredSignals[i].signalId + ": " + monitoredSignals[i].symbol;
                consoleText += " " + monitoredSignals[i].direction + " @ " + DoubleToString(monitoredSignals[i].entryPrice, 5);
                consoleText += " | " + monitoredSignals[i].status;
                consoleText += " | ⏰ " + IntegerToString(minutesLeft) + "m left\n";
            }
        }
        if(monitoredSignalCount > 5)
            consoleText += "   ... and " + IntegerToString(monitoredSignalCount - 5) + " more\n";
    }
    
    // Today's signal stats
    consoleText += "📨 SIGNALS TODAY:\n";
    consoleText += "   Received: " + IntegerToString(signalsReceivedToday) + "\n";
    consoleText += "   Executed: " + IntegerToString(signalsExecutedToday) + "\n";
    consoleText += "   Rejected: " + IntegerToString(signalsRejectedToday) + "\n";
    
    // Footer
    consoleText += "========================================\n";
    consoleText += "🔄 Last Update: " + TimeToString(TimeCurrent(), TIME_SECONDS) + "\n";
    
    // Display on chart
    Comment(consoleText);
}

// License check removed for Master VPS Mode

//+------------------------------------------------------------------+
//| Poll Watchlist for New Signals                                   |
//+------------------------------------------------------------------+
void PollWatchlist()
{
    static datetime lastPollTime = 0;
    
    // Don't poll too frequently
    if(TimeCurrent() - lastPollTime < 5)
        return;
    
    lastPollTime = TimeCurrent();
    
    if(Show_Console_Output) Print("📡 Polling watchlist for new signals...");
    
    string url = API_URL + "/watchlist";
    string url = API_URL + "/watchlist";
    // Modified for Master VPS: No license key header required
    string headers = "Content-Type: application/json\r\n";
    
    char postData[];
    char result[];
    string resultHeaders;
    
    int res = WebRequest("GET", url, headers, 5000, postData, result, resultHeaders);
    
    if(res == 200)
    {
        string json = CharArrayToString(result);
        ProcessWatchlistSignals(json);
    }
    else if(res != -1)
    {
        Print("⚠️ Watchlist poll failed: HTTP ", res);
    }
}

//+------------------------------------------------------------------+
//| Process Watchlist Signals                                         |
//+------------------------------------------------------------------+
void ProcessWatchlistSignals(string json)
{
    // Check if response has signals
    if(StringFind(json, "signalId") == -1)
    {
        if(Show_Console_Output) Print("📭 No new signals in watchlist");
        return;
    }
    
    // Extract signal data
    string signalId = ExtractJsonValue(json, "signalId");
    string symbol = ExtractJsonValue(json, "symbol");
    string direction = ExtractJsonValue(json, "direction");
    string entryStr = ExtractJsonValue(json, "entryPrice");
    string slStr = ExtractJsonValue(json, "stopLoss");
    string tp1Str = ExtractJsonValue(json, "takeProfit1");
    string tp2Str = ExtractJsonValue(json, "takeProfit2");
    string confidenceStr = ExtractJsonValue(json, "confidence");
    
    // Validate required fields
    if(signalId == "" || symbol == "" || entryStr == "" || slStr == "" || tp1Str == "")
    {
        Print("⚠️ Received incomplete signal data");
        return;
    }
    
    // Convert strings to numbers
    double entryPrice = StringToDouble(entryStr);
    double stopLoss = StringToDouble(slStr);
    double takeProfit1 = StringToDouble(tp1Str);
    double takeProfit2 = StringToDouble(tp2Str);
    double confidence = (confidenceStr != "") ? StringToDouble(confidenceStr) : 0;
    
    // Basic price validation
    if(entryPrice <= 0 || stopLoss <= 0 || takeProfit1 <= 0)
    {
        Print("⚠️ Signal ", signalId, " has invalid price levels - Skipping");
        signalsRejectedToday++;
        totalSignalsReceived++;
        return;
    }
    
    // Check if already monitoring this signal
    for(int i = 0; i < monitoredSignalCount; i++)
    {
        if(monitoredSignals[i].signalId == signalId)
        {
            Print("📊 Signal ", signalId, " is already being monitored");
            return;
        }
    }
    
    // Create signal object
    SignalData signal;
    signal.signalId = signalId;
    signal.symbol = symbol;
    signal.direction = direction;
    signal.entryPrice = entryPrice;
    signal.stopLoss = stopLoss;
    signal.takeProfit1 = takeProfit1;
    signal.takeProfit2 = takeProfit2;
    signal.confidence = confidence;
    signal.validated = false;
    signal.monitoring = false;
    signal.monitoringStartTime = 0;
    signal.status = "RECEIVED";
    signal.reason = "";
    
    // Add to monitoring list
    monitoredSignalCount++;
    ArrayResize(monitoredSignals, monitoredSignalCount);
    monitoredSignals[monitoredSignalCount - 1] = signal;
    
    signalsReceivedToday++;
    totalSignalsReceived++;
    
    Print("📥 NEW SIGNAL RECEIVED:");
    Print("   ID: ", signalId);
    Print("   Symbol: ", symbol, " | Direction: ", direction);
    Print("   Entry: ", DoubleToString(entryPrice, 5));
    Print("   SL: ", DoubleToString(stopLoss, 5), " | TP1: ", DoubleToString(takeProfit1, 5));
    Print("   Confidence: ", DoubleToString(confidence, 1), "%");
    
    // Validate signal (but don't execute yet)
    ValidateSignalForMonitoring(signalId);
}

//+------------------------------------------------------------------+
//| Validate Signal for Monitoring                                    |
//+------------------------------------------------------------------+
bool ValidateSignalForMonitoring(string signalId)
{
    // Find the signal
    int signalIndex = -1;
    for(int i = 0; i < monitoredSignalCount; i++)
    {
        if(monitoredSignals[i].signalId == signalId)
        {
            signalIndex = i;
            break;
        }
    }
    
    if(signalIndex == -1)
    {
        Print("⚠️ Signal ", signalId, " not found for validation");
        return false;
    }
    
    // Create a copy of the signal data instead of using reference
    SignalData signalCopy = monitoredSignals[signalIndex];
    
    Print("🔍 Validating signal ", signalId, "...");
    
    // Check confidence level
    if(signalCopy.confidence < 70)
    {
        monitoredSignals[signalIndex].status = "REJECTED";
        monitoredSignals[signalIndex].reason = "Low confidence (" + DoubleToString(signalCopy.confidence, 1) + "%)";
        Print("❌ Signal rejected: ", monitoredSignals[signalIndex].reason);
        signalsRejectedToday++;
        RemoveMonitoredSignal(signalIndex);
        return false;
    }
    
    // Check risk/reward ratio
    double risk = MathAbs(signalCopy.entryPrice - signalCopy.stopLoss);
    double reward = MathAbs(signalCopy.takeProfit1 - signalCopy.entryPrice);
    double rrRatio = reward / risk;
    
    if(rrRatio < 1.2)
    {
        monitoredSignals[signalIndex].status = "REJECTED";
        monitoredSignals[signalIndex].reason = "Poor R/R ratio (" + DoubleToString(rrRatio, 2) + ")";
        Print("❌ Signal rejected: ", monitoredSignals[signalIndex].reason);
        signalsRejectedToday++;
        RemoveMonitoredSignal(signalIndex);
        return false;
    }
    
    // Check if symbol is available
    if(!SymbolSelect(signalCopy.symbol, true))
    {
        monitoredSignals[signalIndex].status = "REJECTED";
        monitoredSignals[signalIndex].reason = "Symbol not available";
        Print("❌ Signal rejected: ", monitoredSignals[signalIndex].reason);
        signalsRejectedToday++;
        RemoveMonitoredSignal(signalIndex);
        return false;
    }
    
    // Start monitoring
    monitoredSignals[signalIndex].validated = true;
    monitoredSignals[signalIndex].monitoring = true;
    monitoredSignals[signalIndex].monitoringStartTime = TimeCurrent();
    monitoredSignals[signalIndex].status = "PENDING";
    monitoredSignals[signalIndex].reason = "Waiting for price to reach entry zone";
    
    Print("✅ Signal ", signalId, " VALIDATED and ADDED to monitoring:");
    Print("   R/R Ratio: ", DoubleToString(rrRatio, 2));
    Print("   Confidence: ", DoubleToString(signalCopy.confidence, 1), "%");
    Print("   Monitoring started - Waiting for entry zone...");
    
    return true;
}

//+------------------------------------------------------------------+
//| Monitor Signals for Entry                                         |
//+------------------------------------------------------------------+
void MonitorSignalsForEntry()
{
    for(int i = 0; i < monitoredSignalCount; i++)
    {
        if(!monitoredSignals[i].monitoring) continue;
        
        // Check if monitoring time expired
        if(TimeCurrent() - monitoredSignals[i].monitoringStartTime > (Max_Monitoring_Time * 60))
        {
            monitoredSignals[i].status = "EXPIRED";
            monitoredSignals[i].reason = "Monitoring time expired";
            Print("⏰ Signal ", monitoredSignals[i].signalId, " expired (24h limit reached)");
            RemoveMonitoredSignal(i);
            i--;
            continue;
        }
        
        // Check current price and entry zone
        double currentPrice = GetCurrentPrice(monitoredSignals[i]);
        double distance = MathAbs(currentPrice - monitoredSignals[i].entryPrice);
        double zoneSize = Entry_Zone_Pips * SymbolInfoDouble(monitoredSignals[i].symbol, SYMBOL_POINT);
        
        // Update status with distance info
        monitoredSignals[i].reason = "Distance: " + DoubleToString(distance/SymbolInfoDouble(monitoredSignals[i].symbol, SYMBOL_POINT), 1) + 
                                   " pips | Zone: ±" + DoubleToString(Entry_Zone_Pips, 1) + " pips";
        
        // Check if price is in entry zone
        if(IsPriceInEntryZone(monitoredSignals[i]))
        {
            Print("🎯 PRICE REACHED ENTRY ZONE for signal ", monitoredSignals[i].signalId, ":");
            Print("   Current Price: ", DoubleToString(currentPrice, 5));
            Print("   Target Entry: ", DoubleToString(monitoredSignals[i].entryPrice, 5));
            Print("   Distance: ", DoubleToString(distance/SymbolInfoDouble(monitoredSignals[i].symbol, SYMBOL_POINT), 1), " pips");
            Print("   Attempting execution...");
            
            // Execute the trade
            if(ExecuteSignal(monitoredSignals[i]))
            {
                monitoredSignals[i].status = "EXECUTED";
                monitoredSignals[i].reason = "Trade executed successfully";
                RemoveMonitoredSignal(i);
                i--;
            }
            else
            {
                monitoredSignals[i].status = "FAILED";
                monitoredSignals[i].reason = "Execution failed";
                Print("❌ Execution failed for signal ", monitoredSignals[i].signalId);
                RemoveMonitoredSignal(i);
                i--;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Get Current Price for Signal                                      |
//+------------------------------------------------------------------+
double GetCurrentPrice(SignalData &signal)
{
    if(!SymbolSelect(signal.symbol, true)) return 0;
    
    if(signal.direction == "BUY")
        return SymbolInfoDouble(signal.symbol, SYMBOL_ASK);
    else if(signal.direction == "SELL")
        return SymbolInfoDouble(signal.symbol, SYMBOL_BID);
    
    return 0;
}

//+------------------------------------------------------------------+
//| Check if Price is in Entry Zone                                   |
//+------------------------------------------------------------------+
bool IsPriceInEntryZone(SignalData &signal)
{
    double currentPrice = GetCurrentPrice(signal);
    if(currentPrice <= 0) return false;
    
    // Calculate entry zone (entry price ± Entry_Zone_Pips)
    double zoneSize = Entry_Zone_Pips * SymbolInfoDouble(signal.symbol, SYMBOL_POINT);
    double zoneUpper = signal.entryPrice + zoneSize;
    double zoneLower = signal.entryPrice - zoneSize;
    
    // For BUY signals: price should be at or below entry zone
    // For SELL signals: price should be at or above entry zone
    if(signal.direction == "BUY")
    {
        return currentPrice <= zoneUpper && currentPrice >= zoneLower;
    }
    else if(signal.direction == "SELL")
    {
        return currentPrice >= zoneLower && currentPrice <= zoneUpper;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Execute Signal Trade                                              |
//+------------------------------------------------------------------+
bool ExecuteSignal(SignalData &signal)
{
    Print("⚡ EXECUTING TRADE for signal ", signal.signalId, "...");
    
    // Select symbol
    string currentSymbol = Symbol();
    if(signal.symbol != currentSymbol)
    {
        if(!SymbolSelect(signal.symbol, true))
        {
            Print("❌ Cannot switch to symbol: ", signal.symbol);
            return false;
        }
    }
    
    // Calculate lot size based on risk
    double lotSize = CalculateLotSize(signal.symbol, signal.entryPrice, signal.stopLoss);
    if(lotSize <= 0)
    {
        Print("❌ Invalid lot size calculation");
        return false;
    }
    
    // Determine order type
    ENUM_ORDER_TYPE orderType;
    if(signal.direction == "BUY")
        orderType = ORDER_TYPE_BUY;
    else if(signal.direction == "SELL")
        orderType = ORDER_TYPE_SELL;
    else
    {
        Print("❌ Invalid direction: ", signal.direction);
        return false;
    }
    
    // Get current price
    double currentPrice = GetCurrentPrice(signal);
    
    // Prepare trade request
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = signal.symbol;
    request.volume = lotSize;
    request.type = orderType;
    request.price = currentPrice;
    request.sl = signal.stopLoss;
    request.tp = signal.takeProfit1;
    request.deviation = 10;
    request.magic = Magic_Number;
    request.comment = "GoldAI Pro: " + signal.signalId;
    
    // Send order
    bool success = OrderSend(request, result);
    
    if(success && result.retcode == TRADE_RETCODE_DONE)
    {
        double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        double riskAmount = accountBalance * (Risk_Percent / 100.0);
        
        Print("✅ TRADE EXECUTED SUCCESSFULLY:");
        Print("   Ticket: #", result.order);
        Print("   Signal: ", signal.signalId);
        Print("   Type: ", signal.direction);
        Print("   Entry: ", DoubleToString(currentPrice, 5));
        Print("   SL: ", DoubleToString(signal.stopLoss, 5));
        Print("   TP1: ", DoubleToString(signal.takeProfit1, 5));
        Print("   Lots: ", DoubleToString(lotSize, 2));
        Print("   Risk: $", DoubleToString(riskAmount, 2));
        
        // Add to active trades
        AddActiveTrade(signal.signalId, result.order, currentPrice, 
                      signal.stopLoss, signal.takeProfit1, signal.takeProfit2);
        
        // Send notification
        if(Enable_Email_Alerts)
        {
            SendNotification("GoldAI Trade Executed", 
                StringFormat("Signal: %s\nDirection: %s\nEntry: %.5f\nSL: %.5f\nTP1: %.5f",
                signal.signalId, signal.direction, currentPrice, 
                signal.stopLoss, signal.takeProfit1));
        }

        // Broadcast to Cloud Copier
        BroadcastTradeEvent(signal.symbol, signal.direction, "ORDER_TYPE_OPEN", currentPrice, signal.stopLoss, signal.takeProfit1, result.order);
        
        signalsExecutedToday++;
        totalTradesExecuted++;
        totalTradesToday++;
        
        return true;
    }
    else
    {
        Print("❌ TRADE EXECUTION FAILED:");
        Print("   Error Code: ", result.retcode);
        Print("   Error: ", GetTradeErrorDescription(result.retcode));
        return false;
    }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size Based on Risk                                  |
//+------------------------------------------------------------------+
double CalculateLotSize(string symbol, double entryPrice, double stopLoss)
{
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * (Risk_Percent / 100.0);
    
    // Calculate risk in points
    double pointValue = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double stopDistance = MathAbs(entryPrice - stopLoss);
    double stopPoints = stopDistance / pointValue;
    
    // Calculate tick value
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    // Calculate lot size
    double lotSize = riskAmount / (stopPoints * pointValue * tickValue);
    
    // Normalize to symbol requirements
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    
    lotSize = MathRound(lotSize / lotStep) * lotStep;
    lotSize = MathMax(lotSize, minLot);
    lotSize = MathMin(lotSize, maxLot);
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| Add Active Trade                                                  |
//+------------------------------------------------------------------+
void AddActiveTrade(string signalId, ulong ticket, double entryPrice, 
                    double stopLoss, double tp1, double tp2)
{
    ActiveTrade trade;
    trade.signalId = signalId;
    trade.ticket = ticket;
    trade.entryPrice = entryPrice;
    trade.stopLoss = stopLoss;
    trade.tp1Price = tp1;
    trade.tp2Price = tp2;
    trade.tp1Hit = false;
    trade.movedToBreakeven = false;
    trade.openTime = TimeCurrent();
    trade.currentProfit = 0;
    trade.currentProfitPips = 0;
    
    activeTradeCount++;
    ArrayResize(activeTrades, activeTradeCount);
    activeTrades[activeTradeCount - 1] = trade;
    
    Print("📊 Active trade added - Total active: ", activeTradeCount);
}

//+------------------------------------------------------------------+
//| Update Active Trades Profit                                       |
//+------------------------------------------------------------------+
void UpdateActiveTradesProfit()
{
    for(int i = 0; i < activeTradeCount; i++)
    {
        if(PositionSelectByTicket(activeTrades[i].ticket))
        {
            activeTrades[i].currentProfit = PositionGetDouble(POSITION_PROFIT);
            
            // Calculate profit in pips
            long type = PositionGetInteger(POSITION_TYPE);
            double currentPrice = (type == POSITION_TYPE_BUY) ? 
                                 SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                                 SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            
            if(type == POSITION_TYPE_BUY)
                activeTrades[i].currentProfitPips = (currentPrice - activeTrades[i].entryPrice) / point;
            else
                activeTrades[i].currentProfitPips = (activeTrades[i].entryPrice - currentPrice) / point;
        }
    }
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
            Print("📊 Trade closed: ", activeTrades[i].signalId);
            
            // Broadcast closure to Cloud Copier
            BroadcastTradeEvent(Symbol(), "CLOSE", "ORDER_TYPE_CLOSE", 0, 0, 0, activeTrades[i].ticket);
            
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
    
    bool tp1Reached = false;
    
    if(type == POSITION_TYPE_BUY)
        tp1Reached = currentPrice >= trade.tp1Price;
    else
        tp1Reached = currentPrice <= trade.tp1Price;
    
    if(tp1Reached && !trade.tp1Hit)
    {
        Print("🎯 TP1 REACHED for trade ", trade.signalId);
        trade.tp1Hit = true;
    }
    
    return tp1Reached;
}

//+------------------------------------------------------------------+
//| Move Stop Loss to Breakeven                                       |
//+------------------------------------------------------------------+
void MoveToBreakeven(ActiveTrade &trade)
{
    if(!PositionSelectByTicket(trade.ticket)) return;
    
    long type = PositionGetInteger(POSITION_TYPE);
    double newSL = trade.entryPrice;
    
    // Add buffer
    if(type == POSITION_TYPE_BUY)
        newSL += Breakeven_Pips * _Point;
    else
        newSL -= Breakeven_Pips * _Point;
    
    // Modify position
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_SLTP;
    request.position = trade.ticket;
    request.symbol = PositionGetString(POSITION_SYMBOL);
    request.sl = newSL;
    request.tp = trade.tp2Price;
    
    if(OrderSend(request, result))
    {
        Print("🛡️ BREAKEVEN ACTIVATED for trade ", trade.signalId);
        Print("   New SL: ", DoubleToString(newSL, 5));
        Print("   New TP: ", DoubleToString(trade.tp2Price, 5));
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
            break;
        }
    }
    
    // Update stats
    if(profit > 0)
    {
        dailyProfit += profit;
        totalTradesWon++;
    }
    else
    {
        dailyLoss += MathAbs(profit);
        totalTradesLost++;
    }
    
    Print("💰 TRADE CLOSED - P/L: $", DoubleToString(profit, 2));
    
    // Check daily limits
    CheckDailyLimits();
}

//+------------------------------------------------------------------+
//| Remove Monitored Signal                                           |
//+------------------------------------------------------------------+
void RemoveMonitoredSignal(int index)
{
    if(index < 0 || index >= monitoredSignalCount) return;
    
    for(int i = index; i < monitoredSignalCount - 1; i++)
    {
        monitoredSignals[i] = monitoredSignals[i + 1];
    }
    monitoredSignalCount--;
    ArrayResize(monitoredSignals, monitoredSignalCount);
}

//+------------------------------------------------------------------+
//| Remove Active Trade by Index                                      |
//+------------------------------------------------------------------+
void RemoveActiveTradeByIndex(int index)
{
    if(index < 0 || index >= activeTradeCount) return;
    
    for(int i = index; i < activeTradeCount - 1; i++)
    {
        activeTrades[i] = activeTrades[i + 1];
    }
    activeTradeCount--;
    ArrayResize(activeTrades, activeTradeCount);
}

//+------------------------------------------------------------------+
//| Check Daily Limits                                               |
//+------------------------------------------------------------------+
void CheckDailyLimits()
{
    if(!Enable_Daily_Limits) return;
    
    double profitTarget = dailyStartBalance * (Daily_Profit_Target_Percent / 100);
    double maxLoss = dailyStartBalance * (Daily_Max_Loss_Percent / 100);
    
    if(dailyProfit >= profitTarget)
    {
        Print("🎯 DAILY PROFIT TARGET HIT!");
        dailyLimitHit = true;
    }
    else if(dailyLoss >= maxLoss)
    {
        Print("🛑 DAILY MAX LOSS HIT!");
        dailyLimitHit = true;
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
    totalTradesToday = 0;
    signalsReceivedToday = 0;
    signalsExecutedToday = 0;
    signalsRejectedToday = 0;
    lastDailyReset = TimeCurrent();
    
    Print("📊 Daily stats initialized:");
    Print("   Start Balance: $", DoubleToString(dailyStartBalance, 2));
    Print("   Profit Target: $", DoubleToString(dailyStartBalance * (Daily_Profit_Target_Percent / 100), 2));
    Print("   Max Loss: $", DoubleToString(dailyStartBalance * (Daily_Max_Loss_Percent / 100), 2));
}

//+------------------------------------------------------------------+
//| Check if Should Reset Daily Stats                                |
//+------------------------------------------------------------------+
bool ShouldResetDaily()
{
    MqlDateTime now, last;
    TimeToStruct(TimeCurrent(), now);
    TimeToStruct(lastDailyReset, last);
    
    return (now.day != last.day || now.mon != last.mon || now.year != last.year);
}

//+------------------------------------------------------------------+
//| Reset Daily Stats                                                 |
//+------------------------------------------------------------------+
void ResetDailyStats()
{
    Print("🔄 Resetting daily stats (new trading day)");
    
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double dailyPL = currentBalance - dailyStartBalance;
    
    Print("   Previous Balance: $", DoubleToString(dailyStartBalance, 2));
    Print("   Current Balance: $", DoubleToString(currentBalance, 2));
    Print("   Daily P/L: $", DoubleToString(dailyPL, 2));
    Print("   Trades Yesterday: ", totalTradesToday);
    
    InitializeDailyStats();
}

//+------------------------------------------------------------------+
//| Extract JSON Value                                                |
//+------------------------------------------------------------------+
string ExtractJsonValue(string json, string key)
{
    string search = "\"" + key + "\":";
    int start = StringFind(json, search);
    if(start < 0) return "";
    
    start += StringLen(search);
    
    // Skip whitespace
    while(start < StringLen(json) && (json[start] == ' ' || json[start] == '\t' || json[start] == '\n'))
        start++;
    
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
        if(end < 0) end = StringFind(json, "]", start);
    }
    
    if(end < 0) end = StringLen(json);
    
    return StringSubstr(json, start, end - start);
}

//+------------------------------------------------------------------+
//| Send Notification                                                 |
//+------------------------------------------------------------------+
void SendNotification(string subject, string message)
{
    if(Enable_Email_Alerts)
    {
        SendMail(subject, message);
    }
    
    if(Enable_Push_Notifications)
    {
        SendNotification(subject + ": " + message);
    }
}

//+------------------------------------------------------------------+
//| Get Trade Error Description                                       |
//+------------------------------------------------------------------+
string GetTradeErrorDescription(int errorCode)
{
    switch(errorCode)
    {
        case 10004: return "Requote";
        case 10006: return "Request rejected";
        case 10007: return "Request canceled by trader";
        case 10008: return "Order placed too late";
        case 10009: return "Invalid price";
        case 10010: return "Invalid SL/TP";
        case 10011: return "Invalid volume";
        case 10012: return "Market closed";
        case 10013: return "Trade disabled";
        case 10014: return "Not enough money";
        case 10015: return "Price changed";
        case 10016: return "Off quotes";
        case 10017: return "Broker busy";
        case 10018: return "Requote expired";
        case 10019: return "Order locked";
        case 10020: return "Long positions only allowed";
        case 10021: return "Too many requests";
        default: return "Unknown error (' IntegerToString(errorCode)' )";
    }
}

//+------------------------------------------------------------------+
//| Trade function - Handles manual trading                           |
//+------------------------------------------------------------------+
void OnTrade()
{
    Print("⚡ Trade event detected - updating console...");
    if(Show_Console_Output)
        UpdateConsole();
}

//+------------------------------------------------------------------+
//| Chart event function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    // Refresh console on chart events
    if(Show_Console_Output && (id == CHARTEVENT_CLICK || id == CHARTEVENT_CHART_CHANGE))
    {
        UpdateConsole();
    }
}

//+------------------------------------------------------------------+
//| Broadcast Trade Event to Cloud Copier Bridge                      |
//+------------------------------------------------------------------+
void BroadcastTradeEvent(string symbol, string direction, string operation, double price, double sl, double tp, ulong ticket)
{
    string url = API_URL + "/copier/master/trade";
    string headers = "Content-Type: application/json\r\n";
    
    // Format JSON body
    string body = StringFormat(
        "{\"symbol\":\"%s\",\"type\":\"%s\",\"operation\":\"%s\",\"price\":%.5f,\"sl\":%.5f,\"tp\":%.5f,\"ticket\":%llu}",
        symbol, direction, operation, price, sl, tp, ticket
    );
    
    char postData[];
    StringToCharArray(body, postData);
    
    char result[];
    string resultHeaders;
    
    ResetLastError();
    int res = WebRequest("POST", url, headers, 1000, postData, result, resultHeaders);
    int error = GetLastError();
    
    if(res == 200)
    {
        if(Show_Console_Output) Print("📡 Cloud Copier: Event broadcasted successfully (#", ticket, ")");
    }
    else
    {
        Print("⚠️ Cloud Copier: Broadcast failed (HTTP ", res, " | Error: ", error, ")");
    }
}

//+------------------------------------------------------------------+