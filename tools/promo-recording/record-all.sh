#!/bin/zsh
# Records every story in order. ~25 minutes. Results in $WORK/out/final and $WORK/out/story.
source "$(dirname "$0")/env.sh"
for t in testS01LogParameters testS02TargetHints testS03AIAnalysis testS04Warnings testS05TrendCharts testS06Export testS07Reminders testS08WaterChange testS09Livestock testS10HealthLog testS11Tanks testS12SavedAnalyses testS13Credits testS14Montage; do
  echo "== $t $(date +%H:%M:%S)"; "$KIT/run.sh" $t record
done
