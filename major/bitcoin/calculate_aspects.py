#!/usr/bin/env python3
"""
Major Planetary Aspects Calculator
Generates accurate planetary aspects using PyEphem and exports to CSV for MQ5 use
"""

import ephem
import csv
import datetime
from typing import List, Tuple, Dict, Any, Union
import swisseph as swe
import math
import os
import shutil
from pathlib import Path
import pytz

# Initialize Swiss Ephemeris
swe.set_ephe_path('.')

# Planet codes for Swiss Ephemeris
planets = {
    'Sun': swe.SUN,
    'Moon': swe.MOON,
    'Mercury': swe.MERCURY,
    'Venus': swe.VENUS,
    'Mars': swe.MARS,
    'Jupiter': swe.JUPITER,
    'Saturn': swe.SATURN,
    'Uranus': swe.URANUS,
    'Neptune': swe.NEPTUNE,
    'Pluto': swe.PLUTO
}

# Aspect definitions with tighter orbs for highest accuracy
aspects = {
    'Conjunction': {'angle': 0, 'orb': 0.5, 'abbrev': 'Conj'},      # Reduced from 1.0
    'Semisquare': {'angle': 45, 'orb': 0.5, 'abbrev': 'Semi'},      # Reduced from 1.0  
    'Sextile': {'angle': 60, 'orb': 1.0, 'abbrev': 'Sext'},        # Reduced from 2.0
    'Square': {'angle': 90, 'orb': 1.0, 'abbrev': 'Sq'},           # Reduced from 2.0
    'Trine': {'angle': 120, 'orb': 1.0, 'abbrev': 'Trine'},        # Reduced from 2.0
    'Gann109': {'angle': 109, 'orb': 0.5, 'abbrev': 'G109'},       # Updated from 161
    'Opposition': {'angle': 180, 'orb': 1.0, 'abbrev': 'Opp'},     # Reduced from 2.0
    'Gann74': {'angle': 74, 'orb': 0.5, 'abbrev': 'G74'}          # Updated from 207
}

# MT5 destination folder
MT5_FILES_PATH = r"C:\Users\shali\AppData\Roaming\MetaQuotes\Terminal\5D8E9E7539757427599AFFA39CA368B7\MQL5\Files"

def copy_files_to_mt5():
    """Copy generated CSV files and MQL5 files to MT5 folder"""
    try:
        # Ensure MT5 directory exists
        os.makedirs(MT5_FILES_PATH, exist_ok=True)
        
        # Get current directory
        current_dir = Path.cwd()
        
        # Files to copy
        files_to_copy = [
            # Bitcoin-specific CSV files
            "bitcoin_complete_major_aspects.csv",
            "bitcoin_generated_aspects.csv", 
            "bitcoin_clean_future_aspects.csv",
            "bitcoin_extended_future_aspects.csv",
            # Bitcoin-specific MQL5 files
            "BitcoinMajorAspects.mq5",
            "BitcoinMajorAspectsCSV.mq5", 
            "BitcoinPrice45Degrees.mq5",
            # Swiss Ephemeris files
            "semo_18.se1",
            "sepl_18.se1",
            "swedll32.dll"
        ]
        
        copied_files = []
        
        for filename in files_to_copy:
            source_path = current_dir / filename
            if source_path.exists():
                dest_path = Path(MT5_FILES_PATH) / filename
                shutil.copy2(source_path, dest_path)
                copied_files.append(filename)
                print(f"✓ Copied: {filename}")
            else:
                print(f"⚠ File not found: {filename}")
        
        if copied_files:
            print(f"\n✅ Successfully copied {len(copied_files)} files to MT5 folder:")
            print(f"   {MT5_FILES_PATH}")
        else:
            print("❌ No files were copied")
            
    except Exception as e:
        print(f"❌ Error copying files to MT5: {e}")

def calculate_position(planet_code, jd):
    """Calculate precise planetary position using Swiss Ephemeris with maximum accuracy flags"""
    try:
        # Use highest accuracy flags for maximum precision
        flags = swe.FLG_SWIEPH | swe.FLG_SPEED | swe.FLG_TRUEPOS
        result, ret = swe.calc_ut(jd, planet_code, flags)
        return result[0] if result else None  # Return longitude
    except Exception as e:
        print(f"Error calculating position for planet {planet_code}: {e}")
        return None

def normalize_angle(angle):
    """Normalize angle to 0-360 degrees"""
    while angle < 0:
        angle += 360
    while angle >= 360:
        angle -= 360
    return angle

def angular_distance(lon1, lon2):
    """Calculate the angular distance between two longitudes with proper handling of 0/360 boundary"""
    diff = abs(lon1 - lon2)
    if diff > 180:
        diff = 360 - diff
    return diff

def angular_distance_both_arcs(lon1, lon2):
    """Calculate both short and long arc distances between two longitudes"""
    diff = abs(lon1 - lon2)
    short_arc = diff if diff <= 180 else 360 - diff
    long_arc = diff if diff > 180 else 360 - diff
    return short_arc, long_arc

