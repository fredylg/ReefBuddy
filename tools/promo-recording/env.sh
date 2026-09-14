# Shared settings for the promo recording scripts. Source this file.
KIT="$(cd "$(dirname "${(%):-%N}")" && pwd)"
REPO="$(cd "$KIT/../.." && pwd)"
WORK="${PROMO_WORK:-$HOME/ReefBuddy-Promo}"          # build products, marks, recordings
SIM="${PROMO_SIM:-$(xcrun simctl list devices available | grep -m1 'iPhone 17 Pro (' | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')}"
BUNDLE=au.com.aethers.reefbuddy
DEVICE_ID_FILE="$WORK/device-id.txt"
mkdir -p "$WORK/out/raw" "$WORK/out/final" "$WORK/out/story" "$WORK/marks"
container(){ xcrun simctl get_app_container "$SIM" $BUNDLE data; }
appsupport(){ echo "$(container)/Library/Application Support"; }
