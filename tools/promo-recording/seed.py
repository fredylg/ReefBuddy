#!/usr/bin/env python3
"""Seed the ReefBuddy simulator install with realistic demo data.
Tanks, measurements and water changes go through the local dev API (server wins on fetch);
livestock, health logs, photos, saved analyses and maintenance schedules are written locally."""
import json, os, random, shutil, sys, time, uuid, urllib.request
from datetime import datetime, timedelta, timezone

API = "http://localhost:8787"
DEVICE_ID = sys.argv[1]
CONTAINER = sys.argv[2]
PHOTOS = sys.argv[3]
DATA = os.path.join(CONTAINER, "Library/Application Support/ReefBuddy/Data")
IMAGES = os.path.join(CONTAINER, "Library/Application Support/LivestockImages")
random.seed(42)
NOW = datetime(2026, 9, 9, 8, 0, tzinfo=timezone.utc)
TZ = "Australia/Sydney"

def iso(d): return d.strftime("%Y-%m-%dT%H:%M:%SZ")
def ref(d): return (d - datetime(2001, 1, 1, tzinfo=timezone.utc)).total_seconds()
def U(): return str(uuid.uuid4()).upper()
def days_ago(n, h=9, m=30): return (NOW - timedelta(days=n)).replace(hour=h, minute=m)

def api(method, path, body=None):
    req = urllib.request.Request(API + path, method=method, headers={
        "Content-Type": "application/json", "X-Device-ID": DEVICE_ID})
    data = json.dumps(body).encode() if body is not None else None
    with urllib.request.urlopen(req, data, timeout=30) as r:
        out = json.loads(r.read())
    time.sleep(1.05)  # 60 req/min per device
    return out.get("data", out)

def r(a, b, nd=2): return round(random.uniform(a, b), nd)

# ---------------------------------------------------------------- tanks
print("tanks…")
display = api("POST", "/api/tanks", {"name": "Display Tank", "volume_gallons": 90, "tank_type": "mixed_reef"})
frag = api("POST", "/api/tanks", {"name": "Frag Tank", "volume_gallons": 20, "tank_type": "nano"})
DID, FID = display["id"].upper(), frag["id"].upper()
tanks_local = [
    {"id": DID, "name": "Display Tank", "volumeGallons": 90, "tankType": "mixed_reef",
     "createdAt": iso(days_ago(430)), "updatedAt": iso(days_ago(5)),
     "notes": "Red Sea Reefer 425. 2x Radion XR30, Trident + DOS, 15% water change fortnightly."},
    {"id": FID, "name": "Frag Tank", "volumeGallons": 20, "tankType": "nano",
     "createdAt": iso(days_ago(240)), "updatedAt": iso(days_ago(2)),
     "notes": "IM Nuvo 20. Grow-out for SPS and zoa frags."},
]

# ---------------------------------------------------------------- measurements
def post_measurement(tank_id, when, p, notes=None):
    body = {"tank_id": tank_id.lower(), "measured_at": iso(when), "salinity_unit": "SG"}
    body.update({k: v for k, v in p.items() if v is not None})
    if notes: body["notes"] = notes
    out = api("POST", "/api/measurements", body)
    local = {"id": str(out.get("id", uuid.uuid4())).upper(), "tankId": tank_id, "measuredAt": iso(when), "salinityUnit": "SG"}
    local.update(p)
    if notes: local["notes"] = notes
    return local

print("measurements (display)…")
display_meas = []
notes_pool = {20: "Switched to Hanna alk checker", 12: "After 15% water change", 6: "Started 2-part dosing",
              3: "Corals a bit pale, alk keeps dropping", 1: "Retest to confirm alk"}
