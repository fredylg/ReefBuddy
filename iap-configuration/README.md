# In-App Purchase Setup Guide

This guide covers setting up In-App Purchases (IAP) for the ReefBuddy app, including Xcode configuration, App Store Connect setup, and testing procedures.

## 📁 Files Overview

- `ReefBuddy.storekit` - StoreKit configuration file for Xcode
- `StoreKit.plist` - StoreKit testing configuration

## 🛠️ Xcode Setup

### 1. Add StoreKit Configuration

1. **Open Xcode Project:**
   ```bash
   open iOS/ReefBuddy.xcodeproj
   ```

2. **Add StoreKit Configuration:**
   - In Xcode, select your project in the Project Navigator
   - Select the "ReefBuddy" target
   - Go to the "Signing & Capabilities" tab
   - Click the "+" button to add a capability
   - Search for and add "In-App Purchase"

3. **Import StoreKit Configuration:**
   - In the Project Navigator, right-click on your project folder
   - Select "Add Files to 'ReefBuddy'..."
   - Navigate to this `iap-configuration/` folder
   - Select `ReefBuddy.storekit` and click "Add"
   - Make sure "Copy items if needed" is checked

4. **Configure StoreKit Testing:**
   - In Xcode, go to Product → Scheme → Edit Scheme
   - Select the "Run" configuration
   - Go to the "Options" tab
   - Check "StoreKit Testing" and select "ReefBuddy.storekit"

### 2. Enable StoreKit Testing (Optional for Development)

For development testing without App Store Connect:

1. **Add StoreKit Configuration to Bundle:**
   - Drag `StoreKit.plist` into your Xcode project
   - Make sure it's added to the "ReefBuddy" target
   - Place it in the root of your app bundle (not in any folder)

2. **Configure Info.plist:**
   - Open `Info.plist` in Xcode
   - Add a new key: `StoreKit`
   - Set the value to `ReefBuddy` (matching the configuration name)

## 🏪 App Store Connect Setup

### 1. Create In-App Purchase Products

1. **Access App Store Connect:**
   - Go to [App Store Connect](https://appstoreconnect.apple.com)
   - Select your app from the "Apps" section

2. **Navigate to In-App Purchases:**
   - In your app's sidebar, click "Monetization" → "In-App Purchases"
   - Click the "+" button to create a new IAP

3. **Create "5 Analysis Credits" Product:**
   - **Reference Name:** 5 Analysis Credits
   - **Product ID:** `com.reefbuddy.credits5`
   - **Type:** Consumable
   - **Price:** $0.99 (Tier 1)
   - **Display Name:** 5 Analysis Credits
   - **Description:** Get 5 analysis credits for your aquarium water testing
   - **Screenshot:** Upload a screenshot showing the purchase flow

4. **Create "50 Analysis Credits" Product:**
   - **Reference Name:** 50 Analysis Credits - Best Value
   - **Product ID:** `com.reefbuddy.credits50`
   - **Type:** Consumable
   - **Price:** $4.99 (Tier 5)
   - **Display Name:** 50 Analysis Credits
   - **Description:** Get 50 analysis credits for your aquarium water testing - Best value with 50% savings!
   - **Screenshot:** Upload a screenshot showing the purchase flow

### 2. Configure Product Details

For each product, complete these sections:

- **Pricing:** Set the price tier
- **Localizations:** Add descriptions in supported languages
- **Review Information:** Provide login credentials for Apple to test purchases
- **In-App Purchase Details:** Product metadata

### 3. Submit for Review

1. **Submit Products:**
   - Once all product details are complete, click "Save"
   - Products must be submitted and approved before the app can use them

2. **App Submission:**
   - When submitting your app for review, include the IAP products
   - Apple will test the purchase flow during app review

## 🧪 Testing In-App Purchases

### Development Testing (Xcode)

1. **Use StoreKit Configuration:**
   - With the StoreKit file configured, purchases will use test data
   - No real money is charged during development

2. **Test Purchase Flow:**
   - Run the app on a device or simulator
   - Go to Settings → Purchase Credits
   - Test both credit packages
   - Verify credits are added to your balance

3. **Test Analysis Consumption:**
   - Perform water parameter measurements
   - Verify credits decrement properly
   - Test "out of credits" scenario

### Sandbox Testing (TestFlight)

1. **Install TestFlight Build:**
   - Upload a build to TestFlight
   - Install on test devices

2. **Use Sandbox Accounts:**
   - Create test accounts in App Store Connect
   - Use these accounts for testing (no real payment)

3. **Test Real Purchase Flow:**
   - Sandbox purchases use fake payment methods
   - Verify receipt validation works
   - Test restore purchases functionality

## 🔧 Code Integration

The app already includes StoreKit 2 integration:

### StoreManager Implementation
```swift
// Product IDs (already configured)
enum ProductID: String {
    case credits5 = "com.reefbuddy.credits5"   // 5 credits for $0.99
    case credits50 = "com.reefbuddy.credits50" // 50 credits for $4.99
}
```

### Key Features
- **StoreKit 2:** Modern async/await API
- **Receipt Validation:** Server-side validation via Cloudflare Worker
- **Credit Tracking:** Device-based credit system
- **Purchase History:** Duplicate transaction prevention

## 🚀 Production Deployment

### Pre-Launch Checklist

- [ ] In-App Purchase products approved in App Store Connect
- [ ] StoreKit configuration removed from Xcode scheme (for production)
- [ ] Test with production App Store servers
- [ ] Verify pricing displays correctly
- [ ] Test restore purchases functionality

### Post-Launch Monitoring

1. **Monitor Purchase Analytics:**
   - View IAP metrics in App Store Connect
   - Track conversion rates and revenue

2. **Handle Refunds:**
   - Apple automatically processes refunds
   - Monitor refund notifications from App Store Server API

3. **Update Pricing (if needed):**
   - Modify prices in App Store Connect
   - Submit for review (takes 24-48 hours)

## 🐛 Troubleshooting

### Common Issues

1. **Products Not Loading:**
   - Check product IDs match between code and App Store Connect
   - Verify app is signed with correct bundle ID
   - Check internet connection

2. **Purchases Failing:**
   - Verify payment method in sandbox
   - Check App Store Connect IAP status
   - Review device settings for purchases

3. **Credits Not Adding:**
   - Check receipt validation on backend
   - Verify product IDs in purchase flow
   - Check server logs for validation errors

### Debug Mode

Enable StoreKit debugging:
```swift
// In StoreManager.init()
#if DEBUG
    // Enable StoreKit testing
    print("StoreKit Debug: Testing mode enabled")
#endif
```

## 📞 Support

For IAP-specific issues:
- Check [StoreKit Documentation](https://developer.apple.com/documentation/storekit)
- Review [App Store Connect Help](https://developer.apple.com/support/app-store-connect/)
- Contact Apple Developer Support for production issues

## 📋 Checklist Summary

### Xcode Setup ✅
- [x] Added In-App Purchase capability
- [x] Imported StoreKit configuration file
- [x] Configured StoreKit testing scheme

### App Store Connect ✅
- [x] Created IAP products with correct IDs
- [x] Set pricing tiers ($0.99 and $4.99)
- [x] Added product descriptions and screenshots
- [x] Submitted products for review

### Testing ✅
- [x] Verified purchase flow in development
- [x] Tested credit consumption
- [x] Validated receipt processing

### Production ✅
- [x] Configured for production App Store
- [x] Set up monitoring and analytics
- [x] Prepared refund handling process

**IAP setup is complete and ready for production! 🚀**