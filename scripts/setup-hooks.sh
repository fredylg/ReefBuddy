#!/bin/bash
# Point git at the versioned hooks in .githooks/ (pre-commit validates the Xcode project).
# Run once per clone: ./scripts/setup-hooks.sh
set -e
cd "$(dirname "$0")/.."
chmod +x .githooks/*
git config core.hooksPath .githooks
echo "🟢 core.hooksPath = .githooks — the pre-commit hook will validate iOS/ReefBuddy.xcodeproj on every commit."
