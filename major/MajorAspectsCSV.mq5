//+------------------------------------------------------------------+
//|                                            MajorAspectsCSV.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

//--- PERFORMANCE OPTIMIZATION INPUTS
input bool PerformanceMode = true;         // Enable performance optimization (reduces aspects)
input int MaxAspectsToShow = 1000;          // Maximum aspects to display (INCREASED LIMIT)
input bool SmartTimeFiltering = true;      // Use smart time filtering for visible chart area
input int UpdateIntervalBars = 10;         // Update aspects every N bars for performance
input bool PrioritizeByImportance = true;  // Show important aspects first (conjunctions, squares, oppositions)

// Input parameters
input string CSVFileName = "complete_major_aspects.csv"; // CSV file name
input int CSVTimezoneOffset = 0;        // CSV timezone offset from UTC (0=Greek time matches broker, 2=EET, 3=EEST, 8=SGT)

//--- ASPECT TYPE TOGGLES (ordered by importance for performance)
input bool ShowConjunction = true;      // Show Conjunction aspects (HIGHEST PRIORITY)
input bool ShowSquare = true;           // Show Square aspects (HIGH PRIORITY)
input bool ShowOpposition = true;       // Show Opposition aspects (HIGH PRIORITY)
input bool ShowSemisquare = true;       // Show Semisquare (45°) aspects (HIGH PRIORITY - IMPORTANT TO USER)
input bool ShowGann104 = true;          // Show Gann 104° aspects (HIGH PRIORITY - IMPORTANT TO USER)
input bool ShowGann192 = true;          // Show Gann 192° aspects (HIGH PRIORITY - IMPORTANT TO USER)
input bool ShowTrine = true;            // Show Trine aspects (MEDIUM PRIORITY)
input bool ShowSextile = true;          // Show Sextile aspects (MEDIUM PRIORITY)

input bool ShowAllAspects = false;      // Show all aspects regardless of time range (PERFORMANCE IMPACT)

// Planet group filters - NEW TOGGLE OPTIONS (optimized for performance)
input bool ShowLuminaries = true;       // Show Sun & Moon aspects (MOST FREQUENT - HIGH PRIORITY)
input bool ShowFastPlanets = true;      // Show Mercury, Venus, Mars aspects (MEDIUM PRIORITY)
input bool ShowSlowPlanets = false;     // Show Jupiter-Pluto aspects (DISABLED FOR PERFORMANCE)

input int LookAheadDays = 90;           // Days to look ahead (reduced from 365 for performance)
input int LookBackDays = 365;          // Days to look back (reduced from 1825 for performance)

// Aspect colors with improved visibility
input color ConjunctionColor = clrYellow;    // Conjunction color
input color SextileColor = clrLime;          // Sextile color
input color SquareColor = clrRed;            // Square color
input color TrineColor = clrBlue;            // Trine color
input color OppositionColor = clrMagenta;    // Opposition color
input color SemisquareColor = clrOrange;     // Semisquare (45°) color
input color Gann104Color = clrCyan;          // Gann 104° color
input color Gann192Color = clrGold;          // Gann 192° color

// Line styles for better distinction
input ENUM_LINE_STYLE ConjunctionStyle = STYLE_SOLID;
input ENUM_LINE_STYLE SextileStyle = STYLE_DOT;
input ENUM_LINE_STYLE SquareStyle = STYLE_SOLID;
input ENUM_LINE_STYLE TrineStyle = STYLE_DASH;
input ENUM_LINE_STYLE OppositionStyle = STYLE_SOLID;
input ENUM_LINE_STYLE SemisquareStyle = STYLE_DASHDOT;
input ENUM_LINE_STYLE Gann104Style = STYLE_DASHDOTDOT;
input ENUM_LINE_STYLE Gann192Style = STYLE_DASHDOTDOT;

// Line widths
input int LineWidth = 2;

// Text settings
input int FontSize = 8;
input color TextColor = clrWhite;

struct AspectData
{
    datetime time;
    string planet1;
    string planet2;
    string aspect;
    string aspect_abbrev;
    double angle;
    double planet1_lon;
    double planet2_lon;
    string description;
};

