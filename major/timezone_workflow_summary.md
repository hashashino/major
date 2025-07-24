# Planetary Aspects Timezone Workflow Summary

## Overview
This document describes the complete timezone handling workflow for displaying planetary aspects from Swiss Ephemeris on MT5 charts.

## Workflow Components

### 1. Swiss Ephemeris
- **Role**: Calculates planetary positions and aspect times
- **Output**: All times are in UTC (as per Swiss Ephemeris documentation)
- **Files**: `semo_18.se1`, `sepl_18.se1`, `swedll32.dll`

### 2. Python Script (`calculate_aspects.py`)
- **Role**: Processes Swiss Ephemeris data and exports to CSV
- **Input**: UTC times from Swiss Ephemeris calculations
- **Processing**: Converts UTC times to EEST (Greek timezone) using pytz
- **Output**: CSV file with aspect times in EEST
- **Key Code**:
  ```python
  import pytz
  UTC = pytz.UTC
  EEST = pytz.timezone('Europe/Athens')  # Handles EET/EEST automatically
  
  # In export_to_csv function:
  dt_utc = UTC.localize(dt)
  dt_eest = dt_utc.astimezone(EEST)
  ```

### 3. MQL5 Indicator (`MajorAspectsCSV.mq5`)
- **Role**: Reads CSV and displays aspect lines on MT5 chart
- **Input**: CSV with EEST times
- **Processing**: 
  - Converts EEST to UTC by subtracting 3 hours (`CSVTimezoneOffset = 3`)
  - Converts UTC back to Greek time for chart display
  - Generates tooltips with UTC, EEST, and SGT times
- **Output**: Aspect lines at correct times on MT5 chart with multi-timezone tooltips

## Configuration Settings

### Python Script
- `UTC = pytz.UTC`
- `EEST = pytz.timezone('Europe/Athens')`
- CSV output is in EEST

### MQL5 Indicator
- `CSVTimezoneOffset = 3` (EEST is UTC+3 during summer, UTC+2 during winter - pytz handles this)
- Chart display uses Greek time (matches broker time)
- Tooltips show UTC, EEST, and SGT

## Timezone Flow
1. **Swiss Ephemeris**: Calculates aspect at 12:00 UTC
2. **Python Script**: Converts to 15:00 EEST (summer) or 14:00 EET (winter)
3. **CSV Output**: Contains "15:00" or "14:00" 
4. **MQL5 Input**: Reads "15:00" or "14:00"
5. **MQL5 Processing**: Subtracts 3 hours → 12:00 UTC
6. **MQL5 Chart Display**: Converts UTC to Greek time → shows line at 15:00 or 14:00 on chart
7. **MQL5 Tooltips**: 
   - UTC: 12:00
   - EEST/EET: 15:00 or 14:00
   - SGT: 20:00

## Benefits
- **Accuracy**: Aspect lines appear at correct local time on MT5 chart
- **Clarity**: Tooltips show times in multiple relevant timezones
- **Automation**: pytz handles EET/EEST transitions automatically
- **Consistency**: All times are correctly synchronized across the workflow

## Files Generated
- `generated_aspects.csv`: Main CSV file with EEST times for MT5
- `clean_future_aspects.csv`: Filtered aspects data
- `complete_major_aspects.csv`: Complete dataset
- `extended_future_aspects.csv`: Extended future projections

## Testing
The workflow has been tested and verified:
1. Python script successfully converts UTC to EEST
2. CSV contains EEST times (verified by sample inspection)
3. MQL5 code configured to handle EEST input with CSVTimezoneOffset=3
4. Tooltips display UTC, EEST, and SGT correctly
