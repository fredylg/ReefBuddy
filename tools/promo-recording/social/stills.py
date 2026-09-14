#!/usr/bin/env python3
"""Builds the post library: stills from the raw clips, composed post images (4:5 and 1:1), a 3-slide
carousel per story, caption/hashtags/alt text, and a manifest.json an uploader can read."""
import json, os, subprocess, sys, datetime, shutil
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from reel import render_caption, AQUA, BLACK, WHITE, FONT_BLACK, FONT_BOLD, SHADOW, BORDER

S = os.environ.get("PROMO_WORK", os.path.expanduser("~/ReefBuddy-Promo"))
RAW = f"{S}/out/final"
LIB = sys.argv[1] if len(sys.argv) > 1 else f"{S}/library"
REEL_REL = "../../stories/social"   # where the reels live relative to a post folder
HANDLE = "@reefbuddyapp"

BASE_TAGS = ["reeftank", "reefkeeping", "saltwateraquarium", "reefaquarium", "coralreeftank", "marineaquarium",
             "reefer", "aquariumhobby", "reeflife", "reefbuddy", "reefbuddyapp", "reefapp", "aquariumapp"]

POSTS = [
 {"id": "S01_Log_Parameters", "clip": "testS01LogParameters", "title": "Log 10 parameters in seconds",
  "hook": "Still writing your test results in a notebook?",
  "caption": ["Still writing test results in a notebook? 📓", "",
              "ReefBuddy logs all ten parameters on one screen: temperature, salinity, pH, alkalinity, calcium, magnesium, nitrate, phosphate, ammonia and nitrite.",
              "Type the numbers, save, done. Or tap Analyze and let the AI read them for you.", "",
              "Free to download, no subscription. Link in bio."],
  "tags": ["waterchemistry", "reefchemistry", "alkalinity", "calcium", "magnesium", "testkit", "hannachecker"],
  "frames": [(32.0, "*10* PARAMETERS\nONE SCREEN", 0.5, 0.5, 1.0), (64.0, "SAVE OR *ANALYZE*", 0.5, 0.7, 1.15), (6.0, "LOG IN *SECONDS*", 0.5, 0.35, 1.0)],
  "alt": "ReefBuddy measurement screen with alkalinity, calcium and magnesium fields filled in, each showing its healthy target range."},
 {"id": "S02_Target_Ranges", "clip": "testS02TargetHints", "title": "Healthy range under every field",
  "hook": "Is 7.2 dKH ok? Don't Google it.",
  "caption": ["Is 7.2 dKH okay? 🤔", "",
              "You don't need to Google it. Every field in ReefBuddy shows the healthy range right underneath as you type, so you know before you hit save.",
              "Celsius or Fahrenheit, SG or ppt. Your units, your call.", "",
              "Download free. Link in bio."],
  "tags": ["alkalinity", "dkh", "reefparameters", "waterchemistry", "reefchemistry", "beginnerreefer", "reeftips"],
  "frames": [(12.0, "HEALTHY RANGE\nUNDER *EVERY* FIELD", 0.4, 0.45, 1.25), (30.0, "*°C* OR *°F*", 0.8, 0.3, 1.2), (34.0, "*SG* OR *PPT*", 0.8, 0.4, 1.2)],
  "alt": "Alkalinity field in ReefBuddy showing a reading of 7.2 dKH with the target range 7.0 to 11.0 printed under it."},
 {"id": "S03_AI_Analysis", "clip": "testS03AIAnalysis", "title": "AI analysis with exact dosing",
  "hook": "Still guessing your dosing?",
  "caption": ["Still guessing how much to dose? 🧪", "",
              "Tap Analyze and ReefBuddy reads your numbers against your tank's size, type and history. You get a plain-English summary, specific recommendations and dosing amounts worked out for YOUR volume.",
              "Not \"add some buffer\". Exact amounts.", "",
              "3 analyses free, no subscription. Link in bio."],
  "tags": ["dosing", "twopart", "alkalinity", "calcium", "reefchemistry", "aidosing", "coralgrowth", "spsreef"],
  "frames": [(73.6, "AI ANALYSIS\n*COMPLETE*", 0.5, 0.3, 1.0), (80.5, "*EXACT* DOSING\nFOR YOUR VOLUME", 0.5, 0.42, 1.25), (76.0, "SPECIFIC\n*RECOMMENDATIONS*", 0.5, 0.5, 1.15)],
  "alt": "ReefBuddy AI analysis result screen with a green Complete banner, a written summary and numbered recommendations."},
 {"id": "S04_Warnings_First", "clip": "testS04Warnings", "title": "Warnings first",
  "hook": "Ammonia 0.5 ppm. Would you catch it in time?",
  "caption": ["Ammonia at 0.5 ppm. Would you catch it? ⚠️", "",
              "ReefBuddy puts the dangerous readings at the top, in orange, before anything else. Then it tells you exactly what to do today: water change, test daily, cut feeding.",
              "So you act before you lose a fish. Not after.", "",
              "Free to download. Link in bio."],
  "tags": ["ammonia", "nitrite", "newtanksyndrome", "reefemergency", "fishhealth", "waterquality", "reeftips"],
  "frames": [(79.0, "_WARNINGS_ FIRST", 0.5, 0.55, 1.2), (82.5, "WHAT TO DO *TODAY*", 0.5, 0.5, 1.0), (56.0, "THE NUMBERS THAT\n_KILL FISH_", 0.3, 0.5, 1.25)],
  "alt": "ReefBuddy analysis showing an orange warning box about ammonia and nitrite above a list of recommendations."},
 {"id": "S05_Trend_Charts", "clip": "testS05TrendCharts", "title": "See the drift",
  "hook": "Stop guessing your tank trends.",
  "caption": ["Stop guessing your tank trends. 📉", "",
              "Corals don't crash overnight. They drift. ReefBuddy charts every parameter against its healthy range so you see the slide weeks before the corals show it.",
              "From 7 days to a year, alkalinity to salinity.", "",
              "Download free. Link in bio."],
  "tags": ["alkalinity", "reefparameters", "waterchemistry", "spsreef", "coralhealth", "reefdata", "trends"],
  "frames": [(14.0, "SEE THE *DRIFT*", 0.5, 0.45, 1.15), (11.0, "*90 DAYS* · ALKALINITY", 0.5, 0.38, 1.15), (23.0, "EVERY PARAMETER\nITS OWN *RANGE*", 0.5, 0.4, 1.0)],
  "alt": "Full-screen alkalinity trend chart in ReefBuddy with a shaded optimal range band and a line drifting downward over three months."},
 {"id": "S06_CSV_Export", "clip": "testS06Export", "title": "Your data, exported",
  "hook": "Your data should be yours.",
  "caption": ["Your tank data should be yours. 📤", "",
              "Every test you've ever logged, in one list. Pick a date range, preview the CSV and send it anywhere: spreadsheet, email, your local fish store.",
              "No lock-in. Ever.", "",
              "Download free. Link in bio."],
  "tags": ["reefdata", "csv", "spreadsheet", "waterchemistry", "reeflog", "aquariumlog", "reeftips"],
  "frames": [(26.0, "*CSV* TO ANYWHERE", 0.5, 0.55, 1.0), (10.0, "EVERY TEST\nYOU'VE *LOGGED*", 0.5, 0.5, 1.0), (30.5, "NO _LOCK-IN_", 0.5, 0.3, 1.0)],
  "alt": "ReefBuddy export screen with a date range selector, a CSV preview and an Export CSV button."},
 {"id": "S07_Reminders", "clip": "testS07Reminders", "title": "Maintenance reminders",
  "hook": "When was your last water change? Exactly.",
  "caption": ["When was your last water change? Exactly. 🪣", "",
              "ReefBuddy schedules your water changes, filter service and testing. Every 14 days or every Sunday at nine, your phone reminds you.",
              "No more forgetting. No more guessing.", "",
              "Download free. Link in bio."],
  "tags": ["waterchange", "reefmaintenance", "aquariummaintenance", "filterservice", "reefroutine", "reeftips", "aquariumcare"],
  "frames": [(8.0, "MAINTENANCE\n*REMINDERS*", 0.5, 0.45, 1.0), (13.0, "WATER CHANGE · FILTER · TESTING", 0.5, 0.25, 1.2), (27.0, "OR EVERY *SUNDAY*", 0.5, 0.5, 1.15)],
  "alt": "ReefBuddy maintenance schedules list showing a fortnightly water change and a weekly testing reminder."},
 {"id": "S08_Water_Change", "clip": "testS08WaterChange", "title": "Log a water change",
  "hook": "Water change done? Log it in two taps.",
  "caption": ["Twenty percent done. Now log it. 💧", "",
              "Two taps from the measure screen: percent or gallons, plus a note. It's saved against your tank's history, so next week when the numbers move you know exactly why.", "",
              "Download free. Link in bio."],
  "tags": ["waterchange", "reefmaintenance", "saltmix", "waterchemistry", "reeflog", "reeftips"],
  "frames": [(24.0, "PERCENT OR *GALLONS*", 0.5, 0.45, 1.0), (13.0, "TWO *TAPS*", 0.5, 0.78, 1.2), (27.0, "SAVED TO *HISTORY*", 0.5, 0.5, 1.0)],
  "alt": "ReefBuddy log water change sheet with 20 percent and 18 gallons entered and a Save Water Change button."},
 {"id": "S09_Livestock", "clip": "testS09Livestock", "title": "Livestock catalogue",
  "hook": "How many frags do you actually own?",
  "caption": ["How many frags do you actually own? 🪸", "",
              "Catalogue every coral, fish and invert: photo, species, health status, and what you paid. Seven categories from SPS to anemones.",
              "Maybe don't show your partner the total.", "",
              "Download free. Link in bio."],
  "tags": ["coral", "sps", "lps", "zoanthids", "clownfish", "reeflivestock", "coralcollection", "fragtank"],
  "frames": [(6.0, "EVERY CORAL\nEVERY *FISH*", 0.5, 0.45, 1.0), (33.0, "PHOTO · SPECIES · *HEALTH*", 0.5, 0.4, 1.0), (25.0, "*7* CATEGORIES", 0.5, 0.35, 1.2)],
  "alt": "ReefBuddy livestock list with photos of a clownfish, blue tang, torch coral and acropora, each with a health status badge."},
 {"id": "S10_Health_Log", "clip": "testS10HealthLog", "title": "Health log timeline",
  "hook": "That coral looks off. Now what?",
  "caption": ["That coral looks off. Now what? 🔍", "",
              "Log a health entry in ReefBuddy: thriving, healthy, stressed, declining. Write down what changed. Then watch the recovery on a timeline, entry by entry.",
              "Track recovery, not just losses.", "",
              "Download free. Link in bio."],
  "tags": ["coralhealth", "montipora", "acropora", "spsreef", "coralcare", "reefjournal", "reeftips"],
  "frames": [(58.0, "WATCH IT *RECOVER*", 0.5, 0.62, 1.15), (16.0, "THRIVING → _STRESSED_", 0.5, 0.22, 1.2), (42.0, "ON A *TIMELINE*", 0.5, 0.8, 1.15)],
  "alt": "Health log timeline for a Montipora coral in ReefBuddy moving from stressed to healthy to thriving over six weeks."},
 {"id": "S11_Multiple_Tanks", "clip": "testS11Tanks", "title": "Every tank, its own history",
  "hook": "One tank is never enough.",
  "caption": ["One tank is never enough. 🐠", "",
              "Display, frag tank, quarantine, nano. Seven tank types, because a fish-only tank and an SPS reef don't want the same numbers. Each gets its own history, livestock and reminders.", "",
              "Download free. Link in bio."],
  "tags": ["nanoreef", "fragtank", "quarantinetank", "fowlr", "mixedreef", "spsreef", "multipletanks"],
  "frames": [(34.0, "ITS OWN *HISTORY*", 0.5, 0.5, 1.0), (22.0, "*7* TANK TYPES", 0.5, 0.55, 1.2), (15.0, "ADD A *TANK*", 0.5, 0.3, 1.0)],
  "alt": "ReefBuddy tank list showing a frag tank, a display tank and a new quarantine tank with gallons and age."},
 {"id": "S12_Saved_Analyses", "clip": "testS12SavedAnalyses", "title": "Saved analyses",
  "hook": "What did the AI say last month?",
  "caption": ["What did the AI say last month? Check. 📚", "",
              "Every analysis is saved and filtered by tank, with warning badges on the bad months. Open one and the summary, warnings, dosing and the exact numbers you tested that day are all still there.", "",
              "Download free. Link in bio."],
  "tags": ["reefjournal", "reefdata", "dosing", "waterchemistry", "reeflog", "reeftips"],
  "frames": [(10.0, "_WARNING_ BADGES", 0.5, 0.45, 1.15), (15.0, "SUMMARY · WARNINGS · *DOSING*", 0.5, 0.5, 1.0), (22.0, "THE *NUMBERS*\nTHAT DAY", 0.5, 0.6, 1.2)],
  "alt": "ReefBuddy saved analyses list with dated entries per tank, some carrying an orange warning badge."},
 {"id": "S13_Free_Credits", "clip": "testS13Credits", "title": "No subscription",
  "hook": "No subscription. Three free analyses.",
  "caption": ["No subscription. 🙌", "",
              "Logging, charts, livestock and reminders are free forever. AI analysis: three free, then 5 for $0.99 or 50 for $4.99, and credits never expire.", "",
              "Download free. Link in bio."],
  "tags": ["freeapp", "nosubscription", "reefapp", "aquariumapp", "reefonabudget", "reeftips"],
  "frames": [(10.0, "*3* FREE ANALYSES", 0.5, 0.4, 1.15), (12.0, "CREDITS *NEVER EXPIRE*", 0.5, 0.66, 1.2), (6.0, "LOGGING · CHARTS\nREMINDERS · *FREE*", 0.5, 0.4, 1.0)],
  "alt": "ReefBuddy credits screen showing 3 free analyses left and two credit packs priced at $0.99 and $4.99."},
 {"id": "S14_Design", "clip": "testS14Montage", "title": "An app that isn't beige",
  "hook": "An aquarium app that isn't beige.",
  "caption": ["An aquarium app that isn't beige. ⬛⬜", "",
              "Black. White. Aquamarine. Zero rounded corners. Built to be read at arm's length with wet hands.", "",
              "ReefBuddy. Download free, link in bio."],
  "tags": ["appdesign", "brutalism", "uidesign", "reefapp", "aquariumapp", "reeflife"],
  "frames": [(3.0, "AN AQUARIUM APP\nTHAT ISN'T _BEIGE_", 0.5, 0.4, 1.0), (5.0, "BLACK · WHITE\n*AQUAMARINE*", 0.5, 0.4, 1.0), (10.0, "ZERO ROUNDED\nCORNERS", 0.5, 0.4, 1.0)],
  "alt": "Three ReefBuddy screens in black, white and aquamarine: measurement form, livestock list and trend chart."},
]