# 20 weekly tests, then 6 weeks of twice-weekly tests with an alkalinity/calcium slide
sched = [days_ago(7 * w + 42) for w in range(20, 0, -1)]
sched += [days_ago(d) for d in range(41, -1, -3)]  # every 3 days over the last 6 weeks
n_recent = 15
for i, when in enumerate(sched):
    recent_i = i - (len(sched) - n_recent)
    if recent_i < 0:
        alk, ca = r(8.4, 8.8, 1), r(425, 442, 0)
    else:
        f = recent_i / (n_recent - 1)
        alk = round(8.6 - 1.4 * f + random.uniform(-0.08, 0.08), 1)
        ca = round(432 - 37 * f + random.uniform(-4, 4), 0)
    p = {"temperature": r(77.6, 78.6, 1), "salinity": r(1.0250, 1.0262, 4), "ph": r(8.05, 8.30, 2),
         "alkalinity": alk, "calcium": ca, "magnesium": r(1338, 1382, 0), "nitrate": r(4, 10, 1),
         "phosphate": r(0.03, 0.08, 2), "ammonia": 0.0, "nitrite": 0.0}
    display_meas.append(post_measurement(DID, when, p, notes_pool.get(len(sched) - 1 - i)))

print("measurements (frag)…")
frag_meas = []
for w in range(20, 0, -1):
    when = days_ago(7 * w - 2, 18, 0)
    p = {"temperature": r(78.0, 78.8, 1), "salinity": r(1.0255, 1.0262, 4), "ph": r(8.10, 8.28, 2),
         "alkalinity": r(8.8, 9.2, 1), "calcium": r(430, 450, 0), "magnesium": r(1380, 1420, 0),
         "nitrate": r(2, 6, 1), "phosphate": r(0.02, 0.05, 2), "ammonia": 0.0, "nitrite": 0.0}
    frag_meas.append(post_measurement(FID, when, p))

# ---------------------------------------------------------------- water changes
print("water changes…")
wc_local = {DID: [], FID: []}
def post_wc(tank_id, when, pct, gal, notes=None):
    body = {"performedAt": iso(when), "percentReplaced": pct, "gallonsReplaced": gal}
    if notes: body["notes"] = notes
    out = api("POST", f"/api/tanks/{tank_id.lower()}/water-changes", body)
    wc_local[tank_id].append({"id": str(out.get("id", uuid.uuid4())).upper(), "tankId": tank_id, "performedAt": iso(when),
        "percentReplaced": pct, "gallonsReplaced": gal, "notes": notes, "createdAt": iso(when), "updatedAt": iso(when),
        "needsSync": False, "isDeleted": False})
for k in range(13):
    d = 5 + 14 * k
    post_wc(DID, days_ago(d, 10, 0), 15, 13.5, "Red Sea Coral Pro, mixed 24h" if k % 4 == 0 else None)
for k in range(20):
    post_wc(FID, days_ago(3 + 7 * k, 11, 0), 20, 4)

# ---------------------------------------------------------------- livestock (local only)
print("livestock…")
os.makedirs(DATA, exist_ok=True); os.makedirs(IMAGES, exist_ok=True)
for f in os.listdir(IMAGES): os.remove(os.path.join(IMAGES, f))
livestock, logs = [], []
def ls(tank, name, sci, cat, status, qty, days, price, notes, photo, created_days=None):
    lid = U()
    item = {"id": lid, "tankId": tank, "name": name, "scientificName": sci, "category": cat, "healthStatus": status,
            "quantity": qty, "purchaseDate": iso(days_ago(days, 14, 0)), "purchasePrice": price, "notes": notes,
            "createdAt": iso(days_ago(created_days or days, 15, 0)), "updatedAt": iso(days_ago(random.randint(1, 20), 19, 0))}
    livestock.append(item)
    if photo: shutil.copy(os.path.join(PHOTOS, photo + ".jpg"), os.path.join(IMAGES, lid + ".jpg"))
    return lid
def log(lid, days, status, note):
    logs.append({"id": U(), "livestockId": lid, "loggedAt": iso(days_ago(days, 20, 15)), "healthStatus": status, "notes": note})

