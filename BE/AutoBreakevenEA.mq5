//+------------------------------------------------------------------+
//|                                          AutoBreakevenEA.mq5    |
//|                                  Copyright 2025, Your Name Here |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Name Here"
#property link      "https://www.mql5.com"
#property version   "1.00"

//--- Input parameters
input group "=== Breakeven Settings ==="
input int    BreakevenPoints = 500;        // Points in profit to trigger breakeven
input int    AdditionalPoints = 0;         // Additional points beyond entry (0 = exact breakeven)
input bool   UseOnlyCurrentSymbol = true;  // Apply only to current chart symbol

input group "=== Initial Stop Loss Settings ==="
input bool   SetInitialSL = true;          // Set initial SL for positions without SL
input int    InitialSLPoints = 500;        // Initial SL distance in points from entry
input bool   OnlySetSLForNewPositions = false; // Only set SL for positions opened after EA start
input bool   OverrideExistingSL = true;    // Override existing SL with initial SL setting

input group "=== Notification Settings ==="
input bool   ShowAlerts = false;           // Show alert messages
input bool   WriteToLog = true;            // Write actions to Expert log
input bool   SendNotifications = false;    // Send push notifications

input group "=== Auto Close Settings ==="
input bool   EnableAutoClose = false;      // Enable auto close functionality
input bool   UseSpecificCloseTime = false; // Use specific daily close time
input int    CloseHour = 17;               // Hour to close positions (0-23)
input int    CloseMinute = 0;              // Minute to close positions (0-59)
input bool   UseSpecificDateTime = false;  // Use specific date and time to close
input int    CloseYear = 2025;             // Year to close positions
input int    CloseMonth = 7;               // Month to close positions (1-12)
input int    CloseDay = 5;                 // Day to close positions (1-31)
input int    CloseHourSpecific = 15;       // Hour for specific date close (0-23)
input int    CloseMinuteSpecific = 30;     // Minute for specific date close (0-59)
input bool   CloseOnlyProfitable = false;  // Only close profitable positions
input double MinProfitToClose = 0.0;       // Minimum profit in account currency to close
input bool   ShowCloseMarker = true;       // Show close time marker on chart
input color  CloseMarkerColor = clrRed;    // Color of the close marker

input group "=== Trailing Stop Loss Settings ==="
input bool   EnableTrailingStop = false;   // Enable trailing stop loss
input double TrailingTriggerPrice = 3330.0; // Price level to activate trailing stop
input int    TrailingStopPoints = 500;     // Trailing stop distance in points
input int    TrailingStepPoints = 10;      // Minimum points to move trailing stop

input group "=== Advanced Settings ==="
input int    CheckIntervalMs = 1000;       // Check interval in milliseconds
input double MinProfitPercent = 0.1;       // Minimum profit percentage to consider

//--- Global variables
datetime lastCheckTime = 0;
ulong processedPositions[];
ulong positionsWithSL[];
datetime eaStartTime;
ulong closedPositions[];
bool closeMarkerCreated = false;

// Trailing stop variables
bool trailingStopActivated = false;
ulong trailingManagedPositions[];
double lastTrailingCheckPrice = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("AutoBreakeven EA initialized - HIERARCHICAL SL MANAGEMENT SYSTEM");
    Print("=== SL PRIORITY SYSTEM ===");
    Print("1. TRAILING STOP (Highest Priority) - Takes full control when activated");
    Print("2. BREAKEVEN - Activates at profit targets, respects trailing stop");
    Print("3. INITIAL SL (Lowest Priority) - Immediate protection, yields to higher systems");
    Print("========================");
    Print("Breakeven trigger: ", BreakevenPoints, " points");
    Print("Additional points: ", AdditionalPoints, " points");
    Print("Check interval: ", CheckIntervalMs, " ms");
    
    if(SetInitialSL)
    {
        Print("Initial SL: ", InitialSLPoints, " points");
        Print("Only new positions: ", OnlySetSLForNewPositions ? "Yes" : "No");
        Print("Override existing SL: ", OverrideExistingSL ? "Yes" : "No");
    }
    
    if(EnableAutoClose)
    {
        Print("Auto close enabled");
        if(UseSpecificDateTime)
        {
            MqlDateTime closeDateTime;
            closeDateTime.year = CloseYear;
            closeDateTime.mon = CloseMonth;
            closeDateTime.day = CloseDay;
            closeDateTime.hour = CloseHourSpecific;
            closeDateTime.min = CloseMinuteSpecific;
            closeDateTime.sec = 0;
            datetime closeDT = StructToTime(closeDateTime);
            
            Print("Close at specific date/time: ", TimeToString(closeDT, TIME_DATE|TIME_MINUTES));
            Print("Server time zone: Broker server time (check MT5 terminal)");
            Print("Current server time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
        }
        else if(UseSpecificCloseTime)
            Print("Close time: ", CloseHour, ":", StringFormat("%02d", CloseMinute));
        Print("Close only profitable: ", CloseOnlyProfitable ? "Yes" : "No");
        if(CloseOnlyProfitable)
            Print("Min profit to close: ", MinProfitToClose);
    }
    
    if(EnableTrailingStop)
    {
        Print("=== TRAILING STOP SYSTEM ===");
        Print("Trailing stop enabled - HIGHEST PRIORITY SYSTEM");
        Print("Trigger price: ", TrailingTriggerPrice);
        Print("Trailing distance: ", TrailingStopPoints, " points");
        Print("Trailing step: ", TrailingStepPoints, " points");
        Print("Auto-deactivation: When price moves back beyond trigger");
        Print("===========================");
    }
    
    // Reset processed positions array
    ArrayResize(processedPositions, 0);
    ArrayResize(positionsWithSL, 0);
    ArrayResize(closedPositions, 0);
    ArrayResize(trailingManagedPositions, 0);
    
    // Record EA start time
    eaStartTime = TimeCurrent();
    
    // Create close marker if auto close is enabled
    if(EnableAutoClose && ShowCloseMarker)
        CreateCloseMarker();
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("AutoBreakeven EA stopped. Reason: ", reason);
    
    // Remove close marker when EA is removed
    ObjectDelete(0, "AutoClose_Marker");
    ObjectDelete(0, "AutoClose_Label");
    
    // Reset trailing stop state
    trailingStopActivated = false;
    ArrayResize(trailingManagedPositions, 0);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Control check frequency
    if(GetTickCount() - lastCheckTime < CheckIntervalMs) return;
    lastCheckTime = GetTickCount();
    
    CheckAndModifyPositions();
}

