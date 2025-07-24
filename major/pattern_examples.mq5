//+------------------------------------------------------------------+
//|                                    Pattern Examples Demo        |
//|                              Demonstrates all Price45Degrees patterns |
//+------------------------------------------------------------------+

#property strict

// Function declarations from Price45Degrees.mq5
bool IsBoldPattern(int price);
bool IsShortTermPattern(int price);
bool IsRegular45Multiple(int price);
string ExplainBoldPattern(int price);

//+------------------------------------------------------------------+
//| Script start function                                           |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("===============================================================================");
   Print("           COMPLETE PATTERN DEMONSTRATION - Price45Degrees.mq5");
   Print("===============================================================================");
   
   // LONG-TERM PATTERNS (RED BOLD LINES)
   Print("");
   Print("=== LONG-TERM PATTERNS (RED BOLD LINES) ===");
   
   Print("--- Priority Patterns (Key Gann Levels) ---");
   int priority[] = {45, 90, 135, 180, 225, 270, 315, 360, 405, 450, 495, 540, 585, 630, 675, 720, 765, 810, 855, 900};
   for(int i = 0; i < ArraySize(priority); i++)
   {
      if(IsBoldPattern(priority[i]))
         Print(priority[i], " = LONG-TERM RED (Priority Gann Level)");
   }
   
   Print("--- xxx00 Patterns (5-digit) ---");
   int xxx00_patterns[] = {04500, 09000, 13500, 18000, 22500, 27000, 31500, 36000, 40500, 45000, 49500, 54000, 58500, 63000, 67500, 72000};
   for(int i = 0; i < ArraySize(xxx00_patterns); i++)
   {
      if(IsBoldPattern(xxx00_patterns[i]))
      {
         string explanation = ExplainBoldPattern(xxx00_patterns[i]);
         Print(xxx00_patterns[i], " = LONG-TERM RED - ", explanation);
      }
   }
   
   Print("--- xx00 Patterns (4-digit) ---");
   int xx00_patterns[] = {4500, 9000, 1350, 1800, 2250, 2700, 3150, 3600};
   for(int i = 0; i < ArraySize(xx00_patterns); i++)
   {
      if(IsBoldPattern(xx00_patterns[i]))
      {
         string explanation = ExplainBoldPattern(xx00_patterns[i]);
         Print(xx00_patterns[i], " = LONG-TERM RED - ", explanation);
      }
   }
   
   // SHORT-TERM PATTERNS (YELLOW LINES)
   Print("");
   Print("=== SHORT-TERM PATTERNS (YELLOW LINES) ===");
   
   Print("--- yyxxx Patterns (5-digit, last 3 divisible by 45) ---");
   int yyxxx_patterns[] = {12045, 34090, 56135, 78180, 91225, 23270, 45315, 67360, 89405, 11450, 33495, 55540};
   for(int i = 0; i < ArraySize(yyxxx_patterns); i++)
   {
      if(IsShortTermPattern(yyxxx_patterns[i]))
      {
         string explanation = ExplainBoldPattern(yyxxx_patterns[i]);
         Print(yyxxx_patterns[i], " = SHORT-TERM YELLOW - ", explanation);
      }
   }
   
   Print("--- yxxx Patterns (4-digit, last 3 divisible by 45) ---");
   int yxxx_patterns[] = {1045, 2090, 3135, 4180, 5225, 6270, 7315, 8360, 9405, 1450, 2495, 3540};
   for(int i = 0; i < ArraySize(yxxx_patterns); i++)
   {
      if(IsShortTermPattern(yxxx_patterns[i]))
      {
         string explanation = ExplainBoldPattern(yxxx_patterns[i]);
         Print(yxxx_patterns[i], " = SHORT-TERM YELLOW - ", explanation);
      }
   }
   
   // REGULAR 45° MULTIPLES (YELLOW LINES)
   Print("");
   Print("=== REGULAR 45° MULTIPLES (YELLOW LINES) ===");
   Print("--- Regular multiples (not special patterns) ---");
   int regular_multiples[] = {135, 315, 405, 495, 585, 675, 765, 855, 945, 1035, 1125, 1215, 1305, 1395, 1485, 1575, 1665, 1755, 1845, 1935};
   for(int i = 0; i < ArraySize(regular_multiples); i++)
   {
      if(IsRegular45Multiple(regular_multiples[i]))
      {
         string explanation = ExplainBoldPattern(regular_multiples[i]);
         Print(regular_multiples[i], " = REGULAR YELLOW - ", explanation);
      }
   }
   
   // NEGATIVE EXAMPLES (NOT 45° PATTERNS)
   Print("");
   Print("=== NEGATIVE EXAMPLES (NOT 45° PATTERNS) ===");
   int negative_examples[] = {12046, 34091, 56136, 78181, 91226, 12345, 67890, 11111, 22222, 33333};
   for(int i = 0; i < ArraySize(negative_examples); i++)
   {
      bool is_long = IsBoldPattern(negative_examples[i]);
      bool is_short = IsShortTermPattern(negative_examples[i]);
      bool is_regular = IsRegular45Multiple(negative_examples[i]);
      
      if(!is_long && !is_short && !is_regular)
         Print(negative_examples[i], " = NOT A 45° PATTERN");
   }
   
   Print("");
   Print("===============================================================================");
   Print("                           PATTERN SUMMARY");
   Print("===============================================================================");
   Print("LONG-TERM (RED BOLD):    xxx00, xx00, xxx000 + Priority levels");
   Print("SHORT-TERM (YELLOW):     yyxxx, yxxx, yyyxxx patterns");
   Print("REGULAR (YELLOW):        Simple 45° multiples (not special patterns)");
   Print("===============================================================================");
}