def is_aspect_within_orb(angle, target_angle, orb):
    """Check if angle is within orb of target aspect angle"""
    diff = abs(angle - target_angle)
    if diff > 180:
        diff = 360 - diff
    return diff <= orb

def is_aspect_within_orb_both_arcs(short_arc, long_arc, target_angle, orb):
    """Check if either arc measurement matches target aspect angle within orb"""
    short_diff = abs(short_arc - target_angle)
    long_diff = abs(long_arc - target_angle)
    return (short_diff <= orb) or (long_diff <= orb)

def find_exact_aspect_time(planet1_code, planet2_code, target_angle, start_jd, search_days=30):
    """Find the exact time when an aspect occurs using binary search for maximum precision"""
    
    def angle_difference_from_target(jd):
        pos1 = calculate_position(planet1_code, jd)
        pos2 = calculate_position(planet2_code, jd)
        if pos1 is None or pos2 is None:
            return float('inf')
        
        current_angle = angular_distance(pos1, pos2)
        
        # Handle opposition case (180 degrees)
        if target_angle == 180:
            return abs(current_angle - 180)
        
        # Handle other aspects - find minimum difference considering 0/360 wrap
        diff1 = abs(current_angle - target_angle)
        diff2 = abs(current_angle - (target_angle + 360))
        diff3 = abs((current_angle + 360) - target_angle)
        
        return min(diff1, diff2, diff3)
    
    # Binary search for exact timing with ultra-high precision
    left_jd = start_jd
    right_jd = start_jd + search_days
    
    # Iterative refinement for maximum accuracy
    for iteration in range(100):  # Increased iterations for ultra-high precision
        mid_jd = (left_jd + right_jd) / 2
        
        left_diff = angle_difference_from_target(left_jd)
        mid_diff = angle_difference_from_target(mid_jd)
        right_diff = angle_difference_from_target(right_jd)
        
        if mid_diff < 0.0001:  # Ultra-tight precision: 0.0001 degrees (about 0.36 arcseconds)
            return mid_jd
        
        if left_diff < right_diff:
            right_jd = mid_jd
        else:
            left_jd = mid_jd
    
    return (left_jd + right_jd) / 2

def is_aspect_within_orb(angle, target_angle, orb):
    """Check if angle is within orb of target aspect angle"""
    diff = abs(angle - target_angle)
    if diff > 180:
        diff = 360 - diff
    return diff <= orb

