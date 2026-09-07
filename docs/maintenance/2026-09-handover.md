# ReefBuddy maintenance pass — September 2026 handover

Companion to `MAINTENANCE_REVIEW_2026-09.md` (findings and decisions) and
`IMPLEMENTATION_PLAN_2026-09.md` (task tracking and dated progress log). Status on 2026-09-07:
Phases 0–6 complete, Phase 7 waiting on two Cloudflare deletions, Phase 8 waiting on the final deploy.

## What changed

**Backend (Cloudflare Worker `reefbuddy`, live version `e667dee4…`)**
- Toolchain: wrangler 4.129, Vitest 4.1 with `@cloudflare/vitest-plugin`, TypeScript 6, jose 6,
  bcryptjs 3, zod 4.5; `npm audit` clean; Prettier.
- Security: StoreKit 2 JWS verified by signature **and** x5c chain to the pinned Apple Root CA G3
  (Xcode-signed only outside production); DeviceCheck two-bit free tier; credits consumed with a
  conditional update (no negative balances); refunds work; CORS allow-list only; HSTS and
  `X-Request-Id` on every response; generic error bodies; no tokens/bodies in logs; `/analyze`
  limiter fails closed on KV outage (not yet deployed — see below).
- API: table-driven router in `src/index.ts`, every app route accepts session **or** `X-Device-ID`,
  uppercase UUIDs accepted, legacy duplicate routes removed, nitrite end to end, livestock enums match
  the app (migration 0016), duplicate indexes dropped (0015).
- Structure: `src/index.ts` split into `env`, `http`, `schemas`, `ai/`, `auth/`, `credits/`, `routes/`.
- Data: sandbox purchase rows and 39 probe-only device rows removed from production; the owner device
  `8B629A9B-9907-4D5B-80F9-DC18E3FF3587` keeps its 11 credits. Backup: `backups/reef-db-2026-09-07.sql`
  (git-ignored).

**iOS (1.0.8 build 7, iOS 18.0+, Swift 6)**
- Sync actually works: tolerant date decoding (`APIDates`), typed `APIError`, lowercase ids,
  unified livestock DTOs, Keychain-backed `DeviceIdentity`, merge/cascade handling in `AppState`.
- Notifications: delegate installed at launch, cold-start taps buffered, anchor-based interval
  reminders, `PrivacyInfo.xcprivacy`, encryption-exemption key.
- Modernisation: strict concurrency clean, Swift 6 language mode, `@Observable` stores, JSON documents
  in Application Support (`JSONFileStore`, automatic one-time migration from UserDefaults), Swift
  Charts, dead views removed, `foregroundStyle`/`topBar*` sweep.

**Repo**
- Docs regenerated (`CLAUDE.md`, `README.md`, `migrations/README.md`, `tests/README.md`,
  `iOS/README.md`); stale plans in `docs/archive/`; helper scripts in `scripts/`; versioned
  pre-commit hook (`./scripts/setup-hooks.sh`); `npm run lint:migrations` guards hard deletes.

## How to deploy

```bash
npm run deploy             # typecheck → lint:migrations → 243 tests → wrangler deploy (production)
npm run db:migrate:remote  # only when a new migrations/00xx_*.sql exists
npm run deploy:web         # website (Pages project reefbuddy-web)
```
iOS: Xcode → Product → Archive (scheme ReefBuddy) → TestFlight → App Store. After the release is
live, set `workers_dev = false` in `wrangler.toml` so only `api.reefbuddy.aethers.com.au` serves traffic.

## Open on 2026-09-07

| Item | Owner | Detail |
|---|---|---|
| Deploy the H3 fail-closed limiter | Claude, needs go-ahead | `npm run deploy`, then P8-03 smoke (spends one owner credit) |
| P7-12 delete KV `SESSIONS`, `SESSIONS_preview` | Claude, needs go-ahead | ids in the plan; not bound anywhere |
| P7-13 delete Pages `reefbuddy-site`; delete probe row `8b629a9b…` (lowercase) | Claude, needs go-ahead | live site is `reefbuddy-web` |
| TestFlight 1.0.8 build 7, device test, App Store | you | covers Phases 4 and 6 |
| Confirm `privacy@` / `support@reefbuddy.app` mailboxes | you | policy and site reference them |
| Free-plan WAF rate rule on `aethers.com.au` | you | expression in plan task P7-14 |

## Deferred (Phase 9)
Push notifications (separate plan when asked; `NotificationSettingsView` unreachable until then),
AI Gateway BYOK / payload-logging / gateway rate limit (declined), bcrypt rounds (login not shipped).

## Next maintenance window (suggested: December 2026)
- Bump `compatibility_date`, wrangler, vitest plugin, TypeScript; re-run `npm audit`.
- Re-run `wrangler types` and the full gate; check Apple Root CA G3 pin and the WWDR intermediate.
- Xcode 26.x / iOS 19 SDK deprecation sweep; re-verify the simulator regression list in P4-27.
- Review AI Gateway analytics for cost and error rate; consider CF-12 if traffic grows.
