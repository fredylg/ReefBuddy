# Promo recording kit

Reproducible screen recordings of the ReefBuddy iOS app for the Instagram story series described in
`docs/marketing/INSTAGRAM_STORIES.md`. Nothing here ships in the app or touches the Xcode project.

## What it does
1. Builds the Debug app for an iPhone 17 Pro simulator and installs it.
2. Starts the local Worker with `wrangler dev --env dev --host localhost`. The `--host` flag matters:
   without it wrangler reports the production hostname to the Worker and the simulator DeviceCheck
   bypass in `/analyze` never fires (see `src/routes/analysis.ts`).
3. Seeds two tanks with six months of measurements and water changes through the local API (the
   server wins on fetch), and writes livestock, photos, health logs, saved analyses and maintenance
   schedules straight into the app's Application Support folder (`seed.py`).
4. Generates a throwaway XCUITest project with xcodegen (`uitest/`) that drives the app by bundle id.
   One test per story (`Stories.swift`); each writes start/end marks so the recording is trimmed.
5. Records with `simctl io recordVideo`, trims with ffmpeg, and also renders a 1080x1920 story
   canvas with the phone centred on white.

## Requirements
Xcode 26, `brew install xcodegen ffmpeg`, `.dev.vars` with a working `ANTHROPIC_API_KEY` (two stories run a live analysis).

## Use
```bash
tools/promo-recording/setup.sh                       # once (~5 min)
tools/promo-recording/run.sh testS05TrendCharts       # dry-run one story
tools/promo-recording/run.sh testS05TrendCharts record
tools/promo-recording/record-all.sh                   # all 14 (~25 min)
```
Output lands in `~/ReefBuddy-Promo/out/` (override with `PROMO_WORK`). `reset.sh` restores the seeded
state before every take, so retakes are cheap and the three free analysis credits are refilled.

## Gotchas learned while building this
- SwiftUI's keyboard-avoidance scroll is not reflected in the accessibility frames XCUITest uses, so
  taps on fields below the keyboard land in the wrong place. `typeParam` nudges the scroll view by hand
  first, which refreshes the frames.
- A `TextField` that has text no longer exposes its placeholder; paired fields (ammonia/nitrite) are
  resolved by column instead.
- Debug builds show the header subtitle in green when not pointed at production. It is in every clip.
- Livestock photos are from Wikimedia Commons under CC BY / CC BY-SA / public domain; see
  `photos/CREDITS.md` before publishing anything that shows them.
