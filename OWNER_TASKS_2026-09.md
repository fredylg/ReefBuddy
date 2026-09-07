# Your tasks to close out the September 2026 maintenance pass

Everything Claude could do on its own is done and recorded in `IMPLEMENTATION_PLAN_2026-09.md`.
The five jobs below need your Apple account, your Cloudflare dashboard login or a decision only you
can make. Tick them off as you go; none of them is urgent enough to do out of order, but 1 should
happen before 4.

## 1. Ship iOS 1.0.8 (build 7) through TestFlight

- [ ] Open `iOS/ReefBuddy.xcodeproj`, scheme ReefBuddy, and archive it (Product, Archive). The
      version is already 1.0.8 build 7 in the project; this one archive covers the Phase 4 sync fixes
      and the Phase 6 Swift 6 work, so the old "archive 1.0.7" task is gone.
- [ ] Upload to TestFlight and install it on your phone.
- [ ] Run through the app against production. The parts worth checking by hand: the tank list loads
      your existing tanks, a new measurement saves and shows in History, the chart opens, livestock and
      photos still load, a maintenance reminder fires, and one AI analysis completes. That analysis
      should take your balance from 11 credits to 10. It is the only step curl could not cover, because
      production insists on a DeviceCheck token.
- [ ] Watch the first launch on your phone: the app moves your saved data out of UserDefaults into
      JSON files in Application Support. If anything looks missing after that first launch, tell Claude
      before you reinstall, because the migration only runs once.
- [ ] Submit to App Store review.

## 2. Confirm the two mailboxes exist

The website, privacy policy and terms point at `privacy@reefbuddy.app` and `support@reefbuddy.app`.

- [ ] Send a test email to each and make sure it lands somewhere you read.
- [ ] If either does not exist, either create it or tell Claude which address to put on the site instead.

## 3. Add the free-plan rate limiting rule in Cloudflare

The zone is on the Free plan, so there is no WAF, but one rate limiting rule is allowed. It protects
the two endpoints that matter most against brute force and purchase spam.

- [ ] Cloudflare dashboard, zone `aethers.com.au`, Security, WAF, Rate limiting rules, Create rule.
- [ ] Name it `reefbuddy-auth-purchase`.
- [ ] Use the custom expression editor and paste:

```
(http.host eq "api.reefbuddy.aethers.com.au" and (starts_with(http.request.uri.path, "/credits/purchase") or starts_with(http.request.uri.path, "/auth/")))
```

- [ ] Characteristics: IP. Rate: 10 requests per 10 seconds. Action: Block, for 10 seconds.
- [ ] Tell Claude once it is saved and it will probe the rule from outside.

## 4. Turn off the workers.dev hostname once 1.0.8 is live

Older app builds call `reefbuddy.fredylg.workers.dev` directly, so this has to wait until 1.0.8 is
the version people actually have installed.

- [ ] In `wrangler.toml`, change the production `workers_dev = true` (near the top of the file) to
      `false`. Leave the one under `[env.dev]` alone so `reefbuddy-dev` stays reachable.
- [ ] Run `npm run deploy`. That also ships the small fix that makes `/health` report 1.0.8 instead
      of 1.0.6.
- [ ] Check that `https://api.reefbuddy.aethers.com.au/health` still answers and the workers.dev
      address no longer does.

## 5. Decide how the branches get merged

Nothing has been pushed or merged. The work sits on `maint/p1-hotfix`, `maint/p2-toolchain`,
`maint/p3-hardening`, `maint/p4-ios`, `maint/p5-structure`, `maint/p6-ios` and `maint/p7-hygiene`,
41 commits ahead of `main`, each branch building on the previous one.

- [ ] Choose: one merge commit per phase (keeps the phase history readable) or a single squash onto
      `main` (one commit, simpler log). Tell Claude and it will do the merge and the push.
- [ ] After the merge, run `./scripts/setup-hooks.sh` once on each clone so the pre-commit check on
      the Xcode project file keeps running from the new `.githooks/` location.

## Later, when you feel like it

Push notifications were deferred on purpose. The settings screen is still in the code but
unreachable, and the backend alert pipeline is untouched. Ask Claude for `PUSH_NOTIFICATIONS_PLAN.md`
when you want to pick that up. The suggested next maintenance window is December 2026; the checklist
for it is at the end of `docs/maintenance/2026-09-handover.md`.