clown = ls(DID, "Ocellaris Clownfish", "Amphiprion ocellaris", "fish", "thriving", 2, 395, 89.98, "Bonded pair. Host the bubble tip.", "clown")
tang  = ls(DID, "Blue Tang", "Paracanthurus hepatus", "fish", "healthy", 1, 270, 79.99, "Eats nori daily. Watch for ich after any stress.", "tang")
torch = ls(DID, "Gold Torch", "Euphyllia glabrescens", "lps", "thriving", 1, 300, 180.00, "3 heads. Front left rock, moderate flow.", "torch")
acro  = ls(DID, "Acropora tenuis", "Acropora tenuis", "sps", "thriving", 1, 210, 120.00, "Top of the scape, ~350 PAR.", "acropora")
dunc  = ls(DID, "Duncan Coral", "Duncanopsammia axifuga", "lps", "thriving", 1, 240, 65.00, "Sandbed. Feeds on mysis twice a week.", "duncan")
zoa   = ls(DID, "Utter Chaos Zoas", "Zoanthus sp.", "soft_coral", "healthy", 1, 180, 45.00, "Started as 5 polyps, now ~30.", "zoa")
bta   = ls(DID, "Bubble Tip Anemone", "Entacmaea quadricolor", "anemone", "thriving", 1, 330, 70.00, "Rose BTA. Split once in March.", "bta")
shr   = ls(DID, "Cleaner Shrimp", "Lysmata amboinensis", "invertebrate", "healthy", 1, 360, 35.00, "Cleans the tang every morning.", "shrimp")
clam  = ls(DID, "Maxima Clam", "Tridacna maxima", "invertebrate", "healthy", 1, 150, 150.00, "Blue. Sandbed under the Radion.", "clam")
monti = ls(DID, "Montipora capitata", "Montipora capitata", "sps", "thriving", 1, 180, 55.00, "Orange plating. Recovered after the August light change.", "monti")
chrom = ls(DID, "Green Chromis", "Chromis viridis", "fish", "healthy", 5, 365, 49.95, "School of five. Top of the water column.", None)
snail = ls(DID, "Trochus Snails", "Trochus sp.", "invertebrate", "healthy", 8, 400, 32.00, "Clean-up crew.", None)
ls(FID, "Acropora frag", "Acropora sp.", "sps", "healthy", 1, 60, 40.00, "Cut from the display colony.", "acropora")
ls(FID, "Zoa frag", "Zoanthus sp.", "soft_coral", "thriving", 1, 45, 25.00, "Utter Chaos, 4 polyps.", "zoa")
ls(FID, "Montipora frag", "Montipora capitata", "sps", "healthy", 1, 30, 30.00, "Encrusting well.", "monti")
ls(FID, "Torch frag", "Euphyllia glabrescens", "lps", "healthy", 1, 20, 90.00, "Single head from the gold torch.", "torch")

log(monti, 42, "stressed", "Tips paling two days after the new light schedule.")
log(monti, 35, "stressed", "Dropped intensity 15%. No further tissue loss.")
log(monti, 24, "healthy", "Colour coming back at the base.")
log(monti, 14, "healthy", "New growth along the plate edge.")
log(monti, 6,  "thriving", "Full orange again, polyps out all day.")
log(clown, 180, "healthy", "Both eating pellets and mysis.")
log(clown, 60,  "thriving", "Hosting the BTA. First spawn on the rock!")
log(torch, 95,  "healthy", "Middle head is splitting.")
log(torch, 30,  "thriving", "Three full heads now.")
log(tang, 262, "stressed", "Ich spots on the fins after introduction.")
log(tang, 248, "healthy", "Spots gone after two weeks. Eating well.")
log(bta, 120, "thriving", "Split into two. Moved the second to the frag rack.")

# ---------------------------------------------------------------- saved analyses (local only, Foundation dates)
print("saved analyses…")
def analysis(tank_id, tank_name, days, params, summary, recs, warns=None, dosing=None):
    return {"id": U(), "tankId": tank_id, "tankName": tank_name, "analyzedAt": ref(days_ago(days, 10, 5)),
            "parameters": params, "summary": summary, "recommendations": recs, "warnings": warns, "dosingAdvice": dosing}
