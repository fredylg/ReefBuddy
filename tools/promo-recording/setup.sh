#!/bin/zsh
# One-time setup: boot the simulator, build + install the app, start the dev backend, seed data,
# build the UI-test harness and grant notification permission. Run from anywhere.
set -e
source "$(dirname "$0")/env.sh"
xcrun simctl boot "$SIM" 2>/dev/null || true; open -a Simulator
echo "· building ReefBuddy (Debug, simulator)"
xcodebuild -project "$REPO/iOS/ReefBuddy.xcodeproj" -scheme ReefBuddy -configuration Debug -destination "id=$SIM" -derivedDataPath "$WORK/dd-app" build -quiet
xcrun simctl install "$SIM" "$WORK/dd-app/Build/Products/Debug-iphonesimulator/ReefBuddy.app"
echo "· local backend (wrangler dev --host localhost so the simulator DeviceCheck bypass applies)"
if ! curl -sf --max-time 3 http://localhost:8787/health >/dev/null; then
  (cd "$REPO" && npm run db:migrate >/dev/null && (npx wrangler dev --env dev --host localhost > "$WORK/wrangler-dev.log" 2>&1 &))
  for i in {1..30}; do curl -sf --max-time 2 http://localhost:8787/health >/dev/null && break; sleep 1; done
fi
echo "· first launch to create the device id"
xcrun simctl launch "$SIM" $BUNDLE >/dev/null; sleep 6; xcrun simctl terminate "$SIM" $BUNDLE
DEVICE_ID=$(cd "$REPO" && npx wrangler d1 execute reef-db --local --env dev --json --command "select device_id from device_credits order by created_at desc limit 1" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['results'][0]['device_id'])")
echo "$DEVICE_ID" > "$DEVICE_ID_FILE"; echo "  device id $DEVICE_ID"
echo "· photos + seed"
[ -f "$KIT/photos/clown.jpg" ] || "$KIT/fetch-photos.sh"
python3 "$KIT/seed.py" "$DEVICE_ID" "$(container)" "$KIT/photos"
rm -rf "$WORK/seed-backup"; mkdir -p "$WORK/seed-backup"; cp -R "$(appsupport)/ReefBuddy" "$(appsupport)/LivestockImages" "$WORK/seed-backup/"
python3 - "$WORK/seed-backup/ReefBuddy/Data/tanks.json" <<'PY'
import json,sys; p=sys.argv[1]; t=json.load(open(p)); t.sort(key=lambda x: x['name']!='Display Tank'); json.dump(t,open(p,'w'))
PY
echo "· UI test harness"
(cd "$KIT/uitest" && xcodegen generate >/dev/null && xcodebuild -project ReefBuddyPromo.xcodeproj -scheme Promo -destination "id=$SIM" -derivedDataPath "$WORK/dd-ui" build-for-testing -quiet)
"$KIT/run.sh" testSetupNotifications
echo "setup done"
