# ReefBuddy — Instagram Stories Feature Series

Promotional Instagram Stories, one feature per story. Each script is written for a 15-second
card (Instagram's story limit); a few are marked as 2-card stories (30 s). Scripts describe
what appears on screen, the caption text overlay, and an optional voiceover (VO) line.

Everything below reflects what ships in 1.0.9. Record from the 1.0.9 build so nothing appears
in a story that isn't reachable in the App Store version.

---

## Production notes (apply to every story)

| Item | Guideline |
|------|-----------|
| Format | 1080 × 1920 (9:16), 30 fps, exported H.264 |
| Safe zones | Keep text out of the top 250 px and bottom 340 px (Instagram UI overlays) |
| Sound | Assume muted playback. Every VO line must also appear as an on-screen caption |
| Brand look | White `#FFFFFF` background, black `#000000` text in a heavy sans (e.g. Archivo Black / Inter Black), Electric Aquamarine `#00FFD1` for the action word, Safety Orange `#FF3D00` for warnings. Hard 3–4 pt black borders, zero corner radius, 5 pt hard offset shadows, no blur, no gradients |
| Captions | ALL CAPS, short. Max 6 words per caption line |
| Phone capture | iPhone screen recording (Settings → Control Centre → Screen Recording). Use a demo tank with 6–8 weeks of realistic data so charts have shape. Hide the status bar clutter: full battery, Wi-Fi, no notifications |
| Transitions | Hard cuts only. No dissolves, no zooms. Brutalist = abrupt |
| Music | Punchy, percussive, royalty-free. Cut captions on the beat |
| CTA | Every story ends with the "GET THE APP" link sticker to the App Store page |
| Sticker | Use a "Link" sticker for the App Store, a "Poll" or "Question" sticker on 2–3 stories to boost engagement |

Demo data suggestions: a 90-gallon mixed reef named **"Display Tank"**, a 20-gallon nano
named **"Frag Tank"**, a dozen livestock entries with photos, two maintenance schedules.

---

## Feature list

| # | Feature | Story hook |
|---|---------|-----------|
| 1 | Log 10 water parameters in seconds | "Test kit → app in 30 seconds" |
| 2 | Instant in-range indicators | "Know if it's wrong before you hit save" |
| 3 | AI analysis with dosing advice | "Your reef, analysed" |
| 4 | Warnings surfaced first | "The stuff that kills corals, flagged" |
| 5 | Trend charts with optimal range band | "See the drift before the crash" |
| 6 | Measurement history + CSV export | "Your data. Yours to keep" |
| 7 | Maintenance reminders | "Never forget a water change again" |
| 8 | Water change logging | "Log it in two taps" |
| 9 | Livestock catalogue | "Every coral. Every fish. One place" |
| 10 | Health log timeline | "Track recovery, not just losses" |
| 11 | Multiple tanks, 7 tank types | "Nano, SPS, FOWLR. All of them" |
| 12 | Saved analyses | "What did it say last month?" |
| 13 | 3 free analyses, credits never expire | "Free to start. No subscription" |
| 14 | New Brutalist design | "An aquarium app that isn't beige" |

Suggested posting order: 13 → 1 → 2 → 3 → 4 → 5 → 7 → 8 → 9 → 10 → 6 → 11 → 12 → 14.
Lead with price so nobody bounces later, then the core loop (log → analyse), then the tracking features.

---

## Story scripts

### 1. Log 10 water parameters in seconds

**Length:** 15 s · **Screens:** Tank list → Measurement Entry

| Time | On screen | Caption | VO |
|------|-----------|---------|----|
| 0–2 s | Close-up B-roll: a test kit vial being held against a colour card | **STILL WRITING THESE DOWN?** | "Still scribbling test results in a notebook?" |
| 2–4 s | Hard cut. App icon on white, then tap into "Display Tank" | **REEFBUDDY** | |
| 4–11 s | Screen recording, sped up 2×: tapping through Temperature, Salinity, pH, Alkalinity, Calcium, Magnesium, Nitrate, Phosphate, Ammonia, Nitrite. Each field fills | **10 PARAMETERS** → **ONE SCREEN** | "Ten parameters. One screen. Thirty seconds." |
| 11–13 s | Finger hovers over the aquamarine **ANALYZE PARAMETERS** button, doesn't press it | **THEN THE FUN PART…** | "And then…" |
| 13–15 s | End card: white, black border box, "GET THE APP" + link sticker | **GET THE APP** | |

Capture note: keep the field list scrolling smoothly. Pre-fill nothing; the point is speed of entry.

---

### 2. Instant in-range indicators

**Length:** 15 s · **Screens:** Measurement Entry

| Time | On screen | Caption | VO |
|------|-----------|---------|----|
| 0–3 s | Screen recording: type `7.2` into Alkalinity. The field's target hint "Target: 8.0–12.0 dKH" is visible | **ALK 7.2** | "Is 7.2 dKH okay?" |
| 3–6 s | Zoom crop (post-production) on the target range hint and the field border | **YOU DON'T NEED TO GOOGLE IT** | "You don't need to Google it." |
| 6–10 s | Type `1350` into Magnesium, then `8.3` into pH. Show each target hint | **EVERY FIELD SHOWS ITS TARGET** | "Every field shows the healthy range as you type." |
| 10–13 s | Tap the °C / °F toggle, then the SG / ppt toggle | **YOUR UNITS. YOUR CHOICE.** | "Celsius or Fahrenheit. SG or ppt. Your call." |
| 13–15 s | End card | **GET THE APP** | |

Sticker idea: Poll — "How do you measure salinity?" SG / ppt.

---

### 3. AI analysis with dosing advice

**Length:** 2 cards, 30 s · **Screens:** Measurement Entry → AI Analysis result

**Card A (0–15 s)**

| Time | On screen | Caption | VO |
|------|-----------|---------|----|
| 0–3 s | Filled measurement form. Finger presses **ANALYZE PARAMETERS** | **TAP.** | "One tap." |
| 3–7 s | Brutalist loading view (the black-bordered loader) | **THINKING…** | "ReefBuddy reads your numbers in context: tank size, tank type, your history." |
| 7–12 s | Result appears. "AI ANALYSIS — COMPLETE" header, then the SUMMARY block | **AI ANALYSIS · COMPLETE** | "And gives you a plain-English summary." |
| 12–15 s | Slow scroll down to the RECOMMENDATIONS heading | **SWIPE FOR THE ADVICE →** | |

**Card B (15–30 s)**

| Time | On screen | Caption | VO |
|------|-----------|---------|----|
| 0–5 s | RECOMMENDATIONS list, scrolling slowly. Highlight one line with a hand-drawn aquamarine underline (post) | **SPECIFIC. NOT "ADD SOME BUFFER".** | "Specific recommendations, not 'add some buffer'." |
| 5–10 s | DOSING ADVICE section. Freeze frame on a dosing amount for the 90-gallon demo tank | **DOSING FOR YOUR VOLUME** | "Dosing worked out for your tank's volume." |
| 10–13 s | Scroll to the disclaimer line at the bottom | **ALWAYS TEST TWICE** | "Always test twice. Always." |
| 13–15 s | End card | **3 FREE ANALYSES · GET THE APP** | |

Capture note: run the analysis on realistic slightly-off numbers (low alk, low calcium) so the recommendations are concrete. Read the output before recording; don't screen-record a bland "everything looks fine" response.

---

### 4. Warnings surfaced first

**Length:** 15 s · **Screens:** AI Analysis result (WARNINGS section)

| Time | On screen | Caption | VO |
|------|-----------|---------|----|
| 0–3 s | Black screen, orange text | **AMMONIA 0.5 PPM** | "Ammonia at 0.5." |
| 3–6 s | Hard cut to the analysis result. WARNINGS box with the orange "!" badge and count | **WARNINGS · 2** | "ReefBuddy puts the dangerous stuff at the top." |
| 6–11 s | Scroll the warning lines. Orange highlight on the ammonia warning | **BEFORE YOU LOSE A FISH** | "So you act before you lose a fish, not after." |
| 11–13 s | Cut to the same tank a week later: WARNINGS gone, only RECOMMENDATIONS shown | **ONE WEEK LATER** | "One week later." |
| 13–15 s | End card | **GET THE APP** | |

Capture note: this story uses Safety Orange heavily. Keep the rest of the palette strictly black and white so the orange lands.

---

### 5. Trend charts with optimal range band

**Length:** 15 s · **Screens:** History → Trend Chart

| Time | On screen | Caption | VO |
|------|-----------|---------|----|
| 0–3 s | B-roll: a browning SPS frag (stock footage or your own) | **IT DIDN'T HAPPEN OVERNIGHT.** | "Corals don't crash overnight." |
| 3–7 s | Screen recording: History tab, TREND CHART for Alkalinity over 90 days. The shaded optimal range band is visible, the line drifts below it | **SEE THE DRIFT** | "They drift. ReefBuddy shows you the drift." |
| 7–11 s | Switch the parameter picker: Alkalinity → Calcium → Magnesium. Each chart redraws with its own optimal band | **EVERY PARAMETER · ITS OWN RANGE** | "Every parameter, charted against its healthy range." |
| 11–13 s | Switch time range picker to a shorter window | **7 DAYS TO 1 YEAR** | "From a week to a year." |
| 13–15 s | End card | **GET THE APP** | |

Capture note: the demo tank needs a deliberate downward alkalinity trend across ~6 weeks for this to read. Seed it before recording.

---

### 6. Measurement history + CSV export

**Length:** 15 s · **Screens:** History (MEASUREMENTS list) → Export

| Time | On screen | Caption | VO |
|------|-----------|---------|----|
| 0–3 s | History screen, MEASUREMENTS list scrolling | **EVERY TEST YOU'VE EVER LOGGED** | "Every test you've ever logged." |
| 3–6 s | Tap **EXPORT** | **YOUR DATA. YOURS.** | "And it's yours." |
| 6–10 s | Export screen: DATE RANGE pickers, then the CSV PREVIEW with "142 RECORDS" | **PICK A RANGE · PREVIEW IT** | "Pick a date range, preview it…" |
| 10–13 s | Tap **EXPORT CSV**, iOS share sheet slides up, tap Numbers / Mail | **CSV → ANYWHERE** | "…and send a CSV anywhere. Spreadsheet, email, your LFS." |
| 13–15 s | End card | **GET THE APP** | |

Sticker idea: Question — "What would you do with your tank's data?"

---

### 7. Maintenance reminders

**Length:** 15 s · **Screens:** Maintenance Schedules → Editor → lock-screen notification

| Time | On screen | Caption | VO |
|------|-----------|---------|----|
| 0–3 s | B-roll: a calendar with nothing written on it, or a dusty bucket | **WHEN WAS YOUR LAST WATER CHANGE?** | "When was your last water change? …Exactly." |
| 3–7 s | Screen recording: MAINTENANCE SCHEDULES, tap +, choose WATER CHANGE | **WATER CHANGE · FILTER · TESTING** | "Water changes, filter service, testing." |
| 7–10 s | Editor: toggle between "Every N days" and "Weekly", pick Sunday, set 9:00 AM | **EVERY 14 DAYS · OR EVERY SUNDAY** | "Every two weeks, or every Sunday at 9." |
| 10–13 s | Cut to the home screen. Notification banner: "WATER CHANGE · Display Tank · Time for your 15% water change (13.5 gal)" | **YOUR PHONE REMINDS YOU** | "Your phone reminds you." |
| 13–15 s | End card | **GET THE APP** | |

Capture note: the banner in the recorded clip is a real notification delivered to the simulator. For a lock-screen version, set a schedule 2 minutes ahead on a physical phone and film the lock screen.

---

### 8. Water change logging

**Length:** 15 s · **Screens:** Measurement Entry → Log Water Change

| Time | On screen | Caption | VO |
|------|-----------|---------|----|
| 0–3 s | B-roll: pouring new saltwater into a tank | **20% DONE.** | "Twenty percent. Done." |
| 3–6 s | Screen recording: Measurement Entry, tap **LOG WATER CHANGE** | **NOW LOG IT** | "Now log it." |
| 6–10 s | Water change sheet: enter 20%, gallons auto-shown for the 90-gal tank, add a note "new salt batch" | **PERCENT OR GALLONS** | "Percent or gallons, plus a note." |
| 10–13 s | Save. Cut to the trend chart where the water change lines up with a parameter bump | **SEE WHAT IT DID** | "Then see what it actually did to your numbers." |
| 13–15 s | End card | **GET THE APP** | |

---

### 9. Livestock catalogue

**Length:** 15 s · **Screens:** Livestock List → Add Livestock → Detail

| Time | On screen | Caption | VO |
|------|-----------|---------|----|
| 0–3 s | Fast montage of 4 real coral/fish photos (0.7 s each) | **HOW MANY FRAGS DO YOU OWN?** | "How many frags do you actually own?" |
| 3–7 s | Screen recording: Livestock list scrolling, mix of photos and category icons | **EVERY CORAL. EVERY FISH.** | "Catalogue every coral, fish and invert." |
| 7–10 s | Add Livestock: category picker showing SPS · LPS · SOFT CORAL · FISH · INVERTEBRATE · ANEMONE | **7 CATEGORIES** | "Seven categories." |
| 10–13 s | Detail view: large photo, SPECIES INFO, PURCHASE INFO with price and date | **PHOTO · SPECIES · WHAT YOU PAID** | "Photo, species, and what you paid. Don't show your partner that last one." |
| 13–15 s | End card | **GET THE APP** | |

Sticker idea: Poll — "SPS or LPS?"

---

### 10. Health log timeline

**Length:** 15 s · **Screens:** Livestock Detail → HEALTH STATUS → LOG

| Time | On screen | Caption | VO |
|------|-----------|---------|----|
| 0–3 s | Photo of a stressed-looking coral (retracted polyps) | **IT LOOKS OFF.** | "It looks off." |
| 3–6 s | Screen recording: Livestock Detail, HEALTH STATUS shows THRIVING, tap **LOG**, change to STRESSED | **THRIVING → STRESSED** | "Log it." |
| 6–10 s | Add a note "polyps retracted after light change", save | **WRITE DOWN WHAT CHANGED** | "Write down what changed." |
| 10–13 s | HEALTH LOG TIMELINE with 5 entries, status moving Stressed → Healthy → Thriving over weeks | **WATCH IT RECOVER** | "Then watch the recovery, entry by entry." |
| 13–15 s | End card | **GET THE APP** | |

Capture note: the six health states are Thriving, Healthy, Stressed, Declining, Critical, Deceased. Show the recovery direction, not the decline.

---

### 11. Multiple tanks, 7 tank types

**Length:** 15 s · **Screens:** Tank List → New Tank

| Time | On screen | Caption | VO |
|------|-----------|---------|----|
| 0–3 s | Tank list with two tanks: "Display Tank · 90 gal · Mixed Reef", "Frag Tank · 20 gal · Nano" | **ONE TANK IS NEVER ENOUGH** | "One tank is never enough." |
| 3–8 s | Tap +. Tank type picker scrolling: Fish Only, FOWLR, Soft Coral, LPS, SPS, Mixed Reef, Nano | **7 TANK TYPES** | "Seven tank types, because a FOWLR and an SPS tank don't want the same numbers." |
| 8–12 s | Enter volume, name "QT", save. Back to list with three tanks | **EACH WITH ITS OWN HISTORY** | "Each with its own history, livestock and reminders." |
| 12–15 s | End card | **GET THE APP** | |

---

### 12. Saved analyses

**Length:** 15 s · **Screens:** Saved Analyses → Analysis detail → Share

| Time | On screen | Caption | VO |
|------|-----------|---------|----|
| 0–3 s | Saved Analyses list, dated entries per tank | **EVERY ANALYSIS. SAVED.** | "Every analysis, saved." |
| 3–7 s | Open one from six weeks ago, scroll the recommendations | **WHAT DID IT SAY LAST MONTH?** | "What did it say last month? Check." |
| 7–11 s | Tap the DISPLAY TANK filter, scroll the list of dated analyses with their warning badges | **FILTER BY TANK** | "Filter by tank. Spot the months that had warnings." |
| 11–15 s | End card | **GET THE APP** | |

Note: sharing is on the analysis result screen (the share icon top-right, story 3), not on saved analyses. The "send it to your reef club" line belongs in story 3 if you want it.

---

### 13. 3 free analyses, credits never expire

**Length:** 15 s · **Screens:** Credits / Purchase view

| Time | On screen | Caption | VO |
|------|-----------|---------|----|
| 0–3 s | Black screen, giant white text | **NO SUBSCRIPTION.** | "No subscription." |
| 3–6 s | White screen, black text | **3 FREE AI ANALYSES** | "Three AI analyses free. Everything else is free forever: logging, charts, livestock, reminders." |
| 6–10 s | Screen recording: Purchase Credits view showing the 5-credit and 50-credit packs | **5 FOR $0.99 · 50 FOR $4.99** | "Need more? Five for ninety-nine cents. Fifty for $4.99." |
| 10–13 s | Text card | **CREDITS NEVER EXPIRE** | "They never expire. Use them at your own pace." |
| 13–15 s | End card | **DOWNLOAD FREE** | |

Note: confirm the localised App Store prices before publishing; the USD figures above come from the website.

---

### 14. New Brutalist design

**Length:** 15 s · **Screens:** montage

| Time | On screen | Caption | VO |
|------|-----------|---------|----|
| 0–3 s | Blurry, beige, generic aquarium app UI (mock it up, no real competitor) | **AQUARIUM APPS LOOK LIKE THIS.** | "Most aquarium apps look like this." |
| 3–5 s | Hard cut to ReefBuddy tank list. Full contrast | **OURS DOESN'T.** | "Ours doesn't." |
| 5–12 s | Rapid montage on the beat, ~1 s each: measurement entry, analysis result with orange warning, trend chart, livestock grid, maintenance list, export preview, purchase view | **BLACK. WHITE. AQUAMARINE.** | "Black. White. Aquamarine. Zero rounded corners. Built to be read at arm's length with wet hands." |
| 12–15 s | End card with the app icon | **REEFBUDDY · GET THE APP** | |

---

## Reusable end card spec

- White background, single black box with a 4 pt border and 5 pt hard black shadow, centred.
- Inside: **GET THE APP** in black; the word **APP** in Electric Aquamarine.
- App icon above the box, 200 px, no shadow.
- Link sticker placed directly below the box, inside the bottom safe zone.
- Hold for 2 seconds minimum.

## Checklist before publishing a story

- [ ] Recorded from the 1.0.9 build (nothing shown that App Review can't reach)
- [ ] Captions inside safe zones, readable without sound
- [ ] No personal data on screen (real device name, notification previews from other apps)
- [ ] Prices match the App Store listing for the target region
- [ ] AI disclaimer ("Always test twice") visible somewhere in the analysis stories (3 and 4)
- [ ] Link sticker points at the live App Store URL

---

## Recorded clips

Screen recordings of every story were captured from the 1.0.9 Debug build on an iPhone 17 Pro
simulator, driven by the scripted UI tests in `tools/promo-recording/` against a seeded demo data set
(two tanks, six months of tests, 16 livestock entries with photos, 7 saved analyses, 3 schedules).

Location: `docs/marketing/stories/phone/` and `docs/marketing/stories/story-canvas/` (git-ignored, ~80 MB).

| Story | Phone clip (1206×2622) | Story canvas (1080×1920, white pad) |
|-------|------------------------|--------------------------------------|
| 1 | `testS01LogParameters.mp4` | `testS01LogParameters_story.mp4` |
| 2 | `testS02TargetHints.mp4` | `testS02TargetHints_story.mp4` |
| 3 | `testS03AIAnalysis.mp4` (single take, split into two cards) | `testS03AIAnalysis_story.mp4` |
| 4 | `testS04Warnings.mp4` | `testS04Warnings_story.mp4` |
| 5 | `testS05TrendCharts.mp4` | `testS05TrendCharts_story.mp4` |
| 6 | `testS06Export.mp4` | `testS06Export_story.mp4` |
| 7 | `testS07Reminders.mp4` (ends on the home-screen banner) | `testS07Reminders_story.mp4` |
| 8 | `testS08WaterChange.mp4` | `testS08WaterChange_story.mp4` |
| 9 | `testS09Livestock.mp4` | `testS09Livestock_story.mp4` |
| 10 | `testS10HealthLog.mp4` | `testS10HealthLog_story.mp4` |
| 11 | `testS11Tanks.mp4` | `testS11Tanks_story.mp4` |
| 12 | `testS12SavedAnalyses.mp4` | `testS12SavedAnalyses_story.mp4` |
| 13 | `testS13Credits.mp4` | `testS13Credits_story.mp4` |
| 14 | `testS14Montage.mp4` (raw tab tour, cut to the beat) | `testS14Montage_story.mp4` |

What the clips do not contain, by design: captions, voiceover, music, B-roll and end cards. Add
those in your editor over the story canvas versions; the phone occupies the middle 883 px, leaving
white columns either side for text.

Known blemishes in the raw clips:
- The header subtitle ("Manage your aquariums" etc.) is green. Debug builds colour it green when the
  app talks to a non-production backend. Crop or cover it, or re-record from a Release build once
  a production DeviceCheck-capable device is available.
- Clips are real-time. Speed the form-filling in story 1 up 2× in the edit as the script suggests.
- The AI text in stories 3 and 4 is a live model response and differs slightly on every take.
- Livestock photos are Wikimedia Commons images under CC BY / CC BY-SA / public domain
  (`tools/promo-recording/photos/CREDITS.md`). Attribute them or swap in your own tank photos
  (re-run the seed with your JPEGs) before publishing.

---

## Social cuts (reels)

Finished, post-ready versions of every story live in `docs/marketing/stories/social/` (git-ignored).
Each has three files: `<name>_reel.mp4` (voice + music), `<name>_reel_voice-only.mp4` (add trending
audio in Instagram) and `<name>_reel_script.md` (shot list, voiceover, captions).

| Story | File | Length | Hook |
|-------|------|--------|------|
| 1 | `S01_Log_Parameters` | 32 s | Still writing tests in a notebook? |
| 2 | `S02_Target_Ranges` | 31 s | Is 7.2 dKH ok? |
| 3 | `S03_AI_Analysis` | 42 s | Still guessing your dosing? |
| 4 | `S04_Warnings_First` | 33 s | Ammonia 0.5 ppm. Would you catch it? |
| 5 | `S05_Trend_Charts` | 31 s | Stop guessing your trends |
| 6 | `S06_CSV_Export` | 26 s | Your data. Yours. |
| 7 | `S07_Reminders` | 26 s | When was your last water change? |
| 8 | `S08_Water_Change` | 24 s | Water change done? Log it |
| 9 | `S09_Livestock` | 31 s | How many frags do you actually own? |
| 10 | `S10_Health_Log` | 28 s | That coral looks off |
| 11 | `S11_Multiple_Tanks` | 25 s | One tank is never enough |
| 12 | `S12_Saved_Analyses` | 25 s | What did it say last month? |
| 13 | `S13_Free_Credits` | 26 s | No subscription |
| 14 | `S14_Design` | 22 s | An aquarium app that isn't beige |

Common treatment: 1080×1920, opens inside the app (never the simulator home screen), form filling
sped up 3–4×, punch-in zooms on the key control, black brutalist caption blocks with aquamarine
feature chips and Safety Orange pain points, ElevenLabs "Jessica" voiceover, "Cipher" (Kevin MacLeod,
CC BY 4.0) ducked under the voice, loudness −14 LUFS, and a shared end card: Download Reef Buddy ·
Link in bio · Follow @reefbuddyapp for more reef tips · 3 free analyses · No subscription · music credit.

Differences from the storyboard above: story 7 ends on the saved schedule instead of a home-screen
banner (the simulator home screen is never shown), story 8 ends on the saved water change, and
story 14 is a straight tab tour rather than a competitor comparison.

Rebuild any of them with `tools/promo-recording/social/` (see its README).
