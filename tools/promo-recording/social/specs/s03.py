import os
S = os.environ.get("PROMO_WORK", os.path.expanduser("~/ReefBuddy-Promo"))
spec = {
    "source": f"{S}/out/final/testS03AIAnalysis.mp4",
    "out": f"{S}/social/out/S03_AI_Analysis_reel.mp4",
    "voice": "jessica", "rate": "+8%", "handle": "@reefbuddyapp",
    "music_credit": "MUSIC: CIPHER · KEVIN MACLEOD · CC BY 4.0",
    "music": f"{S}/social/music/cipher.mp3", "music_offset": 6.0, "music_db": -14, "music_duck_db": -25,
    "segments": [
        # 1 · hook on the tank list (no simulator home screen anywhere)
        {"src": [1.3, 4.4], "patch": True, "min": 3.0, "tail": 0.2,
         "vo": "Still guessing how much to dose your reef? Stop.",
         "zoom": {"to": 1.12, "x": 0.5, "y": 0.45, "frames": 90},
         "caps": [{"text": "STILL _GUESSING_\nYOUR DOSING?", "pos": "mid", "size": 84}]},
        # 2 · measure screen
        {"src": [4.5, 7.9], "patch": True, "min": 2.2, "tail": 0.2,
         "vo": "Log your test results in ReefBuddy.",
         "caps": [{"text": "LOG YOUR *TESTS*", "pos": "top"}]},
        # 3 · typing, cut into three fast passes
        {"src": [8.0, 16.0], "patch": True, "min": 2.0, "tail": 0.0,
         "vo": "Ten parameters. One screen.",
         "caps": [{"text": "*10* PARAMETERS\nONE SCREEN", "pos": "top"}]},
        {"src": [27.0, 38.0], "patch": True, "min": 2.6, "tail": 0.1,
         "vo": "Every field shows the healthy range as you type.",
         "zoom": {"to": 1.35, "x": 0.35, "y": 0.5, "frames": 14},
         "caps": [{"text": "HEALTHY RANGE\nAS YOU *TYPE*", "pos": "top"}]},
        {"src": [44.0, 58.6], "patch": True, "min": 2.4, "tail": 0.0,
         "vo": "Alkalinity, calcium, magnesium, nutrients, all of it.",
         "caps": [{"text": "ALK · CA · MG\nNO3 · PO4 · NH3", "pos": "top", "size": 58}]},
        # 4 · analyze
        {"src": [61.8, 64.6], "patch": True, "min": 2.0, "tail": 0.2,
         "vo": "Then tap Analyze.",
         "zoom": {"to": 1.3, "x": 0.5, "y": 0.62, "frames": 20, "start": 0.4},
         "caps": [{"text": "TAP *ANALYZE*", "pos": "top", "size": 84}]},
        # 5 · loader → result
        {"src": [70.6, 73.8], "min": 2.6, "tail": 0.1,
         "vo": "The AI reads your numbers against your tank's size, type and history,",
         "caps": [{"text": "AI READS YOUR *TANK*\nSIZE · TYPE · HISTORY", "pos": "top", "size": 56}]},
        # 6 · summary + recommendations
        {"src": [73.8, 78.5], "min": 3.0, "tail": 0.1,
         "vo": "and gives you a plain English summary, then specific recommendations.",
         "caps": [{"text": "PLAIN-ENGLISH *SUMMARY*", "pos": "top", "size": 56, "until": 1.8},
                  {"text": "SPECIFIC *RECOMMENDATIONS*", "pos": "top", "size": 52, "at": 1.8}]},
        # 7 · dosing advice with punch-in
        {"src": [78.5, 84.5], "min": 3.6, "tail": 0.2,
         "vo": "Not add some buffer. Exact dosing amounts, worked out for your tank volume.",
         "zoom": {"to": 1.4, "x": 0.5, "y": 0.42, "frames": 16, "start": 0.8},
         "caps": [{"text": "NOT _\"ADD SOME BUFFER\"_", "pos": "top", "size": 56, "until": 1.6},
                  {"text": "*EXACT* DOSING\nFOR YOUR VOLUME", "pos": "top", "size": 64, "at": 1.6}]},
        # 8 · save
        {"src": [88.6, 91.6], "min": 2.2, "tail": 0.2,
         "vo": "Save it. Share it with your reef club.",
         "caps": [{"text": "SAVE IT · *SHARE IT*", "pos": "top", "size": 60}]},
        # 9 · end card
        {"src": None, "min": 5.5, "tail": 0.6,
         "vo": "Three analyses free, no subscription. Download ReefBuddy, link in bio, and follow at reef buddy app for more reef tips."},
    ],
}
