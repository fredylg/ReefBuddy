#!/bin/bash

# ReefBuddy In-App Purchase Setup Script
# This script helps configure IAP for both development and production

set -e

echo "🚀 ReefBuddy In-App Purchase Setup"
echo "=================================="

# Check if Xcode project exists
if [ ! -f "iOS/ReefBuddy.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: Xcode project not found. Run this script from the project root."
    exit 1
fi

echo "✅ Found Xcode project"

# Check if StoreKit files exist
if [ ! -f "iap-configuration/ReefBuddy.storekit" ]; then
    echo "❌ Error: StoreKit configuration file not found."
    exit 1
fi

echo "✅ Found StoreKit configuration files"

# Copy StoreKit file to Xcode project directory (user needs to import manually)
echo ""
echo "📋 Next Steps:"
echo "1. Open Xcode: open iOS/ReefBuddy.xcodeproj"
echo "2. Add In-App Purchase capability to the ReefBuddy target"
echo "3. Import iap-configuration/ReefBuddy.storekit into Xcode"
echo "4. Configure StoreKit testing in Product → Scheme → Edit Scheme"
echo ""
echo "For App Store Connect:"
echo "1. Go to https://appstoreconnect.apple.com"
echo "2. Create the following IAP products:"
echo "   - com.reefbuddy.credits5 (Consumable, $0.99)"
echo "   - com.reefbuddy.credits50 (Consumable, $4.99)"
echo "3. Add screenshots and submit for review"
echo ""
echo "🎉 Setup complete! Check the README.md for detailed instructions."