// ===================================================================
// CONFLUENCE VALIDATION HELPER FUNCTIONS
// Add these to the EA after the existing code
// ===================================================================

//+------------------------------------------------------------------+
//| Validate RSI Condition                                            |
//+------------------------------------------------------------------+
bool ValidateRSI(string condition, double requiredValue)
{
    // Calculate current RSI
    double rsiArray[];
    ArraySetAsSeries(rsiArray, true);
    
    int rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
    if(rsiHandle == INVALID_HANDLE)
    {
        Print("❌ RSI indicator failed");
        return false;
    }
    
    if(CopyBuffer(rsiHandle, 0, 0, 3, rsiArray) < 3)
    {
        IndicatorRelease(rsiHandle);
        return false;
    }
    
    double currentRSI = rsiArray[0];
    double prevRSI = rsiArray[1];
    
    IndicatorRelease(rsiHandle);
    
    Print("   RSI: ", NormalizeDouble(currentRSI, 2), " (Required: ", condition, ")");
    
    // Validate based on condition
    if(condition == "ABOVE_60_TURNING_DOWN")
    {
        if(currentRSI < 60) return false;
        if(currentRSI >= prevRSI) return false; // Still rising
        Print("   ✅ RSI Valid: Above 60 and turning down");
        return true;
    }
    else if(condition == "ABOVE_70_OVERBOUGHT")
    {
        if(currentRSI < 70) return false;
        Print("   ✅ RSI Valid: Overbought");
        return true;
    }
    else if(condition == "BELOW_40_TURNING_UP")
    {
        if(currentRSI > 40) return false;
        if(currentRSI <= prevRSI) return false; // Still falling
        Print("   ✅ RSI Valid: Below 40 and turning up");
        return true;
    }
    else if(condition == "BELOW_30_OVERSOLD")
    {
        if(currentRSI > 30) return false;
        Print("   ✅ RSI Valid: Oversold");
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Detect Wick Rejection                                             |
//+------------------------------------------------------------------+
bool DetectWickRejection(string direction, double minSizePips)
{
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    
    if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 3, rates) < 3)
    {
        Print("❌ Failed to get candle data");
        return false;
    }
    
    // Check current candle
    double open = rates[0].open;
    double close = rates[0].close;
    double high = rates[0].high;
    double low = rates[0].low;
    
    double body = MathAbs(close - open);
    double upperWick = high - MathMax(open, close);
    double lowerWick = MathMin(open, close) - low;
    
    // Convert to pips
    double upperWickPips = upperWick / _Point / 10;
    double lowerWickPips = lowerWick / _Point / 10;
    
    Print("   Candle Analysis:");
    Print("   Upper Wick: ", NormalizeDouble(upperWickPips, 1), " pips");
    Print("   Lower Wick: ", NormalizeDouble(lowerWickPips, 1), " pips");
    Print("   Body: ", NormalizeDouble(body / _Point / 10, 1), " pips");
    
    if(direction == "UPPER_WICK")
    {
        // Upper wick must be significant
        if(upperWickPips < minSizePips) return false;
        if(upperWick < body * 1.5) return false; // Wick must be at least 1.5x body
        
        Print("   ✅ Upper Wick Rejection Detected");
        return true;
    }
    else if(direction == "LOWER_WICK")
    {
        // Lower wick must be significant
        if(lowerWickPips < minSizePips) return false;
        if(lowerWick < body * 1.5) return false;
        
        Print("   ✅ Lower Wick Rejection Detected");
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Detect Reversal Candlestick Pattern                              |
//+------------------------------------------------------------------+
bool DetectReversalCandle(string pattern)
{
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    
    if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 3, rates) < 3)
        return false;
    
    if(pattern == "SHOOTING_STAR_OR_ENGULFING")
    {
        // Check for shooting star
        if(IsShootingStar(rates[0]))
        {
            Print("   ✅ Shooting Star detected");
            return true;
        }
        
        // Check for bearish engulfing
        if(IsBearishEngulfing(rates[0], rates[1]))
        {
            Print("   ✅ Bearish Engulfing detected");
            return true;
        }
    }
    else if(pattern == "HAMMER_OR_BULLISH_ENGULFING")
    {
        // Check for hammer
        if(IsHammer(rates[0]))
        {
            Print("   ✅ Hammer detected");
            return true;
        }
        
        // Check for bullish engulfing
        if(IsBullishEngulfing(rates[0], rates[1]))
        {
            Print("   ✅ Bullish Engulfing detected");
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check if Candle is Shooting Star                                 |
//+------------------------------------------------------------------+
bool IsShootingStar(const MqlRates &candle)
{
    double body = MathAbs(candle.close - candle.open);
    double upperWick = candle.high - MathMax(candle.open, candle.close);
    double lowerWick = MathMin(candle.open, candle.close) - candle.low;
    
    // Shooting star: Long upper wick, small body, small lower wick
    if(upperWick > body * 2 && lowerWick < body * 0.5)
        return true;
    
    return false;
}

//+------------------------------------------------------------------+
//| Check if Candle is Hammer                                         |
//+------------------------------------------------------------------+
bool IsHammer(const MqlRates &candle)
{
    double body = MathAbs(candle.close - candle.open);
    double upperWick = candle.high - MathMax(candle.open, candle.close);
    double lowerWick = MathMin(candle.open, candle.close) - candle.low;
    
    // Hammer: Long lower wick, small body, small upper wick
    if(lowerWick > body * 2 && upperWick < body * 0.5)
        return true;
    
    return false;
}

//+------------------------------------------------------------------+
//| Check for Bearish Engulfing                                       |
//+------------------------------------------------------------------+
bool IsBearishEngulfing(const MqlRates &current, const MqlRates &previous)
{
    // Previous candle bullish
    if(previous.close <= previous.open) return false;
    
    // Current candle bearish
    if(current.close >= current.open) return false;
    
    // Current candle engulfs previous
    if(current.open >= previous.close && current.close <= previous.open)
        return true;
    
    return false;
}

//+------------------------------------------------------------------+
//| Check for Bullish Engulfing                                       |
//+------------------------------------------------------------------+
bool IsBullishEngulfing(const MqlRates &current, const MqlRates &previous)
{
    // Previous candle bearish
    if(previous.close >= previous.open) return false;
    
    // Current candle bullish
    if(current.close <= current.open) return false;
    
    // Current candle engulfs previous
    if(current.open <= previous.close && current.close >= previous.open)
        return true;
    
    return false;
}

//+------------------------------------------------------------------+
//| Check if Price is in Entry Zone                                  |
//+------------------------------------------------------------------+
bool IsPriceInZone(double zoneMin, double zoneMax)
{
    double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double currentPrice = (currentAsk + currentBid) / 2;
    
    bool inZone = (currentPrice >= zoneMin && currentPrice <= zoneMax);
    
    if(inZone)
    {
        Print("   ✅ Price in Entry Zone: ", NormalizeDouble(currentPrice, 2), 
              " (Zone: ", NormalizeDouble(zoneMin, 2), " - ", NormalizeDouble(zoneMax, 2), ")");
    }
    
    return inZone;
}

//+------------------------------------------------------------------+
//| Calculate Lot Size Based on Risk                                 |
//+------------------------------------------------------------------+
double CalculateLotSize(double entryPrice, double stopLoss, double riskPercent)
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = balance * (riskPercent / 100.0);
    
    double stopLossPips = MathAbs(entryPrice - stopLoss) / _Point / 10;
    
    // For XAUUSD: 1 pip = $10 per 1.0 lot (approximately)
    // LotSize = RiskAmount / (SLPips * 10)
    double lotSize = riskAmount / (stopLossPips * 10);
    
    // Normalize to broker's lot step
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lotSize = MathFloor(lotSize / lotStep) * lotStep;
    
    // Apply limits
    if(lotSize < minLot) lotSize = minLot;
    if(lotSize > maxLot) lotSize = maxLot;
    if(lotSize > 5.0) lotSize = 5.0; // Hard cap
    
    Print("   💰 Lot Size Calculation:");
    Print("   Balance: $", balance);
    Print("   Risk: ", riskPercent, "% = $", riskAmount);
    Print("   SL Distance: ", NormalizeDouble(stopLossPips, 1), " pips");
    Print("   Lot Size: ", NormalizeDouble(lotSize, 2));
    
    return lotSize;
}

// ===================================================================
// END OF HELPER FUNCTIONS
// Copy all this code and add to your EA
// ===================================================================
