# ReefBuddy Implementation Plan — September 2026

Source: `MAINTENANCE_REVIEW_2026-09.md` (your marked decisions as of 2026-09-07 10:56). Every task below cites the review IDs it implements. Items you marked NO or deferred are listed in Phase 9 so nothing is silently dropped.

## How tracking works

- Each task is a checkbox. I change `- [ ]` to `- [x]` the moment the task is done **and verified**, and append a line to the **Progress log** at the bottom with the date, what changed, and the commit hash.
- A task that is started but not finished is marked `- [~]`. A task that is blocked on you is marked `- [!]` with the reason.
- The **Phase status** table is updated at the end of each work session.
- Tasks marked 🧑 need you (Xcode signing, App Store Connect, Cloudflare dashboard, a decision). Tasks marked ⛔ are destructive or outward-facing and I will ask for a go-ahead in chat before running them, even if this plan is approved.
- One git branch per phase (`maint/p1-hotfix`, `maint/p2-toolchain`, …), one commit per task or tightly related task group, commit message prefixed with the task ID. I do not push or merge without you saying so.

## Phase status

| Phase | Scope | Tasks | Done | Status |
|---|---|---|---|---|
| 0 | Prep and safety net | 6 | 6 | **done** 2026-09-07 |
| 1 | Stop the bleeding (backend hotfix + deploy) | 16 | 16 | **done** 2026-09-07 |
| 2 | Toolchain and hermetic tests | 12 | 12 | **done** 2026-09-07 |
| 3 | Backend correctness and hardening | 30 | 30 | **done** 2026-09-07 (live version 572828b5) |
| 4 | iOS sync fixes and 1.0.7 release | 28 | 27 | code complete; **P4-28 (archive/TestFlight) is yours** |
| 5 | Backend structure | 4 | 4 | done (branch `maint/p5-structure`, live `e667dee4`) |
| 6 | iOS modernisation | 8 | 7 | code complete (branch `maint/p6-ios`); **P6-08 TestFlight 1.0.8 is yours** |
| 7 | Database, docs, hygiene, Cloudflare cleanup | 16 | 12 | branch `maint/p7-hygiene`; **P7-12/P7-13 need your go-ahead, P7-05 mailboxes and P7-14 WAF rule are yours** |
| 8 | Final verification and handover | 5 | 3 | gates green; **P8-03 needs the deploy go-ahead** |
| 9 | Deferred / declined (no work) | — | — | — |

## Standing rules for every task

1. Before touching Swift files: `./verify-xcode-project.sh`. After: same. `project.pbxproj` is edited by hand only, never regenerated (CLAUDE.md rule).
2. Backend gate before each commit: `npx tsc --noEmit && npx vitest run` (both green from Phase 2 onward; in Phase 1 only vitest is required to be green, tsc must not get worse).
3. Any production data change: D1 export first (P0-02), then the statement is shown to you in chat, then run.
4. Deploy only with the production command established in P1-11, then `curl /health` and confirm `environment: production` and the new version string.
5. iOS builds are verified with `xcodebuild -scheme ReefBuddy -destination 'platform=iOS Simulator,name=iPhone 16' build` plus a simulator run of the affected screens. Archive and TestFlight upload are yours (🧑).

---

## Phase 0 — Prep and safety net

Goal: nothing in later phases can lose data or surprise production.

- [x] **P0-01** Create branch `maint/p1-hotfix` from `main`; record baseline: `npx vitest run` result, `npx tsc --noEmit` error count (46), `npm audit` count (13). Save to `docs/maintenance/baseline-2026-09.txt`.
- [x] **P0-02** (CF-08) Export production D1: `npx wrangler d1 export reef-db --remote --output backups/reef-db-2026-09-07.sql`. Add `backups/` to `.gitignore`. Confirm the file has the 13 tables.
- [x] **P0-03** (CF-02) 🧑 Owner device confirmed 2026-09-07: `8B629A9B-9907-4D5B-80F9-DC18E3FF3587` is excluded from the cleanup; the other 9 devices are cleaned in P1-15. Candidates holding sandbox credits today (the first is the most active and the likely owner device):

  | device_id | paid | analyses | last update | purchase rows |
  |---|---|---|---|---|
  | 8B629A9B-9907-4D5B-80F9-DC18E3FF3587 | 11 | 62 | 2026-06-17 | 5 |
  | E4547DFA-BFAD-49C1-9761-A9062F2A9BD2 | 50 | 10 | 2026-05-06 | 0 |
  | 7C4F4E03-9C76-4DB8-8B88-C336A45E5055 | 52 | 0 | 2026-01-22 | 0 |
  | 17D4E936-EF8C-49D9-93E3-FB71DD661D2B | 49 | 9 | 2026-01-22 | 1 |
  | C3D939EA-C1CD-426E-879A-5C214983F24B | 50 | 0 | 2026-01-20 | 1 |
  | DB869A0A-8974-4A8B-815D-1E61E72AC3CF | 1 | 7 | 2026-01-19 | 0 |
  | test-device-ios | 25 | 0 | 2026-01-17 | 0 |
  | 6CD701D5-6E9A-4783-A147-1CEE755AA431 | 50 | 5 | 2026-01-17 | 0 |
  | 10E067C0-0E04-4247-8665-0BD232D2D28F | 5 | 0 | 2026-01-17 | 0 |
  | test-device-123 | 5 | 0 | 2026-01-17 | 1 |

  Note: 6 of the 10 have credits but no `purchase_history` row at all, which is itself evidence for B-02 (tx id `0` skips the audit insert) and the legacy receipt path (B-09).
