//+------------------------------------------------------------------+
//|                                                 MajorAspects.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "3.00"
#property indicator_chart_window
#property indicator_plots 0

// Swiss Ephemeris DLL imports - using local file
#import "c:\\Trading\\major\\swedll32.dll"
   void swe_set_ephe_path(string path);
   int swe_calc_ut(double tjd_ut, int ipl, int iflag, double &xx[], string serr);
   double swe_julday(int year, int month, int day, double hour, int gregflag);
   void swe_close();
   string swe_get_planet_name(int ipl, string spname);
#import

// Swiss Ephemeris planet constants
#define SE_SUN          0
#define SE_MOON         1
#define SE_MERCURY      2
#define SE_VENUS        3
#define SE_MARS         4
#define SE_JUPITER      5
#define SE_SATURN       6
#define SE_URANUS       7
#define SE_NEPTUNE      8
#define SE_PLUTO        9

// Swiss Ephemeris calculation flags
#define SEFLG_SWIEPH    2     // Use Swiss Ephemeris
#define SEFLG_SPEED     256   // Calculate speed

// Structure to hold aspect data
struct AspectData
{
   datetime date;
   string   description;
   color    line_color;
   bool     verified;
   double   exact_angle;
   double   orb_tolerance;
};

// Major aspects data with better dates from Swiss Ephemeris research
AspectData aspects[] = 
{
   {D'2020.12.21 18:22', "Jupiter-Saturn Conj", clrRed, false, 0.0, 1.0},
   {D'2021.06.14 10:00', "Saturn-Uranus Sq", clrBlue, false, 0.0, 2.0},
   {D'2022.04.12 14:00', "Jupiter-Neptune Conj", clrGreen, false, 0.0, 1.0},
   {D'2024.04.20 21:00', "Jupiter-Uranus Conj", clrOrange, false, 0.0, 1.0},
   {D'2025.03.01 12:00', "Saturn-Pluto Conj", clrPurple, false, 0.0, 1.5},
   {D'2025.08.11 08:00', "Saturn-Uranus Sext", clrYellow, false, 0.0, 2.0},
   {D'2025.08.11 16:00', "Uranus-Neptune Sext", clrCyan, false, 0.0, 2.0},
   {D'2026.07.20 12:00', "Jupiter-Neptune Trine", clrAqua, false, 0.0, 1.5},
   {D'2026.07.20 18:00', "Jupiter-Pluto Opp", clrLightBlue, false, 0.0, 1.5},
   {D'2027.06.28 09:00', "Neptune-Pluto Sext", clrMagenta, false, 0.0, 2.0}
};

input bool ShowVerticalLines = true;        // Show vertical lines
input bool ShowLabels = true;               // Show aspect labels
input int  LineWidth = 2;                   // Line width
input ENUM_LINE_STYLE LineStyle = STYLE_SOLID; // Line style
input bool VerifyAspects = true;            // Verify existing aspects on init
input bool GenerateNewAspects = false;      // Generate new aspects for date range
input datetime StartDate = D'2025.01.01';   // Start date for generation
input datetime EndDate = D'2027.12.31';     // End date for generation
input double AspectOrb = 1.0;               // Orb in degrees for aspect detection
input string EphePath = "c:\\Trading\\major\\"; // Path to Swiss Ephemeris data files (current folder)

bool swiss_ephe_initialized = false;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME, "Major Aspects v3.0 (Swiss Ephemeris)");
   
   // Initialize Swiss Ephemeris
   if(!InitializeSwissEphemeris())
   {
      Print("ERROR: Swiss Ephemeris initialization failed!");
      Print("Swiss Ephemeris files found in: ", EphePath);
      Print("Files: swedll32.dll, sepl_18.se1, semo_18.se1");
      return(INIT_FAILED);
   }
   
   if(VerifyAspects)
   {
      Print("=== VERIFYING ASPECTS WITH SWISS EPHEMERIS ===");
      VerifyAspectsWithSwissEph();
   }
   
   if(GenerateNewAspects)
   {
      Print("=== GENERATING NEW ASPECTS WITH SWISS EPHEMERIS ===");
      GenerateAspectsWithSwissEph(StartDate, EndDate);
   }
   
   // Remove all existing objects created by this indicator
   RemoveAllObjects();
   
   // Draw all aspects
   DrawMajorAspects();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Initialize Swiss Ephemeris                                      |
