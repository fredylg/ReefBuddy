# App Review 5.6 — plan of attack

Living document. Tick items as they land and add a line to the progress log at the bottom.
Owner column: **Fredy** (only you can do it: App Store Connect, Apple contact, deploy approval) or
**Claude** (code, docs, tests, drafts).

## Where we are (11 Sep 2026)

| Date | Event |
|------|-------|
| 8 Sep | 1.0.8 build 7 submitted |
| 9 Sep | Rejected, Guideline 2.3.1 ("features intentionally hidden during review") |
| 9 Sep | Cleanup shipped as 1.0.9 build 8 on `fix/app-review-2.3.1`: removed NotificationSettingsView, User.swift, "Subscription" row, `isDevelopment` field |
| 10 Sep | Replied in Resolution Center, resubmitted 1.0.9 build 8 |
| 11 Sep | Rejected again, now Guideline 5.6 Developer Code of Conduct, same "hidden features" wording |
| 11 Sep | 1.0.10 build 9 submitted with the fixes, new screenshots, notes and video |
| 12 Sep | Apple: 5.6 issue addressed; asks for a new binary to proceed |

5.6 is an escalation: Apple is saying the *pattern* looks fraudulent, not just the build. Another
rejection risks a developer-account review. So: no new build until every real difference between
"reviewer's experience" and "customer's experience" is gone, and the submission notes disclose everything.

## Root causes found (audit of the Release binary, backend and project, 11 Sep)

| # | Finding | Why it reads as "hidden" | Evidence |
|---|---------|--------------------------|----------|
| 1 | Production backend rejects Apple **Sandbox** purchase receipts (`ALLOW_SANDBOX_PURCHASES = "false"`) | App Review buys through the sandbox, so every reviewer purchase fails with "Transaction environment not accepted" while real customers can buy. This is the textbook shape of "behaves differently in review". | `wrangler.toml:39`, `src/credits/storekit.ts:426` |
| 2 | `ReefBuddy.storekit` (StoreKit *testing* configuration) ships inside the app bundle | A local IAP test harness in a production binary looks like a hidden testing mechanism. It should exist only in the Xcode scheme. | `project.pbxproj:316` (Copy Bundle Resources), Release bundle listing |
| 3 | DeviceCheck failure tells the user to "update to the latest app version" even on the latest version | If the reviewer's device does not yield a token, the headline feature is blocked behind a false reason. Misleading copy is exactly what 5.6 calls out. | `src/routes/analysis.ts:128`, `APIClient.swift:525` |
| 5 | The App Store screenshots (1.0.8 set) show Account, Notification Settings and Subscription rows | Metadata advertising features the reviewer cannot find in the app; found 11 Sep while preparing the submission. Replaced by a fresh 1.0.10 set in `docs/marketing/app-store-screenshots/`. | ASC → 1.0.8 → Previews and Screenshots, image 3 |
| 4 | Public route table at `GET /` still lists `/auth/*` and `/notifications/*` | Contradicts what we told Apple ("no accounts, no push"). Server-only, but cheap to remove and easy for a reviewer to see. | `src/index.ts:97-99, 292-322` |

Checked and clean: Release binary contains no localhost, dev hostnames, debug flags, auth strings or
notification UI. Build 8 did remove what the first rejection pointed at.

## The plan, in order

### Phase 0 — hold the line (today)

- [x] **Fredy** — Do not upload another build yet.
- [x] **Fredy** — Post reply A (below) in the Resolution Center thread and tick "request a phone call" if
      the option is offered. Paste any reply from Apple into this doc under the progress log.

### Phase 1 — fixes (Claude, branch `fix/app-review-5.6`, today)

- [x] **Claude** — Backend: accept Apple-signed `Sandbox` transactions in production; keep rejecting
      `Xcode`-signed ones. `ALLOW_SANDBOX_PURCHASES` becomes irrelevant for Sandbox and is left only for
      Xcode transactions outside production. Unit test: Production and Sandbox accepted, Xcode rejected in
      production.
