# MT5 Auto Breakeven Scripts

This collection contains three MQL5 files for automatically moving trades to breakeven in MetaTrader 5.

## Files Included

### 1. AutoBreakeven.mq5 (Script)
A one-time script that checks all open positions and moves them to breakeven if they meet the criteria.

**Features:**
- Runs once when executed
- Processes all open positions
- Configurable breakeven trigger points
- Optional additional points beyond entry price
- Detailed logging and alerts

**Usage:**
1. Drag the script to any chart
2. Configure the input parameters
3. Click OK to execute

### 2. AutoBreakevenEA.mq5 (Expert Advisor)
A continuously running Expert Advisor that monitors positions in real-time and automatically applies breakeven.

**Features:**
- Runs continuously while attached to chart
- Real-time monitoring of positions
- Configurable check intervals
- Prevents duplicate modifications
- Push notification support

**Usage:**
1. Drag the EA to any chart
2. Configure input parameters
3. Enable auto-trading
4. The EA will run continuously

### 3. ManualBreakeven.mq5 (Script)
A manual script for immediate breakeven of selected positions with confirmation dialogs.

**Features:**
- Manual execution with confirmation
- Can process all positions or only profitable ones
- Detailed results display
- Sound notifications
- User-friendly interface

**Usage:**
1. Drag the script to any chart
2. Configure whether to breakeven all positions or only profitable ones
3. Confirm the action when prompted

## Input Parameters

### Common Parameters
- **BreakevenPoints**: Number of points in profit required to trigger breakeven (default: 200)
- **AdditionalPoints**: Extra points beyond entry price for the new stop loss (default: 10)
- **UseOnlyCurrentSymbol**: Apply only to the current chart's symbol (default: true)
- **ShowAlerts**: Display alert messages (default: true/false depending on script)
- **WriteToLog**: Write actions to Expert log (default: true)

### EA-Specific Parameters
- **CheckIntervalMs**: How often to check positions in milliseconds (default: 1000)
- **MinProfitPercent**: Minimum profit percentage to consider (default: 0.1)
- **SendNotifications**: Send push notifications (default: false)

### Manual Script Parameters
- **BreakevenAllPositions**: Breakeven all positions regardless of profit (default: true)
- **MinimumProfitPoints**: Minimum profit required if not breaking all (default: 50)
- **ConfirmBeforeAction**: Show confirmation dialog (default: true)
- **ShowDetailedResults**: Display detailed results (default: true)
- **PlaySoundOnComplete**: Play sound when finished (default: true)

## How It Works

1. **Profit Calculation**: The scripts calculate profit in points by comparing current market price to entry price
2. **Threshold Check**: If profit exceeds the specified breakeven points, the position becomes eligible
3. **Stop Loss Modification**: The stop loss is moved to entry price + additional points
4. **Duplicate Prevention**: The EA tracks processed positions to avoid repeated modifications

## Installation

1. Copy the .mq5 files to your MetaTrader 5 `MQL5\Scripts` or `MQL5\Experts` folder
2. Compile the files in MetaEditor (F7) or they will auto-compile when first used
3. Restart MetaTrader 5 or refresh the Navigator

## Important Notes

- **Auto-trading must be enabled** for the EA and scripts to modify positions
- **Test on demo account first** before using on live trading
- The scripts work with both buy and sell positions
- Point values are automatically calculated for different symbols
- All modifications are logged for review

## Risk Disclaimer

These scripts modify your trading positions automatically. Always:
- Test thoroughly on demo accounts
- Understand the code before use
- Monitor the scripts' behavior
- Use appropriate risk management
- Keep backups of your original Expert Advisors

## Troubleshooting

**Common Issues:**
- Auto-trading disabled: Enable auto-trading in MT5
- Invalid stops error: Check your broker's minimum stop level requirements
- No positions modified: Verify positions meet the profit threshold
- Permission errors: Ensure MT5 has permission to modify trades

**Error Codes:**
The scripts include detailed error reporting. Check the Expert log for specific error descriptions.

## Customization

The scripts are well-commented and can be modified for specific needs:
- Change profit calculation methods
- Add trailing stop functionality
- Include additional filters (time, symbol, etc.)
- Modify notification methods

## Support

For questions or modifications, refer to the MQL5 documentation or community forums.
