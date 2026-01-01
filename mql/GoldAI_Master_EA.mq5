//+------------------------------------------------------------------+
//|                                         GoldAI_Master_EA.mq5    |
//|                          Copyright 2024, GoldAI Mentor Pro      |
//|                          Master VPS Trading System              |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, GoldAI Mentor Pro"
#property link      "https://goldai.pro"
#property version   "3.00"
#property strict
#property description "Master EA with 3-Tier TP, Breakeven, Trailing Stop & Recovery Protocol"

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input string   API_URL = "https://goldai-bridge-is7d.onrender.com/api/v1";  // Bridge API URL
input string   BRIDGE_TOKEN = "MASTER_VPS_TOKEN";                      // Master VPS Token

// Risk Management
input double   Risk_Percent = 5.0;                         // Risk per trade (%)
input double   Min_Risk_Percent = 3.0;                     // Minimum risk after losses
input double   Max_Risk_Percent = 8.0;                     // Maximum risk allowed (%)
input int      Magic_Number = 999888;                      // Magic number

// Take Profit Configuration
input double   TP1_RR_Ratio = 1.0;                         // TP1 Risk/Reward (1:1)
input double   TP2_RR_Ratio = 1.5;                         // TP2 Risk/Reward (1:1.5)
input double   TP3_RR_Ratio = 2.0;                         // TP3 Risk/Reward (1:2)
input double   TP1_Close_Percent = 33.0;                   // Close 33% at TP1
input double   TP2_Close_Percent = 33.0;                   // Close 33% at TP2

// Breakeven & Trailing
input bool     Enable_Breakeven = true;                    // Move SL to breakeven at TP1
input int      Breakeven_Buffer_Pips = 5;                  // Pips above breakeven
input bool     Enable_Trailing_Stop = true;                // Enable trailing stop after TP2
input int      Trailing_Stop_Distance = 10;                // Trailing stop distance (pips)

// Recovery Protocol
input bool     Enable_Recovery_Protocol = true;            // Enable loss recovery system
input int      Pause_After_Losses = 2;                     // Pause after X consecutive losses
input int      Pause_Duration_Hours = 6;                   // Pause duration (hours)
input int      Full_Stop_After_Losses = 3;                 // Full stop after X losses
input int      Full_Stop_Duration_Hours = 24;              // Full stop duration (hours)

// Signal Polling
input int      Poll_Interval_Seconds = 3600;               // Poll every hour (3600s)
input int      Poll_Offset_Seconds = 120;                  // Poll at :02 past the hour

// Display
input bool     Show_Console_Output = true;                 // Show detailed console
input bool     Show_Dashboard = true;                      // Show on-chart dashboard

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
    double takeProfit3;
    double confidence;
    string grade;           // "A+", "A", "B+"
    datetime receivedAt;
};

struct TradePosition
{
    ulong ticket;
    string signalId;
    double entryPrice;
    double stopLoss;
    double originalSL;
    double tp1Price;
    double tp2Price;
    double tp3Price;
    double originalLotSize;
    double remainingLots;
    bool tp1Hit;
    bool tp2Hit;
    bool movedToBreakeven;
    bool trailingActive;
    datetime openTime;
};

struct RecoveryState
{
    int consecutiveLosses;
    int consecutiveWins;
    datetime lastLossTime;
    datetime pauseUntil;
    bool isPaused;
    bool isFullStop;
    double currentRiskPercent;
};

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
datetime lastPollTime = 0;
datetime lastConsoleUpdate = 0;
SignalData currentSignal;
TradePosition activePosition;
RecoveryState recovery;
bool hasActivePosition = false;