- [x] **Claude** — Backend: remove `/auth/*` and `/notifications/*` from `ROUTES` (or at minimum from the
      `GET /` listing). Update the tests and the endpoint table in `CLAUDE.md`.
- [x] **Claude** — Backend: replace the "update to the latest app version" DeviceCheck message with an
      honest one ("This device could not be verified. Check your connection and try again.") and return a
      distinct code.
- [x] **Claude** — iOS: remove `ReefBuddy.storekit` from Copy Bundle Resources (keep the file and the
      scheme reference so local StoreKit testing still works). Verify with a Release build that the
      bundle no longer contains it.
- [x] **Claude** — iOS: replace the DeviceCheck error copy in `APIClient.swift` to match the server.
- [x] **Claude** — iOS: bump to **1.0.10 build 9**. `./verify-xcode-project.sh`, Release build, backend
      typecheck and tests.
- [x] **Claude** — Draft the App Review notes (text B) and the "what's new" text into this doc.

### Phase 2 — deploy and prove it (Fredy approves, Claude executes)

- [x] **Fredy** — Approve the production backend deploy (`npm run deploy`). It must be live before the
      reviewer opens the app.
- [x] **Claude** — Deploy, then confirm `GET /` no longer lists auth or notification routes and `/health`
      shows the new version.
- [x] **Fredy** — Archive 1.0.10 build 9, upload to TestFlight.
- [x] **Fredy** — On a physical iPhone signed into a **sandbox tester** account, from TestFlight: run one
      AI analysis (uses a free credit), then buy the 5-credit pack. Both must succeed. Screenshot the
      balance going 2 → 7. This is the proof the reviewer path works; TestFlight uses the same sandbox
      App Review uses.
- [x] **Fredy** — Optional but recommended: record a 60-second screen video of the app on that device
      (tank, measure, analyze, buy credits, history, livestock, maintenance) to attach or link in the
      notes.

### Phase 3 — submit

- [x] **Fredy** — Replace the screenshots: in Previews and Screenshots (iPhone tab) click **Delete All**, then
      **Choose File** and upload the nine files from `docs/marketing/app-store-screenshots/6.5-inch-1284x2778/`
      in name order. Check the iPad tab has nothing stale.
- [x] **Fredy** — In App Store Connect, set the App Review notes to text B, the "what's new" to text C,
      attach the video if made, and submit 1.0.10 build 9. Submit as a new version, not "Update Review" on
      the rejected one, so the record shows a changed binary.
- [x] **Fredy** — Post reply D in the Resolution Center thread at the same time.

### Phase 3b — Apple closed the 5.6 finding, asked for a new binary (12 Sep)

- [x] **Claude** — Bump to 1.0.10 **build 10**, no other change (commit on `fix/app-review-5.6`).
- [ ] **Fredy** — In Xcode on `fix/app-review-5.6`: Product → Archive, Distribute to App Store Connect, wait for
      TestFlight processing.
- [ ] **Fredy** — In App Store Connect, on the 1.0.10 version page: Build section → remove build 9, add
      **1.0.10 (10)**. Keep the screenshots, notes, video and What's New as they are. Add one line at the top of
      the App Review notes: "Resubmitted with build 10 at App Review's request (12 Sep). No functional
      changes from build 9." Save.
- [ ] **Fredy** — Click **Add for Review** (or **Update Review** if that is what the page shows) and submit.
- [x] ~~**Fredy** — Post reply F in the App Review thread.~~ Not possible and not needed: Apple closed the
      case when they cleared the finding, so the thread has no reply box. The submission itself carries the
      message. A new thread opens if Apple raises anything further.

### Phase 5 — after approval (12 Sep)

- [x] **Claude** — Confirm nothing is outstanding in Cloudflare: `ALLOW_SANDBOX_PURCHASES` is gone from
      `wrangler.toml`, is not a secret, and is no longer read by the code. Production vars and the five
      secrets are correct; `/health` reports 1.0.10.
