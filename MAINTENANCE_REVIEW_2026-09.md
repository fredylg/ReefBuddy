# ReefBuddy Maintenance Review — 2026-09-07

Last commit: `ac5abe0` (2026-05-06). Reviewed: backend (`src/`, 5 files), iOS (38 Swift files, pbxproj), migrations, tests, docs, config, dependencies.

## How to use this file

Every item ends with a decision line. Mark it like this:

- `[x] YES` — I implement it in the follow-up plan.
- `[x] NO` — I skip it.
- Leave a note after the line if you want it done differently.

Items marked **Recommended: YES** are ones I'd do without hesitation. Items marked **Your call** depend on product intent. Section 18 collects the product decisions that several items hang on; answer those first.

---



## 0. Health snapshot


| Check              | Result                                                                                                                                                                     |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `npx vitest run`   | 211 passed, 12 skipped, 0 failed (84s). The `/analyze` tests call the real Anthropic API through the gateway using your `.dev.vars` key.                                   |
| `npx tsc --noEmit` | **46 errors** (12 in `src/index.ts`, 34 in `tests/`). Wrangler bundles with esbuild so it still deploys, but the types are broken.                                         |
| `npm audit`        | 13 vulnerabilities (12 high, 1 critical). All in dev tooling (vitest, vite, undici, ws). None ship to production.                                                          |
| Xcode project      | `verify-xcode-project.sh` passes. Toolchain is Xcode 26.2 / Swift 6.2.3; project is `SWIFT_VERSION = 5.0`, `LastUpgradeCheck = 1500`, iOS 17.0 target.                     |
| Live API           | Both hosts report `environment: production`, v1.0.6, `/debug/jws-test` returns 404. Production is healthy right now. Live account audit via wrangler is in **section 19**. |
| Secrets            | `AuthKey_*.p8` and `.dev.vars` are gitignored and were never committed. `.p8` still sits in the repo root.                                                                 |


The two headline findings:

1. **Anyone can grant themselves paid credits.** `/credits/purchase` skips signature verification when the unsigned JWS payload says `environment: "Sandbox"`. No auth, no rate limit. (B-01)
2. **The iOS app's server sync is almost entirely broken and failing silently.** Date decoding, required fields, uppercase UUIDs and session-only routes mean only `/analyze` and `/credits/`* actually work. Every tank, measurement, livestock and schedule save falls back to local storage while the server inserts orphaned rows. (Section 8)

---



## 1. Dependency updates


