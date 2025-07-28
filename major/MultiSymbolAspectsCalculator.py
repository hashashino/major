#!/usr/bin/env python3
"""
Multi-Symbol Planetary Aspects Calculator
Automatically detects law of vibration and calculates aspects for any trading symbol
Supports all symbols from symbol_discovery.csv with automatic price-to-degrees conversion
"""

import ephem
import csv
import datetime
import pandas as pd
from typing import List, Tuple, Dict, Any, Union, Optional
import swisseph as swe
import math
import os
import shutil
from pathlib import Path
import pytz
import numpy as np
from dataclasses import dataclass
import MetaTrader5 as mt5

# Initialize Swiss Ephemeris
swe.set_ephe_path('.')

@dataclass
class SymbolConfig:
    """Configuration for a trading symbol"""
    symbol: str
    gann_category: str
    price_360_range: float
    degree_per_point: float
    digits: int
    point: float
    tick_size: float
    description: str
    base_currency: str
    profit_currency: str

@dataclass
class VibrationLaw:
    """Law of vibration detected for a symbol"""
    symbol: str
    high_price: float
    low_price: float
    high_date: datetime.datetime
    low_date: datetime.datetime
    price_range: float
    degrees_per_point: float
    vibration_type: str  # "HIGH_TO_LOW" or "LOW_TO_HIGH"

class SymbolConfigLoader:
    """Loads and manages symbol configurations"""
    
    def __init__(self, csv_path: str = "symbol_discovery.csv"):
        self.csv_path = csv_path
        self.symbols = {}
        self.load_symbols()
    
    def load_symbols(self):
        """Load symbol configurations from CSV"""
        try:
            # Load CSV with error handling for malformed lines
            df = pd.read_csv(self.csv_path, on_bad_lines='skip')
            
            for _, row in df.iterrows():
                try:
                    config = SymbolConfig(
                        symbol=row['Symbol'],
                        gann_category=row['GannCategory'],
                        price_360_range=float(row['Price360Range']),
                        degree_per_point=float(row['DegreePerPoint']),
                        digits=int(row['Digits']),
                        point=float(row['Point']),
                        tick_size=float(row['TickSize']),
                        description=row['Description'],
                        base_currency=row['BaseCurrency'],
                        profit_currency=row['ProfitCurrency']
                    )
                    # Remove trailing dash if present
                    clean_symbol = config.symbol.rstrip('-')
                    self.symbols[clean_symbol] = config
                except Exception as row_error:
                    print(f"Warning: Skipping malformed row: {row_error}")
                    continue
                
            print(f"[OK] Loaded {len(self.symbols)} symbol configurations")
            print(f"[OK] Categories: {set(config.gann_category for config in self.symbols.values())}")
            
        except Exception as e:
            print(f"ERROR: Error loading symbol configurations: {e}")
            raise
    
    def get_symbol_config(self, symbol: str) -> Optional[SymbolConfig]:
        """Get configuration for a specific symbol"""
        # Try exact match first
        if symbol in self.symbols:
            return self.symbols[symbol]
        
        # Try without trailing characters
        clean_symbol = symbol.rstrip('-.')
        if clean_symbol in self.symbols:
            return self.symbols[clean_symbol]
        
        # Try case insensitive
        for sym, config in self.symbols.items():
            if sym.upper() == symbol.upper():
                return config
                
        return None
    
    def list_symbols_by_category(self, category: str = None) -> List[str]:
        """List symbols by Gann category"""
        if category:
            return [sym for sym, config in self.symbols.items() 
                   if config.gann_category == category]
        else:
            categories = {}
            for sym, config in self.symbols.items():
                if config.gann_category not in categories:
                    categories[config.gann_category] = []
                categories[config.gann_category].append(sym)
            return categories

class MT5DataProvider:
    """Handles MT5 connection and historical data retrieval"""
    
    def __init__(self):
        self.connected = False
        self.connect_to_mt5()
    
    def connect_to_mt5(self):
        """Establish connection to MT5"""
        if not mt5.initialize():
            print(f"ERROR: Failed to initialize MT5, error code: {mt5.last_error()}")
            return False
        
        self.connected = True
        print(f"[OK] Connected to MT5")
        print(f"[OK] MT5 version: {mt5.version()}")
        return True
    
    def get_historical_data(self, symbol: str, timeframes: List = None) -> Optional[pd.DataFrame]:
        """
        Get historical data for symbol starting from first available record
        Falls back to shorter timeframes if longer ones don't have enough data
        """
        if not self.connected:
            print(f"ERROR: Not connected to MT5")
            return None
        
        # Default timeframes: Start with daily, fall back to shorter
        if timeframes is None:
            timeframes = [
                mt5.TIMEFRAME_D1,   # Daily (primary for accurate levels)
                mt5.TIMEFRAME_H4,   # 4-hour (fallback)
                mt5.TIMEFRAME_H1,   # 1-hour (if 4H insufficient)
                mt5.TIMEFRAME_W1    # Weekly (last resort for very long history)
            ]
        
        for timeframe in timeframes:
            timeframe_name = self.get_timeframe_name(timeframe)
            print(f"Trying {symbol} on {timeframe_name}...")
            
            # Get all available history from first record
            rates = mt5.copy_rates_from_pos(symbol, timeframe, 0, 10000)
            
            if rates is not None and len(rates) > 100:  # Need minimum data for analysis
                df = pd.DataFrame(rates)
                df['time'] = pd.to_datetime(df['time'], unit='s')
                
                print(f"[OK] {symbol}: Got {len(df)} bars on {timeframe_name}")
                print(f"     Data range: {df['time'].min()} to {df['time'].max()}")
                
                return df
            else:
                print(f"     {symbol}: Insufficient data on {timeframe_name} ({len(rates) if rates is not None else 0} bars)")
        
        print(f"WARNING: {symbol}: No suitable timeframe found")
        return None
    
    def get_timeframe_name(self, timeframe):
        """Get human-readable timeframe name"""
        timeframe_names = {
            mt5.TIMEFRAME_W1: "Weekly",
            mt5.TIMEFRAME_D1: "Daily", 
            mt5.TIMEFRAME_H4: "4-Hour",
            mt5.TIMEFRAME_H1: "1-Hour"
        }
        return timeframe_names.get(timeframe, f"TF_{timeframe}")
    
    def disconnect(self):
        """Close MT5 connection"""
        if self.connected:
            mt5.shutdown()
            self.connected = False
            print("[OK] Disconnected from MT5")