- [ ] **Fredy** — Release 1.0.10 if you chose manual release.
- [x] **Claude** — Merge `fix/app-review-5.6` into `main` (fast-forward, 14 Sep). `fix/app-review-2.3.1` was
      already contained in it. Gate green on main: verify script, 0 type errors, 199 tests. Not pushed.
- [ ] **Later, not yet** — Turn off the `workers.dev` hostname (owner task 4). `reefbuddy.fredylg.workers.dev`
      still answers, and the App Store version before this release was **1.0.5**, which calls that host
      directly; the custom domain only arrived in 1.0.6. Turning it off now breaks every user who has not
      yet updated. Wait until 1.0.10 adoption is high (check App Analytics), then flip `workers_dev = true`
      to `false` in the production block of `wrangler.toml` and redeploy.

### Phase 4 — if it is rejected again

- [ ] **Fredy** — Paste the letter here. Do not resubmit.
- [ ] **Claude** — Draft the App Review Board appeal (text E skeleton below) from the facts in this doc.
- [ ] **Fredy** — File the appeal from App Store Connect (Resolution Center → "appeal").

---

## Texts for Apple

Plain, factual, no argument. Apple reads hundreds of these; short and specific gets read.

### A. Resolution Center reply (post now, before any new build)

> Thank you for the review. We want to comply fully with guideline 5.6 and are not resubmitting until we
> have addressed the cause.
>
> We have audited the 1.0.9 binary and our backend and found one behaviour that would differ for App
> Review: our server rejected purchase receipts from the App Store sandbox environment, so in-app credit
> purchases made during review would have failed while production purchases succeed. We are correcting
> this, removing a StoreKit test configuration file that was included in the bundle, and removing unused
> server endpoints, and we will resubmit with full release notes describing every feature.
>
> If there is a specific feature or behaviour the reviewer observed, we would be grateful to know which
> one so we can address it directly. We would also welcome a phone call.
>
> Fredy Lievano, ReefBuddy

### B. App Review notes for 1.0.10 (App Store Connect → App Review Information → Notes)

> ReefBuddy is a saltwater-aquarium logbook with an optional AI water-chemistry analysis. There are no
> user accounts and no login. Nothing is gated by region, date, or device beyond the credit balance
> described below. Every feature is reachable from the five tabs.
>
> HOW TO TEST
> 1. Tanks tab: tap "Add new tank", give it a name, volume and type. Select it.
> 2. Measure tab: enter any readings (e.g. alkalinity 7.4, calcium 400). Tap "Analyze parameters". An
>    AI analysis appears after a few seconds. This uses one of 3 free analyses.
> 3. Settings → Analysis Credits: shows the balance and two consumable packs (5 credits $0.99,
>    50 credits $4.99). Purchases are StoreKit 2 and are verified on our server, which accepts App Store
>    sandbox transactions, so a sandbox tester account can complete a purchase.
> 4. History tab: measurements, trend chart, CSV export.
> 5. Livestock tab: add corals/fish with photo and health log.
> 6. Settings → Maintenance Schedules: local reminders (notification permission is requested here).
>
> ANTI-ABUSE
> The app sends an Apple DeviceCheck token with each analysis so a device cannot reset its 3 free
> analyses by reinstalling. If DeviceCheck is unavailable the app shows a plain "device could not be
> verified" message; no other behaviour changes.
>
> WHAT CHANGED SINCE THE REJECTED BUILDS
> - Server now accepts App Store sandbox purchase receipts (previously rejected in production, which
>   would have made purchases fail during review).
> - Removed a StoreKit testing configuration file that was mistakenly included in the app bundle.
> - Removed unused server endpoints for accounts and push notifications; the app never had these
>   features enabled.
> - Corrected an error message that wrongly asked users to update the app.
> - Earlier (1.0.9): removed unreachable notification-settings and account code from the app.
>
> Demo video: [link, if recorded]. Contact: fredy.lievano@adaca.com

### C. "What's new" for 1.0.10

> Fixes to purchasing and error messages. Removed unused code.

### D. Resolution Center reply to accompany the submission

