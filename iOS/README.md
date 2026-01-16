# ReefBuddy iOS App

## 🚨 CRITICAL WARNING FOR ALL AGENTS 🚨

### NEVER DELETE OR RECREATE project.pbxproj

The file `ReefBuddy.xcodeproj/project.pbxproj` is **SACRED** and must **NEVER** be:
- Deleted
- Moved
- Recreated
- Modified with `rm` or `mv` commands

**If you think you need to recreate it, YOU ARE WRONG.**

## Before Working on iOS Code

Run this verification script from the project root:
```bash
./verify-xcode-project.sh
```

This will check:
- ✅ project.pbxproj exists
- ✅ File is valid format
- ✅ File has correct line count (~477+ lines)
- ✅ All Swift files are referenced

## After Working on iOS Code

Run the verification script again:
```bash
./verify-xcode-project.sh
```

If the script fails:
```bash
# Restore from git immediately
git checkout HEAD -- iOS/ReefBuddy.xcodeproj/project.pbxproj
```

## Adding New Swift Files

When adding new Swift files, you must EDIT (not recreate) the `project.pbxproj` file to add:

1. **PBXBuildFile entry** - for compiling
2. **PBXFileReference entry** - for referencing
3. **PBXGroup entry** - for organizing
4. **PBXSourcesBuildPhase entry** - for building

See CLAUDE.md Section 8 for detailed instructions.

## Current Swift Files (28 total)

```
Sources/
├── App/
│   ├── ReefBuddyApp.swift
│   ├── ContentView.swift
│   └── AppIconGenerator.swift
├── Theme/
│   └── BrutalistTheme.swift
├── Components/
│   ├── BrutalistButton.swift
│   ├── BrutalistTextField.swift
│   ├── BrutalistLoadingView.swift     # AI analysis loading indicator
│   └── ShareSheet.swift
├── Models/
│   ├── Tank.swift
│   ├── Measurement.swift
│   ├── User.swift
│   ├── Livestock.swift
│   └── SavedAnalysis.swift            # Saved AI analyses model
├── Views/
│   ├── TankListView.swift
│   ├── MeasurementEntryView.swift
│   ├── AnalysisView.swift
│   ├── HistoryView.swift
│   ├── ChartView.swift
│   ├── PurchaseCreditsView.swift      # IAP Credits purchase UI
│   ├── SavedAnalysesView.swift        # View saved AI analyses
│   ├── ExportView.swift
│   ├── LivestockListView.swift
│   ├── LivestockDetailView.swift
│   ├── AddLivestockView.swift
│   └── NotificationSettingsView.swift
├── Store/
│   ├── StoreManager.swift             # StoreKit 2 integration
│   └── AnalysisStorage.swift          # Local persistence for saved analyses
└── Networking/
    └── APIClient.swift
```

## Key Features

### Saved Analyses
Users can save AI water analyses for later reference:
- **Save**: After running an analysis, tap "Save Analysis" to store it locally
- **View**: Go to Settings → Saved Analyses to browse all saved analyses
- **Filter**: Filter saved analyses by tank
- **Delete**: Swipe or tap to delete individual analyses

Saved analyses are stored in UserDefaults and persist across app restarts.

## Design System

ReefBuddy uses a New Brutalist design:
- **Background:** #FFFFFF (Pure White)
- **Text:** #000000 (Pure Black)
- **Action:** #00FFD1 (Electric Aquamarine)
- **Warning:** #FF3D00 (Safety Orange)
- **Borders:** 3-4pt solid black
- **Corners:** 0px (sharp only)
- **Shadows:** Hard offset 5pt x 5pt, no blur

## Target Configuration

- **Platform:** iOS 18.0+
- **Device:** iPhone only
- **Bundle ID:** com.reefbuddy.app
