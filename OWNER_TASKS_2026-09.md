# Your tasks to close out the September 2026 maintenance pass

Everything Claude could do on its own is done and recorded in `IMPLEMENTATION_PLAN_2026-09.md`.
The jobs below need your Apple account or a decision only you can make. Tick them off as you go.
The order that matters: 1 (review) before 4 (workers.dev off) before 6 (the follow-up build).

## 1. Ship iOS 1.0.8 (build 7) through TestFlight

Done on 8 September 2026: the TestFlight build ran on your phone, one analysis went through production
(balance 11 → 10, 63 analyses total) and the build was submitted for review the same day.

- [ ] Wait for Apple. When the app shows as Ready for Sale, tell Claude, then do 4 and 6 in that order.
- [ ] If Apple rejects it, paste the reviewer's note into the chat. The dosing card fix from section 6
      gets folded into the resubmission in that case.

- [x] Open `iOS/ReefBuddy.xcodeproj`, scheme ReefBuddy, and archive it (Product, Archive). The
      version is already 1.0.8 build 7 in the project; this one archive covers the Phase 4 sync fixes
      and the Phase 6 Swift 6 work, so the old "archive 1.0.7" task is gone.
- [x] Upload to TestFlight and install it on your phone.
- [x] Run through the app against production. The parts worth checking by hand: the tank list loads
      your existing tanks, a new measurement saves and shows in History, the chart opens, livestock and
      photos still load, a maintenance reminder fires, and one AI analysis completes. That analysis
      should take your balance from 11 credits to 10. It is the only step curl could not cover, because
      production insists on a DeviceCheck token.
- [x] Watch the first launch on your phone: the app moves your saved data out of UserDefaults into
      JSON files in Application Support. If anything looks missing after that first launch, tell Claude
      before you reinstall, because the migration only runs once.
- [x] Submit to App Store review. (Submitted 8 September 2026.)

## 2. Set up the mailboxes on aethers.com.au

You do not own reefbuddy.app, so the site, privacy policy and terms now use addresses on your own domain:
`privacy-reefbuddy@aethers.com.au`, `support-reefbuddy@aethers.com.au` and `legal-reefbuddy@aethers.com.au`.

- [x] Routing rules created 8 Sep 2026: the three addresses go to the `aethersmail-email-handler` worker,
      the same path as `fredy@aethers.com.au`.
- [ ] Send a test email to each and make sure it lands somewhere you read.
- [ ] App Store Connect, App Information: make the support URL and privacy policy URL point at
      https://reefbuddy.aethers.com.au and check the support email there matches.

## 3. Free-plan rate limiting rule in Cloudflare

Done by Claude on 8 September 2026 through the API: rule `reefbuddy-auth-purchase` on `aethers.com.au`
blocks an IP for 10 seconds after 10 requests in 10 seconds to `/credits/purchase*` or `/auth/*` on
`api.reefbuddy.aethers.com.au`. Probed from outside: requests 11 to 13 returned Cloudflare's 429 (error 1015).

- [ ] Revoke the temporary API token you created for this (My Profile, API Tokens). It was pasted in
      chat, so treat it as burned.

## 4. Turn off the workers.dev hostname once 1.0.8 is live

Older app builds call `reefbuddy.fredylg.workers.dev` directly, so this has to wait until 1.0.8 is
the version people actually have installed.

- [ ] In `wrangler.toml`, change the production `workers_dev = true` (near the top of the file) to
      `false`. Leave the one under `[env.dev]` alone so `reefbuddy-dev` stays reachable.
- [ ] Run `npm run deploy` (or ask Claude). The `/health` version fix already shipped on 8 September.
- [ ] Check that `https://api.reefbuddy.aethers.com.au/health` still answers and the workers.dev
      address no longer does.

## 5. Branches merged

Done 8 September 2026: `main` was fast-forwarded to the maintenance work, tagged `1.0.8` and pushed.
The `maint/*` branches can be deleted whenever you like; they are all contained in `main`.

- [ ] Run `./scripts/setup-hooks.sh` once on each clone so the pre-commit check on the Xcode project
      file keeps running from the new `.githooks/` location.

## 6. Follow-up build 1.0.9 (build 8), after the release is live

A user screenshot on 8 September showed the dosing card printing a whole sentence at 28 point in
aquamarine. Two fixes went in the same day:

- Backend (already deployed, version `cb97ba87`): the model is now asked for the dose and the cadence
  as short phrases, with the explanation in the reason field. The build under review benefits from this
  without an update.
- iOS (commit 8048bf0, on `main`, not yet in any build): the card itself now handles long text, black on
  white, so a stray long answer can never look like that again.

There is no need to resubmit now; pulling the build would restart the review queue. Once 1.0.8 is
live and section 4 is done:

- [ ] Tell Claude to bump the app to 1.0.9 build 8 and archive it, the same way as build 7.
- [ ] Upload with Transporter or Xcode, run it once on your phone, submit. No hurry on this one.

## Later, when you feel like it

Push notifications were deferred on purpose. The unreachable settings screen and the unused
account models were removed from the app in 1.0.9 (App Review 2.3.1, September 2026); the backend
alert and account routes are untouched. Ask Claude for `PUSH_NOTIFICATIONS_PLAN.md`
when you want to pick that up. The suggested next maintenance window is December 2026; the checklist
for it is at the end of `docs/maintenance/2026-09-handover.md`.