//+------------------------------------------------------------------+
bool InitializeSwissEphemeris()
{
   // Set ephemeris path to current folder
   swe_set_ephe_path(EphePath);
   
   // Test calculation to verify Swiss Ephemeris is working
   double tjd = swe_julday(2020, 12, 21, 18.0, 1); // Jupiter-Saturn conjunction
   double xx[6];
   string serr = "";
   
   int ret = swe_calc_ut(tjd, SE_JUPITER, SEFLG_SWIEPH, xx, serr);
   
   if(ret < 0)
   {
      Print("Swiss Ephemeris test failed: ", serr);
      Print("Make sure the following files are in ", EphePath, ":");
      Print("- swedll32.dll");
      Print("- sepl_18.se1");
      Print("- semo_18.se1");
      return false;
   }
   
   swiss_ephe_initialized = true;
   Print("✓ Swiss Ephemeris initialized successfully");
   Print("✓ Using ephemeris data from: ", EphePath);
   Print("✓ Test calculation successful - Jupiter longitude: ", DoubleToString(xx[0], 4), "°");
   return true;
}

//+------------------------------------------------------------------+
//| Convert datetime to Julian Day for Swiss Ephemeris             |
//+------------------------------------------------------------------+
double DateTimeToJulianDay(datetime dt)
{
   MqlDateTime mdt;
   TimeToStruct(dt, mdt);
   
   double hour = mdt.hour + mdt.min/60.0 + mdt.sec/3600.0;
   return swe_julday(mdt.year, mdt.mon, mdt.day, hour, 1); // Gregorian calendar
}

//+------------------------------------------------------------------+
//| Get planetary longitude using Swiss Ephemeris                   |
//+------------------------------------------------------------------+
double GetPlanetaryLongitude(int planet, datetime date)
{
   if(!swiss_ephe_initialized) return -1;
   
   double tjd = DateTimeToJulianDay(date);
   double xx[6];
   string serr = "";
   
   int ret = swe_calc_ut(tjd, planet, SEFLG_SWIEPH, xx, serr);
   
   if(ret < 0)
   {
      Print("Error calculating planet ", planet, ": ", serr);
      return -1;
   }
   
   return xx[0]; // Longitude in degrees
}

//+------------------------------------------------------------------+
//| Calculate precise aspect angle between two planets              |
//+------------------------------------------------------------------+
double CalculatePreciseAspectAngle(double long1, double long2)
{
   double angle = MathAbs(long1 - long2);
   if(angle > 180.0) angle = 360.0 - angle;
   return angle;
}

//+------------------------------------------------------------------+
//| Get aspect type with precise orb checking                       |
//+------------------------------------------------------------------+
string GetPreciseAspectType(double angle, double orb = 1.0)
{
   if(MathAbs(angle - 0) <= orb) return "Conj";      // Conjunction
   if(MathAbs(angle - 45) <= orb) return "Semi";     // Semisquare
   if(MathAbs(angle - 60) <= orb) return "Sext";     // Sextile  
   if(MathAbs(angle - 90) <= orb) return "Sq";       // Square
   if(MathAbs(angle - 120) <= orb) return "Trine";   // Trine
   if(MathAbs(angle - 161) <= orb) return "G161";    // Gann 161°
   if(MathAbs(angle - 180) <= orb) return "Opp";     // Opposition
   if(MathAbs(angle - 207) <= orb) return "G207";    // Gann 207°
   
   return "";
}

//+------------------------------------------------------------------+
//| Get planet name for Swiss Ephemeris constant                   |
//+------------------------------------------------------------------+
string GetSwissPlanetName(int planet)
{
   switch(planet)
   {
      case SE_SUN: return "Sun";
      case SE_MOON: return "Moon";
      case SE_MERCURY: return "Mercury";
      case SE_VENUS: return "Venus";
      case SE_MARS: return "Mars";
      case SE_JUPITER: return "Jupiter";
      case SE_SATURN: return "Saturn";
      case SE_URANUS: return "Uranus";
      case SE_NEPTUNE: return "Neptune";
      case SE_PLUTO: return "Pluto";
      default: return "Unknown";
   }
}

//+------------------------------------------------------------------+
//| Get Swiss Ephemeris planet constant from name                   |
//+------------------------------------------------------------------+
int GetSwissPlanetConstant(string name)
{
   if(name == "Sun") return SE_SUN;
   if(name == "Moon") return SE_MOON;
   if(name == "Mercury") return SE_MERCURY;
   if(name == "Venus") return SE_VENUS;
   if(name == "Mars") return SE_MARS;
   if(name == "Jupiter") return SE_JUPITER;
   if(name == "Saturn") return SE_SATURN;
   if(name == "Uranus") return SE_URANUS;
   if(name == "Neptune") return SE_NEPTUNE;
   if(name == "Pluto") return SE_PLUTO;
   return -1;
}

