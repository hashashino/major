//+------------------------------------------------------------------+
//|                                    MultiSymbolPlanetaryAspects.mq5 |
//|                           Multi-Symbol Planetary Aspects Indicator |
//|                     Automatically detects law of vibration for any symbol |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Multi-Symbol Planetary Aspects"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

//--- SYMBOL CONFIGURATION INPUTS
input string SymbolToAnalyze = "";              // Symbol (empty = current chart symbol)

//--- CSV FILE INPUTS  
input bool UseIndividualFiles = true;         // Use individual symbol files (recommended)
input string PlanetaryAspectsCSV = "all_symbols_timing_aspects.csv";  // Combined file (huge, not recommended)
input int CSVTimezoneOffset = 0;              // CSV timezone offset from UTC

//--- ASPECT TYPE FILTERS
input bool ShowConjunction = true;            // Show Conjunction aspects
input bool ShowSemisquare = true;             // Show Semisquare (45°) aspects
input bool ShowSextile = true;                // Show Sextile aspects
input bool ShowSquare = true;                 // Show Square aspects
input bool ShowTrine = true;                  // Show Trine aspects
input bool ShowGannHigh = true;               // Show Dynamic Gann High aspects
input bool ShowOpposition = true;             // Show Opposition aspects
input bool ShowGannLow = true;                // Show Dynamic Gann Low aspects

//--- PLANET FILTERS
input bool ShowSun = true;                    // Show Sun aspects
input bool ShowMoon = true;                   // Show Moon aspects
input bool ShowMercury = true;                // Show Mercury aspects
input bool ShowVenus = true;                  // Show Venus aspects
input bool ShowMars = true;                   // Show Mars aspects
input bool ShowJupiter = false;               // Show Jupiter aspects
input bool ShowSaturn = false;                // Show Saturn aspects
input bool ShowUranus = false;                // Show Uranus aspects
input bool ShowNeptune = false;               // Show Neptune aspects
input bool ShowPluto = false;                 // Show Pluto aspects

//--- DISPLAY SETTINGS
input color ConjunctionColor = clrYellow;     // Conjunction color
input color SemisquareColor = clrOrange;      // Semisquare color
input color SextileColor = clrLime;           // Sextile color
input color SquareColor = clrRed;             // Square color
input color TrineColor = clrBlue;             // Trine color
input color GannHighColor = clrCyan;          // Dynamic Gann High color
input color OppositionColor = clrMagenta;     // Opposition color
input color GannLowColor = clrGold;           // Dynamic Gann Low color

input int FontSize = 8;                       // Text font size
input color TextColor = clrWhite;             // Text color
input bool ShowAspectLabels = true;           // Show aspect labels

//--- PERFORMANCE SETTINGS
input bool PerformanceMode = true;            // Enable performance optimization
input int MaxAspectsToShow = 10000;           // Maximum aspects to display (increased for full visibility)
input int LookAheadDays = 365;                // Days to look ahead (1 year future)
input int LookBackDays = 365;                 // Days to look back (1 year past)

// Simple timing aspect structure (timing only)

// Planetary timing aspect structure (timing only)
struct PlanetaryTimingAspect
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
    string symbol;
};

// Global variables
PlanetaryTimingAspect g_aspects[];
int g_aspect_count = 0;
string g_current_symbol;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== SIMPLE PLANETARY TIMING INDICATOR ===");
    
    // Determine which symbol to analyze
    g_current_symbol = (SymbolToAnalyze == "") ? Symbol() : SymbolToAnalyze;
    Print("Symbol: ", g_current_symbol);
    
    // Load planetary timing aspects (ONLY THING WE DO)
    if(!LoadPlanetaryTimingAspects())
    {
        Print("ERROR: Failed to load planetary timing aspects");
        return INIT_FAILED;
    }
    
    Print("SUCCESS: Loaded ", g_aspect_count, " timing aspects for ", g_current_symbol);
    
    return INIT_SUCCEEDED;
}