class VibrationLawDetector:
    """Automatically detects the law of vibration for any symbol"""
    
    def __init__(self, symbol_config: SymbolConfig):
        self.config = symbol_config
        self.symbol = symbol_config.symbol
        self.mt5_data = MT5DataProvider()
    
    def detect_from_price_levels(self, high_price: float, low_price: float, 
                                high_date: datetime.datetime = None, 
                                low_date: datetime.datetime = None) -> VibrationLaw:
        """
        Detect vibration law from significant high and low price levels
        This is the manual method where user provides the key levels
        """
        if high_date is None:
            high_date = datetime.datetime.now()
        if low_date is None:
            low_date = datetime.datetime.now()
            
        price_range = abs(high_price - low_price)
        
        # Use the symbol's configured degree per point
        degrees_per_point = self.config.degree_per_point
        
        # Determine vibration direction
        vibration_type = "HIGH_TO_LOW" if high_date < low_date else "LOW_TO_HIGH"
        
        vibration = VibrationLaw(
            symbol=self.symbol,
            high_price=high_price,
            low_price=low_price,
            high_date=high_date,
            low_date=low_date,
            price_range=price_range,
            degrees_per_point=degrees_per_point,
            vibration_type=vibration_type
        )
        
        print(f"[OK] Detected vibration law for {self.symbol}:")
        print(f"  Range: {low_price} to {high_price} ({price_range:.{self.config.digits}f} points)")
        print(f"  Degrees per point: {degrees_per_point}")
        print(f"  360° price range: {360 / degrees_per_point:.{self.config.digits}f}")
        print(f"  Category: {self.config.gann_category}")
        print(f"  Direction: {vibration_type}")
        
        return vibration
    
    def detect_from_mt5_history(self) -> Optional[VibrationLaw]:
        """
        Automatically detect vibration law by getting historical data from MT5
        Finds significant swing highs and lows from MT5 data
        """
        print(f"\nDetecting vibration law for {self.symbol} from MT5 history...")
        
        # Get historical data from MT5
        df = self.mt5_data.get_historical_data(self.symbol)
        if df is None or len(df) < 100:
            print(f"ERROR: Insufficient historical data for {self.symbol}")
            return None
        
        # Convert DataFrame to the format expected by existing method
        ohlc_data = []
        for _, row in df.iterrows():
            ohlc_data.append({
                'datetime': row['time'],
                'high': row['high'],
                'low': row['low'],
                'open': row['open'],
                'close': row['close']
            })
        
        return self.auto_detect_from_ohlc_data(ohlc_data)
    
    def auto_detect_from_ohlc_data(self, ohlc_data: List[Dict], 
                                   min_range_percent: float = 5.0) -> Optional[VibrationLaw]:
        """
        Automatically detect vibration law from OHLC data
        Finds ABSOLUTE highest high and lowest low (most accurate for Gann)
        """
        if not ohlc_data or len(ohlc_data) < 20:
            print(f"[ERROR] Insufficient data for auto-detection ({len(ohlc_data) if ohlc_data else 0} bars)")
            return None
        
        # Convert to pandas for easier analysis
        df = pd.DataFrame(ohlc_data)
        df['datetime'] = pd.to_datetime(df['datetime'])
        
        # Find ABSOLUTE highest high and lowest low from entire dataset
        absolute_high = df['high'].max()
        absolute_low = df['low'].min()
        
        # Get the dates when these extremes occurred
        high_date = df[df['high'] == absolute_high]['datetime'].iloc[0]
        low_date = df[df['low'] == absolute_low]['datetime'].iloc[0]
        
        # Calculate range significance
        price_range = abs(absolute_high - absolute_low)
        avg_price = (absolute_high + absolute_low) / 2
        range_percent = (price_range / avg_price) * 100
        
        if range_percent < min_range_percent:
            print(f"[WARNING] Range may be small ({range_percent:.1f}%), but using absolute extremes")
        
        print(f"[OK] Found absolute extremes: High {absolute_high:.{self.config.digits}f} -> Low {absolute_low:.{self.config.digits}f}")
        print(f"     Range: {price_range:.{self.config.digits}f} ({range_percent:.1f}% of average)")
        print(f"     High date: {high_date}")
        print(f"     Low date: {low_date}")
        
        return self.detect_from_price_levels(absolute_high, absolute_low, high_date, low_date)
    