| Package                         | Installed  | Latest                | Jump     | Notes                                                                                                                                         |
| ------------------------------- | ---------- | --------------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| wrangler                        | 4.59.1     | 4.129.0               | minor    | Safe. Needs Node ≥22 (you have 22.22.3).                                                                                                      |
| @cloudflare/vitest-pool-workers | 0.12.3     | 0.22.0                | breaking | Fixes the undici/ws audit findings. Requires **vitest ^4.1**, not 5.                                                                          |
| vitest                          | 3.2.4      | 4.1.11 (5.0.0 exists) | major    | Go to 4.1.x to match the pool. 3.2.4 has a critical advisory.                                                                                 |
| @cloudflare/workers-types       | 4.20260115 | 5.20260906            | major    | Alternative: drop it and use `wrangler types` to generate `worker-configuration.d.ts` (Cloudflare's current recommendation).                  |
| typescript                      | 5.9.3      | 7.0.2 (6.0.3 exists)  | major    | TS 7 is the native-Go compiler; vitest/esbuild toolchain compatibility is unproven. Recommend 5.9.x → 6.0.3 only.                             |
| jose                            | 5.10.0     | 6.2.12                | major    | Only `SignJWT` and `importPKCS8` are used; both unchanged in v6.                                                                              |
| bcryptjs                        | 2.4.3      | 3.0.3                 | major    | v3 ships its own types (fixes the `TS7016` error) and is ESM-first. `hash`/`compare` API unchanged.                                           |
| zod                             | 4.3.5      | 4.5.4                 | minor    | Safe. But `src/index.ts` uses 61 deprecated v3-compat calls (`z.string().uuid()`, `.flatten()`, `ZodIssueCode`) slated for removal. See B-22. |


**D-01 · Upgrade the Workers toolchain: wrangler 4.129, vitest 4.1.x, vitest-pool-workers 0.22, run the suite.** Clears all 13 audit findings. Recommended: YES → Decision: [x] YES  [ ] NO **Done 2026-09-07 (Phase 2).**

**D-02 · Runtime deps: jose 6, bcryptjs 3, zod 4.5.** Low risk given the tiny API surface used. Recommended: YES → Decision: [ x] YES  [ ] NO **Done 2026-09-07 (Phase 2).**

**D-03 · TypeScript 5.9.3 → 6.0.3 (not 7).** Recommended: YES → Decision: [ x] YES  [ ] NO **Done 2026-09-07 (Phase 2).**

**D-04 · Replace** `@cloudflare/workers-types` **with** `wrangler types` **generated bindings.** Also fixes the 34 `ProvidedEnv` errors in tests because the generated `Env` becomes the source of truth. Recommended: YES → Decision: [ x] YES  [ ] NO **Done 2026-09-07 (Phase 2).**

**D-05 · Fix the remaining 12** `tsc` **errors in** `src/index.ts` (unknown `body` at 4598/4983, unsafe `Record<string,unknown>[]` casts at 4 sites). Recommended: YES → Decision: [ x] YES  [ ] NO **Done 2026-09-07 (Phase 2).**

**D-06 · Add a** `typecheck` **npm script and run** `tsc --noEmit` **before** `deploy`**.** Recommended: YES → Decision: [ x] YES  [ ] NO **Done 2026-09-07 (Phase 2).**

---



## 2. Backend — critical security

**B-01 · Critical · Sandbox/Xcode JWS skips signature verification.** `src/index.ts:3674-3701`. The payload is decoded *before* verification; if it says `environment: "Sandbox"` the unsigned payload is trusted. POSTing a hand-made base64 payload with `productId: com.reefbuddy.credits50` grants 50 credits per request in production. Fix: always verify the signature first, then require `environment === "Production"` when `ENVIRONMENT === "production"`; also check `type === "Consumable"` and `bundleId`. **Live evidence:** all 8 rows in production `purchase_history` are `Sandbox`/`Xcode` transactions (Jan 2026) that were accepted and granted 180 credits; 298 paid credits sit on 10 devices and not one is a real App Store purchase. Recommended: YES → Decision: [ x] YES  [ ] NO

**B-02 · Critical ·** `transactionId === "0"` **skips duplicate check and audit insert.** `src/index.ts:1221-1234`. Combined with B-01, infinitely replayable. Fix: remove the special case; accept Xcode transactions only outside production. Recommended: YES → Decision: [ x] YES  [ ] NO

**B-03 · Critical · Production JWS verification does not validate the x5c chain.** `src/index.ts:3239-3410`. It scans `x5c[0]` for a 65-byte EC point and never checks the chain to Apple Root CA G3, validity dates, or the App Store leaf OID. A self-signed JWS with a homemade leaf verifies. Fix options: (a) proper X.509 chain validation pinned to Apple's root (`@peculiar/x509`, needs `nodejs_compat`), or (b) confirm server-to-server via App Store Server API `GET /inApps/v1/transactions/{id}` (needs an App Store Connect API key). Recommended: YES — option (b) is simpler and stronger. → Decision: [ ] YES  [ ] NO   Option: [ ] a  [ x] b **Resolved 2026-09-07 with P-07: option (a) X.509 chain validation in the Worker.**

**B-04 · High · Free-tier is keyed on the client-supplied** `deviceId` **string.** `src/index.ts:2616,2779,810-916`. DeviceCheck bits are set to `false,false` and never read; the token is not bound to `deviceId`. Rotating `deviceId` gives unlimited free analyses, bounded only by 10 req/min/IP. Fix: persist bit0 = "free tier consumed" via DeviceCheck `update_two_bits` and read it back, so free credits follow the physical device. Recommended: YES → Decision: [x ] YES  [ ] NO

**B-05 · High · Plain** `npx wrangler deploy` **overwrites production with development config.** `wrangler.toml:4,27,78`; `package.json:9`; `CLAUDE.md:14`. Top-level and `[env.production]` share `name = "reefbuddy"`; top-level has `ENVIRONMENT = "development"`. A wrong deploy enables `/debug/jws-test` and the DeviceCheck bypass. The `TEST_FAILURE_REPORT.md` from Feb 2026 records this having happened. Fix: make production the top-level config, move dev to `[env.dev]` with a distinct name, and add a post-deploy `/health` check. Recommended: YES → Decision: [ x] YES  [ ] NO

**B-06 · High ·** `isDevWorker` **matches every** `*.workers.dev` **host.** `src/index.ts:2708-2712`: `hostname.includes('dev')` is true for the `.workers.dev` suffix itself, so with a dev deploy any request without a `deviceToken` skips DeviceCheck. Fix: match an explicit dev hostname or drop the bypass. Recommended: YES → Decision: [x ] YES  [ ] NO

**B-07 · High · Unauthenticated device routes create DB rows per arbitrary header.** `getOrCreateDeviceUser` and `checkDeviceCredits` insert a `users` / `device_credits` row for every new `X-Device-ID` value; no rate limit outside `/analyze`. Fix: validate `deviceId` as a UUID, rate-limit all device routes. **Live evidence:** 200 `device_credits` rows vs 117 users; 105 rows have zero analyses and zero purchases (probe-only IDs). Recommended: YES → Decision: [x ] YES  [ ] NO

**B-08 · Medium · Device identity is a synthetic email anyone can pre-register.** `src/index.ts:1387,1421`. `/auth/signup` accepts `device_<id>@reefbuddy.device`, hijacking that device's tanks. Fix: reject the `@reefbuddy.device` suffix in signup; longer term, model device users with a column. Recommended: YES → Decision: [x ] YES  [ ] NO

**B-09 · Medium · Remove the legacy** `verifyReceipt` **path.** `src/index.ts:398-404,3414-3475,3804-3878`. Apple deprecated it in 2023; it binds any receipt containing the product to any `deviceId` with no ownership check. Recommended: YES → Decision: [ x] YES  [ ] NO

**B-10 · Medium · Delete** `/debug/jws-test`**.** `src/index.ts:3559-3645,5436`. Gated only by `ENVIRONMENT`, see B-05. Recommended: YES → Decision: [x ] YES  [ ] NO

**B-11 · Medium · Stop logging request bodies, DeviceCheck tokens and JWS.** 60 `console.log` calls; `:2655-2668,3487-3495,881,3208-3346`. Production invocation logs are a PII sink. Fix: structured logger gated on environment; never log tokens. Recommended: YES → Decision: [ x] YES  [ ] NO

**B-12 · Medium · Rate-limit** `/auth/login` **and** `/auth/signup`**; cap password length.** `src/index.ts:1488-1549,212`. Recommended: YES → Decision: [ x] YES  [ ] NO

**B-13 · Medium · Stop echoing** `error.message` **and upstream** `details` **to clients.** ~30 sites like `:1476-1480`, `:988`. Return a generic message plus request ID; details go to logs. Recommended: YES → Decision: [x ] YES  [ ] NO

**B-14 · Low · CORS: return** `Vary: Origin`**, never fall back to** `capacitor://localhost`**, and don't return** `*` **when** `Origin` **is absent.** `:557,5131-5139,5753`. Native app sends no `Origin`, so low impact. Recommended: YES → Decision: [ x] YES  [ ] NO

**B-15 · Low · Move the bundle ID (hard-coded twice,** `:3608,3743`**) to an env var.** Recommended: YES → Decision: [ x] YES  [ ] NO

---



## 3. Backend — bugs

**B-16 · High · Credit refunds have never worked.** `src/index.ts:1182,1194` use `GREATEST(...)`; SQLite has no such function (verified with `sqlite3`), so `refundDeviceCredit` always throws and returns `false` while the 503 body says "Your credit has been refunded". Fix: `MAX(0, total_analyses - 1)` + a test. Recommended: YES → Decision: [ x] YES  [ ] NO

**B-17 · High · Non-retryable AI errors are returned as HTTP 200 success and the credit is kept.** `:2871-2905`. `callAIGateway` signals errors as a JSON string on the same channel as model text; only `retryable` triggers refund. Fix: return a typed `{ok, text} | {ok:false, status, retryable}` union, refund on every failure, respond 502/503. Recommended: YES → Decision: [ x] YES  [ ] NO

**B-18 · High · Route regexes are case-sensitive but iOS sends uppercase UUIDs.** `:5329,5342,5355,5446-5488`. `GET/PUT/DELETE /api/tanks/:id` and `/tanks/:id/{history,trends,averages,export}` 404 for all real app traffic. Water-change routes already use `/i`. Fix: lowercase `pathname` once at the router, use `tankResult.id` in handlers (`:3946,4004,4062,4124`). Recommended: YES → Decision: [x ] YES  [ ] NO

**B-19 · High · Same routes require a Bearer session the app never has.** `:5332,5345,5358,5449-5488`, and all `/maintenance/schedules`* (`:5226-5270`). Fix: reuse the device-or-session `authenticateWaterChangeRequest` for every device-facing route. Recommended: YES → Decision: [x ] YES  [ ] NO

**B-20 · High · Credit consumption is check-then-act; concurrent requests drive** `paid_credits` **negative.** `:1131-1160,2779-2828`. Fix: conditional `UPDATE ... AND paid_credits > 0`, treat `meta.changes === 0` as no credit. Recommended: YES → Decision: [x ] YES  [ ] NO

**B-21 · Medium ·** `addDeviceCredits` **is not atomic; duplicate purchases can double-grant.** `:1221-1273`. Fix: INSERT `purchase_history` (UNIQUE) first, then UPDATE, in `DB.batch()`; map UNIQUE violation to 409. Recommended: YES → Decision: [x ] YES  [ ] NO

**B-22 · Medium · Migrate 61 deprecated zod v3-compat calls.** `z.string().uuid()/.email()/.datetime()/.url()`, `.flatten()`, `.format()`, `ZodIssueCode.custom` → `z.uuid()`, `z.email()`, `z.iso.datetime()`, `z.url()`, `z.treeifyError()`, `ctx.addIssue({code:'custom'})`. Recommended: YES (with D-02) → Decision: [x ] YES  [ ] NO **Done 2026-09-07 (Phase 2).**

**B-23 · Medium ·** `unreadOnly` **query param is always true.** `src/notifications.ts:153` + `src/index.ts:4398`: `z.coerce.boolean()` turns the string `"false"` into `true`. Fix: `z.stringbool()`. Recommended: YES → Decision: [ x] YES  [ ] NO

**B-24 · Medium · Salinity alerts ignore** `salinity_unit`**; a 35 PPT reading always alerts "too high at 35SG".** `notifications.ts:175`, `index.ts:2552-2569`. Recommended: YES → Decision: [ x] YES  [ ] NO

**B-25 · Medium · Hard** `DELETE FROM maintenance_schedules` **violates the FK from** `water_changes.source_schedule_id` **→ 500.** `:2250`; migrations 0013/0014. Also list/get never filter `deleted_at`. Fix: soft delete + filter. Recommended: YES → Decision: [x ] YES  [ ] NO

**B-26 · Medium ·** `/analyze` **validation rejects the tanks that most need analysis.** `WaterParametersSchema` (`:137-188`) 400s on pH < 7.8, ammonia > 1, nitrate > 50, phosphate > 0.5, SG outside 1.020–1.030. `CreateMeasurementSchema` accepts them. Fix: widen to physically plausible ranges and let the model comment. Recommended: YES → Decision: [ x] YES  [ ] NO

**B-27 · Medium · Nitrite is collected but never sent to the AI or exported.** `WaterParametersSchema`, `historical.ts:15-29,107-117,147`, `export.ts:51-64`, iOS `Measurement.swift:346-357`. Recommended: YES → Decision: [x ] YES  [ ] NO

**B-28 · Low ·** `derSignatureToRaw` **mangles ~1/256 legitimate ES256 signatures** (any raw signature starting with `0x30`). `:3140-3143`. Fix: if `length === 64` use as-is. Recommended: YES → Decision: [ x] YES  [ ] NO

**B-29 · Low · Malformed JSON → 500 instead of 400 across ~15 handlers; several lines have multiple statements merged (bad merge).** `:2483-2488,2504-2510,2599,3892-3901,4614,4727,5299-5302,5406-5418,5499-5501`. Fix: central `readJson()` helper + run Prettier. Recommended: YES → Decision: [ x] YES  [ ] NO **readJson() done 2026-09-07 (P2-05); Prettier pass pending (P5-03).**

**B-30 · Low · Assorted small bugs:** soft-deleted livestock ID gives false 409 (`:4620-4657`); signup race → 500 not 409 (`:1439-1456`); `errorResponse` at `:5410` bypasses CORS pass; `historical.ts:225` "slope" is first-vs-last delta and `:271` runs 9 sequential queries; `v_weekly_averages` mixes Monday/Sunday week starts (`0006:463-483`); N+1 in `:4335`; no `AbortSignal` timeout on the gateway fetch (`:957`). Recommended: YES (bundle) → Decision: [ x] YES  [ ] NO

**B-31 · Low · Delete the 29 leftover debug beacons** `fetch('http://127.0.0.1:7242/ingest/...')` in the livestock handlers (`:4584-5622`, `// #region agent log` blocks). Floating promises posting user IDs and stack traces on every production livestock request. Recommended: YES → Decision: [ x] YES  [ ] NO

---



## 4. Backend — dead code and structure

**B-32 · Medium · Remove or wire the Stripe / premium remnants.** Migration 0003 columns have zero references; `subscription_tier` always `'free'`; `checkPremiumAccess` (`export.ts:203`) never called, so CSV export is ungated. Your call: see P-04. → Decision: [ x] YES remove  [ ] NO keep

**B-33 · Low · Delete** `src/receipt-crypto.ts` **and its test, or wire it in.** Only imported by `tests/security-stage2.test.ts`; `RECEIPT_ENCRYPTION_KEY` exists nowhere. Recommended: YES delete → Decision: [ x] YES  [ ] NO

**B-34 · Low · Remove unused symbols:** `getMonthlyAverages`, `getAllHeaders`, `CreditBalanceSchema`, `AnalysisRequestSchema` (`:193`), `ALLOWED_ORIGINS` fallback, `SessionData.created_at`, `APNsConfig`/`FCMConfig`. Add `noUnusedLocals` to tsconfig. Recommended: YES → Decision: [x ] YES  [ ] NO

**B-35 · Low · Collapse the duplicate route families.** `/tanks/:id/livestock`, `/livestock/:id`, `/livestock/:id/logs`, `/measurements` (session-only) duplicate the `/api/...` versions the app uses. Keep `/api/`*, delete the rest. Recommended: YES → Decision: [ x] YES  [ ] NO

**B-36 · Medium · Split** `src/index.ts` **(5,759 lines) into modules.** Proposed: `index.ts` (router only) · `env.ts` · `http.ts` · `schemas/`* · `auth/{session,devicecheck}.ts` · `ai/gateway.ts` · `credits/{store,storekit}.ts` · `routes/{auth,tanks,measurements,analysis,credits,maintenance,water-changes,livestock,notifications,history}.ts`. Do it *after* the bug fixes so the diff is reviewable. Recommended: YES → Decision: [ x] YES  [ ] NO

**B-37 · Medium · Normalise UUIDs to lowercase at the boundary and drop** `WHERE LOWER(id) = ?` (23 sites). Those comparisons defeat every index. Recommended: YES → Decision: [x ] YES  [ ] NO

---



## 5. AI / model

**A-01 · Info · Current model** `claude-haiku-4-5-20251001` **is still served.** It is a dated snapshot; the alias is `claude-haiku-4-5`. Current lineup and list prices per 1M tokens: Haiku 4.5 $1/$5, Sonnet 5 $2/$10, Opus 5 $5/$25. For a single-turn 2k-token reply Haiku is a defensible cost choice; Sonnet 5 would give noticeably better reef-chemistry reasoning at ~2x the cost. Your call: see P-05.

**A-02 · Medium · Move the model ID and** `max_tokens` **to env vars** so the next retirement is a config change, not a deploy. Recommended: YES → Decision: [ x] YES  [ ] NO

**A-03 · Medium · Handle** `stop_reason` **and log** `usage`**.** `:962,994-1006`. `max_tokens` truncation is returned as a complete recommendation; `refusal` becomes "unexpected shape → retryable" → broken refund path → 503. Fix: branch on `end_turn` / `max_tokens` / `refusal`; log `usage` for cost tracking. Recommended: YES → Decision: [ x] YES  [ ] NO

**A-04 · Medium · Use structured output (**`output_config.format`**) so the client always gets one fixed JSON schema** instead of the current "prose becomes `{recommendation}`, JSON-looking prose becomes `analysis`" dual shape (`:2901`). Also lowers prompt-injection steering risk. Recommended: YES → Decision: [ x] YES  [ ] NO

**A-05 · Low · Pick one retry layer.** Manual loop (1s+2s+4s) × `cf-aig-max-attempts: 3` can reach 12 upstream attempts; 429/500/503 are not retried by the loop at all. Fix: let AI Gateway retry, honour `retry-after`. Recommended: YES → Decision: [x ] YES  [ ] NO

**A-06 · Low · Consider AI Gateway BYOK** so the Worker does not hold `ANTHROPIC_API_KEY`. Your call. → Decision: [ ] YES  [ x] NO

---



## 6. Config and deploy

**C-01 · High · Fix the wrangler environment layout** (see B-05). Production at top level, `[env.dev]` named `reefbuddy-dev`, `npm run deploy` = production, `npm run deploy:dev`. Update CLAUDE.md/README. Recommended: YES → Decision: [ x] YES  [ ] NO

**C-02 · Medium · Bump** `compatibility_date` **from** `2024-01-01` **to a current date.** Run tests + `wrangler deploy --dry-run`. `nodejs_compat` not needed unless B-03 option (a) is chosen. Recommended: YES → Decision: [ x] YES  [ ] NO **Done 2026-09-07 (Phase 2).**

**C-03 · Low · Point iOS at** `api.reefbuddy.aethers.com.au` **and then set** `workers_dev = false`**.** The custom domain is live and healthy but unused; the app hard-codes the personal `reefbuddy.fredylg.workers.dev` host (`APIClient.swift:14`). Recommended: YES → Decision: [ x] YES  [ ] NO

**C-04 · Low · Flatten** `[vars.AI_GATEWAY] gateway_id` **to** `AI_GATEWAY_ID`**; fix the deprecated** `kv:namespace` **comment; verify observability applies to the production env; add** `head_sampling_rate`**.** Recommended: YES → Decision: [ x] YES  [ ] NO

**C-05 · Low ·** `.dev.vars` ****`APPLE_PRIVATE_KEY` **is an unquoted multi-line PEM**, so local `wrangler dev` sees DeviceCheck "configured" but the import fails and every local `/analyze` 403s. Fix: quote it or use `\n`. Recommended: YES → Decision: [ x] YES  [ ] NO

**C-06 · Low · Move** `AuthKey_27VKZ6LCQ3.p8` **out of the working tree.** Never committed, but one `git add -f` away. The secret is already in `wrangler secret` and `.dev.vars`. Recommended: YES → Decision: [x ] YES  [ ] NO

---



## 7. iOS — API contract (critical; sync is silently broken)

**I-01 · Critical · Date decoding fails on every server response.** `APIClient.swift:85` uses `.iso8601`, which does not accept fractional seconds; the backend emits `toISOString()` with milliseconds. `getTanks`, `createTank`, `createMeasurement`, `createWaterChange`, `getWaterChanges`, `createMaintenanceSchedule`, `updateMaintenanceSchedule` all throw and fall back to local storage, while the server row was already inserted (orphans on every save). Fix: custom strategy trying `.withFractionalSeconds` then without. Recommended: YES → Decision: [x ] YES  [ ] NO

**I-02 · Critical ·** `needsSync` **/** `isDeleted` **are required Decodable keys the server never sends.** `MaintenanceSchedule.swift:58-59,108-109`. Schedule upsert decoding always fails. Fix: `decodeIfPresent ?? false`, or separate API DTOs from local models. Recommended: YES → Decision: [x ] YES  [ ] NO

**I-03 · Critical ·** `getMeasurements` **calls** `GET /api/measurements?tank_id=`**, which does not exist.** `APIClient.swift:246-260`. History only ever shows local data. Fix: call `/tanks/{id}/history` (after B-18/B-19) or add the GET route. Recommended: YES → Decision: [ x] YES  [ ] NO

**I-04 · Critical · Tank GET/PUT/DELETE send uppercase UUIDs to case-sensitive, session-only routes.** `APIClient.swift:104,129,142`. `deleteTank` only deletes locally. Fix: lowercase UUIDs in paths (client) + B-18/B-19 (server). Recommended: YES → Decision: [x ] YES  [ ] NO

**I-05 · High · Livestock create/list/update decoding fails on every call.** `Livestock.swift:411-456`: `createdAt` required but server sends only `added_at`; `category` optionality differs across three duplicate `LivestockDBRecord` structs. Users see "Saved locally, but failed to sync" on every add. Fix: one DTO, optional `createdAt`. Recommended: YES → Decision: [x ] YES  [ ] NO

**I-06 · High · Health status and category enums don't match the backend.** iOS sends `thriving|stressed|declining|critical`; server accepts `healthy|sick|deceased|quarantine` → 400. `.anemone` and `.other` are silently sent as `Invertebrate`. Fix: extend server enums (preferred) or map in the DTO. **Live evidence:** all 81 livestock rows in production have `health_status = healthy`; no other value has ever been stored. Recommended: YES → Decision: [ x] YES  [ ] NO

**I-07 · Medium ·** `Measurement.pH` **has no** `CodingKeys`**, so** `ph` **from the server decodes as nil.** `Measurement.swift:31`. Recommended: YES → Decision: [x ] YES  [ ] NO

**I-08 · Medium ·** `Tank.tankType` **is non-optional; server column is nullable.** `Tank.swift:20`. Recommended: YES → Decision: [ x] YES  [ ] NO

**I-09 · Medium · Every 403 becomes "Please update to the latest app version"** even for "You do not have access to this tank". `APIClient.swift:759-762`. Parse the `code` field. Recommended: YES → Decision: [ x] YES  [ ] NO

**I-10 · Medium · Wrap network/decoding errors and log** `DecodingError` **context** so silent fallbacks become visible; `.decodingError`/`.networkError`/`.forbidden` cases exist but are never thrown. Recommended: YES → Decision: [x ] YES  [ ] NO

**I-11 · Low · Single** `DeviceIdentity` **helper.** `X-Device-ID` uses `identifierForVendor` with no fallback in `APIClient`, while `AppState`/`StoreManager` fall back to a UserDefaults UUID. Optionally back it with Keychain (the unused `KeychainManager`) so the free tier survives reinstall. Recommended: YES → Decision: [ x] YES  [ ] NO

**I-12 · Low ·** `fetchTanks` **replaces local tanks wholesale;** `deleteTank` **never cascades to measurements/livestock/schedules/water changes in UserDefaults.** Will bite once sync works. Recommended: YES → Decision: [ x] YES  [ ] NO

---



## 8. iOS — StoreKit / credits

**I-13 · High ·** `transaction.finish()` **is called even when backend validation fails.** `StoreManager.swift:337-356`. A consumable finished without credits is unrecoverable. Fix: finish only on success. Recommended: YES → Decision: [ x] YES  [ ] NO

**I-14 · High · Purchase error alert re-presents forever.** `PurchaseCreditsView.swift:51-57` binds to `.constant(purchaseError != nil)` and OK does nothing. Recommended: YES → Decision: [ x] YES  [ ] NO

**I-15 · Medium · Prices are hardcoded** `$0.99` **/** `$4.99`**.** `Product.displayPrice` is loaded but never shown; wrong in every non-USD storefront and an App Review risk. Recommended: YES → Decision: [ x] YES  [ ] NO

**I-16 · Medium · App fabricates 3 free credits when the balance fetch fails.** `StoreManager.swift:256-270`, `ReefBuddyApp.swift:433-437`. Show "balance unavailable" instead. Recommended: YES → Decision: [ x] YES  [ ] NO

**I-17 · Medium ·** `Task.detached` **capturing** `@MainActor self` **in the transaction listener** (leak + Swift 6 error); send `String(transaction.id)` instead of a random UUID (`:209`). Recommended: YES → Decision: [ x] YES  [ ] NO

**I-18 · Low · "Restore" via** `AppStore.sync()` **cannot restore consumables**; replay `Transaction.unfinished` + refetch balance instead. Regenerate `ReefBuddy.storekit` (invalid `internalID`s); drop `StoreKit.plist` from Resources. Recommended: YES → Decision: [x ] YES  [ ] NO

---



## 9. iOS — notifications / deep links

**I-19 · High · Notification delegate is set in** `ContentView.onAppear`**, too late for cold-start taps.** `ReefBuddyApp.swift:33-52`. Tapping a reminder when the app is not running never opens the quick-action sheet. Fix: set the delegate in `didFinishLaunchingWithOptions`, buffer the pending deep link in `AppState`. Recommended: YES → Decision: [ x] YES  [ ] NO

**I-20 · High · Interval reminders re-anchor to "today" on every launch**, so an every-7-days reminder fires the day after every launch. `MaintenanceNotificationService.swift:180-203`. Fix: add `anchorDate`/`lastFiredAt` to the model; reschedule only on change. Recommended: YES → Decision: [ x] YES  [ ] NO

**I-21 · Medium · 10 pending requests per interval schedule × 64-request iOS cap;** `try? addRequest` **swallows errors.** Lower window to 2–3, log failures. Recommended: YES → Decision: [ x] YES  [ ] NO

**I-22 · Low · Weekly triggers omit** `timeZone`**; deep-link handler runs twice per tap.** `MaintenanceNotificationService.swift:105-121`, `ContentView.swift:32-40`. Recommended: YES → Decision: [ x] YES  [ ] NO

**I-23 · Medium ·** `NotificationSettingsView` **(550 lines) is unreachable and non-functional**: `@State` only, never persisted, sample history hardcoded, entry point commented out; the app never registers for remote notifications so the backend `/notifications/`* pipeline receives nothing, and `sendPushNotification` is a stub. Your call: see P-02. → Decision: [ x] YES wire it  [ ] NO delete it **Deferred to the push-notifications plan (see P-02).**

---



## 10. iOS — App Store compliance and project config

**I-24 · High · No** `PrivacyInfo.xcprivacy`**.** Required since May 2024; the app uses `UserDefaults` (reason code `CA92.1`) and collects a device identifier. Uploads without it are rejected (ITMS-91053). Recommended: YES → Decision: [ x] YES  [ ] NO

**I-25 · Medium · Version/build strings hardcoded** (`ContentView.swift:695,699` says build `2026.02`; pbxproj says `5`). Read from `Bundle.main`. Recommended: YES → Decision: [ x] YES  [ ] NO

**I-26 · Medium · 98 ungated** `print(` **statements; some dump the full JWS, the full analysis payload with notes, and device IDs.** Replace with `os.Logger` (privacy `.private`). Recommended: YES → Decision: [ x] YES  [ ] NO

**I-27 · Low · Add** `ITSAppUsesNonExemptEncryption = NO` to the generated Info.plist (removes the upload prompt). Recommended: YES → Decision: [ x] YES  [ ] NO

**I-28 · Medium · Update project settings for Xcode 26**: `LastUpgradeCheck 1500` → current, accept "recommended settings". Recommended: YES → Decision: [ x] YES  [ ] NO

---



## 11. iOS — modernisation (no user-visible change, reduces future breakage)

**I-29 · Medium · Swift 6 readiness in Swift 5 mode.** Enable `SWIFT_STRICT_CONCURRENCY = complete`, fix the ~8 known blockers (`Task.detached` self capture, `UIDevice.current` inside `actor APIClient`, non-Sendable singletons `MaintenanceNotificationService`/`KeychainManager`/`ImageStorage`, `AppDelegate` isolation, `Timer.publish` in a View). Recommended: YES → Decision: [ x] YES  [ ] NO

**I-30 · Low · Flip** `SWIFT_VERSION` **to 6** after I-29. Your call. → Decision: [ x] YES  [ ] NO

**I-31 · Low · Mechanical deprecation sweep**: 345× `.foregroundColor` → `.foregroundStyle`; `.navigationBarLeading/Trailing` → `.topBarLeading/Trailing` (7 sites); `NavigationLink(destination:)` → value-based; `sendAction(resignFirstResponder)` → `@FocusState`; `DispatchQueue.main.async` + completion handlers → async APIs. Recommended: YES → Decision: [ x] YES  [ ] NO

**I-32 · Medium · Migrate** `ObservableObject`**/**`@Published`**/**`@EnvironmentObject` **to** `@Observable`**/**`@Environment`**.** iOS 17 floor allows it; fixes over-invalidation from `AppState` publishing seven arrays. Larger refactor. Your call. → Decision: [ x] YES  [ ] NO

**I-33 · Low · Storage:** `ObservableObject` **stores held as** `let` **in** `AppState` **(their** `@Published` **never drives views); unbounded measurement history in UserDefaults; every livestock save rewrites every photo to disk.** Move to JSON files in Application Support (or SwiftData); write photos only when changed. Recommended: YES → Decision: [ x] YES  [ ] NO

**I-34 · Low · Replace hand-drawn** `Path` **charts (~300 lines in** `ChartView`**/**`HistoryView`**) with Swift Charts.** Your call. → Decision: [x ] YES  [ ] NO

