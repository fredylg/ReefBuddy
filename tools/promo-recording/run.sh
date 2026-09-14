#!/bin/zsh
# usage: run.sh <testName> [record]
# Resets the seeded state, runs one Stories test, optionally records the simulator and trims the
# video to the test's start/end marks. Outputs: out/final/<test>.mp4 (phone) and out/story/<test>_story.mp4 (1080x1920).
source "$(dirname "$0")/env.sh"
T=$1; REC=$2
XCT=$(ls "$WORK"/dd-ui/Build/Products/*.xctestrun | head -1)
rm -f "$WORK/marks/$T.start" "$WORK/marks/$T.end" "$WORK/marks/$T.push"
"$KIT/reset.sh"
if [[ "$REC" == "record" ]]; then
  xcrun simctl io "$SIM" recordVideo --codec h264 --force "$WORK/out/raw/$T.mp4" > "$WORK/marks/$T.rec.log" 2>&1 &
  RECPID=$!
  python3 -c "import time; print(time.time())" > "$WORK/marks/$T.recstart"
  sleep 1.5
fi
( while [[ ! -f "$WORK/marks/$T.end" ]]; do
    if [[ -f "$WORK/marks/$T.push" ]]; then xcrun simctl push "$SIM" $BUNDLE "$KIT/push.json" >/dev/null 2>&1; rm -f "$WORK/marks/$T.push"; fi
    sleep 0.3
  done ) &
WATCH=$!
TEST_RUNNER_OUT_DIR="$WORK" xcodebuild test-without-building -xctestrun "$XCT" -destination "id=$SIM" -only-testing:ReefBuddyPromoUITests/Stories/$T 2>&1 | grep -E "error:|failed|passed \(" | head -20
kill $WATCH 2>/dev/null
if [[ "$REC" == "record" ]]; then
  sleep 1; kill -INT $RECPID; wait $RECPID 2>/dev/null
  python3 - "$WORK" "$T" <<'PY'
import sys, subprocess
W, T = sys.argv[1], sys.argv[2]
rd = lambda n: float(open(f"{W}/marks/{T}.{n}").read())
rec, st, en = rd("recstart"), rd("start"), rd("end")
ss = max(0.0, st - rec - 0.4); dur = (en - st) + 0.8
raw, fin, story = f"{W}/out/raw/{T}.mp4", f"{W}/out/final/{T}.mp4", f"{W}/out/story/{T}_story.mp4"
subprocess.run(["ffmpeg","-y","-loglevel","error","-ss",f"{ss:.2f}","-i",raw,"-t",f"{dur:.2f}","-c:v","libx264","-preset","medium","-crf","18","-pix_fmt","yuv420p","-r","30","-an",fin], check=True)
subprocess.run(["ffmpeg","-y","-loglevel","error","-i",fin,"-vf","scale=-2:1920,pad=1080:1920:(ow-iw)/2:0:white","-c:v","libx264","-crf","18","-pix_fmt","yuv420p",story], check=True)
print(f"video {T}: {dur:.1f}s -> {fin}")
PY
fi
