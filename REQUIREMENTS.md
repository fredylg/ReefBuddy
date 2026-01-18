# ReefBuddy Phase 1 Requirements

**Generated:** 2026-01-15
**Status:** All Decisions Made - Ready for Implementation

---

## 1. Keys & Secrets (Secured)

| Secret | Status | Storage |
|--------|--------|---------|
| `ANTHROPIC_API_KEY` | ✅ Configured | Wrangler secret + `.env` |
| `CF_ACCOUNT_ID` | ✅ `34fe73a21dc07a799a1ded7cc1763895` | `wrangler.toml` |
| `D1_DATABASE_ID` | ✅ `5171dac0-7584-49a2-956b-971f2516e0cd` | `wrangler.toml` |
| `KV_NAMESPACE_ID` | ✅ `b971329ac04e4171a65cfb907da0b08f` | `wrangler.toml` |

---

## 2. Decisions by Agent

### @edge-engineer - Infrastructure

| Item | Decision |
|------|----------|
| Cloudflare Account | ✅ Yes - Account ID: `34fe73a21dc07a799a1ded7cc1763895` |
| Anthropic API Tier | Build (pay-as-you-go) |
| AI Model | **Start with Haiku** (not Sonnet) for cost efficiency |
| Custom Domain | `lievano.org` |
| CORS Policy | Keep `*` (open for all origins) |

### @data-steward - Database

| Item | Decision |
|------|----------|
| Authentication | Password-based (store credentials in `.env`) |
| Ammonia Column | ✅ Yes - add all water parameter elements as columns |
| Data Retention | Free tier only (no premium tier distinction) |
| Livestock Category | ✅ Yes - add category field (SPS/LPS/Soft/Fish/Invert) |
| Delete Strategy | Soft deletes (`deleted_at` column) |
| Measurement Frequency | User-defined - just store the date with each measurement |

### @ui-brutalist - iOS

| Item | Decision |
|------|----------|
| Font | Free Grotesque font if available, otherwise system (San Francisco) |
| Font Loading | System fonts only (no bundled fonts) |
| Dynamic Type | No - fixed sizes |
| App Icon | Blue box with "RB" letters |
| Launch Screen | Basic - match New Brutalist style |
| VoiceOver | No |
| Contrast Issues | Accept aquamarine contrast as-is |
| Reduce Motion | No support needed |
| Minimum iOS | **Latest only (iOS 18.0+)** |

### @tester-agent - Testing

| Item | Decision |
|------|----------|
| UI Test Type | Interaction tests |
| Code Coverage | Functional - ensure features work (no % minimum) |
| Task Completion | Claude (@tester-agent) moves tasks from `[!]` to `[x]` |
| Parameter Ranges | Trust AI - just ensure valid responses |
| D1 Integration Tests | ✅ Yes in Phase 1 |
| AI Gateway Testing | ✅ Yes - use mocks/sandbox |
| iOS Framework | Simplest option (XCTest) |
| Previews as Tests | No - separate tests required |
| Accessibility Testing | No |

---

## 3. Implementation Specifications

### 3.1 AI Configuration
```
Model: claude-3-haiku-20240307 (start with Haiku for cost efficiency)
Gateway: reefbuddy-ai-gateway
Account: 34fe73a21dc07a799a1ded7cc1763895
```

### 3.2 Database Schema Updates Required
- Add `ammonia` column to `measurements` table
- Add `category` column to `livestock` table (enum: SPS, LPS, Soft, Fish, Invertebrate)
- Add `deleted_at` column to all tables for soft deletes
- Add `password_hash` column to `users` table

### 3.3 iOS Target
```
Minimum Deployment: iOS 18.0
Devices: iPhone only (latest)
```

### 3.4 Authentication Flow
```
Method: Password-based
Storage: password_hash in D1 users table
Session: KV-based session tokens
Credentials: .env file for local dev
```

---

## 4. Remaining Setup Tasks

| Task | Owner | Status |
|------|-------|--------|
| Create D1 database | @edge-engineer | ✅ Done (`5171dac0-7584-49a2-956b-971f2516e0cd`) |
| Create KV namespace | @edge-engineer | ✅ Done (`b971329ac04e4171a65cfb907da0b08f`) |
| Update wrangler.toml | @edge-engineer | ✅ Done |
| Add zod dependency | @edge-engineer | ✅ Done |
| Update src/index.ts for Haiku | @edge-engineer | ✅ Done |
| Create AI Gateway | @edge-engineer | ⬜ Pending (Cloudflare Dashboard) |
| Apply DB migrations | @data-steward | ⬜ Pending |
| Create Xcode project | @ui-brutalist | ⬜ Pending |
| Update DB schema | @data-steward | ⬜ Pending (`0002_schema_updates.sql`) |

---

## 5. New Questions (Arising from Decisions)

| # | Question | For | Context |
|---|----------|-----|---------|
| N1 | What password hashing algorithm? | @data-steward | bcrypt, argon2, or scrypt? |
| N2 | Session token expiry time? | @edge-engineer | How long should sessions last? |
| N3 | Free Grotesque font selection? | @ui-brutalist | Space Grotesk, Inter, or Work Sans? |

---

## 6. Cross-Agent Action Items

### For @edge-engineer
1. Update `wrangler.toml` with Account ID: `34fe73a21dc07a799a1ded7cc1763895`
2. Change AI model from Sonnet to Haiku in `src/index.ts`
3. Create D1 and KV resources
4. Set up AI Gateway in Cloudflare Dashboard
5. Add `zod` to package.json
6. Implement password-based auth endpoints

### For @data-steward
1. Create `0002_schema_updates.sql` migration:
   - Add `ammonia REAL` to measurements
   - Add `category TEXT` to livestock
   - Add `deleted_at TEXT` to all tables
   - Add `password_hash TEXT` to users
2. Update seed data fixtures

### For @ui-brutalist
1. Create Xcode project targeting iOS 18.0+
2. Find free Grotesque font (Space Grotesk recommended)
3. Design app icon: blue box with "RB"
4. Create basic New Brutalist launch screen

### For @tester-agent
1. Set up XCTest for iOS
2. Create interaction tests for UI components
3. Create D1 integration tests
4. Set up AI Gateway mocks
5. Verify features work (functional testing)

---

## Decision Log

| Date | Decision | Details |
|------|----------|---------|
| 2026-01-15 | All Phase 1 decisions | See sections 2.1-2.4 above |

---

*All questions resolved. Agents may proceed with Phase 1 implementation.*