---



## 12. iOS — dead code and small bugs

**I-35 · Medium · Delete unused files/views**: `AnalysisView.swift` (445 lines, never instantiated; `AnalysisResultSheet` duplicates it), `User.swift` + `KeychainManager.swift` (no login UI; see P-01), `AppIconGenerator.swift` from the shipping target, `BrutalistPicker`, `BrutalistIconButton`. Recommended: YES (except keep `KeychainManager` if I-11 uses it) → Decision: [ x] YES  [ ] NO **Adjusted for P-01 (b): `User.swift` and `KeychainManager.swift` are kept.**

**I-36 · Low · Small bugs bundle**: unreachable `catch` blocks around a non-throwing `requestAnalysis` (`MeasurementEntryView.swift:552-601`); `hasAnyValue` ignores ammonia/nitrite (`:516-525`); stale-copy double PUT in `LivestockDetailView.swift:86-97`; `Double(volumeText)!` in `TankListView.swift:231`; "Last updated: Today" hardcoded; CSV escaping not RFC 4180 (`ExportView.swift:298`); dead state `isRefreshing`/`showingSubscription`; previews missing environment objects; `Tab.logWaterChange` duplicates the modal sheet. Recommended: YES → Decision: [ x] YES  [ ] NO

**I-37 · Low · Move livestock photos from** `Documents/` **to Application Support** (keeps them out of Files/backups). Recommended: YES → Decision: [ x] YES  [ ] NO