def scan_for_aspects(start_date, end_date, step_hours=3):
    """Scan for aspects with ultra-high precision timing"""
    start_jd = swe.julday(start_date.year, start_date.month, start_date.day, 
                         start_date.hour + start_date.minute/60.0)
    end_jd = swe.julday(end_date.year, end_date.month, end_date.day, 
                       end_date.hour + end_date.minute/60.0)
    
    found_aspects = []
    current_jd = start_jd
    step_jd = step_hours / 24.0  # Convert hours to Julian day fraction
    
    # Include all major planets for comprehensive analysis
    all_planets = ['Sun', 'Moon', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn', 'Uranus', 'Neptune', 'Pluto']
    planet_pairs = []
    
    # Generate all possible planet pairs
    for i, planet1 in enumerate(all_planets):
        for j, planet2 in enumerate(all_planets):
            if i < j:  # Avoid duplicates
                planet_pairs.append((planet1, planet2))
    
    print(f"Scanning {len(planet_pairs)} planet pairs from {start_date} to {end_date}")
    print(f"Step size: {step_hours} hours for maximum precision")
    
    previous_angles = {}
    
    while current_jd <= end_jd:
        current_date = swe.jdut1_to_utc(current_jd, 1)[0:6]  # Get UTC components
        dt = datetime(*current_date[:6])
        
        for planet1, planet2 in planet_pairs:
            pair_key = f"{planet1}-{planet2}"
            
            pos1 = calculate_position(planets[planet1], current_jd)
            pos2 = calculate_position(planets[planet2], current_jd)
            
            if pos1 is None or pos2 is None:
                continue
            
            current_angle = angular_distance(pos1, pos2)
            
            # Check for aspects
            for aspect_name, aspect_info in aspects.items():
                target_angle = aspect_info['angle']
                orb = aspect_info['orb']
                
                if is_aspect_within_orb(current_angle, target_angle, orb):
                    # Find exact timing with ultra-high precision
                    exact_jd = find_exact_aspect_time(planets[planet1], planets[planet2], 
                                                    target_angle, current_jd - 0.5, 1)
                    
                    if exact_jd:
                        exact_date_components = swe.jdut1_to_utc(exact_jd, 1)[0:6]
                        exact_dt = datetime(*exact_date_components[:6])
                        
                        # Calculate exact positions at precise time
                        exact_pos1 = calculate_position(planets[planet1], exact_jd)
                        exact_pos2 = calculate_position(planets[planet2], exact_jd)
                        exact_angle = angular_distance(exact_pos1, exact_pos2)
                        
                        # Verify this is actually the target aspect within ultra-tight tolerance
                        angle_error = abs(exact_angle - target_angle)
                        if target_angle == 180:
                            angle_error = abs(exact_angle - 180)
                        elif target_angle == 0:
                            angle_error = min(exact_angle, 360 - exact_angle)
                        
                        if angle_error <= 0.01:  # Ultra-tight tolerance: 0.01 degrees (36 arcseconds)
                            # Convert UTC time to Greek time (EEST/EET) for CSV output
                            utc_dt = datetime(*exact_date_components[:6])
                            utc_dt = utc_dt.replace(tzinfo=pytz.UTC)
                            
                            # Convert to Greek time (handles DST automatically)
                            greek_tz = pytz.timezone('Europe/Athens')
                            greek_dt = utc_dt.astimezone(greek_tz)
                            
                            aspect_data = {
                                'date': greek_dt.strftime('%Y.%m.%d'),
                                'time': greek_dt.strftime('%H:%M'),
                                'planet1': planet1,
                                'planet2': planet2,
                                'aspect': aspect_name,
                                'aspect_abbrev': aspect_info['abbrev'],
                                'angle': round(exact_angle, 6),  # Ultra-high precision output
                                'planet1_lon': round(exact_pos1, 6),
                                'planet2_lon': round(exact_pos2, 6),
                                'description': f"{planet1}-{planet2} {aspect_info['abbrev']}",
                                'exact_jd': exact_jd,
                                'angle_error': round(angle_error, 6)
                            }
                            
                            found_aspects.append(aspect_data)
                            print(f"  Keeping: {exact_dt.strftime('%Y-%m-%d')} ('{planet1}', '{planet2}') {aspect_name} ({exact_angle:.3f}°)")
        
        current_jd += step_jd
        
        # Progress indicator
        progress = (current_jd - start_jd) / (end_jd - start_jd) * 100
        if int(progress) % 5 == 0 and current_jd - start_jd > 0:
            print(f"Progress: {progress:.1f}%")
    
    return found_aspects

def remove_duplicate_aspects(aspects_list, time_threshold_hours=24):
    """Remove consecutive duplicate aspects with improved algorithm"""
    if not aspects_list:
        return []
    
    # Sort by datetime for proper sequential processing
    aspects_list.sort(key=lambda x: datetime.strptime(f"{x['date']} {x['time']}", '%Y.%m.%d %H:%M'))
    
    filtered_aspects = []
    
    for current_aspect in aspects_list:
        current_dt = datetime.strptime(f"{current_aspect['date']} {current_aspect['time']}", '%Y.%m.%d %H:%M')
        current_key = (current_aspect['planet1'], current_aspect['planet2'], current_aspect['aspect'])
        
        # Check if this is a duplicate of recent aspect
        is_duplicate = False
        for recent_aspect in filtered_aspects[-3:]:  # Check last 3 aspects
            recent_dt = datetime.strptime(f"{recent_aspect['date']} {recent_aspect['time']}", '%Y.%m.%d %H:%M')
            recent_key = (recent_aspect['planet1'], recent_aspect['planet2'], recent_aspect['aspect'])
            
            if (current_key == recent_key and 
                abs((current_dt - recent_dt).total_seconds()) < time_threshold_hours * 3600):
                
                # Keep the more accurate one (smaller angle error)
                if current_aspect.get('angle_error', 1) < recent_aspect.get('angle_error', 1):
                    # Replace the recent one with current (more accurate)
                    filtered_aspects = [a for a in filtered_aspects if a != recent_aspect]
                    break
                else:
                    is_duplicate = True
                    break
        
        if not is_duplicate:
            filtered_aspects.append(current_aspect)
    
    return filtered_aspects

class AspectCalculator:
    def __init__(self):
        # Define ALL planets - both fast and slow moving
        self.all_planets = {
            # Luminaries (most important in Gann analysis)
            'Sun': ephem.Sun(),
            'Moon': ephem.Moon(),
            # Fast-moving planets (inner planets)
            'Mercury': ephem.Mercury(),
            'Venus': ephem.Venus(), 
            'Mars': ephem.Mars(),
            # Slow-moving planets (outer planets)
            'Jupiter': ephem.Jupiter(),
            'Saturn': ephem.Saturn(),
            'Uranus': ephem.Uranus(),
            'Neptune': ephem.Neptune(),
            'Pluto': ephem.Pluto()
        }
        
        # Planet groups for easy toggling
        self.luminaries = ['Sun', 'Moon']
        self.fast_planets = ['Mercury', 'Venus', 'Mars']
        self.slow_planets = ['Jupiter', 'Saturn', 'Uranus', 'Neptune', 'Pluto']
        
        # Toggle settings (can be modified via function parameters)
        self.use_luminaries = True      # Sun & Moon (Gann considered these essential)
        self.use_fast_planets = False   # Mercury, Venus, Mars (for short-term aspects)
        self.use_slow_planets = True    # Jupiter through Pluto (for long-term aspects)
        
        # Build active planet list based on toggles
        self.planets = {}
        self._update_active_planets()
        
        # Define major aspects including Gann angles (in degrees)
        self.aspects = {
            'Conjunction': 0,
            'Semisquare': 45,
            'Sextile': 60,
            'Square': 90,
            'Trine': 120,
            'Gann109': 109,
            'Opposition': 180,
            'Gann74': 74
        }
        
        # Default orb tolerance
        self.orb = 1.0
        
        # Minimum days between same aspects for deduplication
        self.min_days_between_aspects = 14  # 2 weeks minimum
    
    def _update_active_planets(self):
        """Update the active planets dictionary based on toggle settings"""
        self.planets = {}
        
        if self.use_luminaries:
            for planet in self.luminaries:
                self.planets[planet] = self.all_planets[planet]
                
        if self.use_fast_planets:
            for planet in self.fast_planets:
                self.planets[planet] = self.all_planets[planet]
                
        if self.use_slow_planets:
            for planet in self.slow_planets:
                self.planets[planet] = self.all_planets[planet]
    
    def set_planet_groups(self, use_luminaries=True, use_fast_planets=False, use_slow_planets=True):
        """Configure which planet groups to use for aspect calculations"""
        self.use_luminaries = use_luminaries
        self.use_fast_planets = use_fast_planets
        self.use_slow_planets = use_slow_planets
        self._update_active_planets()
        
        print(f"=== PLANET CONFIGURATION ===")
        print(f"Luminaries (Sun, Moon): {'ENABLED' if use_luminaries else 'DISABLED'}")
        print(f"Fast Planets (Mercury, Venus, Mars): {'ENABLED' if use_fast_planets else 'DISABLED'}")
        print(f"Slow Planets (Jupiter-Pluto): {'ENABLED' if use_slow_planets else 'DISABLED'}")
        print(f"Active planets: {list(self.planets.keys())}")
        print(f"Total planet pairs: {len(self.planets) * (len(self.planets) - 1) // 2}")
        
        return len(self.planets)
    
    def calculate_angle_between_planets(self, planet1_lon: float, planet2_lon: float) -> tuple:
        """Calculate both short and long arc angular separations between two planetary longitudes"""
        diff = abs(planet1_lon - planet2_lon)
        short_arc = diff if diff <= 180 else 360 - diff
        long_arc = diff if diff > 180 else 360 - diff
        return short_arc, long_arc
    
    def get_aspect_type(self, short_arc: float, long_arc: float) -> str:
        """Determine the aspect type based on both arc measurements"""
        # Check short arc for most aspects
        for aspect_name, aspect_angle in self.aspects.items():
            if aspect_name == 'Gann74':
                # For 74° aspects, check the long arc (since 74° is the complement to 286°)
                if abs(long_arc - (360 - aspect_angle)) <= self.orb:
                    return aspect_name
            else:
                # For other aspects, check the short arc
                if abs(short_arc - aspect_angle) <= self.orb:
                    return aspect_name
        return ""
    
    def get_aspect_abbreviation(self, aspect_name: str) -> str:
        """Get short abbreviation for aspect"""
        abbrev = {
            'Conjunction': 'Conj',
            'Semisquare': 'Semi',
            'Sextile': 'Sext',
            'Square': 'Sq',
            'Trine': 'Trine',
            'Gann109': 'G109',
            'Opposition': 'Opp',
            'Gann74': 'G74'
        }
        return abbrev.get(aspect_name, aspect_name)
    
    def calculate_planetary_positions(self, date: Any) -> Dict[str, float]:
        """Calculate planetary positions for a given date"""
        positions = {}
        for name, planet in self.planets.items():
            planet.compute(date)
            # Convert to degrees (ephem uses radians)
            positions[name] = float(planet.hlon) * 180.0 / ephem.pi
        return positions
    
    def find_aspects_for_date(self, date: Any) -> List[Dict[str, Any]]:
        """Find all major aspects for a specific date"""
        positions = self.calculate_planetary_positions(date)
        aspects_found = []
        
        planet_names = list(self.planets.keys())
        
        # Check all planet pairs
        for i in range(len(planet_names)):
            for j in range(i + 1, len(planet_names)):
                planet1 = planet_names[i]
                planet2 = planet_names[j]
                
                short_arc, long_arc = self.calculate_angle_between_planets(
                    positions[planet1], 
                    positions[planet2]
                )
                
                aspect_type = self.get_aspect_type(short_arc, long_arc)
                
                if aspect_type:
                    # Use the appropriate angle measurement for the aspect
                    if aspect_type == 'Gann74':
                        angle_to_record = long_arc
                    else:
                        angle_to_record = short_arc
                        
                    aspects_found.append({
                        'date': date,
                        'planet1': planet1,
                        'planet2': planet2,
                        'aspect': aspect_type,
                        'angle': angle_to_record,
                        'planet1_lon': positions[planet1],
                        'planet2_lon': positions[planet2]
                    })
        
        return aspects_found
    
    def deduplicate_aspects(self, aspects: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Remove consecutive duplicate aspects, keeping only significant entries"""
        if not aspects:
            return aspects
        
        # Sort by date first
        sorted_aspects = sorted(aspects, key=lambda x: x['date'])
        
        deduplicated = []
        aspect_tracking = {}  # Track last occurrence of each aspect type
        
        print("=== DEDUPLICATING ASPECTS ===")
        print(f"Processing {len(sorted_aspects)} aspects...")
        
        for aspect in sorted_aspects:
            # Create unique key for aspect pair
            planet_pair = tuple(sorted([aspect['planet1'], aspect['planet2']]))
            aspect_key = (planet_pair, aspect['aspect'])
            
            # Convert date to comparable format
            if hasattr(aspect['date'], 'datetime'):
                current_date = aspect['date']
            else:
                current_date = ephem.Date(aspect['date'])
            
            # Check if this is a new aspect or significantly different timing
            should_include = True
            
            if aspect_key in aspect_tracking:
                last_date = aspect_tracking[aspect_key]['date']
                days_diff = current_date - last_date
                
                # Skip if same aspect occurred too recently
                if days_diff < self.min_days_between_aspects:
                    should_include = False
                    
                    # But include if this is significantly more exact
                    last_angle_diff = abs(aspect_tracking[aspect_key]['angle'] - self.aspects[aspect['aspect']])
                    current_angle_diff = abs(aspect['angle'] - self.aspects[aspect['aspect']]);
                    
                    if current_angle_diff < last_angle_diff - 0.1:  # More exact by 0.1 degrees
                        should_include = True
                        print(f"  Replacing less exact: {planet_pair} {aspect['aspect']} - more exact by {last_angle_diff - current_angle_diff:.2f}°")
                        
                        # Remove the previous less exact entry
                        deduplicated = [a for a in deduplicated if not (
                            tuple(sorted([a['planet1'], a['planet2']])) == planet_pair and
                            a['aspect'] == aspect['aspect'] and
                            abs(a['date'] - last_date) < 1  # Within 1 day
                        )]
            
            if should_include:
                deduplicated.append(aspect)
                aspect_tracking[aspect_key] = {
                    'date': current_date,
                    'angle': aspect['angle']
                }
                
                # Show what we're keeping
                if hasattr(current_date, 'datetime'):
                    date_str = current_date.datetime().strftime('%Y-%m-%d')
                else:
                    date_str = str(current_date)[:10]
                print(f"  Keeping: {date_str} {planet_pair} {aspect['aspect']} ({aspect['angle']:.2f}°)")
        
        print(f"Reduced from {len(sorted_aspects)} to {len(deduplicated)} aspects")
        print(f"Removed {len(sorted_aspects) - len(deduplicated)} duplicate/consecutive aspects")
        
        return deduplicated
    
    def find_exact_aspect_dates(self, start_date: str, end_date: str, precision_hours: int = 6) -> List[Dict[str, Any]]:
        """Find exact dates when aspects are most precise, avoiding retrograde duplicates"""
        print("=== FINDING EXACT ASPECT DATES ===")
        
        start = ephem.Date(start_date)
        end = ephem.Date(end_date)
        
        exact_aspects = []
        current_date = start
        step = precision_hours / 24.0  # Convert hours to days
        
        # Track aspects to avoid duplicates during retrograde periods
        aspect_windows = {}
        
        while current_date <= end:
            aspects = self.find_aspects_for_date(current_date)
            
            for aspect in aspects:
                planet_pair = tuple(sorted([aspect['planet1'], aspect['planet2']]))
                aspect_key = (planet_pair, aspect['aspect'])
                target_angle = self.aspects[aspect['aspect']]
                angle_precision = abs(aspect['angle'] - target_angle)
                
                # Check if we're in a tracking window for this aspect
                if aspect_key in aspect_windows:
                    window = aspect_windows[aspect_key]
                    
                    # Update if more precise
                    if angle_precision < window['best_precision']:
                        window['best_precision'] = angle_precision
                        window['best_aspect'] = aspect
                        window['last_seen'] = current_date
                    elif current_date - window['last_seen'] > 30:  # End window after 30 days
                        # Save the best aspect from this window
                        if window['best_aspect']:
                            exact_aspects.append(window['best_aspect'])
                            
                            date_str = window['best_aspect']['date'].datetime().strftime('%Y-%m-%d %H:%M') if hasattr(window['best_aspect']['date'], 'datetime') else str(window['best_aspect']['date'])
                            print(f"Exact: {date_str} {planet_pair} {window['best_aspect']['aspect']} ({window['best_aspect']['angle']:.4f}°)")
                        
                        # Start new window
                        aspect_windows[aspect_key] = {
                            'best_precision': angle_precision,
                            'best_aspect': aspect,
                            'last_seen': current_date
                        }
                else:
                    # Start new tracking window
                    aspect_windows[aspect_key] = {
                        'best_precision': angle_precision,
                        'best_aspect': aspect,
                        'last_seen': current_date
                    }
            
            current_date += step
            
            # Progress indicator
            if int(current_date) % 365 == 0:  # Every year
                year = int(current_date) + 1900  # Ephem years start from 1900
                print(f"  Processing year ~{year}...")
        
        # Add remaining aspects from open windows
        for window in aspect_windows.values():
            if window['best_aspect']:
                exact_aspects.append(window['best_aspect'])
        
        # Final deduplication
        return self.deduplicate_aspects(exact_aspects)
    
    def export_to_csv(self, aspects: List[Dict[str, Any]], filename: str):
        """Export aspects to CSV file for MQ5 consumption"""
        with open(filename, 'w', newline='', encoding='utf-8') as csvfile:
            fieldnames = [
                'date', 'time', 'planet1', 'planet2', 'aspect', 'aspect_abbrev',
                'angle', 'planet1_lon', 'planet2_lon', 'description'
            ]
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            
            writer.writeheader()
            
            for aspect in aspects:
                # Convert ephem date to datetime - handle both ephem.Date and string formats
                if isinstance(aspect['date'], ephem.Date):
                    dt = aspect['date'].datetime()
                elif isinstance(aspect['date'], str):
                    dt = datetime.datetime.strptime(aspect['date'], '%Y/%m/%d %H:%M:%S')
                elif isinstance(aspect['date'], (int, float)):
                    # Handle Julian day numbers from ephem
                    dt = ephem.Date(aspect['date']).datetime()
                else:
                    # Fallback - try to convert to ephem date first
                    dt = ephem.Date(aspect['date']).datetime()
                
                # Convert UTC time to Greek time (EEST/EET) for CSV output
                if dt.tzinfo is None:  # If no timezone info, assume UTC
                    dt = dt.replace(tzinfo=pytz.UTC)
                
                # Convert to Greek time (handles DST automatically)
                greek_tz = pytz.timezone('Europe/Athens')
                greek_dt = dt.astimezone(greek_tz)
                
                aspect_abbrev = self.get_aspect_abbreviation(aspect['aspect'])
                description = f"{aspect['planet1']}-{aspect['planet2']} {aspect_abbrev}"
                
                writer.writerow({
                    'date': greek_dt.strftime('%Y.%m.%d'),
                    'time': greek_dt.strftime('%H:%M'),
                    'planet1': aspect['planet1'],
                    'planet2': aspect['planet2'],
                    'aspect': aspect['aspect'],
                    'aspect_abbrev': aspect_abbrev,
                    'angle': f"{aspect['angle']:.4f}",
                    'planet1_lon': f"{aspect['planet1_lon']:.4f}",
                    'planet2_lon': f"{aspect['planet2_lon']:.4f}",
                    'description': description
                })
        
        print(f"Exported {len(aspects)} aspects to {filename}")

    def scan_date_range(self, start_date: str, end_date: str, step_days: int = 1) -> List[Dict[str, Any]]:
        """Scan a date range for major aspects"""
        start = ephem.Date(start_date)
        end = ephem.Date(end_date)
        
        all_aspects = []
        current_date = start
        
        print(f"Scanning from {start_date} to {end_date} (step: {step_days} days)")
        
        while current_date <= end:
            aspects = self.find_aspects_for_date(current_date)
            all_aspects.extend(aspects)
            current_date += step_days
            
            # Progress indicator - fix the tuple() error
            current_year = int(current_date)  # Get year as integer
            if current_year % 1 == 0:  # Every year
                print(f"Processing: {current_date}")
        
        return all_aspects
    
    def verify_known_aspects(self, known_aspects: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Verify a list of known aspects against calculations"""
        verified_aspects = []
        
        print("=== VERIFYING KNOWN ASPECTS ===")
        
        for aspect in known_aspects:
            date = ephem.Date(aspect['date'])
            positions = self.calculate_planetary_positions(date)
            
            planet1 = aspect['planet1']
            planet2 = aspect['planet2']
            
            if planet1 in positions and planet2 in positions:
                angle = self.calculate_angle_between_planets(
                    positions[planet1], 
                    positions[planet2]
                )
                
                calculated_aspect = self.get_aspect_type(angle)
                expected_aspect = aspect['expected_aspect']
                
                verified = (calculated_aspect == expected_aspect)
                
                result = {
                    'date': aspect['date'],
                    'planet1': planet1,
                    'planet2': planet2,
                    'aspect': calculated_aspect if calculated_aspect else expected_aspect,  # Fix KeyError
                    'expected_aspect': expected_aspect,
                    'calculated_aspect': calculated_aspect,
                    'angle': angle,
                    'verified': verified,
                    'planet1_lon': positions[planet1],
                    'planet2_lon': positions[planet2]
                }
                
                verified_aspects.append(result)
                
                status = "✓ VERIFIED" if verified else "✗ MISMATCH"
                print(f"{aspect['date']}: {planet1}-{planet2} {expected_aspect}")
                print(f"  Expected: {expected_aspect}, Calculated: {calculated_aspect} ({angle:.4f}°)")
                print(f"  Status: {status}")
                print(f"  {planet1}: {positions[planet1]:.4f}° | {planet2}: {positions[planet2]:.4f}°")
                print("  ---")
        
        return verified_aspects

    def find_exact_aspects(self, start_date: str, end_date: str, target_aspects: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Find exact dates for target aspects"""
        print("=== FINDING EXACT ASPECT DATES ===")
        
        exact_aspects = []
        
        for target in target_aspects:
            planet1 = target['planet1'] 
            planet2 = target['planet2']
            expected_aspect = target['expected_aspect']
            approx_date = ephem.Date(target['date'])
            
            # Search around the approximate date (±30 days)
            best_date = None
            best_angle_diff = float('inf')
            target_angle = self.aspects[expected_aspect]
            
            for days_offset in range(-30, 31):
                test_date = approx_date + days_offset
                positions = self.calculate_planetary_positions(test_date)
                
                if planet1 in positions and planet2 in positions:
                    angle = self.calculate_angle_between_planets(
                        positions[planet1], 
                        positions[planet2]
                    )
                    
                    angle_diff = abs(angle - target_angle)
                    if angle_diff < best_angle_diff:
                        best_angle_diff = angle_diff
                        best_date = test_date
            
            if best_date and best_angle_diff <= 2.0:  # Within 2 degrees
                positions = self.calculate_planetary_positions(best_date)
                angle = self.calculate_angle_between_planets(
                    positions[planet1], 
                    positions[planet2]
                )
                
                exact_aspects.append({
                    'date': best_date,
                    'planet1': planet1,
                    'planet2': planet2,
                    'aspect': expected_aspect,
                    'angle': angle,
                    'planet1_lon': positions[planet1],
                    'planet2_lon': positions[planet2]
                })
                
                print(f"Found: {planet1}-{planet2} {expected_aspect}")
                print(f"  Exact date: {best_date}")
                print(f"  Angle: {angle:.4f}° (diff: {best_angle_diff:.4f}°)")
                print("  ---")
        
        return exact_aspects

def main():
    calculator = AspectCalculator()
    
    # MQL5 Files directory path
    mql5_files_path = r"C:\Users\shali\AppData\Roaming\MetaQuotes\Terminal\5D8E9E7539757427599AFFA39CA368B7\MQL5\Files"
    
    print("=== PLANETARY ASPECT CALCULATOR ===")
    print("Multiple planet group configurations available:")
    print("1. Luminaries only (Sun, Moon)")
    print("2. Slow planets only (Jupiter-Pluto)")  
    print("3. All planets (Sun, Moon, Mercury-Pluto)")
    print("4. Custom combinations")
    
    # Configuration: ALL PLANETS (recommended for comprehensive Gann analysis)
    calculator.set_planet_groups(
        use_luminaries=True,    # Sun & Moon - essential for Gann timing
        use_fast_planets=True,  # Mercury, Venus, Mars - for short-term aspects  
        use_slow_planets=True   # Jupiter-Pluto - for major long-term cycles
    )
    
    print("\nUsing ALL PLANETS configuration for comprehensive Gann analysis")
    print("This includes Sun & Moon (essential) + all planets Mercury through Pluto")
    print("Toggle options available in set_planet_groups() function:")
    print("  - use_luminaries: Sun & Moon (timing cycles)")
    print("  - use_fast_planets: Mercury, Venus, Mars (short-term)")
    print("  - use_slow_planets: Jupiter through Pluto (major cycles)")
    
    # Generate clean aspects using exact method with ultra-high precision - starting from 2020
    future_aspects = calculator.find_exact_aspect_dates('2020/01/01', '2050/12/31', precision_hours=2)
    
    # Convert all dates to ephem.Date for consistent sorting
    for aspect in future_aspects:
        if isinstance(aspect['date'], str):
            aspect['date'] = ephem.Date(aspect['date'])
        elif isinstance(aspect['date'], (int, float)):
            aspect['date'] = ephem.Date(aspect['date'])
    
    future_aspects.sort(key=lambda x: x['date'])
    
    # Export files with bitcoin prefix to avoid conflicts with gold data
    calculator.export_to_csv(future_aspects, 'bitcoin_clean_future_aspects.csv')
    calculator.export_to_csv(future_aspects, f'{mql5_files_path}\\bitcoin_clean_future_aspects.csv')
    
    calculator.export_to_csv(future_aspects, 'bitcoin_generated_aspects.csv')
    calculator.export_to_csv(future_aspects, f'{mql5_files_path}\\bitcoin_generated_aspects.csv')
    
    # Keep complete file for reference
    calculator.export_to_csv(future_aspects, 'bitcoin_complete_major_aspects.csv')
    calculator.export_to_csv(future_aspects, f'{mql5_files_path}\\bitcoin_complete_major_aspects.csv')
    
    # Copy files to MT5 folder
    copy_files_to_mt5()
    
    print(f"\n=== SUMMARY ===")
    print(f"✓ bitcoin_clean_future_aspects.csv: {len(future_aspects)} aspects (2020-2050)")
    print(f"✓ bitcoin_generated_aspects.csv: {len(future_aspects)} aspects (for MT5)")
    print(f"✓ bitcoin_complete_major_aspects.csv: {len(future_aspects)} total aspects")
    
    print(f"\n=== ASPECT TYPES INCLUDED ===")
    aspect_counts = {}
    for aspect in future_aspects:
        aspect_type = aspect['aspect']
        aspect_counts[aspect_type] = aspect_counts.get(aspect_type, 0) + 1
    
    for aspect_type, count in sorted(aspect_counts.items()):
        print(f"✓ {aspect_type}: {count} occurrences")
    
    print(f"\n=== PLANET COMBINATIONS ===")
    planet_pairs = {}
    for aspect in future_aspects:
        pair = f"{aspect['planet1']}-{aspect['planet2']}"
        planet_pairs[pair] = planet_pairs.get(pair, 0) + 1
    
    # Show top 15 most active planet pairs
    sorted_pairs = sorted(planet_pairs.items(), key=lambda x: x[1], reverse=True)[:15]
    for pair, count in sorted_pairs:
        print(f"✓ {pair}: {count} aspects")
    
    if future_aspects:
        first_date = min(aspect['date'] for aspect in future_aspects)
        last_date = max(aspect['date'] for aspect in future_aspects)
        print(f"\n=== DATE COVERAGE ===")
        print(f"Aspects span: {first_date} to {last_date}")
    
    print(f"\n=== FILE LOCATIONS ===")
    print(f"Local files: c:\\Trading\\major\\")
    print(f"MQL5 files: {mql5_files_path}")
    print(f"\nAll files exported to both locations!")
    
    # Show upcoming Gann aspects for reference
    print(f"\n=== UPCOMING GANN ASPECTS (G109 & G74) ===")
    gann_aspects = [a for a in future_aspects if a['aspect'] in ['Gann109', 'Gann74']]
    for aspect in gann_aspects[:15]:  # Show first 15
        date_str = aspect['date'].datetime().strftime('%Y-%m-%d') if hasattr(aspect['date'], 'datetime') else str(aspect['date'])[:10]
        print(f"{date_str}: {aspect['planet1']}-{aspect['planet2']} {aspect['aspect']} ({aspect['angle']:.2f}°)")

# Alternative configurations for different analysis types  
def generate_luminaries_only():
    """Generate aspects using only Sun and Moon - for pure luminaries analysis"""
    calculator = AspectCalculator()
    calculator.set_planet_groups(use_luminaries=True, use_fast_planets=False, use_slow_planets=False)
    return calculator.find_exact_aspect_dates('2020/01/01', '2050/12/31', precision_hours=4)

def generate_fast_planets_only():
    """Generate aspects using only Mercury, Venus, Mars - for short-term trading"""
    calculator = AspectCalculator()
    calculator.set_planet_groups(use_luminaries=False, use_fast_planets=True, use_slow_planets=False)
    return calculator.find_exact_aspect_dates('2020/01/01', '2030/12/31', precision_hours=2)

def generate_slow_planets_only():
    """Generate aspects using only Jupiter through Pluto - for major cycles"""
    calculator = AspectCalculator()
    calculator.set_planet_groups(use_luminaries=False, use_fast_planets=False, use_slow_planets=True)
    return calculator.find_exact_aspect_dates('2020/01/01', '2050/12/31', precision_hours=12)

def generate_gann_essentials():
    """Generate aspects using Sun, Moon + outer planets - Gann's preferred combination"""
    calculator = AspectCalculator()
    calculator.set_planet_groups(use_luminaries=True, use_fast_planets=False, use_slow_planets=True)
    return calculator.find_exact_aspect_dates('2020/01/01', '2050/12/31', precision_hours=6)

def generate_custom_configuration(luminaries=True, fast=True, slow=True):
    """Generate aspects with custom planet selection"""
    calculator = AspectCalculator()
    calculator.set_planet_groups(
        use_luminaries=luminaries,
        use_fast_planets=fast,
        use_slow_planets=slow
    )
    return calculator.find_exact_aspect_dates('2020/01/01', '2050/12/31', precision_hours=8)

if __name__ == "__main__":
    main()