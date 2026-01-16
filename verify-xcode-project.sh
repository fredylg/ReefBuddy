#!/bin/bash
# Xcode Project Verification Script
# ALL AGENTS must run this before AND after ANY iOS work

set -e

PBXPROJ_PATH="iOS/ReefBuddy.xcodeproj/project.pbxproj"
MIN_LINES=100
EXPECTED_LINES=500

echo "🔍 Verifying Xcode project integrity..."

# Check if file exists
if [ ! -f "$PBXPROJ_PATH" ]; then
    echo "❌ CRITICAL ERROR: project.pbxproj is MISSING!"
    echo "📍 Expected location: $PBXPROJ_PATH"
    echo ""
    echo "🚨 STOP ALL WORK IMMEDIATELY"
    echo ""
    echo "Recovery steps:"
    echo "1. git checkout HEAD -- $PBXPROJ_PATH"
    echo "2. If that fails, alert the user"
    echo "3. DO NOT attempt to recreate the file"
    exit 1
fi

echo "✅ File exists: $PBXPROJ_PATH"

# Check file size
LINE_COUNT=$(wc -l < "$PBXPROJ_PATH" | tr -d ' ')
echo "📊 Line count: $LINE_COUNT lines"

if [ "$LINE_COUNT" -lt "$MIN_LINES" ]; then
    echo "❌ CRITICAL ERROR: File is too small ($LINE_COUNT < $MIN_LINES lines)"
    echo "🚨 File may be corrupted or empty"
    echo ""
    echo "Recovery steps:"
    echo "1. git checkout HEAD -- $PBXPROJ_PATH"
    echo "2. If that fails, alert the user"
    exit 1
fi

if [ "$LINE_COUNT" -lt "$EXPECTED_LINES" ]; then
    echo "⚠️  WARNING: File is smaller than expected ($LINE_COUNT < $EXPECTED_LINES lines)"
    echo "This might be okay, but verify all Swift files are referenced"
fi

# Check file format
FIRST_LINE=$(head -n 1 "$PBXPROJ_PATH")
if [ "$FIRST_LINE" != "// !\$*UTF8*\$!" ]; then
    echo "❌ CRITICAL ERROR: Invalid file format"
    echo "Expected first line: // !\$*UTF8*\$!"
    echo "Actual first line: $FIRST_LINE"
    echo ""
    echo "Recovery: git checkout HEAD -- $PBXPROJ_PATH"
    exit 1
fi

echo "✅ File format is valid"

# Count Swift file references
SWIFT_REF_COUNT=$(grep -c "\.swift" "$PBXPROJ_PATH" || true)
ACTUAL_SWIFT_COUNT=$(find iOS/ReefBuddy/Sources -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')

echo "📦 Swift files in project: $ACTUAL_SWIFT_COUNT"
echo "📝 Swift references in pbxproj: $SWIFT_REF_COUNT"

if [ "$SWIFT_REF_COUNT" -lt "$((ACTUAL_SWIFT_COUNT * 2))" ]; then
    echo "⚠️  WARNING: Expected at least $((ACTUAL_SWIFT_COUNT * 2)) Swift references"
    echo "(Each Swift file needs multiple entries: PBXBuildFile, PBXFileReference, etc.)"
fi

echo ""
echo "✅ ALL CHECKS PASSED"
echo "🟢 Safe to proceed with Xcode project"