---



## 13. Database

**M-01 · Resolved · Migrations 0013/0014 are applied remotely.** Verified with `wrangler d1 migrations list --remote` (no pending) and the `d1_migrations` table (13 rows, 0013/0014 applied 2026-05-06). Nothing to do.
→ Decision: [x] N/A

**M-02 · Low · Migration 0015: drop redundant indexes** (4 overlapping on `measurements(tank_id, measured_at)`; 3 duplicating UNIQUE constraints), add `water_changes(source_schedule_id)` index, drop unused view `v_parameter_stats`. Recommended: YES → Decision: [x ] YES  [ ] NO

**M-03 · Low · Document that 0008 never existed** (confirmed via git history and the D1 comparison) and fix misleading headers (0006 says "0003"; 0011 says "skip locally"). Recommended: YES → Decision: [ x] YES  [ ] NO

**M-04 · Low · Document "soft-delete only" and grep-guard** `DELETE FROM`**.** Recommended: YES → Decision: [x ] YES  [ ] NO

---



## 14. Tests

**T-01 · High · Make the suite hermetic.** Blank `ANTHROPIC_API_KEY`/`CF_AI_GATEWAY_TOKEN` in the pool bindings and mock the gateway URL with `fetchMock` from `cloudflare:test`; keep one opt-in integration file behind an env var. Today every run spends money and asserts different things depending on whether `.dev.vars` exists. Recommended: YES → Decision: [ x] YES  [ ] NO **Done 2026-09-07 (Phase 2).**

