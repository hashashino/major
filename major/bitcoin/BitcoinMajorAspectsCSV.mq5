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
input int MaxAspectsToShow = 1000;         // Maximum aspects to display (PERFORMANCE LIMIT)
input bool SmartTimeFiltering = true;      // Use smart time filtering for visible chart area
input int UpdateIntervalBars = 10;         // Update aspects every N bars for performance
input bool PrioritizeByImportance = true;  // Show important aspects first (conjunctions, squares, oppositions)
input bool ForceRedrawAspects = false;     // Force manual redraw (toggle on/off to refresh)

// Input parameters
input string CSVFileName = "bitcoin_complete_major_aspects.csv"; // Bitcoin-specific CSV file name
input int CSVTimezoneOffset = 3;        // CSV timezone offset from UTC (0=UTC, 2=EET, 3=EEST, 8=SGT)

//--- ASPECT TYPE TOGGLES (ordered by importance for performance)
input bool ShowConjunction = true;      // Show Conjunction aspects (HIGHEST PRIORITY)
input bool ShowSquare = true;           // Show Square aspects (HIGH PRIORITY)
input bool ShowOpposition = true;       // Show Opposition aspects (HIGH PRIORITY)
input bool ShowSemisquare = true;       // Show Semisquare (45°) aspects (HIGH PRIORITY - IMPORTANT TO USER)
input bool ShowGann109 = true;          // Show Gann 109° aspects (HIGH PRIORITY - IMPORTANT TO USER)
input bool ShowGann74 = true;           // Show Gann 74° aspects (HIGH PRIORITY - IMPORTANT TO USER)
input bool ShowTrine = true;            // Show Trine aspects (MEDIUM PRIORITY)
input bool ShowSextile = true;          // Show Sextile aspects (MEDIUM PRIORITY)

input bool ShowAllAspects = false;      // Show all aspects regardless of time range (PERFORMANCE IMPACT)
input bool CenterOnCurrentTime = true;  // Center time range around current time (instead of chart range)

// Planet group filters - CORRECTED LOGIC (optimized for performance)
input bool ShowLuminaries = true;       // Show Sun & Moon with ALL other planets (FAST timing - HIGH PRIORITY)
input bool ShowFastPlanets = true;      // Show Mercury, Venus, Mars only among themselves (MEDIUM PRIORITY)
input bool ShowSlowPlanets = false;     // Show Jupiter, Saturn, Uranus, Neptune, Pluto only among themselves (DISABLED FOR PERFORMANCE)

input int LookAheadDays = 180;          // Days to look ahead (increased to show more future aspects)
input int LookBackDays = 180;          // Days to look back (increased to show more past aspects)

// Aspect colors with improved visibility
input color ConjunctionColor = clrYellow;    // Conjunction color
input color SextileColor = clrLime;          // Sextile color
input color SquareColor = clrRed;            // Square color
input color TrineColor = clrBlue;            // Trine color
input color OppositionColor = clrMagenta;    // Opposition color
input color SemisquareColor = clrOrange;     // Semisquare (45°) color
input color Gann109Color = clrCyan;          // Gann 109° color
input color Gann74Color = clrGold;           // Gann 74° color

// Line styles for better distinction
input ENUM_LINE_STYLE ConjunctionStyle = STYLE_SOLID;
input ENUM_LINE_STYLE SextileStyle = STYLE_DOT;
input ENUM_LINE_STYLE SquareStyle = STYLE_SOLID;
input ENUM_LINE_STYLE TrineStyle = STYLE_DASH;
input ENUM_LINE_STYLE OppositionStyle = STYLE_SOLID;
input ENUM_LINE_STYLE SemisquareStyle = STYLE_DASHDOT;
input ENUM_LINE_STYLE Gann109Style = STYLE_DASHDOTDOT;
input ENUM_LINE_STYLE Gann74Style = STYLE_DASHDOTDOT;

// Line widths
input int LineWidth = 2;

// Planet Group Visual Distinction
input bool DistinguishPlanetGroups = true;    // Enable visual distinction between planet groups
input color LuminariesLineColor = clrWhite;    // Color for Luminaries (Sun/Moon) aspects - WHITE for fast timing
input color MediumTermLineColor = clrYellow;  // Color for Medium-term (Mercury/Venus/Mars) aspects - YELLOW  
input color SlowPlanetsLineColor = clrRed;    // Color for Slow planets (Jupiter-Pluto) aspects - RED
input int LuminariesLineWidth = 1;            // Line width for Luminaries aspects (thinnest)
input int MediumTermLineWidth = 2;            // Line width for Medium-term aspects (medium)
input int SlowPlanetsLineWidth = 4;           // Line width for Slow planets aspects (thickest)
input ENUM_LINE_STYLE LuminariesLineStyle = STYLE_DOT;      // Line style for Luminaries (FAST - dotted)
input ENUM_LINE_STYLE MediumTermLineStyle = STYLE_DASH;     // Line style for Medium-term (MEDIUM - dashed)
input ENUM_LINE_STYLE SlowPlanetsLineStyle = STYLE_SOLID;   // Line style for Slow planets (LONG-TERM - solid)