- [x] **P0-04** (CF-10) 🧑 Answered 2026-09-07: zone is on the Free plan, so no WAF managed rules (only Cloudflare's Free Managed Ruleset, which is automatic). Free plan still allows **one** rate-limiting rule; P7-14 becomes: create that rule for `/credits/purchase` + `/auth/*` (e.g. 10 requests per 10s per IP, block 10s). Bot Fight Mode: leave off (it can challenge the native app).
- [x] **P0-05** (CF-09) 🧑 Answered 2026-09-07: last 30 days = 33 requests, 29.3k tokens, $0.07, 0 errors, 0 cached. 32 of the 33 were the vitest run on the morning of 2026-09-07 (the suite calls the real gateway, T-01). Real app usage in the window: about 1 request.
- [x] **P0-06** Move `AuthKey_27VKZ6LCQ3.p8` out of the working tree (C-06) to `~/Keys/ReefBuddy/` and fix `.dev.vars` `APPLE_PRIVATE_KEY` quoting (C-05). Done 2026-09-07: key moved; `.dev.vars` PEM rewritten as a quoted `\n`-escaped value; `APPLE_KEY_ID` was a wrong 38-char value and is now `27VKZ6LCQ3` (same key material as the .p8). Verified: local `/analyze` with a random token now reaches Apple and gets the expected "incorrectly formatted device token" 400 instead of failing at key import.

**Exit:** backup exists, device ID known, baseline recorded.

---

## Phase 1 — Stop the bleeding (backend hotfix + deploy)

Goal: close the credit-grant holes and the broken refund, make deploys safe, ship. Minimal diff, each change covered by a test.

- [x] **P1-01** (B-01) `/credits/purchase`: verify the JWS signature *before* reading `environment`. In `ENVIRONMENT=production` accept only `environment === "Production"`; accept `Sandbox`/`Xcode` only when not production. Check `bundleId`, `type === "Consumable"`, and `signedDate` within 24h. Test: forged base64 Sandbox payload → 400/403, no credits.
- [x] **P1-02** (B-02) Remove the `transactionId === "0"` bypass in `addDeviceCredits`; every transaction goes through the duplicate check and audit insert. Test: replay same transaction → 409, balance unchanged.
- [x] **P1-03** (B-16) Replace `GREATEST(...)` with `MAX(0, ...)` in both refund statements. Test: force AI failure after consumption → `paid_credits`/`free_used` restored, `creditsRefunded: true`.
- [x] **P1-04** (B-17) `callAIGateway` returns a typed result `{ok:true,text,stopReason,usage} | {ok:false,status,retryable,kind}`. `/analyze` refunds on every failure and responds 502/503 with a generic message. Test: gateway 400/500/429 → refund + non-200.
- [x] **P1-05** (B-20) Credit consumption becomes a conditional `UPDATE … WHERE … AND paid_credits > 0` (or `free_used < ?`); `meta.changes === 0` means no credit. Test: two concurrent `/analyze` with 1 credit → exactly one succeeds.
- [x] **P1-06** (B-21) `addDeviceCredits`: insert `purchase_history` first (UNIQUE), then update balance, both in `env.DB.batch()`; UNIQUE violation → 409. Test included.
- [x] **P1-07** (B-31) Delete all 29 `// #region agent log` beacon blocks. Grep gate: `grep -c 127.0.0.1:7242 src/index.ts` must be 0.
- [x] **P1-08** (B-06) Replace `hostname.includes('dev')` with an explicit allow-list (`localhost`, `127.0.0.1`, the `[env.dev]` hostname). Test: `reefbuddy.fredylg.workers.dev` without a device token in dev mode → 403.
- [x] **P1-09** (B-10) Delete `/debug/jws-test` handler, route, and `test-jws-validation.sh`.
- [x] **P1-10** (B-09) Delete legacy `verifyReceipt` path: `CreditPurchaseSchema`, `validateAppleReceipt`, `handleLegacyPurchase`; `/credits/purchase` accepts only `jwsRepresentation`.
- [x] **P1-11** (B-05, C-01) `wrangler.toml`: production becomes top-level (`ENVIRONMENT=production`, custom domain route, `workers_dev = true` for now until Phase 4 ships the custom-domain client), dev moves to `[env.dev]` with `name = "reefbuddy-dev"`. `package.json`: `deploy` = `wrangler deploy`, `deploy:dev` = `wrangler deploy --env dev`, `dev` = `wrangler dev --env dev`. `vitest.config.ts` points at the dev env. Verify with `wrangler deploy --dry-run` for both.
- [x] **P1-12** (CF-06) Add `Strict-Transport-Security: max-age=31536000; includeSubDomains` to the security headers.
- [x] **P1-13** (T-04 part) Tests for P1-01 to P1-06 and P1-08 land with each task; this task is the sweep: `npx vitest run` green, new tests count recorded in the progress log.
- [x] **P1-14** (CF-01) ⛔ Deploy with `npm run deploy`. Verify `/health` on both hosts shows `environment: production` and the new version; `POST /debug/jws-test` → 404; forged Sandbox purchase → rejected (using a throwaway device ID).
- [x] **P1-15** (CF-02) ⛔ Production cleanup after P1-14 and P0-03: delete the 8 sandbox `purchase_history` rows; set `paid_credits = 0` on the 9 non-owner devices listed in P0-03. Statement shown in chat first. Verify with a count query.
- [x] **P1-16** (CF-03) ⛔ Prune probe-only `device_credits` rows. **Rescoped 2026-09-07:** of 106 rows with 0 analyses and 0 paid credits, 72 belong to real installs (a users row exists; 23 have tanks) and are kept; only the **34** rows with no users row and no purchase are deleted. Statement shown first.

**Exit:** no unsigned purchase is accepted in production; refunds work; deploys are unambiguous; production data reflects reality.

---

## Phase 2 — Toolchain and hermetic tests

Goal: green `tsc`, green offline `vitest`, zero audit findings, current wrangler.

- [x] **P2-01** (D-01) `wrangler@4.129`, `vitest@4.1.x`, `@cloudflare/vitest-pool-workers@0.22`. Run suite; fix pool config breakage.
- [x] **P2-02** (D-02) `jose@6`, `bcryptjs@3`, `zod@4.5`. Verify `SignJWT`/`importPKCS8` and `bcrypt.hash/compare` usage compiles.
- [x] **P2-03** (D-03) `typescript@6.0.3`. Confirm `tsc --noEmit` runs.
- [x] **P2-04** (D-04) Remove `@cloudflare/workers-types`; add `wrangler types` → `worker-configuration.d.ts` (committed), `tsconfig` types updated; `Env` in `src/index.ts` derived from the generated interface. This clears the 34 `ProvidedEnv` test errors.
- [x] **P2-05** (D-05) Fix the remaining `src/index.ts` type errors: `readJson<T>()` helper with 400 on malformed JSON (also B-29), typed D1 row mappers instead of `as X[]` casts.
- [x] **P2-06** (D-06) `npm run typecheck`; `deploy` scripts run `typecheck && vitest run` first. Add `noUnusedLocals`/`noUnusedParameters` (B-34 prep).
- [x] **P2-07** (C-02) `compatibility_date` → current date. Run suite and `deploy --dry-run`.
- [x] **P2-08** (T-01) Hermetic suite: blank `ANTHROPIC_API_KEY`/`CF_AI_GATEWAY_TOKEN` in pool bindings; `fetchMock` for the gateway URL with success, refusal, `max_tokens`, 429, 500 fixtures. Move the real-gateway test to `tests/integration/` gated by `RUN_INTEGRATION=1`. `npx vitest run` must pass with `.dev.vars` renamed away.
- [x] **P2-09** (T-02) Delete the DROP/CREATE schema blocks in `db.test.ts` and `tanks-backward-compat.test.ts`; convert `db.test.ts` to go through worker handlers or fold it into `api.test.ts`.
- [x] **P2-10** (T-03, B-33) Delete no-op tests in `security-stage2.test.ts`; delete `src/receipt-crypto.ts` and its test.
- [x] **P2-11** (T-05) Move `devicecheck-production.test.ts` to `tests/e2e/` (excluded by default); counter-based IPs for rate-limit tests; remove unused imports and the `FREE_TIER_LIMIT` binding.
- [x] **P2-12** (B-22) Migrate the 61 zod v3-compat calls to zod 4 idioms. Suite green.

**Exit:** `npm run typecheck` 0 errors, `npm audit` 0 findings, `npx vitest run` passes offline in under 60s.

---

## Phase 3 — Backend correctness and hardening

Goal: every route the app calls works with device auth; security items closed; AI path robust. Response shapes stay backward compatible with iOS 1.0.6 until Phase 4 ships.

Routing and auth
- [x] **P3-01** (B-18) Lowercase `url.pathname` once at the router; add `/i` to all UUID matchers; handlers use `tankResult.id`.
- [x] **P3-02** (B-19, P-03) Device-or-session auth (`resolveActor`) on `/api/tanks/:id` GET/PUT/DELETE, `/tanks/:id/{history,trends,averages,export}`, `/maintenance/schedules*`. Tests for each with `X-Device-ID`.
- [x] **P3-03** (B-07) Validate `X-Device-ID` as UUID (allow-list the two legacy `test-device-*` IDs out); rate-limit all device routes (60/min/IP) via the existing KV limiter.
- [x] **P3-04** (B-08) Reject `@reefbuddy.device` addresses in `/auth/signup`. Keep `/auth/*` routes (P-01 b).
- [x] **P3-05** (B-12) Rate-limit `/auth/login` and `/auth/signup` (10/min/IP); `password.max(128)`.
- [x] **P3-06** (B-14) CORS: `Vary: Origin`; unknown origin → no ACAO header; no `*` fallback. Native app unaffected (no Origin).
- [x] **P3-07** (B-13) Central `errorResponse` with generic message + `requestId` (from `cf-ray`); `error.message` only to `console.error`.
- [x] **P3-08** (B-11) Structured logger `log(level, event, fields)` gated on `ENVIRONMENT`; remove all body/token/JWS dumps.
- [x] **P3-09** (B-15) `APPLE_BUNDLE_ID` var; remove the two hard-coded literals.

StoreKit and DeviceCheck
- [x] **P3-10** (B-03, P-07 a) X.509 chain validation for the JWS `x5c`: leaf → intermediate → pinned Apple Root CA G3; check validity dates and the App Store receipt OID (1.2.840.113635.100.6.11.1); extract the leaf public key properly. Use `@peculiar/x509` (WebCrypto-based; add `nodejs_compat` only if it turns out to be required). Fixtures: a real sandbox JWS from `purchase_history` (owner device) must pass; a self-signed JWS must fail.
- [x] **P3-11** (B-28) `derSignatureToRaw`: treat 64-byte signatures as raw.
- [x] **P3-12** (B-04) DeviceCheck bit0 = free tier consumed: `query_two_bits` on first `/analyze`, `update_two_bits` when the third free analysis is used; a rotated `deviceId` on a device with bit0 set gets no free credits. Tests with mocked Apple responses.

Data correctness
- [x] **P3-13** (B-25) Soft-delete maintenance schedules; filter `deleted_at IS NULL` in list/get.
- [x] **P3-14** (B-23) `unreadOnly` via `z.stringbool()`.
- [x] **P3-15** (B-24) Pass `salinity_unit` into alert evaluation; PPT thresholds.
- [x] **P3-16** (B-26) Widen `WaterParametersSchema` to plausible physical ranges (pH 6.0–9.5, ammonia 0–10, nitrate 0–200, phosphate 0–5, SG 1.000–1.040 / PPT 0–50).
- [x] **P3-17** (B-27) Nitrite end to end: `WaterParametersSchema`, prompt, `historical.ts` `Measurement`/`WATER_PARAMETERS`/SELECT, CSV header, alert thresholds.
- [x] **P3-18** (B-30) Small-bugs bundle: soft-deleted livestock 409; signup race → 409; `errorResponse` at the `/measurements` switch goes through CORS; real regression slope; `Promise.all` in trends; N+1 in notification settings; `AbortSignal.timeout(25_000)` on the gateway fetch; `v_weekly_averages` week-start consistency (migration 0015, with M-02).
- [x] **P3-19** (B-32, P-04 a) Delete `checkPremiumAccess`; export ungated by design; comment in migration README that Stripe columns are retained but unused.
- [x] **P3-20** (B-34) Remove unused symbols; `noUnusedLocals` green.

AI path (backward compatible)
- [x] **P3-21** (A-02) `AI_MODEL` (`claude-haiku-4-5`, P-05 a) and `AI_MAX_TOKENS` vars in `wrangler.toml`; code reads them.
- [x] **P3-22** (A-03) Branch on `stop_reason`: `end_turn` → success; `max_tokens` → retry once with +1024 then return with `truncated: true`; `refusal` → 422 `analysis_refused`, credit refunded. Log `usage` (input/output tokens) per request.
- [x] **P3-23** (A-04) Structured output via `output_config.format` with a fixed schema (`summary`, `parameters[] {name, value, status, note}`, `dosing[]`, `warnings[]`). Response keeps the existing `recommendation` string (rendered from the structure) so 1.0.6 clients keep working; adds `structured` object for 1.0.7.
- [x] **P3-24** (A-05) Remove the manual retry loop; rely on AI Gateway retries (`cf-aig-max-attempts: 3`, `cf-aig-retry-delay`); honour `retry-after` on 429 once.

Config
- [x] **P3-25** (C-04) Flatten `AI_GATEWAY_ID`; fix `kv namespace` comment; `[observability]` at top level with `head_sampling_rate = 1`; verify in dashboard after deploy.
- [x] **P3-26** (M-02) Migration `0015_index_cleanup.sql`: drop redundant indexes, add `idx_water_changes_source_schedule`, drop `v_parameter_stats`, recreate `v_weekly_averages` consistently. Apply local, then remote after P3-28.
- [x] **P3-27** (T-04 rest) Coverage for `/api/livestock/*`, `/api/measurements`, `/api/tanks/:id` CRUD, `/maintenance/schedules` PUT/DELETE, `/tanks/:id/history|trends|averages|export` with device auth, `/credits/balance`.
- [x] **P3-28** ⛔ Deploy; verify `/health`; run `tests/e2e` against production with the owner device (read-only endpoints); apply 0015 remote.
- [x] **P3-29** (B-37) Normalise UUIDs to lowercase on insert paths and drop `LOWER(id) = ?` comparisons (23 sites). Production data already has 0 uppercase IDs, so no backfill needed.
- [x] **P3-30** ⛔ Deploy P3-29; smoke test.

**Exit:** every endpoint the app calls returns 2xx with device auth in tests; forged and self-signed JWS rejected; a real sandbox JWS accepted only in dev.

---

## Phase 4 — iOS sync fixes and 1.0.7 release

Goal: server sync actually works, App Store compliance, StoreKit and notification bugs fixed, ship 1.0.7 on iOS 18.

Networking and models
- [x] **P4-01** (I-01) `JSONDecoder` date strategy: custom ISO 8601 with and without fractional seconds. Unit test with both formats.
- [x] **P4-02** (I-10) `APIClient.send<T>()` helper: maps `URLError` → `.networkError`, `DecodingError` → `.decodingError` with context logged via `os.Logger`; all endpoints use it.
- [x] **P4-03** (I-02) `MaintenanceSchedule` / `WaterChange` API DTOs separated from local models; `needsSync`/`isDeleted` local-only.
- [x] **P4-04** (I-04, C-03) Lowercase UUIDs in every path; production base URL → `https://api.reefbuddy.aethers.com.au`.
- [x] **P4-05** (I-03, P-03 a) `getMeasurements` → `GET /tanks/{id}/history`; `HistoryView` and `ExportView` merge server + local by ID.
- [x] **P4-06** (I-05, I-06) One `LivestockDTO` (optional `createdAt`, optional `category`); server enums extended in P3 to accept iOS health statuses and `anemone`/`other` categories (add to P3-02 scope note); DTO maps 1:1.
- [x] **P4-07** (I-07, I-08) `Measurement.CodingKeys` for `ph`; `Tank.tankType` optional with default.
- [x] **P4-08** (I-09) Parse `code` from error bodies; distinct messages for `DEVICE_CHECK_FAILED` vs `FORBIDDEN`.
- [x] **P4-09** (I-11) `DeviceIdentity` helper: Keychain-backed UUID (uses the retained `KeychainManager`), falls back to `identifierForVendor` on first run so existing users keep their ID; used by `APIClient`, `AppState`, `StoreManager`.
- [x] **P4-10** (I-12) `fetchTanks` merges by ID; `deleteTank` cascades local measurements, livestock, schedules, water changes.
- [x] **P4-11** (A-04 client) Decode the new `structured` analysis object when present; fall back to `recommendation`.

StoreKit
- [x] **P4-12** (I-13) `finish()` only after backend success; unfinished transactions replayed on launch.
- [x] **P4-13** (I-14) `StoreManager.clearError()`; proper alert binding.
- [x] **P4-14** (I-15) Show `product.displayPrice`; per-credit from `product.price`.
- [x] **P4-15** (I-16) No fabricated credits; "balance unavailable" state; analyze button disabled until balance known.
- [x] **P4-16** (I-17) `Task { [weak self] }` listener; send `String(transaction.id)`.
- [x] **P4-17** (I-18) Restore = `Transaction.unfinished` replay + balance refresh; regenerate `ReefBuddy.storekit` in Xcode; remove `StoreKit.plist` from Resources.

Notifications (local reminders only; push is Phase 9/deferred)
- [x] **P4-18** (I-19) Set `UNUserNotificationCenter.delegate` in `didFinishLaunchingWithOptions`; buffer pending deep link in `AppState`.
- [x] **P4-19** (I-20) `anchorDate`/`lastFiredAt` on `MaintenanceSchedule`; interval occurrences computed from anchor; reschedule only on change.
- [x] **P4-20** (I-21, I-22) Window of 3 pending requests per schedule, top-up on launch, `addRequest` errors logged; weekly triggers carry `timeZone`; deep link handled once.

Compliance and project
- [x] **P4-21** (I-24) Add `PrivacyInfo.xcprivacy`: `NSPrivacyAccessedAPICategoryUserDefaults` reason `CA92.1`; collected data: Device ID, User Content (measurements, notes, photos), Purchases. Register the file in `project.pbxproj` by hand and verify.
- [x] **P4-22** (I-25) Version/build from `Bundle.main`. Bump `MARKETING_VERSION` 1.0.7, `CURRENT_PROJECT_VERSION` 6.
- [x] **P4-23** (I-26) Replace 98 `print(` with `os.Logger` (`.private` for IDs/tokens); no payload dumps.
- [x] **P4-24** (I-27, I-28, P-06 b) `ITSAppUsesNonExemptEncryption = NO`; `IPHONEOS_DEPLOYMENT_TARGET = 18.0`; `LastUpgradeCheck` current; accept Xcode recommended settings.
- [x] **P4-25** (I-36) Small-bugs bundle: throwing `requestAnalysis` with typed errors; `hasAnyValue` includes ammonia/nitrite; remove stale double PUT in `LivestockDetailView`; `if let` volume; real `updatedAt`; RFC 4180 CSV; dead state removed; previews fixed; `Tab.logWaterChange` removed in favour of the modal.
- [x] **P4-26** (I-37) Photos to Application Support with one-time migration from Documents.
- [x] **P4-27** Build + simulator run of: tank create/edit/delete, measurement save, analysis, purchase (StoreKit config), livestock add, schedule create, reminder tap. Confirm server rows appear via D1 (dev worker).
- [!] **P4-28** 🧑 (waiting on you: archive → TestFlight → device test → App Store) Archive, upload to TestFlight, run on a physical device against production; then App Store submission. After the release is live: set `workers_dev = false` (C-03 tail). **2026-09-07:** the project is now at 1.0.8 build 7 (Phase 6 included) — archive that instead of 1.0.7; see P6-08.

**Exit:** a fresh install on the simulator creates exactly one server row per tank/measurement/livestock/schedule save; no decode errors in the log; privacy manifest accepted by App Store Connect.

---

## Phase 5 — Backend structure

Goal: `src/index.ts` becomes a router; behaviour unchanged (suite is the guard).

- [x] **P5-01** (B-35) Delete the non-`/api` duplicate route family (`/tanks/:id/livestock`, `/livestock/:id`, `/livestock/:id/logs`, `/measurements`); keep `/api/*`. Update tests that used the old paths.
- [x] **P5-02** (B-36) Split into `env.ts`, `http.ts`, `schemas/*`, `auth/{session,devicecheck}.ts`, `ai/gateway.ts`, `credits/{store,storekit}.ts`, `routes/*.ts`, table-driven router in `index.ts`. Mechanical moves only; one commit per module.
- [x] **P5-03** (B-29) Prettier config + one formatting commit; merged-statement lines gone.
- [x] **P5-04** ⛔ Deploy; smoke test; `wrangler check startup` compared with baseline.

**Exit:** no file over 600 lines; suite green; identical responses for the smoke set.

---

## Phase 6 — iOS modernisation

Goal: Swift 6, `@Observable`, Charts, sane storage. No user-visible change except performance.

- [x] **P6-01** (I-29) `SWIFT_STRICT_CONCURRENCY = complete` in Swift 5 mode; fix: `Task.detached` capture, `UIDevice.current` in `APIClient`, `Sendable` singletons, `@MainActor AppDelegate`, `Timer.publish` in view.
- [x] **P6-02** (I-30) `SWIFT_VERSION = 6`; build clean.
- [x] **P6-03** (I-31) Deprecation sweep: `.foregroundStyle`, `.topBarLeading/Trailing`, value-based `NavigationLink`, `@FocusState`, async notification APIs.
- [x] **P6-04** (I-32) `@Observable` `AppState`, `StoreManager`, stores; `@Environment` injection; remove `@EnvironmentObject`.
- [x] **P6-05** (I-33) Stores become actors persisting JSON files in Application Support; one-time migration from UserDefaults; measurement history no longer in UserDefaults.
- [x] **P6-06** (I-34) Swift Charts replaces hand-drawn paths in `ChartView`/`HistoryView`.
- [x] **P6-07** (I-35, adjusted for P-01 b) Delete `AnalysisView.swift`, `BrutalistPicker`, `BrutalistIconButton`; move `AppIconGenerator.swift` out of the app target (keep in repo under `tools/`); **keep** `User.swift` and `KeychainManager.swift`.
- [!] **P6-08** Simulator regression done 2026-09-07 (see log); 🧑 **TestFlight 1.0.8 build 7 is yours** — it supersedes the 1.0.7 archive in P4-28 (one archive covers Phases 4 and 6).

**Exit:** Swift 6 build with zero warnings in the concurrency category; regression list passes.

---

## Phase 7 — Database, docs, hygiene, Cloudflare cleanup

- [x] **P7-01** (M-03, M-04) `migrations/README.md`: 0008 never existed; soft-delete-only rule; fix 0006/0011 headers. CI grep guard for `DELETE FROM` outside `push_tokens`.
- [x] **P7-02** (X-01) `CLAUDE.md` + `README.md`: model Haiku 4.5, deploy commands, 38 iOS files (regenerated tree), full endpoint table generated from the router, iOS 18.0.
- [x] **P7-03** (X-02) Correct `SECURITY_REMEDIATION_PLAN.md` tracker; H1/H3 marked as done by Phase 3 items; then archive it.
- [x] **P7-04** (X-03) `docs/archive/` for `REQUIREMENTS.md`, `REQUIREMENT-ANSWERS.md`, `SECURITY_AUDIT.md`, `MANUAL_TESTING_GUIDE.md`, `APP_ATTEST_IMPLEMENTATION_PLAN.md`, `MAINTENANCE_SCHEDULES_PLAN.md`, `PLAN.md`, `iOS/SETUP.md`, `iOS/VERIFICATION.md`. Keep `AI_GATEWAY_AUTH_SETUP.md`.
- [!] **P7-05** (X-04) copy + policy done 2026-09-07; 🧑 still to confirm the mailboxes — `web/`: soften Smart Alerts copy; privacy policy data inventory + date; 🧑 confirm `privacy@`/`support@reefbuddy.app` exist.
- [x] **P7-06** (H-01) Delete `test.txt`, `src/test.txt`, `src/verification/`, `TEST_FAILURE_REPORT.md`, `D1_LOCAL_VS_REMOTE_COMPARISON.md`, `CLOUDFLARE_SECURITY_BACKFILL.md` (archived copy of the last two under `docs/archive/`), `.cursor/`, `count-tables.sh`, the two dashboard screenshots in the repo root. **Added 2026-09-07:** `.wrangler/state/…/*.sqlite` (local Miniflare D1 files) are tracked in git despite `.gitignore`; `git rm -r --cached .wrangler` so local dev stops dirtying the tree.
- [x] **P7-07** (H-02, CF-07) Commit `web/tiktok*.txt`; `npm run deploy:web` = `wrangler pages deploy web --project-name reefbuddy-web`.
- [x] **P7-08** (H-03) `.gitignore`: `!.claude/agents/`.
- [x] **P7-09** (H-04) `scripts/` with parameterised base URL; delete `test-iap-fix.sh`; fix `capture-app-screenshots.sh` for bash 3.2; `core.hooksPath` for the pre-commit hook.
- [x] **P7-10** (H-05) `package.json` `private: true`, license `UNLICENSED`, author; dedupe pbxproj rules to `CLAUDE.md` only; remove duplicate `StoreKit.plist`/`.storekit` under `iap-configuration/`.
- [x] **P7-11** (T-06) Rewrite `tests/README.md`.
- [ ] **P7-12** (CF-04) ⛔ `wrangler kv namespace delete` for `SESSIONS` and `SESSIONS_preview` — exact commands: `npx wrangler kv namespace delete --namespace-id cc91d53bedea428587120defc94926f2` (SESSIONS) and `npx wrangler kv namespace delete --namespace-id a8af95c0bda64bca81f016e2899b1c5f` (SESSIONS_preview). Neither is bound in `wrangler.toml` (the Worker uses `REEF_KV`).
- [ ] **P7-13** (CF-05) ⛔ `npx wrangler pages project delete reefbuddy-site` — orphan; the live site is project `reefbuddy-web` (reefbuddy.aethers.com.au). Also delete the stale probe row `device_credits` `8b629a9b-9907-4d5b-80f9-dc18e3ff3587` (lowercase id, created by my P5-04 smoke test; 0 analyses, 0 credits) with the same go-ahead.
- [!] **P7-14** (CF-10 follow-up) 🧑 Create the single Free-plan rate-limiting rule on `aethers.com.au` (Security → WAF → Rate limiting rules → Create): name `reefbuddy-auth-purchase`; **expression** `(http.host eq "api.reefbuddy.aethers.com.au" and (starts_with(http.request.uri.path, "/credits/purchase") or starts_with(http.request.uri.path, "/auth/")))`; characteristics: IP; rate 10 requests per 10 seconds; action Block, duration 10 seconds. Tell me when it is in and I will probe it.
- [x] **P7-15** (CF-09 follow-up) Recorded in the review (CF-09 notes) on 2026-09-07.
- [x] **P7-16** (X-01) Regenerate the iOS file tree and endpoint table one last time after Phases 5–6.

---

## Phase 8 — Final verification and handover

- [x] **P8-01** Full backend gate: `npm run typecheck`, `npx vitest run` offline, `npm audit`, `wrangler deploy --dry-run` (prod and dev).
- [x] **P8-02** Full iOS gate: `./verify-xcode-project.sh`, Swift 6 build, simulator regression list.
- [ ] **P8-03** ⛔ (after deploying 73b9688) Production smoke with the owner device: health, balance, analyze (one credit), tank list, history, livestock list, schedule list.
- [x] **P8-04** Update `MAINTENANCE_REVIEW_2026-09.md`: every YES item marked `Done (task-id, commit)`.
- [!] **P8-05** (draft written 2026-09-07; final after P7-12/13 and the deploy) Handover note in `docs/maintenance/2026-09-handover.md`: what changed, how to deploy, what is deferred, next maintenance window suggestion (quarterly compat-date bump, wrangler update).

---

## Phase 9 — Deferred or declined (no work in this plan)

| Item | Your decision | What happens |
|---|---|---|
| P-02 / I-23 push notifications | Implement, separate plan later | `NotificationSettingsView` stays in the code, unreachable. Backend alert pipeline untouched. I write `PUSH_NOTIFICATIONS_PLAN.md` when you ask. Feasibility confirmed: APNs HTTP/2 works from deployed Workers via `fetch`. |
| A-06 AI Gateway BYOK | NO | Worker keeps `ANTHROPIC_API_KEY`. |
| CF-11 gateway payload logging | NO | Prompt/response payloads keep being stored at the gateway. |
| CF-12 gateway rate limit | NO | No gateway-level spend cap; Worker-side limits from P3-03 apply. |
| A-01 model choice | Info only, P-05 a | Stay on Haiku 4.5 via `AI_MODEL` var. |
| M-01 | N/A | Already applied. |

---

## Progress log

_(appended as tasks complete: `YYYY-MM-DD · task-id · summary · commit`)_

- 2026-09-07 · P0-03 · owner device `8B629A9B…` confirmed for cleanup exclusion · (no commit, plan only)
- 2026-09-07 · P0-04 · zone on Free plan, no WAF managed rules; P7-14 rescoped to the one free rate-limiting rule · (no commit)
- 2026-09-07 · P0-05 · AI Gateway 30-day analytics: 33 req / 29.3k tok / $0.07 / 0 errors; 32 were today's test run · (no commit)
- 2026-09-07 · P7-15 · analytics recorded in review CF-09 · (no commit)
- 2026-09-07 · P0-01 · branch `maint/p1-hotfix`; baseline in `docs/maintenance/baseline-2026-09.txt` (tsc **99** errors, not 46 as first reported: the earlier count was truncated by `head`) · 612c40d
- 2026-09-07 · P0-02 · D1 export `backups/reef-db-2026-09-07.sql` (472 KB, 13 tables, row counts match production) · 612c40d (gitignore)
- 2026-09-07 · P0-06 · .p8 moved to ~/Keys/ReefBuddy; .dev.vars PEM quoted and APPLE_KEY_ID corrected; local DeviceCheck auth verified against Apple · (local files only, no commit)
- 2026-09-07 · P1-01..P1-10, P1-12 · purchase verify-first + environment policy, tx "0" bypass removed, MAX() refunds, typed AI result with refund-on-failure, atomic credit consumption, atomic add with UNIQUE guard, 29 beacons removed, explicit dev host, HSTS, legacy receipt + debug route deleted. **Extra finding:** x5c key extraction matched none of the 8 real Apple-signed JWS in production (pattern lacked the 0x00 unused-bits byte), so real App Store purchases would have been rejected; replaced with SPKI import. `src/index.ts` 5759 → 5069 lines · f50b8aa
- 2026-09-07 · P1-13 · `tests/credits-purchase.test.ts` (18 tests) + `tests/analyze-credits-refund.test.ts` (7 tests, gateway mocked with `fetchMock`); suite 234 passed / 12 skipped / 0 failed; tsc 99 → 97 (src 12 → 6; 4 new `ProvidedEnv` typing errors in the new tests, fixed by P2-04) · f50b8aa
- 2026-09-07 · P1-11 · wrangler.toml production-first, `[env.dev]` = reefbuddy-dev, npm scripts, vitest on dev env, CLAUDE.md commands; both dry-runs verified (prod=production, dev=development) · b6799db
- 2026-09-07 · P1-14 (+CF-01) · `npm run deploy` → version `262bcd63-e61c-48c3-9904-00e9bb253309`, 762 KiB, startup 35 ms. Verified on both hosts: `/health` environment=production, `/debug/jws-test` 404, HSTS present, forged Sandbox JWS → 400 JWS_INVALID with 0 credits granted, legacy receiptData → 400, all 5 secrets still bound · (deploy, no commit)
- 2026-09-07 · P1-15 (CF-02) · production: 3 non-owner sandbox purchase rows deleted, paid_credits zeroed on 9 devices (287 credits); owner device 8B629A9B keeps 11 credits and its 5 audit rows · (data change, no commit)
- 2026-09-07 · P1-16 (CF-03) · production: 39 probe-only device_credits rows deleted (34 previewed + 5 test devices that P1-15 had just zeroed); 162 rows remain, 0 probe-only left · (data change, no commit)
- 2026-09-07 · **Phase 1 complete.**
- 2026-09-07 · P2-01..P2-07, P2-12 · wrangler 4.129, vitest 4.1.11, TS 6.0.3, jose 6, bcryptjs 3, zod 4.5; **`@cloudflare/vitest-plugin` 1.1.4 instead of pool-workers 0.22** (Cloudflare deprecated the pool package mid-upgrade); `npm audit` 13 → 0; workers-types replaced by generated `worker-configuration.d.ts`; compat date 2026-08-15; `readJson()` in 15 handlers; zod v3-compat calls migrated; **tsc 99 → 0 errors** · 267168e
- 2026-09-07 · **Phase 2 complete.**
- 2026-09-07 · P3-01..P3-09 · table-driven router (lowercased paths, anchored patterns), `resolveActor()` session-or-device on all app routes, bounded device ids + scoped rate limits (device 60/min, auth 10/min), signup domain guard, CORS allow-list only + `Vary`, generic 500s (34 sites), `X-Request-Id`, debug logs gated off in production, `APPLE_BUNDLE_ID` var. Device id rule is a bounded charset rather than strict UUID so the legacy test ids keep working. `src/index.ts` 5091 → 4573 lines. Suite 202 passed · ac972e3
- 2026-09-07 · P3-11 · already done in Phase 1 (raw 64-byte signatures) · f50b8aa
- 2026-09-07 · P3-10 · x5c chain validation with pinned Apple Root CA G3 (`@peculiar/x509` + `reflect-metadata`); leaf marker OID + WWDR marker required; Xcode-signed transactions accepted only outside production; real Apple-signed Sandbox fixture + tampered copy + Xcode fixture in tests; the former `it.fails` gap test now passes as a normal test. Bundle 951 → 1439 KiB raw (243 KiB gzip) · aa8dae5
- 2026-09-07 · P3-12 · DeviceCheck bit0 marks free tier consumed per physical device; query first, validate via update(bit1) on first sight, set bit0 after the 3rd free analysis; fresh device ids on a marked device get 402; 5 new tests with mocked Apple endpoints · b54f9c1
- 2026-09-07 · P3-13..P3-20 · soft-delete schedules, stringbool, PPT→SG alerts, plausibility ranges, nitrite end to end, small-bugs bundle (livestock 409, signup race, regression slope, parallel trends, N+1, gateway timeout), premium gate removed, unused-symbol checks on. Weekly-view fix deferred to migration 0015 (P3-26) · 2ba8aa8
- 2026-09-07 · P3-21..P3-25 · AI_MODEL/AI_MAX_TOKENS vars, structured JSON output matching the iOS model (+ rendered `recommendation`), refusal → 422 + refund, max_tokens retry + `truncated`, single gateway attempt, AI_GATEWAY_ID flattened, observability sampling · d5ec2c0
- 2026-09-07 · P3-26 · migration 0015: 6 redundant indexes dropped, water_changes FK index, v_parameter_stats dropped, averages views with avg_nitrite and Monday-start weeks · 9f03a47
- 2026-09-07 · P3-27 · `tests/device-routes.test.ts`: 21 tests covering every app-facing route with X-Device-ID and uppercase UUIDs · 9f03a47
- 2026-09-07 · P3-02 follow-up · migration 0016 + zod enums accept the iOS livestock categories (Anemone, Other) and health statuses (thriving, stressed, declining, critical) · ff9c3be
- 2026-09-07 · P3-28 · `npm run deploy` → version `1508ba3f-9488-419d-aefe-719e9585696d` (gate: tsc 0, 239 tests); both hosts healthy, HSTS + X-Request-Id present, debug route 404, route table served at `/`. Migrations: 0015 applied first try; **0016 failed on the livestock_logs FK** (D1 enforces FKs; deferred checks do not survive a parent DROP), production left intact (81 livestock / 5 logs), migration rewritten to park child rows, proven locally with FK on, then applied · 14ceed5
- 2026-09-07 · P3-29 · `LowercaseUuid` schema for all body ids; 29 `LOWER()` comparisons removed (indexes usable again) · cea9266
- 2026-09-07 · P3-30 · deploy → version `572828b5-658a-4ada-ac52-f29cc80aa2a1` (gate: tsc 0, 240 tests); health OK on both hosts; owner-device smoke: tanks list, uppercase tank GET, livestock list, history, balance all 200 · (deploy)
- 2026-09-07 · **Phase 3 complete.**
- 2026-09-07 · P4-01..P4-17 · APIClient rewritten (tolerant dates, typed errors, lowercase paths, history endpoint, unified livestock DTOs, os.Logger); Measurement/Tank/Schedule decoding fixes; Keychain-backed DeviceIdentity; tank merge + delete cascade; StoreKit finish-on-success, storefront prices, no fabricated credits, restore via unfinished. Simulator build green · 50bf5e0
- 2026-09-07 · P4-18..P4-26 · delegate at launch + buffered cold-start taps, anchor-based interval reminders (window 3), PrivacyInfo.xcprivacy, version from bundle (1.0.7 build 6), iOS 18 target, encryption exemption key, 64 prints → debugLog, small-bug bundle, water-change tab removed, photos in Application Support. Build green, 0 warnings · 20c95f5
- 2026-09-07 · P4-27 · simulator (iPhone 17) debug build against production: server-created tank fetched and merged (screenshot + log, no decode errors); all five payload types decoded with the app models compiled for macOS; seeded rows removed. UI-tap automation is not available here, so the livestock/history tabs were verified at the decode level rather than by tapping · 85194f2
- 2026-09-07 · P4-28 · **needs you**: Xcode → Product → Archive (scheme ReefBuddy, 1.0.7 build 6) → upload to TestFlight → run on your phone against production → App Store review. After 1.0.7 is live: set `workers_dev = false` (C-03 tail).
- 2026-09-07 · P5-01 · legacy `/tanks/:id/livestock`, `/livestock/:id`, `/livestock/:id/logs` and `/measurements` routes removed from the router; livestock tests moved to `/api/*` · 5355475
- 2026-09-07 · P5-02 · `src/index.ts` 4,743 → 221 lines; split into `env.ts`, `http.ts` (incl. KV rate limiter), `schemas.ts`, `ai/gateway.ts`, `auth/{session,devicecheck}.ts`, `credits/{store,storekit}.ts`, `routes/*.ts` (10 files); `reflect-metadata` stays the first import · 5355475
- 2026-09-07 · P5-03 · Prettier 3.9.6 (`.prettierrc.json`, `.prettierignore`, `npm run format[:check]`); one formatting-only commit over src/ and tests/ (39 files); tsc 0, 240 tests before and after · ff7d232
- 2026-09-07 · P5-04 · `npm run deploy` → version `e667dee4-0da8-412b-b30b-108bd1b44af6` (gate: tsc 0, 240 tests; 1444 KiB / 245 KiB gzip; startup 35.7 ms vs 35 ms baseline). Smoke on workers.dev + `api.reefbuddy.aethers.com.au`: health 200, owner-device tanks 200 (data intact, 11 credits), schedules 200, legacy `/measurements` 404, no-device 401, malformed JSON 400, HSTS + X-Request-Id present · (deploy)
- 2026-09-07 · **Phase 5 complete.**
- 2026-09-07 · P6-01 · strict concurrency in Swift 5 mode: 20 warnings → 0 (nonisolated notification delegate with `[String: String]` payload, async UserNotifications calls, Sendable singletons, `nonisolated(unsafe)` ISO formatters, PhotosPicker label view, `@MainActor` preview helper) · 2068d34
- 2026-09-07 · P6-02 · `SWIFT_VERSION = 6.0`, zero warnings · d253944
- 2026-09-07 · P6-03 · `.foregroundStyle` ×345, `.topBarLeading/Trailing` ×7; `NavigationLink(destination:label:)` in the settings rows is not deprecated and stays · 0ceb9e6
- 2026-09-07 · P6-04 · `@Observable` for AppState, StoreManager and the six stores; `@Environment(Type.self)` / `.environment(_:)` / `@State` everywhere; listener task `@ObservationIgnored` · b101bc3
- 2026-09-07 · P6-05 · `JSONFileStore` actor (Application Support/ReefBuddy/Data, atomic writes off the main actor, generation-ordered, `*.corrupt` quarantine) + `JSONDocument`; all seven UserDefaults blobs migrate on first launch and the keys are removed — verified on the iPhone 17 simulator (4 blobs migrated, `defaults read` clean, UI intact) · 1a8c691
- 2026-09-07 · P6-06 · Swift Charts in `ChartView` (line/point/range/rule marks, touch selection via `chartOverlay`) and the history mini chart; hand-drawn `Path` code removed · 5e58891
- 2026-09-07 · P6-07 · `AnalysisView.swift`, `BrutalistPicker`, `BrutalistIconButton` deleted; `AppIconGenerator.swift` moved to `tools/` (out of the target); pbxproj edited by hand, verify script green · 9c9e844
- 2026-09-07 · P6-08 · simulator Debug build (Swift 6) against production with `API_BASE_URL`: launch clean, no crash reports, tanks list rendered from the migrated `tanks.json`, credit balance fetched (3), no subsystem errors. Version bumped to **1.0.8 build 7** for your archive. Remaining 🧑: TestFlight + device test (also covers P4-28).
- 2026-09-07 · **Phase 6 code complete.**
- 2026-09-07 · P7-04, P7-06..P7-10 · nine stale docs + two reports → `docs/archive/`; stray files, `.cursor/`, `count-tables.sh`, `test-iap-fix.sh`, `test-jws-validation.sh` (debug route gone) deleted; `.wrangler/` untracked; `web/tiktok*.txt` committed and `npm run deploy:web` → `reefbuddy-web`; `.claude/agents/` tracked; `package.json` private/UNLICENSED/author/1.0.8; duplicate StoreKit config removed; `scripts/` with parameterised base URL, bash-3.2 screenshot script, `.githooks/pre-commit` + `scripts/setup-hooks.sh` (`core.hooksPath`) · d18311b
- 2026-09-07 · X-02 follow-up · `/analyze` limiter fails closed on KV error (`onError: 'deny'`), cheap routes still fail open; 3 new tests (243 total) · 73b9688
- 2026-09-07 · P7-01, P7-02, P7-03, P7-05, P7-11, P7-16 · `migrations/README.md` (+ `lint:migrations` in the deploy chain, 0006/0011 headers fixed); CLAUDE.md/README/iOS README regenerated (endpoint table from `ROUTES`, 39 files, Haiku 4.5, Swift 6/iOS 18); security plan tracker corrected and archived; website copy + privacy policy (Sept 2026); tests/README rewritten · 66a5cd5
- 2026-09-07 · P7-12, P7-13 · **awaiting your go-ahead** (commands in the task lines). P7-05 mailboxes and P7-14 WAF rule are yours (expression in the task line).
- 2026-09-07 · P8-01 · backend gate: tsc 0, 243 passed / 6 skipped, `npm audit` 0 vulnerabilities, dry-run prod and dev 1444.71 KiB / 245.47 KiB, lint:migrations OK, Prettier clean · (gate)
- 2026-09-07 · P8-02 · iOS gate: verify script green, Swift 6 Debug and Release simulator builds succeed with 0 warnings; simulator regression recorded under P6-08 · (gate)
- 2026-09-07 · P8-04 · review: 26 more items marked Done/Deferred with task ids and commits; only CF-04/CF-05 (P7-12/P7-13) remain, awaiting go-ahead · (this commit)
- 2026-09-07 · P8-05 · draft `docs/maintenance/2026-09-handover.md` · (this commit)
- 2026-09-07 · **Waiting on you:** deploy go-ahead for 73b9688 (then P8-03 smoke), P7-12/P7-13 deletions, TestFlight 1.0.8, mailboxes, WAF rule.