//+------------------------------------------------------------------+
//| Load planetary timing aspects from CSV                         |
//+------------------------------------------------------------------+
bool LoadPlanetaryTimingAspects()
{
    string filename;
    
    if(UseIndividualFiles)
    {
        // Use individual symbol file (much faster for large datasets)
        string clean_symbol = g_current_symbol;
        // Remove trailing dash or dot from symbol for filename
        if(StringLen(clean_symbol) > 0)
        {
            string last_char = StringSubstr(clean_symbol, StringLen(clean_symbol)-1, 1);
            if(last_char == "-" || last_char == ".")
                clean_symbol = StringSubstr(clean_symbol, 0, StringLen(clean_symbol)-1);
        }
        filename = clean_symbol + "_timing_aspects.csv";
        Print("Using individual file: ", filename);
    }
    else
    {
        // Use combined file (slow for large datasets)
        filename = PlanetaryAspectsCSV;
        Print("Using combined file: ", filename, " (may be slow)");
    }
    
    int file_handle = FileOpen(filename, FILE_READ | FILE_TXT | FILE_ANSI);
    
    if(file_handle == INVALID_HANDLE)
    {
        Print("ERROR: Cannot open timing aspects file: ", filename);
        return false;
    }
    
    g_aspect_count = 0;
    ArrayResize(g_aspects, 50000); // Reserve space for aspects (increased for individual files)
    
    string header = FileReadString(file_handle); // Skip header
    Print("CSV Header: ", header);
    
    bool filter_by_symbol = !UseIndividualFiles; // Only filter if using combined file
    string clean_current_symbol = "";
    
    // Calculate time range for pre-filtering (always available)
    datetime current_time = TimeCurrent();
    datetime filter_start = current_time - LookBackDays * 24 * 3600;
    datetime filter_end = current_time + LookAheadDays * 24 * 3600;
    
    if(filter_by_symbol)
    {
        // Clean current symbol for matching in combined file
        clean_current_symbol = g_current_symbol;
        if(StringLen(clean_current_symbol) > 0)
        {
            string last_char = StringSubstr(clean_current_symbol, StringLen(clean_current_symbol)-1, 1);
            if(last_char == "-" || last_char == ".")
                clean_current_symbol = StringSubstr(clean_current_symbol, 0, StringLen(clean_current_symbol)-1);
        }
        Print("Looking for symbol: '", clean_current_symbol, "' (original: '", g_current_symbol, "')");
    }
    else
    {
        Print("Loading aspects from individual file");
        Print("Time filter range: ", TimeToString(filter_start), " to ", TimeToString(filter_end));
    }
    
    int line_count = 0;
    string symbols_found = "";
    
    while(!FileIsEnding(file_handle))
    {
        string line = FileReadString(file_handle);
        if(line == "") continue;
        
        line_count++;
        string fields[];
        int field_count = StringSplit(line, ',', fields);
        
        // Expected CSV format: date,time,planet1,planet2,aspect,aspect_abbrev,angle,planet1_lon,planet2_lon,description,symbol
        if(field_count >= 11)
        {
            string csv_symbol = fields[10]; // symbol field
            
            // Debug: show first few symbols found (only for combined file)
            if(filter_by_symbol && line_count <= 5)
            {
                Print("Line ", line_count, " symbol: '", csv_symbol, "'");
            }
            
            // Load aspect if: using individual file OR symbol matches in combined file
            bool should_load = !filter_by_symbol || (csv_symbol == clean_current_symbol);
            
            if(should_load)
            {
                // Parse date and time
                string date_str = fields[0];
                string time_str = fields[1];
                
                // Convert date format from YYYY.MM.DD to datetime
                string date_parts[];
                if(StringSplit(date_str, '.', date_parts) == 3)
                {
                    string time_parts[];
                    if(StringSplit(time_str, ':', time_parts) == 2)
                    {
                        datetime aspect_time = StringToTime(date_parts[0] + "." + date_parts[1] + "." + date_parts[2] + " " + time_str);
                        
                        // Pre-filter by time range during loading (much more efficient)
                        if(UseIndividualFiles)
                        {
                            if(aspect_time < filter_start || aspect_time > filter_end)
                                continue; // Skip aspects outside time range
                        }
                        
                        // Check array bounds before adding
                        if(g_aspect_count >= ArraySize(g_aspects))
                        {
                            Print("WARNING: Reached maximum array size (", ArraySize(g_aspects), "). Stopping loading to prevent crash.");
                            break;
                        }
                        
                        g_aspects[g_aspect_count].time = aspect_time;
                        g_aspects[g_aspect_count].planet1 = fields[2];
                        g_aspects[g_aspect_count].planet2 = fields[3];
                        g_aspects[g_aspect_count].aspect = fields[4];
                        g_aspects[g_aspect_count].aspect_abbrev = fields[5];
                        g_aspects[g_aspect_count].angle = StringToDouble(fields[6]);
                        g_aspects[g_aspect_count].planet1_lon = StringToDouble(fields[7]);
                        g_aspects[g_aspect_count].planet2_lon = StringToDouble(fields[8]);
                        g_aspects[g_aspect_count].description = fields[9];
                        g_aspects[g_aspect_count].symbol = csv_symbol;
                        
                        g_aspect_count++;
                        
                        // Debug: show progress every 1000 aspects
                        if(g_aspect_count % 1000 == 0)
                        {
                            Print("Loaded ", g_aspect_count, " aspects...");
                        }
                    }
                }
            }
        }
    }
    
    FileClose(file_handle);
    ArrayResize(g_aspects, g_aspect_count);
    
    Print("✓ Loaded ", g_aspect_count, " timing aspects from ", filename);
    return (g_aspect_count > 0);
}