**T-02 · Medium · Remove test-owned schemas.** `db.test.ts:57-135` and `tanks-backward-compat.test.ts:22-62` DROP the migrated tables and recreate divergent ones (`salt_type`, no `nitrite`/`notes`); `db.test.ts` never calls the worker. Rely on `apply-d1-migrations.ts`. Recommended: YES → Decision: [ x] YES  [ ] NO **Done 2026-09-07 (Phase 2).**

**T-03 · Medium · Delete the no-op tests in** `security-stage2.test.ts` (bcrypt at the wrong rounds, `randomUUID`, string length) and the `receipt-crypto` test if B-33 is YES. Recommended: YES → Decision: [ x] YES  [ ] NO **Done 2026-09-07 (Phase 2).**

**T-04 · Medium · Add coverage for the routes the app actually calls and the security fixes**: `/api/livestock/`*, `/api/measurements`, `/api/tanks/:id` GET/PUT/DELETE, `/maintenance/schedules` PUT/DELETE, `/credits/purchase` with a fixture JWS (forged sandbox payload must be rejected), refund path, concurrent credit consumption. Recommended: YES → Decision: [ x] YES  [ ] NO

**T-05 · Low · Move** `devicecheck-production.test.ts` **to** `tests/e2e/` **excluded from default** `include`**; fix random-IP collisions (**`Math.random()` **in a /24 with a 10/min limit); remove unused imports; remove the phantom** `FREE_TIER_LIMIT` **binding.** Recommended: YES → Decision: [x ] YES  [ ] NO **Done 2026-09-07 (Phase 2).**

