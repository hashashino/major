//+------------------------------------------------------------------+
//|                                            Price45Degrees.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//|                                                                  |
//| ENHANCED LONG-TERM vs SHORT-TERM VISUAL DISTINCTION:            |
//| 🔴 LONG-TERM: Red + ALL fractional levels (1/4,1/2,3/8,5/8)    |
//|     - Main red lines: VERY THICK (5px), Solid                  |
//|     - Bold Quarters (25%,75%): THICK (5px), Solid              |
//|     - Bold Eighths (37.5%,62.5%): THICK (5px), Solid           |
//|     - Bold Half (50%): THICK (5px), Solid - MAJOR LEVEL        |
//|     - Bold Special (12.5%,87.5%): THICK (5px), Solid           |
//| 🟡 SHORT-TERM: Yellow, THIN (1px), Dotted - Minor levels       |
//| Visual Impact: 5x thickness difference for clear distinction    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

//--- Enhanced Long-term vs Short-term Visual Distinction
input bool ShowHorizontalLines = true;     // Show horizontal lines at 45° intervals
input bool ShowRegularLines = true;        // Show regular 45° lines (SHORT-TERM - yellow thin)
input bool ShowBoldPatterns = true;        // Show bold patterns (LONG-TERM - red thick)
input bool ShowLongTermLines = true;       // Show long-term lines (red bold patterns - THICK)
input bool ShowShortTermLines = true;      // Show short-term lines (yellow regular patterns - THIN)
input bool ShowDecimalPatterns = true;     // Show Gann thirds patterns (blue)
input bool ShowGannEighths = true;         // Show Gann eighths (1/8, 3/8, 5/8, 7/8)
input bool ShowBlueEighths = true;         // Show blue eighths (37.5% & 62.5%) separately
input bool ShowBoldEighths = true;         // Show 37.5% & 62.5% between red bold lines
input bool ShowBoldQuarters = true;        // Show 25% & 75% between red bold lines  
input bool ShowBoldEighthsSpecial = true;  // Show 12.5% & 87.5% between red bold lines
input bool ShowGannQuarters = true;        // Show Gann quarters (1/4, 3/4)
input bool ShowGannHalf = true;            // Show Gann half (1/2 - 50%)
input color LineColor = clrYellow;          // Short-term line color (yellow - subtle)
input color BoldLineColor = clrRed;         // Long-term line color (red - prominent)
input color DecimalLineColor = clrBlue;    // Gann thirds pattern line color
input color EighthsLineColor = clrGreen;   // Gann eighths line color
input color SpecialEighthsLineColor = clrBrown; // Special eighths (12.5% & 87.5%) color
input color BlueEighthsLineColor = clrCyan; // Blue eighths (37.5% & 62.5%) color
input color BoldEighthsLineColor = clrMagenta; // Bold eighths (37.5% & 62.5% between red bold lines - LONG-TERM)
input color BoldQuartersLineColor = clrTeal; // Bold quarters (25% & 75% between red bold lines - LONG-TERM)
input color BoldEighthsSpecialLineColor = clrMaroon; // Bold special eighths (12.5% & 87.5% between red bold lines - LONG-TERM)
input color BoldHalfLineColor = clrViolet; // Bold half (50% between red bold lines - LONG-TERM MAJOR)
input color QuartersLineColor = clrOrange; // Gann quarters line color  
input color HalfLineColor = clrPurple;     // Gann half line color (50% between yellow lines - SHORT TERM)
input int LineWidth = 1;                    // Short-term line width (yellow lines - THIN)
input int BoldLineWidth = 5;                // Long-term line width (red bold patterns - VERY THICK)
input int DecimalLineWidth = 2;             // Decimal pattern line width
input int EighthsLineWidth = 1;             // Gann eighths line width
input int BoldEighthsLineWidth = 4;         // Bold eighths line width (LONG-TERM - thick)
input int BoldQuartersLineWidth = 4;        // Bold quarters line width (LONG-TERM - thick)
input int BoldEighthsSpecialLineWidth = 3;  // Bold special eighths line width (LONG-TERM - thick)
input int QuartersLineWidth = 2;            // Gann quarters line width
input int HalfLineWidth = 5;                // Gann half line width (VERY THICK for 50% emphasis)
input ENUM_LINE_STYLE LineStyle = STYLE_DOT; // Short-term line style (yellow lines - DOTTED for subtle appearance)
input ENUM_LINE_STYLE BoldLineStyle = STYLE_SOLID; // Long-term line style (red bold - SOLID for strong visibility)
input ENUM_LINE_STYLE DecimalLineStyle = STYLE_DASHDOT; // Decimal pattern line style
input ENUM_LINE_STYLE EighthsLineStyle = STYLE_DOT; // Gann eighths line style
input ENUM_LINE_STYLE BoldEighthsLineStyle = STYLE_SOLID; // Bold eighths line style (LONG-TERM - solid)
input ENUM_LINE_STYLE BoldQuartersLineStyle = STYLE_SOLID; // Bold quarters line style (LONG-TERM - solid)
input ENUM_LINE_STYLE BoldEighthsSpecialLineStyle = STYLE_SOLID; // Bold special eighths line style (LONG-TERM - solid)
input ENUM_LINE_STYLE QuartersLineStyle = STYLE_DASH; // Gann quarters line style
input ENUM_LINE_STYLE HalfLineStyle = STYLE_SOLID; // Gann half line style
input int PriceRange = 500;                 // Price range above/below current price to draw lines

