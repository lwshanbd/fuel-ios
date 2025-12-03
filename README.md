# Fuel - Car Fueling Tracker

A native iOS app built with SwiftUI to track your vehicle's fuel consumption, costs, and efficiency.

## Features

### 🚗 Multi-Vehicle Support
- Track multiple vehicles
- Each vehicle has its own dashboard and history
- Easy switching between vehicles

### 📊 Dashboard
- **Total Spent**: All-time fuel expenses
- **Total Miles**: Distance driven since tracking began
- **Total Gallons**: Fuel consumed
- **Average MPG**: Fuel efficiency (excludes partial fill-ups for accuracy)
- **Average $/Mile**: Cost per mile driven
- **Average Fill-up Cost**: Typical fill-up expense
- **Last Fill-up**: Quick view of most recent fueling
- **Trend Charts**: Visual graphs for MPG, cost, and gas prices over time

### 📝 Fueling Records
- **Date & Time**: When you filled up
- **Odometer Reading**: Current miles (previous miles auto-inferred from prior record)
- **Price per Gallon**: Gas price
- **Gallons**: Amount purchased
- **Total Cost**: What you paid
- **Partial Fill-up Toggle**: Mark incomplete fills for accurate MPG
- **Notes**: Optional memo for each fill-up

### 🧮 Smart Auto-Calculation
Enter any 2 of these 3 fields and the third is calculated automatically:
- Price per Gallon
- Gallons
- Total Cost

### 📈 Post Fill-up Summary
After adding a record, see a beautiful summary showing:
- Gas mileage (MPG) for this fill-up
- Cost per mile
- Trip statistics

### 📤 Import/Export
- **Export to CSV**: Share your data or backup
- **Import from CSV**: Migrate from other apps or spreadsheets

## Requirements

- iOS 17.0+
- Xcode 15.0+

## Installation

1. Open `Fuel/Fuel.xcodeproj` in Xcode
2. Select your development team in Signing & Capabilities (optional, for device testing)
3. Build and run on your device or simulator

## CSV Format

### Export/Import Format
```csv
date,currentMiles,pricePerGallon,gallons,totalCost,isPartialFillUp,notes
2024-01-15,12500,3.459,10.5,36.32,false,"First fill-up"
```

Previous miles are automatically inferred from the prior record's odometer reading.

Supported date formats:
- `yyyy-MM-dd` (preferred)
- `MM/dd/yyyy`
- ISO 8601

## License

MIT License - Feel free to use and modify as needed.

