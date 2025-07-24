#!/usr/bin/env python3
"""
Interactive Gann Aspect Calculator
Lets user input any number of Gann aspect degrees and finds all matching planetary aspects in a date range.
"""

import ephem
import swisseph as swe
import datetime
import pytz
from typing import List, Dict, Any

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

def calculate_position(planet_code, jd):
    flags = swe.FLG_SWIEPH | swe.FLG_SPEED | swe.FLG_TRUEPOS
    result, ret = swe.calc_ut(jd, planet_code, flags)
    return result[0] if result else None

def angular_distance(lon1, lon2):
    diff = abs(lon1 - lon2)
    if diff > 180:
        diff = 360 - diff
    return diff

def is_aspect_within_orb(angle, target_angle, orb):
    diff = abs(angle - target_angle)
    if diff > 180:
        diff = 360 - diff
    return diff <= orb

def is_aspect_within_any(angle, target_angles, orb):
    return any(is_aspect_within_orb(angle, t, orb) for t in target_angles)

def find_gann_aspects(start_date: str, end_date: str, gann_angles: List[float], orb: float = 0.5, step_hours: int = 2) -> List[Dict[str, Any]]:
    start = ephem.Date(start_date)
    end = ephem.Date(end_date)
    start_jd = swe.julday(start.datetime().year, start.datetime().month, start.datetime().day, start.datetime().hour + start.datetime().minute/60.0)
    end_jd = swe.julday(end.datetime().year, end.datetime().month, end.datetime().day, end.datetime().hour + end.datetime().minute/60.0)
    step_jd = step_hours / 24.0
    found_aspects = []
    all_planets = list(planets.keys())
    planet_pairs = [(p1, p2) for i, p1 in enumerate(all_planets) for j, p2 in enumerate(all_planets) if i < j]
    current_jd = start_jd
    while current_jd <= end_jd:
        current_date = swe.jdut1_to_utc(current_jd, 1)[0:6]
        dt = datetime.datetime(*(int(x) for x in current_date[:6]))
        for planet1, planet2 in planet_pairs:
            try:
                pos1 = calculate_position(planets[planet1], current_jd)
                pos2 = calculate_position(planets[planet2], current_jd)
            except Exception as e:
                print(f"Ephemeris error: {e}")
                return []
            if pos1 is None or pos2 is None:
                continue
            angle = angular_distance(pos1, pos2)
            if is_aspect_within_any(angle, gann_angles, orb):
                utc_dt = dt.replace(tzinfo=pytz.UTC)
                greek_tz = pytz.timezone('Europe/Athens')
                greek_dt = utc_dt.astimezone(greek_tz)
                found_aspects.append({
                    'date': greek_dt.strftime('%Y.%m.%d'),
                    'time': greek_dt.strftime('%H:%M'),
                    'planet1': planet1,
                    'planet2': planet2,
                    'angle': round(angle, 4)
                })
        current_jd += step_jd
    return found_aspects

def main():
    print("=== Interactive Gann Aspect Calculator ===")
    start_date = input("Enter start date (YYYY/MM/DD): ").strip()
    end_date = input("Enter end date (YYYY/MM/DD): ").strip()
    gann_degrees = input("Enter Gann aspect degrees separated by commas (e.g. 45,90,104,192): ").strip()
    gann_angles = [float(x) for x in gann_degrees.split(',') if x.strip()]
    orb = float(input("Enter orb/tolerance in degrees (default 0.5): ") or 0.5)
    step_hours = int(input("Step size in hours (default 2): ") or 2)
    print(f"\nSearching for all planetary pairs with aspect(s) {', '.join(str(g) for g in gann_angles)}° ±{orb}° from {start_date} to {end_date}...")
    aspects = find_gann_aspects(start_date, end_date, gann_angles, orb, step_hours)
    print(f"\nFound {len(aspects)} aspects:")
    for a in aspects[:50]:
        print(f"{a['date']} {a['time']}: {a['planet1']}-{a['planet2']} ({a['angle']:.2f}°)")
    if len(aspects) > 50:
        print(f"...and {len(aspects)-50} more.\n")
    save = input("Save results to CSV? (y/n): ").strip().lower()
    if save == 'y':
        import csv
        filename = "gann_" + "_".join(str(int(g)) for g in gann_angles) + "_aspects.csv"
        with open(filename, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=['date','time','planet1','planet2','angle'])
            writer.writeheader()
            for a in aspects:
                writer.writerow(a)
        print(f"Results saved to {filename}")

if __name__ == "__main__":
    main()