//--- Enhanced Visual Distinction Controls
input int LongTermThicknessMultiplier = 5;  // Long-term line thickness multiplier (1=same, 5=5x thicker)
input bool EnhancedVisualMode = true;       // Enable enhanced visual distinction mode
input bool ForceRedraw = false;             // Force manual redraw (toggle on/off to refresh)
input int AutoRedrawSeconds = 60;           // Auto redraw interval in seconds (0=disabled)

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME, "Price 45° Degrees");
   
   // Print visual distinction summary
   PrintVisualDistinctionSummary();
   
   // Remove existing lines
   RemoveAllPriceLines();
   
   // Draw initial lines
   DrawPrice45DegreeLines();
   
   return(INIT_SUCCEEDED);
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
   // Redraw lines on new data or significant price movement
   static double last_price = 0;
   static ENUM_TIMEFRAMES last_calc_timeframe = PERIOD_CURRENT;
   static datetime last_redraw_time = 0;
   
   double current_price = close[rates_total-1];
   ENUM_TIMEFRAMES current_timeframe = Period();
   datetime current_time = TimeCurrent();
   
   bool should_redraw = false;
   string redraw_reason = "";
   
   // Check for significant price movement
   if(MathAbs(current_price - last_price) > (PriceRange * 0.1))
   {
      should_redraw = true;
      redraw_reason = "Price Movement";
      last_price = current_price;
   }
   
   // Check for timeframe change
   if(current_timeframe != last_calc_timeframe)
   {
      should_redraw = true;
      redraw_reason = "Timeframe Change in OnCalculate";
      last_calc_timeframe = current_timeframe;
   }
   
   // Force redraw if manual toggle is enabled or auto-refresh interval reached
   if(ForceRedraw || (AutoRedrawSeconds > 0 && current_time - last_redraw_time > AutoRedrawSeconds))
   {
      should_redraw = true;
      redraw_reason = ForceRedraw ? "Manual Force Redraw" : "Auto Refresh";
      last_redraw_time = current_time;
   }
   
   if(should_redraw)
   {
      Print("🔄 Redrawing lines - Reason: ", redraw_reason, 
            " | Price: ", DoubleToString(current_price, _Digits),
            " | Timeframe: ", EnumToString(current_timeframe));
      
      RemoveAllPriceLines();
      DrawPrice45DegreeLines();
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Draw horizontal lines at 45-degree price levels                |
//+------------------------------------------------------------------+
void DrawPrice45DegreeLines()
{
   if(!ShowHorizontalLines) return;
   
   double current_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   int digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
   
   Print("Current price: ", current_price, ", Digits: ", digits);
   
   int lines_drawn = 0;
   
   // Create lines for price ranges from 0 to 9999 (integer levels)
   for(double price = 0; price <= 9999; price += 1)
   {
      int price_int = (int)price;
      bool is_45_degree_level = false;
      int matched_degree = 0;
      
      // NEW: Check for continuous 45-degree arithmetic progression
      // Every 45 units starting from 0: 0, 45, 90, 135, 180, 225, 270, 315, 360, 405, 450, etc.
      if(price_int % 45 == 0)
      {
         is_45_degree_level = true;
         matched_degree = (price_int % 360); // Get the degree within 0-360 cycle
         if(matched_degree == 0 && price_int > 0) matched_degree = 360; // Handle 360° case
      }
      
      // ALSO check for your special patterns (900, 1800, 2250, etc.)
      bool is_bold = IsBoldPattern(price_int);
      if(is_bold)
      {
         is_45_degree_level = true;
         matched_degree = GetSpecialPatternDegree(price_int);
      }
      
      if(is_45_degree_level)
      {
         // Check toggles before drawing
         if(is_bold && !ShowBoldPatterns) continue;
         if(!is_bold && !ShowRegularLines) continue;
         
         // NEW: Check long-term and short-term toggles
         if(is_bold && !ShowLongTermLines) continue;    // Red bold lines = Long term
         if(!is_bold && !ShowShortTermLines) continue;  // Yellow lines = Short term
         
         string line_name = "Price45_" + IntegerToString(matched_degree) + "_" + IntegerToString(price_int);
         
         // Enhanced visual distinction: Apply thickness multiplier for long-term lines
         int line_width = is_bold ? (EnhancedVisualMode ? LineWidth * LongTermThicknessMultiplier : BoldLineWidth) : LineWidth;
         color line_color = is_bold ? BoldLineColor : LineColor;
         ENUM_LINE_STYLE line_style = is_bold ? BoldLineStyle : (EnhancedVisualMode ? STYLE_DOT : LineStyle);
         
         if(ObjectCreate(0, line_name, OBJ_HLINE, 0, 0, price))
         {
            // Set line properties
            ObjectSetInteger(0, line_name, OBJPROP_COLOR, line_color);
            ObjectSetInteger(0, line_name, OBJPROP_WIDTH, line_width);
            ObjectSetInteger(0, line_name, OBJPROP_STYLE, line_style);
            ObjectSetInteger(0, line_name, OBJPROP_BACK, true);
            
            // Create enhanced tooltip with clear timeframe distinction
            string timeframe_note = is_bold ? " ⭐ LONG-TERM (Major Support/Resistance)" : " ⚡ SHORT-TERM (Minor Level)";
            string pattern_note = is_bold ? " 🔴 SPECIAL 45° PATTERN" : " 🟡 Regular 45° Level";
            string line_thickness = is_bold ? " [THICK: " + IntegerToString(line_width) + "px]" : " [THIN: " + IntegerToString(line_width) + "px]";
            string tooltip = "45° Level: " + IntegerToString(matched_degree) + "°\nPrice: " + DoubleToString(price, digits) + 
                           pattern_note + timeframe_note + line_thickness;
            ObjectSetString(0, line_name, OBJPROP_TOOLTIP, tooltip);
            
            lines_drawn++;
            
            if(is_bold)
               Print("Drew 🔴 LONG-TERM THICK line at price ", DoubleToString(price, digits), " (", matched_degree, "°) - Width:", line_width, "px - MAJOR LEVEL");
            else
               Print("Drew 🟡 SHORT-TERM THIN line at price ", DoubleToString(price, digits), " (", matched_degree, "°) - Width:", line_width, "px - Minor level");
         }
      }
   }
   
   // NEW: Add Gann thirds levels between consecutive yellow lines (only if enabled)
   /*
   if(ShowDecimalPatterns)
   {
      // Gann thirds ratios - strongest levels in Gann analysis
      double gann_ratios[] = {0.333, 0.666}; // 1/3 and 2/3 (Gann thirds - strongest levels)
      
      color gann_color = clrBlue; // Keep original blue color
      
      // Generate consecutive 45-degree price levels for Gann calculation
      for(double base_price = 0; base_price <= 9999; base_price += 45)
      {
         double next_price = base_price + 45;
         if(next_price > 9999) break;
         
         // Skip if either level is not within reasonable range
         if(base_price < 0 || next_price > 10000) continue;
         
         // Calculate Gann thirds levels between base_price and next_price
         for(int g = 0; g < ArraySize(gann_ratios); g++)
         {
            double gann_price = base_price + (next_price - base_price) * gann_ratios[g];
            
            // Only draw if within reasonable price range
            if(gann_price >= 0 && gann_price <= 9999)
            {
               string ratio_str = DoubleToString(gann_ratios[g] * 100, 1) + "pct";
               string line_name = "Price45_GannThirds_" + ratio_str + "_" + DoubleToString(gann_price, 3);
               StringReplace(line_name, ".", "_");
               
               if(ObjectCreate(0, line_name, OBJ_HLINE, 0, 0, gann_price))
               {
                  // Set properties for Gann thirds lines
                  ObjectSetInteger(0, line_name, OBJPROP_COLOR, gann_color);
                  ObjectSetInteger(0, line_name, OBJPROP_WIDTH, DecimalLineWidth);
                  ObjectSetInteger(0, line_name, OBJPROP_STYLE, DecimalLineStyle);
                  ObjectSetInteger(0, line_name, OBJPROP_BACK, true);
                  
                  // Create tooltip showing the Gann thirds level
                  string tooltip = "Gann " + DoubleToString(gann_ratios[g] * 100, 1) + "% Level (THIRDS)\n" +
                                 "Between: " + DoubleToString(base_price, digits) + " - " + DoubleToString(next_price, digits) + "\n" +
                                 "Price: " + DoubleToString(gann_price, digits);
                  ObjectSetString(0, line_name, OBJPROP_TOOLTIP, tooltip);
                  
                  lines_drawn++;
                  
                  Print("Drew ORANGE Gann ", DoubleToString(gann_ratios[g] * 100, 1), "% line at price ", DoubleToString(gann_price, digits), 
                        " (between ", DoubleToString(base_price, digits), " - ", DoubleToString(next_price, digits), ")");
               }
            }
         }
      }
   }
   */
   
   // NEW: Add Gann eighths levels (1/8, 3/8, 5/8, 7/8) if enabled
   if(ShowGannEighths && ShowShortTermLines)  // SHORT-TERM: calculated between YELLOW lines
   {
      // Gann eighths ratios - additional precision levels (excluding blue eighths)
      double eighths_ratios[] = {0.125, 0.875}; // Only 1/8 and 7/8 (12.5% and 87.5%)
      
      // Generate consecutive 45-degree price levels for Gann eighths calculation
      for(double base_price = 0; base_price <= 9999; base_price += 45)
      {
         double next_price = base_price + 45;
         if(next_price > 9999) break;
         
         // Skip if either level is not within reasonable range
         if(base_price < 0 || next_price > 10000) continue;
         
         // Calculate Gann eighths levels between base_price and next_price
         for(int e = 0; e < ArraySize(eighths_ratios); e++)
         {
            double eighths_price = base_price + (next_price - base_price) * eighths_ratios[e];
            
            // Only draw if within reasonable price range
            if(eighths_price >= 0 && eighths_price <= 9999)
            {
               string ratio_str = DoubleToString(eighths_ratios[e] * 100, 1) + "pct";
               string line_name = "Price45_GannEighths_" + ratio_str + "_" + DoubleToString(eighths_price, 3);
               StringReplace(line_name, ".", "_");
               
               color eighths_color = SpecialEighthsLineColor; // Brown for 12.5% and 87.5%
               ENUM_LINE_STYLE eighths_style = EighthsLineStyle; // Use input parameter style
               
               if(ObjectCreate(0, line_name, OBJ_HLINE, 0, 0, eighths_price))
               {
                  // Set properties for Gann eighths lines
                  ObjectSetInteger(0, line_name, OBJPROP_COLOR, eighths_color);
                  ObjectSetInteger(0, line_name, OBJPROP_WIDTH, EighthsLineWidth);
                  ObjectSetInteger(0, line_name, OBJPROP_STYLE, eighths_style);
                  ObjectSetInteger(0, line_name, OBJPROP_BACK, true);
                  
                  // Create tooltip showing the Gann eighths level
                  string tooltip = "Gann " + DoubleToString(eighths_ratios[e] * 100, 1) + "% Level (EIGHTHS)\n" +
                                 "Between: " + DoubleToString(base_price, digits) + " - " + DoubleToString(next_price, digits) + "\n" +
                                 "Price: " + DoubleToString(eighths_price, digits);
                  ObjectSetString(0, line_name, OBJPROP_TOOLTIP, tooltip);
                  
                  lines_drawn++;
                  
                  Print("Drew BROWN Gann ", DoubleToString(eighths_ratios[e] * 100, 1), "% line at price ", DoubleToString(eighths_price, digits), 
                        " (between ", DoubleToString(base_price, digits), " - ", DoubleToString(next_price, digits), ")");
               }
            }
         }
      }
   }
   
   // NEW: Add BLUE EIGHTHS levels (3/8, 5/8) as completely separate entity
   if(ShowBlueEighths && ShowShortTermLines)  // SHORT-TERM: calculated between YELLOW lines
   {
      // Blue eighths ratios - completely independent from regular eighths
      double blue_eighths_ratios[] = {0.375, 0.625}; // 3/8 and 5/8 (37.5% and 62.5%)
      
      // Generate consecutive 45-degree price levels for blue eighths calculation
      for(double base_price = 0; base_price <= 9999; base_price += 45)
      {
         double next_price = base_price + 45;
         if(next_price > 9999) break;
         
         // Skip if either level is not within reasonable range
         if(base_price < 0 || next_price > 10000) continue;
         
         // Calculate blue eighths levels between base_price and next_price
         for(int be = 0; be < ArraySize(blue_eighths_ratios); be++)
         {
            double blue_eighths_price = base_price + (next_price - base_price) * blue_eighths_ratios[be];
            
            // Only draw if within reasonable price range
            if(blue_eighths_price >= 0 && blue_eighths_price <= 9999)
            {
               string ratio_str = DoubleToString(blue_eighths_ratios[be] * 100, 1) + "pct";
               string line_name = "Price45_BlueEighths_" + ratio_str + "_" + DoubleToString(blue_eighths_price, 3);
               StringReplace(line_name, ".", "_");
               
               if(ObjectCreate(0, line_name, OBJ_HLINE, 0, 0, blue_eighths_price))
               {
                  // Set properties for blue eighths lines
                  ObjectSetInteger(0, line_name, OBJPROP_COLOR, BlueEighthsLineColor);
                  ObjectSetInteger(0, line_name, OBJPROP_WIDTH, EighthsLineWidth);
                  ObjectSetInteger(0, line_name, OBJPROP_STYLE, EighthsLineStyle);
                  ObjectSetInteger(0, line_name, OBJPROP_BACK, true);
                  
                  // Create tooltip showing the blue eighths level
                  string tooltip = "Gann " + DoubleToString(blue_eighths_ratios[be] * 100, 1) + "% Level (BLUE EIGHTHS)\n" +
                                 "Between: " + DoubleToString(base_price, digits) + " - " + DoubleToString(next_price, digits) + "\n" +
                                 "Price: " + DoubleToString(blue_eighths_price, digits);
                  ObjectSetString(0, line_name, OBJPROP_TOOLTIP, tooltip);
                  
                  lines_drawn++;
                  
                  Print("Drew BLUE Gann ", DoubleToString(blue_eighths_ratios[be] * 100, 1), "% line at price ", DoubleToString(blue_eighths_price, digits), 
                        " (between ", DoubleToString(base_price, digits), " - ", DoubleToString(next_price, digits), ")");
               }
            }
         }
      }
   }
   
   // NEW: Add Gann quarters levels (1/4, 3/4) if enabled
   if(ShowGannQuarters && ShowShortTermLines)  // SHORT-TERM: calculated between YELLOW lines
   {
      // Gann quarters ratios - major support/resistance levels
      double quarters_ratios[] = {0.25, 0.75}; // 1/4 and 3/4
      
      color quarters_color = clrOrange; // Orange color for quarters
      
      // Generate consecutive 45-degree price levels for Gann quarters calculation
      for(double base_price = 0; base_price <= 9999; base_price += 45)
      {
         double next_price = base_price + 45;
         if(next_price > 9999) break;
         
         // Skip if either level is not within reasonable range
         if(base_price < 0 || next_price > 10000) continue;
         
         // Calculate Gann quarters levels between base_price and next_price
         for(int q = 0; q < ArraySize(quarters_ratios); q++)
         {
            double quarters_price = base_price + (next_price - base_price) * quarters_ratios[q];
            
            // Only draw if within reasonable price range
            if(quarters_price >= 0 && quarters_price <= 9999)
            {
               string ratio_str = DoubleToString(quarters_ratios[q] * 100, 1) + "pct";
               string line_name = "Price45_GannQuarters_" + ratio_str + "_" + DoubleToString(quarters_price, 3);
               StringReplace(line_name, ".", "_");
               
               if(ObjectCreate(0, line_name, OBJ_HLINE, 0, 0, quarters_price))
               {
                  // Set properties for Gann quarters lines
                  ObjectSetInteger(0, line_name, OBJPROP_COLOR, quarters_color);
                  ObjectSetInteger(0, line_name, OBJPROP_WIDTH, QuartersLineWidth);
                  ObjectSetInteger(0, line_name, OBJPROP_STYLE, QuartersLineStyle);
                  ObjectSetInteger(0, line_name, OBJPROP_BACK, true);
                  
                  // Create tooltip showing the Gann quarters level
                  string tooltip = "Gann " + DoubleToString(quarters_ratios[q] * 100, 1) + "% Level (QUARTERS)\n" +
                                 "Between: " + DoubleToString(base_price, digits) + " - " + DoubleToString(next_price, digits) + "\n" +
                                 "Price: " + DoubleToString(quarters_price, digits);
                  ObjectSetString(0, line_name, OBJPROP_TOOLTIP, tooltip);
                  
                  lines_drawn++;
                  
                  Print("Drew ORANGE Gann ", DoubleToString(quarters_ratios[q] * 100, 1), "% line at price ", DoubleToString(quarters_price, digits), 
                        " (between ", DoubleToString(base_price, digits), " - ", DoubleToString(next_price, digits), ")");
               }
            }
         }
      }
   }
   
   // NEW: Add Gann half level (50%) if enabled
   if(ShowGannHalf && ShowShortTermLines)  // SHORT-TERM: calculated between YELLOW lines
   {
      // Gann half ratio - major psychological level
      double half_ratio = 0.5; // 1/2
      
      color half_color = clrPurple; // Purple color for half
      
      // Generate consecutive 45-degree price levels for Gann half calculation
      for(double base_price = 0; base_price <= 9999; base_price += 45)
      {
         double next_price = base_price + 45;
         if(next_price > 9999) break;
         
         // Skip if either level is not within reasonable range
         if(base_price < 0 || next_price > 10000) continue;
         
         // Calculate Gann half level between base_price and next_price
         double half_price = base_price + (next_price - base_price) * half_ratio;
         
         // Only draw if within reasonable price range
         if(half_price >= 0 && half_price <= 9999)
         {
            string line_name = "Price45_GannHalf_" + DoubleToString(half_price, 3);
            
            if(ObjectCreate(0, line_name, OBJ_HLINE, 0, 0, half_price))
            {
               // Set properties for Gann half line (SHORT-TERM - thin like other short-term lines)
               ObjectSetInteger(0, line_name, OBJPROP_COLOR, half_color);
               ObjectSetInteger(0, line_name, OBJPROP_WIDTH, LineWidth);  // Use 1px for consistency with other short-term lines
               ObjectSetInteger(0, line_name, OBJPROP_STYLE, HalfLineStyle);
               ObjectSetInteger(0, line_name, OBJPROP_BACK, true);
               
               // Create tooltip showing the Gann half level
               string tooltip = "⚡ SHORT-TERM Gann 50% Level [THIN: " + IntegerToString(LineWidth) + "px]\n" +
                               "Between YELLOW: " + DoubleToString(base_price, digits) + " - " + DoubleToString(next_price, digits) + "\n" +
                               "Price: " + DoubleToString(half_price, digits);
               ObjectSetString(0, line_name, OBJPROP_TOOLTIP, tooltip);
               
               lines_drawn++;
               
               Print("Drew 🟣 PURPLE SHORT-TERM Gann 50% line at price ", DoubleToString(half_price, digits), 
                     " - Width:", LineWidth, "px (between YELLOW ", DoubleToString(base_price, digits), " - ", DoubleToString(next_price, digits), ") - Short-term level");
            }
         }
      }
   }
   
   // NEW: Add Bold Eighths levels (37.5% & 62.5%) between RED BOLD lines only
   if(ShowBoldEighths && ShowLongTermLines)  // LONG-TERM: calculated between RED BOLD lines
   {
      // Bold eighths ratios - specifically between red bold lines
      double bold_eighths_ratios[] = {0.375, 0.625}; // 3/8 and 5/8 (37.5% and 62.5%)
      
      // Collect all red bold line prices first
      double bold_prices[];
      int bold_count = 0;
      
      // Find all red bold line prices in the range
      for(double price = 0; price <= 9999; price += 1)
      {
         int price_int = (int)price;
         if(IsBoldPattern(price_int) || (price_int % 45 == 0 && IsBoldPattern(price_int)))
         {
            ArrayResize(bold_prices, bold_count + 1);
            bold_prices[bold_count] = price;
            bold_count++;
         }
      }
      
      // Sort the bold prices array
      ArraySort(bold_prices);
      
      // Generate bold eighths levels between consecutive red bold lines
      for(int b = 0; b < bold_count - 1; b++)
      {
         double base_price = bold_prices[b];
         double next_price = bold_prices[b + 1];
         
         // Skip if either level is not within reasonable range
         if(base_price < 0 || next_price > 10000) continue;
         
         // Calculate bold eighths levels between base_price and next_price
         for(int be = 0; be < ArraySize(bold_eighths_ratios); be++)
         {
            double bold_eighths_price = base_price + (next_price - base_price) * bold_eighths_ratios[be];
            
            // Only draw if within reasonable price range
            if(bold_eighths_price >= 0 && bold_eighths_price <= 9999)
            {
               string ratio_str = DoubleToString(bold_eighths_ratios[be] * 100, 1) + "pct";
               string line_name = "Price45_BoldEighths_" + ratio_str + "_" + DoubleToString(bold_eighths_price, 3);
               StringReplace(line_name, ".", "_");
               
               if(ObjectCreate(0, line_name, OBJ_HLINE, 0, 0, bold_eighths_price))
               {
                  // Set properties for bold eighths lines (LONG-TERM with enhanced thickness)
                  int bold_eighths_width = EnhancedVisualMode ? LineWidth * LongTermThicknessMultiplier : BoldEighthsLineWidth;
                  ObjectSetInteger(0, line_name, OBJPROP_COLOR, BoldEighthsLineColor);
                  ObjectSetInteger(0, line_name, OBJPROP_WIDTH, bold_eighths_width);
                  ObjectSetInteger(0, line_name, OBJPROP_STYLE, BoldEighthsLineStyle);
                  ObjectSetInteger(0, line_name, OBJPROP_BACK, true);
                  
                  // Create tooltip showing the bold eighths level
                  string tooltip = "⭐ LONG-TERM Bold " + DoubleToString(bold_eighths_ratios[be] * 100, 1) + "% Level [THICK: " + IntegerToString(bold_eighths_width) + "px]\n" +
                                 "Between RED BOLD: " + DoubleToString(base_price, digits) + " - " + DoubleToString(next_price, digits) + "\n" +
                                 "Price: " + DoubleToString(bold_eighths_price, digits);
                  ObjectSetString(0, line_name, OBJPROP_TOOLTIP, tooltip);
                  
                  lines_drawn++;
                  
                  Print("Drew 🟣 MAGENTA LONG-TERM Bold ", DoubleToString(bold_eighths_ratios[be] * 100, 1), "% line at price ", DoubleToString(bold_eighths_price, digits), 
                        " - Width:", bold_eighths_width, "px (between RED BOLD ", DoubleToString(base_price, digits), " - ", DoubleToString(next_price, digits), ")");
               }
            }
         }
      }
   }
   
   // NEW: Add Bold Quarters levels (25% & 75%) between RED BOLD lines only
   if(ShowBoldQuarters && ShowLongTermLines)  // LONG-TERM: calculated between RED BOLD lines
   {
      // Bold quarters ratios - specifically between red bold lines
      double bold_quarters_ratios[] = {0.25, 0.75}; // 1/4 and 3/4 (25% and 75%)
      
      // Collect all red bold line prices first
      double bold_prices[];
      int bold_count = 0;
      
      // Find all red bold line prices in the range
      for(double price = 0; price <= 9999; price += 1)
      {
         int price_int = (int)price;
         if(IsBoldPattern(price_int) || (price_int % 45 == 0 && IsBoldPattern(price_int)))
         {
            ArrayResize(bold_prices, bold_count + 1);
            bold_prices[bold_count] = price;
            bold_count++;
         }
      }
      
      // Sort the bold prices array
      ArraySort(bold_prices);
      
      // Generate bold quarters levels between consecutive red bold lines
      for(int b = 0; b < bold_count - 1; b++)
      {
         double base_price = bold_prices[b];
         double next_price = bold_prices[b + 1];
         
         // Skip if either level is not within reasonable range
         if(base_price < 0 || next_price > 10000) continue;
         
         // Calculate bold quarters levels between base_price and next_price
         for(int bq = 0; bq < ArraySize(bold_quarters_ratios); bq++)
         {
            double bold_quarters_price = base_price + (next_price - base_price) * bold_quarters_ratios[bq];
            
            // Only draw if within reasonable price range
            if(bold_quarters_price >= 0 && bold_quarters_price <= 9999)
            {
               string ratio_str = DoubleToString(bold_quarters_ratios[bq] * 100, 1) + "pct";
               string line_name = "Price45_BoldQuarters_" + ratio_str + "_" + DoubleToString(bold_quarters_price, 3);
               StringReplace(line_name, ".", "_");
               
               if(ObjectCreate(0, line_name, OBJ_HLINE, 0, 0, bold_quarters_price))
               {
                  // Set properties for bold quarters lines (LONG-TERM with enhanced thickness)
                  int bold_quarters_width = EnhancedVisualMode ? LineWidth * LongTermThicknessMultiplier : BoldQuartersLineWidth;
                  ObjectSetInteger(0, line_name, OBJPROP_COLOR, BoldQuartersLineColor);
                  ObjectSetInteger(0, line_name, OBJPROP_WIDTH, bold_quarters_width);
                  ObjectSetInteger(0, line_name, OBJPROP_STYLE, BoldQuartersLineStyle);
                  ObjectSetInteger(0, line_name, OBJPROP_BACK, true);
                  
                  // Create tooltip showing the bold quarters level
                  string tooltip = "⭐ LONG-TERM Bold " + DoubleToString(bold_quarters_ratios[bq] * 100, 1) + "% Level [THICK: " + IntegerToString(bold_quarters_width) + "px]\n" +
                                 "Between RED BOLD: " + DoubleToString(base_price, digits) + " - " + DoubleToString(next_price, digits) + "\n" +
                                 "Price: " + DoubleToString(bold_quarters_price, digits);
                  ObjectSetString(0, line_name, OBJPROP_TOOLTIP, tooltip);
                  
                  lines_drawn++;
                  
                  Print("Drew 🔷 TEAL LONG-TERM Bold ", DoubleToString(bold_quarters_ratios[bq] * 100, 1), "% line at price ", DoubleToString(bold_quarters_price, digits), 
                        " - Width:", bold_quarters_width, "px (between RED BOLD ", DoubleToString(base_price, digits), " - ", DoubleToString(next_price, digits), ")");
               }
            }
         }
      }
   }
   
   // NEW: Add Bold Eighths Special levels (12.5% & 87.5%) between RED BOLD lines only
   if(ShowBoldEighthsSpecial && ShowLongTermLines)  // LONG-TERM: calculated between RED BOLD lines
   {
      // Bold special eighths ratios - specifically between red bold lines
      double bold_eighths_special_ratios[] = {0.125, 0.875}; // 1/8 and 7/8 (12.5% and 87.5%)
      
      // Collect all red bold line prices first
      double bold_prices[];
      int bold_count = 0;
      
      // Find all red bold line prices in the range
      for(double price = 0; price <= 9999; price += 1)
      {
         int price_int = (int)price;
         if(IsBoldPattern(price_int) || (price_int % 45 == 0 && IsBoldPattern(price_int)))
         {
            ArrayResize(bold_prices, bold_count + 1);
            bold_prices[bold_count] = price;
            bold_count++;
         }
      }
      
      // Sort the bold prices array
      ArraySort(bold_prices);
      
      // Generate bold eighths special levels between consecutive red bold lines
      for(int b = 0; b < bold_count - 1; b++)
      {
         double base_price = bold_prices[b];
         double next_price = bold_prices[b + 1];
         
         // Skip if either level is not within reasonable range
         if(base_price < 0 || next_price > 10000) continue;
         
         // Calculate bold eighths special levels between base_price and next_price
         for(int bes = 0; bes < ArraySize(bold_eighths_special_ratios); bes++)
         {
            double bold_eighths_special_price = base_price + (next_price - base_price) * bold_eighths_special_ratios[bes];
            
            // Only draw if within reasonable price range
            if(bold_eighths_special_price >= 0 && bold_eighths_special_price <= 9999)
            {
               string ratio_str = DoubleToString(bold_eighths_special_ratios[bes] * 100, 1) + "pct";
               string line_name = "Price45_BoldEighthsSpecial_" + ratio_str + "_" + DoubleToString(bold_eighths_special_price, 3);
               StringReplace(line_name, ".", "_");
               
               if(ObjectCreate(0, line_name, OBJ_HLINE, 0, 0, bold_eighths_special_price))
               {
                  // Set properties for bold eighths special lines (LONG-TERM with enhanced thickness)
                  int bold_eighths_special_width = EnhancedVisualMode ? LineWidth * LongTermThicknessMultiplier : BoldEighthsSpecialLineWidth;
                  ObjectSetInteger(0, line_name, OBJPROP_COLOR, BoldEighthsSpecialLineColor);
                  ObjectSetInteger(0, line_name, OBJPROP_WIDTH, bold_eighths_special_width);
                  ObjectSetInteger(0, line_name, OBJPROP_STYLE, BoldEighthsSpecialLineStyle);
                  ObjectSetInteger(0, line_name, OBJPROP_BACK, true);
                  
                  // Create tooltip showing the bold eighths special level
                  string tooltip = "⭐ LONG-TERM Bold " + DoubleToString(bold_eighths_special_ratios[bes] * 100, 1) + "% Level [THICK: " + IntegerToString(bold_eighths_special_width) + "px]\n" +
                                 "Between RED BOLD: " + DoubleToString(base_price, digits) + " - " + DoubleToString(next_price, digits) + "\n" +
                                 "Price: " + DoubleToString(bold_eighths_special_price, digits);
                  ObjectSetString(0, line_name, OBJPROP_TOOLTIP, tooltip);
                  
                  lines_drawn++;
                  
                  Print("Drew 🟤 MAROON LONG-TERM Bold ", DoubleToString(bold_eighths_special_ratios[bes] * 100, 1), "% line at price ", DoubleToString(bold_eighths_special_price, digits), 
                        " - Width:", bold_eighths_special_width, "px (between RED BOLD ", DoubleToString(base_price, digits), " - ", DoubleToString(next_price, digits), ")");
               }
            }
         }
      }
   }
   
   // NEW: Add Bold Half level (50%) between RED BOLD lines only
   if(ShowGannHalf && ShowLongTermLines)  // LONG-TERM: calculated between RED BOLD lines
   {
      // Bold half ratio - major psychological level between red bold lines
      double bold_half_ratio = 0.5; // 1/2
      
      // Collect all red bold line prices first
      double bold_prices[];
      int bold_count = 0;
      
      // Find all red bold line prices in the range
      for(double price = 0; price <= 9999; price += 1)
      {
         int price_int = (int)price;
         if(IsBoldPattern(price_int) || (price_int % 45 == 0 && IsBoldPattern(price_int)))
         {
            ArrayResize(bold_prices, bold_count + 1);
            bold_prices[bold_count] = price;
            bold_count++;
         }
      }
      
      // Sort the bold prices array
      ArraySort(bold_prices);
      
      // Generate bold half levels between consecutive red bold lines
      for(int b = 0; b < bold_count - 1; b++)
      {
         double base_price = bold_prices[b];
         double next_price = bold_prices[b + 1];
         
         // Skip if either level is not within reasonable range
         if(base_price < 0 || next_price > 10000) continue;
         
         // Calculate bold half level between base_price and next_price
         double bold_half_price = base_price + (next_price - base_price) * bold_half_ratio;
         
         // Only draw if within reasonable price range
         if(bold_half_price >= 0 && bold_half_price <= 9999)
         {
            string line_name = "Price45_BoldHalf_" + DoubleToString(bold_half_price, 3);
            StringReplace(line_name, ".", "_");
            
            if(ObjectCreate(0, line_name, OBJ_HLINE, 0, 0, bold_half_price))
            {
               // Set properties for bold half line (LONG-TERM with enhanced thickness)
               int bold_half_width = EnhancedVisualMode ? LineWidth * LongTermThicknessMultiplier : HalfLineWidth;
               ObjectSetInteger(0, line_name, OBJPROP_COLOR, BoldHalfLineColor);
               ObjectSetInteger(0, line_name, OBJPROP_WIDTH, bold_half_width);
               ObjectSetInteger(0, line_name, OBJPROP_STYLE, HalfLineStyle);
               ObjectSetInteger(0, line_name, OBJPROP_BACK, true);
               
               // Create tooltip showing the bold half level
               string tooltip = "⭐ LONG-TERM Bold 50% Level [VERY THICK: " + IntegerToString(bold_half_width) + "px]\n" +
                               "Between RED BOLD: " + DoubleToString(base_price, digits) + " - " + DoubleToString(next_price, digits) + "\n" +
                               "Price: " + DoubleToString(bold_half_price, digits) + " (MAJOR PSYCHOLOGICAL LEVEL)";
               ObjectSetString(0, line_name, OBJPROP_TOOLTIP, tooltip);
               
               lines_drawn++;
               
               Print("Drew 🟣 VIOLET LONG-TERM Bold 50% line at price ", DoubleToString(bold_half_price, digits), 
                     " - Width:", bold_half_width, "px (between RED BOLD ", DoubleToString(base_price, digits), " - ", DoubleToString(next_price, digits), ") - MAJOR LEVEL");
            }
         }
      }
   }
   
   Print("Drew ", lines_drawn, " horizontal lines at all 45° price levels");
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Extract first 3 digits from price                              |
//+------------------------------------------------------------------+
int GetFirst3Digits(double price)
{
   // Convert price to string and remove decimal point
   string price_str = DoubleToString(price, 6);
   StringReplace(price_str, ".", "");
   
   // Get first 3 digits
   if(StringLen(price_str) >= 3)
   {
      string first_3 = StringSubstr(price_str, 0, 3);
      return (int)StringToInteger(first_3);
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| Check if number represents a 45-degree level                   |
//+------------------------------------------------------------------+
bool Is45DegreeLevel(int digits)
{
   // Degree intervals including new 161° and 207°: 0°, 45°, 90°, 135°, 161°, 180°, 207°, 225°, 270°, 315°, 360°
   // Map to 3-digit numbers
   int degree_levels[] = {0, 45, 90, 135, 161, 180, 207, 225, 270, 315, 360};
   
   for(int i = 0; i < ArraySize(degree_levels); i++)
   {
      if(digits == degree_levels[i])
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get degree value from first 3 digits                           |
//+------------------------------------------------------------------+
int GetDegreeFromDigits(int digits)
{
   // Direct mapping for exact matches
   int degree_levels[] = {0, 45, 90, 135, 161, 180, 207, 225, 270, 315, 360};
   
   for(int i = 0; i < ArraySize(degree_levels); i++)
   {
      if(digits == degree_levels[i])
         return degree_levels[i];
   }
   
   return -1; // Not a 45-degree level
}

//+------------------------------------------------------------------+
//| Remove all price lines created by this indicator               |
//+------------------------------------------------------------------+
void RemoveAllPriceLines()
{
   int objectsTotal = ObjectsTotal(0);
   
   for(int i = objectsTotal - 1; i >= 0; i--)
   {
      string objectName = ObjectName(0, i);
      if(StringFind(objectName, "Price45_") == 0)
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
   RemoveAllPriceLines();
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
   static ENUM_TIMEFRAMES last_timeframe = PERIOD_CURRENT;
   ENUM_TIMEFRAMES current_timeframe = Period();
   
   // Redraw on chart changes OR timeframe changes
   if(id == CHARTEVENT_CHART_CHANGE || 
      (current_timeframe != last_timeframe))
   {
      Print("🔄 Redrawing lines - Event: ", 
            (id == CHARTEVENT_CHART_CHANGE ? "Chart Change" : "Timeframe Change"),
            " (", EnumToString(current_timeframe), ")");
      
      RemoveAllPriceLines();
      DrawPrice45DegreeLines();
      last_timeframe = current_timeframe;
   }
}

//+------------------------------------------------------------------+
//| Check if price represents a bold pattern (00xxx and xxx00)     |
//+------------------------------------------------------------------+
bool IsBoldPattern(int price)
{
   // Convert price to string for pattern analysis
   string price_str = IntegerToString(price);
   int price_len = StringLen(price_str);
   
   // Pattern 1: 00xxx (like 0045, 0090, 0135, 0180, 0225, 0270, 0315, 0360)
   if(price_len <= 4 && price < 1000)
   {
      // For prices like 45, 90, 135, 180, 225, 270, 315, 360 (treated as 0045, 0090, etc.)
      if(price == 45 || price == 90 || price == 135 || price == 180 || 
         price == 225 || price == 270 || price == 315 || price == 360)
         return true;
   }
   
   // Pattern 2: xxx00 (prices ending in 00)
   if(price % 100 == 0 && price > 0)
   {
      // Check if the hundreds digit is a multiple of 45
      int hundreds = price / 100;
      
      // Check if hundreds is a multiple of 45
      if(hundreds % 45 == 0)
         return true;
   }
   
   // NEW Pattern 4: First 3 digits multiple of 45 (e.g., 450, 4500, 90x, 900, 9000)
   if(price >= 100)  // Only for 3+ digit numbers
   {
      int first_3_digits = GetFirst3Digits(price);
      if(first_3_digits > 0 && first_3_digits % 45 == 0)
         return true;
   }
   
   // Pattern 3: Specific cases you mentioned
   if(price == 900 || price == 1800 || price == 2250 || price == 2700)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if price represents 00xx.x pattern                       |
//+------------------------------------------------------------------+
bool Is00xxPattern(double price)
{
   // Check for 00xx.x patterns (like 0018.0, 0022.5, 0045.0, 0067.5, etc.)
   if(price >= 10.0 && price < 100.0)
   {
      // These are prices that would be displayed as 00xx.x
      // Examples: 18.0 (displayed as 0018.0), 22.5 (displayed as 0022.5), 45.0 (displayed as 0045.0)
      
      // Check for exact 45° patterns
      if(price == 18.0 || price == 22.5 || price == 45.0 || price == 67.5 || 
         price == 90.0)  // Note: 90.0 would be displayed as 0090.0
         return true;
         
      // Check for half-degree astronomical levels in the 00xx range
      double valid_00xx_levels[] = {13.5, 18.0, 22.5, 27.0, 31.5, 36.0, 40.5, 45.0, 
                                    49.5, 54.0, 58.5, 63.0, 67.5, 72.0, 76.5, 81.0, 
                                    85.5, 90.0, 94.5, 99.0};
      
      for(int i = 0; i < ArraySize(valid_00xx_levels); i++)
      {
         if(MathAbs(price - valid_00xx_levels[i]) < 0.1) // Within 0.1 of the target
            return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if price represents XXxx.x pattern                       |
//+------------------------------------------------------------------+
bool IsXXxxPattern(double price)
{
   // Check for XXxx.x patterns (like 0018.0, 0118.0, 0218.0, 1318.0, etc.)
   if(price >= 10.0 && price < 10000.0)
   {
      // Extract the last two digits before decimal (the xx part)
      int whole_part = (int)price;
      int last_two_digits = whole_part % 100;
      
      // Check if the last two digits match 45° astronomical patterns
      // Valid patterns: 18, 22, 27, 31, 36, 40, 45, 49, 54, 58, 63, 67, 72, 76, 81, 85, 90, 94, 99
      int valid_xx_patterns[] = {18, 22, 27, 31, 36, 40, 45, 49, 54, 58, 63, 67, 72, 76, 81, 85, 90, 94, 99};
      
      for(int i = 0; i < ArraySize(valid_xx_patterns); i++)
      {
         if(last_two_digits == valid_xx_patterns[i])
            return true;
      }
      
      // Also check for .5 decimal patterns (like 22.5, 67.5, etc.)
      double decimal_part = price - whole_part;
      if(MathAbs(decimal_part - 0.5) < 0.01) // Check if it's .5
      {
         int adjusted_digits = last_two_digits;
         int valid_half_patterns[] = {22, 67, 112 % 100, 157 % 100, 202 % 100, 247 % 100, 292 % 100, 337 % 100}; // These become 22, 67, 12, 57, 2, 47, 92, 37
         
         for(int j = 0; j < ArraySize(valid_half_patterns); j++)
         {
            if(adjusted_digits == valid_half_patterns[j])
               return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get degree for special patterns                                 |
//+------------------------------------------------------------------+
int GetSpecialPatternDegree(int price)
{
   // Map special patterns to their corresponding degrees
   if(price == 450 || price == 900 || price == 1350 || price == 1800 || 
      price == 2250 || price == 2700 || price == 3150 || price == 3600 || 
      price == 4050 || price == 4500) return 45;
      
   return 0; // Default
}

//--- Helper function to check if price is at Gann thirds (33.33% or 66.67%)
bool IsGannThirdsPattern(double price)
{
   string price_str = DoubleToString(price, 2);
   int decimal_pos = StringFind(price_str, ".");
   
   if(decimal_pos == -1) return false;
   
   string decimal_part = StringSubstr(price_str, decimal_pos + 1);
   
   // Check for .33 or .67 patterns (Gann thirds)
   return (StringFind(decimal_part, "33") == 0 || StringFind(decimal_part, "67") == 0);
}

//--- Helper function to check if price is at Gann eighths (12.5%, 37.5%, 62.5%, 87.5%)
bool IsGannEighthsPattern(double price)
{
   string price_str = DoubleToString(price, 2);
   int decimal_pos = StringFind(price_str, ".");
   
   if(decimal_pos == -1) return false;
   
   string decimal_part = StringSubstr(price_str, decimal_pos + 1);
   
   // Check for .125, .375, .625, .875 patterns (Gann eighths)
   return (StringFind(decimal_part, "12") == 0 || StringFind(decimal_part, "13") == 0 ||
           StringFind(decimal_part, "37") == 0 || StringFind(decimal_part, "38") == 0 ||
           StringFind(decimal_part, "62") == 0 || StringFind(decimal_part, "63") == 0 ||
           StringFind(decimal_part, "87") == 0 || StringFind(decimal_part, "88") == 0);
}

//--- Helper function to check if price is at Gann quarters (25% or 75%)
bool IsGannQuartersPattern(double price)
{
   string price_str = DoubleToString(price, 2);
   int decimal_pos = StringFind(price_str, ".");
   
   if(decimal_pos == -1) return false;
   
   string decimal_part = StringSubstr(price_str, decimal_pos + 1);
   
   // Check for .25 or .75 patterns (Gann quarters)
   return (StringFind(decimal_part, "25") == 0 || StringFind(decimal_part, "75") == 0);
}

//--- Helper function to check if price is at Gann half (50%)
bool IsGannHalfPattern(double price)
{
   string price_str = DoubleToString(price, 2);
   int decimal_pos = StringFind(price_str, ".");
   
   if(decimal_pos == -1) return false;
   
   string decimal_part = StringSubstr(price_str, decimal_pos + 1);
   
   // Check for .50 pattern (Gann half)
   return (StringFind(decimal_part, "50") == 0);
}

//+------------------------------------------------------------------+
//| Delete all lines created by this indicator                     |
//+------------------------------------------------------------------+
void DeleteAllLines()
{
   int total = ObjectsTotal(0, 0, OBJ_HLINE);
   
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, OBJ_HLINE);
      
      // Delete lines created by this indicator
      if(StringFind(name, "Price45_Cardinal_") == 0 ||
         StringFind(name, "Price45_GannFourths_") == 0 ||
         StringFind(name, "Price45_GannEighths_") == 0 ||
         StringFind(name, "Price45_BlueEighths_") == 0)  // Add blue eighths deletion
      {
         ObjectDelete(0, name);
      }
   }
}

//+------------------------------------------------------------------+
//| Print visual distinction summary                                  |
//+------------------------------------------------------------------+
void PrintVisualDistinctionSummary()
{
   Print("=== PRICE 45° ENHANCED VISUAL DISTINCTION ===");
   
   int long_term_width = EnhancedVisualMode ? LineWidth * LongTermThicknessMultiplier : BoldLineWidth;
   int short_term_width = LineWidth;
   
   Print("🔴 LONG-TERM LINES (Red, VERY THICK, Solid):");
   Print("   - Main Lines Width: ", long_term_width, " pixels");
   Print("   - Fractional Levels Width: ", long_term_width, " pixels (1/4, 1/2, 3/8, 5/8, etc.)");
   Print("   - Color: Red main + Various colors for fractional levels");
   Print("   - Style: Solid lines for strong visibility");
   Print("   - Pattern: Special 45° patterns + ALL fractional levels between them");
   Print("   - Includes: Main red lines + Bold Quarters + Bold Eighths + Bold Half");
   Print("   - Significance: MAJOR price levels for long-term analysis");
   Print("");
   Print("🟡 SHORT-TERM LINES (Yellow & Purple, Thin, Dotted):");
   Print("   - Width: ", short_term_width, " pixel");
   Print("   - Color: Yellow (Minor levels) + Purple (50% between yellow)");
   Print("   - Style: ", EnhancedVisualMode ? "Dotted" : "Solid", " lines");
   Print("   - Pattern: Regular 45° intervals + minor fractional levels + 50% half lines");
   Print("   - Significance: Minor price levels for short-term analysis");
   Print("   - Consistency: ALL short-term lines including 50% use same thin width");
   Print("");
   Print("📊 DISTINCTION RATIO: Long-term lines are ", (long_term_width/short_term_width), "x thicker than short-term");
   Print("✨ Enhanced Mode: ", EnhancedVisualMode ? "ENABLED" : "DISABLED");
   Print("⚙️ Thickness Multiplier: ", LongTermThicknessMultiplier, "x");
   Print("🎯 Long-term Fractional Levels: ALL fractional levels between red bold lines are thick");
   Print("💡 Visual Impact: Long-term levels (main + fractional) stand out prominently");
}