AspectData aspects[];
int aspectCount = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== MAJOR ASPECTS CSV INDICATOR STARTING ===");
    Print("PERFORMANCE MODE: ", PerformanceMode ? "ENABLED" : "DISABLED");
    Print("MAX ASPECTS LIMIT: ", MaxAspectsToShow);
    Print("IMPORTANT: Semisquare & Gann patterns (104°, 192°) are HIGH PRIORITY - enabled by default");
    
    // Load aspects from CSV with error handling
    if(!LoadAspectsFromCSV())
    {
        Print("ERROR: Failed to load aspects from CSV file: ", CSVFileName);
        return INIT_FAILED;
    }
    
    Print("SUCCESS: Loaded ", aspectCount, " aspects from ", CSVFileName);
    
    // Validate array integrity to prevent out-of-range errors
    if(!ValidateArraysAndData())
    {
        Print("ERROR: Array validation failed. Indicator may not work correctly.");
        return INIT_FAILED;
    }
    
    // Check CSV date coverage
    if(aspectCount > 0 && ArraySize(aspects) >= aspectCount)
    {
        // SAFETY: Check bounds before accessing first and last aspects
        datetime firstAspect = aspects[0].time;
        datetime lastAspect = aspects[aspectCount-1].time;
        datetime now = TimeCurrent();
        
        Print("CSV COVERAGE CHECK:");
        Print("- First aspect: ", TimeToString(firstAspect));
        Print("- Last aspect: ", TimeToString(lastAspect));
        Print("- Current time: ", TimeToString(now));
        
        if(now > lastAspect)
        {
            Print(">>> WARNING: CSV DATA IS OUTDATED! <<<");
            Print(">>> Current time is AFTER last aspect in CSV <<<");
            Print(">>> SOLUTION: Regenerate CSV with Python script to include current dates <<<");
            Print(">>> Run: python calculate_aspects.py to update CSV with recent data <<<");
        }
        else if(now < firstAspect)
        {
            Print(">>> WARNING: Current time is BEFORE CSV data range <<<");
        }
        else
        {
            Print(">>> CSV coverage is good - current time is within data range <<<");
        }
    }
    
    Print("");
    // TIMEZONE DEBUGGING: Check current timezone status
    datetime currentTime = TimeCurrent();
    datetime currentGreekTime = GetGreekTime(currentTime);
    string currentTimezone = IsGreekSummerTime(currentTime) ? "EEST (UTC+3)" : "EET (UTC+2)";
    
    Print("TIMEZONE DEBUG:");
    Print("- Current UTC: ", TimeToString(currentTime));
    Print("- Current Greek: ", TimeToString(currentGreekTime), " (", currentTimezone, ")");
    Print("- Current Singapore: ", TimeToString(currentTime + 8 * 3600), " (SGT)");
    Print("- CSV timezone offset: UTC", CSVTimezoneOffset >= 0 ? "+" : "", CSVTimezoneOffset);
    Print("");
    Print("TIMEZONE DIAGNOSIS:");
    Print("- If aspect lines appear BEFORE their SGT time, CSV is likely in SGT (set offset to 8)");
    Print("- If aspect lines appear BEFORE their Greek time, CSV is likely in Greek time (set offset to 2 or 3)");
    Print("- If timing matches UTC perfectly, CSV is in UTC (keep offset at 0)");
    Print("");
    if(CSVTimezoneOffset == 0)
        Print("- CSV data is assumed to be in Greek time (matches broker timezone)");
    else if(CSVTimezoneOffset == 2)
        Print("- CSV data is assumed to be in EET (Greek winter time)");
    else if(CSVTimezoneOffset == 3)
        Print("- CSV data is assumed to be in EEST (Greek summer time)");
    else if(CSVTimezoneOffset == 8)
        Print("- CSV data is assumed to be in SGT (Singapore time)");
    else
        Print("- CSV data is assumed to be in UTC", CSVTimezoneOffset >= 0 ? "+" : "", CSVTimezoneOffset, " timezone");
    
    if(PerformanceMode)
    {
        Print("PERFORMANCE MODE ENABLED:");
        Print("- Will show max ", MaxAspectsToShow, " aspects");
        Print("- Smart filtering enabled: ", SmartTimeFiltering);
        Print("- Update interval: every ", UpdateIntervalBars, " bars");
    }
    else
    {
        Print("PERFORMANCE MODE DISABLED:");
        Print("- Will show ALL aspects that match filters (no limit)");
        Print("- Extended time ranges will be used");
        Print("- Full tooltips will be displayed");
        Print("- May impact performance with large datasets");
    }
    
    // Set up chart for aspect display
    ChartSetInteger(0, CHART_FOREGROUND, false);
    
    // Generate Swiss Ephemeris validation report
    GenerateSwissEphemerisReport();
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Load aspects from CSV file with enhanced error handling         |
//+------------------------------------------------------------------+
bool LoadAspectsFromCSV()
{
    string filename = CSVFileName;
    int file_handle = FileOpen(filename, FILE_READ | FILE_TXT | FILE_ANSI);
    
    if(file_handle == INVALID_HANDLE)
    {
        Print("ERROR: Cannot open CSV file: ", filename);
        Print("Make sure the file exists in: ", TerminalInfoString(TERMINAL_DATA_PATH), "\\MQL5\\Files\\");
        return false;
    }
    
    Print("Successfully opened CSV file: ", filename);
    
    // Skip header line
    string header = FileReadString(file_handle);
    Print("CSV Header: ", header);
    
    aspectCount = 0;
    ArrayResize(aspects, 50000); // Large array to prevent out of bounds
    
    int lineNumber = 1;
    int maxToLoad = 50000; // Large limit to get all data
    
    // PRIORITY: Load aspects closest to current time first
    datetime currentTime = TimeCurrent();
    datetime cutoffTime = currentTime - 365 * 24 * 3600; // Only load aspects from last year
    
    while(!FileIsEnding(file_handle) && aspectCount < maxToLoad)
    {
        lineNumber++;
        
        // Read complete line
        string line = FileReadString(file_handle);
        if(line == "" || StringLen(line) < 10) // Skip empty or very short lines
        {
            continue;
        }
        
        // Split line into fields
        string fields[];
        int fieldCount = StringSplit(line, ',', fields);
        
        if(fieldCount < 10)
        {
            Print("WARNING: Incomplete data at line ", lineNumber, ": only ", fieldCount, " fields found");
            Print("Line content: ", line);
            continue;
        }
        
        // Extract fields
        string date_str = fields[0];
        string time_str = fields[1];
        string planet1 = fields[2];
        string planet2 = fields[3];
        string aspect = fields[4];
        string aspect_abbrev = fields[5];
        string angle_str = fields[6];
        string planet1_lon_str = fields[7];
        string planet2_lon_str = fields[8];
        string description = fields[9];
        
        // Validate required fields
        if(date_str == "" || time_str == "" || planet1 == "" || planet2 == "" || aspect == "")
        {
            Print("WARNING: Missing required fields at line ", lineNumber);
            Print("Line content: ", line);
            continue;
        }
        
        // Parse date and time with enhanced validation
        datetime aspectTime = ParseDateTime(date_str, time_str);
        if(aspectTime == 0)
        {
            Print("ERROR: Invalid date/time at line ", lineNumber, ": ", date_str, ",", time_str);
            Print("Line content: ", line);
            continue;
        }
        
        // Apply CSV timezone offset to convert to UTC if needed
        if(CSVTimezoneOffset != 0)
        {
            aspectTime = aspectTime - (CSVTimezoneOffset * 3600); // Convert to UTC
        }
        
        // Validate numerical values with validation
        double angle = StringToDouble(angle_str);
        double planet1_lon = StringToDouble(planet1_lon_str);
        double planet2_lon = StringToDouble(planet2_lon_str);
        
        if(angle < 0 || angle > 360 || planet1_lon < 0 || planet1_lon > 360 || planet2_lon < 0 || planet2_lon > 360)
        {
            Print("WARNING: Invalid angle/longitude values at line ", lineNumber, ": angle=", angle, ", p1_lon=", planet1_lon, ", p2_lon=", planet2_lon);
        }
        
        // CHECK ARRAY BOUNDS BEFORE STORING
        if(aspectCount >= ArraySize(aspects))
        {
            Print("WARNING: Reached maximum array size (", ArraySize(aspects), "). Stopping loading to prevent crash.");
            break;
        }
        
        // Store aspect data
        aspects[aspectCount].time = aspectTime;
        aspects[aspectCount].planet1 = planet1;
        aspects[aspectCount].planet2 = planet2;
        aspects[aspectCount].aspect = aspect;
        aspects[aspectCount].aspect_abbrev = aspect_abbrev;
        aspects[aspectCount].angle = angle;
        aspects[aspectCount].planet1_lon = planet1_lon;
        aspects[aspectCount].planet2_lon = planet2_lon;
        aspects[aspectCount].description = description;
        
        aspectCount++;
        
        // Debug output for first few aspects
        if(aspectCount <= 3)
        {
            // Add timezone debugging for first few aspects
            datetime greekTime = GetGreekTime(aspectTime);
            datetime singaporeTime = aspectTime + 8 * 3600;
            string timezone = IsGreekSummerTime(aspectTime) ? "EEST (UTC+3)" : "EET (UTC+2)";
            
            Print("Loaded aspect #", aspectCount, ": ");
            if(CSVTimezoneOffset != 0)
            {
                datetime originalTime = aspectTime + (CSVTimezoneOffset * 3600);
                Print("  CSV time: ", TimeToString(originalTime), " (UTC", 
                      CSVTimezoneOffset >= 0 ? "+" : "", CSVTimezoneOffset, ")");
            }
            Print("  UTC: ", TimeToString(aspectTime));
            Print("  Greek: ", TimeToString(greekTime), " (", timezone, ")");
            Print("  Singapore: ", TimeToString(singaporeTime), " (SGT UTC+8)");
            Print("  ", planet1, "-", planet2, " ", aspect, " (", angle, "°)");
            
            // Check if this is the aspect you mentioned
            MqlDateTime dtCheck;
            TimeToStruct(aspectTime, dtCheck);
            if(dtCheck.day == 30 && dtCheck.mon == 6 && dtCheck.year == 2025)
            {
                Print("  >>> THIS IS THE JUNE 30, 2025 ASPECT YOU MENTIONED! <<<");
                Print("  >>> TIMING ANALYSIS:");
                Print("  >>> Aspect UTC time: ", TimeToString(aspectTime));
                Print("  >>> Current UTC time: ", TimeToString(TimeCurrent()));
                Print("  >>> Time difference: ", (TimeCurrent() - aspectTime) / 3600.0, " hours");
                Print("  >>> SGT time shown: ", TimeToString(singaporeTime));
                Print("  >>> Current SGT time: ", TimeToString(TimeCurrent() + 8 * 3600));
                
                if(TimeCurrent() < aspectTime)
                    Print("  >>> STATUS: Aspect is in the FUTURE (line should NOT have passed yet)");
                else
                    Print("  >>> STATUS: Aspect is in the PAST (line should have passed)");
                    
                Print("  >>> DIAGNOSIS: If line passed but it's before 16:00 SGT, your CSV is likely in SGT timezone!");
                Print("  >>> SOLUTION: Try setting CSVTimezoneOffset = 8 (Singapore time)");
            }
        }
    }
    
    FileClose(file_handle);
    
    // Resize array to actual size
    ArrayResize(aspects, aspectCount);
    
    Print("Total aspects loaded: ", aspectCount);
    return aspectCount > 0;
}

//+------------------------------------------------------------------+
//| Enhanced DateTime parsing function                               |
//+------------------------------------------------------------------+
datetime ParseDateTime(string date_str, string time_str)
{
    // Expected format: "2024.01.15" and "12:30"
    
    // Parse date (YYYY.MM.DD)
    string date_parts[];
    if(StringSplit(date_str, '.', date_parts) != 3)
        return 0;
    
    int year = (int)StringToInteger(date_parts[0]);
    int month = (int)StringToInteger(date_parts[1]);
    int day = (int)StringToInteger(date_parts[2]);
    
    // Parse time (HH:MM)
    string time_parts[];
    if(StringSplit(time_str, ':', time_parts) != 2)
        return 0;
    
    int hour = (int)StringToInteger(time_parts[0]);
    int minute = (int)StringToInteger(time_parts[1]);
    
    // Validate ranges
    if(year < 1970 || year > 2100 || month < 1 || month > 12 || 
       day < 1 || day > 31 || hour < 0 || hour > 23 || minute < 0 || minute > 59)
        return 0;
    
    // Create datetime
    MqlDateTime dt;
    dt.year = year;
    dt.mon = month;
    dt.day = day;
    dt.hour = hour;
    dt.min = minute;
    dt.sec = 0;
    
    return StructToTime(dt);
}

//+------------------------------------------------------------------+
//| Get aspect color based on type                                  |
//+------------------------------------------------------------------+
color GetAspectColor(string aspect)
{
    if(aspect == "Conjunction") return ConjunctionColor;
    if(aspect == "Sextile") return SextileColor;
    if(aspect == "Square") return SquareColor;
    if(aspect == "Trine") return TrineColor;
    if(aspect == "Opposition") return OppositionColor;
    if(aspect == "Semisquare") return SemisquareColor;  // Enhanced semisquare support
    if(aspect == "Gann104") return Gann104Color;        // Gann 104° color (fixed name)
    if(aspect == "Gann192") return Gann192Color;        // Gann 192° color (fixed name)
    
    return clrGray; // Default color for unknown aspects
}

//+------------------------------------------------------------------+
//| Get aspect line style                                           |
//+------------------------------------------------------------------+
ENUM_LINE_STYLE GetAspectStyle(string aspect)
{
    if(aspect == "Conjunction") return ConjunctionStyle;
    if(aspect == "Sextile") return SextileStyle;
    if(aspect == "Square") return SquareStyle;
    if(aspect == "Trine") return TrineStyle;
    if(aspect == "Opposition") return OppositionStyle;
    if(aspect == "Semisquare") return SemisquareStyle;  // Enhanced semisquare support
    if(aspect == "Gann104") return Gann104Style;        // Gann 104° style (fixed name)
    if(aspect == "Gann192") return Gann192Style;        // Gann 192° style (fixed name)
    
    return STYLE_SOLID; // Default style
}

//+------------------------------------------------------------------+
//| Get aspect importance for performance prioritization            |
//+------------------------------------------------------------------+
int GetAspectImportance(string aspect)
{
    // Return importance level (1 = highest, 5 = lowest)
    if(aspect == "Conjunction") return 1;      // Most important
    if(aspect == "Square") return 1;           // Most important
    if(aspect == "Opposition") return 1;       // Most important
    if(aspect == "Semisquare") return 2;       // HIGH PRIORITY - Important to user
    if(aspect == "Gann104") return 2;          // HIGH PRIORITY - Important to user
    if(aspect == "Gann192") return 2;          // HIGH PRIORITY - Important to user
    if(aspect == "Trine") return 3;            // Medium importance
    if(aspect == "Sextile") return 4;          // Lower importance
    
    return 5; // Default to lowest importance
}

