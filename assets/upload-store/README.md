# App Store Assets for ReefBuddy

This folder contains all icons and screenshots needed to publish ReefBuddy to the Apple App Store.

## 📱 App Icon

- **`AppIcon-1024.png`** (1024x1024px)
  - Required for App Store Connect submission
  - Design: Electric Aquamarine (#00FFD1) background with bold white "RB" letters
  - Features hard black shadow and 3pt border following New Brutalist design principles
  - Upload to App Store Connect → App Information → App Icon

## 📸 Screenshots

Screenshots are organized by device size. Each device folder contains 4 different app views:

1. **`*_tank-list.png`** - Main tank management screen
2. **`*_analysis.png`** - AI analysis results view
3. **`*_measurement.png`** - Water parameter entry form
4. **`*_chart.png`** - History and trend charts

### iPhone Screenshots

#### iPhone 6.7" (iPhone 14 Pro Max, 15 Pro Max)
- **Folder:** `iphone_67/`
- **Size:** 1290 x 2796 pixels
- **Files:**
  - `iphone_67_tank-list.png`
  - `iphone_67_analysis.png`
  - `iphone_67_measurement.png`
  - `iphone_67_chart.png`

#### iPhone 6.5" (iPhone 11 Pro Max, XS Max)
- **Folder:** `iphone_65/`
- **Size:** 1242 x 2688 pixels
- **Files:**
  - `iphone_65_tank-list.png`
  - `iphone_65_analysis.png`
  - `iphone_65_measurement.png`
  - `iphone_65_chart.png`

#### iPhone 5.5" (iPhone 8 Plus)
- **Folder:** `iphone_55/`
- **Size:** 1242 x 2208 pixels
- **Files:**
  - `iphone_55_tank-list.png`
  - `iphone_55_analysis.png`
  - `iphone_55_measurement.png`
  - `iphone_55_chart.png`

### iPad Screenshots

#### iPad Pro 12.9" (3rd generation)
- **Folder:** `ipad_129/`
- **Size:** 2048 x 2732 pixels
- **Files:**
  - `ipad_129_tank-list.png`
  - `ipad_129_analysis.png`
  - `ipad_129_measurement.png`
  - `ipad_129_chart.png`

#### iPad Pro 11" (2nd generation)
- **Folder:** `ipad_11/`
- **Size:** 1668 x 2388 pixels
- **Files:**
  - `ipad_11_tank-list.png`
  - `ipad_11_analysis.png`
  - `ipad_11_measurement.png`
  - `ipad_11_chart.png`

## 🎨 Design System

All assets follow the New Brutalist design system:

- **Colors:**
  - Background: Pure White (#FFFFFF)
  - Text/Accents: Pure Black (#000000)
  - Action: Electric Aquamarine (#00FFD1)
  - Warning: Safety Orange (#FF3D00)

- **Visual Style:**
  - Borders: 3pt solid black
  - Corners: 0px radius (sharp corners only)
  - Shadows: Hard offset 5pt x 5pt black (no blur)
  - Typography: Bold, oversized headers, Grotesque sans-serif

## 📤 Upload Instructions

### App Store Connect

1. **App Icon:**
   - Go to App Store Connect → Your App → App Information
   - Upload `AppIcon-1024.png`

2. **Screenshots:**
   - Go to App Store Connect → Your App → App Store → [Version]
   - For each device size, upload the corresponding screenshots:
     - At minimum, upload the `tank-list` screenshot (main feature)
     - Optionally add `analysis`, `measurement`, and `chart` screenshots to showcase more features
   - Screenshots are displayed in order, so choose the most compelling first

### Required Screenshots

Apple requires at least one screenshot per device family:
- **iPhone:** At least one iPhone screenshot (6.7" recommended)
- **iPad:** At least one iPad screenshot if your app supports iPad (12.9" recommended)

### Recommended Screenshot Order

1. **Tank List** - Shows main functionality and app purpose
2. **Analysis** - Highlights AI-powered features
3. **Measurement Entry** - Shows ease of use
4. **Charts** - Demonstrates data visualization

## 🔄 Regenerating Assets

To regenerate all assets with updated designs:

```bash
python3 generate-store-assets.py
```

The script will recreate all icons and screenshots in this folder.

## 📋 Checklist Before Submission

- [ ] App icon (1024x1024) uploaded to App Store Connect
- [ ] At least one iPhone screenshot uploaded
- [ ] At least one iPad screenshot uploaded (if app supports iPad)
- [ ] Screenshots showcase key features
- [ ] All screenshots follow App Store guidelines (no pricing, no device frames)
- [ ] Screenshots are in correct dimensions for each device

## 📚 App Store Guidelines

- Screenshots must be actual app screenshots (not mockups)
- No device frames or bezels
- No pricing information visible
- No "Coming Soon" or "Beta" labels
- Must accurately represent the app's functionality

---

**Generated:** 2026-01-18  
**Total Assets:** 21 files (1 icon + 20 screenshots)