def sh(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode: print(r.stderr[-1500:]); sys.exit(1)

def grab(clip, t, path):
    sh(["ffmpeg", "-y", "-v", "error", "-ss", f"{t:.2f}", "-i", f"{RAW}/{clip}.mp4", "-frames:v", "1", path])
    return Image.open(path).convert("RGB")

def phone_zoom(img, fx, fy, z):
    """Crop the phone frame around a focus point (normalised) by zoom factor z, keep the aspect."""
    if z <= 1.0: return img
    w, h = img.size; cw, ch = int(w / z), int(h / z)
    x = min(max(int(fx * w - cw / 2), 0), w - cw); y = min(max(int(fy * h - ch / 2), 0), h - ch)
    return img.crop((x, y, x + cw, y + ch)).resize((w, h), Image.LANCZOS)

def frame_with_border(img, target_h):
    w = int(img.width * target_h / img.height)
    ph = img.resize((w, target_h), Image.LANCZOS)
    canvas = Image.new("RGBA", (w + 2 * BORDER + SHADOW, target_h + 2 * BORDER + SHADOW), (0, 0, 0, 0))
    d = ImageDraw.Draw(canvas)
    d.rectangle([SHADOW, SHADOW, SHADOW + w + 2 * BORDER - 1, SHADOW + target_h + 2 * BORDER - 1], fill=BLACK)
    d.rectangle([0, 0, w + 2 * BORDER - 1, target_h + 2 * BORDER - 1], fill=BLACK)
    canvas.paste(ph, (BORDER, BORDER))
    return canvas

def cta_chip(size=30):
    return render_caption(f"REEFBUDDY · *{HANDLE.upper()}*", size=size)

def compose(img, headline, W, H, path, caption=True, cta=True, fy=0.4):
    """Post image: white canvas, bordered phone, headline block over the header, small CTA chip."""
    bg = Image.new("RGB", (W, H), WHITE)
    ph = frame_with_border(img, int(H * 0.86 if H > W else H * 0.92))
    if H == W:  # square: fill the width and show the part of the phone around the focus point
        ph = frame_with_border(img, int(W * 2622 / 1206 * 0.62))
        win = H - 40
        top = min(max(int(fy * ph.height - win * 0.45), 0), ph.height - win)
        crop = ph.crop((0, top, ph.width, top + win))
        x = (W - ph.width) // 2; y = 40
        bg.paste(crop, (x, y), crop)
    else:
        x = (W - ph.width) // 2; y = (H - ph.height) // 2 + 20
        bg.paste(ph, (x, y), ph)
    if caption and headline:
        c = render_caption(headline, size=64 if len(headline) < 26 else 54, maxw=W - 100)
        bg.paste(c, ((W - c.width) // 2, 70 if H == W else int(H * 0.06)), c)
    if cta:
        chip = cta_chip()
        bg.paste(chip, ((W - chip.width) // 2, H - chip.height - 28), chip)
    bg.save(path, optimize=True)
    return {"file": os.path.relpath(path, LIB), "width": W, "height": H}

def main():
    os.makedirs(LIB, exist_ok=True)
    manifest = {"schema": "reefbuddy-post-library/1", "generated_at": datetime.datetime.now().isoformat(timespec="seconds"),
                "brand": {"name": "ReefBuddy", "handle": HANDLE, "colors": {"background": "#FFFFFF", "text": "#000000", "action": "#00FFD1", "warning": "#FF3D00"},
                          "cta": "Download Reef Buddy (link in bio) | Follow @reefbuddyapp for more tips",
                          "music_credit": "Music: Cipher by Kevin MacLeod (incompetech.com), CC BY 4.0"},
                "posts": []}
    for p in POSTS:
        d = f"{LIB}/posts/{p['id']}"; os.makedirs(f"{d}/images", exist_ok=True)
        images = []
        for i, (t, headline, fx, fy, z) in enumerate(p["frames"], 1):
            raw = grab(p["clip"], t, f"{d}/images/frame{i}_raw.png")
            images.append({"kind": "still_raw", "slide": i, "file": os.path.relpath(f"{d}/images/frame{i}_raw.png", LIB), "width": raw.width, "height": raw.height, "source_time_s": t})
            focused = phone_zoom(raw, fx, fy, z)
            if i == 1:
                images.append({"kind": "post", "aspect": "4:5", "slide": 1, **compose(focused, headline, 1080, 1350, f"{d}/images/post_4x5.png")})
                images.append({"kind": "post", "aspect": "1:1", "slide": 1, **compose(focused, headline, 1080, 1080, f"{d}/images/post_1x1.png", fy=fy)})
                images.append({"kind": "still_clean", "aspect": "4:5", "slide": 1, **compose(raw, None, 1080, 1350, f"{d}/images/still_clean_4x5.png", caption=False, cta=False)})
            images.append({"kind": "carousel", "aspect": "4:5", "slide": i, "headline": headline, **compose(focused, headline, 1080, 1350, f"{d}/images/carousel_{i}_4x5.png")})
        tags = ["#" + t for t in dict.fromkeys(p["tags"] + BASE_TAGS)]
        caption = "\n".join(p["caption"])
        post = {"id": p["id"], "story_number": int(p["id"][1:3]), "title": p["title"], "hook": p["hook"], "status": "draft",
                "platforms": ["instagram_reel", "instagram_post", "instagram_carousel", "tiktok", "facebook"],
                "caption": caption, "caption_with_hashtags": caption + "\n\n" + " ".join(tags), "hashtags": tags,
                "alt_text": p["alt"], "cta": manifest["brand"]["cta"],
                "video": {"reel": f"{REEL_REL}/{p['id']}_reel.mp4", "reel_voice_only": f"{REEL_REL}/{p['id']}_reel_voice-only.mp4", "script": f"{REEL_REL}/{p['id']}_reel_script.md",
                          "music_credit_required": True},
                "images": images,
                "primary_image": os.path.relpath(f"{d}/images/post_4x5.png", LIB)}
        json.dump(post, open(f"{d}/post.json", "w"), indent=2, ensure_ascii=False)
        open(f"{d}/caption.txt", "w").write(post["caption_with_hashtags"] + "\n")
        manifest["posts"].append({k: post[k] for k in ("id", "story_number", "title", "hook", "status", "primary_image")} | {"post_json": os.path.relpath(f"{d}/post.json", LIB), "reel": post["video"]["reel"]})
        print("post", p["id"], len(images), "images")
    json.dump(manifest, open(f"{LIB}/manifest.json", "w"), indent=2, ensure_ascii=False)

if __name__ == "__main__":
    main()
