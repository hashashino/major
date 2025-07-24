import sys

def is_bold_pattern(price):
    """LONG-TERM patterns (RED BOLD)"""
    price_str = str(price)
    price_len = len(price_str)
    
    # Priority patterns
    priority_patterns = [45, 90, 135, 180, 225, 270, 315, 360]
    if price in priority_patterns:
        return True
    
    # xxx00 pattern (5-digit)
    if price_len == 5:
        last_2_digits = price % 100
        first_3_digits = price // 100
        if last_2_digits == 0 and first_3_digits % 45 == 0 and first_3_digits > 0:
            return True
    
    # xx00 pattern (4-digit)
    if price_len == 4:
        last_2_digits = price % 100
        first_2_digits = price // 100
        if last_2_digits == 0 and first_2_digits % 45 == 0 and first_2_digits > 0:
            return True
    
    # 3-digit exact multiple
    if price_len == 3:
        if price % 45 == 0 and price > 0:
            return True
    
    return False

def is_short_term_pattern(price):
    """SHORT-TERM patterns (YELLOW)"""
    price_str = str(price)
    price_len = len(price_str)
    
    # yyxxx pattern (5-digit)
    if price_len == 5:
        last_3_digits = price % 1000
        if last_3_digits % 45 == 0 and last_3_digits > 0:
            first_3_digits = price // 100
            if first_3_digits % 45 != 0 or first_3_digits == 0:
                return True
    
    # yxxx pattern (4-digit)
    if price_len == 4:
        last_3_digits = price % 1000
        if last_3_digits % 45 == 0 and last_3_digits > 0:
            first_2_digits = price // 100
            if first_2_digits % 45 != 0 or first_2_digits == 0:
                return True
    
    return False

def is_regular_45_multiple(price):
    """REGULAR 45° multiples (YELLOW)"""
    if price % 45 != 0 or price <= 0:
        return False
    
    # Exclude priority patterns
    priority_patterns = [45, 90, 135, 180, 225, 270, 315, 360]
    if price in priority_patterns:
        return False
    
    # Exclude if it's a long-term pattern
    if is_bold_pattern(price):
        return False
    
    # Exclude if it's a short-term pattern
    if is_short_term_pattern(price):
        return False
    
    return True

def explain_pattern(price):
    """Explain why a number matches a pattern"""
    price_str = str(price)
    price_len = len(price_str)
    
    is_long = is_bold_pattern(price)
    is_short = is_short_term_pattern(price)
    is_regular = is_regular_45_multiple(price)
    
    if not is_long and not is_short and not is_regular:
        return "Not a 45° pattern"
    
    if is_regular:
        return f"Regular 45° multiple ({price} ÷ 45 = {price//45})"
    
    # Priority patterns
    priority_patterns = [45, 90, 135, 180, 225, 270, 315, 360]
    if price in priority_patterns:
        return f"Priority Gann level ({price}°)"
    
    if is_long:
        if price_len == 5:
            last_2_digits = price % 100
            first_3_digits = price // 100
            if last_2_digits == 0 and first_3_digits % 45 == 0:
                return f"xxx00 pattern (first 3: {first_3_digits} ÷ 45 = {first_3_digits//45}, last 2: 00)"
        
        if price_len == 4:
            last_2_digits = price % 100
            first_2_digits = price // 100
            if last_2_digits == 0 and first_2_digits % 45 == 0:
                return f"xx00 pattern (first 2: {first_2_digits} ÷ 45 = {first_2_digits//45}, last 2: 00)"
        
        if price_len == 3:
            return f"xxx pattern ({price} ÷ 45 = {price//45})"
    
    if is_short:
        if price_len == 5:
            last_3_digits = price % 1000
            return f"yyxxx pattern (last 3: {last_3_digits} ÷ 45 = {last_3_digits//45})"
        
        if price_len == 4:
            last_3_digits = price % 1000
            return f"yxxx pattern (last 3: {last_3_digits} ÷ 45 = {last_3_digits//45})"
    
    return "Unknown pattern"

def demonstrate_all_patterns():
    print("=" * 80)
    print("           COMPLETE PATTERN DEMONSTRATION")
    print("=" * 80)
    
    # LONG-TERM PATTERNS (RED BOLD)
    print("\n=== LONG-TERM PATTERNS (RED BOLD LINES) ===")
    
    print("\n--- Priority Patterns ---")
    priority = [45, 90, 135, 180, 225, 270, 315, 360, 405, 450, 495, 540, 585, 630, 675, 720]
    for p in priority:
        if is_bold_pattern(p):
            print(f"{p} = LONG-TERM RED - {explain_pattern(p)}")
    
    print("\n--- xxx00 Patterns (5-digit) ---")
    xxx00_patterns = [4500, 9000, 13500, 18000, 22500, 27000, 31500, 36000, 40500, 45000]
    for p in xxx00_patterns:
        if is_bold_pattern(p):
            print(f"{p} = LONG-TERM RED - {explain_pattern(p)}")
    
    print("\n--- xx00 Patterns (4-digit) ---")
    xx00_patterns = [4500, 9000]  # Only valid ones where first 2 digits are divisible by 45
    for p in xx00_patterns:
        if is_bold_pattern(p):
            print(f"{p} = LONG-TERM RED - {explain_pattern(p)}")
    
    # SHORT-TERM PATTERNS (YELLOW)
    print("\n=== SHORT-TERM PATTERNS (YELLOW LINES) ===")
    
    print("\n--- yyxxx Patterns (5-digit) ---")
    yyxxx_patterns = [12045, 34090, 56135, 78180, 91225, 23270, 45315, 67360]
    for p in yyxxx_patterns:
        if is_short_term_pattern(p):
            print(f"{p} = SHORT-TERM YELLOW - {explain_pattern(p)}")
    
    print("\n--- yxxx Patterns (4-digit) ---")
    yxxx_patterns = [1045, 2090, 3135, 4180, 5225, 6270, 7315, 8360]
    for p in yxxx_patterns:
        if is_short_term_pattern(p):
            print(f"{p} = SHORT-TERM YELLOW - {explain_pattern(p)}")
    
    # REGULAR MULTIPLES (YELLOW)
    print("\n=== REGULAR 45° MULTIPLES (YELLOW LINES) ===")
    regular_multiples = [315, 405, 495, 585, 675, 765, 855, 945, 1035, 1125, 1215, 1305]
    for p in regular_multiples:
        if is_regular_45_multiple(p):
            print(f"{p} = REGULAR YELLOW - {explain_pattern(p)}")
    
    # NEGATIVE EXAMPLES
    print("\n=== NEGATIVE EXAMPLES (NOT 45° PATTERNS) ===")
    negative = [12046, 34091, 56136, 78181, 91226, 12345, 67890]
    for p in negative:
        is_long = is_bold_pattern(p)
        is_short = is_short_term_pattern(p)
        is_regular = is_regular_45_multiple(p)
        
        if not is_long and not is_short and not is_regular:
            print(f"{p} = NOT A 45° PATTERN")
    
    print("\n" + "=" * 80)
    print("                           PATTERN SUMMARY")
    print("=" * 80)
    print("LONG-TERM (RED BOLD):    xxx00, xx00, xxx + Priority levels")
    print("SHORT-TERM (YELLOW):     yyxxx, yxxx patterns")
    print("REGULAR (YELLOW):        Simple 45° multiples (not special patterns)")
    print("=" * 80)

if __name__ == "__main__":
    demonstrate_all_patterns()
