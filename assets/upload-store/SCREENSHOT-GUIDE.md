# App Store Screenshot Capture Guide

This guide explains how to capture real screenshots from the iOS Simulator for App Store submission.

## 📱 Required Screenshot Sizes

Apple requires screenshots in these exact dimensions:

| Device | Orientation | Size (width × height) |
|--------|-------------|----------------------|
| iPhone 6.7" (14 Pro Max, 15 Pro Max) | Portrait | 1284 × 2778 px |
| iPhone 6.7" (14 Pro Max, 15 Pro Max) | Landscape | 2778 × 1284 px |
| iPhone 6.5" (11 Pro Max, XS Max) | Portrait | 1242 × 2688 px |
| iPhone 6.5" (11 Pro Max, XS Max) | Landscape | 2688 × 1242 px |

**Note:** You only need portrait OR landscape, not both. Portrait is recommended.

## 🎯 Step-by-Step Instructions

### 1. Open the App in iOS Simulator

```bash
# Open Xcode
open iOS/ReefBuddy.xcodeproj

# Or use command line (if Xcode is installed)
xcodebuild -project iOS/ReefBuddy.xcodeproj \
  -scheme ReefBuddy \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro Max' \
  build
```

### 2. Navigate to Each View

Capture screenshots of these key views:
- **Tank List** - Main dashboard showing tanks
- **Analysis** - AI analysis results screen
- **Measurement Entry** - Water parameter input form
- **Charts/History** - Trend visualization

### 3. Take Screenshots

**Method 1: Simulator Menu**
1. In Simulator, go to: **Device → Screenshot → [Device Name]**
2. Screenshot is saved to Desktop

**Method 2: Keyboard Shortcut**
- Press **Cmd + S** in Simulator
- Screenshot is saved to Desktop

**Method 3: Command Line** (if simulator is running)
```bash
xcrun simctl io booted screenshot ~/Desktop/screenshot.png
```

### 4. Resize Screenshots

Use the helper script to resize to exact App Store dimensions:

```bash
# Navigate to the screenshot directory
cd assets/upload-store/real-screenshots

# Resize a screenshot
./resize-screenshots.sh ~/Desktop/screenshot.png
```

Or manually using `sips` (macOS built-in):

```bash
# iPhone 6.7" Portrait
sips -z 2778 1284 ~/Desktop/screenshot.png --out iphone_67_portrait_tank-list.png

# iPhone 6.7" Landscape
sips -z 1284 2778 ~/Desktop/screenshot.png --out iphone_67_landscape_tank-list.png

# iPhone 6.5" Portrait
sips -z 2688 1242 ~/Desktop/screenshot.png --out iphone_65_portrait_tank-list.png

# iPhone 6.5" Landscape
sips -z 1242 2688 ~/Desktop/screenshot.png --out iphone_65_landscape_tank-list.png
```

### 5. Organize Screenshots

Save screenshots with descriptive names:
```
real-screenshots/
├── iphone_67_portrait_tank-list.png
├── iphone_67_portrait_analysis.png
├── iphone_67_portrait_measurement.png
├── iphone_67_portrait_chart.png
└── ...
```

## 🔧 Automated Capture Script

Use the provided script for easier capture:

```bash
./capture-app-screenshots.sh "iPhone 15 Pro Max" "tank-list"
```

The script will:
1. Guide you through taking screenshots
2. Automatically resize to all required dimensions
3. Save to `assets/upload-store/real-screenshots/`

## 📋 Screenshot Checklist

Before submitting to App Store Connect, ensure:

- [ ] At least one iPhone screenshot (portrait or landscape)
- [ ] Screenshots are exact dimensions (no scaling needed)
- [ ] Screenshots show actual app UI (not mockups)
- [ ] No device frames or bezels
- [ ] No pricing information visible
- [ ] Screenshots showcase key features
- [ ] Screenshots are in PNG format
- [ ] File sizes are reasonable (< 10MB each)

## 🎨 Screenshot Best Practices

1. **Show Key Features First**
   - Lead with the tank list (main feature)
   - Follow with analysis results (AI-powered feature)
   - Include measurement entry (ease of use)
   - Add charts (data visualization)

2. **Use Real Data**
   - Fill in realistic tank names and parameters
   - Show actual analysis results
   - Display meaningful chart data

3. **Highlight Value**
   - Show the AI analysis prominently
   - Display clear parameter status indicators
   - Showcase the bold, high-contrast design

4. **Avoid**
   - Placeholder text ("Lorem ipsum")
   - Empty states (unless showing onboarding)
   - Error messages
   - Loading states
   - Test/dummy data that looks fake

## 🚀 Quick Start

1. **Open app in Simulator:**
   ```bash
   open iOS/ReefBuddy.xcodeproj
   # Then press Cmd+R to run
   ```

2. **Take screenshots:**
   - Navigate to each view
   - Press Cmd+S for each screenshot

3. **Process screenshots:**
   ```bash
   cd assets/upload-store/real-screenshots
   ./resize-screenshots.sh ~/Desktop/screenshot.png
   ```

4. **Upload to App Store Connect:**
   - Go to App Store Connect → Your App → App Store
   - Upload screenshots in the correct size slots

## 📱 Simulator Device Recommendations

For best results, use these simulator devices:

- **iPhone 15 Pro Max** (6.7") - Best for 1284×2778 screenshots
- **iPhone 14 Pro Max** (6.7") - Alternative for 1284×2778
- **iPhone 11 Pro Max** (6.5") - For 1242×2688 screenshots

## 🔍 Verifying Screenshot Dimensions

Check screenshot dimensions:

```bash
# Using sips
sips -g pixelWidth -g pixelHeight screenshot.png

# Using file command
file screenshot.png

# Using ImageMagick (if installed)
identify screenshot.png
```

## ❓ Troubleshooting

**Screenshots are wrong size:**
- Use `sips` or ImageMagick to resize
- Ensure you're using the exact dimensions listed above

**Simulator won't start:**
- Check Xcode is installed: `xcode-select -p`
- Reset simulator: `xcrun simctl erase all`

**Can't find screenshots:**
- Check Desktop folder
- Check `~/Library/Developer/Xcode/DerivedData/` for simulator data

---

**Need help?** Run the capture script for interactive guidance:
```bash
./capture-app-screenshots.sh
```