P = lambda **k: {"salinity": None, "temperature": None, "ph": None, "alkalinity": None, "calcium": None, "magnesium": None,
                 "nitrate": None, "nitrite": None, "ammonia": None, "phosphate": None} | k
analyses = [
    analysis(DID, "Display Tank", 4,
        P(salinity=1.0255, temperature=78.1, ph=8.12, alkalinity=7.4, calcium=400, magnesium=1345, nitrate=8.0, nitrite=0, ammonia=0, phosphate=0.06),
        "Alkalinity has slipped to 7.4 dKH, well below the 8-9 dKH this mixed reef held for months, and calcium is drifting down with it. Nutrients, salinity and temperature are stable and suit a 90-gallon mixed reef.",
        ["Raise alkalinity gradually back to 8.5 dKH over 4-5 days, no more than 1 dKH per day.",
         "Bring calcium back to 420-430 ppm alongside the alkalinity correction to keep the two balanced.",
         "Test alkalinity daily until it holds steady for three consecutive days, then set your daily dose to match consumption.",
         "Hold nitrate at 5-10 ppm and phosphate at 0.03-0.08 ppm. Both are in a good place for coral colour.",
         "Check the calcium reactor or two-part pump output. A steady six-test decline points to consumption outpacing supply."],
        ["Alkalinity 7.4 dKH is below the target range and has fallen for six consecutive tests.",
         "Calcium 400 ppm is at the bottom of the acceptable range and trending down with alkalinity."],
        "Two-part alkalinity (sodium carbonate): 45 mL daily for 4 days, then retest - lifts alkalinity about 0.3 dKH per day in 90 gallons\n"
        "Two-part calcium (calcium chloride): 30 mL daily for 4 days - keeps calcium rising in step with alkalinity\n"
        "Magnesium: no dose - 1345 ppm is in range"),
    analysis(DID, "Display Tank", 33,
        P(salinity=1.0258, temperature=78.0, ph=8.18, alkalinity=8.5, calcium=428, magnesium=1360, nitrate=9.5, nitrite=0, ammonia=0, phosphate=0.07),
        "All major elements sit inside the target ranges for a mature mixed reef. Nitrate is at the upper end of where you want it but not a concern with phosphate this steady.",
        ["Keep the current dosing routine. Alkalinity, calcium and magnesium are all stable.",
         "If nitrate climbs past 10 ppm, add a small carbon dose or an extra 10% water change rather than changing feeding.",
         "Continue testing alkalinity weekly. It is the first parameter to move when consumption changes."],
        None, "No dosing changes - maintain current two-part schedule"),
    analysis(DID, "Display Tank", 68,
        P(salinity=1.0252, temperature=77.8, ph=8.22, alkalinity=8.7, calcium=436, magnesium=1372, nitrate=6.0, nitrite=0, ammonia=0, phosphate=0.04),
        "Textbook numbers for a 90-gallon mixed reef. Salinity is slightly under 1.026; top-off and water change salt should be matched.",
        ["Nudge salinity from 1.0252 to 1.0255-1.026 by mixing the next water change batch a touch stronger.",
         "Everything else is on target. Log the same time of day each week so pH readings compare fairly."],
        None, None),
    analysis(DID, "Display Tank", 100,
        P(salinity=1.0256, temperature=78.4, ph=8.10, alkalinity=8.6, calcium=430, magnesium=1350, nitrate=12.0, nitrite=0, ammonia=0, phosphate=0.12),
        "Phosphate at 0.12 ppm is above the range that keeps SPS colours bright, and nitrate is elevated with it. Major elements are fine.",
        ["Cut phosphate back towards 0.05 ppm with GFO or a lanthanum product, reducing slowly over two weeks.",
         "Rinse frozen food before feeding and check the skimmer is pulling dark skimmate.",
         "Retest phosphate in seven days before making any further change."],
        ["Phosphate 0.12 ppm is above the recommended range for an SPS-dominant reef."],
        "GFO: 1/2 cup in a media reactor, replace fortnightly - lowers phosphate gradually without shocking corals"),
    analysis(DID, "Display Tank", 140,
        P(salinity=1.0260, temperature=78.2, ph=8.25, alkalinity=8.8, calcium=440, magnesium=1380, nitrate=5.0, nitrite=0, ammonia=0, phosphate=0.03),
        "Stable and well balanced. Low nutrients with strong alkalinity and calcium suit the SPS at the top of the scape.",
        ["Maintain the current routine.", "Watch that nitrate does not fall below 2-3 ppm; a little nutrient keeps colours from washing out."],
        None, None),
    analysis(FID, "Frag Tank", 9,
        P(salinity=1.0258, temperature=78.4, ph=8.20, alkalinity=9.0, calcium=442, magnesium=1400, nitrate=3.5, nitrite=0, ammonia=0, phosphate=0.03),
        "Parameters are ideal for a 20-gallon grow-out tank. Alkalinity at 9.0 dKH will encourage fast SPS encrusting.",
        ["Weekly 20% water changes are doing the heavy lifting here. Keep them up.",
         "Test alkalinity twice a week as frags grow; consumption in a small volume rises quickly."],
        None, None),
    analysis(FID, "Frag Tank", 58,
        P(salinity=1.0261, temperature=78.6, ph=8.15, alkalinity=8.9, calcium=435, magnesium=1390, nitrate=5.0, nitrite=0, ammonia=0, phosphate=0.04),
        "Healthy numbers across the board for a nano frag system.",
        ["No changes needed.", "Match salinity of new saltwater to 1.026 before each change."],
        None, None),
]