class UniversalPriceConverter:
    """Converts prices to degrees for any symbol using its vibration law"""
    
    def __init__(self, vibration_law: VibrationLaw):
        self.vibration = vibration_law
        self.symbol = vibration_law.symbol
        self.zero_degree_price = vibration_law.low_price  # Price that represents 0 degrees
        
    def price_to_degrees(self, price: float) -> float:
        """Convert price to degrees using first-3-digits method with proper scaling"""
        # Convert price to string to handle decimal positioning
        price_str = f"{price:.6f}"
        
        # Find first non-zero digit and extract first 3 significant digits
        price_clean = price_str.replace('.', '').lstrip('0')
        
        if len(price_clean) >= 3:
            first_three = price_clean[:3]
            
            # Always scale to meaningful degree range (10-360)
            # Examples: 
            # 0.99932 -> 999 -> 99.9°
            # 1.14895 -> 114 -> 114.0° (not 1.1°)
            # 77.893 -> 778 -> 77.8°
            # 109.369 -> 109 -> 109.0°
            
            degrees = float(first_three)
            
            # Scale down if too large (keep in 0-360 range)
            while degrees > 360:
                degrees = degrees / 10
                
            # Scale up if too small (ensure meaningful values > 10)
            if degrees < 10 and price >= 1.0:
                degrees = degrees * 10
                
        else:
            # Fallback to original method if price format is unusual
            price_diff = price - self.zero_degree_price
            degrees = price_diff * self.vibration.degrees_per_point
        
        # Normalize to 0-360 range
        degrees = degrees % 360
        return degrees
    
    def degrees_to_price(self, degrees: float) -> float:
        """Convert degrees back to price"""
        # Normalize degrees
        degrees = degrees % 360
        price_diff = degrees / self.vibration.degrees_per_point
        price = self.zero_degree_price + price_diff
        return price
    
    def get_price_at_aspect(self, aspect_degrees: float) -> float:
        """Get the price level where a specific aspect degree occurs"""
        return self.degrees_to_price(aspect_degrees)
    
    def get_aspect_prices(self) -> Dict[str, List[float]]:
        """Get all major aspect price levels within the vibration range"""
        # Calculate dynamic Gann angles from high/low prices
        high_degrees = self.price_to_degrees(self.vibration.high_price)
        low_degrees = self.price_to_degrees(self.vibration.low_price)
        
        aspects = {
            'Conjunction': [0],
            'Semisquare': [45, 315],  # 45° and 315° (360-45)
            'Sextile': [60, 300],     # 60° and 300° (360-60)
            'Square': [90, 270],      # 90° and 270°
            'Trine': [120, 240],      # 120° and 240°
            'GannHigh': [high_degrees],  # Direct angle from high price (no complement)
            'Opposition': [180],       # 180°
            'GannLow': [low_degrees]     # Direct angle from low price (no complement)
        }
        
        aspect_prices = {}
        for aspect_name, degrees_list in aspects.items():
            prices = []
            for degrees in degrees_list:
                price = self.get_price_at_aspect(degrees)
                # Only include prices within reasonable range
                if self.vibration.low_price <= price <= self.vibration.high_price * 2:
                    prices.append(price)
            aspect_prices[aspect_name] = prices
        
        return aspect_prices