// Text settings
input int FontSize = 8;
input color TextColor = clrWhite;

// Global state tracking for aspect drawing
bool g_aspects_drawn = false;  // Track if aspects are currently displayed

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
    Print("IMPORTANT: Semisquare & Gann patterns (161°, 207°) are HIGH PRIORITY - enabled by default");
    Print("PLANET GROUPS: ", DistinguishPlanetGroups ? "VISUAL DISTINCTION ENABLED" : "STANDARD ASPECT COLORS");
    if(DistinguishPlanetGroups)
    {
        Print("  - FAST (Luminaries): Sun/Moon with ALL planets - ", EnumToString(LuminariesLineStyle), " lines");
        Print("  - MEDIUM: Mercury/Venus/Mars among themselves - ", EnumToString(MediumTermLineStyle), " lines");  
        Print("  - LONG-TERM: Jupiter/Saturn/Uranus/Neptune/Pluto among themselves - ", EnumToString(SlowPlanetsLineStyle), " lines");
        Print("DEBUG: LuminariesLineStyle = ", (int)LuminariesLineStyle, " (STYLE_DOT = ", (int)STYLE_DOT, ")");
        Print("DEBUG: MediumTermLineStyle = ", (int)MediumTermLineStyle, " (STYLE_DASH = ", (int)STYLE_DASH, ")");
        Print("DEBUG: SlowPlanetsLineStyle = ", (int)SlowPlanetsLineStyle, " (STYLE_SOLID = ", (int)STYLE_SOLID, ")");
    }
    
    // Load aspects from CSV with error handling
    if(!LoadAspectsFromCSV())
    {
        Print("ERROR: Failed to load aspects from CSV file: ", CSVFileName);
        return INIT_FAILED;
    }
    
    Print("SUCCESS: Loaded ", aspectCount, " aspects from ", CSVFileName);
    
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
        Print("- CSV data is assumed to be in UTC timezone");
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
    // MQL5 FileOpen automatically looks in the terminal's Files directory
    // Just use the filename, not the full path
    int file_handle = FileOpen(filename, FILE_READ | FILE_TXT | FILE_ANSI);
    
    if(file_handle == INVALID_HANDLE)
    {
        Print("ERROR: Cannot open CSV file: ", filename);
        Print("Make sure the file exists in the terminal's Files directory");
        return false;
    }
    
    Print("Successfully opened CSV file: ", filename);
    
    // Skip header line
    string header = FileReadString(file_handle);
    Print("CSV Header: ", header);
    
    aspectCount = 0;
    ArrayResize(aspects, PerformanceMode ? 5000 : 25000); // Reduced for performance mode
    
    int lineNumber = 1;
    int maxToLoad = PerformanceMode ? 5000 : 25000; // Performance limit
    
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
        
        // Parse numerical values with validation
        double angle = StringToDouble(angle_str);
        double planet1_lon = StringToDouble(planet1_lon_str);
        double planet2_lon = StringToDouble(planet2_lon_str);
        
        if(angle < 0 || angle > 360 || planet1_lon < 0 || planet1_lon > 360 || planet2_lon < 0 || planet2_lon > 360)
        {
            Print("WARNING: Invalid angle/longitude values at line ", lineNumber, ": angle=", angle, ", p1_lon=", planet1_lon, ", p2_lon=", planet2_lon);
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
    if(aspect == "Gann109") return Gann109Color;        // Gann 109° color (fixed name)
    if(aspect == "Gann74") return Gann74Color;          // Gann 74° color (fixed name)
    
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
    if(aspect == "Gann109") return Gann109Style;        // Gann 109° style (fixed name)
    if(aspect == "Gann74") return Gann74Style;          // Gann 74° style (fixed name)
    
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
    if(aspect == "Gann109") return 2;          // HIGH PRIORITY - Important to user
    if(aspect == "Gann74") return 2;           // HIGH PRIORITY - Important to user
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
    else if(group == "Medium")  // Medium-term: Mercury, Venus, Mars
    {
        return (planet == "Mercury" || planet == "Venus" || planet == "Mars");
    }
    else if(group == "Slow")    // Long-term: Jupiter, Saturn, Uranus, Neptune, Pluto
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
    bool planet1_medium = IsPlanetInGroup(planet1, "Medium");
    bool planet1_slow = IsPlanetInGroup(planet1, "Slow");
    
    bool planet2_luminary = IsPlanetInGroup(planet2, "Luminaries");
    bool planet2_medium = IsPlanetInGroup(planet2, "Medium");
    bool planet2_slow = IsPlanetInGroup(planet2, "Slow");
    
    // Check if this aspect should be shown based on enabled groups
    bool showAspect = false;
    
    // FAST (LUMINARIES): Show Sun & Moon with ALL other planets (most frequent and important timing)
    if(ShowLuminaries && (planet1_luminary || planet2_luminary))
        showAspect = true;
    
    // MEDIUM TERM: Show aspects between Mercury, Venus, Mars only among themselves
    if(ShowFastPlanets && planet1_medium && planet2_medium)
        showAspect = true;
    
    // LONG TERM (SLOW): Show aspects between Jupiter, Saturn, Uranus, Neptune, Pluto only among themselves
    if(ShowSlowPlanets && planet1_slow && planet2_slow)
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
    if(aspect == "Gann109") return ShowGann109;         // Gann 109° aspect visibility (fixed name)
    if(aspect == "Gann74") return ShowGann74;           // Gann 74° aspect visibility (fixed name)
    
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
    // Safety checks first
    if(rates_total <= 0)
    {
        Print("ERROR: Invalid rates_total: ", rates_total);
        return 0;
    }
    
    if(ArraySize(time) != rates_total)
    {
        Print("ERROR: Time array size mismatch. Array size: ", ArraySize(time), ", rates_total: ", rates_total);
        return 0;
    }
    
    // ENHANCED: Track timeframe changes for automatic redraw
    static int last_update_bar = 0;
    static ENUM_TIMEFRAMES last_calc_timeframe = PERIOD_CURRENT;
    static datetime last_redraw_time = 0;
    
    ENUM_TIMEFRAMES current_timeframe = Period();
    datetime current_time = TimeCurrent();
    bool force_update = false;
    string update_reason = "";
    
    // Check for timeframe change (backup detection)
    if(current_timeframe != last_calc_timeframe)
    {
        force_update = true;
        update_reason = "Timeframe Change in OnCalculate";
        last_calc_timeframe = current_timeframe;
        last_update_bar = 0; // Reset to force immediate update
        g_aspects_drawn = false; // Mark for redraw
    }
    
    // Check if aspects need to be drawn initially
    if(!g_aspects_drawn && rates_total > 0)
    {
        force_update = true;
        update_reason = "Initial Draw";
    }
    
    // Check for manual force redraw
    if(ForceRedrawAspects)
    {
        force_update = true;
        update_reason = "Manual Force Redraw";
        g_aspects_drawn = false; // Mark for redraw
    }
    
    // PERFORMANCE: Only update every N bars if performance mode is enabled (unless forced)
    if(PerformanceMode && !force_update && (rates_total - last_update_bar) < UpdateIntervalBars)
    {
        return rates_total;
    }
    
    if(force_update)
    {
        Print("🔄 MajorAspects Force Update - Reason: ", update_reason, 
              " | Timeframe: ", EnumToString(current_timeframe));
    }
    
    last_update_bar = rates_total;
    
    // Clear previous objects ONLY when we're about to redraw
    if(force_update || !g_aspects_drawn)
    {
        ObjectsDeleteAll(0, "ASPECT_");
        Print("🗑️ Cleared aspect objects for redraw");
    }
    
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
        // TIME RANGE CALCULATION - Center on current time OR use chart range
        datetime currentTime = TimeCurrent();
        datetime chartStartTime, chartEndTime;
        datetime referenceTime;
        
        if(SmartTimeFiltering && PerformanceMode)
        {
            // Get current chart time range for reference
            long firstVisibleBar = ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
            long lastVisibleBar = ChartGetInteger(0, CHART_VISIBLE_BARS);
            
            // Calculate chart time range from visible bars with bounds checking
            int startIndex = (int)MathMax(0, MathMin(rates_total - 1, rates_total - firstVisibleBar - lastVisibleBar));
            int endIndex = rates_total - 1;
            
            // Ensure indices are within valid range
            if(startIndex < 0) startIndex = 0;
            if(endIndex >= rates_total) endIndex = rates_total - 1;
            if(startIndex >= rates_total) startIndex = rates_total - 1;
            
            chartStartTime = time[startIndex];
            chartEndTime = time[endIndex];
            
            // Choose reference point: Current time OR chart center
            if(CenterOnCurrentTime)
            {
                referenceTime = currentTime;
                Print("CENTERING: Using CURRENT TIME as reference: ", TimeToString(currentTime));
            }
            else
            {
                referenceTime = chartStartTime + (chartEndTime - chartStartTime) / 2; // Chart center
                Print("CENTERING: Using CHART CENTER as reference: ", TimeToString(referenceTime));
            }
            
            // Use balanced look-ahead/back ranges for performance (increased to ensure current aspects are visible)
            int effectiveLookBack = PerformanceMode ? MathMin(LookBackDays, 180) : LookBackDays;
            int effectiveLookAhead = PerformanceMode ? MathMin(LookAheadDays, 120) : LookAheadDays;
            
            // CENTER THE TIME RANGE AROUND REFERENCE TIME
            startTime = referenceTime - effectiveLookBack * 24 * 3600;
            endTime = referenceTime + effectiveLookAhead * 24 * 3600;
            
            Print("PERFORMANCE: Smart filtering enabled - chart range: ", TimeToString(chartStartTime), " to ", TimeToString(chartEndTime));
            Print("ASPECT SEARCH: Centered around reference - ", TimeToString(startTime), " to ", TimeToString(endTime));
        }
        else
        {
            // Standard time range - choose centering method
            // Add bounds checking for safety
            if(rates_total > 0)
            {
                chartStartTime = time[0];
                chartEndTime = time[rates_total-1];
            }
            else
            {
                Print("ERROR: No price data available (rates_total = 0)");
                return prev_calculated;
            }
            
            // Choose reference point: Current time OR chart end
            if(CenterOnCurrentTime)
            {
                referenceTime = currentTime;
                Print("CENTERING: Using CURRENT TIME as reference: ", TimeToString(currentTime));
            }
            else
            {
                referenceTime = chartEndTime; // Traditional method - from chart end
                Print("CENTERING: Using CHART END as reference: ", TimeToString(referenceTime));
            }
            
            if(PerformanceMode)
            {
                // CENTER AROUND REFERENCE TIME
                startTime = referenceTime - LookBackDays * 24 * 3600;
                endTime = referenceTime + LookAheadDays * 24 * 3600;
            }
            else
            {
                // When PerformanceMode is disabled, use extended time range CENTERED ON REFERENCE TIME
                startTime = referenceTime - (LookBackDays * 2) * 24 * 3600;  // Double the lookback from reference
                endTime = referenceTime + (LookAheadDays * 2) * 24 * 3600;     // Double the lookahead from reference
                Print("PERFORMANCE MODE DISABLED: Using extended time range CENTERED ON REFERENCE TIME");
            }
            
            Print("TIME CENTERING: Reference time = ", TimeToString(referenceTime));
        }
        
    Print("Search time range: ", TimeToString(startTime), " to ", TimeToString(endTime));
    Print("CURRENT TIME FOR REFERENCE: ", TimeToString(TimeCurrent()));
    Print("Days from current time: Back=", (TimeCurrent() - startTime) / (24*3600), ", Forward=", (endTime - TimeCurrent()) / (24*3600));
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
    int totalInRange = 0;
    int currentTimeWindow = 0; // Aspects within ±7 days of current time
    datetime currentTime = TimeCurrent();
    
    for(int i = 0; i < aspectCount; i++)
    {
        if(aspects[i].time >= startTime && aspects[i].time <= endTime)
        {
            totalInRange++;
            
            // Count aspects near current time (±7 days)
            if(MathAbs(aspects[i].time - currentTime) <= 7 * 24 * 3600)
            {
                currentTimeWindow++;
                Print("CURRENT TIME ASPECT FOUND: ", TimeToString(aspects[i].time), " ", 
                      aspects[i].planet1, "-", aspects[i].planet2, " ", aspects[i].aspect);
            }
            
            // Check both aspect type AND planet group filters
            if(ShouldShowAspect(aspects[i].aspect) && ShouldShowPlanetGroup(aspects[i].planet1, aspects[i].planet2))
            {
                // Add to priority array
                ArrayResize(priorityAspects, priorityCount + 1);
                priorityAspects[priorityCount].index = i;
                priorityAspects[priorityCount].importance = GetAspectImportance(aspects[i].aspect);
                priorityAspects[priorityCount].time = aspects[i].time;
                priorityCount++;
            }
        }
    }
    
    Print("Found ", priorityCount, " aspects to potentially display");
    Print("DIAGNOSTIC: ", totalInRange, " aspects in time range, ", currentTimeWindow, " within ±7 days of current time");
    
    // DIAGNOSTIC: Check if we have recent aspects
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
            if(aspects[i].time >= startTime && aspects[i].time <= endTime)
            {
                if(ShouldShowAspect(aspects[i].aspect) && ShouldShowPlanetGroup(aspects[i].planet1, aspects[i].planet2))
                {
                    ArrayResize(priorityAspects, priorityCount + 1);
                    priorityAspects[priorityCount].index = i;
                    priorityAspects[priorityCount].importance = GetAspectImportance(aspects[i].aspect);
                    priorityAspects[priorityCount].time = aspects[i].time;
                    priorityCount++;
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
        int aspectIndex = priorityAspects[i].index;
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
        if(aspects[aspectIndex].aspect == "Semisquare" || aspects[aspectIndex].aspect == "Gann109" || aspects[aspectIndex].aspect == "Gann74")
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
        datetime firstDrawn = aspects[priorityAspects[0].index].time;
        datetime lastDrawn = aspects[priorityAspects[MathMin(drawnAspects-1, priorityCount-1)].index].time;
        Print("- Drawn aspect time range: ", TimeToString(firstDrawn), " to ", TimeToString(lastDrawn));
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
    
    // Mark aspects as successfully drawn
    g_aspects_drawn = true;
    Print("✅ MajorAspects drawing completed - aspects visible");
    
    return rates_total;
}

//+------------------------------------------------------------------+
//| Draw aspect line with enhanced accuracy (PERFORMANCE OPTIMIZED)|
//+------------------------------------------------------------------+
void DrawAspectLine(AspectData &aspect, int index)
{
    string objectName = "ASPECT_" + IntegerToString(index);
    
    // PERFORMANCE: Use simpler object creation for better speed
    // Convert UTC time to Greek time for chart display
    datetime chartTime = GetGreekTime(aspect.time);
    
    if(ObjectCreate(0, objectName, OBJ_VLINE, 0, chartTime, 0))
    {
        // Use group-based visual styling if enabled, otherwise use aspect-based styling
        ObjectSetInteger(0, objectName, OBJPROP_COLOR, GetGroupColor(aspect.planet1, aspect.planet2, aspect.aspect));
        ObjectSetInteger(0, objectName, OBJPROP_STYLE, GetGroupLineStyle(aspect.planet1, aspect.planet2, aspect.aspect));
        ObjectSetInteger(0, objectName, OBJPROP_WIDTH, GetGroupLineWidth(aspect.planet1, aspect.planet2));
        ObjectSetInteger(0, objectName, OBJPROP_BACK, true);
        
        // PERFORMANCE: Simplified tooltip for better performance
        if(!PerformanceMode)
        {
            // Full tooltip only when performance mode is disabled
            // aspect.time is now in UTC after CSV conversion
            datetime greekTime = GetGreekTime(aspect.time);
            datetime singaporeTime = aspect.time + 8 * 3600;
            
            string greekTimezone = IsGreekSummerTime(aspect.time) ? "EEST" : "EET";
            
            string groupType = GetPlanetGroupType(aspect.planet1, aspect.planet2);
            string groupLabel = "";
            if(groupType == "Luminaries") groupLabel = " [FAST]";
            else if(groupType == "Medium") groupLabel = " [MEDIUM]";
            else if(groupType == "Slow") groupLabel = " [LONG-TERM]";
            
            string tooltip = StringFormat("%s %s-%s %s%s\nUTC: %s\n%s: %s\nSGT: %s\nAngle: %.4f°\n%s: %.4f°\n%s: %.4f°",
                                        TimeToString(aspect.time, TIME_DATE),
                                        aspect.planet1, aspect.planet2, aspect.aspect, groupLabel,
                                        TimeToString(aspect.time, TIME_MINUTES),
                                        greekTimezone, TimeToString(greekTime, TIME_MINUTES),
                                        TimeToString(singaporeTime, TIME_MINUTES),
                                        aspect.angle,
                                        aspect.planet1, aspect.planet1_lon,
                                        aspect.planet2, aspect.planet2_lon);
            
            ObjectSetString(0, objectName, OBJPROP_TOOLTIP, tooltip);
        }
        else
        {
            // Simplified tooltip for performance (includes SGT for user convenience)
            // aspect.time is now in UTC after CSV conversion
            datetime greekTime = GetGreekTime(aspect.time);
            datetime singaporeTime = aspect.time + 8 * 3600;
            
            string greekTimezone = IsGreekSummerTime(aspect.time) ? "EEST" : "EET";
            
            string groupType = GetPlanetGroupType(aspect.planet1, aspect.planet2);
            string groupLabel = "";
            if(groupType == "Luminaries") groupLabel = " [FAST]";
            else if(groupType == "Medium") groupLabel = " [MEDIUM]";
            else if(groupType == "Slow") groupLabel = " [LONG-TERM]";
            
            string tooltip = StringFormat("%s %s-%s %s%s\nUTC: %s\n%s: %s\nSGT: %s\nAngle: %.2f°",
                                        TimeToString(aspect.time, TIME_DATE),
                                        aspect.planet1, aspect.planet2, aspect.aspect, groupLabel,
                                        TimeToString(aspect.time, TIME_MINUTES),
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
    if(aspect.aspect == "Semisquare" || aspect.aspect == "Gann109" || aspect.aspect == "Gann74")
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
                // Full label tooltip only when performance mode is disabled
                datetime greekTime = GetGreekTime(aspect.time);
                datetime singaporeTime = aspect.time + 8 * 3600;
                
                string greekTimezone = IsGreekSummerTime(aspect.time) ? "EEST" : "EET";
                
                string labelTooltip = StringFormat("%s\n%s-%s %s\nUTC: %s\n%s: %s\nSGT: %s\n%.4f° (Target: %s)\nPrecision: ±%.4f°",
                                                 TimeToString(aspect.time, TIME_DATE),
                                                 aspect.planet1, aspect.planet2, aspect.aspect,
                                                 TimeToString(aspect.time, TIME_MINUTES),
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
    if(aspect == "Gann109") return "109°";    // Gann 109° target angle
    if(aspect == "Gann74") return "74°";      // Gann 74° target angle
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
    else if(aspect == "Gann109") targetAngle = 109;  // Gann 109° precision
    else if(aspect == "Gann74") targetAngle = 74;    // Gann 74° precision
    
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
    else if(aspectType == "Gann109") expectedAngle = 109;
    else if(aspectType == "Gann74") expectedAngle = 74;
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
    Print("=== JUNE 30, 2025 ASPECT DIAGNOSIS ===");
    
    datetime targetDate = D'2025.06.30 00:00:00';
    datetime targetStart = targetDate;
    datetime targetEnd = targetDate + 24 * 3600; // Full day
    
    Print("Searching for aspects on June 30, 2025...");
    Print("Target date range: ", TimeToString(targetStart), " to ", TimeToString(targetEnd));
    Print("");
    
    bool found = false;
    for(int i = 0; i < aspectCount; i++)
    {
        if(aspects[i].time >= targetStart && aspects[i].time < targetEnd)
        {
            found = true;
            Print("FOUND JUNE 30 ASPECT:");
            Print("  ", aspects[i].planet1, "-", aspects[i].planet2, " ", aspects[i].aspect);
            Print("  CSV Time (UTC", CSVTimezoneOffset >= 0 ? "+" : "", CSVTimezoneOffset, "): ", TimeToString(aspects[i].time));
            
            // Show what this time would be in various timezones
            datetime utcTime = aspects[i].time;
            datetime greekTime = GetGreekTime(utcTime);
            datetime sgtTime = utcTime + 8 * 3600;
            
            Print("  UTC Time: ", TimeToString(utcTime));
            Print("  Greek Time: ", TimeToString(greekTime), " (", IsGreekSummerTime(utcTime) ? "EEST" : "EET", ")");
            Print("  Singapore Time: ", TimeToString(sgtTime), " (SGT)");
            Print("  Angle: ", DoubleToString(aspects[i].angle, 2), "°");
            Print("");
            
            // Validate this specific aspect
            ValidateSpecificAspect(aspects[i]);
        }
    }
    
    if(!found)
    {
        Print("No aspects found for June 30, 2025.");
        Print("This could mean:");
        Print("1. No aspects occur on this date in your CSV");
        Print("2. Timezone conversion is pushing the aspects to different dates");
        Print("3. CSV data doesn't cover this date range");
        Print("");
        Print("Try checking June 29 or July 1, 2025 as well.");
    }
    
    Print("=== END JUNE 30 DIAGNOSIS ===");
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
    Print("Current date: June 30, 2025 (TODAY!)");
    Print("");
    
    datetime now = TimeCurrent();
    Print("Current UTC time: ", TimeToString(now));
    Print("Current Greek time: ", TimeToString(GetGreekTime(now)), " (", IsGreekSummerTime(now) ? "EEST" : "EET", ")");
    Print("Current Singapore time: ", TimeToString(now + 8 * 3600), " (SGT)");
    Print("");
    
    // Find today's aspects
    datetime todayStart = D'2025.06.30 00:00:00';
    datetime todayEnd = D'2025.06.30 23:59:59';
    
    Print("CSV ASPECTS FOR TODAY (June 30, 2025):");
    Print("=======================================");
    
    bool foundToday = false;
    for(int i = 0; i < aspectCount; i++)
    {
        if(aspects[i].time >= todayStart && aspects[i].time <= todayEnd)
        {
            foundToday = true;
            datetime aspectUTC = aspects[i].time;
            datetime aspectGreek = GetGreekTime(aspectUTC);
            datetime aspectSGT = aspectUTC + 8 * 3600;
            
            Print("");
            Print("ASPECT: ", aspects[i].planet1, "-", aspects[i].planet2, " ", aspects[i].aspect);
            Print("CSV Time (as UTC): ", TimeToString(aspectUTC));
            Print("Greek Time: ", TimeToString(aspectGreek), " (", IsGreekSummerTime(aspectUTC) ? "EEST" : "EET", ")");
            Print("Singapore Time: ", TimeToString(aspectSGT), " (SGT)");
            Print("Planet longitudes: ", aspects[i].planet1, "=", DoubleToString(aspects[i].planet1_lon, 2), "°, ",
                  aspects[i].planet2, "=", DoubleToString(aspects[i].planet2_lon, 2), "°");
            
            // Check timing relative to now
            double hoursFromNow = (aspectUTC - now) / 3600.0;
            Print("Time from now: ", DoubleToString(hoursFromNow, 1), " hours");
            
            if(hoursFromNow > -24 && hoursFromNow < 24)
            {
                Print(">>> THIS ASPECT IS VERY CLOSE TO CURRENT TIME! <<<");
                Print(">>> PERFECT FOR TIMEZONE VALIDATION <<<");
                
                // Test different timezone assumptions
                Print("");
                Print("TIMEZONE ANALYSIS:");
                Print("If CSV is in UTC (offset 0): Aspect time = ", TimeToString(aspectUTC));
                Print("If CSV is in Greek time (offset 3): Aspect time = ", TimeToString(aspectUTC - 3*3600));
                Print("If CSV is in Singapore time (offset 8): Aspect time = ", TimeToString(aspectUTC - 8*3600));
                Print("");
                Print("VERIFICATION STEPS:");
                Print("1. Check Swiss Ephemeris NOW for current planet positions");
                Print("2. Compare with the longitudes shown above");
                Print("3. The timezone that makes the positions match is CORRECT");
                
                // Generate Swiss Ephemeris check for current time
                Print("");
                GenerateSwissEphemerisCheckForNow();
            }
        }
    }
    
    if(!foundToday)
    {
        Print("No aspects found for today in CSV data.");
        Print("This suggests either:");
        Print("1. No major aspects occur today");
        Print("2. Timezone conversion is moving aspects to different dates");
        Print("3. CSV data range doesn't include today");
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
//| Get planet group type for visual distinction                    |
//+------------------------------------------------------------------+
string GetPlanetGroupType(string planet1, string planet2)
{
    bool planet1_luminary = IsPlanetInGroup(planet1, "Luminaries");
    bool planet1_medium = IsPlanetInGroup(planet1, "Medium");
    bool planet1_slow = IsPlanetInGroup(planet1, "Slow");
    
    bool planet2_luminary = IsPlanetInGroup(planet2, "Luminaries");
    bool planet2_medium = IsPlanetInGroup(planet2, "Medium");
    bool planet2_slow = IsPlanetInGroup(planet2, "Slow");
    
    // Debug output for first few calls
    static int debugCount = 0;
    if(debugCount < 3)
    {
        Print("DEBUG GetPlanetGroupType: ", planet1, " (lum:", planet1_luminary, " med:", planet1_medium, " slow:", planet1_slow, ") - ", 
              planet2, " (lum:", planet2_luminary, " med:", planet2_medium, " slow:", planet2_slow, ")");
        debugCount++;
    }
    
    // Determine group type based on planets involved
    if(planet1_luminary || planet2_luminary)
        return "Luminaries";  // Fast timing - Sun/Moon with any planet
    else if(planet1_medium && planet2_medium)
        return "Medium";      // Medium timing - Mercury/Venus/Mars among themselves
    else if(planet1_slow && planet2_slow)
        return "Slow";        // Long-term timing - Jupiter-Pluto among themselves
    
    return "Unknown";
}

//+------------------------------------------------------------------+
//| Get group-specific color (if distinction is enabled)           |
//+------------------------------------------------------------------+
color GetGroupColor(string planet1, string planet2, string aspect)
{
    if(!DistinguishPlanetGroups)
    {
        // Use original aspect-based colors when group distinction is disabled
        return GetAspectColor(aspect);
    }
    
    string groupType = GetPlanetGroupType(planet1, planet2);
    
    if(groupType == "Luminaries")
        return LuminariesLineColor;  // Use input parameter color
    else if(groupType == "Medium")
        return MediumTermLineColor;  // Use input parameter color
    else if(groupType == "Slow")
        return SlowPlanetsLineColor; // Use input parameter color
    
    // Fallback to aspect color for unknown groups
    return GetAspectColor(aspect);
}

//+------------------------------------------------------------------+
//| Get group-specific line width (if distinction is enabled)      |
//+------------------------------------------------------------------+
int GetGroupLineWidth(string planet1, string planet2)
{
    if(!DistinguishPlanetGroups)
    {
        // Use default line width when group distinction is disabled
        return LineWidth;
    }
    
    string groupType = GetPlanetGroupType(planet1, planet2);
    
    if(groupType == "Luminaries")
        return LuminariesLineWidth;
    else if(groupType == "Medium")
        return MediumTermLineWidth;
    else if(groupType == "Slow")
        return SlowPlanetsLineWidth;
    
    // Fallback to default width for unknown groups
    return LineWidth;
}

//+------------------------------------------------------------------+
//| Get group-specific line style (if distinction is enabled)      |
//+------------------------------------------------------------------+
ENUM_LINE_STYLE GetGroupLineStyle(string planet1, string planet2, string aspect)
{
    if(!DistinguishPlanetGroups)
    {
        // Use original aspect-based styles when group distinction is disabled
        return GetAspectStyle(aspect);
    }
    
    string groupType = GetPlanetGroupType(planet1, planet2);
    
    // Debug output for first few calls
    static int debugCount = 0;
    if(debugCount < 5)
    {
        Print("DEBUG GetGroupLineStyle: ", planet1, "-", planet2, " = ", groupType, " group");
        if(groupType == "Luminaries")
        {
            Print("  Returning LuminariesLineStyle = ", (int)LuminariesLineStyle, " (STYLE_DOT = ", (int)STYLE_DOT, ")");
        }
        else if(groupType == "Medium")
        {
            Print("  Returning MediumTermLineStyle = ", (int)MediumTermLineStyle, " (STYLE_DASH = ", (int)STYLE_DASH, ")");
        }
        else if(groupType == "Slow")
        {
            Print("  Returning SlowPlanetsLineStyle = ", (int)SlowPlanetsLineStyle, " (STYLE_SOLID = ", (int)STYLE_SOLID, ")");
        }
        debugCount++;
    }
    
    if(groupType == "Luminaries")
    {
        Print("  DEBUG: Setting Luminaries to width 1, red color");
        return STYLE_SOLID;  // Use solid but make them distinguishable by width/color
    }
    else if(groupType == "Medium")
    {
        Print("  DEBUG: Setting Medium to width 2, yellow");  
        return STYLE_SOLID; 
    }
    else if(groupType == "Slow")
    {
        Print("  DEBUG: Setting Slow to width 3, cyan");
        return STYLE_SOLID; 
    }
    
    // Fallback to aspect style for unknown groups
    return GetAspectStyle(aspect);
}

//+------------------------------------------------------------------+
//| Chart event handler - ENHANCED TIMEFRAME DETECTION             |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   static ENUM_TIMEFRAMES last_timeframe = PERIOD_CURRENT;
   ENUM_TIMEFRAMES current_timeframe = Period();
   
   // Redraw on chart changes OR timeframe changes
   if(id == CHARTEVENT_CHART_CHANGE || 
      (current_timeframe != last_timeframe))
   {
      Print("🔄 MajorAspects Redrawing - Event: ", 
            (id == CHARTEVENT_CHART_CHANGE ? "Chart Change" : "Timeframe Change"),
            " (", EnumToString(current_timeframe), ")");
      
      // Clear all aspect objects and force recalculation
      ObjectsDeleteAll(0, "ASPECT_");
      g_aspects_drawn = false; // Reset drawing state
      
      // Force immediate recalculation by resetting update tracking
      static int force_update_bar = 0;
      force_update_bar = 0; // Reset to force update
      
      last_timeframe = current_timeframe;
      ChartRedraw(0);
   }
}

//+------------------------------------------------------------------+