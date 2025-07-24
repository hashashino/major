#!/usr/bin/env python3
"""
Major Planetary Aspects Calculator with Custom Gann Angles
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

# MT5 destination folder
MT5_FILES_PATH = r"C:\Users\shali\AppData\Roaming\MetaQuotes\Terminal\5D8E9E7539757427599AFFA39CA368B7\MQL5\Files"

class AspectCalculator:
    def __init__(self, gann_angles=None):
        """
        Initialize the calculator with optional custom Gann angles
        
        Args:
            gann_angles (list): List of custom Gann angles to include (e.g., [104, 192])
        """
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
        
        # Define standard aspects
        self.standard_aspects = {
            'Conjunction': 0,
            'Semisquare': 45,
            'Sextile': 60,
            'Square': 90,
            'Trine': 120,
            'Opposition': 180
        }
        
        # Initialize Gann angles (default to empty if none provided)
        self.gann_angles = {}
        if gann_angles:
            for angle in gann_angles:
                self.gann_angles[f'Gann{angle}'] = angle
        
        # Combine standard and Gann aspects
        self.aspects = {**self.standard_aspects, **self.gann_angles}
        
        # Default orb tolerance
        self.orb = 1.0
        
        # Minimum days between same aspects for deduplication
        self.min_days_between_aspects = 14  # 2 weeks minimum
    
    def set_gann_angles(self, angles: list):
        """Set custom Gann angles"""
        self.gann_angles = {}
        for angle in angles:
            self.gann_angles[f'Gann{angle}'] = angle
        self.aspects = {**self.standard_aspects, **self.gann_angles}
    
    def get_aspects_config(self):
        """Return the current aspects configuration"""
        return self.aspects
    
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
        # Check short arc for standard aspects
        for aspect_name, aspect_angle in self.standard_aspects.items():
            if abs(short_arc - aspect_angle) <= self.orb:
                return aspect_name
        
        # Check long arc for Gann angles
        for aspect_name, aspect_angle in self.gann_angles.items():
            if abs(long_arc - aspect_angle) <= self.orb:
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
            'Opposition': 'Opp'
        }
        
        # Handle Gann angles (e.g., 'Gann104' becomes 'G104')
        if aspect_name.startswith('Gann'):
            return f"G{aspect_name[4:]}"
        
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
                    if aspect_type in self.gann_angles:
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
    
    # [Rest of the methods remain the same as in the original file...]
    # deduplicate_aspects, find_exact_aspect_dates, export_to_csv, etc.

def main():
    print("=== PLANETARY ASPECT CALCULATOR WITH CUSTOM GANN ANGLES ===")
    
    # Get custom Gann angles from user
    print("\nEnter custom Gann angles (comma-separated, e.g., 104,192):")
    gann_input = input("Gann angles (leave empty for none): ").strip()
    
    if gann_input:
        try:
            gann_angles = [int(angle.strip()) for angle in gann_input.split(',')]
            print(f"Using custom Gann angles: {gann_angles}")
        except ValueError:
            print("Invalid input. Using default Gann angles (104, 192).")
            gann_angles = [104, 192]
    else:
        print("No Gann angles specified. Only standard aspects will be calculated.")
        gann_angles = None
    
    # Initialize calculator with custom Gann angles
    calculator = AspectCalculator(gann_angles=gann_angles)
    
    # Configuration: ALL PLANETS (recommended for comprehensive analysis)
    calculator.set_planet_groups(
        use_luminaries=True,    # Sun & Moon - essential for timing
        use_fast_planets=True,  # Mercury, Venus, Mars - for short-term aspects  
        use_slow_planets=True   # Jupiter-Pluto - for major long-term cycles
    )
    
    # Generate aspects using exact method with high precision - starting from 2020
    future_aspects = calculator.find_exact_aspect_dates('2020/01/01', '2050/12/31', precision_hours=2)
    
    # Convert all dates to ephem.Date for consistent sorting
    for aspect in future_aspects:
        if isinstance(aspect['date'], str):
            aspect['date'] = ephem.Date(aspect['date'])
        elif isinstance(aspect['date'], (int, float)):
            aspect['date'] = ephem.Date(aspect['date'])
    
    future_aspects.sort(key=lambda x: x['date'])
    
    # Export files
    calculator.export_to_csv(future_aspects, 'custom_gann_aspects.csv')
    calculator.export_to_csv(future_aspects, f'{MT5_FILES_PATH}\\custom_gann_aspects.csv')
    
    print(f"\n=== SUMMARY ===")
    print(f"✓ custom_gann_aspects.csv: {len(future_aspects)} aspects (2020-2050)")
    
    # Show aspect configuration
    print(f"\n=== ASPECT CONFIGURATION ===")
    for aspect, angle in calculator.get_aspects_config().items():
        print(f"✓ {aspect}: {angle}°")
    
    # Show upcoming Gann aspects if any were specified
    if gann_angles:
        print(f"\n=== UPCOMING GANN ASPECTS ===")
        gann_aspects = [a for a in future_aspects if a['aspect'].startswith('Gann')]
        for aspect in gann_aspects[:15]:  # Show first 15
            date_str = aspect['date'].datetime().strftime('%Y-%m-%d') if hasattr(aspect['date'], 'datetime') else str(aspect['date'])[:10]
            print(f"{date_str}: {aspect['planet1']}-{aspect['planet2']} {aspect['aspect']} ({aspect['angle']:.2f}°)")

if __name__ == "__main__":
    main()