//+------------------------------------------------------------------+
//| Check and modify positions function                              |
//+------------------------------------------------------------------+
void CheckAndModifyPositions()
{
    int totalPositions = PositionsTotal();
    if(WriteToLog && totalPositions > 0)
        Print("=== CHECKING ", totalPositions, " POSITIONS ===");
    if(totalPositions == 0) return;
    
    // First check for auto close if enabled
    if(EnableAutoClose)
        CheckAutoClose();
    
    // Check for trailing stop if enabled
    if(EnableTrailingStop)
        CheckTrailingStop();
    
    // Check and recreate close marker if needed (handles timeframe changes)
    if(EnableAutoClose && ShowCloseMarker)
        CheckAndRecreateMarker();
    
    // Process all positions for breakeven and initial SL
    for(int i = 0; i < totalPositions; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        // Get position properties
        string symbol = PositionGetString(POSITION_SYMBOL);
        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentTP = PositionGetDouble(POSITION_TP);
        datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
        
        // Skip if UseOnlyCurrentSymbol is true and symbol doesn't match
        if(UseOnlyCurrentSymbol && symbol != _Symbol) 
        {
            if(WriteToLog) Print("Position #", ticket, " skipped - different symbol (", symbol, " vs ", _Symbol, ")");
            continue;
        }
        
        if(WriteToLog) 
            Print("Processing position #", ticket, " (", symbol, ") - SL:", currentSL, " TP:", currentTP, " OpenTime:", TimeToString(openTime));
        
        // Get current market price
        MqlTick tick;
        if(!SymbolInfoTick(symbol, tick)) continue;
        
        double currentPrice = (type == POSITION_TYPE_BUY) ? tick.bid : tick.ask;
        
        // Calculate profit in points
        double pointSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        
        double profitInPoints = 0;
        if(type == POSITION_TYPE_BUY)
            profitInPoints = (currentPrice - openPrice) / pointSize;
        else
            profitInPoints = (openPrice - currentPrice) / pointSize;
        
        // HIERARCHICAL SL MANAGEMENT SYSTEM
        // Priority: 1. Trailing Stop (highest) 2. Breakeven 3. Initial SL (lowest)
        
        // Skip if position is being managed by trailing stop (trailing has highest priority)
        if(EnableTrailingStop && IsTrailingManagedPosition(ticket)) 
        {
            if(WriteToLog) 
                Print("Position #", ticket, " managed by trailing stop - skipping other SL systems");
            continue;
        }
        
        // First, check if we need to set initial SL for positions without SL
        // This check is done BEFORE the profit percentage check to ensure all positions get SL
        bool needsInitialSL = false;
        if(SetInitialSL)
        {
            if(WriteToLog) 
                Print("Position #", ticket, " - Checking initial SL. Current SL: ", currentSL, " SetInitialSL: ", SetInitialSL);
            
            // Check if we should set initial SL - always check positions without SL
            if(currentSL == 0)
            {
                needsInitialSL = true; // No SL exists - always process
                if(WriteToLog) Print("Position #", ticket, " needs initial SL - no SL exists");
            }
            else if(OverrideExistingSL && !IsPositionProcessedForSL(ticket))
            {
                needsInitialSL = true; // Override existing SL only if not processed before
                if(WriteToLog) Print("Position #", ticket, " needs initial SL - override enabled and not processed");
            }
            else if(WriteToLog)
            {
                Print("Position #", ticket, " does not need initial SL. OverrideExistingSL: ", OverrideExistingSL, " IsProcessed: ", IsPositionProcessedForSL(ticket));
            }
        }
        else if(WriteToLog)
        {
            Print("Position #", ticket, " - SetInitialSL is disabled");
        }
        
        if(needsInitialSL)
        {
            bool shouldSetSL = true;
            
            // If OnlySetSLForNewPositions is true, only set SL for positions opened after EA start
            if(OnlySetSLForNewPositions && openTime < eaStartTime)
            {
                shouldSetSL = false;
                if(WriteToLog) 
                    Print("Position #", ticket, " opened before EA start (", TimeToString(openTime), " vs ", TimeToString(eaStartTime), "), skipping initial SL");
            }
            
            if(shouldSetSL)
            {
                double initialSL = 0;
                if(type == POSITION_TYPE_BUY)
                    initialSL = NormalizeDouble(openPrice - (InitialSLPoints * pointSize), digits);
                else
                    initialSL = NormalizeDouble(openPrice + (InitialSLPoints * pointSize), digits);
                
                // Smart SL setting: Only set if it improves protection or no SL exists
                bool needsModification = true;
                if(currentSL != 0 && !OverrideExistingSL)
                {
                    // Check if current SL is already better than our initial SL
                    bool currentSLIsBetter = false;
                    if(type == POSITION_TYPE_BUY && currentSL >= initialSL)
                        currentSLIsBetter = true;
                    else if(type == POSITION_TYPE_SELL && currentSL <= initialSL)
                        currentSLIsBetter = true;
                    
                    if(currentSLIsBetter)
                    {
                        needsModification = false;
                        if(WriteToLog)
                            Print("Position #", ticket, " already has better SL (", currentSL, ") than initial SL (", initialSL, ")");
                    }
                }
                else if(currentSL != 0)
                {
                    double slDifference = MathAbs(initialSL - currentSL);
                    if(slDifference < pointSize) // Less than 1 point difference
                        needsModification = false;
                }
                
                if(needsModification)
                {
                    string slAction = (currentSL == 0) ? "set" : "modified";
                    if(WriteToLog)
                        Print("Attempting to ", slAction, " initial SL for position #", ticket, " (", symbol, ") from ", currentSL, " to ", initialSL);
                    
                    if(ModifyPosition(ticket, symbol, initialSL, currentTP))
                    {
                        AddPositionWithSL(ticket);
                        
                        string message = StringFormat("Initial SL %s for %s #%I64u: SL %.5f (%d points from entry)",
                                                    slAction, symbol, ticket, initialSL, InitialSLPoints);
                        
                        if(WriteToLog) Print(message);
                        if(ShowAlerts) Alert(message);
                        if(SendNotifications) SendNotification(message);
                        
                        // Update currentSL for further processing
                        currentSL = initialSL;
                    }
                    else
                    {
                        if(WriteToLog) Print("Failed to ", slAction, " initial SL for position #", ticket);
                    }
                }
                else
                {
                    if(WriteToLog) Print("Position #", ticket, " SL already at target level (", initialSL, ")");
                    AddPositionWithSL(ticket); // Mark as processed to avoid repeated checks
                }
            }
        }
        else if(SetInitialSL)
        {
            if(WriteToLog && currentSL != 0 && !OverrideExistingSL) 
                Print("Position #", ticket, " already has SL (", currentSL, "), override disabled");
        }
        
        // Check if position is already processed for breakeven
        if(IsPositionProcessed(ticket)) continue;
        
        // Check minimum profit percentage for breakeven processing only
        double profitPercent = MathAbs(profitInPoints * pointSize / openPrice) * 100;
        if(profitPercent < MinProfitPercent) continue;
        
        // BREAKEVEN LOGIC - Only proceed if not managed by trailing stop
        if(EnableTrailingStop && IsTrailingManagedPosition(ticket)) 
        {
            if(WriteToLog) 
                Print("Position #", ticket, " managed by trailing stop - skipping breakeven");
            continue;
        }
        
        // Check if position is in profit enough to trigger breakeven
        if(profitInPoints >= BreakevenPoints)
        {
            // Calculate new stop loss (breakeven + additional points)
            double newSL = 0;
            if(type == POSITION_TYPE_BUY)
                newSL = NormalizeDouble(openPrice + (AdditionalPoints * pointSize), digits);
            else
                newSL = NormalizeDouble(openPrice - (AdditionalPoints * pointSize), digits);
            
            // Check if we need to modify (smart breakeven - only improve existing SL)
            bool needsModification = false;
            if(currentSL == 0)
            {
                needsModification = true; // No SL exists
                if(WriteToLog)
                    Print("Position #", ticket, " has no SL - setting breakeven");
            }
            else if(type == POSITION_TYPE_BUY)
            {
                // For BUY: only set breakeven if it's better than current SL
                if(newSL > currentSL + pointSize)
                {
                    needsModification = true;
                    if(WriteToLog)
                        Print("Position #", ticket, " breakeven improves SL: ", currentSL, " -> ", newSL);
                }
                else if(WriteToLog)
                    Print("Position #", ticket, " current SL (", currentSL, ") already better than breakeven (", newSL, ")");
            }
            else // POSITION_TYPE_SELL
            {
                // For SELL: only set breakeven if it's better than current SL
                if(newSL < currentSL - pointSize)
                {
                    needsModification = true;
                    if(WriteToLog)
                        Print("Position #", ticket, " breakeven improves SL: ", currentSL, " -> ", newSL);
                }
                else if(WriteToLog)
                    Print("Position #", ticket, " current SL (", currentSL, ") already better than breakeven (", newSL, ")");
            }
            
            if(needsModification)
            {
                if(ModifyPosition(ticket, symbol, newSL, currentTP))
                {
                    // Mark position as processed
                    AddProcessedPosition(ticket);
                    
                    string message = StringFormat("Breakeven set for %s #%I64u: SL %.5f (Entry: %.5f, +%.1f pts)",
                                                symbol, ticket, newSL, openPrice, profitInPoints);
                    
                    if(WriteToLog) Print(message);
                    if(ShowAlerts) Alert(message);
                    if(SendNotifications) SendNotification(message);
                }
            }
        }
    }
    
    // Clean up processed positions arrays (remove closed positions)
    CleanProcessedPositions();
    CleanPositionsWithSL();
    CleanClosedPositions();
    
    // Clean trailing managed positions if trailing is active
    if(EnableTrailingStop && trailingStopActivated)
        CleanTrailingManagedPositions();
}