// Statistics
int totalTrades = 0;
int winningTrades = 0;
int losingTrades = 0;
double totalProfit = 0;
double totalLoss = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("========================================");
    Print("🤖 GoldAI Master EA v3.0");
    Print("========================================");
    Print("API URL: ", API_URL);
    Print("Risk: ", Risk_Percent, "%");
    Print("TP Ratios: 1:", TP1_RR_Ratio, " | 1:", TP2_RR_Ratio, " | 1:", TP3_RR_Ratio);
    Print("========================================");
    
    // Initialize recovery state
    recovery.consecutiveLosses = 0;
    recovery.consecutiveWins = 0;
    recovery.isPaused = false;
    recovery.isFullStop = false;
    recovery.currentRiskPercent = Risk_Percent;
    
    // Initialize position
    hasActivePosition = false;
    
    // Set timer for 1-second updates
    EventSetTimer(1);
    
    Print("🚀 Master EA Initialized Successfully");
    Print("⏰ Will poll for signals every hour at :02");
    Print("========================================");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();
    
    Print("========================================");
    Print("📊 FINAL STATISTICS");
    Print("   Total Trades: ", totalTrades);
    Print("   Winning Trades: ", winningTrades);
    Print("   Losing Trades: ", losingTrades);
    if(totalTrades > 0)
        Print("   Win Rate: ", DoubleToString((double)winningTrades/totalTrades*100, 1), "%");
    Print("   Total Profit: $", DoubleToString(totalProfit, 2));
    Print("   Total Loss: $", DoubleToString(totalLoss, 2));
    Print("   Net P/L: $", DoubleToString(totalProfit - totalLoss, 2));
    Print("========================================");
    Print("🛑 GoldAI Master EA Stopped");
}

//+------------------------------------------------------------------+
//| Timer function - Runs every second                               |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Update console periodically
    if(Show_Console_Output && TimeCurrent() - lastConsoleUpdate >= 5)
    {
        UpdateConsole();
        lastConsoleUpdate = TimeCurrent();
    }
    
    // Check recovery state
    if(Enable_Recovery_Protocol)
    {
        UpdateRecoveryState();
        if(recovery.isPaused || recovery.isFullStop)
            return; // Don't poll or trade during pause
    }
    
    // Poll for signals at the right time
    if(ShouldPollNow())
    {
        PollForSignal();
        lastPollTime = TimeCurrent();
    }
    
    // Manage active position
    if(hasActivePosition)
    {
        ManageActivePosition();
    }
}