class MultiSymbolAspectCalculator:
    """Enhanced aspect calculator for multiple symbols"""
    
    def __init__(self, output_folder: str = "MultiSymbolResults"):
        self.symbol_loader = SymbolConfigLoader()
        self.mt5_data = MT5DataProvider()
        self.detected_vibrations = {}  # Store detected vibration laws for all symbols
        self.output_folder = output_folder
        
        # Create output folder if it doesn't exist
        os.makedirs(self.output_folder, exist_ok=True)
        print(f"[OK] Output folder: {os.path.abspath(self.output_folder)}")
        
        # Planet codes for Swiss Ephemeris
        self.planets = {
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
        
        # Base aspect definitions (Gann angles will be calculated dynamically per symbol)
        self.base_aspects = {
            'Conjunction': {'angle': 0, 'orb': 0.5, 'abbrev': 'Conj'},
            'Semisquare': {'angle': 45, 'orb': 0.5, 'abbrev': 'Semi'},
            'Sextile': {'angle': 60, 'orb': 1.0, 'abbrev': 'Sext'},
            'Square': {'angle': 90, 'orb': 1.0, 'abbrev': 'Sq'},
            'Trine': {'angle': 120, 'orb': 1.0, 'abbrev': 'Trine'},
            'Opposition': {'angle': 180, 'orb': 1.0, 'abbrev': 'Opp'}
        }
    
    def setup_symbol(self, symbol: str, high_price: float, low_price: float,
                     high_date: datetime.datetime = None, 
                     low_date: datetime.datetime = None) -> Tuple[SymbolConfig, VibrationLaw, UniversalPriceConverter]:
        """Setup a symbol for aspect calculations"""
        
        # Get symbol configuration
        config = self.symbol_loader.get_symbol_config(symbol)
        if not config:
            raise ValueError(f"Symbol {symbol} not found in configuration")
        
        # Detect vibration law
        detector = VibrationLawDetector(config)
        vibration = detector.detect_from_price_levels(high_price, low_price, high_date, low_date)
        
        # Create price converter
        converter = UniversalPriceConverter(vibration)
        
        return config, vibration, converter
    
    def get_symbol_aspects(self, converter: UniversalPriceConverter) -> Dict[str, Dict]:
        """Generate dynamic aspects for a specific symbol based on its vibration law"""
        # Start with base aspects
        aspects = self.base_aspects.copy()
        
        # Calculate dynamic Gann angles from high/low prices  
        high_degrees = converter.price_to_degrees(converter.vibration.high_price)
        low_degrees = converter.price_to_degrees(converter.vibration.low_price)
        
        # Add symbol-specific Gann angles
        aspects['GannHigh'] = {
            'angle': high_degrees, 
            'orb': 0.5, 
            'abbrev': f'GH{high_degrees:.0f}'
        }
        aspects['GannLow'] = {
            'angle': low_degrees, 
            'orb': 0.5, 
            'abbrev': f'GL{low_degrees:.0f}'
        }
        
        # No complement calculations - use direct price degrees only
        
        return aspects
    
    def calculate_position(self, planet_code: int, jd: float) -> Optional[float]:
        """Calculate planetary position using Swiss Ephemeris"""
        try:
            flags = swe.FLG_SWIEPH | swe.FLG_SPEED | swe.FLG_TRUEPOS
            result, ret = swe.calc_ut(jd, planet_code, flags)
            return result[0] if result else None
        except Exception as e:
            print(f"Error calculating position for planet {planet_code}: {e}")
            return None
    
    def find_planetary_price_aspects(self, symbol: str, high_price: float, low_price: float,
                                   start_date: datetime.datetime, end_date: datetime.datetime,
                                   target_price: float = None) -> List[Dict]:
        """
        Find when planetary aspects align with specific price levels
        """
        config, vibration, converter = self.setup_symbol(symbol, high_price, low_price)
        
        # Get symbol-specific aspects (including dynamic Gann angles)
        symbol_aspects = self.get_symbol_aspects(converter)
        
        if target_price is None:
            target_price = (high_price + low_price) / 2  # Use midpoint as default
        
        # Convert target price to degrees
        target_degrees = converter.price_to_degrees(target_price)
        
        print(f"Finding aspects for {symbol} at price {target_price:.{config.digits}f} ({target_degrees:.2f}°)")
        print(f"Dynamic Gann angles: High={converter.price_to_degrees(high_price):.1f}°, Low={converter.price_to_degrees(low_price):.1f}°")
        
        # Calculate Julian days for date range
        start_jd = swe.julday(start_date.year, start_date.month, start_date.day, 
                             start_date.hour + start_date.minute/60.0)
        end_jd = swe.julday(end_date.year, end_date.month, end_date.day, 
                           end_date.hour + end_date.minute/60.0)
        
        found_aspects = []
        current_jd = start_jd
        step_jd = 0.25  # 6-hour steps for precision
        
        # Generate planet pairs for comprehensive analysis
        planet_names = list(self.planets.keys())
        
        while current_jd <= end_jd:
            current_date_components = swe.jdut1_to_utc(current_jd, 1)[0:6]
            # Convert float components to integers for datetime
            date_ints = [int(x) for x in current_date_components[:6]]
            current_dt = datetime.datetime(*date_ints)
            
            # Calculate all planetary positions
            positions = {}
            for planet_name, planet_code in self.planets.items():
                pos = self.calculate_position(planet_code, current_jd)
                if pos is not None:
                    positions[planet_name] = pos
            
            # Check for planetary aspects that align with our target price degree
            for planet_name, planet_degrees in positions.items():
                # Check if planet is at aspect to our target price degree
                for aspect_name, aspect_info in symbol_aspects.items():
                    aspect_angle = aspect_info['angle']
                    orb = aspect_info['orb']
                    
                    # Calculate angular distance
                    diff = abs(planet_degrees - target_degrees)
                    if diff > 180:
                        diff = 360 - diff
                    
                    # Check for exact aspect
                    if abs(diff - aspect_angle) <= orb:
                        # Calculate the exact price where this aspect occurs
                        aspect_price = converter.degrees_to_price(planet_degrees)
                        
                        # Convert UTC to Greek time for consistency
                        utc_dt = datetime.datetime(*date_ints)
                        utc_dt = utc_dt.replace(tzinfo=pytz.UTC)
                        greek_tz = pytz.timezone('Europe/Athens')
                        greek_dt = utc_dt.astimezone(greek_tz)
                        
                        aspect_data = {
                            'symbol': symbol,
                            'date': greek_dt.strftime('%Y.%m.%d'),
                            'time': greek_dt.strftime('%H:%M'),
                            'planet': planet_name,
                            'aspect': aspect_name,
                            'aspect_abbrev': aspect_info['abbrev'],
                            'planet_degrees': round(planet_degrees, 4),
                            'price_degrees': round(target_degrees, 4),
                            'aspect_price': round(aspect_price, config.digits),
                            'target_price': round(target_price, config.digits),
                            'angle_diff': round(diff, 4),
                            'exact_jd': current_jd,
                            'description': f"{symbol} {planet_name} {aspect_info['abbrev']} @{aspect_price:.{config.digits}f}"
                        }
                        
                        found_aspects.append(aspect_data)
                        print(f"  Found: {greek_dt.strftime('%Y-%m-%d %H:%M')} {planet_name} {aspect_name} @{aspect_price:.{config.digits}f}")
            
            current_jd += step_jd
            
            # Progress indicator
            if int((current_jd - start_jd) / (end_jd - start_jd) * 100) % 10 == 0:
                progress = (current_jd - start_jd) / (end_jd - start_jd) * 100
                if progress > 0:
                    print(f"Progress: {progress:.1f}%")
        
        return found_aspects
    
    def generate_price_level_aspects(self, symbol: str, high_price: float, low_price: float,
                                   start_date: datetime.datetime, end_date: datetime.datetime) -> List[Dict]:
        """Generate aspects for all major price levels of a symbol"""
        config, vibration, converter = self.setup_symbol(symbol, high_price, low_price)
        
        # Get all aspect price levels
        aspect_prices = converter.get_aspect_prices()
        
        all_aspects = []
        
        print(f"\n=== GENERATING ASPECTS FOR {symbol} ===")
        print(f"Price range: {low_price:.{config.digits}f} - {high_price:.{config.digits}f}")
        print(f"Degree conversion: {vibration.degrees_per_point} degrees per point")
        
        # Calculate aspects for each price level
        for aspect_name, prices in aspect_prices.items():
            for price in prices:
                print(f"\nCalculating {aspect_name} aspects at {price:.{config.digits}f}...")
                aspects = self.find_planetary_price_aspects(
                    symbol, high_price, low_price, start_date, end_date, price
                )
                all_aspects.extend(aspects)
        
        # Sort by date/time
        all_aspects.sort(key=lambda x: datetime.datetime.strptime(f"{x['date']} {x['time']}", '%Y.%m.%d %H:%M'))
        
        return all_aspects
    
    def detect_all_symbol_vibrations(self, max_symbols: int = None) -> Dict[str, VibrationLaw]:
        """
        Automatically detect vibration laws for all symbols from symbol_discovery.csv
        Gets historical data from MT5 and finds significant high/low for each symbol
        """
        
        print("=" * 80)
        print("DETECTING VIBRATION LAWS FOR ALL SYMBOLS")
        print("=" * 80)
        print(f"Processing symbols from symbol_discovery.csv...")
        
        all_symbols = list(self.symbol_loader.symbols.keys())
        if max_symbols:
            all_symbols = all_symbols[:max_symbols]
            print(f"Limited to first {max_symbols} symbols for testing")
        
        print(f"Total symbols to process: {len(all_symbols)}")
        
        successful_detections = 0
        failed_detections = 0
        
        for i, symbol in enumerate(all_symbols, 1):
            print(f"\n[{i}/{len(all_symbols)}] Processing {symbol}...")
            
            try:
                # Get symbol configuration
                config = self.symbol_loader.get_symbol_config(symbol)
                if not config:
                    print(f"ERROR: No configuration found for {symbol}")
                    failed_detections += 1
                    continue
                
                # Create detector and get vibration law from MT5 history
                detector = VibrationLawDetector(config)
                vibration_law = detector.detect_from_mt5_history()
                
                if vibration_law:
                    self.detected_vibrations[symbol] = vibration_law
                    successful_detections += 1
                    
                    print(f"[OK] {symbol}: High {vibration_law.high_price:.{config.digits}f} -> "
                          f"Low {vibration_law.low_price:.{config.digits}f} "
                          f"({vibration_law.price_range:.{config.digits}f} range)")
                else:
                    print(f"[FAILED] {symbol}: Could not detect vibration law")
                    failed_detections += 1
                    
                # Clean up MT5 connection for this symbol
                detector.mt5_data.disconnect()
                    
            except Exception as e:
                print(f"[ERROR] {symbol}: {e}")
                failed_detections += 1
        
        # Cleanup main MT5 connection
        self.mt5_data.disconnect()
        
        print(f"\n" + "=" * 80)
        print(f"VIBRATION LAW DETECTION COMPLETE")
        print(f"=" * 80)
        print(f"Successful: {successful_detections}/{len(all_symbols)}")
        print(f"Failed: {failed_detections}/{len(all_symbols)}")
        print(f"Success rate: {(successful_detections/len(all_symbols)*100):.1f}%")
        
        return self.detected_vibrations
    
    def save_detected_vibrations(self, filename: str = "detected_vibrations.csv"):
        """Save all detected vibration laws with dynamic Gann angles to CSV file"""
        if not self.detected_vibrations:
            print("No vibration laws detected yet")
            return
        
        filepath = os.path.join(self.output_folder, filename)
        with open(filepath, 'w', newline='', encoding='utf-8') as csvfile:
            fieldnames = [
                'symbol', 'high_price', 'low_price', 'high_date', 'low_date', 
                'price_range', 'degrees_per_point', 'vibration_type', 'gann_category',
                'gann_high_degrees', 'gann_low_degrees'
            ]
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            
            for symbol, vibration in self.detected_vibrations.items():
                config = self.symbol_loader.get_symbol_config(symbol)
                
                # Calculate dynamic Gann angles using first-3-digits method
                converter = UniversalPriceConverter(vibration)
                gann_high_degrees = converter.price_to_degrees(vibration.high_price)
                gann_low_degrees = converter.price_to_degrees(vibration.low_price)
                # Direct degrees only - no complement calculations
                
                writer.writerow({
                    'symbol': symbol,
                    'high_price': vibration.high_price,
                    'low_price': vibration.low_price,
                    'high_date': vibration.high_date.isoformat() if vibration.high_date else '',
                    'low_date': vibration.low_date.isoformat() if vibration.low_date else '',
                    'price_range': vibration.price_range,
                    'degrees_per_point': vibration.degrees_per_point,
                    'vibration_type': vibration.vibration_type,
                    'gann_category': config.gann_category if config else '',
                    'gann_high_degrees': round(gann_high_degrees, 2),
                    'gann_low_degrees': round(gann_low_degrees, 2)
                })
        
        print(f"[OK] Saved {len(self.detected_vibrations)} vibration laws with dynamic Gann angles to {filepath}")
    
    def load_vibration_laws_from_csv(self, csv_path: str = None) -> Dict[str, VibrationLaw]:
        """Load detected vibration laws from CSV file"""
        if csv_path is None:
            csv_path = os.path.join(self.output_folder, "all_symbols_gann_angles.csv")
        
        if not os.path.exists(csv_path):
            print(f"ERROR: Vibration CSV file not found: {csv_path}")
            return {}
        
        vibrations = {}
        try:
            with open(csv_path, 'r', encoding='utf-8') as csvfile:
                reader = csv.DictReader(csvfile)
                for row in reader:
                    symbol = row['symbol']
                    
                    # Parse dates
                    high_date = datetime.datetime.fromisoformat(row['high_date']) if row['high_date'] else None
                    low_date = datetime.datetime.fromisoformat(row['low_date']) if row['low_date'] else None
                    
                    vibration = VibrationLaw(
                        symbol=symbol,
                        high_price=float(row['high_price']),
                        low_price=float(row['low_price']),
                        high_date=high_date,
                        low_date=low_date,
                        price_range=float(row['price_range']),
                        degrees_per_point=float(row['degrees_per_point']),
                        vibration_type=row['vibration_type']
                    )
                    
                    vibrations[symbol] = vibration
                    
            print(f"[OK] Loaded {len(vibrations)} vibration laws from {csv_path}")
            return vibrations
            
        except Exception as e:
            print(f"ERROR: Failed to load vibration laws: {e}")
            return {}
    
    def calculate_timing_for_all_symbols(self, start_date: datetime.datetime, end_date: datetime.datetime,
                                       step_hours: float = 6.0, vibration_csv: str = None) -> Dict[str, List[Dict]]:
        """
        Calculate timing for all symbols using their detected vibration laws
        This is the equivalent of calculate_aspects.py but for multiple symbols
        """
        # Load vibration laws
        vibrations = self.load_vibration_laws_from_csv(vibration_csv)
        if not vibrations:
            print("ERROR: No vibration laws loaded")
            return {}
        
        print(f"\n=== CALCULATING TIMING FOR {len(vibrations)} SYMBOLS ===")
        print(f"Date range: {start_date} to {end_date}")
        print(f"Step: {step_hours} hours")
        
        all_symbol_aspects = {}
        
        for i, (symbol, vibration) in enumerate(vibrations.items(), 1):
            print(f"\n[{i}/{len(vibrations)}] Processing {symbol}...")
            
            try:
                # Create price converter for this symbol
                converter = UniversalPriceConverter(vibration)
                
                # Get symbol-specific aspects (including dynamic Gann angles)
                symbol_aspects = self.get_symbol_aspects(converter)
                
                # Calculate timing aspects for this symbol
                symbol_timing = self.scan_planetary_aspects_for_symbol(
                    symbol, vibration, converter, symbol_aspects, 
                    start_date, end_date, step_hours
                )
                
                all_symbol_aspects[symbol] = symbol_timing
                print(f"[OK] {symbol}: Found {len(symbol_timing)} timing aspects")
                
            except Exception as e:
                print(f"[ERROR] {symbol}: {e}")
                all_symbol_aspects[symbol] = []
        
        return all_symbol_aspects
    
    def scan_planetary_aspects_for_symbol(self, symbol: str, vibration: VibrationLaw, 
                                        converter: UniversalPriceConverter, symbol_aspects: Dict,
                                        start_date: datetime.datetime, end_date: datetime.datetime,
                                        step_hours: float = 6.0) -> List[Dict]:
        """
        Scan for planetary aspects timing - pure timing like calculate_aspects.py
        No price calculations, just when planetary aspects occur
        """
        # Calculate Julian days for scanning
        start_jd = swe.julday(start_date.year, start_date.month, start_date.day,
                             start_date.hour + start_date.minute/60.0)
        end_jd = swe.julday(end_date.year, end_date.month, end_date.day,
                           end_date.hour + end_date.minute/60.0)
        
        found_aspects = []
        last_aspects = {}  # Track last aspect for each planet pair to avoid duplicates
        current_jd = start_jd
        step_jd = step_hours / 24.0  # Convert hours to Julian day fraction
        
        # Generate all possible planet pairs
        planet_names = list(self.planets.keys())
        planet_pairs = []
        for i, planet1 in enumerate(planet_names):
            for j, planet2 in enumerate(planet_names):
                if i < j:  # Avoid duplicates
                    planet_pairs.append((planet1, planet2))
        
        while current_jd <= end_jd:
            # Convert Julian day to datetime
            current_date_components = swe.jdut1_to_utc(current_jd, 1)[0:6]
            date_ints = [int(x) for x in current_date_components[:6]]
            current_dt = datetime.datetime(*date_ints)
            
            # Calculate all planetary positions for this time
            positions = {}
            for planet_name, planet_code in self.planets.items():
                pos = self.calculate_position(planet_code, current_jd)
                if pos is not None:
                    positions[planet_name] = pos
            
            # Check planetary aspects between planets - PURE TIMING ONLY
            for planet1, planet2 in planet_pairs:
                if planet1 not in positions or planet2 not in positions:
                    continue
                
                pos1 = positions[planet1]
                pos2 = positions[planet2]
                
                # Calculate angular distance
                current_angle = abs(pos1 - pos2)
                if current_angle > 180:
                    current_angle = 360 - current_angle
                
                # Check against symbol-specific aspects (but only for timing)
                for aspect_name, aspect_info in symbol_aspects.items():
                    target_angle = aspect_info['angle']
                    orb = aspect_info['orb']
                    
                    # Check if current angle matches target aspect within orb
                    angle_diff = abs(current_angle - target_angle)
                    if angle_diff > 180:
                        angle_diff = 360 - angle_diff
                    
                    if angle_diff <= orb:
                        # Convert UTC to Greek time
                        utc_dt = datetime.datetime(*date_ints).replace(tzinfo=pytz.UTC)
                        greek_tz = pytz.timezone('Europe/Athens')
                        greek_dt = utc_dt.astimezone(greek_tz)
                        
                        # Pure timing data - no price calculations
                        aspect_data = {
                            'symbol': symbol,
                            'date': greek_dt.strftime('%Y.%m.%d'),
                            'time': greek_dt.strftime('%H:%M'),
                            'planet1': planet1,
                            'planet2': planet2,
                            'aspect': aspect_name,
                            'aspect_abbrev': aspect_info['abbrev'],
                            'planet1_degrees': round(pos1, 4),
                            'planet2_degrees': round(pos2, 4),
                            'aspect_angle': round(current_angle, 4),
                            'target_angle': target_angle,
                            'angle_diff': round(angle_diff, 4),
                            'exact_jd': current_jd,
                            'description': f"{symbol} {planet1}-{planet2} {aspect_info['abbrev']}"
                        }
                        
                        # Create unique key for this planet pair + aspect combination
                        aspect_key = f"{planet1}-{planet2}-{aspect_name}"
                        
                        # Check if this is a duplicate of the last aspect for this pair
                        should_add = True
                        if aspect_key in last_aspects:
                            last_time = last_aspects[aspect_key]
                            time_diff_hours = (current_jd - last_time) * 24  # Convert to hours
                            # Only add if it's been more than 24 hours since last aspect of this type
                            if time_diff_hours < 24:
                                should_add = False
                        
                        if should_add:
                            found_aspects.append(aspect_data)
                            last_aspects[aspect_key] = current_jd  # Remember this aspect timing
            
            current_jd += step_jd
            
            # Progress indicator
            if int((current_jd - start_jd) / (end_jd - start_jd) * 100) % 20 == 0:
                progress = (current_jd - start_jd) / (end_jd - start_jd) * 100
                if progress > 0:
                    print(f"  {symbol}: {progress:.0f}%")
        
        return found_aspects
    
    def export_symbol_timing_to_csv(self, symbol_aspects: Dict[str, List[Dict]], 
                                   individual_files: bool = True) -> None:
        """Export timing aspects to CSV files"""
        
        # Export individual symbol files
        if individual_files:
            for symbol, aspects in symbol_aspects.items():
                if aspects:
                    filename = f"{symbol}_timing_aspects.csv"
                    self.export_timing_csv(aspects, filename)
        
        # Export combined file
        all_aspects = []
        for aspects in symbol_aspects.values():
            all_aspects.extend(aspects)
        
        if all_aspects:
            # Sort by date/time
            all_aspects.sort(key=lambda x: datetime.datetime.strptime(f"{x['date']} {x['time']}", '%Y.%m.%d %H:%M'))
            self.export_timing_csv(all_aspects, "all_symbols_timing_aspects.csv")
            print(f"[OK] Combined timing file: {len(all_aspects)} total aspects")
    
    def export_timing_csv(self, aspects: List[Dict], filename: str):
        """Export timing aspects to CSV file - pure timing like calculate_aspects.py"""
        if not aspects:
            print(f"No aspects to export for {filename}")
            return
        
        filepath = os.path.join(self.output_folder, filename)
        with open(filepath, 'w', newline='', encoding='utf-8') as csvfile:
            # Match calculate_aspects.py format exactly - pure timing, no price
            fieldnames = [
                'date', 'time', 'planet1', 'planet2', 'aspect', 'aspect_abbrev',
                'angle', 'planet1_lon', 'planet2_lon', 'description', 'symbol'
            ]
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            
            for aspect in aspects:
                # Pure timing data - exactly like calculate_aspects.py
                writer.writerow({
                    'date': aspect['date'],
                    'time': aspect['time'],
                    'planet1': aspect['planet1'],
                    'planet2': aspect['planet2'],
                    'aspect': aspect['aspect'],
                    'aspect_abbrev': aspect['aspect_abbrev'],
                    'angle': f"{aspect['aspect_angle']:.4f}",
                    'planet1_lon': f"{aspect['planet1_degrees']:.4f}",
                    'planet2_lon': f"{aspect['planet2_degrees']:.4f}",
                    'description': aspect['description'],
                    'symbol': aspect['symbol']  # Only additional field for multi-symbol identification
                })
        
        print(f"[OK] Exported {len(aspects)} timing aspects to {filepath}")
        print(f"[OK] Pure timing format (no prices): date, time, planets, aspect, angles")
    
    def copy_timing_files_to_mt5(self, symbol_aspects: Dict[str, List[Dict]]) -> None:
        """Copy timing CSV files to MT5 Files directory for MQ5 access"""
        mt5_files_path = r"C:\Users\shali\AppData\Roaming\MetaQuotes\Terminal\5D8E9E7539757427599AFFA39CA368B7\MQL5\Files"
        
        try:
            os.makedirs(mt5_files_path, exist_ok=True)
            copied_files = []
            
            # Copy individual symbol timing files
            for symbol in symbol_aspects.keys():
                if symbol_aspects[symbol]:  # Only if has aspects
                    source_file = os.path.join(self.output_folder, f"{symbol}_timing_aspects.csv")
                    if os.path.exists(source_file):
                        dest_file = os.path.join(mt5_files_path, f"{symbol}_timing_aspects.csv")
                        shutil.copy2(source_file, dest_file)
                        copied_files.append(f"{symbol}_timing_aspects.csv")
            
            # Copy combined timing file
            combined_source = os.path.join(self.output_folder, "all_symbols_timing_aspects.csv")
            if os.path.exists(combined_source):
                combined_dest = os.path.join(mt5_files_path, "all_symbols_timing_aspects.csv")
                shutil.copy2(combined_source, combined_dest)
                copied_files.append("all_symbols_timing_aspects.csv")
            
            # Copy gann angles file (required for vibration law setup)
            gann_source = os.path.join(self.output_folder, "all_symbols_gann_angles.csv")
            if os.path.exists(gann_source):
                gann_dest = os.path.join(mt5_files_path, "all_symbols_gann_angles.csv")
                shutil.copy2(gann_source, gann_dest)
                copied_files.append("all_symbols_gann_angles.csv")
            
            if copied_files:
                print(f"[OK] Copied {len(copied_files)} timing files to MT5:")
                for file in copied_files:
                    print(f"  ✓ {file}")
                print(f"[OK] MT5 Path: {mt5_files_path}")
            else:
                print("[WARNING] No timing files to copy to MT5")
                
        except Exception as e:
            print(f"[ERROR] Failed to copy files to MT5: {e}")

    def copy_gann_angles_to_mt5(self) -> None:
        """Copy gann angles CSV file to MT5 Files directory"""
        mt5_files_path = r"C:\Users\shali\AppData\Roaming\MetaQuotes\Terminal\5D8E9E7539757427599AFFA39CA368B7\MQL5\Files"
        
        try:
            os.makedirs(mt5_files_path, exist_ok=True)
            
            # Copy gann angles file
            gann_source = os.path.join(self.output_folder, "all_symbols_gann_angles.csv")
            if os.path.exists(gann_source):
                gann_dest = os.path.join(mt5_files_path, "all_symbols_gann_angles.csv")
                shutil.copy2(gann_source, gann_dest)
                print(f"[OK] Copied gann angles to MT5: all_symbols_gann_angles.csv")
                print(f"[OK] MT5 Path: {mt5_files_path}")
            else:
                print(f"[WARNING] Gann angles file not found: {gann_source}")
                
        except Exception as e:
            print(f"[ERROR] Failed to copy gann angles to MT5: {e}")

    def export_to_csv(self, aspects: List[Dict], filename: str):
        """Export aspects to CSV file"""
        if not aspects:
            print("No aspects to export")
            return
        
        filepath = os.path.join(self.output_folder, filename)
        with open(filepath, 'w', newline='', encoding='utf-8') as csvfile:
            fieldnames = [
                'symbol', 'date', 'time', 'planet', 'aspect', 'aspect_abbrev',
                'planet_degrees', 'price_degrees', 'aspect_price', 'target_price',
                'angle_diff', 'description'
            ]
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            
            for aspect in aspects:
                writer.writerow({
                    'symbol': aspect['symbol'],
                    'date': aspect['date'],
                    'time': aspect['time'],
                    'planet': aspect['planet'],
                    'aspect': aspect['aspect'],
                    'aspect_abbrev': aspect['aspect_abbrev'],
                    'planet_degrees': aspect['planet_degrees'],
                    'price_degrees': aspect['price_degrees'],
                    'aspect_price': aspect['aspect_price'],
                    'target_price': aspect['target_price'],
                    'angle_diff': aspect['angle_diff'],
                    'description': aspect['description']
                })
        
        print(f"[OK] Exported {len(aspects)} aspects to {filepath}")

def example_usage():
    """Example usage for different symbols"""
    calculator = MultiSymbolAspectCalculator()
    
    # Example 1: XAUUSD (Gold)
    print("=== XAUUSD EXAMPLE ===")
    gold_aspects = calculator.find_planetary_price_aspects(
        symbol="XAUUSD",
        high_price=2075.0,    # Example significant high
        low_price=1715.0,     # Example significant low
        start_date=datetime.datetime(2024, 1, 1),
        end_date=datetime.datetime(2024, 12, 31),
        target_price=1900.0   # Price level to analyze
    )
    calculator.export_to_csv(gold_aspects, "xauusd_aspects.csv")
    
    # Example 2: EURUSD
    print("\n=== EURUSD EXAMPLE ===")
    eur_aspects = calculator.find_planetary_price_aspects(
        symbol="EURUSD",
        high_price=1.2350,    # Example significant high
        low_price=1.0350,     # Example significant low
        start_date=datetime.datetime(2024, 1, 1),
        end_date=datetime.datetime(2024, 12, 31),
        target_price=1.1000   # Price level to analyze
    )
    calculator.export_to_csv(eur_aspects, "eurusd_aspects.csv")
    
    # Example 3: S&P 500
    print("\n=== S&P500 EXAMPLE ===")
    sp500_aspects = calculator.find_planetary_price_aspects(
        symbol=".S&P500",
        high_price=4800.0,    # Example significant high
        low_price=3200.0,     # Example significant low
        start_date=datetime.datetime(2024, 1, 1),
        end_date=datetime.datetime(2024, 12, 31),
        target_price=4000.0   # Price level to analyze
    )
    calculator.export_to_csv(sp500_aspects, "sp500_aspects.csv")

def calculate_timing_for_symbols():
    """Calculate timing for all symbols using their detected vibration laws"""
    calculator = MultiSymbolAspectCalculator(output_folder="MultiSymbolResults")
    
    print("=== CALCULATING TIMING FOR ALL SYMBOLS ===")
    
    # Calculate timing aspects for all symbols using their vibration laws
    # This is similar to calculate_aspects.py but for multiple symbols
    symbol_timing = calculator.calculate_timing_for_all_symbols(
        start_date=datetime.datetime(2020, 1, 1),
        end_date=datetime.datetime(2030, 12, 31),
        step_hours=6.0,  # 6-hour precision like calculate_aspects.py
        vibration_csv="MultiSymbolResults/all_symbols_gann_angles.csv"
    )
    
    if symbol_timing:
        # Export timing results to CSV files
        calculator.export_symbol_timing_to_csv(symbol_timing, individual_files=True)
        
        # Copy files to MT5 for MQ5 access
        calculator.copy_timing_files_to_mt5(symbol_timing)
        
        print(f"\n=== TIMING CALCULATION COMPLETE ===")
        total_aspects = sum(len(aspects) for aspects in symbol_timing.values())
        print(f"Generated {total_aspects} timing aspects across {len(symbol_timing)} symbols")
        print(f"Time range: 2020-2030 (10 years)")
        print(f"Local files: MultiSymbolResults/")
        print(f"MT5 files: Available for MQ5 indicators")
        print(f"Combined file: all_symbols_timing_aspects.csv")
        
        return symbol_timing
    else:
        print("ERROR: No timing aspects calculated")
        return None

def main():
    """Main function - Generate dynamic Gann angles for all symbols"""
    calculator = MultiSymbolAspectCalculator(output_folder="MultiSymbolResults")
    
    print("=== GENERATING DYNAMIC GANN ANGLES FOR ALL SYMBOLS ===")
    print(f"[OK] Loaded {len(calculator.symbol_loader.symbols)} symbols")
    
    # Show available symbols by category
    categories = calculator.symbol_loader.list_symbols_by_category()
    for category, symbols in categories.items():
        print(f"[OK] {category}: {len(symbols)} symbols")
    
    # Generate dynamic Gann angles for ALL symbols
    print("\n=== DETECTING VIBRATION LAWS FOR ALL SYMBOLS ===")
    print("This will take time as it processes each symbol's MT5 history...")
    
    vibrations = calculator.detect_all_symbol_vibrations()  # No limit - all symbols
    
    if vibrations:
        # Save complete CSV with dynamic Gann angles
        calculator.save_detected_vibrations("all_symbols_gann_angles.csv")
        
        # Copy gann angles file to MT5 for immediate use
        calculator.copy_gann_angles_to_mt5()
        
        print(f"\n=== COMPLETE ===")
        print(f"Generated dynamic Gann angles for {len(vibrations)} symbols")
        print(f"CSV location: MultiSymbolResults/all_symbols_gann_angles.csv")
        print(f"This CSV contains dynamic Gann angles for MQL5 to read")
        print(f"No more hardcoded G104/G192 - all angles are symbol-specific!")
        
        return vibrations
    else:
        print("ERROR: No vibrations detected")
        return None

if __name__ == "__main__":
    print("=== MULTISYMBOL ASPECTS CALCULATOR ===")
    print("Choose operation:")
    print("1. Generate vibration laws (main)")
    print("2. Calculate timing for all symbols") 
    print("3. Both (recommended)")
    
    choice = input("Enter choice (1-3): ").strip()
    
    if choice == "1":
        main()
    elif choice == "2":
        calculate_timing_for_symbols()
    elif choice == "3":
        print("Running both operations...")
        vibrations = main()
        if vibrations:
            print("\nNow calculating timing...")
            calculate_timing_for_symbols()
    else:
        print("Invalid choice, running main() by default")
        main()