//+------------------------------------------------------------------+
//| Pattern detection functions (simplified versions)               |
//+------------------------------------------------------------------+
bool IsBoldPattern(int price)
{
   string price_str = IntegerToString(price);
   int price_len = StringLen(price_str);
   
   // Priority patterns
   int priority_patterns[] = {45, 90, 135, 180, 225, 270, 315, 360};
   for(int i = 0; i < ArraySize(priority_patterns); i++)
   {
      if(price == priority_patterns[i])
         return true;
   }
   
   // xxx00 pattern (5-digit)
   if(price_len == 5)
   {
      int last_2_digits = price % 100;
      int first_3_digits = price / 100;
      if(last_2_digits == 0 && first_3_digits % 45 == 0 && first_3_digits > 0)
         return true;
   }
   
   // xx00 pattern (4-digit)
   if(price_len == 4)
   {
      int last_2_digits = price % 100;
      int first_2_digits = price / 100;
      if(last_2_digits == 0 && first_2_digits % 45 == 0 && first_2_digits > 0)
         return true;
   }
   
   // 3-digit exact multiple
   if(price_len == 3)
   {
      if(price % 45 == 0 && price > 0)
         return true;
   }
   
   // xxx000 pattern (6-digit)
   if(price_len == 6)
   {
      int last_3_digits = price % 1000;
      int first_3_digits = price / 1000;
      if(last_3_digits == 0 && first_3_digits % 45 == 0 && first_3_digits > 0)
         return true;
   }
   
   return false;
}

bool IsShortTermPattern(int price)
{
   string price_str = IntegerToString(price);
   int price_len = StringLen(price_str);
   
   // yyxxx pattern (5-digit)
   if(price_len == 5)
   {
      int last_3_digits = price % 1000;
      if(last_3_digits % 45 == 0 && last_3_digits > 0)
      {
         int first_3_digits = price / 100;
         if(first_3_digits % 45 != 0 || first_3_digits == 0)
            return true;
      }
   }
   
   // yxxx pattern (4-digit)
   if(price_len == 4)
   {
      int last_3_digits = price % 1000;
      if(last_3_digits % 45 == 0 && last_3_digits > 0)
      {
         int first_2_digits = price / 100;
         if(first_2_digits % 45 != 0 || first_2_digits == 0)
            return true;
      }
   }
   
   // yyyxxx pattern (6-digit)
   if(price_len == 6)
   {
      int last_3_digits = price % 1000;
      if(last_3_digits % 45 == 0 && last_3_digits > 0)
      {
         int first_3_digits = price / 1000;
         if(first_3_digits % 45 != 0 || first_3_digits == 0)
            return true;
      }
   }
   
   return false;
}

bool IsRegular45Multiple(int price)
{
   if(price % 45 != 0 || price <= 0)
      return false;
   
   // Exclude priority patterns
   int priority_patterns[] = {45, 90, 135, 180, 225, 270, 315, 360};
   for(int i = 0; i < ArraySize(priority_patterns); i++)
   {
      if(price == priority_patterns[i])
         return false;
   }
   
   // Exclude if it's a long-term pattern
   if(IsBoldPattern(price))
      return false;
   
   // Exclude if it's a short-term pattern
   if(IsShortTermPattern(price))
      return false;
   
   return true;
}

string ExplainBoldPattern(int price)
{
   string price_str = IntegerToString(price);
   int price_len = StringLen(price_str);
   
   bool is_long_term = IsBoldPattern(price);
   bool is_short_term = IsShortTermPattern(price);
   bool is_regular = IsRegular45Multiple(price);
   
   if(!is_long_term && !is_short_term && !is_regular)
      return "Not a 45° pattern";
   
   if(is_regular)
      return "Regular 45° multiple (" + IntegerToString(price) + " ÷ 45 = " + IntegerToString(price/45) + ")";
   
   // Priority patterns
   int priority_patterns[] = {45, 90, 135, 180, 225, 270, 315, 360};
   for(int i = 0; i < ArraySize(priority_patterns); i++)
   {
      if(price == priority_patterns[i])
         return "Priority Gann level (" + IntegerToString(price) + "°)";
   }
   
   if(is_long_term)
   {
      if(price_len == 5)
      {
         int last_2_digits = price % 100;
         int first_3_digits = price / 100;
         if(last_2_digits == 0 && first_3_digits % 45 == 0)
            return "xxx00 pattern (first 3: " + IntegerToString(first_3_digits) + " ÷ 45 = " + IntegerToString(first_3_digits/45) + ", last 2: 00)";
      }
      
      if(price_len == 4)
      {
         int last_2_digits = price % 100;
         int first_2_digits = price / 100;
         if(last_2_digits == 0 && first_2_digits % 45 == 0)
            return "xx00 pattern (first 2: " + IntegerToString(first_2_digits) + " ÷ 45 = " + IntegerToString(first_2_digits/45) + ", last 2: 00)";
      }
      
      if(price_len == 3)
         return "xxx pattern (" + IntegerToString(price) + " ÷ 45 = " + IntegerToString(price/45) + ")";
   }
   
   if(is_short_term)
   {
      if(price_len == 5)
      {
         int last_3_digits = price % 1000;
         return "yyxxx pattern (last 3: " + IntegerToString(last_3_digits) + " ÷ 45 = " + IntegerToString(last_3_digits/45) + ")";
      }
      
      if(price_len == 4)
      {
         int last_3_digits = price % 1000;
         return "yxxx pattern (last 3: " + IntegerToString(last_3_digits) + " ÷ 45 = " + IntegerToString(last_3_digits/45) + ")";
      }
   }
   
   return "Unknown pattern";
}
