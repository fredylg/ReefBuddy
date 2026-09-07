# Cloudflare Security Backfill Tracker

**Purpose:** Track security checks that were implemented in the iOS app after version 1.0.1 (non-retroactive) and have been backfilled into the Cloudflare Workers backend.

**Reference:** [SECURITY_REMEDIATION_PLAN.md](SECURITY_REMEDIATION_PLAN.md) (Stage 2 backend items)

**App version compatibility:** Verified against iOS 1.0.4 (`MARKETING_VERSION` 1.0.4 in [iOS/ReefBuddy.xcodeproj/project.pbxproj](iOS/ReefBuddy.xcodeproj/project.pbxproj)). No app code changes in this backfill; Cloudflare-only.

---

## Backfill items

| Item | Status | Date | Notes |
|------|--------|------|--------|
| Debug endpoint | Done | 2026-02-05 | `POST /debug/jws-test` returns 404 in production; available in development only |
| Error verbosity (L1) | Done | 2026-02-05 | Removed `debug` from credits purchase 400 responses (product mismatch, bundle ID mismatch) |
| JWS comment | Done | 2026-02-05 | Replaced misleading "TEMPORARY" comment with accurate Sandbox/Xcode vs Production behavior |

---

## Implementation details

- **Debug endpoint** ([src/index.ts](src/index.ts)): When `env.ENVIRONMENT === 'production'`, the `/debug/jws-test` route returns 404 with a generic body. Otherwise `handleJWSTest` is invoked.
- **Error verbosity**: In `handleCreditsPurchase`, the two 400 responses (product ID mismatch, bundle ID mismatch) no longer include a `debug` property. App 1.0.4 uses only `message` and status codes.
- **Comment**: Line ~2834 now states that Sandbox/Xcode transactions skip cryptographic verification by design; Production transactions are always verified via `verifyAppleJWS`.

---

## Verification

- Run `./verify-xcode-project.sh` after any Xcode-related work.
- Run `npx vitest run` for backend tests (credits/purchase, device-check).
- In production, `POST /debug/jws-test` should return 404.
- App 1.0.4 flows (analyze, credits, tanks, measurements) do not depend on `debug` or `/debug/jws-test`.
