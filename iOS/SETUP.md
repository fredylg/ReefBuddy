# ReefBuddy iOS App Setup

## Project Status: ✅ Ready to Build

The Xcode project has been configured and all source files have been properly added to the build system.

## Project Structure

```
iOS/ReefBuddy/
├── Sources/
│   ├── App/
│   │   ├── ReefBuddyApp.swift         (Main app entry point)
│   │   ├── ContentView.swift          (Root view with tab navigation)
│   │   └── AppIconGenerator.swift     (App icon generation utility)
│   │
│   ├── Theme/
│   │   └── BrutalistTheme.swift       (New Brutalist design system)
│   │
│   ├── Components/
│   │   ├── BrutalistButton.swift      (Custom button components)
│   │   ├── BrutalistTextField.swift   (Custom input components)
│   │   ├── BrutalistLoadingView.swift (AI analysis loading indicator)
│   │   └── ShareSheet.swift           (iOS share sheet wrapper)
│   │
│   ├── Models/
│   │   ├── Tank.swift                 (Tank data model)
│   │   ├── Measurement.swift          (Water parameter measurements)
│   │   ├── Livestock.swift            (Livestock/coral tracking)
│   │   └── User.swift                 (User & authentication)
│   │
│   ├── Views/
│   │   ├── TankListView.swift
│   │   ├── MeasurementEntryView.swift
│   │   ├── AnalysisView.swift
│   │   ├── HistoryView.swift
│   │   ├── ChartView.swift
│   │   ├── SubscriptionView.swift     (Legacy - to be deprecated)
│   │   ├── PurchaseCreditsView.swift  (IAP Credits purchase UI)
│   │   ├── ExportView.swift
│   │   ├── NotificationSettingsView.swift
│   │   ├── LivestockListView.swift
│   │   ├── LivestockDetailView.swift
│   │   └── AddLivestockView.swift
│   │
│   ├── Store/
│   │   └── StoreManager.swift         (StoreKit 2 integration)
│   │
│   └── Networking/
│       └── APIClient.swift            (Cloudflare Workers API client)
│
└── Resources/
    └── Assets.xcassets/               (App icons and images)
```

## Files Added to Project

The following files were missing from the Xcode project and have been added:

### Models (1 file)
- ✅ `Livestock.swift` - Livestock and health tracking models

### Views (4 files)
- ✅ `NotificationSettingsView.swift` - Parameter alert configuration
- ✅ `LivestockListView.swift` - Livestock grid/list display
- ✅ `LivestockDetailView.swift` - Individual livestock details
- ✅ `AddLivestockView.swift` - Add new livestock form

## Build Configuration

- **Platform**: iOS 18.0+
- **Language**: Swift 5.0
- **Architecture**: iPhone only (portrait orientation)
- **Bundle ID**: au.com.aethers.reefbuddy
- **Design System**: New Brutalist (high contrast, sharp edges, bold typography)

## Key Features

1. **Tank Management**: Create and manage multiple aquarium tanks
2. **Water Parameter Tracking**: Log temperature, salinity, pH, alkalinity, calcium, magnesium, nitrate, phosphate, etc.
3. **AI Analysis**: Get intelligent recommendations from Claude 3.5 Sonnet via Cloudflare AI Gateway
4. **Livestock Tracking**: Monitor corals, fish, and invertebrates with health logging
5. **Notifications**: Set parameter thresholds for alerts
6. **Data Export**: Export measurements for analysis
7. **Credits System**: 3 free analyses, then in-app purchase credits (5 for $0.99, 50 for $4.99)

## API Integration

The app is configured to connect to a Cloudflare Workers backend:

- **Default**: `http://localhost:8787` (for local development)
- **Production**: Set via `API_BASE_URL` environment variable

## Design System

The app uses a **New Brutalist** design language:

- Pure white background (#FFFFFF)
- Pure black text (#000000)
- Electric aquamarine for actions (#00FFD1)
- Safety orange for warnings (#FF3D00)
- Sharp corners (no border radius)
- Thick borders (3-4pt)
- Hard offset shadows (no blur)
- Bold, grotesque typography

## Building the Project

### Prerequisites

- macOS 14.0 or later
- Xcode 15.0 or later
- iOS 18.0 SDK

### Steps

1. Open `ReefBuddy.xcodeproj` in Xcode
2. Select a simulator or connected device
3. Press `Cmd + B` to build
4. Press `Cmd + R` to run

### Expected Build Result

The project should compile successfully with no errors. All Swift files are properly referenced in the build phases.

## Next Steps

1. **Backend Setup**: Ensure the Cloudflare Workers backend is running (see main project README)
2. **API Configuration**: Update the API base URL if not using localhost
3. **Testing**: Run the app and verify all features work correctly
4. **Customization**: Modify the brutalist theme colors if desired

## Troubleshooting

### Build Errors

If you encounter build errors:

1. Clean the build folder: `Product > Clean Build Folder` (Cmd + Shift + K)
2. Delete derived data: `~/Library/Developer/Xcode/DerivedData/ReefBuddy-*`
3. Restart Xcode

### Missing Files

All source files are now properly added to the project. If Xcode shows missing file warnings:

1. Check that files exist in the correct directories
2. Verify file references in Project Navigator
3. Re-add files if necessary: Right-click on group > Add Files to "ReefBuddy"

## Development Notes

- All views use SwiftUI (no UIKit view controllers)
- State management via `@EnvironmentObject` with `AppState`
- Async/await for API calls
- Actor-based API client for thread safety
- Sample data available for previews and development

## License

See main project README for license information.