//+------------------------------------------------------------------+
//| Check if it's time to poll                                       |
//+------------------------------------------------------------------+
bool ShouldPollNow()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    // Poll at :02 past every hour
    if(dt.min == 2 && dt.sec < 10)
    {
        // Make sure we haven't polled in the last 5 minutes
        if(TimeCurrent() - lastPollTime > 300)
            return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Poll Bridge API for new signal                                   |
//+------------------------------------------------------------------+
void PollForSignal()
{
    if(hasActivePosition)
    {
        Print("⚠️ Already have active position. Skipping poll.");
        return;
    }
    
    Print("📡 Polling Bridge API for new signal...");
    
    string url = API_URL + "/watchlist";
    string headers = "Content-Type: application/json\r\n";
    headers += "x-bridge-token: " + BRIDGE_TOKEN + "\r\n";
    
    char postData[];
    char result[];
    string resultHeaders;
    
    int res = WebRequest("GET", url, headers, 5000, postData, result, resultHeaders);
    
    if(res == 200)
    {
        string json = CharArrayToString(result);
        ProcessSignalResponse(json);
    }
    else if(res != -1)
    {
        Print("⚠️ Poll failed: HTTP ", res);
    }
}

//+------------------------------------------------------------------+
//| Process signal response from API                                 |
//+------------------------------------------------------------------+
void ProcessSignalResponse(string json)
{
    // Check if there's a signal
    if(StringFind(json, "\"signalId\"") == -1)
    {
        Print("📭 No new signals available");
        return;
    }
    
    // Extract signal data
    currentSignal.signalId = ExtractJsonValue(json, "signalId");
    currentSignal.symbol = ExtractJsonValue(json, "symbol");
    currentSignal.direction = ExtractJsonValue(json, "type");
    currentSignal.entryPrice = StringToDouble(ExtractJsonValue(json, "entry"));
    currentSignal.stopLoss = StringToDouble(ExtractJsonValue(json, "sl"));
    currentSignal.takeProfit1 = StringToDouble(ExtractJsonValue(json, "tp"));
    currentSignal.confidence = StringToDouble(ExtractJsonValue(json, "confidence"));
    currentSignal.grade = ExtractJsonValue(json, "grade");
    currentSignal.receivedAt = TimeCurrent();
    
    // Calculate TP2 and TP3 based on RR ratios
    double slDistance = MathAbs(currentSignal.entryPrice - currentSignal.stopLoss);
    if(currentSignal.direction == "BUY")
    {
        currentSignal.takeProfit2 = currentSignal.entryPrice + (slDistance * TP2_RR_Ratio);
        currentSignal.takeProfit3 = currentSignal.entryPrice + (slDistance * TP3_RR_Ratio);
    }
    else
    {
        currentSignal.takeProfit2 = currentSignal.entryPrice - (slDistance * TP2_RR_Ratio);
        currentSignal.takeProfit3 = currentSignal.entryPrice - (slDistance * TP3_RR_Ratio);
    }
    
    Print("📥 NEW SIGNAL RECEIVED:");
    Print("   ID: ", currentSignal.signalId);
    Print("   ", currentSignal.direction, " ", currentSignal.symbol);
    Print("   Entry: ", DoubleToString(currentSignal.entryPrice, 2));
    Print("   SL: ", DoubleToString(currentSignal.stopLoss, 2));
    Print("   TP1: ", DoubleToString(currentSignal.takeProfit1, 2), " (1:", TP1_RR_Ratio, ")");
    Print("   TP2: ", DoubleToString(currentSignal.takeProfit2, 2), " (1:", TP2_RR_Ratio, ")");
    Print("   TP3: ", DoubleToString(currentSignal.takeProfit3, 2), " (1:", TP3_RR_Ratio, ")");
    Print("   Confidence: ", DoubleToString(currentSignal.confidence, 1), "%");
    Print("   Grade: ", currentSignal.grade);
    
    // Validate and execute
    if(ValidateSignal())
    {
        ExecuteSignal();
    }
}

//+------------------------------------------------------------------+
//| Validate signal before execution                                 |
//+------------------------------------------------------------------+
bool ValidateSignal()
{
    // Check if during recovery pause, only accept A+ signals
    if(recovery.isPaused && currentSignal.grade != "A+")
    {
        Print("❌ Signal rejected: Only A+ signals accepted during recovery pause");
        return false;
    }
    
    // Check confidence
    if(currentSignal.confidence < 70)
    {
        Print("❌ Signal rejected: Low confidence (", currentSignal.confidence, "%)");
        return false;
    }
    
    // Check prices are valid
    if(currentSignal.entryPrice <= 0 || currentSignal.stopLoss <= 0 || currentSignal.takeProfit1 <= 0)
    {
        Print("❌ Signal rejected: Invalid price levels");
        return false;
    }
    
    // Check symbol is available
    if(!SymbolSelect(currentSignal.symbol, true))
    {
        Print("❌ Signal rejected: Symbol not available");
        return false;
    }
    
    Print("✅ Signal validated successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Execute the signal                                                |
//+------------------------------------------------------------------+
void ExecuteSignal()
{
    Print("⚡ EXECUTING TRADE...");
    
    // Calculate lot size
    double lotSize = CalculateLotSize();
    if(lotSize <= 0)
    {
        Print("❌ Execution failed: Invalid lot size");
        return;
    }
    
    // Determine order type
    ENUM_ORDER_TYPE orderType;
    double price;
    if(currentSignal.direction == "BUY")
    {
        orderType = ORDER_TYPE_BUY;
        price = SymbolInfoDouble(currentSignal.symbol, SYMBOL_ASK);
    }
    else
    {
        orderType = ORDER_TYPE_SELL;
        price = SymbolInfoDouble(currentSignal.symbol, SYMBOL_BID);
    }
    
    // Prepare trade request
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = currentSignal.symbol;
    request.volume = lotSize;
    request.type = orderType;
    request.price = price;
    request.sl = currentSignal.stopLoss;
    request.tp = currentSignal.takeProfit1; // Set initial TP to TP1
    request.deviation = 10;
    request.magic = Magic_Number;
    request.comment = "GoldAI Master: " + currentSignal.signalId;
    
    // Send order
    bool success = OrderSend(request, result);
    
    if(success && result.retcode == TRADE_RETCODE_DONE)
    {
        Print("✅ TRADE EXECUTED SUCCESSFULLY:");
        Print("   Ticket: #", result.order);
        Print("   Lots: ", DoubleToString(lotSize, 2));
        Print("   Entry: ", DoubleToString(price, 2));
        Print("   Risk: $", DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE) * recovery.currentRiskPercent / 100, 2));
        
        // Store position data
        activePosition.ticket = result.order;
        activePosition.signalId = currentSignal.signalId;
        activePosition.entryPrice = price;
        activePosition.stopLoss = currentSignal.stopLoss;
        activePosition.originalSL = currentSignal.stopLoss;
        activePosition.tp1Price = currentSignal.takeProfit1;
        activePosition.tp2Price = currentSignal.takeProfit2;
        activePosition.tp3Price = currentSignal.takeProfit3;
        activePosition.originalLotSize = lotSize;
        activePosition.remainingLots = lotSize;
        activePosition.tp1Hit = false;
        activePosition.tp2Hit = false;
        activePosition.movedToBreakeven = false;
        activePosition.trailingActive = false;
        activePosition.openTime = TimeCurrent();
        
        hasActivePosition = true;
        totalTrades++;
        
        // Broadcast trade event to copier
        BroadcastTradeEvent("OPEN", price, lotSize);
    }
    else
    {
        Print("❌ TRADE EXECUTION FAILED:");
        Print("   Error Code: ", result.retcode);
        Print("   Error: ", GetTradeErrorDescription(result.retcode));
    }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                                 |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = balance * (recovery.currentRiskPercent / 100.0);
    
    // Calculate SL distance in price
    double slDistance = MathAbs(currentSignal.entryPrice - currentSignal.stopLoss);
    
    // For XAUUSD: 1 pip = 0.01, and 1 lot = $1 per pip
    // Risk = SL_Distance * Lot_Size * Pip_Value
    // Lot_Size = Risk / (SL_Distance * Pip_Value)
    double pipValue = 1.0; // $1 per pip for 0.01 lot on XAUUSD
    double lotSize = riskAmount / (slDistance * pipValue * 100); // *100 because slDistance is in price, not pips
    
    // Normalize
    double minLot = SymbolInfoDouble(currentSignal.symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(currentSignal.symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(currentSignal.symbol, SYMBOL_VOLUME_STEP);
    
    lotSize = MathRound(lotSize / lotStep) * lotStep;
    lotSize = MathMax(lotSize, minLot);
    lotSize = MathMin(lotSize, maxLot);
    
    Print("💰 Position Sizing:");
    Print("   Balance: $", DoubleToString(balance, 2));
    Print("   Risk: ", DoubleToString(recovery.currentRiskPercent, 1), "% = $", DoubleToString(riskAmount, 2));
    Print("   SL Distance: ", DoubleToString(slDistance, 2));
    Print("   Calculated Lots: ", DoubleToString(lotSize, 2));
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| Manage active position                                            |
//+------------------------------------------------------------------+
void ManageActivePosition()
{
    if(!PositionSelectByTicket(activePosition.ticket))
    {
        // Position closed
        OnPositionClosed();
        return;
    }
    
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double currentProfit = PositionGetDouble(POSITION_PROFIT);
    
    // Check TP1 hit
    if(!activePosition.tp1Hit)
    {
        if(IsPriceAtLevel(currentPrice, activePosition.tp1Price, currentSignal.direction))
        {
            OnTP1Hit();
        }
    }
    // Check TP2 hit
    else if(!activePosition.tp2Hit)
    {
        if(IsPriceAtLevel(currentPrice, activePosition.tp2Price, currentSignal.direction))
        {
            OnTP2Hit();
        }
    }
    // Manage trailing stop
    else if(activePosition.trailingActive && Enable_Trailing_Stop)
    {
        UpdateTrailingStop(currentPrice);
    }
}

//+------------------------------------------------------------------+
//| Check if price reached a level                                   |
//+------------------------------------------------------------------+
bool IsPriceAtLevel(double currentPrice, double targetPrice, string direction)
{
    if(direction == "BUY")
        return currentPrice >= targetPrice;
    else
        return currentPrice <= targetPrice;
}

//+------------------------------------------------------------------+
//| Handle TP1 hit                                                    |
//+------------------------------------------------------------------+
void OnTP1Hit()
{
    Print("🎯 TP1 HIT! Closing ", DoubleToString(TP1_Close_Percent, 0), "% of position...");
    
    double closeVolume = activePosition.originalLotSize * (TP1_Close_Percent / 100.0);
    closeVolume = NormalizeLots(closeVolume);
    
    if(ClosePartialPosition(closeVolume))
    {
        activePosition.tp1Hit = true;
        activePosition.remainingLots -= closeVolume;
        
        // Move SL to breakeven
        if(Enable_Breakeven)
        {
            MoveToBreakeven();
        }
        
        // Broadcast partial close
        BroadcastTradeEvent("PARTIAL_CLOSE_TP1", activePosition.tp1Price, closeVolume);
    }
}

//+------------------------------------------------------------------+
//| Handle TP2 hit                                                    |
//+------------------------------------------------------------------+
void OnTP2Hit()
{
    Print("🎯 TP2 HIT! Closing another ", DoubleToString(TP2_Close_Percent, 0), "% of position...");
    
    double closeVolume = activePosition.originalLotSize * (TP2_Close_Percent / 100.0);
    closeVolume = NormalizeLots(closeVolume);
    
    if(ClosePartialPosition(closeVolume))
    {
        activePosition.tp2Hit = true;
        activePosition.remainingLots -= closeVolume;
        activePosition.trailingActive = true;
        
        Print("🔄 Trailing stop activated!");
        
        // Broadcast partial close
        BroadcastTradeEvent("PARTIAL_CLOSE_TP2", activePosition.tp2Price, closeVolume);
    }
}

//+------------------------------------------------------------------+
//| Close partial position                                            |
//+------------------------------------------------------------------+
bool ClosePartialPosition(double volume)
{
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_DEAL;
    request.position = activePosition.ticket;
    request.symbol = currentSignal.symbol;
    request.volume = volume;
    request.type = currentSignal.direction == "BUY" ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.price = currentSignal.direction == "BUY" ? 
                    SymbolInfoDouble(currentSignal.symbol, SYMBOL_BID) :
                    SymbolInfoDouble(currentSignal.symbol, SYMBOL_ASK);
    request.deviation = 10;
    request.magic = Magic_Number;
    
    bool success = OrderSend(request, result);
    
    if(success && result.retcode == TRADE_RETCODE_DONE)
    {
        Print("   ✅ Partial close successful: ", DoubleToString(volume, 2), " lots");
        return true;
    }
    else
    {
        Print("   ❌ Partial close failed: ", result.retcode);
        return false;
    }
}

//+------------------------------------------------------------------+
//| Move SL to breakeven                                              |
//+------------------------------------------------------------------+
void MoveToBreakeven()
{
    double newSL = activePosition.entryPrice;
    
    // Add buffer
    double point = SymbolInfoDouble(currentSignal.symbol, SYMBOL_POINT);
    if(currentSignal.direction == "BUY")
        newSL += Breakeven_Buffer_Pips * point * 10;
    else
        newSL -= Breakeven_Buffer_Pips * point * 10;
    
    if(ModifyPositionSL(newSL))
    {
        activePosition.movedToBreakeven = true;
        activePosition.stopLoss = newSL;
        Print("🛡️ BREAKEVEN ACTIVATED! SL moved to ", DoubleToString(newSL, 2));
    }
}

//+------------------------------------------------------------------+
//| Update trailing stop                                              |
//+------------------------------------------------------------------+
void UpdateTrailingStop(double currentPrice)
{
    double point = SymbolInfoDouble(currentSignal.symbol, SYMBOL_POINT);
    double trailDistance = Trailing_Stop_Distance * point * 10;
    double newSL;
    
    if(currentSignal.direction == "BUY")
    {
        newSL = currentPrice - trailDistance;
        if(newSL > activePosition.stopLoss)
        {
            ModifyPositionSL(newSL);
            activePosition.stopLoss = newSL;
        }
    }
    else
    {
        newSL = currentPrice + trailDistance;
        if(newSL < activePosition.stopLoss)
        {
            ModifyPositionSL(newSL);
            activePosition.stopLoss = newSL;
        }
    }
}

//+------------------------------------------------------------------+
//| Modify position SL                                                |
//+------------------------------------------------------------------+
bool ModifyPositionSL(double newSL)
{
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_SLTP;
    request.position = activePosition.ticket;
    request.symbol = currentSignal.symbol;
    request.sl = newSL;
    request.tp = PositionGetDouble(POSITION_TP);
    
    return OrderSend(request, result);
}

//+------------------------------------------------------------------+
//| Handle position closed                                            |
//+------------------------------------------------------------------+
void OnPositionClosed()
{
    // Get final profit from history
    if(HistorySelectByPosition(activePosition.ticket))
    {
        ulong ticket = 0;
        for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
        {
            ticket = HistoryDealGetTicket(i);
            if(HistoryDealGetInteger(ticket, DEAL_POSITION_ID) == activePosition.ticket)
                break;
        }
        
        double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
        
        Print("🏁 POSITION CLOSED");
        Print("   Final P/L: $", DoubleToString(profit, 2));
        
        // Update statistics
        if(profit > 0)
        {
            winningTrades++;
            totalProfit += profit;
            recovery.consecutiveWins++;
            recovery.consecutiveLosses = 0;
            
            // Reset risk to normal after win
            recovery.currentRiskPercent = Risk_Percent;
        }
        else
        {
            losingTrades++;
            totalLoss += MathAbs(profit);
            recovery.consecutiveLosses++;
            recovery.consecutiveWins = 0;
            recovery.lastLossTime = TimeCurrent();
            
            // Trigger recovery protocol
            if(Enable_Recovery_Protocol)
            {
                TriggerRecoveryProtocol();
            }
        }
        
        // Broadcast close
        BroadcastTradeEvent("CLOSE", PositionGetDouble(POSITION_PRICE_CURRENT), activePosition.remainingLots);
    }
    
    hasActivePosition = false;
}

//+------------------------------------------------------------------+
//| Trigger recovery protocol                                         |
//+------------------------------------------------------------------+
void TriggerRecoveryProtocol()
{
    if(recovery.consecutiveLosses >= Full_Stop_After_Losses)
    {
        // Full stop
        recovery.isFullStop = true;
        recovery.pauseUntil = TimeCurrent() + (Full_Stop_Duration_Hours * 3600);
        recovery.currentRiskPercent = Min_Risk_Percent;
        
        Print("🛑 FULL STOP ACTIVATED!");
        Print("   Consecutive Losses: ", recovery.consecutiveLosses);
        Print("   Trading halted for ", Full_Stop_Duration_Hours, " hours");
        Print("   Risk reduced to ", DoubleToString(Min_Risk_Percent, 1), "%");
    }
    else if(recovery.consecutiveLosses >= Pause_After_Losses)
    {
        // Pause
        recovery.isPaused = true;
        recovery.pauseUntil = TimeCurrent() + (Pause_Duration_Hours * 3600);
        
        Print("⏸️ RECOVERY PAUSE ACTIVATED!");
        Print("   Consecutive Losses: ", recovery.consecutiveLosses);
        Print("   Paused for ", Pause_Duration_Hours, " hours");
        Print("   Will only accept A+ signals");
    }
}

//+------------------------------------------------------------------+
//| Update recovery state                                             |
//+------------------------------------------------------------------+
void UpdateRecoveryState()
{
    if(recovery.isPaused || recovery.isFullStop)
    {
        if(TimeCurrent() >= recovery.pauseUntil)
        {
            recovery.isPaused = false;
            recovery.isFullStop = false;
            Print("✅ Recovery period ended. Resuming normal trading.");
        }
    }
}

//+------------------------------------------------------------------+
//| Broadcast trade event to copier                                  |
//+------------------------------------------------------------------+
void BroadcastTradeEvent(string operation, double price, double lots)
{
    string url = API_URL + "/copier/master/trade";
    
    string json = "{";
    json += "\"symbol\":\"" + currentSignal.symbol + "\",";
    json += "\"type\":\"" + currentSignal.direction + "\",";
    json += "\"operation\":\"" + operation + "\",";
    json += "\"price\":" + DoubleToString(price, 5) + ",";
    json += "\"sl\":" + DoubleToString(activePosition.stopLoss, 5) + ",";
    json += "\"tp\":" + DoubleToString(activePosition.tp1Price, 5) + ",";
    json += "\"ticket\":" + IntegerToString(activePosition.ticket) + ",";
    json += "\"lotSize\":" + DoubleToString(lots, 2);
    json += "}";
    
    char postData[];
    StringToCharArray(json, postData, 0, StringLen(json));
    
    char result[];
    string resultHeaders;
    string headers = "Content-Type: application/json\r\n";
    
    int res = WebRequest("POST", url, headers, 5000, postData, result, resultHeaders);
    
    if(res == 200)
    {
        Print("📡 Trade event broadcasted to copier: ", operation);
    }
    else
    {
        Print("⚠️ Failed to broadcast trade event: HTTP ", res);
    }
}

//+------------------------------------------------------------------+
//| Update console display                                            |
//+------------------------------------------------------------------+
void UpdateConsole()
{
    if(!Show_Console_Output) return;
    
    string console = "";
    console += "========================================\n";
    console += "🤖 GOLDAI MASTER EA - LIVE STATUS\n";
    console += "========================================\n";
    
    // Account info
    console += "💰 ACCOUNT:\n";
    console += "   Balance: $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\n";
    console += "   Equity: $" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "\n";
    console += "   Risk: " + DoubleToString(recovery.currentRiskPercent, 1) + "%\n";
    
    // Recovery status
    if(recovery.isPaused)
    {
        int remaining = (int)((recovery.pauseUntil - TimeCurrent()) / 60);
        console += "⏸️ PAUSED: " + IntegerToString(remaining) + " min remaining\n";
    }
    else if(recovery.isFullStop)
    {
        int remaining = (int)((recovery.pauseUntil - TimeCurrent()) / 3600);
        console += "🛑 FULL STOP: " + IntegerToString(remaining) + " hours remaining\n";
    }
    else
    {
        console += "🟢 STATUS: Active\n";
    }
    
    // Position info
    if(hasActivePosition)
    {
        console += "\n📊 ACTIVE POSITION:\n";
        console += "   " + currentSignal.direction + " " + currentSignal.symbol + "\n";
        console += "   Entry: " + DoubleToString(activePosition.entryPrice, 2) + "\n";
        console += "   SL: " + DoubleToString(activePosition.stopLoss, 2);
        if(activePosition.movedToBreakeven) console += " (BE)";
        console += "\n";
        console += "   TP1: " + (activePosition.tp1Hit ? "✅" : "⏳") + " " + DoubleToString(activePosition.tp1Price, 2) + "\n";
        console += "   TP2: " + (activePosition.tp2Hit ? "✅" : "⏳") + " " + DoubleToString(activePosition.tp2Price, 2) + "\n";
        console += "   TP3: ⏳ " + DoubleToString(activePosition.tp3Price, 2) + "\n";
        
        if(PositionSelectByTicket(activePosition.ticket))
        {
            double profit = PositionGetDouble(POSITION_PROFIT);
            console += "   P/L: " + (profit >= 0 ? "🟢" : "🔴") + " $" + DoubleToString(profit, 2) + "\n";
        }
    }
    else
    {
        console += "\n📭 No active position\n";
    }
    
    // Statistics
    console += "\n📈 STATISTICS:\n";
    console += "   Total Trades: " + IntegerToString(totalTrades) + "\n";
    console += "   Wins: " + IntegerToString(winningTrades) + " | Losses: " + IntegerToString(losingTrades) + "\n";
    if(totalTrades > 0)
        console += "   Win Rate: " + DoubleToString((double)winningTrades/totalTrades*100, 1) + "%\n";
    console += "   Net P/L: $" + DoubleToString(totalProfit - totalLoss, 2) + "\n";
    
    console += "========================================\n";
    console += "🕐 " + TimeToString(TimeCurrent(), TIME_SECONDS) + "\n";
    
    Comment(console);
}

//+------------------------------------------------------------------+
//| Helper: Extract JSON value                                       |
//+------------------------------------------------------------------+
string ExtractJsonValue(string json, string key)
{
    string searchKey = "\"" + key + "\":";
    int start = StringFind(json, searchKey);
    if(start == -1) return "";
    
    start += StringLen(searchKey);
    
    // Skip whitespace and quotes
    while(start < StringLen(json) && (StringGetCharacter(json, start) == ' ' || StringGetCharacter(json, start) == '"'))
        start++;
    
    int end = start;
    bool inQuotes = false;
    
    // Find end of value
    while(end < StringLen(json))
    {
        ushort ch = StringGetCharacter(json, end);
        if(ch == '"') inQuotes = !inQuotes;
        if(!inQuotes && (ch == ',' || ch == '}' || ch == ']'))
            break;
        end++;
    }
    
    string value = StringSubstr(json, start, end - start);
    StringReplace(value, "\"", "");
    StringTrimLeft(value);
    StringTrimRight(value);
    
    return value;
}

//+------------------------------------------------------------------+
//| Helper: Normalize lot size                                       |
//+------------------------------------------------------------------+
double NormalizeLots(double lots)
{
    double lotStep = SymbolInfoDouble(currentSignal.symbol, SYMBOL_VOLUME_STEP);
    return MathRound(lots / lotStep) * lotStep;
}

//+------------------------------------------------------------------+
//| Helper: Get trade error description                              |
//+------------------------------------------------------------------+
string GetTradeErrorDescription(uint retcode)
{
    switch(retcode)
    {
        case TRADE_RETCODE_DONE: return "Request completed";
        case TRADE_RETCODE_REJECT: return "Request rejected";
        case TRADE_RETCODE_INVALID: return "Invalid request";
        case TRADE_RETCODE_ERROR: return "Request error";
        case TRADE_RETCODE_TIMEOUT: return "Request timeout";
        case TRADE_RETCODE_INVALID_PRICE: return "Invalid price";
        case TRADE_RETCODE_INVALID_STOPS: return "Invalid stops";
        case TRADE_RETCODE_INVALID_VOLUME: return "Invalid volume";
        case TRADE_RETCODE_MARKET_CLOSED: return "Market closed";
        case TRADE_RETCODE_NO_MONEY: return "Not enough money";
        default: return "Unknown error: " + IntegerToString(retcode);
    }
}