**T-06 · Low · Rewrite** `tests/README.md` (describes a "3/month" limit and "Premium Bypass" that no longer exist). Recommended: YES → Decision: [ x] YES  [ ] NO

---



## 15. Documentation

**X-01 · High · Fix** `CLAUDE.md` **and** `README.md`: model is Haiku 4.5 not "Claude 3.5 Sonnet"; deploy command; 38 iOS files not 28; regenerate the API endpoint table (`GET /tanks` does not exist; 20+ routes missing); iOS min version 17.0 not 18.0. Recommended: YES → Decision: [ x] YES  [ ] NO

**X-02 · Medium · Correct** `SECURITY_REMEDIATION_PLAN.md` **tracker**: H3 "fail-closed" is ticked but the rate limiter fails open; C3 "CORS restricted" but `*` is returned without `Origin`; M2/L2/L3 open. Then decide which open items survive (H1 prompt-injection hardening and H3 are worth it). Recommended: YES → Decision: [ x] YES  [ ] NO

**X-03 · Low · Archive to** `docs/archive/`: `REQUIREMENTS.md`, `REQUIREMENT-ANSWERS.md`, `SECURITY_AUDIT.md`, `MANUAL_TESTING_GUIDE.md`, `APP_ATTEST_IMPLEMENTATION_PLAN.md` (0% implemented; backlog), `MAINTENANCE_SCHEDULES_PLAN.md` (implemented), `PLAN.md`, `iOS/SETUP.md`, `iOS/VERIFICATION.md`. Keep `AI_GATEWAY_AUTH_SETUP.md` (accurate). Recommended: YES → Decision: [ x] YES  [ ] NO

**X-04 · Low · Website copy**: soften "Smart Alerts" (server push does not exist; only local reminders do); refresh privacy policy data inventory for schedules/water changes (still "January 2026"); verify `privacy@reefbuddy.app` / `support@reefbuddy.app` are real. Recommended: YES → Decision: [ x] YES  [ ] NO

---



## 16. Repo hygiene

**H-01 · Low · Delete**: `test.txt`, `src/test.txt` (empty), `src/verification/tiktok*.txt` (Worker serves no static files), untracked `TEST_FAILURE_REPORT.md` (fully resolved), `D1_LOCAL_VS_REMOTE_COMPARISON.md`, `CLOUDFLARE_SECURITY_BACKFILL.md` (or archive), `.cursor/` (empty), `count-tables.sh` (stale). Recommended: YES → Decision: [ x] YES  [ ] NO

**H-02 · Low ·** `web/tiktok*.txt`: commit if the TikTok developer app is still wanted, otherwise delete. Your call. **Live evidence:** the file is already served at `https://reefbuddy.aethers.com.au/tiktok….txt` (200), so it was deployed from the working tree; the repo is behind the live site. Recommended: commit. → Decision: [ x] Commit  [ ] Delete

