# ReefBuddy | Development Guide

## Project Overview

ReefBuddy is a New Brutalist iOS app for saltwater aquarium hobbyists. It provides AI-powered water
chemistry analysis and dosing recommendations, plus local tank, livestock, maintenance and history tracking.

**Tech stack**
- **iOS:** Swift 6 / SwiftUI (`@Observable`, Swift Charts), StoreKit 2 for IAP, iOS 18.0+
- **Backend:** Cloudflare Workers (TypeScript), D1 (SQLite), KV (rate limits, sessions)
- **AI:** Claude Haiku 4.5 (`AI_MODEL` var) through Cloudflare AI Gateway, structured JSON output

---

## Quick Reference

### Commands
```bash
# Backend
npm run dev                # wrangler dev --env dev (local D1/KV, reefbuddy-dev)
npm run typecheck          # tsc --noEmit (0 errors expected)
npm test                   # vitest (Workers runtime via @cloudflare/vitest-plugin)
npm run format             # prettier over src/ and tests/
npm run deploy             # typecheck + lint:migrations + tests + wrangler deploy → PRODUCTION
npm run deploy:dry         # bundle only
npm run db:migrate         # apply migrations to the local dev database
npm run db:migrate:remote  # apply migrations to production (ask first)
npm run deploy:web         # Cloudflare Pages project reefbuddy-web (web/)

# iOS
./verify-xcode-project.sh  # Xcode project integrity (also runs as the pre-commit hook)
open iOS/ReefBuddy.xcodeproj
```

The top-level `wrangler.toml` config **is production** (`reefbuddy`, `api.reefbuddy.aethers.com.au`);
`[env.dev]` is `reefbuddy-dev`. Secrets live in `.dev.vars` locally and `wrangler secret` remotely.
Never print `.dev.vars`.

### Key files
| Component | Location |
|-----------|----------|
| Router + fetch handler | `src/index.ts` (table-driven `ROUTES`) |
| Env / shared types | `src/env.ts`, `src/http.ts`, `src/schemas.ts` |
| Route handlers | `src/routes/*.ts` |
| Auth, DeviceCheck, credits, StoreKit JWS | `src/auth/`, `src/credits/` |
| AI Gateway call + output schema | `src/ai/gateway.ts` |
| History / export / notifications | `src/historical.ts`, `src/export.ts`, `src/notifications.ts` |
| Migrations | `migrations/` (see `migrations/README.md`) |
| Tests | `tests/` (see `tests/README.md`) |
| iOS app | `iOS/ReefBuddy/Sources/` |
| Xcode project | `iOS/ReefBuddy.xcodeproj/project.pbxproj` |
| Helper scripts | `scripts/` |

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

The Xcode project file is maintained by hand. This is the single source of these rules (README and
`iOS/README.md` point here). To add or remove Swift files:

1. **Before work:** `./verify-xcode-project.sh`
2. **Edit** the existing `project.pbxproj`: one `PBXBuildFile`, one `PBXFileReference`, one entry in
   the right `PBXGroup`, one entry in `PBXSourcesBuildPhase`. New ids continue the
   `8A1B2C3D000000xx` sequence (last used: `B1`).
3. **Verify ids are unique:** `grep "8A1B2C3D000000" iOS/ReefBuddy.xcodeproj/project.pbxproj | sort | uniq -d`
4. **After work:** `./verify-xcode-project.sh`, then build:
   `xcodebuild -project iOS/ReefBuddy.xcodeproj -scheme ReefBuddy -destination 'generic/platform=iOS Simulator' build`

**If project.pbxproj is missing:** `git checkout HEAD -- iOS/ReefBuddy.xcodeproj/project.pbxproj`

### Conventions
- Swift 6 language mode: everything the views touch is `@MainActor`; stores are `@Observable`
  final classes injected with `.environment(_:)` and read with `@Environment(Type.self)`.
- Persistence: `JSONFileStore` (Application Support/ReefBuddy/Data), never UserDefaults for data.
- Networking: `APIClient` (actor) with `APIDates` tolerant date decoding; UUIDs are sent lowercase.
- Device identity: `DeviceIdentity.deviceId` (Keychain-backed, sent as `X-Device-ID`).
- Logging: `appLog` (os.Logger) for operational events, `debugLog()` for DEBUG-only noise.
- DEBUG builds call `http://localhost:8787` unless `API_BASE_URL` is set in the scheme environment.

---