//+------------------------------------------------------------------+
//| Check if aspect should be shown based on filters               |
//+------------------------------------------------------------------+
bool ShouldShowAspect(const PlanetaryTimingAspect &aspect)
{
    // Check aspect type filter
    bool show_aspect_type = false;
    if(aspect.aspect == "Conjunction" && ShowConjunction) show_aspect_type = true;
    else if(aspect.aspect == "Semisquare" && ShowSemisquare) show_aspect_type = true;
    else if(aspect.aspect == "Sextile" && ShowSextile) show_aspect_type = true;
    else if(aspect.aspect == "Square" && ShowSquare) show_aspect_type = true;
    else if(aspect.aspect == "Trine" && ShowTrine) show_aspect_type = true;
    else if(aspect.aspect == "GannHigh" && ShowGannHigh) show_aspect_type = true;
    else if(aspect.aspect == "Opposition" && ShowOpposition) show_aspect_type = true;
    else if(aspect.aspect == "GannLow" && ShowGannLow) show_aspect_type = true;
    
    if(!show_aspect_type) return false;
    
    // Check planet filter for both planets in the aspect
    bool show_planet1 = false;
    bool show_planet2 = false;
    
    // Check planet1
    if(aspect.planet1 == "Sun" && ShowSun) show_planet1 = true;
    else if(aspect.planet1 == "Moon" && ShowMoon) show_planet1 = true;
    else if(aspect.planet1 == "Mercury" && ShowMercury) show_planet1 = true;
    else if(aspect.planet1 == "Venus" && ShowVenus) show_planet1 = true;
    else if(aspect.planet1 == "Mars" && ShowMars) show_planet1 = true;
    else if(aspect.planet1 == "Jupiter" && ShowJupiter) show_planet1 = true;
    else if(aspect.planet1 == "Saturn" && ShowSaturn) show_planet1 = true;
    else if(aspect.planet1 == "Uranus" && ShowUranus) show_planet1 = true;
    else if(aspect.planet1 == "Neptune" && ShowNeptune) show_planet1 = true;
    else if(aspect.planet1 == "Pluto" && ShowPluto) show_planet1 = true;
    
    // Check planet2
    if(aspect.planet2 == "Sun" && ShowSun) show_planet2 = true;
    else if(aspect.planet2 == "Moon" && ShowMoon) show_planet2 = true;
    else if(aspect.planet2 == "Mercury" && ShowMercury) show_planet2 = true;
    else if(aspect.planet2 == "Venus" && ShowVenus) show_planet2 = true;
    else if(aspect.planet2 == "Mars" && ShowMars) show_planet2 = true;
    else if(aspect.planet2 == "Jupiter" && ShowJupiter) show_planet2 = true;
    else if(aspect.planet2 == "Saturn" && ShowSaturn) show_planet2 = true;
    else if(aspect.planet2 == "Uranus" && ShowUranus) show_planet2 = true;
    else if(aspect.planet2 == "Neptune" && ShowNeptune) show_planet2 = true;
    else if(aspect.planet2 == "Pluto" && ShowPluto) show_planet2 = true;
    
    return (show_planet1 && show_planet2); // Both planets must be enabled
}

