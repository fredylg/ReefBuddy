#!/bin/zsh
# Restore the seeded state before a take: local documents, local D1 rows, credits.
source "$(dirname "$0")/env.sh"
DEVICE_ID=$(cat "$DEVICE_ID_FILE")
xcrun simctl terminate "$SIM" $BUNDLE 2>/dev/null || true
rm -rf "$(appsupport)/ReefBuddy" "$(appsupport)/LivestockImages"
cp -R "$WORK/seed-backup/ReefBuddy" "$WORK/seed-backup/LivestockImages" "$(appsupport)/"
cd "$REPO" && npx wrangler d1 execute reef-db --local --env dev --command "UPDATE device_credits SET free_used=0, paid_credits=0 WHERE device_id='$DEVICE_ID'; DELETE FROM measurements WHERE measured_at > '2026-09-08T00:00:00Z'; DELETE FROM water_changes WHERE performed_at > '2026-09-08T00:00:00Z'; DELETE FROM tanks WHERE name NOT IN ('Display Tank','Frag Tank');" >/dev/null 2>&1 || echo "d1 reset failed"