## Architecture

### Credits (StoreKit 2)
- 3 free analyses per device, enforced with DeviceCheck two-bit state (bit0 = free tier consumed).
- Paid credits via IAP (`com.reefbuddy.credits5`, `com.reefbuddy.credits50`).
- `POST /credits/purchase` verifies the StoreKit 2 JWS: signature, then the `x5c` chain up to the pinned
  Apple Root CA G3 with the App Store receipt OIDs. Xcode-signed transactions are accepted only outside
  production (`ALLOW_SANDBOX_PURCHASES`).
- Credits and audit rows live in D1 (`device_credits`, `purchase_history`); refunds on failed analyses.

### Auth
Every app route accepts either a Bearer session (accounts, kept for a future login feature) or the
`X-Device-ID` header (`resolveActor`). Notification routes are session-only. Device ids are bounded by
`DEVICE_ID_PATTERN`; request bodies are validated with Zod; paths are lowercased before matching.

### API endpoints (from `ROUTES` in `src/index.ts`)
| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/` | none | route table |
| GET | `/health` | none | health/version |
| POST | `/auth/signup`, `/auth/login` | none (10/min/IP) | accounts |
| POST | `/auth/logout` | none | end session |
| GET, POST | `/api/tanks` | actor | list / create tanks |
| GET, PUT, DELETE | `/api/tanks/:id` | actor | one tank |
| POST | `/api/measurements` | actor | save a measurement |
| POST | `/analyze` | device id in body | AI analysis (credits, 10/min/IP) |
| GET | `/credits/balance?deviceId=` | none (60/min) | credit balance |
| POST | `/credits/purchase` | none (60/min) | StoreKit 2 JWS → credits |
| GET | `/tanks/:id/history`, `/trends`, `/averages` | actor | history data |
| GET | `/tanks/:id/export` | actor | CSV export |
| GET, POST | `/maintenance/schedules` | actor | schedule sync |
| PUT, DELETE | `/maintenance/schedules/:id` | actor | one schedule |
| GET, POST | `/api/tanks/:id/water-changes` | actor | water changes |
| DELETE | `/api/water-changes/:id` | actor | soft-delete a water change |
| GET, POST | `/api/tanks/:id/livestock` | actor | livestock per tank |
| PUT, DELETE | `/api/livestock/:id` | actor | one livestock record |
| GET, POST | `/api/livestock/:id/logs` | actor | health logs |
| POST, DELETE | `/notifications/token` | session | push token (push not shipped, P-02) |
| GET, PUT | `/notifications/settings` | session | alert thresholds |
| GET | `/notifications/history` | session | notification history |
| POST | `/notifications/read` | session | mark read |

"actor" = session or `X-Device-ID`, rate-limited 60/min per device. Every response carries
`X-Request-Id`, HSTS and the security headers from `src/http.ts`; CORS is allow-list only.

---

## iOS Source Files (39)

```
iOS/ReefBuddy/Sources/
├── App/           ReefBuddyApp (AppDelegate, AppState), ContentView
├── Theme/         BrutalistTheme
├── Components/    BrutalistButton, BrutalistTextField, BrutalistLoadingView, ShareSheet
├── Models/        Tank, Measurement, User, Livestock, SavedAnalysis, MaintenanceSchedule
├── Views/         TankListView, MeasurementEntryView, HistoryView, ChartView,
│                  PurchaseCreditsView, SavedAnalysesView, ExportView,
│                  LivestockListView, LivestockDetailView, AddLivestockView,
│                  MaintenanceSchedulesListView, MaintenanceScheduleEditorView,
│                  NotificationSettingsView
├── Store/         StoreManager (StoreKit 2), JSONFileStore, TankStorage, MeasurementStorage,
│                  LivestockStorage, AnalysisStorage, MaintenanceScheduleStore (+WaterChangeStorage),
│                  MaintenanceNotificationService, ImageStorage, DeviceIdentity, KeychainManager
└── Networking/    APIClient, APIDates
```
`tools/AppIconGenerator.swift` regenerates the app icon and is not part of the target.

---

## Working agreements
- One branch per piece of work, one commit per logical change; no push or merge without the owner.
- Ask before deploying, running remote migrations, or changing production data.
- `MAINTENANCE_REVIEW_2026-09.md` and `IMPLEMENTATION_PLAN_2026-09.md` record the September 2026
  maintenance pass; `docs/archive/` holds superseded plans.