//+------------------------------------------------------------------+
//| Get aspect color                                               |
//+------------------------------------------------------------------+
color GetAspectColor(string aspect_type)
{
    if(aspect_type == "Conjunction") return ConjunctionColor;
    if(aspect_type == "Semisquare") return SemisquareColor;
    if(aspect_type == "Sextile") return SextileColor;
    if(aspect_type == "Square") return SquareColor;
    if(aspect_type == "Trine") return TrineColor;
    if(aspect_type == "GannHigh") return GannHighColor;
    if(aspect_type == "Opposition") return OppositionColor;
    if(aspect_type == "GannLow") return GannLowColor;
    return clrGray;
}

//+------------------------------------------------------------------+
//| Main calculation function                                       |
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
    // Clear previous aspect objects
    ObjectsDeleteAll(0, "PLANETARY_ASPECT_");
    
    // Determine time range for aspect display
    datetime current_time = TimeCurrent();
    datetime start_time = current_time - LookBackDays * 24 * 3600;
    datetime end_time = current_time + LookAheadDays * 24 * 3600;
    
    int aspects_drawn = 0;
    
    // Draw planetary aspects within the time range
    for(int i = 0; i < g_aspect_count && aspects_drawn < MaxAspectsToShow; i++)
    {
        if(g_aspects[i].time >= start_time && g_aspects[i].time <= end_time)
        {
            if(ShouldShowAspect(g_aspects[i]))
            {
                DrawPlanetaryAspect(g_aspects[i], aspects_drawn);
                aspects_drawn++;
            }
        }
    }
    
    // Simple chart comment
    Comment(StringFormat("%s | Aspects: %d", g_current_symbol, aspects_drawn));
    
    return rates_total;
}

//+------------------------------------------------------------------+
//| Draw planetary timing aspect line                              |
//+------------------------------------------------------------------+
void DrawPlanetaryAspect(const PlanetaryTimingAspect &aspect, int index)
{
    string object_name = "PLANETARY_ASPECT_" + IntegerToString(index);
    
    if(ObjectCreate(0, object_name, OBJ_VLINE, 0, aspect.time, 0))
    {
        ObjectSetInteger(0, object_name, OBJPROP_COLOR, GetAspectColor(aspect.aspect));
        ObjectSetInteger(0, object_name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, object_name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, object_name, OBJPROP_BACK, true);
        
        // Create tooltip with timing information only
        string tooltip = StringFormat("%s-%s %s\nTime: %s\nAngle: %.1f°\n%s: %.1f° | %s: %.1f°\nSymbol: %s",
                                    aspect.planet1,
                                    aspect.planet2,
                                    aspect.aspect,
                                    TimeToString(aspect.time, TIME_MINUTES),
                                    aspect.angle,
                                    aspect.planet1,
                                    aspect.planet1_lon,
                                    aspect.planet2,
                                    aspect.planet2_lon,
                                    aspect.symbol);
        
        ObjectSetString(0, object_name, OBJPROP_TOOLTIP, tooltip);
        
        // Add text label if enabled
        if(ShowAspectLabels)
        {
            string label_name = object_name + "_LABEL";
            double label_price = (ChartGetDouble(0, CHART_PRICE_MAX) + ChartGetDouble(0, CHART_PRICE_MIN)) / 2;
            
            if(ObjectCreate(0, label_name, OBJ_TEXT, 0, aspect.time, label_price))
            {
                ObjectSetString(0, label_name, OBJPROP_TEXT, aspect.aspect_abbrev);
                ObjectSetInteger(0, label_name, OBJPROP_COLOR, TextColor);
                ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, FontSize);
                ObjectSetInteger(0, label_name, OBJPROP_ANCHOR, ANCHOR_UPPER);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Indicator deinitialization function                            |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up timing aspect objects only
    ObjectsDeleteAll(0, "PLANETARY_ASPECT_");
    
    Comment("");
    
    Print("Multi-Symbol Planetary Timing Indicator deinitialized");
}

//+------------------------------------------------------------------+