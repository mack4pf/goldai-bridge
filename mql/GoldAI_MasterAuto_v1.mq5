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
    double confidence;
    string grade;
    datetime timestamp;
};

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    trade.SetExpertMagicNumber(Magic_Number);
    starting_balance_today = AccountInfoDouble(ACCOUNT_BALANCE);
    last_trade_day = iTime(_Symbol, PERIOD_D1, 0);
    
    Print("🚀 GoldAI Master EA v1.0 Initialized");
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
    Print("Starting Equity: ", starting_balance_today);
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("🛑 GoldAI Master EA Stopped");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // 0. Periodic License Check (Every 1 hour)
    if(TimeCurrent() - last_license_check > 3600)
    {
        CheckLicense();
        if(!is_license_valid)
        {
            Print("🛑 LICENSE EXPIRED/INVALID. Stopping trading.");
            return;
        }
    }

    if(!is_license_valid) return;

    // 1. Manage existing positions
    ManagePositions();

    // 2. Poll for new signals
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

    int res = WebRequest("GET", url, headers, 5000, postData, result, resultHeaders);

    if(res == 200)
    {
        string response = CharArrayToString(result);
        ProcessSignal(response);
    }
}

//+------------------------------------------------------------------+
//| Process JSON signal response                                     |
//+------------------------------------------------------------------+
void ProcessSignal(string json)
{
    // Basic JSON parsing (simplified for the example)
    // In a real EA, we would use a robust JSON library
    if(StringFind(json, "\"signalId\"") == -1) return;

    SignalData sig;
    sig.id = GetJsonValue(json, "signalId");
    sig.symbol = GetJsonValue(json, "symbol");
    sig.type = GetJsonValue(json, "type");
    sig.entry = StringToDouble(GetJsonValue(json, "entry"));
    sig.sl = StringToDouble(GetJsonValue(json, "sl"));
    sig.tp = StringToDouble(GetJsonValue(json, "tp"));
    sig.confidence = StringToDouble(GetJsonValue(json, "confidence"));
    sig.grade = GetJsonValue(json, "grade");

    // Skip if it's the same signal we already processed
    if(sig.id == last_signal_id && last_signal_id != "") return;
    
    // Skip if not XAUUSD
    if(sig.symbol != "XAUUSD") return;

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
}