//+------------------------------------------------------------------+
//| Verify existing aspects using Swiss Ephemeris                   |
//+------------------------------------------------------------------+
void VerifyAspectsWithSwissEph()
{
   int aspect_count = ArraySize(aspects);
   
   for(int i = 0; i < aspect_count; i++)
   {
      string planets_str = aspects[i].description;
      
      // Remove aspect type suffixes
      StringReplace(planets_str, " Conj", "");
      StringReplace(planets_str, " Semi", "");
      StringReplace(planets_str, " Sq", "");
      StringReplace(planets_str, " Sext", "");
      StringReplace(planets_str, " Trine", "");
      StringReplace(planets_str, " G161", "");
      StringReplace(planets_str, " Opp", "");
      StringReplace(planets_str, " G207", "");
      
      // Parse planet names
      string planet_names[];
      int split_count = StringSplit(planets_str, '-', planet_names);
      
      if(split_count == 2)
      {
         int planet1 = GetSwissPlanetConstant(planet_names[0]);
         int planet2 = GetSwissPlanetConstant(planet_names[1]);
         
         if(planet1 != -1 && planet2 != -1)
         {
            double long1 = GetPlanetaryLongitude(planet1, aspects[i].date);
            double long2 = GetPlanetaryLongitude(planet2, aspects[i].date);
            
            if(long1 >= 0 && long2 >= 0)
            {
               double angle = CalculatePreciseAspectAngle(long1, long2);
               string calc_aspect = GetPreciseAspectType(angle, aspects[i].orb_tolerance);
               
               aspects[i].exact_angle = angle;
               aspects[i].verified = (calc_aspect != "");
               
               Print("=== ASPECT VERIFICATION ===");
               Print("Date: ", TimeToString(aspects[i].date));
               Print("Listed: ", aspects[i].description);
               Print("Planet 1 (", planet_names[0], "): ", DoubleToString(long1, 4), "°");
               Print("Planet 2 (", planet_names[1], "): ", DoubleToString(long2, 4), "°");
               Print("Calculated: ", planet_names[0], "-", planet_names[1], " ", calc_aspect, " (", DoubleToString(angle, 4), "°)");
               Print("Status: ", (aspects[i].verified ? "✓ VERIFIED" : "✗ NEEDS REVIEW"));
               Print("Orb tolerance: ±", DoubleToString(aspects[i].orb_tolerance, 1), "°");
               Print("---");
            }
            else
            {
               Print("ERROR: Could not calculate positions for ", aspects[i].description, " on ", TimeToString(aspects[i].date));
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Generate new aspects using Swiss Ephemeris                      |
//+------------------------------------------------------------------+
void GenerateAspectsWithSwissEph(datetime start_date, datetime end_date)
{
   Print("Scanning for major aspects from ", TimeToString(start_date), " to ", TimeToString(end_date));
   Print("Using Swiss Ephemeris for precise calculations...");
   
   datetime current_date = start_date;
   int days_increment = 1; // Daily precision for accuracy
   
   // Fix array declaration syntax
   int major_planets[5] = {SE_JUPITER, SE_SATURN, SE_URANUS, SE_NEPTUNE, SE_PLUTO};
   
   while(current_date <= end_date)
   {
      // Check all major planet combinations
      for(int i = 0; i < 5; i++)
      {
         for(int j = i + 1; j < 5; j++)
         {
            CheckPlanetPairSwissEph(major_planets[i], major_planets[j], current_date);
         }
      }
      
      current_date += days_increment * 24 * 3600; // Add one day
   }
}

//+------------------------------------------------------------------+
//| Check aspect between two planets using Swiss Ephemeris         |
//+------------------------------------------------------------------+
void CheckPlanetPairSwissEph(int planet1, int planet2, datetime date)
{
   double long1 = GetPlanetaryLongitude(planet1, date);
   double long2 = GetPlanetaryLongitude(planet2, date);
   
   if(long1 >= 0 && long2 >= 0)
   {
      double angle = CalculatePreciseAspectAngle(long1, long2);
      string aspect_type = GetPreciseAspectType(angle, AspectOrb);
      
      if(aspect_type != "")
      {
         string planet1_name = GetSwissPlanetName(planet1);
         string planet2_name = GetSwissPlanetName(planet2);
         
         Print(TimeToString(date), ": ", planet1_name, "-", planet2_name, " ", aspect_type, 
               " (", DoubleToString(angle, 4), "°)");
         Print("  ", planet1_name, ": ", DoubleToString(long1, 4), "° | ", 
               planet2_name, ": ", DoubleToString(long2, 4), "°");
      }
   }
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Draw major aspects on chart                                     |
//+------------------------------------------------------------------+
void DrawMajorAspects()
{
   int aspectCount = ArraySize(aspects);
   
   for(int i = 0; i < aspectCount; i++)
   {
      // Check if the aspect date is within the chart's time range
      datetime chart_start = iTime(Symbol(), PERIOD_CURRENT, iBars(Symbol(), PERIOD_CURRENT) - 1);
      datetime chart_end = TimeCurrent();
      
      if(aspects[i].date >= chart_start && aspects[i].date <= chart_end)
      {
         string objectName = "MajorAspect_" + IntegerToString(i);
         
         // Modify color based on verification status
         color line_color = aspects[i].line_color;
         if(aspects[i].verified && aspects[i].exact_angle > 0)
         {
            // Verified aspects keep original colors
            line_color = aspects[i].line_color;
         }
         else if(!aspects[i].verified)
         {
            // Unverified aspects get dimmed colors
            line_color = clrGray;
         }
         
         // Draw vertical line if enabled
         if(ShowVerticalLines)
         {
            if(ObjectCreate(0, objectName + "_line", OBJ_VLINE, 0, aspects[i].date, 0))
            {
               ObjectSetInteger(0, objectName + "_line", OBJPROP_COLOR, line_color);
               ObjectSetInteger(0, objectName + "_line", OBJPROP_STYLE, LineStyle);
               ObjectSetInteger(0, objectName + "_line", OBJPROP_WIDTH, LineWidth);
               ObjectSetInteger(0, objectName + "_line", OBJPROP_BACK, true);
               
               string tooltip = aspects[i].description;
               if(aspects[i].exact_angle > 0)
               {
                  tooltip += " (" + DoubleToString(aspects[i].exact_angle, 4) + "°)";
               }
               if(aspects[i].verified)
               {
                  tooltip += " [SWISS EPH VERIFIED]";
               }
               else
               {
                  tooltip += " [UNVERIFIED]";
               }
               
               ObjectSetString(0, objectName + "_line", OBJPROP_TOOLTIP, tooltip);
            }
         }
         
         // Draw label if enabled
         if(ShowLabels)
         {
            int bar_shift = iBarShift(Symbol(), PERIOD_CURRENT, aspects[i].date);
            double price = (iHigh(Symbol(), PERIOD_CURRENT, bar_shift) + 
                           iLow(Symbol(), PERIOD_CURRENT, bar_shift)) / 2;
            
            if(ObjectCreate(0, objectName + "_label", OBJ_TEXT, 0, aspects[i].date, price))
            {
               string label_text = aspects[i].description;
               if(aspects[i].verified)
               {
                  label_text += " ✓";
               }
               else
               {
                  label_text += " ?";
               }
               
               ObjectSetString(0, objectName + "_label", OBJPROP_TEXT, label_text);
               ObjectSetInteger(0, objectName + "_label", OBJPROP_COLOR, line_color);
               ObjectSetInteger(0, objectName + "_label", OBJPROP_FONTSIZE, 8);
               ObjectSetString(0, objectName + "_label", OBJPROP_FONT, "Arial");
               ObjectSetInteger(0, objectName + "_label", OBJPROP_ANCHOR, ANCHOR_LEFT);
               ObjectSetInteger(0, objectName + "_label", OBJPROP_ANGLE, 90);
            }
         }
      }
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Remove all objects created by this indicator                    |
//+------------------------------------------------------------------+
void RemoveAllObjects()
{
   int objectsTotal = ObjectsTotal(0);
   
   for(int i = objectsTotal - 1; i >= 0; i--)
   {
      string objectName = ObjectName(0, i);
      if(StringFind(objectName, "MajorAspect_") == 0)
      {
         ObjectDelete(0, objectName);
      }
   }
}

//+------------------------------------------------------------------+
//| Indicator deinitialization function                             |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(swiss_ephe_initialized)
   {
      swe_close();
      Print("Swiss Ephemeris closed");
   }
   
   RemoveAllObjects();
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Chart event handler                                             |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      RemoveAllObjects();
      DrawMajorAspects();
   }
}