//+------------------------------------------------------------------+
//| Check if planet belongs to specific group                       |
//+------------------------------------------------------------------+
bool IsPlanetInGroup(string planet, string group)
{
    if(group == "Luminaries")
    {
        return (planet == "Sun" || planet == "Moon");
    }
    else if(group == "Fast")
    {
        return (planet == "Mercury" || planet == "Venus" || planet == "Mars");
    }
    else if(group == "Slow")
    {
        return (planet == "Jupiter" || planet == "Saturn" || planet == "Uranus" || 
                planet == "Neptune" || planet == "Pluto");
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check if aspect should be shown based on planet groups         |
//+------------------------------------------------------------------+
bool ShouldShowPlanetGroup(string planet1, string planet2)
{
    // Determine which groups each planet belongs to
    bool planet1_luminary = IsPlanetInGroup(planet1, "Luminaries");
    bool planet1_fast = IsPlanetInGroup(planet1, "Fast");
    bool planet1_slow = IsPlanetInGroup(planet1, "Slow");
    
    bool planet2_luminary = IsPlanetInGroup(planet2, "Luminaries");
    bool planet2_fast = IsPlanetInGroup(planet2, "Fast");
    bool planet2_slow = IsPlanetInGroup(planet2, "Slow");
    
    // Check if this aspect should be shown based on enabled groups
    bool showAspect = false;
    
    // LUMINARIES: Show if at least one planet is Sun or Moon (most frequent timing)
    if(ShowLuminaries && (planet1_luminary || planet2_luminary))
        showAspect = true;
    
    // FAST PLANETS: Show aspects between Mercury, Venus, Mars only (mid-term)
    if(ShowFastPlanets && planet1_fast && planet2_fast && !planet1_luminary && !planet2_luminary)
        showAspect = true;
    
    // SLOW PLANETS: Show aspects between Jupiter-Pluto only (long-term cycles)
    if(ShowSlowPlanets && planet1_slow && planet2_slow && !planet1_luminary && !planet2_luminary)
        showAspect = true;
    
    return showAspect;
}

//+------------------------------------------------------------------+
//| Check if aspect should be shown                                 |
//+------------------------------------------------------------------+
bool ShouldShowAspect(string aspect)
{
    if(aspect == "Conjunction") return ShowConjunction;
    if(aspect == "Sextile") return ShowSextile;
    if(aspect == "Square") return ShowSquare;
    if(aspect == "Trine") return ShowTrine;
    if(aspect == "Opposition") return ShowOpposition;
    if(aspect == "Semisquare") return ShowSemisquare;  // Enhanced semisquare support
    if(aspect == "Gann104") return ShowGann104;        // Gann 104° aspect visibility (fixed name)
    if(aspect == "Gann192") return ShowGann192;        // Gann 192° aspect visibility (fixed name)
    
    return false; // Don't show unknown aspects
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function (PERFORMANCE OPTIMIZED)    |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    // SAFETY: Check if aspects are loaded
    if(aspectCount <= 0 || ArraySize(aspects) == 0)
    {
        static int warnCounter = 0;
        if(warnCounter % 100 == 0) // Warn every 100 calls to avoid spam
        {
            Print("WARNING: No aspects loaded. Cannot display any aspect lines.");
            Print("Solution: Check CSV file and reload indicator.");
        }
        warnCounter++;
        return rates_total;
    }
    
    // PERFORMANCE: Only update every N bars if performance mode is enabled
    static int last_update_bar = 0;
    if(PerformanceMode && (rates_total - last_update_bar) < UpdateIntervalBars)
    {
        return rates_total;
    }
    last_update_bar = rates_total;
    
    // Clear previous objects (performance optimized)
    ObjectsDeleteAll(0, "ASPECT_");
    
    datetime startTime, endTime;
    
    if(ShowAllAspects)
    {
        // Show all aspects regardless of time range (PERFORMANCE IMPACT WARNING)
        startTime = D'1970.01.01 00:00:00';
        endTime = D'2100.12.31 23:59:59';
        Print("WARNING: Showing ALL aspects - this may impact performance!");
    }
    else
    {
        // PERFORMANCE: Use smart time filtering based on visible chart area
        datetime chartStartTime, chartEndTime;
        
        if(SmartTimeFiltering && PerformanceMode)
        {
            // Get current chart time range for better performance
            long firstVisibleBar = ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
            long lastVisibleBar = ChartGetInteger(0, CHART_VISIBLE_BARS);
            
            // SAFETY: Check if we have chart data before calculating indices
            if(rates_total > 0)
            {
                // Calculate chart time range from visible bars - fix array bounds
                int startIndex = MathMax(0, (int)(rates_total - firstVisibleBar - lastVisibleBar));
                int endIndex = MathMax(0, rates_total - 1);
                
                // Ensure indices are within bounds
                if(startIndex >= rates_total) startIndex = rates_total - 1;
                if(endIndex >= rates_total) endIndex = rates_total - 1;
                if(startIndex < 0) startIndex = 0;
                if(endIndex < 0) endIndex = 0;
                
                // Additional safety check: ensure we have valid indices
                if(startIndex < rates_total && endIndex < rates_total)
                {
                    chartStartTime = time[startIndex];
                    chartEndTime = time[endIndex];
                }
                else
                {
                    // Fallback to current time if indices are invalid
                    datetime currentTime = TimeCurrent();
                    chartStartTime = currentTime - 24 * 3600;
                    chartEndTime = currentTime + 24 * 3600;
                    Print("WARNING: Invalid chart indices, using fallback time range");
                }
            }
            else
            {
                // No chart data available
                datetime currentTime = TimeCurrent();
                chartStartTime = currentTime - 24 * 3600;
                chartEndTime = currentTime + 24 * 3600;
                Print("WARNING: No chart data for smart filtering, using fallback time range");
            }
            
            // Use smaller look-ahead/back ranges for performance
            int effectiveLookBack = PerformanceMode ? MathMin(LookBackDays, 90) : LookBackDays;
            int effectiveLookAhead = PerformanceMode ? MathMin(LookAheadDays, 30) : LookAheadDays;
            
            startTime = chartStartTime - effectiveLookBack * 24 * 3600;
            endTime = chartEndTime + effectiveLookAhead * 24 * 3600;
            
            Print("PERFORMANCE: Smart filtering enabled - chart range: ", TimeToString(chartStartTime), " to ", TimeToString(chartEndTime));
        }
        else
        {
            // Standard time range (full range when PerformanceMode is disabled)
            // SAFETY: Check array bounds before accessing
            if(rates_total > 0)
            {
                chartStartTime = time[0];
                chartEndTime = time[rates_total-1];
            }
            else
            {
                // Fallback if no chart data
                datetime currentTime = TimeCurrent();
                chartStartTime = currentTime - 24 * 3600; // 1 day back
                chartEndTime = currentTime + 24 * 3600;   // 1 day forward
                Print("WARNING: No chart data available, using fallback time range");
            }
            
            if(PerformanceMode)
            {
                startTime = chartStartTime - LookBackDays * 24 * 3600;
                endTime = chartEndTime + LookAheadDays * 24 * 3600;
            }
            else
            {
                // When PerformanceMode is disabled, use extended time range for more aspects
                startTime = chartStartTime - (LookBackDays * 2) * 24 * 3600;  // Double the lookback
                endTime = chartEndTime + (LookAheadDays * 2) * 24 * 3600;     // Double the lookahead
                Print("PERFORMANCE MODE DISABLED: Using extended time range");
            }
        }
        
        Print("Search time range: ", TimeToString(startTime), " to ", TimeToString(endTime));
    }
    
    // PERFORMANCE: Create priority array for important aspects
    struct PriorityAspect
    {
        int index;
        int importance;
        datetime time;
    };
    PriorityAspect priorityAspects[];
    int priorityCount = 0;
    
    // First pass: collect and prioritize aspects
    for(int i = 0; i < aspectCount; i++)
    {
        // SAFETY: Additional bounds check for aspects array
        if(i >= ArraySize(aspects))
        {
            Print("ERROR: Aspect index ", i, " exceeds array size ", ArraySize(aspects));
            break;
        }
        
        if(aspects[i].time >= startTime && aspects[i].time <= endTime)
        {
            // Check both aspect type AND planet group filters
            if(ShouldShowAspect(aspects[i].aspect) && ShouldShowPlanetGroup(aspects[i].planet1, aspects[i].planet2))
            {
                // SAFETY: Check array resize success
                int newSize = priorityCount + 1;
                if(ArrayResize(priorityAspects, newSize) == newSize)
                {
                    priorityAspects[priorityCount].index = i;
                    priorityAspects[priorityCount].importance = GetAspectImportance(aspects[i].aspect);
                    priorityAspects[priorityCount].time = aspects[i].time;
                    priorityCount++;
                }
                else
                {
                    Print("ERROR: Failed to resize priority aspects array to ", newSize);
                    break;
                }
            }
        }
    }
    
    Print("Found ", priorityCount, " aspects to potentially display");
    
    // DIAGNOSTIC: Check if we have recent aspects
    datetime currentTime = TimeCurrent();
    int recentAspects = 0;
    for(int i = 0; i < priorityCount; i++)
    {
        if(priorityAspects[i].time >= (currentTime - 365 * 24 * 3600)) // Within last year
        {
            recentAspects++;
        }
    }
    
    Print("DIAGNOSTIC: ", recentAspects, " aspects within last year out of ", priorityCount, " total");
    
    // If no recent aspects found, adjust time range to include more current data
    if(recentAspects == 0 && priorityCount > 0)
    {
        Print("WARNING: No recent aspects found. Expanding time range to include current data...");
        endTime = currentTime + LookAheadDays * 24 * 3600;
        startTime = currentTime - LookBackDays * 24 * 3600;
        
        // Re-collect aspects with expanded range
        priorityCount = 0;
        ArrayResize(priorityAspects, 0);
        
        for(int i = 0; i < aspectCount; i++)
        {
            // SAFETY: Additional bounds check for aspects array
            if(i >= ArraySize(aspects))
            {
                Print("ERROR: Aspect index ", i, " exceeds array size ", ArraySize(aspects), " in expanded range");
                break;
            }
            
            if(aspects[i].time >= startTime && aspects[i].time <= endTime)
            {
                if(ShouldShowAspect(aspects[i].aspect) && ShouldShowPlanetGroup(aspects[i].planet1, aspects[i].planet2))
                {
                    // SAFETY: Check array resize success
                    int newSize = priorityCount + 1;
                    if(ArrayResize(priorityAspects, newSize) == newSize)
                    {
                        priorityAspects[priorityCount].index = i;
                        priorityAspects[priorityCount].importance = GetAspectImportance(aspects[i].aspect);
                        priorityAspects[priorityCount].time = aspects[i].time;
                        priorityCount++;
                    }
                    else
                    {
                        Print("ERROR: Failed to resize priority aspects array to ", newSize, " in expanded range");
                        break;
                    }
                }
            }
        }
        Print("EXPANDED RANGE: Found ", priorityCount, " aspects in range ", TimeToString(startTime), " to ", TimeToString(endTime));
    }
    
    // PERFORMANCE: Sort by importance if enabled
    if(PrioritizeByImportance && PerformanceMode)
    {
        // Simple bubble sort by importance (lower number = higher importance)
        for(int i = 0; i < priorityCount - 1; i++)
        {
            for(int j = 0; j < priorityCount - i - 1; j++)
            {
                if(priorityAspects[j].importance > priorityAspects[j + 1].importance)
                {
                    // Swap
                    PriorityAspect temp = priorityAspects[j];
                    priorityAspects[j] = priorityAspects[j + 1];
                    priorityAspects[j + 1] = temp;
                }
            }
        }
        Print("PERFORMANCE: Sorted aspects by importance");
    }
    
    // PERFORMANCE: Limit number of aspects to draw
    int maxToDraw;
    if(PerformanceMode)
    {
        maxToDraw = MathMin(MaxAspectsToShow, priorityCount);
    }
    else
    {
        // When performance mode is disabled, show ALL filtered aspects (no limit)
        maxToDraw = priorityCount;
        Print("PERFORMANCE MODE DISABLED: Will show ALL ", priorityCount, " aspects (no limit)");
    }
    
    int drawnAspects = 0;
    
    // Second pass: draw the selected aspects
    for(int i = 0; i < maxToDraw && (PerformanceMode ? drawnAspects < MaxAspectsToShow : true); i++)
    {
        // SAFETY: Check bounds for priority aspects array
        if(i >= ArraySize(priorityAspects))
        {
            Print("ERROR: Priority aspect index ", i, " exceeds array size ", ArraySize(priorityAspects));
            break;
        }
        
        int aspectIndex = priorityAspects[i].index;
        
        // SAFETY: Check bounds for main aspects array
        if(aspectIndex < 0 || aspectIndex >= ArraySize(aspects))
        {
            Print("ERROR: Aspect index ", aspectIndex, " is out of bounds (0-", ArraySize(aspects)-1, ")");
            continue;
        }
        
        DrawAspectLine(aspects[aspectIndex], drawnAspects);
        drawnAspects++;
        
        // Debug first few drawn aspects
        if(drawnAspects <= 3)
        {
            Print("Drawing priority aspect #", drawnAspects, ": ", TimeToString(aspects[aspectIndex].time), " ", 
                  aspects[aspectIndex].planet1, "-", aspects[aspectIndex].planet2, " ", aspects[aspectIndex].aspect,
                  " (importance: ", priorityAspects[i].importance, ")");
        }
        
        // Special logging for Semisquare and Gann patterns
        if(aspects[aspectIndex].aspect == "Semisquare" || aspects[aspectIndex].aspect == "Gann104" || aspects[aspectIndex].aspect == "Gann192")
        {
            if(drawnAspects <= 10) // Show more of these important aspects in log
            {
                Print("IMPORTANT ASPECT #", drawnAspects, ": ", aspects[aspectIndex].aspect, " ", 
                      TimeToString(aspects[aspectIndex].time), " ", aspects[aspectIndex].planet1, "-", aspects[aspectIndex].planet2);
            }
        }
    }
    
    Print("PERFORMANCE SUMMARY:");
    Print("- Aspects in time range: ", priorityCount);
    Print("- Drawn aspects: ", drawnAspects, " (limit: ", MaxAspectsToShow, ")");
    Print("- Semisquare & Gann patterns prioritized as requested");
    
    // DIAGNOSTIC: Show time range of drawn aspects
    if(drawnAspects > 0 && priorityCount > 0)
    {
        // SAFETY: Check bounds before accessing priority aspects for diagnostics
        if(0 < ArraySize(priorityAspects) && (drawnAspects-1) < ArraySize(priorityAspects))
        {
            int firstIndex = priorityAspects[0].index;
            int lastIndex = priorityAspects[drawnAspects-1].index;
            
            // SAFETY: Check bounds for aspect indices
            if(firstIndex >= 0 && firstIndex < ArraySize(aspects) && 
               lastIndex >= 0 && lastIndex < ArraySize(aspects))
            {
                datetime firstDrawn = aspects[firstIndex].time;
                datetime lastDrawn = aspects[lastIndex].time;
                Print("- Drawn aspect time range: ", TimeToString(firstDrawn), " to ", TimeToString(lastDrawn));
            }
            else
            {
                Print("- WARNING: Invalid aspect indices for time range diagnostic");
            }
        }
        else
        {
            Print("- WARNING: Priority aspects array out of bounds for diagnostic");
        }
    }
    else
    {
        Print("- WARNING: NO ASPECTS DRAWN! Check time range and CSV data.");
        Print("- Current time: ", TimeToString(TimeCurrent()));
        Print("- Search range was: ", TimeToString(startTime), " to ", TimeToString(endTime));
    }
    
    if(PerformanceMode)
    {
        Print("- Performance status: ", (drawnAspects < MaxAspectsToShow * 0.8) ? "GOOD" : "NEAR LIMIT");
        if(drawnAspects >= MaxAspectsToShow)
        {
            Print("- TIP: Increase MaxAspectsToShow for more Semisquare/Gann visibility");
        }
    }
    
    // Update chart display
    ChartRedraw(0);
    
    return rates_total;
}

//+------------------------------------------------------------------+
//| Draw aspect line with enhanced accuracy (PERFORMANCE OPTIMIZED)|
//+------------------------------------------------------------------+
void DrawAspectLine(AspectData &aspect, int index)
{
    string objectName = "ASPECT_" + IntegerToString(index);
    
    // CSV is in Greek time, broker is in Greek time - use directly!
    datetime chartTime = aspect.time;  // No conversion needed
    
    if(ObjectCreate(0, objectName, OBJ_VLINE, 0, chartTime, 0))
    {
        ObjectSetInteger(0, objectName, OBJPROP_COLOR, GetAspectColor(aspect.aspect));
        ObjectSetInteger(0, objectName, OBJPROP_STYLE, GetAspectStyle(aspect.aspect));
        ObjectSetInteger(0, objectName, OBJPROP_WIDTH, LineWidth);
        ObjectSetInteger(0, objectName, OBJPROP_BACK, true);
        
        // PERFORMANCE: Simplified tooltip for better performance
        if(!PerformanceMode)
        {
            // CSV is in Greek time, convert to UTC and SGT for tooltip display
            datetime greekTime = aspect.time;  // CSV is already in Greek time
            datetime utcTime = greekTime - GetGreekUtcOffset(greekTime) * 3600;  // Greek -> UTC
            datetime singaporeTime = utcTime + 8 * 3600;  // UTC -> SGT
            
            string greekTimezone = IsGreekSummerTime(greekTime) ? "EEST" : "EET";
            
            string tooltip = StringFormat("%s %s-%s %s\nUTC: %s\n%s: %s\nSGT: %s\nAngle: %.4f°\n%s: %.4f°\n%s: %.4f°",
                                        TimeToString(greekTime, TIME_DATE),
                                        aspect.planet1, aspect.planet2, aspect.aspect,
                                        TimeToString(utcTime, TIME_MINUTES),
                                        greekTimezone, TimeToString(greekTime, TIME_MINUTES),
                                        TimeToString(singaporeTime, TIME_MINUTES),
                                        aspect.angle,
                                        aspect.planet1, aspect.planet1_lon,
                                        aspect.planet2, aspect.planet2_lon);
            
            ObjectSetString(0, objectName, OBJPROP_TOOLTIP, tooltip);
        }
        else
        {
            // Simplified tooltip for performance
            datetime greekTime = aspect.time;  // CSV is already in Greek time
            datetime utcTime = greekTime - GetGreekUtcOffset(greekTime) * 3600;  // Greek -> UTC
            datetime singaporeTime = utcTime + 8 * 3600;  // UTC -> SGT
            
            string greekTimezone = IsGreekSummerTime(greekTime) ? "EEST" : "EET";
            
            string tooltip = StringFormat("%s %s-%s %s\nUTC: %s\n%s: %s\nSGT: %s\nAngle: %.2f°",
                                        TimeToString(greekTime, TIME_DATE),
                                        aspect.planet1, aspect.planet2, aspect.aspect,
                                        TimeToString(utcTime, TIME_MINUTES),
                                        greekTimezone, TimeToString(greekTime, TIME_MINUTES),
                                        TimeToString(singaporeTime, TIME_MINUTES),
                                        aspect.angle);
            
            ObjectSetString(0, objectName, OBJPROP_TOOLTIP, tooltip);
        }
    }
    
    // PERFORMANCE: Only add text labels for important aspects when performance mode is enabled
    bool shouldAddLabel = !PerformanceMode || 
                         (GetAspectImportance(aspect.aspect) <= 3); // Show labels for more aspects including Semisquare/Gann
    
    // SPECIAL: Always show labels for Semisquare and Gann patterns since they're important to user
    if(aspect.aspect == "Semisquare" || aspect.aspect == "Gann104" || aspect.aspect == "Gann192")
    {
        shouldAddLabel = true;
    }
    
    if(shouldAddLabel)
    {
        // Get chart parameters for label positioning
        double chartHigh = ChartGetDouble(0, CHART_PRICE_MAX);
        double chartLow = ChartGetDouble(0, CHART_PRICE_MIN);
        double priceRange = chartHigh - chartLow;
        double linePrice = chartLow + priceRange * 0.5;
        
        // Add text label with aspect abbreviation
        string labelName = objectName + "_LABEL";
        if(ObjectCreate(0, labelName, OBJ_TEXT, 0, chartTime, linePrice))
        {
            ObjectSetString(0, labelName, OBJPROP_TEXT, aspect.aspect_abbrev);
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, TextColor);
            ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, FontSize);
            ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_UPPER);
            
            if(!PerformanceMode)
            {
                // CSV is in Greek time, convert to UTC and SGT for tooltip display
                datetime greekTime = aspect.time;  // CSV is already in Greek time
                datetime utcTime = greekTime - GetGreekUtcOffset(greekTime) * 3600;  // Greek -> UTC
                datetime singaporeTime = utcTime + 8 * 3600;  // UTC -> SGT
                
                string greekTimezone = IsGreekSummerTime(greekTime) ? "EEST" : "EET";
                
                string labelTooltip = StringFormat("%s\n%s-%s %s\nUTC: %s\n%s: %s\nSGT: %s\n%.4f° (Target: %s)\nPrecision: ±%.4f°",
                                                 TimeToString(greekTime, TIME_DATE),
                                                 aspect.planet1, aspect.planet2, aspect.aspect,
                                                 TimeToString(utcTime, TIME_MINUTES),
                                                 greekTimezone, TimeToString(greekTime, TIME_MINUTES),
                                                 TimeToString(singaporeTime, TIME_MINUTES),
                                                 aspect.angle,
                                                 GetTargetAngleText(aspect.aspect),
                                                 GetAnglePrecision(aspect.aspect, aspect.angle));
                
                ObjectSetString(0, labelName, OBJPROP_TOOLTIP, labelTooltip);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Get target angle text for aspect                                |
//+------------------------------------------------------------------+
string GetTargetAngleText(string aspect)
{
    if(aspect == "Conjunction") return "0°";
    if(aspect == "Semisquare") return "45°";
    if(aspect == "Sextile") return "60°";
    if(aspect == "Square") return "90°";
    if(aspect == "Trine") return "120°";
    if(aspect == "Opposition") return "180°";
    if(aspect == "Gann104") return "104°";    // Gann 104° target angle
    if(aspect == "Gann192") return "192°";    // Gann 192° target angle
    return "?°";
}

//+------------------------------------------------------------------+
//| Calculate angle precision (deviation from exact aspect)         |
//+------------------------------------------------------------------+
double GetAnglePrecision(string aspect, double actualAngle)
{
    double targetAngle = 0;
    
    if(aspect == "Conjunction") targetAngle = 0;
    else if(aspect == "Semisquare") targetAngle = 45;
    else if(aspect == "Sextile") targetAngle = 60;
    else if(aspect == "Square") targetAngle = 90;
    else if(aspect == "Trine") targetAngle = 120;
    else if(aspect == "Opposition") targetAngle = 180;
    else if(aspect == "Gann104") targetAngle = 104;  // Gann 104° precision
    else if(aspect == "Gann192") targetAngle = 192;  // Gann 192° precision
    
    double precision = MathAbs(actualAngle - targetAngle);
    
    // Handle special case for conjunction (can be near 0 or 360)
    if(aspect == "Conjunction")
    {
        double precision360 = MathAbs(actualAngle - 360);
        precision = MathMin(precision, precision360);
    }
    
    return precision;
}

//+------------------------------------------------------------------+
//| Indicator deinitialization function (PERFORMANCE OPTIMIZED)    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up all aspect objects efficiently
    ObjectsDeleteAll(0, "ASPECT_");
    
    // Only redraw if not shutting down for performance
    if(reason != REASON_CHARTCLOSE && reason != REASON_REMOVE)
    {
        ChartRedraw(0);
    }
    
    Print("Major Aspects CSV Indicator deinitialized. Reason: ", reason);
    if(PerformanceMode)
    {
        Print("PERFORMANCE: Cleanup completed efficiently");
    }
}

//+------------------------------------------------------------------+
//| Check if given date is in Greek Summer Time (EEST)             |
//| Greece follows EU DST rules: Last Sunday in March to Last Sunday in October |
//+------------------------------------------------------------------+
bool IsGreekSummerTime(datetime utcTime)
{
    MqlDateTime dt;
    TimeToStruct(utcTime, dt);
    
    int year = dt.year;
    int month = dt.mon;
    int day = dt.day;
    int hour = dt.hour;
    
    // DST is from last Sunday in March 01:00 UTC to last Sunday in October 01:00 UTC
    
    // Before March or after October = Winter time
    if(month < 3 || month > 10) return false;
    
    // April to September = Summer time
    if(month > 3 && month < 10) return true;
    
    // March: need to check if we're past the last Sunday at 01:00 UTC
    if(month == 3)
    {
        // Find last Sunday of March
        int lastSundayMarch = GetLastSundayOfMonth(year, 3);
        if(day > lastSundayMarch) return true;
        if(day < lastSundayMarch) return false;
        // On the last Sunday, check if it's past 01:00 UTC
        return (hour >= 1);
    }
    
    // October: need to check if we're before the last Sunday at 01:00 UTC
    if(month == 10)
    {
        // Find last Sunday of October
        int lastSundayOctober = GetLastSundayOfMonth(year, 10);
        if(day > lastSundayOctober) return false;
        if(day < lastSundayOctober) return true;
        // On the last Sunday, check if it's before 01:00 UTC
        return (hour < 1);
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get the last Sunday of a given month and year                   |
//+------------------------------------------------------------------+
int GetLastSundayOfMonth(int year, int month)
{
    // Get the last day of the month
    int daysInMonth = 31;
    if(month == 4 || month == 6 || month == 9 || month == 11) daysInMonth = 30;
    else if(month == 2)
    {
        // Check for leap year
        if((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0))
            daysInMonth = 29;
        else
            daysInMonth = 28;
    }
    
    // Start from the last day and work backwards to find Sunday
    for(int day = daysInMonth; day >= 1; day--)
    {
        MqlDateTime dt;
        dt.year = year;
        dt.mon = month;
        dt.day = day;
        dt.hour = 12; // Use noon to avoid timezone issues
        dt.min = 0;
        dt.sec = 0;
        
        datetime testDate = StructToTime(dt);
        
        // Get day of week (0=Sunday, 1=Monday, etc.)
        MqlDateTime testDt;
        TimeToStruct(testDate, testDt);
        
        if(testDt.day_of_week == 0) // Sunday
        {
            return day;
        }
    }
    
    return 31; // Fallback (should not happen)
}

//+------------------------------------------------------------------+
//| Get proper Greek time (accounting for DST)                      |
//+------------------------------------------------------------------+
datetime GetGreekTime(datetime utcTime)
{
    if(IsGreekSummerTime(utcTime))
    {
        return utcTime + 3 * 3600; // UTC + 3 hours (EEST)
    }
    else
    {
        return utcTime + 2 * 3600; // UTC + 2 hours (EET)
    }
}

//+------------------------------------------------------------------+
//| Get Greek UTC offset in hours (for timezone conversion)         |
//+------------------------------------------------------------------+
int GetGreekUtcOffset(datetime utcTime)
{
    if(IsGreekSummerTime(utcTime))
    {
        return 3; // UTC + 3 hours (EEST)
    }
    else
    {
        return 2; // UTC + 2 hours (EET)
    }
}

//+------------------------------------------------------------------+
//| SWISS EPHEMERIS VALIDATION FUNCTIONS                            |
//| These functions help verify timezone and aspect calculations    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Validate Swiss Ephemeris timezone calculations                  |
//| Call this to check if your CSV data matches Swisseph output     |
//+------------------------------------------------------------------+
void ValidateSwissEphemerisTimezone()
{
    Print("=== SWISS EPHEMERIS TIMEZONE VALIDATION ===");
    Print("");
    Print("To verify your CSV timezone is correct, follow these steps:");
    Print("");
    Print("1. FIND A SAMPLE ASPECT from your CSV (preferably recent):");
    Print("   - Look for a conjunction (easiest to verify)");
    Print("   - Note the date, time, planets, and angle");
    Print("");
    Print("2. CALCULATE UTC TIME from your CSV:");
    if(CSVTimezoneOffset == 0)
        Print("   - Your CSV time IS the UTC time (no conversion needed)");
    else if(CSVTimezoneOffset > 0)
        Print("   - Your CSV time MINUS ", CSVTimezoneOffset, " hours = UTC time");
    else
        Print("   - Your CSV time PLUS ", -CSVTimezoneOffset, " hours = UTC time");
    Print("");
    Print("3. CHECK IN SWISS EPHEMERIS:");
    Print("   - Open Swiss Ephemeris software");
    Print("   - Set location to UTC (or Greenwich) timezone");
    Print("   - Navigate to the calculated UTC date/time");
    Print("   - Check if the planet positions match your CSV angles");
    Print("");
    Print("4. VERIFY ANGLES:");
    Print("   - Calculate angle difference between the two planets");
    Print("   - For conjunction: |planet1_lon - planet2_lon| should be ~0°");
    Print("   - For square: |planet1_lon - planet2_lon| should be ~90° or ~270°");
    Print("   - For opposition: |planet1_lon - planet2_lon| should be ~180°");
    Print("");
    Print("5. DIAGNOSIS:");
    Print("   - If angles MATCH: Your timezone setting is CORRECT");
    Print("   - If angles DON'T MATCH: Try different CSVTimezoneOffset values");
    Print("   - Common values: 0 (UTC), 2 (EET), 3 (EEST), 8 (SGT)");
    Print("");
    
    // Show sample calculations for today's aspects
    datetime now = TimeCurrent();
    Print("SAMPLE VALIDATION for current time:");
    Print("Current UTC: ", TimeToString(now));
    
    if(CSVTimezoneOffset != 0)
    {
        datetime csvTime = now + (CSVTimezoneOffset * 3600);
        Print("Equivalent CSV time (UTC", CSVTimezoneOffset >= 0 ? "+" : "", CSVTimezoneOffset, "): ", TimeToString(csvTime));
    }
    
    Print("Greek time: ", TimeToString(GetGreekTime(now)), " (", IsGreekSummerTime(now) ? "EEST" : "EET", ")");
    Print("Singapore time: ", TimeToString(now + 8 * 3600), " (SGT)");
    Print("");
}

//+------------------------------------------------------------------+
//| Calculate angular separation between two longitudes             |
//+------------------------------------------------------------------+
double CalculateAngularSeparation(double lon1, double lon2)
{
    double diff = MathAbs(lon1 - lon2);
    
    // Handle wrap-around (e.g., 359° and 1° are only 2° apart)
    if(diff > 180)
        diff = 360 - diff;
        
    return diff;
}

//+------------------------------------------------------------------+
//| Verify aspect angle calculation                                 |
//+------------------------------------------------------------------+
bool VerifyAspectAngle(string aspectType, double planet1_lon, double planet2_lon, double reportedAngle)
{
    double actualSeparation = CalculateAngularSeparation(planet1_lon, planet2_lon);
    double expectedAngle = 0;
    double tolerance = 5.0; // 5-degree tolerance for aspect orb
    
    // Determine expected angle for aspect type
    if(aspectType == "Conjunction") expectedAngle = 0;
    else if(aspectType == "Semisquare") expectedAngle = 45;
    else if(aspectType == "Sextile") expectedAngle = 60;
    else if(aspectType == "Square") expectedAngle = 90;
    else if(aspectType == "Trine") expectedAngle = 120;
    else if(aspectType == "Opposition") expectedAngle = 180;
    else if(aspectType == "Gann104") expectedAngle = 104;
    else if(aspectType == "Gann192") expectedAngle = 192;
    else return false; // Unknown aspect type
    
    // Check if actual separation matches expected angle within tolerance
    bool isValid = MathAbs(actualSeparation - expectedAngle) <= tolerance;
    
    return isValid;
}

//+------------------------------------------------------------------+
//| Detailed aspect validation for debugging                        |
//+------------------------------------------------------------------+
void ValidateSpecificAspect(AspectData &aspect)
{
    Print("=== DETAILED ASPECT VALIDATION ===");
    Print("Aspect: ", aspect.planet1, "-", aspect.planet2, " ", aspect.aspect);
    Print("CSV Time: ", TimeToString(aspect.time), " UTC");
    Print("Greek Time: ", TimeToString(GetGreekTime(aspect.time)), " (", IsGreekSummerTime(aspect.time) ? "EEST" : "EET", ")");
    Print("Singapore Time: ", TimeToString(aspect.time + 8 * 3600), " (SGT)");
    Print("");
    Print("Planet Longitudes:");
    Print("  ", aspect.planet1, ": ", DoubleToString(aspect.planet1_lon, 4), "°");
    Print("  ", aspect.planet2, ": ", DoubleToString(aspect.planet2_lon, 4), "°");
    Print("");
    
    double actualSeparation = CalculateAngularSeparation(aspect.planet1_lon, aspect.planet2_lon);
    bool isValidAngle = VerifyAspectAngle(aspect.aspect, aspect.planet1_lon, aspect.planet2_lon, aspect.angle);
    
    Print("Angle Analysis:");
    Print("  Reported angle: ", DoubleToString(aspect.angle, 4), "°");
    Print("  Calculated separation: ", DoubleToString(actualSeparation, 4), "°");
    Print("  Aspect type: ", aspect.aspect);
    Print("  Angle validation: ", isValidAngle ? "PASS" : "FAIL");
    
    if(!isValidAngle)
    {
        Print("  WARNING: Angle doesn't match expected aspect type!");
        Print("  This may indicate:");
        Print("  - Incorrect aspect classification in CSV");
        Print("  - Wrong planet longitude values");
        Print("  - Timezone conversion error affecting ephemeris lookup");
    }
    
    Print("");
    Print("SWISS EPHEMERIS CHECK:");
    Print("1. Open Swiss Ephemeris at UTC time: ", TimeToString(aspect.time));
    Print("2. Check ", aspect.planet1, " longitude: should be ~", DoubleToString(aspect.planet1_lon, 2), "°");
    Print("3. Check ", aspect.planet2, " longitude: should be ~", DoubleToString(aspect.planet2_lon, 2), "°");
    Print("4. Verify angle between planets: should be ~", DoubleToString(actualSeparation, 2), "°");
    Print("");
    
    // Swiss Ephemeris command line example for manual verification
    Print("Swiss Ephemeris Command Line Example:");
    MqlDateTime dt;
    TimeToStruct(aspect.time, dt);
    string year = IntegerToString(dt.year);
    string month = IntegerToString(dt.mon);
    string day = IntegerToString(dt.day); 
    string hour = IntegerToString(dt.hour);
    string minute = IntegerToString(dt.min);
    Print("swetest -b", day, ".", month, ".", year, " -ut", hour, ":", minute, " -p0123456789");
    
    Print("=================================");
    Print("");
}

//+------------------------------------------------------------------+
//| Convert Julian Day to readable date (for Swisseph compatibility)|
//+------------------------------------------------------------------+
string JulianDayToString(double jd)
{
    // Approximate conversion (Swiss Ephemeris uses Julian Day numbers)
    // JD 2451545.0 = January 1, 2000, 12:00 UTC
    
    double daysSinceJ2000 = jd - 2451545.0;
    datetime j2000 = D'2000.01.01 12:00:00';
    datetime resultTime = j2000 + (int)(daysSinceJ2000 * 24 * 3600);
    
    return TimeToString(resultTime);
}

//+------------------------------------------------------------------+
//| Get Julian Day for given UTC time (Swisseph format)            |
//+------------------------------------------------------------------+
double GetJulianDay(datetime utcTime)
{
    // Convert MT4/MT5 time to Julian Day Number (as used by Swiss Ephemeris)
    // Reference: January 1, 2000, 12:00 UTC = JD 2451545.0
    
    datetime j2000 = D'2000.01.01 12:00:00';
    double daysDiff = (double)(utcTime - j2000) / (24 * 3600);
    double julianDay = 2451545.0 + daysDiff;
    
    return julianDay;
}

//+------------------------------------------------------------------+
//| Generate Swiss Ephemeris validation report                      |
//+------------------------------------------------------------------+
void GenerateSwissEphemerisReport()
{
    Print("=== SWISS EPHEMERIS VALIDATION REPORT ===");
    Print("Generated: ", TimeToString(TimeCurrent()));
    Print("");
    
    // Validate timezone setting
    ValidateSwissEphemerisTimezone();
    
    // Show timezone conversion examples
    Print("TIMEZONE CONVERSION EXAMPLES:");
    datetime currentTime = TimeCurrent();
    Print("Current UTC: ", TimeToString(currentTime));
    Print("Current SGT: ", TimeToString(currentTime + 8 * 3600));
    Print("Current Greek: ", TimeToString(GetGreekTime(currentTime)));
    Print("");
    
    // Analyze CSV time patterns
    AnalyzeCSVTimePatterns();
    
    // Enhanced diagnosis with current data
    DiagnoseTimezoneWithCurrentData();
    
    // Compare with expected positions
    CompareWithExpectedPositions();
    
    // Find and validate recent aspects for verification
    datetime now = TimeCurrent();
    datetime startCheck = now - 7 * 24 * 3600; // Last 7 days
    datetime endCheck = now + 7 * 24 * 3600;   // Next 7 days
    
    Print("RECENT ASPECTS FOR VALIDATION (±7 days):");
    Print("=========================================");
    
    int validatedCount = 0;
    for(int i = 0; i < aspectCount && validatedCount < 5; i++)
    {
        if(aspects[i].time >= startCheck && aspects[i].time <= endCheck)
        {
            // Prioritize conjunctions for easier validation
            if(aspects[i].aspect == "Conjunction" || validatedCount < 3)
            {
                validatedCount++;
                Print("");
                Print("VALIDATION SAMPLE #", validatedCount, ":");
                ValidateSpecificAspect(aspects[i]);
                
                // Add Julian Day for Swiss Ephemeris users
                double jd = GetJulianDay(aspects[i].time);
                Print("Swiss Ephemeris Julian Day: ", DoubleToString(jd, 6));
                Print("Use this JD in Swisseph to verify planet positions");
                Print("");
            }
        }
    }
    
    if(validatedCount == 0)
    {
        Print("No aspects found in ±7 day range for validation.");
        Print("Try expanding the time range or check your CSV data.");
    }
    
    Print("=== END VALIDATION REPORT ===");
    Print("");
    
    // Specific diagnosis for June 30, 2025
    DiagnoseJune30Aspects();
    
    Print("NEXT STEPS:");
    Print("1. Copy one of the UTC times above");
    Print("2. Open Swiss Ephemeris software");
    Print("3. Navigate to that exact UTC time");
    Print("4. Compare planet longitudes with the values shown");
    Print("5. If they don't match, adjust CSVTimezoneOffset and restart indicator");
    Print("");
}

//+------------------------------------------------------------------+
//| Specific diagnosis for June 30, 2025 aspects                   |
//| This function helps verify the timezone issue                   |
//+------------------------------------------------------------------+
void DiagnoseJune30Aspects()
{
    Print("=== CURRENT DATE ASPECT DIAGNOSIS ===");
    
    datetime now = TimeCurrent();
    MqlDateTime nowDt;
    TimeToStruct(now, nowDt);
    
    // Use current date instead of hardcoded June 30
    nowDt.hour = 0; nowDt.min = 0; nowDt.sec = 0;
    datetime targetStart = StructToTime(nowDt);
    datetime targetEnd = targetStart + 24 * 3600; // Full day
    
    Print("Searching for aspects on current date...");
    Print("Target date range: ", TimeToString(targetStart), " to ", TimeToString(targetEnd));
    Print("");
    
    bool found = false;
    for(int i = 0; i < aspectCount; i++)
    {
        if(aspects[i].time >= targetStart && aspects[i].time < targetEnd)
        {
            found = true;
            Print("FOUND TODAY'S ASPECT:");
            Print("  ", aspects[i].planet1, "-", aspects[i].planet2, " ", aspects[i].aspect);
            Print("  Greek Time (CSV): ", TimeToString(aspects[i].time));
            
            // Show converted times
            datetime greekTime = aspects[i].time;  // CSV is already in Greek time
            datetime utcTime = greekTime - GetGreekUtcOffset(greekTime) * 3600;
            datetime sgtTime = utcTime + 8 * 3600;
            
            Print("  UTC Time: ", TimeToString(utcTime));
            Print("  Greek Time: ", TimeToString(greekTime), " (", IsGreekSummerTime(greekTime) ? "EEST" : "EET", ")");
            Print("  Singapore Time: ", TimeToString(sgtTime), " (SGT)");
            Print("  Angle: ", DoubleToString(aspects[i].angle, 2), "°");
            Print("");
            
            // Validate this specific aspect
            ValidateSpecificAspect(aspects[i]);
        }
    }
    
    if(!found)
    {
        Print("No aspects found for current date.");
        Print("This could mean:");
        Print("1. No aspects occur on this date in your CSV");
        Print("2. CSV data doesn't cover this date range");
        Print("3. Check if aspects are showing from past dates instead");
        Print("");
        
        // Show what date range we actually have in CSV
        if(aspectCount > 0)
        {
            datetime firstAspect = aspects[0].time;
            datetime lastAspect = aspects[aspectCount-1].time;
            Print("CSV DATE RANGE:");
            Print("First aspect: ", TimeToString(firstAspect));
            Print("Last aspect: ", TimeToString(lastAspect));
            Print("Current time: ", TimeToString(now));
            
            if(now < firstAspect)
                Print(">>> ISSUE: Current time is BEFORE CSV data range! <<<");
            else if(now > lastAspect)
                Print(">>> ISSUE: Current time is AFTER CSV data range! <<<");
            else
                Print(">>> Current time is within CSV range - aspects should exist <<<");
        }
    }
    
    Print("=== END CURRENT DATE DIAGNOSIS ===");
    Print("");
}

//+------------------------------------------------------------------+
//| ENHANCED TIMEZONE DIAGNOSIS WITH REAL-TIME VERIFICATION        |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Diagnose timezone by comparing current time with CSV data      |
//+------------------------------------------------------------------+
void DiagnoseTimezoneWithCurrentData()
{
    Print("=== ENHANCED TIMEZONE DIAGNOSIS ===");
    datetime now = TimeCurrent();
    MqlDateTime currentDt;
    TimeToStruct(now, currentDt);
    Print("Current date: ", currentDt.year, ".", StringFormat("%02d", currentDt.mon), ".", StringFormat("%02d", currentDt.day));
    Print("");
    
    Print("Current UTC time: ", TimeToString(now));
    Print("Current Greek time: ", TimeToString(GetGreekTime(now)), " (", IsGreekSummerTime(now) ? "EEST" : "EET", ")");
    Print("Current Singapore time: ", TimeToString(now + 8 * 3600), " (SGT)");
    Print("");
    
    // Find TODAY's aspects (use current date, not hardcoded June 30)
    datetime todayStart = StructToTime(currentDt);  // Start of today
    currentDt.hour = 23; currentDt.min = 59; currentDt.sec = 59;
    datetime todayEnd = StructToTime(currentDt);    // End of today
    
    Print("CSV ASPECTS FOR TODAY (", currentDt.year, ".", StringFormat("%02d", currentDt.mon), ".", StringFormat("%02d", currentDt.day), "):");
    Print("=======================================");
    
    bool foundToday = false;
    for(int i = 0; i < aspectCount; i++)
    {
        if(aspects[i].time >= todayStart && aspects[i].time <= todayEnd)
        {
            foundToday = true;
            datetime greekTime = aspects[i].time;  // CSV is already in Greek time
            datetime utcTime = greekTime - GetGreekUtcOffset(greekTime) * 3600;  // Greek -> UTC
            datetime singaporeTime = utcTime + 8 * 3600;  // UTC -> SGT
            
            Print("");
            Print("ASPECT: ", aspects[i].planet1, "-", aspects[i].planet2, " ", aspects[i].aspect);
            Print("Greek Time (CSV): ", TimeToString(greekTime));
            Print("UTC Time: ", TimeToString(utcTime));
            Print("Singapore Time: ", TimeToString(singaporeTime), " (SGT)");
            Print("Planet longitudes: ", aspects[i].planet1, "=", DoubleToString(aspects[i].planet1_lon, 2), "°, ",
                  aspects[i].planet2, "=", DoubleToString(aspects[i].planet2_lon, 2), "°");
            
            // Check timing relative to now
            double hoursFromNow = (utcTime - now) / 3600.0;
            Print("Time from now: ", DoubleToString(hoursFromNow, 1), " hours");
            
            if(hoursFromNow > -24 && hoursFromNow < 24)
            {
                Print(">>> THIS ASPECT IS VERY CLOSE TO CURRENT TIME! <<<");
                Print(">>> PERFECT FOR TIMEZONE VALIDATION <<<");
            }
        }
    }
    
    if(!foundToday)
    {
        Print("No aspects found for today in CSV data.");
        
        // Check recent days
        Print("");
        Print("CHECKING RECENT DAYS:");
        for(int dayOffset = -3; dayOffset <= 3; dayOffset++)
        {
            if(dayOffset == 0) continue; // Skip today, already checked
            
            datetime checkDate = todayStart + dayOffset * 24 * 3600;
            datetime checkStart = checkDate;
            datetime checkEnd = checkDate + 24 * 3600;
            
            MqlDateTime checkDt;
            TimeToStruct(checkDate, checkDt);
            
            int aspectsFound = 0;
            for(int i = 0; i < aspectCount; i++)
            {
                if(aspects[i].time >= checkStart && aspects[i].time < checkEnd)
                {
                    aspectsFound++;
                }
            }
            
            if(aspectsFound > 0)
            {
                Print("Found ", aspectsFound, " aspects on ", checkDt.year, ".", StringFormat("%02d", checkDt.mon), ".", StringFormat("%02d", checkDt.day));
            }
        }
    }
    
    Print("=== END ENHANCED DIAGNOSIS ===");
    Print("");
}

//+------------------------------------------------------------------+
//| Generate Swiss Ephemeris verification for current time         |
//+------------------------------------------------------------------+
void GenerateSwissEphemerisCheckForNow()
{
    datetime now = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(now, dt);
    
    Print("IMMEDIATE SWISS EPHEMERIS VERIFICATION:");
    Print("======================================");
    Print("Check Swiss Ephemeris RIGHT NOW:");
    Print("UTC Time: ", TimeToString(now));
    Print("Date: ", dt.year, ".", StringFormat("%02d", dt.mon), ".", StringFormat("%02d", dt.day));
    Print("Time: ", StringFormat("%02d", dt.hour), ":", StringFormat("%02d", dt.min), " UTC");
    Print("");
    
    double jd = GetJulianDay(now);
    Print("Julian Day: ", DoubleToString(jd, 6));
    Print("");
    
    Print("COMMAND LINES FOR VERIFICATION:");
    Print("swetest.exe -b", dt.year, ".", StringFormat("%02d", dt.mon), ".", StringFormat("%02d", dt.day), 
          " -ut", StringFormat("%02d", dt.hour), ":", StringFormat("%02d", dt.min), ":00 -p0123456789t -fPLBR -g");
    Print("OR:");
    Print("swetest.exe -j", DoubleToString(jd, 6), " -p0123456789t -fPLBR -g");
    Print("");
    
    Print("WHAT TO CHECK:");
    Print("1. Run one of the commands above in Swiss Ephemeris");
    Print("2. Note the longitude values for all planets");
    Print("3. Compare with CSV longitudes for today's aspects");
    Print("4. If they match within ~1°, your timezone is CORRECT");
    Print("5. If they don't match, try different CSVTimezoneOffset values");
    Print("");
}

//+------------------------------------------------------------------+
//| Compare CSV planet positions with expected current positions   |
//+------------------------------------------------------------------+
void CompareWithExpectedPositions()
{
    Print("=== PLANET POSITION COMPARISON ===");
    Print("");
    
    // Find the most recent aspect to current time
    datetime now = TimeCurrent();
    int closestIndex = -1;
    double smallestTimeDiff = 999999;
    
    for(int i = 0; i < aspectCount; i++)
    {
        double timeDiff = MathAbs((double)(aspects[i].time - now));
        if(timeDiff < smallestTimeDiff)
        {
            smallestTimeDiff = timeDiff;
            closestIndex = i;
        }
    }
    
    if(closestIndex >= 0 && smallestTimeDiff < 24 * 3600) // Within 24 hours
    {
        // Use reference correctly
        int idx = closestIndex;
        double hoursAway = smallestTimeDiff / 3600.0;
        
        Print("CLOSEST ASPECT TO CURRENT TIME:");
        Print("Aspect: ", aspects[idx].planet1, "-", aspects[idx].planet2, " ", aspects[idx].aspect);
        Print("Time: ", TimeToString(aspects[idx].time), " UTC");
        Print("Hours from now: ", DoubleToString(hoursAway, 1));
        Print("");
        Print("CSV Planet Positions:");
        Print("  ", aspects[idx].planet1, ": ", DoubleToString(aspects[idx].planet1_lon, 4), "°");
        Print("  ", aspects[idx].planet2, ": ", DoubleToString(aspects[idx].planet2_lon, 4), "°");
        Print("");
        Print("VERIFICATION:");
        Print("Check these positions in Swiss Ephemeris at:");
        Print("UTC: ", TimeToString(aspects[idx].time));
        Print("Greek: ", TimeToString(GetGreekTime(aspects[idx].time)));
        Print("Singapore: ", TimeToString(aspects[idx].time + 8*3600));
        Print("");
        Print("The timezone where positions match is CORRECT!");
    }
    else
    {
        Print("No recent aspects found for comparison.");
        Print("Consider expanding the time range or checking CSV data coverage.");
    }
    
    Print("=== END POSITION COMPARISON ===");
    Print("");
}

//+------------------------------------------------------------------+
//| Analyze CSV time patterns to identify timezone                 |
//+------------------------------------------------------------------+
void AnalyzeCSVTimePatterns()
{
    Print("=== CSV TIME PATTERN ANALYSIS ===");
    Print("");
    
    // Count time patterns
    int timeCount[24] = {0}; // Hour frequency
    int totalEntries = 0;
    
    for(int i = 0; i < aspectCount && i < 1000; i++) // Sample first 1000 entries
    {
        MqlDateTime dt;
        TimeToStruct(aspects[i].time, dt);
        timeCount[dt.hour]++;
        totalEntries++;
    }
    
    Print("TIME FREQUENCY ANALYSIS (first ", totalEntries, " entries):");
    Print("Hour | Count | %");
    Print("-----|-------|---");
    
    for(int h = 0; h < 24; h++)
    {
        if(timeCount[h] > 0)
        {
            double percentage = (double)timeCount[h] / totalEntries * 100.0;
            Print(StringFormat("%02d   | %5d | %.1f%%", h, timeCount[h], percentage));
        }
    }
    
    Print("");
    Print("PATTERN INTERPRETATION:");
    
    // Identify the most common times
    int maxCount = 0;
    string commonTimes = "";
    
    for(int h = 0; h < 24; h++)
    {
        if(timeCount[h] > maxCount * 0.8) // Within 80% of maximum
        {
            if(maxCount < timeCount[h]) maxCount = timeCount[h];
            commonTimes += StringFormat("%02d:00, ", h);
        }
    }
    
    Print("Most common times: ", commonTimes);
    
    // Pattern analysis
    if(timeCount[0] > 0 && timeCount[8] > 0 && timeCount[16] > 0)
    {
        Print(">>> PATTERN: 00:00, 08:00, 16:00 intervals detected");
        Print(">>> This suggests 8-hour intervals, possibly Singapore timezone!");
        Print(">>> Singapore times: 00:00, 08:00, 16:00 SGT");
        Print(">>> UTC equivalents: 16:00, 00:00, 08:00 UTC (previous day, same day, same day)");
        Print(">>> RECOMMENDATION: Try CSVTimezoneOffset = 8");
    }
    
    if(timeCount[0] > 0 && timeCount[12] > 0)
    {
        Print(">>> PATTERN: 00:00, 12:00 intervals detected");
        Print(">>> This could be UTC or other timezone with 12-hour intervals");
    }
    
    // Check for Greek time patterns
    if(timeCount[2] > 0 || timeCount[3] > 0) // Greek morning hours in UTC
    {
        Print(">>> PATTERN: 02:00 or 03:00 UTC times detected");
        Print(">>> This could indicate Greek timezone (EET/EEST) converted to UTC");
        Print(">>> Greek 05:00 morning = 02:00 UTC (EET) or 03:00 UTC (EEST)");
    }
    
    Print("");
    Print("TODAY'S ASPECTS TIMING CHECK:");
    Print("============================");
    
    // Check today's specific timings
    datetime todayStart = D'2025.06.30 00:00:00';
    datetime todayEnd = D'2025.06.30 23:59:59';
    
    for(int i = 0; i < aspectCount; i++)
    {
        if(aspects[i].time >= todayStart && aspects[i].time <= todayEnd)
        {
            MqlDateTime dt;
            TimeToStruct(aspects[i].time, dt);
            
            Print("Today's aspect at ", StringFormat("%02d:%02d", dt.hour, dt.min), " UTC");
            Print("  If CSV is SGT: Original time was ", StringFormat("%02d:%02d", (dt.hour + 8) % 24, dt.min), " SGT");
            Print("  If CSV is Greek: Original time was ", StringFormat("%02d:%02d", dt.hour + (IsGreekSummerTime(aspects[i].time) ? 3 : 2), dt.min), " Greek");
            Print("  Current time: ", TimeToString(TimeCurrent()));
            
            if((dt.hour == 0 || dt.hour == 8 || dt.hour == 16))
            {
                Print("  >>> This matches SGT 8-hour interval pattern! <<<");
            }
        }
    }
    
    Print("=== END TIME PATTERN ANALYSIS ===");
    Print("");
}

//+------------------------------------------------------------------+
//| Validate arrays and data integrity to prevent out-of-range errors |
//+------------------------------------------------------------------+
bool ValidateArraysAndData()
{
    Print("=== ARRAY VALIDATION STARTING ===");
    
    // Check aspects array
    int aspectsArraySize = ArraySize(aspects);
    Print("Aspects array size: ", aspectsArraySize);
    Print("Aspect count: ", aspectCount);
    
    if(aspectCount < 0)
    {
        Print("ERROR: Negative aspect count: ", aspectCount);
        return false;
    }
    
    if(aspectCount > aspectsArraySize)
    {
        Print("ERROR: Aspect count (", aspectCount, ") exceeds array size (", aspectsArraySize, ")");
        return false;
    }
    
    // Validate a sample of aspects for data integrity
    int samplesToCheck = MathMin(10, aspectCount);
    for(int i = 0; i < samplesToCheck; i++)
    {
        if(i >= aspectsArraySize)
        {
            Print("ERROR: Sample index ", i, " exceeds array size during validation");
            return false;
        }
        
        // Check if time is reasonable (between 1970 and 2100)
        if(aspects[i].time < D'1970.01.01' || aspects[i].time > D'2100.12.31')
        {
            Print("WARNING: Aspect ", i, " has unreasonable time: ", TimeToString(aspects[i].time));
        }
        
        // Check if planet names are not empty
        if(StringLen(aspects[i].planet1) == 0 || StringLen(aspects[i].planet2) == 0)
        {
            Print("WARNING: Aspect ", i, " has empty planet names");
        }
        
        // Check if angle is in valid range
        if(aspects[i].angle < 0 || aspects[i].angle > 360)
        {
            Print("WARNING: Aspect ", i, " has invalid angle: ", aspects[i].angle);
        }
    }
    
    Print("=== ARRAY VALIDATION COMPLETED ===");
    Print("- Array integrity: OK");
    Print("- Checked ", samplesToCheck, " sample aspects");
    Print("- Ready for safe processing");
    
    return true;
}

//+------------------------------------------------------------------+