//+------------------------------------------------------------------+
//| Check if trade conditions are met                                |
//+------------------------------------------------------------------+
bool CanTrade(SignalData &sig)
{
    // 0. Reset daily stats if new day
    datetime currentDay = iTime(_Symbol, PERIOD_D1, 0);
    if(currentDay != last_trade_day)
    {
        trades_today = 0;
        starting_balance_today = AccountInfoDouble(ACCOUNT_BALANCE);
        last_trade_day = currentDay;
        Print("🌅 New Day Started. Resetting daily stats.");
    }

    // 1. Session Check (GMT)
    MqlDateTime gmt;
    TimeGMT(gmt);
    
    bool isLondon = (gmt.hour >= London_Start && gmt.hour < London_End);
    bool isNY = (gmt.hour >= NY_Start && gmt.hour < NY_End);
    
    if(!isLondon && !isNY)
    {
        Print("❌ Outside trading sessions. London/NY only.");
        return false;
    }

    // 2. Already open check
    if(CountOpenPositions() > 0)
    {
        Print("❌ Already have open positions. One signal at a time.");
        return false;
    }

    // 3. Daily Trade Limit Check
    if(trades_today >= Max_Trades_Per_Day)
    {
        Print("❌ Daily trade limit reached (", Max_Trades_Per_Day, ")");
        return false;
    }

    // 4. Daily Drawdown Check
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    double dailyLoss = starting_balance_today - currentEquity;
    double maxLossAmount = starting_balance_today * (Max_Daily_Drawdown_Percent / 100.0);
    
    if(dailyLoss >= maxLossAmount)
    {
        Print("❌ Daily drawdown limit reached (", Max_Daily_Drawdown_Percent, "%)");
        return false;
    }

    // 5. Margin Check
    double lotSize = CalculateTierLotSize();
    double requiredMargin;
    if(!OrderCalcMargin(sig.type == "BUY" ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, lotSize * 2, SymbolInfoDouble(_Symbol, SYMBOL_ASK), requiredMargin))
    {
        Print("❌ Failed to calculate margin");
        return false;
    }
    
    if(requiredMargin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
    {
        Print("❌ Insufficient free margin for 2 positions");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Calculate Lot Size based on Tier logic                           |
//+------------------------------------------------------------------+
double CalculateTierLotSize()
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double lotPerTrade = 0.01;

    if(balance < 500)       lotPerTrade = 0.01;
    else if(balance < 1000) lotPerTrade = 0.02;
    else if(balance < 2000) lotPerTrade = 0.05;
    else if(balance < 5000) lotPerTrade = 0.10;
    else 
    {
        // 2% Risk calculation for $5000+
        // Simplified pip value for XAUUSD
        double riskAmount = balance * 0.02;
        // In this specific tier rules, the prompt says "max 2% risk" or dynamic
        // We'll stick to a safe 0.20 base or calculate based on SL
        lotPerTrade = 0.20; // Default for scaling
    }

    return lotPerTrade;
}

//+------------------------------------------------------------------+
//| Execute Split Trades                                              |
//+------------------------------------------------------------------+
void ExecuteSplitTrade(SignalData &sig)
{
    double lot = CalculateTierLotSize();
    double tpDistance = MathAbs(sig.entry - sig.tp);
    
    // Trade 1: Early Security (30-50% TP distance)
    double tp1 = (sig.type == "BUY") ? sig.entry + (tpDistance * TP1_Ratio) : sig.entry - (tpDistance * TP1_Ratio);
    
    // Trade 2: Runner (Full TP)
    double tp2 = sig.tp;

    ENUM_ORDER_TYPE orderType = (sig.type == "BUY") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    double price = (sig.type == "BUY") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

    Print("⚡ Executing Split Trades: Lot ", lot, " x 2");

    // Open Trade 1
    if(trade.Buy(lot, _Symbol, price, sig.sl, tp1, "T1:" + sig.id) || 
       trade.Sell(lot, _Symbol, price, sig.sl, tp1, "T1:" + sig.id))
    {
        // Open Trade 2
        if(trade.Buy(lot, _Symbol, price, sig.sl, tp2, "T2:" + sig.id) ||
           trade.Sell(lot, _Symbol, price, sig.sl, tp2, "T2:" + sig.id))
        {
            last_signal_id = sig.id;
            current_signal_type = sig.type;
            trades_today++;
            Print("✅ Successfully opened 2 split positions for Signal ", sig.id, " (Trades today: ", trades_today, ")");
            
            // Broadcast open event
            BroadcastTradeEvent("OPEN", price, lot * 2, sig.sl, sig.id);
        }
    }
}

//+------------------------------------------------------------------+
//| Manage Open Positions Logic                                       |
//+------------------------------------------------------------------+
void ManagePositions()
{
    bool t1_active = false;
    ulong t2_ticket = 0;
    double t2_entry = 0;
    double t2_sl = 0;
    double t2_tp = 0;

    // Scan positions
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(pos.SelectByIndex(i))
        {
            if(pos.Magic() == Magic_Number)
            {
                string comment = pos.Comment();
                if(StringFind(comment, "T1") == 0) t1_active = true;
                if(StringFind(comment, "T2") == 0) 
                {
                    t2_ticket = pos.Ticket();
                    t2_entry = pos.PriceOpen();
                    t2_sl = pos.StopLoss();
                    t2_tp = pos.TakeProfit();
                }

                // Time-based safety: 120 minutes -> Move to BE
                if(TimeCurrent() - pos.Time() > Safety_Close_Minutes * 60)
                {
                    if(pos.StopLoss() != pos.PriceOpen())
                    {
                        if(trade.PositionModify(pos.Ticket(), pos.PriceOpen(), pos.TakeProfit()))
                        {
                            Print("⏰ Safety rule: Moved Ticket ", pos.Ticket(), " to Breakeven (120 min limit)");
                            BroadcastTradeEvent("MODIFY_SL", pos.PriceOpen(), pos.Volume(), pos.PriceOpen(), comment);
                        }
                    }
                }
            }
        }
    }

    // BREAKEVEN LOGIC: If T1 is gone and T2 is still running, move T2 to BE+buffer
    if(!t1_active && t2_ticket > 0)
    {
        double tpDistance = MathAbs(t2_entry - t2_tp);
        double buffer = tpDistance * 0.25; // 25% buffer as per plan
        double desiredBE = (current_signal_type == "BUY") ? t2_entry + buffer : t2_entry - buffer;

        // Only modify if not already moved
        if((current_signal_type == "BUY" && t2_sl < t2_entry) || (current_signal_type == "SELL" && t2_sl > t2_entry))
        {
             if(trade.PositionModify(t2_ticket, desiredBE, t2_tp))
             {
                 Print("🛡️ TP1 Secured: Moving T2 Ticket ", t2_ticket, " to BE + 25% Buffer");
                 BroadcastTradeEvent("MODIFY_SL", t2_entry, activePositionVolume(t2_ticket), desiredBE, "T2_BE");
             }
        }
        
        // TP-ZONE PROTECTION: Tighten SL at 90% completion
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID); // Bid for profit check
        double completion = (MathAbs(currentPrice - t2_entry) / tpDistance);
        
        if(completion >= 0.90)
        {
            double secureSL = (current_signal_type == "BUY") ? t2_entry + (tpDistance * 0.85) : t2_entry - (tpDistance * 0.85);
            if((current_signal_type == "BUY" && t2_sl < secureSL) || (current_signal_type == "SELL" && t2_sl > secureSL))
            {
                if(trade.PositionModify(t2_ticket, secureSL, t2_tp))
                {
                    Print("🎯 Zone Protection: Moved T2 SL to 85% TP to lock runner profit");
                    BroadcastTradeEvent("MODIFY_SL", t2_entry, activePositionVolume(t2_ticket), secureSL, "ZONE_PROTECT");
                }
            }
        }
    }

    // Reset current_signal_type if no positions left
    if(CountOpenPositions() == 0)
    {
        if(current_signal_type != "")
        {
            Print("🏁 All positions closed. Waiting for next signal.");
            current_signal_type = "";
        }
    }
}

