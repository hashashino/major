# Trailing Stop Loss Feature - Usage Guide

## Overview
The trailing stop loss feature has been successfully implemented in the AutoBreakevenEA. This advanced feature allows you to capture additional profits when the market moves significantly in your favor, while protecting against reversals.

## How It Works

### 1. Activation Trigger
- The trailing stop activates when the current market price crosses your specified `TrailingTriggerPrice`
- **For SELL positions**: Activates when price drops to or below the trigger price (e.g., 3330)
- **For BUY positions**: Activates when price rises to or above the trigger price

### 2. Position Management
- Once activated, ALL open positions (matching your symbol filter) are automatically managed with trailing stops
- Each position gets its own trailing stop level based on the current market price
- The system continuously monitors and updates stop losses as the market moves in your favor

### 3. Trailing Logic
- **For BUY positions**: Stop loss trails below the current price by `TrailingStopPoints`
- **For SELL positions**: Stop loss trails above the current price by `TrailingStopPoints`
- Stop loss only moves in your favor (never against you)
- Updates only occur when price moves at least `TrailingStepPoints` in your favor

## Input Parameters

### Trailing Stop Settings
```
EnableTrailingStop = false          // Enable/disable trailing stop feature
TrailingTriggerPrice = 3330.0       // Price level to activate trailing (your scenario: 3330 for sells)
TrailingStopPoints = 50             // Distance of trailing stop from current price (in points)
TrailingStepPoints = 10             // Minimum price movement to update stop loss (in points)
```

## Usage Scenarios

### Scenario 1: SELL Position with 3330 Trigger
```
Initial Setup:
- You have SELL positions open
- Set TrailingTriggerPrice = 3330.0
- Set TrailingStopPoints = 50 (stop will be 50 points above current price)
- Set TrailingStepPoints = 10 (updates every 10 points of favorable movement)

Activation:
- When price drops to 3330.0 or below, trailing stop activates
- All SELL positions get stop losses set 50 points above current price

Example with Price at 3320:
- Initial trailing SL: 3320 + 50 points = 3370
- If price drops to 3310: New SL = 3310 + 50 = 3360 (10 points improvement)
- If price drops to 3300: New SL = 3300 + 50 = 3350 (another 10 points improvement)
- If price reverses to 3350: Stop loss is hit, position closed with profit
```

### Scenario 2: BUY Position Protection
```
Setup for BUY positions:
- Set TrailingTriggerPrice = 3400.0 (or your chosen level)
- When price rises to 3400+, trailing stops activate
- Stop losses trail below current price by TrailingStopPoints
```

## Key Features

### 1. Smart Activation
- Trailing only starts after your trigger price is reached
- Prevents premature stop loss tightening
- Allows positions to develop before applying aggressive management

### 2. Efficient Updates
- Only updates when movement exceeds TrailingStepPoints
- Reduces unnecessary trade modifications
- Minimizes broker requotes and slippage

### 3. Integration with Other Features
- Works alongside breakeven functionality
- Respects initial stop loss settings
- Compatible with auto-close features
- Follows symbol filtering (UseOnlyCurrentSymbol)

### 4. Position Lifecycle Management
- Automatically adds new positions when trailing is active
- Removes closed positions from management
- Deactivates trailing when no positions remain

## Log Messages
The EA provides detailed logging:
```
- "Trailing stop activated at price 3329.50 (trigger: 3330.00)"
- "Position #12345 (EURUSD) added to trailing stop management"
- "Trailing stop updated for EURUSD #12345: SL 3370.0 -> 3360.0 (Price: 3310.0, Profit: 85.3 pts)"
- "All trailing managed positions closed. Trailing stop deactivated."
```

## Best Practices

### 1. Trigger Price Selection
- Set trigger price at a significant technical level
- Consider support/resistance levels for your analysis
- Account for typical market volatility

### 2. Trailing Distance (TrailingStopPoints)
- Larger values: More room for market noise, less frequent exits
- Smaller values: Tighter protection, but may exit prematurely
- Consider average spread and volatility of your instrument

### 3. Step Size (TrailingStepPoints)
- Should be larger than typical spread
- Balance between responsiveness and efficiency
- 10-20 points often works well for major pairs

### 4. Combined Strategy
```
Recommended setup for comprehensive protection:
1. Initial SL: 100 points (immediate protection)
2. Breakeven: 200 points (lock in breakeven after good profit)
3. Trailing trigger: 3330 (activate aggressive trailing after significant move)
4. Trailing distance: 50 points (maintain reasonable protection)
```

## Monitoring and Alerts

### Available Notifications
- Activation alerts (when trailing starts)
- Update notifications (via push notifications)
- Detailed logging in Expert Advisor log

### Performance Tracking
- Monitor profit captured vs. maximum favorable excursion
- Track how often trailing stops are hit vs. manual exits
- Adjust parameters based on historical performance

## Troubleshooting

### Common Issues
1. **Trailing not activating**: Check if current price has crossed trigger level
2. **Stop not updating**: Verify TrailingStepPoints is appropriate for market movement
3. **Unexpected behavior**: Ensure UseOnlyCurrentSymbol matches your intended scope

### Verification Steps
1. Check EA log for activation messages
2. Verify input parameters are correctly set
3. Confirm positions exist and meet criteria
4. Monitor price movement relative to trigger level

This implementation provides a robust, professional-grade trailing stop system that can significantly enhance your trading strategy's profit potential while maintaining appropriate risk management.