# ---------------------------------------------------------------- maintenance schedules (local)
schedules = [
    {"id": U(), "tankId": DID, "type": "water_change", "enabled": True, "scheduleKind": "interval_days", "intervalDays": 14,
     "weekdays": None, "timeLocal": "09:00", "timezone": TZ, "notes": "15% (13.5 gal). Mix salt the night before.",
     "anchorDate": iso(days_ago(5, 9, 0)), "createdAt": iso(days_ago(200)), "updatedAt": iso(days_ago(5)), "needsSync": False, "isDeleted": False},
    {"id": U(), "tankId": DID, "type": "testing", "enabled": True, "scheduleKind": "weekly", "intervalDays": None,
     "weekdays": [7], "timeLocal": "09:00", "timezone": TZ, "notes": None,
     "anchorDate": iso(days_ago(200)), "createdAt": iso(days_ago(200)), "updatedAt": iso(days_ago(60)), "needsSync": False, "isDeleted": False},
    {"id": U(), "tankId": FID, "type": "water_change", "enabled": True, "scheduleKind": "weekly", "intervalDays": None,
     "weekdays": [6], "timeLocal": "10:00", "timezone": TZ, "notes": "20% (4 gal)",
     "anchorDate": iso(days_ago(150)), "createdAt": iso(days_ago(150)), "updatedAt": iso(days_ago(150)), "needsSync": False, "isDeleted": False},
]

# ---------------------------------------------------------------- write local documents
def write(name, obj):
    with open(os.path.join(DATA, name), "w") as f: json.dump(obj, f)
for f in os.listdir(DATA): os.remove(os.path.join(DATA, f))
write("tanks.json", tanks_local)
write("measurements.json", {DID: display_meas, FID: frag_meas})
write("water-changes.json", wc_local)
write("livestock.json", livestock)
write("livestock-logs.json", logs)
write("saved-analyses.json", analyses)
write("maintenance-schedules.json", schedules)
json.dump({"display": DID, "frag": FID, "acro": acro, "monti": monti, "torch": torch}, open(os.path.join(os.path.dirname(__file__), "seed-ids.json"), "w"))
print("done", DID, FID, len(display_meas), len(frag_meas), len(livestock), len(logs), len(analyses))