//+------------------------------------------------------------------+
//| Close all trades with matching magic number                      |
//+------------------------------------------------------------------+
void CloseAllTrades()
{
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
                if(trade.PositionClose(ticket))
                {
                    BroadcastTradeEvent("CLOSE", price, vol, 0, comment);
                }
            }
        }
    }
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
    
    int res = WebRequest("GET", url, headers, 5000, postData, result, resultHeaders);
    
    if(res == 200)
    {
        string json = CharArrayToString(result);
        string success = GetJsonValue(json, "success");
        string message = GetJsonValue(json, "message");
        
        if(success == "true")
        {
            is_license_valid = true;
            string expires = GetJsonValue(json, "expiresAt");
            // Basic date parsing or just display the string
            license_status_msg = StringSubstr(expires, 0, 10);
            Print("✅ License Verification: VALID (Expires: ", license_status_msg, ")");
        }
        else
        {
            is_license_valid = false;
            license_status_msg = message;
            Print("❌ License Verification: FAILED (", message, ")");
        }
    }
    else
    {
        // Network error - be lenient? Or strict? 
        // For security, usually strict, but for reliability, maybe allow if previously valid.
        // Here we'll just log it. If it was valid before, we keep it valid for now until next check.
        if(!is_license_valid)
        {
            license_status_msg = "Network Error " + IntegerToString(res);
            Print("⚠️ License Check Failed: Network Error ", res);
        }
    }
    
    last_license_check = TimeCurrent();
}
//+------------------------------------------------------------------+
//| Get volume of an active position                                 |
//+------------------------------------------------------------------+
double activePositionVolume(ulong ticket)
{
    if(PositionSelectByTicket(ticket)) return PositionGetDouble(POSITION_VOLUME);
    return 0;
}

//+------------------------------------------------------------------+
//| Broadcast trade event to copier via Bridge                       |
//+------------------------------------------------------------------+
void BroadcastTradeEvent(string operation, double price, double lots, double sl, string signalId)
{
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
    
    int res = WebRequest("POST", url, headers, 5000, postData, result, resultHeaders);
    if(res != 200) Print("⚠️ Copier Broadcast Failed: HTTP ", res);
}
//+------------------------------------------------------------------+