**H-03 · Low · Fix** `.claude/` **tracking**: `.gitignore` ignores `.claude/` but four `agents/*.md` are tracked (edits show, new files won't). Add `!.claude/agents/` or `git rm --cached`. Recommended: YES (`!.claude/agents/`) → Decision: [x ] YES  [ ] NO

**H-04 · Low · Scripts**: move survivors to `scripts/`, parameterise the base URL (4 scripts hard-code the personal workers.dev host), delete `test-jws-validation.sh`/`test-iap-fix.sh` (target the deleted debug route), fix `capture-app-screenshots.sh` (bash 4 `declare -A` fails on macOS bash 3.2), version the pre-commit hook via `core.hooksPath`. Recommended: YES → Decision: [ x] YES  [ ] NO

**H-05 · Low ·** `package.json`: `"private": true`, fix `"license": "ISC"` on a proprietary app, `"author"`. Dedupe the pbxproj-protection rules (four copies across CLAUDE.md, README, iOS/README, .cursorrules) and the duplicate `StoreKit.plist`/`.storekit` pairs. Recommended: YES → Decision: [ x] YES  [ ] NO

---



## 17. Product decisions (answer these first; several items above depend on them)

**P-01 · Accounts / login.** Backend has `/auth/`*; iOS has `User.swift`, `KeychainManager`, no login UI. Options: (a) stay device-only and delete the auth code on both sides, (b) build login later and keep the code. **Live evidence:** all 117 production users are synthetic `device_…@reefbuddy.device` rows; nobody has ever signed up. → [ ] a: device-only, delete auth UI models  [ x] b: keep for a future login feature

**P-02 · Push notifications / parameter alerts.** Backend tables and routes exist, but sending is a stub and iOS never registers. Options: (a) delete `NotificationSettingsView` and the backend alert pipeline, (b) implement APNs properly (HTTP/2 + JWT, entitlements, token registration) as a feature. **Live evidence:** 0 push tokens ever registered; 378 `notification_settings` rows auto-created for 42 users; 238 `parameter_alert` history rows written that no client has ever read. → [ ] a: delete  [x ] b: implement **Resolved 2026-09-07: option (b) implement, but scheduled as a separate plan after this one ships. In this plan the view stays in the codebase, unreachable, and the backend pipeline is left untouched.**

**P-03 · Backend history/trends/averages/export routes.** Unreachable from the app today (B-18/B-19). Options: (a) fix auth+casing and use them from iOS `HistoryView`/`ExportView`, (b) keep iOS local-only and delete them. → [ x] a: fix and use  [ ] b: delete

**P-04 · Premium / Stripe remnants.** Options: (a) delete `checkPremiumAccess`, ignore Stripe columns, export stays free, (b) gate export behind a paid tier (needs product design). → [x ] a: delete  [ ] b: gate

**P-05 · AI model.** Options: (a) stay on Haiku 4.5 (`claude-haiku-4-5`), (b) move to Sonnet 5 (`claude-sonnet-5`, ~2x cost, better reasoning), (c) Opus 5 (`claude-opus-5`, ~5x). Either way the ID moves to an env var (A-02). → [ x] a: Haiku 4.5  [ ] b: Sonnet 5  [ ] c: Opus 5

**P-06 · iOS deployment target.** Project says 17.0; docs say 18.0. Options: (a) keep 17.0, (b) raise to 18.0. → [ ] a: 17.0  [ x] b: 18.0

**P-07 · JWS verification approach** (B-03). (a) X.509 chain validation in the Worker, (b) App Store Server API confirmation (needs an App Store Connect API key added as a secret). → [ x] a  [ ] b

---



## Suggested implementation order (once you've marked decisions)

1. **Stop the bleeding**: B-01, B-02, B-16, B-17, B-20, B-31, B-05/C-01 (deploy safety). Deploy.
2. **Toolchain**: D-01 → D-06 (green `tsc`, green hermetic tests T-01/T-02/T-03).
3. **Make iOS sync actually work**: B-18, B-19, I-01 → I-08, plus T-04 coverage. Ship iOS 1.0.7 with I-24 (privacy manifest), I-13/I-14, I-19/I-20, I-25/I-26.
4. **Hardening**: B-03/P-07, B-04, B-06 → B-13, A-02 → A-05, C-02 → C-06.
5. **Cleanup**: dead code (B-32 → B-35, I-35), docs (X-*), hygiene (H-*), DB (M-*).
6. **Structure**: B-36 split, B-37 UUID normalisation, I-29 → I-33 modernisation.

---



## 19. Live Cloudflare account audit (wrangler, 2026-09-07)

Read-only inspection with your logged-in wrangler session: deployments, versions, secrets, D1 (migrations, schema, row counts), KV, Pages, public endpoints. No changes were made. The wrangler OAuth token was not extracted for raw API calls, so AI Gateway settings and zone WAF rules were not inspected (see CF-09).

### What is actually running


| Item               | Live state                                                                                                                                                                                                                                                                        |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Worker             | `reefbuddy`, one script. Top-level and `--env production` show the **same deployment history**, confirming they are the same Worker (B-05/C-01).                                                                                                                                  |
| Current deployment | Version `754411bf…`, created 2026-05-06 03:02 UTC, `ENVIRONMENT=production`, compat date `2024-01-01`, 5 secrets, bindings match `wrangler.toml`.                                                                                                                                 |
| HEAD vs deployed   | Last commit `ac5abe0` is 2026-05-06 03:28 UTC, **26 minutes after** the live deploy. The live Worker may not include everything in HEAD.                                                                                                                                          |
| Bundle             | 788 KiB raw / 130 KiB gzip. Fine.                                                                                                                                                                                                                                                 |
| Secrets            | `ANTHROPIC_API_KEY`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_TEAM_ID`, `CF_AI_GATEWAY_TOKEN` present. No `RECEIPT_ENCRYPTION_KEY` (consistent with B-33).                                                                                                                     |
| D1 `reef-db`       | 815 kB, region OC, 13 tables + 4 views, all 13 migrations applied (0013/0014 on 2026-05-06). Remote columns match the migrations exactly; no drift. **0 reads / 0 writes in the last 24h.**                                                                                       |
| KV `REEF_KV`       | **0 keys.** No sessions, no rate-limit keys. Confirms no logins and negligible recent traffic.                                                                                                                                                                                    |
| Orphan KV          | `SESSIONS` and `SESSIONS_preview` namespaces exist in the account, empty, referenced by nothing in the repo.                                                                                                                                                                      |
| Pages              | `reefbuddy-web` (custom domain `reefbuddy.aethers.com.au`, deployed from `c5cc0ba`, 6 months ago) and `reefbuddy-site` (5 older deployments, no custom domain, orphan). Live HTML equals `web/index.html` plus Cloudflare's injected bot script.                                  |
| Public hosts       | `api.reefbuddy.aethers.com.au` and `reefbuddy.fredylg.workers.dev` both healthy, TLS OK, security headers present (`nosniff`, `DENY`, referrer/permissions policy). **No HSTS header.** CORS returns `*` with no `Origin` and `capacitor://localhost` for unknown origins (B-14). |
| Cron / queues / DO | None configured, none expected.                                                                                                                                                                                                                                                   |




### Real usage numbers (production D1)


| Table                                 | Rows      | Notes                                                                                                                                                  |
| ------------------------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| users                                 | 117       | **All 117 are synthetic device users.** Zero real sign-ups.                                                                                            |
| device_credits                        | 200       | 105 rows have 0 analyses and 0 purchases (probe-only device IDs). 17 devices have exhausted the free tier.                                             |
| tanks                                 | 86        | 0 soft-deleted (because delete never reaches the server, I-04).                                                                                        |
| measurements                          | 180       | Monthly: Jan 31 · Feb 50 · Mar 13 · Apr 36 · May 16 · Jun 13 · Jul 12 · Aug 7 · Sep 2. Last one 2026-09-02. 89 have nitrite, 22 have notes, 0 use PPT. |
| livestock / logs                      | 81 / 5    | All 81 `health_status = healthy`. Categories: Fish 63, Invertebrate 6, Soft 7, LPS 4, SPS 1.                                                           |
| purchase_history                      | 8         | **All 8 are Sandbox/Xcode test transactions from 17–22 Jan 2026** (5× credits5, 3× credits50, two with tx id `0`/`1`). Zero real revenue to date.      |
| sum(paid_credits)                     | 298       | Across 10 devices, all from the test purchases above.                                                                                                  |
| sum(total_analyses)                   | 212       | Lifetime analyses.                                                                                                                                     |
| maintenance_schedules / water_changes | 0 / 1     | The May feature has effectively never synced (I-02/B-19).                                                                                              |
| notification_settings / history       | 378 / 238 | 42 users' default settings auto-created; 238 `parameter_alert` rows generated server-side, never read by any client.                                   |
| push_tokens                           | 0         | Push has never been registered by any device.                                                                                                          |


**Reading:** the app has a small but real trickle of users (a handful of measurements a month, 17 devices used up their free analyses) and has never taken money. Everything users do beyond `/analyze` and credits is stored only on their phone.

### New items from the live audit

**CF-01 · High · Redeploy HEAD after the first fix batch and verify with** `/health`**.** The live Worker predates the last commit. Recommended: YES → Decision: [x ] YES  [ ] NO **Done 2026-09-07 (P1-14, version 262bcd63).**

**CF-02 · Medium · Clean up the test purchases and credits in production.** 8 sandbox rows in `purchase_history` and 298 unpaid credits on 10 devices. Options: leave as-is (they are your own test devices), or zero the sandbox-derived `paid_credits` and delete the 8 rows once B-01 is deployed. Your call. → Decision: [ x] Clean  [ ] Leave **Resolved 2026-09-07: clean, but exclude the owner's test device (ID to be supplied before the cleanup task runs).** **Done 2026-09-07 (P1-15).**

**CF-03 · Low · Prune the 105 probe-only** `device_credits` **rows** (no analyses, no purchases) after B-07 lands. Recommended: YES → Decision: [ x] YES  [ ] NO

**CF-04 · Low · Delete orphan KV namespaces** `SESSIONS` **and** `SESSIONS_preview`**.** Empty, unreferenced. Recommended: YES → Decision: [ x] YES  [ ] NO

**CF-05 · Low · Delete the orphan Pages project** `reefbuddy-site`**.** `reefbuddy-web` owns the custom domain. Recommended: YES → Decision: [ x] YES  [ ] NO

**CF-06 · Medium · Add** `Strict-Transport-Security` **to the security headers** (`src/index.ts:56-57`). Both hosts serve without HSTS today. Recommended: YES → Decision: [ x] YES  [ ] NO

**CF-07 · Low · Version the website deploy.** `reefbuddy-web` was pushed from a working tree that included the untracked TikTok file; add `npm run deploy:web` = `wrangler pages deploy web --project-name reefbuddy-web` and commit `web/tiktok*.txt` (H-02). Recommended: YES → Decision: [ x] YES  [ ] NO

**CF-08 · Low · Enable D1 Time Travel awareness / take a backup before the fix batch.** `wrangler d1 export reef-db --remote --output backups/reef-db-2026-09-07.sql` before deploying B-01/B-16/B-20 and before any CF-02/CF-03 cleanup. Recommended: YES → Decision: [ x] YES  [ ] NO

**CF-09 · Manual check (dashboard) · AI Gateway** `reefbuddy-ai-gateway`**.** Not reachable via wrangler. Please confirm in the dashboard: Authenticated Gateway is ON (the Worker sends `cf-aig-authorization`, A-06 context); caching is OFF for `/v1/messages` (each analysis is unique; a cache hit would return another tank's advice); logging retention and whether logs store request bodies (they contain user notes); rate limiting at the gateway; and the last-30-days request count and error rate to corroborate the ~2–7 analyses/month seen in D1. Report back and I fold it into the plan.
→ Checked: [x] Auth ON  [x] Cache OFF  [ ] Log bodies OFF (**it is ON**: "Collect Logs" stores request and response payloads, limit 100,000, delete oldest)  [ ] Rate limit set (**OFF**)   Confirmed from dashboard screenshots 2026-09-07. Analytics (last 30 days, checked 2026-09-07): 33 requests, 29.3k tokens, $0.07, 0 errors, 0 cached; 32 of them were the 2026-09-07 vitest run against the real gateway, so genuine app traffic was ~1 request in 30 days.

**CF-11 · Medium · AI Gateway: stop storing prompt/response payloads.** Every analysis prompt (including user free-text notes) and every model reply is retained in gateway logs, up to 100,000 entries, in addition to the Worker's own body logging (B-11). Keep logging on for metrics but disable payload collection, or set a short retention. Recommended: YES → Decision: [ ] YES  [ x] NO

**CF-12 · Medium · AI Gateway: enable Rate Limit Requests as a spend cap.** With B-01/B-04 open, the gateway is the only place that can cap Anthropic spend independent of Worker bugs. Suggest something generous relative to real usage (D1 shows single-digit analyses per day at peak), e.g. 200 requests per hour, sliding. Recommended: YES → Decision: [ ] YES  [ x] NO   Limit: ______

**CF-10 · Manual check (dashboard) · Zone** `aethers.com.au` **security for** `api.reefbuddy…`**.** WAF managed rules, a rate-limiting rule on `/credits/purchase` and `/auth/`* (defence in depth for B-07/B-12), Bot Fight Mode not blocking the native app. Not inspectable with the current token scopes. → Checked: [ ] WAF on  [ ] Rate rule present  [x ] App unaffected   Notes: ______ **Status 2026-09-07: zone is on the Free plan, so WAF managed rules are unavailable; one free rate-limiting rule is available and is planned (P7-14).**

### Items the live data changes

- **M-01** is resolved: both May migrations are applied remotely.
- **B-01** is not theoretical: production already holds sandbox-signed purchases with credits granted.
- **P-01** has a clear answer from the data: no one has ever created an account. Option (a) is safe.
- **P-02**: the server-side alert pipeline is doing work (238 alerts) nobody can see; either wire the client or stop generating rows.
- **H-02**: commit the TikTok file; it is already live.
- **I-06**: every livestock row is `healthy`, consistent with the enum mismatch blocking other values.

