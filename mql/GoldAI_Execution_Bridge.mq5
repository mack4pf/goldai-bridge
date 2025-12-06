//+------------------------------------------------------------------+
//|                                      GoldAI_Execution_Bridge.mq5 |
//|                                  Copyright 2024, GoldAI Mentor   |
//|                                             https://goldai.pro   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

// --- INPUTS ---
input string   API_URL     = "http://localhost:3001/api/v1"; // Bridge API URL
input string   Bridge_Token = "";                            // Paste Token from Telegram

// --- GLOBALS ---
int    checkInterval = 3; // Seconds
datetime lastCheck = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(Bridge_Token == "") {
      Alert("❌ Error: Please enter your Bridge Token!");
      return(INIT_FAILED);
   }
   
   // Enable WebRequest for localhost (User must do this in Options)
   Print("🤖 GoldAI Execution Bridge Started. URL: ", API_URL);
   
   EventSetTimer(checkInterval);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   Print("🛑 Bridge Stopped.");
  }

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   CheckForCommands();
  }

//+------------------------------------------------------------------+
//| Main Logic: Poll Server                                          |
//+------------------------------------------------------------------+
void CheckForCommands()
  {
   string url = API_URL + "/commands?token=" + Bridge_Token;
   char postData[];
   char result[];
   string headers = "Content-Type: application/json\r\n";
   string resultHeaders;
   
   int res = WebRequest("GET", url, headers, 5000, postData, result, resultHeaders);
   
   if(res == 200) {
      string json = CharArrayToString(result);
      
      // Simple String Parsing (Production should use a JSON Lib)
      if(StringFind(json, "\"hasCommand\":true") > 0) {
         Print("⚡ Command Received: ", json);
         ProcessCommand(json);
      }
   } else {
      // Print("⚠️ Connection Error: ", res);
   }
  }

//+------------------------------------------------------------------+
//| Process Command & Execute Trade                                  |
//+------------------------------------------------------------------+
void ProcessCommand(string json)
  {
   // Parse JSON manually for MVP (Fragile but works without libs)
   // Needed: commandId, symbol, cmd (0/1), volume, sl, tp
   
   string commandId = ExtractJsonValue(json, "commandId");
   string symbol    = ExtractJsonValue(json, "symbol");
   double volume    = StringToDouble(ExtractJsonValue(json, "volume"));
   double sl        = StringToDouble(ExtractJsonValue(json, "sl"));
   double tp        = StringToDouble(ExtractJsonValue(json, "tp"));
   int    cmd       = (int)StringToInteger(ExtractJsonValue(json, "cmd"));
   
   // Execute Trade
   MqlTradeRequest request;
   MqlTradeResult  result;
   ZeroMemory(request);
   ZeroMemory(result);
   
   request.action       = TRADE_ACTION_DEAL;
   request.symbol       = symbol;
   request.volume       = volume;
   request.type         = (ENUM_ORDER_TYPE)cmd;
   request.price        = (cmd == ORDER_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
   request.sl           = sl;
   request.tp           = tp;
   request.deviation    = 10;
   request.magic        = 123456;
   request.comment      = "GoldAI-Auto";
   
   bool success = OrderSend(request, result);
   
   if(success) {
      Print("✅ Trade Executed! Ticket: ", result.order);
      ReportExecution(commandId, true, (string)result.order, "");
   } else {
      Print("❌ Trade Failed: ", GetLastError());
      ReportExecution(commandId, false, "", (string)GetLastError());
   }
  }

//+------------------------------------------------------------------+
//| Report Execution Result                                          |
//+------------------------------------------------------------------+
void ReportExecution(string commandId, bool success, string ticket, string error)
  {
   string url = API_URL + "/execution";
   string headers = "Content-Type: application/json\r\nx-bridge-token: " + Bridge_Token + "\r\n";
   
   string json = StringFormat("{\"commandId\":\"%s\",\"success\":%s,\"ticket\":\"%s\",\"error\":\"%s\",\"balance\":%.2f}",
                              commandId, success ? "true" : "false", ticket, error, AccountInfoDouble(ACCOUNT_BALANCE));
                              
   char postData[];
   StringToCharArray(json, postData);
   char result[];
   string resultHeaders;
   
   WebRequest("POST", url, headers, 5000, postData, result, resultHeaders);
  }

//+------------------------------------------------------------------+
//| Helper: Extract Value from JSON String                           |
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
   if(isString) end = StringFind(json, "\"", start);
   else {
      end = StringFind(json, ",", start);
      if(end < 0) end = StringFind(json, "}", start);
   }
   
   return StringSubstr(json, start, end - start);
  }
