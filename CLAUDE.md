# ReefBuddy | Development Guide

## Project Overview

ReefBuddy is a New Brutalist iOS app for saltwater aquarium hobbyists. It provides AI-powered water chemistry analysis and dosing recommendations.

**Tech Stack:**
- **iOS:** Swift/SwiftUI, StoreKit 2 for IAP
- **Backend:** Cloudflare Workers (TypeScript), D1 database, KV storage
- **AI:** Claude 3.5 Sonnet via Cloudflare AI Gateway

---

## Quick Reference

### Commands
```bash
# Backend
npx wrangler dev                              # Local development
npx wrangler deploy                           # Deploy to production
npx wrangler d1 migrations apply reef-db      # Apply migrations

# Testing
npx vitest run                                # Run backend tests

# iOS
./verify-xcode-project.sh                     # Verify Xcode project integrity
open iOS/ReefBuddy.xcodeproj                  # Open in Xcode
```

### Key Files
| Component | Location |
|-----------|----------|
| Backend API | `src/index.ts` |
| iOS App | `iOS/ReefBuddy/Sources/` |
| Xcode Project | `iOS/ReefBuddy.xcodeproj/project.pbxproj` |
| Database Migrations | `migrations/` |
| Tests | `tests/` |

---

## Design System (New Brutalism)

| Element | Value |
|---------|-------|
| Background | `#FFFFFF` (Pure White) |
| Text/Accents | `#000000` (Pure Black) |
| Action | `#00FFD1` (Electric Aquamarine) |
| Warning | `#FF3D00` (Safety Orange) |
| Borders | 3-4pt solid black |
| Corners | 0px (sharp only) |
| Shadows | 5pt offset, no blur |

---

## iOS Development Rules

### CRITICAL: Never delete or recreate `project.pbxproj`

The Xcode project file is manually maintained. If you need to add Swift files:

1. **Before work:** `./verify-xcode-project.sh`
2. **Edit** the existing `project.pbxproj` (add PBXFileReference, PBXBuildFile, PBXGroup entries)
3. **Verify UUIDs are unique:** `grep "8A1B2C3D000000" iOS/ReefBuddy.xcodeproj/project.pbxproj | sort | uniq -d`
4. **After work:** `./verify-xcode-project.sh`

**If project.pbxproj is missing:** `git checkout HEAD -- iOS/ReefBuddy.xcodeproj/project.pbxproj`

---

## Architecture

### Credits System (StoreKit 2)
- 3 free analyses per device
- Paid credits via IAP (`com.reefbuddy.credits5`, `com.reefbuddy.credits50`)
- JWS verification on backend (not legacy receipt validation)
- Credits tracked in D1 `device_credits` table

### API Endpoints
| Endpoint | Purpose |
|----------|---------|
| `POST /analyze` | AI water analysis (requires deviceId) |
| `GET /credits/balance` | Get device credit balance |
| `POST /credits/purchase` | Validate StoreKit 2 JWS and add credits |
| `POST /auth/signup` | Create account |
| `POST /auth/login` | Login |
| `GET /tanks` | List tanks |
| `POST /measurements` | Save measurement |

---

## iOS Source Files (28 total)

```
iOS/ReefBuddy/Sources/
├── App/           ReefBuddyApp, ContentView, AppIconGenerator
├── Theme/         BrutalistTheme
├── Components/    BrutalistButton, BrutalistTextField, BrutalistLoadingView, ShareSheet
├── Models/        Tank, Measurement, User, Livestock, SavedAnalysis
├── Views/         TankListView, MeasurementEntryView, AnalysisView, HistoryView,
│                  ChartView, PurchaseCreditsView, SavedAnalysesView, ExportView,
│                  LivestockListView, LivestockDetailView, AddLivestockView,
│                  NotificationSettingsView
├── Store/         StoreManager (StoreKit 2), AnalysisStorage
└── Networking/    APIClient
```
Just in case CLOyYanvmEhgQJm9tIzJElDM6sUmPBP+SfREtwvWAso=