//+------------------------------------------------------------------+
//| Check for auto close conditions                                  |
//+------------------------------------------------------------------+
void CheckAutoClose()
{
    int totalPositions = PositionsTotal();
    
    for(int i = totalPositions - 1; i >= 0; i--) // Process in reverse to handle position removal
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        // Skip if position was already processed for closing
        if(IsPositionClosed(ticket)) continue;
        
        // Get position properties
        string symbol = PositionGetString(POSITION_SYMBOL);
        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
        double currentProfit = PositionGetDouble(POSITION_PROFIT);
        
        // Skip if UseOnlyCurrentSymbol is true and symbol doesn't match
        if(UseOnlyCurrentSymbol && symbol != _Symbol) continue;
        
        bool shouldClose = false;
        string closeReason = "";
        
        // Check close conditions
        if(UseSpecificDateTime)
        {
            // Create the specific close datetime
            MqlDateTime closeDateTime;
            closeDateTime.year = CloseYear;
            closeDateTime.mon = CloseMonth;
            closeDateTime.day = CloseDay;
            closeDateTime.hour = CloseHourSpecific;
            closeDateTime.min = CloseMinuteSpecific;
            closeDateTime.sec = 0;
            datetime targetCloseTime = StructToTime(closeDateTime);
            
            // Check if current time has reached the target close time
            if(TimeCurrent() >= targetCloseTime && openTime < targetCloseTime)
            {
                shouldClose = true;
                closeReason = StringFormat("Specific date/time reached (%s)", 
                                         TimeToString(targetCloseTime, TIME_DATE|TIME_MINUTES));
            }
        }
        else if(UseSpecificCloseTime)
        {
            // Check if current time has passed the close time
            MqlDateTime currentTime, openTimeStruct;
            TimeToStruct(TimeCurrent(), currentTime);
            TimeToStruct(openTime, openTimeStruct);
            
            // Check if position was opened before today's close time and current time is past close time
            if(currentTime.hour > CloseHour || (currentTime.hour == CloseHour && currentTime.min >= CloseMinute))
            {
                // Position should be closed if it was opened before today's close time
                MqlDateTime todayCloseTime = currentTime;
                todayCloseTime.hour = CloseHour;
                todayCloseTime.min = CloseMinute;
                todayCloseTime.sec = 0;
                
                datetime todayCloseDateTime = StructToTime(todayCloseTime);
                
                if(openTime < todayCloseDateTime && TimeCurrent() >= todayCloseDateTime)
                {
                    shouldClose = true;
                    closeReason = StringFormat("Daily close time reached (%02d:%02d)", CloseHour, CloseMinute);
                }
            }
        }
        
        // Apply profit filter if enabled
        if(shouldClose && CloseOnlyProfitable)
        {
            if(currentProfit < MinProfitToClose)
            {
                shouldClose = false;
                if(WriteToLog)
                    Print("Position #", ticket, " meets time criteria but profit (", DoubleToString(currentProfit, 2), 
                          ") below minimum (", DoubleToString(MinProfitToClose, 2), ")");
            }
        }
        
        // Close position if conditions are met
        if(shouldClose)
        {
            if(ClosePosition(ticket, symbol))
            {
                AddClosedPosition(ticket);
                
                string message = StringFormat("Position #%I64u closed: %s (Profit: %.2f)", 
                                            ticket, closeReason, currentProfit);
                
                if(WriteToLog) Print(message);
                if(ShowAlerts) Alert(message);
                if(SendNotifications) SendNotification(message);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Create close marker on chart                                     |
//+------------------------------------------------------------------+
void CreateCloseMarker()
{
    // Always try to recreate marker to handle timeframe changes
    // Remove existing markers first
    ObjectDelete(0, "AutoClose_Marker");
    ObjectDelete(0, "AutoClose_Label");
    
    datetime targetCloseTime = 0;
    string markerText = "";
    
    if(UseSpecificDateTime)
    {
        // Create specific date/time marker
        MqlDateTime closeDateTime;
        closeDateTime.year = CloseYear;
        closeDateTime.mon = CloseMonth;
        closeDateTime.day = CloseDay;
        closeDateTime.hour = CloseHourSpecific;
        closeDateTime.min = CloseMinuteSpecific;
        closeDateTime.sec = 0;
        targetCloseTime = StructToTime(closeDateTime);
        
        markerText = StringFormat("Auto Close: %s", TimeToString(targetCloseTime, TIME_DATE|TIME_MINUTES));
    }
    else if(UseSpecificCloseTime)
    {
        // Create daily close time marker for today
        MqlDateTime currentTime;
        TimeToStruct(TimeCurrent(), currentTime);
        currentTime.hour = CloseHour;
        currentTime.min = CloseMinute;
        currentTime.sec = 0;
        targetCloseTime = StructToTime(currentTime);
        
        // If the time has already passed today, show tomorrow's close time
        if(targetCloseTime <= TimeCurrent())
            targetCloseTime += 86400; // Add 24 hours
        
        markerText = StringFormat("Daily Close: %02d:%02d", CloseHour, CloseMinute);
    }
    
    // Only create marker if we have a valid time and it's in the future (or within 1 hour of past for visibility)
    if(targetCloseTime > 0 && targetCloseTime > (TimeCurrent() - 3600)) // Show marker even if up to 1 hour in the past
    {
        // If time is in the past but recent, adjust marker text
        if(targetCloseTime <= TimeCurrent())
        {
            if(UseSpecificDateTime)
                markerText = StringFormat("Auto Close: %s [PASSED]", TimeToString(targetCloseTime, TIME_DATE|TIME_MINUTES));
            else
                markerText = StringFormat("Daily Close: %02d:%02d [PASSED]", CloseHour, CloseMinute);
        }
        // Create vertical line marker
        if(ObjectCreate(0, "AutoClose_Marker", OBJ_VLINE, 0, targetCloseTime, 0))
        {
            ObjectSetInteger(0, "AutoClose_Marker", OBJPROP_COLOR, CloseMarkerColor);
            ObjectSetInteger(0, "AutoClose_Marker", OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(0, "AutoClose_Marker", OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, "AutoClose_Marker", OBJPROP_BACK, false);
            ObjectSetInteger(0, "AutoClose_Marker", OBJPROP_SELECTABLE, false);
            ObjectSetString(0, "AutoClose_Marker", OBJPROP_TOOLTIP, markerText);
            
            closeMarkerCreated = true;
            Print("Close marker created at: ", TimeToString(targetCloseTime, TIME_DATE|TIME_MINUTES));
        }
        else
        {
            Print("Failed to create close marker at: ", TimeToString(targetCloseTime, TIME_DATE|TIME_MINUTES));
            closeMarkerCreated = false;
        }
        
        // Create text label above the line
        if(ObjectCreate(0, "AutoClose_Label", OBJ_TEXT, 0, targetCloseTime, 0))
        {
            // Get current price and calculate better positioning
            double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double pointSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            
            // Calculate visible price range for better label positioning
            double windowTop = ChartGetDouble(0, CHART_PRICE_MAX, 0);
            double windowBottom = ChartGetDouble(0, CHART_PRICE_MIN, 0);
            double priceRange = windowTop - windowBottom;
            
            // Position label in upper 10% of visible price range
            double labelPrice = windowTop - (priceRange * 0.1);
            
            ObjectSetDouble(0, "AutoClose_Label", OBJPROP_PRICE, labelPrice);
            ObjectSetString(0, "AutoClose_Label", OBJPROP_TEXT, markerText);
            ObjectSetInteger(0, "AutoClose_Label", OBJPROP_COLOR, CloseMarkerColor);
            ObjectSetInteger(0, "AutoClose_Label", OBJPROP_FONTSIZE, 9);
            ObjectSetString(0, "AutoClose_Label", OBJPROP_FONT, "Arial Bold");
            ObjectSetInteger(0, "AutoClose_Label", OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
            ObjectSetInteger(0, "AutoClose_Label", OBJPROP_BACK, false);
            ObjectSetInteger(0, "AutoClose_Label", OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, "AutoClose_Label", OBJPROP_HIDDEN, false);
            
            if(WriteToLog)
                Print("Close marker label created at price: ", labelPrice);
        }
        else
        {
            Print("Failed to create close marker label");
        }
    }
    else
    {
        // Log why marker wasn't created
        if(targetCloseTime == 0)
        {
            if(WriteToLog)
                Print("Close marker not created: No valid close time configured");
        }
        else if(targetCloseTime <= (TimeCurrent() - 3600))
        {
            if(WriteToLog)
                Print("Close marker not created: Target time too far in past (", TimeToString(targetCloseTime), " vs current ", TimeToString(TimeCurrent()), ")");
        }
        
        closeMarkerCreated = false;
    }
}

//+------------------------------------------------------------------+
//| Close position function                                          |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket, string symbol)
{
    // Get position details
    if(!PositionSelectByTicket(ticket)) return false;
    
    double volume = PositionGetDouble(POSITION_VOLUME);
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    
    // Get current price
    MqlTick tick;
    if(!SymbolInfoTick(symbol, tick)) return false;
    
    double closePrice = (type == POSITION_TYPE_BUY) ? tick.bid : tick.ask;
    
    // Create close request
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = symbol;
    request.volume = volume;
    request.price = closePrice;
    request.type = (type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.type_filling = ORDER_FILLING_FOK;
    
    bool success = OrderSend(request, result);
    
    if(!success)
    {
        string errorMsg = StringFormat("Failed to close position #%I64u. Error: %d (%s)",
                                     ticket, result.retcode, GetTradeResultDescription(result.retcode));
        Print(errorMsg);
    }
    
    return success;
}

//+------------------------------------------------------------------+
//| Check if position was already closed                            |
//+------------------------------------------------------------------+
bool IsPositionClosed(ulong ticket)
{
    int size = ArraySize(closedPositions);
    for(int i = 0; i < size; i++)
    {
        if(closedPositions[i] == ticket) return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Add position to closed list                                     |
//+------------------------------------------------------------------+
void AddClosedPosition(ulong ticket)
{
    int size = ArraySize(closedPositions);
    ArrayResize(closedPositions, size + 1);
    closedPositions[size] = ticket;
}

//+------------------------------------------------------------------+
//| Clean closed positions array                                    |
//+------------------------------------------------------------------+
void CleanClosedPositions()
{
    // Since these are closed positions, we can clear the array periodically
    // to prevent it from growing too large
    if(ArraySize(closedPositions) > 100)
    {
        ArrayResize(closedPositions, 0);
        if(WriteToLog) Print("Closed positions array cleared");
    }
}

//+------------------------------------------------------------------+
//| Modify position function                                         |
//+------------------------------------------------------------------+
bool ModifyPosition(ulong ticket, string symbol, double sl, double tp)
{
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = symbol;
    request.sl = sl;
    request.tp = tp;
    
    bool success = OrderSend(request, result);
    
    if(!success)
    {
        string errorMsg = StringFormat("Failed to modify position #%I64u. Error: %d (%s)",
                                     ticket, result.retcode, GetTradeResultDescription(result.retcode));
        Print(errorMsg);
    }
    
    return success;
}

//+------------------------------------------------------------------+
//| Check if position was already processed for SL                  |
//+------------------------------------------------------------------+
bool IsPositionProcessedForSL(ulong ticket)
{
    int size = ArraySize(positionsWithSL);
    for(int i = 0; i < size; i++)
    {
        if(positionsWithSL[i] == ticket) return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Add position to SL processed list                               |
//+------------------------------------------------------------------+
void AddPositionWithSL(ulong ticket)
{
    int size = ArraySize(positionsWithSL);
    ArrayResize(positionsWithSL, size + 1);
    positionsWithSL[size] = ticket;
}

//+------------------------------------------------------------------+
//| Clean positions with SL array (remove closed ones)             |
//+------------------------------------------------------------------+
void CleanPositionsWithSL()
{
    ulong tempArray[];
    int tempSize = 0;
    
    int size = ArraySize(positionsWithSL);
    ArrayResize(tempArray, size);
    
    for(int i = 0; i < size; i++)
    {
        // Check if position still exists
        if(PositionSelectByTicket(positionsWithSL[i]))
        {
            tempArray[tempSize] = positionsWithSL[i];
            tempSize++;
        }
    }
    
    // Update the array
    ArrayResize(positionsWithSL, tempSize);
    for(int i = 0; i < tempSize; i++)
    {
        positionsWithSL[i] = tempArray[i];
    }
}

//+------------------------------------------------------------------+
//| Check if position was already processed                         |
//+------------------------------------------------------------------+
bool IsPositionProcessed(ulong ticket)
{
    int size = ArraySize(processedPositions);
    for(int i = 0; i < size; i++)
    {
        if(processedPositions[i] == ticket) return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Add position to processed list                                   |
//+------------------------------------------------------------------+
void AddProcessedPosition(ulong ticket)
{
    int size = ArraySize(processedPositions);
    ArrayResize(processedPositions, size + 1);
    processedPositions[size] = ticket;
}

//+------------------------------------------------------------------+
//| Clean processed positions (remove closed ones)                  |
//+------------------------------------------------------------------+
void CleanProcessedPositions()
{
    ulong tempArray[];
    int tempSize = 0;
    
    int size = ArraySize(processedPositions);
    ArrayResize(tempArray, size);
    
    for(int i = 0; i < size; i++)
    {
        // Check if position still exists
        if(PositionSelectByTicket(processedPositions[i]))
        {
            tempArray[tempSize] = processedPositions[i];
            tempSize++;
        }
    }
    
    // Update the array
    ArrayResize(processedPositions, tempSize);
    for(int i = 0; i < tempSize; i++)
    {
        processedPositions[i] = tempArray[i];
    }
}

//+------------------------------------------------------------------+
//| Get trade result description                                      |
//+------------------------------------------------------------------+
string GetTradeResultDescription(uint retcode)
{
    switch(retcode)
    {
        case TRADE_RETCODE_REQUOTE: return "Requote";
        case TRADE_RETCODE_REJECT: return "Request rejected";
        case TRADE_RETCODE_CANCEL: return "Request canceled";
        case TRADE_RETCODE_PLACED: return "Order placed";
        case TRADE_RETCODE_DONE: return "Request completed";
        case TRADE_RETCODE_DONE_PARTIAL: return "Request partially completed";
        case TRADE_RETCODE_ERROR: return "Request processing error";
        case TRADE_RETCODE_TIMEOUT: return "Request timeout";
        case TRADE_RETCODE_INVALID: return "Invalid request";
        case TRADE_RETCODE_INVALID_VOLUME: return "Invalid volume";
        case TRADE_RETCODE_INVALID_PRICE: return "Invalid price";
        case TRADE_RETCODE_INVALID_STOPS: return "Invalid stops";
        case TRADE_RETCODE_TRADE_DISABLED: return "Trade disabled";
        case TRADE_RETCODE_MARKET_CLOSED: return "Market closed";
        case TRADE_RETCODE_NO_MONEY: return "No money";
        case TRADE_RETCODE_PRICE_CHANGED: return "Price changed";
        case TRADE_RETCODE_PRICE_OFF: return "Off quotes";
        case TRADE_RETCODE_INVALID_EXPIRATION: return "Invalid expiration";
        case TRADE_RETCODE_ORDER_CHANGED: return "Order changed";
        case TRADE_RETCODE_TOO_MANY_REQUESTS: return "Too many requests";
        case TRADE_RETCODE_NO_CHANGES: return "No changes";
        case TRADE_RETCODE_SERVER_DISABLES_AT: return "Autotrading disabled by server";
        case TRADE_RETCODE_CLIENT_DISABLES_AT: return "Autotrading disabled by client";
        case TRADE_RETCODE_LOCKED: return "Request locked";
        case TRADE_RETCODE_FROZEN: return "Order/position frozen";
        case TRADE_RETCODE_INVALID_FILL: return "Invalid fill";
        case TRADE_RETCODE_CONNECTION: return "No connection";
        case TRADE_RETCODE_ONLY_REAL: return "Only real accounts allowed";
        case TRADE_RETCODE_LIMIT_ORDERS: return "Limit exceeded";
        case TRADE_RETCODE_LIMIT_VOLUME: return "Volume limit exceeded";
        default: return "Unknown error";
    }
}
//+------------------------------------------------------------------+
//| Check and apply trailing stop logic                             |
//+------------------------------------------------------------------+
void CheckTrailingStop()
{
    // Get current market price for the current symbol
    MqlTick tick;
    if(!SymbolInfoTick(_Symbol, tick)) return;
    
    double currentPrice = tick.bid;
    
    // Check if trailing stop should be activated
    if(!trailingStopActivated)
    {
        // For sell positions, activate when price reaches trigger level
        // For buy positions, activate when price reaches trigger level  
        // We'll check each position type individually
        
        int totalPositions = PositionsTotal();
        for(int i = 0; i < totalPositions; i++)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket <= 0) continue;
            
            string symbol = PositionGetString(POSITION_SYMBOL);
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            // Skip if UseOnlyCurrentSymbol is true and symbol doesn't match
            if(UseOnlyCurrentSymbol && symbol != _Symbol) continue;
            
            // Get current price for this symbol
            MqlTick symbolTick;
            if(!SymbolInfoTick(symbol, symbolTick)) continue;
            
            double symbolCurrentPrice = (type == POSITION_TYPE_BUY) ? symbolTick.bid : symbolTick.ask;
            
            // Check activation conditions
            bool shouldActivate = false;
            if(type == POSITION_TYPE_SELL && symbolCurrentPrice <= TrailingTriggerPrice)
            {
                shouldActivate = true;
                if(WriteToLog)
                    Print("Trailing stop activated for SELL positions: Price ", symbolCurrentPrice, " reached trigger ", TrailingTriggerPrice);
            }
            else if(type == POSITION_TYPE_BUY && symbolCurrentPrice >= TrailingTriggerPrice)
            {
                shouldActivate = true;
                if(WriteToLog)
                    Print("Trailing stop activated for BUY positions: Price ", symbolCurrentPrice, " reached trigger ", TrailingTriggerPrice);
            }
            
            if(shouldActivate)
            {
                trailingStopActivated = true;
                lastTrailingCheckPrice = symbolCurrentPrice;
                
                // Add all qualifying positions to trailing management
                AddAllPositionsToTrailing();
                
                string message = StringFormat("Trailing stop activated at price %.5f (trigger: %.5f)", 
                                            symbolCurrentPrice, TrailingTriggerPrice);
                if(WriteToLog) Print(message);
                if(ShowAlerts) Alert(message);
                if(SendNotifications) SendNotification(message);
                break;
            }
        }
    }
    
    // If trailing is activated, manage all positions and check for deactivation
    if(trailingStopActivated)
    {
        ManageTrailingStops();
        CheckTrailingStopDeactivation(); // Check if trailing should be deactivated
    }
}

//+------------------------------------------------------------------+
//| Add all open positions to trailing management                   |
//+------------------------------------------------------------------+
void AddAllPositionsToTrailing()
{
    int totalPositions = PositionsTotal();
    ArrayResize(trailingManagedPositions, 0);
    
    for(int i = 0; i < totalPositions; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        string symbol = PositionGetString(POSITION_SYMBOL);
        
        // Skip if UseOnlyCurrentSymbol is true and symbol doesn't match
        if(UseOnlyCurrentSymbol && symbol != _Symbol) continue;
        
        AddTrailingManagedPosition(ticket);
        
        if(WriteToLog)
            Print("Position #", ticket, " (", symbol, ") added to trailing stop management");
    }
}

//+------------------------------------------------------------------+
//| Manage trailing stops for all managed positions                 |
//+------------------------------------------------------------------+
void ManageTrailingStops()
{
    int managedCount = ArraySize(trailingManagedPositions);
    
    for(int i = 0; i < managedCount; i++)
    {
        ulong ticket = trailingManagedPositions[i];
        if(ticket <= 0) continue;
        
        // Check if position still exists
        if(!PositionSelectByTicket(ticket)) continue;
        
        string symbol = PositionGetString(POSITION_SYMBOL);
        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentTP = PositionGetDouble(POSITION_TP);
        
        // Get current market price
        MqlTick tick;
        if(!SymbolInfoTick(symbol, tick)) continue;
        
        double currentPrice = (type == POSITION_TYPE_BUY) ? tick.bid : tick.ask;
        double pointSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        
        // Calculate new trailing stop level
        double newSL = 0;
        bool shouldUpdate = false;
        
        if(type == POSITION_TYPE_BUY)
        {
            // For BUY positions: SL trails below current price
            newSL = NormalizeDouble(currentPrice - (TrailingStopPoints * pointSize), digits);
            
            // Only update if new SL is better than current SL (protects existing breakeven/initial SL)
            if(currentSL == 0)
            {
                shouldUpdate = true;
            }
            else if(newSL > currentSL)
            {
                double slDifference = (newSL - currentSL) / pointSize;
                if(slDifference >= TrailingStepPoints)
                    shouldUpdate = true;
            }
        }
        else // POSITION_TYPE_SELL
        {
            // For SELL positions: SL trails above current price
            newSL = NormalizeDouble(currentPrice + (TrailingStopPoints * pointSize), digits);
            
            // Only update if new SL is better than current SL (protects existing breakeven/initial SL)
            if(currentSL == 0)
            {
                shouldUpdate = true;
            }
            else if(newSL < currentSL)
            {
                double slDifference = (currentSL - newSL) / pointSize;
                if(slDifference >= TrailingStepPoints)
                    shouldUpdate = true;
            }
        }
        
        // Additional check: Ensure trailing SL is never worse than breakeven level
        if(shouldUpdate)
        {
            // Calculate breakeven level for comparison
            double breakevenSL = 0;
            if(type == POSITION_TYPE_BUY)
                breakevenSL = NormalizeDouble(openPrice + (AdditionalPoints * pointSize), digits);
            else
                breakevenSL = NormalizeDouble(openPrice - (AdditionalPoints * pointSize), digits);
            
            // Ensure trailing SL is at least as good as breakeven
            if(type == POSITION_TYPE_BUY && newSL < breakevenSL)
                newSL = breakevenSL;
            else if(type == POSITION_TYPE_SELL && newSL > breakevenSL)
                newSL = breakevenSL;
            
            // Recheck if modification is still needed after adjustment
            if(type == POSITION_TYPE_BUY)
                shouldUpdate = (newSL > currentSL + (TrailingStepPoints * pointSize));
            else
                shouldUpdate = (newSL < currentSL - (TrailingStepPoints * pointSize));
        }
        
        // Apply trailing stop if conditions are met
        if(shouldUpdate)
        {
            if(ModifyPosition(ticket, symbol, newSL, currentTP))
            {
                double profitPoints = 0;
                if(type == POSITION_TYPE_BUY)
                    profitPoints = (currentPrice - openPrice) / pointSize;
                else
                    profitPoints = (openPrice - currentPrice) / pointSize;
                
                string message = StringFormat("Trailing stop updated for %s #%I64u: SL %.5f -> %.5f (Price: %.5f, Profit: %.1f pts)",
                                            symbol, ticket, currentSL, newSL, currentPrice, profitPoints);
                
                if(WriteToLog) Print(message);
                // Don't show alerts for every trailing update to avoid spam
                // if(ShowAlerts) Alert(message);
                if(SendNotifications) SendNotification(message);
            }
        }
    }
    
    // Clean up trailing managed positions (remove closed ones)
    CleanTrailingManagedPositions();
}

//+------------------------------------------------------------------+
//| Check if position is in trailing management                     |
//+------------------------------------------------------------------+
bool IsTrailingManagedPosition(ulong ticket)
{
    int size = ArraySize(trailingManagedPositions);
    for(int i = 0; i < size; i++)
    {
        if(trailingManagedPositions[i] == ticket) return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Add position to trailing management                             |
//+------------------------------------------------------------------+
void AddTrailingManagedPosition(ulong ticket)
{
    // Check if already managed
    if(IsTrailingManagedPosition(ticket)) return;
    
    int size = ArraySize(trailingManagedPositions);
    ArrayResize(trailingManagedPositions, size + 1);
    trailingManagedPositions[size] = ticket;
}

//+------------------------------------------------------------------+
//| Clean trailing managed positions (remove closed ones)          |
//+------------------------------------------------------------------+
void CleanTrailingManagedPositions()
{
    ulong tempArray[];
    int tempSize = 0;
    
    int size = ArraySize(trailingManagedPositions);
    ArrayResize(tempArray, size);
    
    for(int i = 0; i < size; i++)
    {
        // Check if position still exists
        if(PositionSelectByTicket(trailingManagedPositions[i]))
        {
            tempArray[tempSize] = trailingManagedPositions[i];
            tempSize++;
        }
    }
    
    // Update the array
    ArrayResize(trailingManagedPositions, tempSize);
    for(int i = 0; i < tempSize; i++)
    {
        trailingManagedPositions[i] = tempArray[i];
    }
    
    // If no positions remain, deactivate trailing stop
    if(tempSize == 0 && trailingStopActivated)
    {
        trailingStopActivated = false;
        if(WriteToLog) Print("All trailing managed positions closed. Trailing stop deactivated.");
    }
}

//+------------------------------------------------------------------+
//| Check if close marker exists and recreate if needed             |
//+------------------------------------------------------------------+
void CheckAndRecreateMarker()
{
    // Only check if auto close is enabled and marker should be shown
    if(!EnableAutoClose || !ShowCloseMarker) return;
    
    // Check if marker objects exist
    bool markerExists = ObjectFind(0, "AutoClose_Marker") >= 0;
    bool labelExists = ObjectFind(0, "AutoClose_Label") >= 0;
    
    // If either marker is missing, recreate both
    if(!markerExists || !labelExists)
    {
        if(WriteToLog && closeMarkerCreated)
            Print("Close marker missing after timeframe change - recreating...");
        
        closeMarkerCreated = false; // Reset flag to allow recreation
        CreateCloseMarker();
    }
}

//+------------------------------------------------------------------+
//| Chart event handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
    // Handle chart events that might affect marker visibility
    if(id == CHARTEVENT_CHART_CHANGE)
    {
        // Chart properties changed (including timeframe)
        if(EnableAutoClose && ShowCloseMarker)
        {
            if(WriteToLog)
                Print("Chart change detected - checking marker visibility...");
            
            // Force marker recreation
            closeMarkerCreated = false;
            CreateCloseMarker();
        }
    }
}

//+------------------------------------------------------------------+
//| Check if trailing stop should be deactivated                    |
//+------------------------------------------------------------------+
void CheckTrailingStopDeactivation()
{
    if(!trailingStopActivated) return;
    
    // Check if price has moved back beyond trigger level
    int totalPositions = PositionsTotal();
    bool shouldDeactivate = false;
    
    for(int i = 0; i < totalPositions; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        string symbol = PositionGetString(POSITION_SYMBOL);
        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        
        // Skip if UseOnlyCurrentSymbol is true and symbol doesn't match
        if(UseOnlyCurrentSymbol && symbol != _Symbol) continue;
        
        // Only check managed positions
        if(!IsTrailingManagedPosition(ticket)) continue;
        
        // Get current price for this symbol
        MqlTick symbolTick;
        if(!SymbolInfoTick(symbol, symbolTick)) continue;
        
        double symbolCurrentPrice = (type == POSITION_TYPE_BUY) ? symbolTick.bid : symbolTick.ask;
        
        // Check deactivation conditions (price moved back beyond trigger)
        if(type == POSITION_TYPE_SELL && symbolCurrentPrice > TrailingTriggerPrice)
        {
            shouldDeactivate = true;
            if(WriteToLog)
                Print("Trailing stop should deactivate for SELL positions: Price ", symbolCurrentPrice, " moved back above trigger ", TrailingTriggerPrice);
            break;
        }
        else if(type == POSITION_TYPE_BUY && symbolCurrentPrice < TrailingTriggerPrice)
        {
            shouldDeactivate = true;
            if(WriteToLog)
                Print("Trailing stop should deactivate for BUY positions: Price ", symbolCurrentPrice, " moved back below trigger ", TrailingTriggerPrice);
            break;
        }
    }
    
    // Deactivate trailing stop if conditions are met
    if(shouldDeactivate)
    {
        trailingStopActivated = false;
        
        // Remove all positions from trailing management but keep their current SL
        ArrayResize(trailingManagedPositions, 0);
        
        string message = StringFormat("Trailing stop deactivated: Price moved back beyond trigger level %.5f", TrailingTriggerPrice);
        if(WriteToLog) Print(message);
        if(ShowAlerts) Alert(message);
        if(SendNotifications) SendNotification(message);
        
        if(WriteToLog) Print("Positions retain their current SL levels. Breakeven and Initial SL systems resume normal operation.");
    }
}
//+------------------------------------------------------------------+
