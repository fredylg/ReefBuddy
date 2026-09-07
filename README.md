# ReefBuddy

A high-contrast, New Brutalist iOS app for saltwater aquarium hobbyists, backed by a Cloudflare
Worker and Claude.

## Features

- **AI water chemistry analysis** with dosing recommendations (`POST /analyze`, structured output)
- **Credits**: 3 free analyses per device (DeviceCheck-enforced), then paid credit packs via StoreKit 2
- **Tanks, measurements, history**: charts (Swift Charts), trends, averages, CSV export
- **Livestock** with photos and health logs
- **Maintenance reminders** (local notifications) and water-change logging linked to analyses
- **Saved analyses** kept on device

## Architecture

| Layer | Technology |
|-------|------------|
| iOS | Swift 6, SwiftUI, `@Observable`, Swift Charts, StoreKit 2 — iOS 18.0+ |
| API | Cloudflare Workers (TypeScript), table-driven router in `src/index.ts` |
| Data | Cloudflare D1 (SQLite, 15 migrations), KV for rate limits and sessions |
| AI | Claude Haiku 4.5 via Cloudflare AI Gateway (authenticated, logged) |
| Web | Static site in `web/` on Cloudflare Pages (`reefbuddy-web`, https://reefbuddy.aethers.com.au) |

Production API: `https://api.reefbuddy.aethers.com.au` (Worker `reefbuddy`). Bundle id
`au.com.aethers.reefbuddy`, current version 1.0.8.

## Quick start

```bash
npm install
npm run dev               # local Worker on http://localhost:8787 (uses reefbuddy-dev + .dev.vars)
npm run db:migrate        # local D1
npm test                  # 243 Vitest tests in the Workers runtime
npm run typecheck

./verify-xcode-project.sh # then open iOS/ReefBuddy.xcodeproj (Xcode 26)
./scripts/setup-hooks.sh  # once per clone: pre-commit validation of the Xcode project
```

DEBUG builds of the app target `http://localhost:8787`; set `API_BASE_URL` in the scheme's
environment to point a debug build at production.

## Deployment

```bash
npm run deploy            # typecheck → migration lint → tests → wrangler deploy (production)
npm run db:migrate:remote # production migrations
npm run deploy:web        # website
```

## Pricing

- **Free:** 3 analyses per device
- **5 credits:** `com.reefbuddy.credits5`
- **50 credits:** `com.reefbuddy.credits50`

## Documentation

- [`CLAUDE.md`](CLAUDE.md) — development guide, API endpoint table, **Xcode project rules**
- [`migrations/README.md`](migrations/README.md) — schema history and migration rules
- [`tests/README.md`](tests/README.md) — test suite layout
- [`AI_GATEWAY_AUTH_SETUP.md`](AI_GATEWAY_AUTH_SETUP.md) — AI Gateway configuration
- [`MAINTENANCE_REVIEW_2026-09.md`](MAINTENANCE_REVIEW_2026-09.md) / [`IMPLEMENTATION_PLAN_2026-09.md`](IMPLEMENTATION_PLAN_2026-09.md) — September 2026 maintenance pass
- [`iap-configuration/`](iap-configuration/) — App Store Connect IAP notes
- [`docs/archive/`](docs/archive/) — superseded plans and audits

## Xcode project

`iOS/ReefBuddy.xcodeproj/project.pbxproj` is edited by hand and must never be regenerated. The rules
live in [`CLAUDE.md`](CLAUDE.md#ios-development-rules); `./verify-xcode-project.sh` checks the file
before and after any iOS change.
