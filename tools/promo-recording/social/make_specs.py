"""Writes one spec per story into specs/. Timings come from 1 fps contact sheets of the raw clips."""
import json, os
S = os.environ.get("PROMO_WORK", os.path.expanduser("~/ReefBuddy-Promo"))  # raw clips in $S/out/final, music in $S/social/music
END = "Three analyses free, no subscription. Download ReefBuddy, link in bio, and follow at reef buddy app for more reef tips."
def seg(a, b, vo, cap, pos="top", size=None, zoom=None, patch=False, mn=2.0, tail=0.3, caps=None):
    d = {"src": [a, b], "min": mn, "tail": tail, "vo": vo}
    if caps is not None: d["caps"] = caps
    elif cap:
        c = {"text": cap, "pos": pos}
        if size: c["size"] = size
        d["caps"] = [c]
    if zoom: d["zoom"] = zoom
    if patch: d["patch"] = True
    return d
def end(): return {"src": None, "min": 5.5, "tail": 0.6, "vo": END}
def hook(a, b, vo, cap): return seg(a, b, vo, cap, pos="mid", size=80, patch=True, mn=2.6, tail=0.2, zoom={"to": 1.1, "x": 0.5, "y": 0.45, "frames": 90})

stories = {
 "S01_Log_Parameters": ("testS01LogParameters", 10, [
    hook(3.2, 5.6, "Still writing your test results in a notebook?", "STILL _WRITING_ TESTS\nIN A NOTEBOOK?"),
    seg(6.0, 9.5, "Open ReefBuddy and log them in seconds.", "LOG THEM IN *SECONDS*", patch=True),
    seg(10.0, 31.0, "Temperature, salinity, pH.", "*10* PARAMETERS", patch=True),
    seg(31.0, 45.0, "Alkalinity, calcium, magnesium.", "ONE *SCREEN*", zoom={"to": 1.3, "x": 0.35, "y": 0.5, "frames": 16}),
    seg(45.0, 63.0, "Nitrate, phosphate, ammonia, nitrite. Ten parameters, one screen.", "NO3 · PO4 · NH3 · NO2", size=58),
    seg(63.0, 66.6, "Then analyze, or just save and move on. No spreadsheet. No notebook.", "SAVE OR *ANALYZE*", zoom={"to": 1.3, "x": 0.5, "y": 0.72, "frames": 18, "start": 0.6}),
    end()]),
 "S02_Target_Ranges": ("testS02TargetHints", 18, [
    hook(1.3, 4.4, "Is seven point two dKH okay? Don't Google it.", "IS *7.2 DKH* OK?"),
    seg(6.0, 12.5, "Type your reading, and ReefBuddy shows the healthy range right under it.", "HEALTHY RANGE\nUNDER *EVERY* FIELD", patch=True, zoom={"to": 1.3, "x": 0.4, "y": 0.6, "frames": 18, "start": 1.0}),
    seg(13.0, 20.0, "Magnesium, calcium, every parameter has its own target.", "EVERY *TARGET*\nBUILT IN"),
    seg(21.0, 26.5, "Out of range? You'll know before you hit save.", "KNOW BEFORE\nYOU _SAVE_"),
    seg(27.0, 32.0, "Celsius or Fahrenheit,", "*°C* OR *°F*", zoom={"to": 1.35, "x": 0.85, "y": 0.28, "frames": 14}),
    seg(32.0, 38.5, "SG or ppt. Your units, your call.", "*SG* OR *PPT*", zoom={"to": 1.35, "x": 0.85, "y": 0.38, "frames": 14}),
    end()]),
 "S04_Warnings_First": ("testS04Warnings", 26, [
    hook(1.3, 4.4, "Ammonia at point five. Would you catch it in time?", "AMMONIA _0.5 PPM_\nWOULD YOU CATCH IT?"),
    seg(8.0, 14.0, "Log your tests like normal,", "LOG YOUR TESTS", patch=True),
    seg(50.0, 58.5, "including the ones that kill fish.", "THE NUMBERS THAT\n_KILL FISH_", zoom={"to": 1.35, "x": 0.3, "y": 0.5, "frames": 16}),
    seg(59.5, 62.5, "Tap Analyze.", "TAP *ANALYZE*"),
    seg(71.5, 75.5, "ReefBuddy puts the dangerous stuff at the top, in orange, before anything else.", "_WARNINGS_ FIRST", zoom={"to": 1.3, "x": 0.5, "y": 0.5, "frames": 18, "start": 0.8}),
    seg(75.5, 80.0, "Then tells you exactly what to do today. Big water change, test daily, cut feeding.", "WHAT TO DO *TODAY*"),
    seg(80.0, 84.5, "So you act before you lose a fish. Not after.", "ACT *BEFORE*\nNOT AFTER"),
    end()]),
 "S05_Trend_Charts": ("testS05TrendCharts", 34, [
    hook(1.3, 3.8, "Stop guessing your tank trends.", "STOP _GUESSING_\nYOUR TRENDS"),
    seg(4.2, 7.0, "Corals don't crash overnight. They drift.", "CORALS DON'T CRASH\nTHEY _DRIFT_", patch=True),
    seg(7.0, 11.8, "Pick a parameter and a time range,", "*90 DAYS* · ALKALINITY", zoom={"to": 1.25, "x": 0.5, "y": 0.35, "frames": 18, "start": 0.6}),
    seg(12.0, 16.5, "and see it charted against the healthy range. This alkalinity has been sliding for six weeks.", "SEE THE *DRIFT*", zoom={"to": 1.25, "x": 0.5, "y": 0.45, "frames": 20, "start": 0.5}),
    seg(19.0, 25.0, "Calcium, magnesium, every parameter gets its own optimal band.", "EVERY PARAMETER\nITS OWN *RANGE*"),
    seg(25.0, 30.5, "From a week to a year. Catch the slide before the corals do.", "7 DAYS TO *1 YEAR*"),
    end()]),
 "S06_CSV_Export": ("testS06Export", 42, [
    hook(1.3, 3.8, "Your tank data should be yours.", "YOUR DATA.\n*YOURS.*"),
    seg(4.2, 15.0, "Every test you've ever logged, in one list.", "EVERY TEST\nYOU'VE *LOGGED*", patch=True),
    seg(20.0, 24.0, "Tap export, pick a date range,", "PICK A *DATE RANGE*", zoom={"to": 1.25, "x": 0.5, "y": 0.42, "frames": 18, "start": 0.8}),
    seg(24.0, 29.5, "preview the CSV, and send it anywhere. Spreadsheet, email, your local fish store.", "*CSV* TO ANYWHERE", zoom={"to": 1.3, "x": 0.5, "y": 0.72, "frames": 18, "start": 0.5}),
    seg(29.5, 31.0, "No lock-in. Ever.", "NO _LOCK-IN_"),
    end()]),
 "S07_Reminders": ("testS07Reminders", 50, [
    hook(1.3, 3.8, "When was your last water change? Exactly.", "WHEN WAS YOUR LAST\n_WATER CHANGE?_"),
    seg(4.2, 10.5, "ReefBuddy schedules your maintenance:", "MAINTENANCE\n*REMINDERS*", patch=True),
    seg(11.0, 14.0, "water changes, filter service, testing.", "WATER CHANGE · FILTER · TESTING", size=48, zoom={"to": 1.3, "x": 0.5, "y": 0.22, "frames": 16}),
    seg(18.0, 24.0, "Every fourteen days,", "EVERY *14 DAYS*", zoom={"to": 1.3, "x": 0.5, "y": 0.48, "frames": 16}),
    seg(24.0, 29.0, "or every Sunday at nine.", "OR EVERY *SUNDAY*", zoom={"to": 1.3, "x": 0.5, "y": 0.52, "frames": 16}),
    seg(31.0, 35.5, "Save it, and your phone reminds you. No more forgetting.", "YOUR PHONE\n*REMINDS YOU*", patch=True),
    end()]),
 "S08_Water_Change": ("testS08WaterChange", 58, [
    hook(2.3, 4.8, "Twenty percent done. Now log it in two taps.", "WATER CHANGE DONE?\n*LOG IT*"),
    seg(5.2, 13.5, "From the measure screen, tap Log Water Change.", "TWO *TAPS*", patch=True, zoom={"to": 1.3, "x": 0.5, "y": 0.78, "frames": 18, "start": 1.2}),
    seg(14.5, 25.5, "Percent or gallons, plus a note.", "PERCENT OR *GALLONS*"),
    seg(26.0, 28.0, "And it's saved against your tank's history,", "SAVED TO *HISTORY*"),
    seg(28.0, 30.0, "so next week, when the numbers move, you know exactly why.", "KNOW *WHY*\nNUMBERS MOVED", patch=True),
    end()]),
 "S09_Livestock": ("testS09Livestock", 66, [
    hook(2.3, 4.8, "How many frags do you actually own?", "HOW MANY FRAGS\nDO YOU _ACTUALLY_ OWN?"),
    seg(5.2, 16.0, "Catalogue every coral, fish and invert in your tank.", "EVERY CORAL\nEVERY *FISH*", patch=True),
    seg(17.5, 27.5, "Seven categories: SPS, LPS, soft corals, fish, inverts, anemones.", "*7* CATEGORIES", zoom={"to": 1.3, "x": 0.5, "y": 0.4, "frames": 18, "start": 0.8}),
    seg(31.5, 36.0, "Photo, species, health status,", "PHOTO · SPECIES · *HEALTH*", size=52),
    seg(36.0, 39.5, "and what you paid. Maybe don't show your partner that one.", "AND WHAT YOU _PAID_", zoom={"to": 1.3, "x": 0.5, "y": 0.75, "frames": 18, "start": 0.4}),
    end()]),
 "S10_Health_Log": ("testS10HealthLog", 74, [
    hook(1.3, 4.4, "That coral looks off. Now what?", "THAT CORAL\nLOOKS _OFF_"),
    seg(7.0, 10.5, "Open it in ReefBuddy and log a health entry.", "LOG A *HEALTH* ENTRY", zoom={"to": 1.2, "x": 0.5, "y": 0.6, "frames": 20, "start": 1.0}),
    seg(11.5, 17.0, "Thriving, healthy, stressed, declining.", "THRIVING → _STRESSED_", zoom={"to": 1.3, "x": 0.5, "y": 0.22, "frames": 16}),
    seg(17.0, 36.0, "Write down what changed.", "WRITE DOWN\nWHAT *CHANGED*"),
    seg(37.0, 43.5, "It lands on a timeline.", "ON A *TIMELINE*", zoom={"to": 1.3, "x": 0.5, "y": 0.8, "frames": 18, "start": 0.8}),
    seg(50.0, 62.5, "Then watch the recovery, entry by entry. Stressed, healthy, thriving.", "WATCH IT *RECOVER*", zoom={"to": 1.3, "x": 0.5, "y": 0.62, "frames": 18, "start": 1.5}),
    end()]),
 "S11_Multiple_Tanks": ("testS11Tanks", 82, [
    hook(1.3, 4.5, "One tank is never enough.", "ONE TANK IS\n*NEVER* ENOUGH"),
    seg(10.5, 17.0, "Add your frag tank, your quarantine, your nano.", "ADD A *TANK*"),
    seg(19.5, 30.0, "Seven tank types, because a fish-only tank and an SPS reef don't want the same numbers.", "*7* TANK TYPES", zoom={"to": 1.3, "x": 0.5, "y": 0.55, "frames": 18, "start": 0.5}),
    seg(30.5, 36.5, "Each with its own history, livestock and reminders.", "ITS OWN *HISTORY*", patch=True),
    end()]),
 "S12_Saved_Analyses": ("testS12SavedAnalyses", 90, [
    hook(1.3, 3.8, "What did the AI say last month? Check.", "WHAT DID IT SAY\n_LAST MONTH?_"),
    seg(4.2, 9.0, "Every analysis is saved,", "EVERY ANALYSIS\n*SAVED*", patch=True),
    seg(9.0, 13.5, "filtered by tank, with warning badges on the bad months.", "_WARNING_ BADGES", zoom={"to": 1.25, "x": 0.5, "y": 0.45, "frames": 18, "start": 0.5}),
    seg(14.0, 20.0, "Open one and the summary, warnings and dosing are all still there.", "SUMMARY · WARNINGS · *DOSING*", size=48),
    seg(20.0, 22.5, "Plus the exact numbers you tested that day.", "THE *NUMBERS*\nTHAT DAY", zoom={"to": 1.3, "x": 0.5, "y": 0.6, "frames": 16}),
    end()]),
 "S13_Free_Credits": ("testS13Credits", 98, [
    hook(1.3, 3.8, "No subscription. Three free analyses.", "*NO* SUBSCRIPTION"),
    seg(4.2, 7.5, "Everything in ReefBuddy is free: logging, charts, livestock, reminders.", "LOGGING · CHARTS\nREMINDERS · *FREE*", size=52, patch=True),
    seg(8.0, 10.5, "AI analysis? Three free, then packs.", "*3* FREE ANALYSES", zoom={"to": 1.3, "x": 0.5, "y": 0.4, "frames": 16, "start": 0.4}),
    seg(10.5, 12.3, "Five for ninety-nine cents, fifty for four ninety-nine, and they never expire.", "CREDITS *NEVER EXPIRE*", size=56, zoom={"to": 1.3, "x": 0.5, "y": 0.66, "frames": 16}),
    end()]),
 "S14_Design": ("testS14Montage", 106, [
    seg(2.2, 3.9, "An aquarium app that isn't beige.", "AN AQUARIUM APP\nTHAT ISN'T _BEIGE_", pos="mid", size=80, patch=True, mn=2.4, tail=0.2),
    seg(4.2, 5.9, "Black. White. Aquamarine.", "BLACK · WHITE\n*AQUAMARINE*", patch=True),
    seg(6.2, 11.5, "Zero rounded corners.", "ZERO ROUNDED\nCORNERS", patch=True),
    seg(12.2, 19.5, "Built to be read at arm's length, with wet hands.", "READ WITH\n*WET HANDS*", patch=True),
    seg(20.2, 22.6, "ReefBuddy.", "*REEFBUDDY*", patch=True),
    end()]),
}
for name, (clip, moff, segs) in stories.items():
    spec = {"source": f"{S}/out/final/{clip}.mp4", "out": f"{S}/social/out/{name}_reel.mp4",
            "voice": "jessica", "rate": "+8%", "handle": "@reefbuddyapp",
            "music_credit": "MUSIC: CIPHER · KEVIN MACLEOD · CC BY 4.0",
            "music": f"{S}/social/music/cipher.mp3", "music_offset": moff, "music_db": -14, "music_duck_db": -25,
            "segments": segs}
    with open(f"specs/{name.split('_')[0].lower()}.py", "w") as f:
        f.write("spec = " + repr(spec) + "\n")
    print("spec", name)