> We have submitted 1.0.10 (build 9). Changes: the server now accepts App Store sandbox purchase
> receipts, so in-app purchases work during review; a StoreKit test configuration file has been removed
> from the bundle; unused account and notification endpoints have been removed from the server; a
> misleading error message has been corrected. The App Review notes list every feature and how to reach
> it, and describe our use of DeviceCheck. Thank you for your patience.

### F. Resolution Center reply after Apple closed the 5.6 finding (unused — thread closed, kept for reference)

> Thank you for confirming the guideline 5.6 issue is resolved. We have submitted a new binary, 1.0.10
> (build 10), which is identical in function to build 9. The App Review notes describe every feature and
> how to reach it, and the attached video walks through the app. We have reviewed the App Review Guidelines
> and the Developer Code of Conduct.

### E. App Review Board appeal (skeleton, only if Phase 4 is reached)

> App: ReefBuddy, version 1.0.10 build 9. Rejected under 5.6 for "features intentionally hidden".
>
> We believe the finding stems from [the cause Apple names, or: our server rejecting sandbox purchase
> receipts, which made in-app purchases fail only for reviewers]. This was a configuration error, not
> concealment, and it is fixed: [evidence: TestFlight sandbox purchase screenshot dated …]. The app has
> no accounts, no remote feature flags, no region or date gating, and no code paths that detect review.
> A full feature list and test steps are in the App Review notes. We request a re-review or a specific
> description of the behaviour observed so we can correct it.

---

## Progress log

| When | Who | What |
|------|-----|------|
| 11 Sep | Claude | Audit done; four causes identified; this plan written |
| 11 Sep | Fredy | Phase 0 done: reply A posted, no new build uploaded |
| 12 Sep | Apple | "We have determined that the App Review Guideline 5.6 issue that was previously identified is addressed. In order to proceed with the review, please resubmit a new binary." |
| 14 Sep | Claude | `fix/app-review-5.6` merged into `main` (fast-forward, tip `ebc8f6b`); main is 8 commits ahead of `origin/main` and **not pushed**. |
| 12 Sep | Apple | **1.0.10 approved.** |
| 12 Sep | Claude | Post-approval check: no Cloudflare change outstanding. Flagged that workers.dev must stay on until 1.0.5 users update. |
| 12 Sep | Fredy | App Review thread no longer accepts replies (case closed by Apple); reply F dropped. |
| 12 Sep | Claude | Bumped to 1.0.10 build 10, no functional change; added Phase 3b and reply F. |
| 11 Sep | Fredy | Phase 3 done: screenshots replaced with the 1.0.10 set, notes (text B plus the TestFlight transaction line), What's New, video attached, build 1.0.10 (9) submitted via Update Review; text D (plan version) posted in the App Review thread. Waiting for Apple. |
| 11 Sep | Claude | Found the 1.0.8 App Store screenshots still show Account / Notification Settings / Subscription. Captured a nine-image 1.0.10 set on a Pro Max simulator (`docs/marketing/app-store-screenshots/`). |
| 11 Sep | Fredy | TestFlight proof on a physical iPhone (09:48–09:49 AEST): one AI analysis saved a measurement (alk 8.5, Ca 411) and consumed a credit; the 5-credit pack purchase was accepted by production (Apple transaction 2000001234618618, environment Sandbox), balance 9 → 14 paid credits. Walkthrough video recorded. |
| 11 Sep | Claude | Production deployed (version ff0dd7cd, 09:29 AEST): `/health` reports 1.0.10, `GET /` lists 28 routes with no auth or notification entries, sandbox purchases now accepted. Commit 14b9c46 bumps API_VERSION. |
| 11 Sep | Claude | Phase 1 done on `fix/app-review-5.6`: backend accepts Apple-signed Sandbox purchases in production and rejects Xcode ones; `/auth/*` and `/notifications/*` routes and their handlers removed; DeviceCheck message corrected on server and app; `ReefBuddy.storekit` out of the bundle (verified in a Release build); 1.0.10 build 9. Typecheck clean, 199 backend tests pass (tests rewritten to device actors; cross-device livestock access now asserted as 403, which is what the server returns). Docs updated. Two commits, not pushed. |
