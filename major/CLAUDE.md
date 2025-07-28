## MultiSymbolAspectsCalculator Design Notes

- The MultiSymbolAspectsCalculator should use a symbol-specific approach for price conversion and Gann angle calculation
- Key design principles:
  1. Use the symbol's detected vibration law to determine price to degrees conversion
  2. Calculate dynamic Gann angles instead of using hardcoded values (104°/192°)
  3. Let vibration law detection drive the conversion method
- Avoid universal hardcoded approaches like "if price >= 10000 then do this"
- Goal: Create a dynamic calculation method where:
  - Each symbol gets its own conversion method
  - Conversion is based on the symbol's specific vibration characteristics
  - Gann angles are calculated from the symbol's unique high/low range
- Implementation should replace static 104°/192° angles with dynamically calculated angles
- Conversion method should be entirely driven by the detected vibration law

## Symbol Discovery Guidelines

- Refer to symbol_discovery.csv for the following:
  - Symbol - Trading symbol name
  - GannCategory - MICRO, SMALL, MEDIUM, LARGE, XLARGE, MASSIVE
  - Price360Range - Price range that equals 360° (e.g., 0.36, 3.6, 36.0, 360.0, 3600.0, 36000.0)
  - DegreePerPoint - How many degrees per price point (e.g., 1000.0, 100.0, 10.0, 1.0, 0.1, 0.01)

## Python scripts guideline

- No UNIcode. it will break the script