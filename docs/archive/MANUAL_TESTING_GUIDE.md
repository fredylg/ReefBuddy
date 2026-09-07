# ReefBuddy Manual Testing Guide

**Last Updated:** January 19, 2026
**Tested Changes:**
- Health log timeline persistence
- Livestock saving persistence
- Temperature unit consistency in AI responses
- Livestock list view (removed grid option)
- Stage 1 security remediation (backend)

## Prerequisites

1. **iOS App Installed**: TestFlight build with latest changes
2. **Test Tank**: Create a test tank with some basic parameters
3. **Network Connection**: Ensure app can reach production backend
4. **Test Account**: If needed for advanced features

---

## Test 1: Health Log Timeline Persistence

### Objective
Verify that health logs save correctly and persist across app restarts.

### Steps
1. **Launch App** → Select test tank
2. **Navigate** → Livestock tab → Select a livestock item
3. **Add Health Log**:
   - Tap "Add Log" button
   - Select health status (e.g., "Excellent")
   - Add notes (e.g., "Fish appears healthy and active")
   - Tap "SAVE LOG"
4. **Verify Log Appears**:
   - Log should appear immediately in timeline
   - Check date, health status, and notes display correctly
5. **Force App Close**:
   - Double-click home button → Swipe up to close app
   - Wait 10 seconds
6. **Relaunch App** → Navigate back to same livestock
7. **Verify Persistence**:
   - ✅ Log should still be visible in timeline
   - ✅ All details should be preserved
   - ✅ Timeline should show correct entry count

### Expected Results
- ✅ Health log saves immediately
- ✅ Log persists after app restart
- ✅ Timeline displays logs in correct order (newest first)
- ✅ No duplicate logs created

---

## Test 2: Livestock Creation and Persistence

### Objective
Verify that livestock items save correctly and persist across app restarts.

### Steps
1. **Launch App** → Select test tank
2. **Navigate** → Livestock tab
3. **Add New Livestock**:
   - Tap "+" button (bottom right)
   - Enter name: "Test Clownfish"
   - Scientific name: "Amphiprion ocellaris" (optional)
   - Category: Fish
   - Quantity: 1
   - Health Status: Healthy (should auto-select)
   - Add photo (optional)
   - Notes: "Test fish for validation"
   - Tap "ADD LIVESTOCK"
4. **Verify Livestock Appears**:
   - ✅ Should appear in list immediately
   - ✅ Image, name, category should display
   - ✅ Health status indicator should show
5. **Force App Close** → Relaunch
6. **Verify Persistence**:
   - ✅ Livestock should still be in list
   - ✅ All details preserved
   - ✅ Photo (if added) should still display
7. **Test Health Log on New Livestock**:
   - Tap new livestock → Add health log → Verify it saves

### Expected Results
- ✅ Livestock saves immediately after creation
- ✅ Persists across app restarts
- ✅ Photos save and display correctly
- ✅ Can add health logs to new livestock

---

## Test 3: Temperature Unit Consistency

### Objective
Verify that AI responds in the same temperature unit selected by user.

### Steps
1. **Launch App** → Select test tank
2. **Navigate** → Measurements tab
3. **Enter Water Parameters** (Celsius test):
   - Salinity: 1.025
   - Temperature: 25.5°C (use toggle to select Celsius)
   - pH: 8.2
   - Alkalinity: 8.5 dKH
   - Calcium: 420 ppm
   - Submit measurement
4. **Run Analysis**:
   - Tap "Analyze" button
   - Wait for AI response
   - ✅ Check that temperature recommendations use Celsius
   - ✅ Look for phrases like "25.5°C" or "26-27°C" ranges
5. **Test Fahrenheit**:
   - Enter new measurement with 78.0°F
   - Run analysis
   - ✅ Verify AI responds with Fahrenheit units

### Expected Results
- ✅ AI uses Celsius when user inputs Celsius
- ✅ AI uses Fahrenheit when user inputs Fahrenheit
- ✅ Temperature ranges in recommendations match input unit
- ✅ No mixing of units in responses

---

## Test 4: Livestock List View Changes

### Objective
Verify that livestock list only shows list view (no grid option).

### Steps
1. **Launch App** → Select test tank with multiple livestock
2. **Navigate** → Livestock tab
3. **Check View Options**:
   - ✅ No grid/list toggle buttons in header
   - ✅ Only item count should show ("X ITEMS")
4. **Verify List Format**:
   - ✅ All livestock show as vertical list
   - ✅ Each item shows: photo (left), name, category, quantity, health status
   - ✅ Items are scrollable
   - ✅ Tap any item → Opens detail view
5. **Test Empty State**:
   - Create new tank with no livestock
   - ✅ Shows "NO LIVESTOCK YET" message
   - ✅ "ADD LIVESTOCK" button works

### Expected Results
- ✅ No grid view option available
- ✅ Clean list-only interface
- ✅ All existing functionality preserved
- ✅ Empty state works correctly

---

## Test 5: Settings View Changes

### Objective
Verify that Alerts section is hidden in Settings.

### Steps
1. **Launch App** → Tap profile/settings icon
2. **Navigate** → Settings view
3. **Check Available Sections**:
   - ✅ ACCOUNT section (Subscription)
   - ✅ DATA section (Saved Analyses, Export Data)
   - ✅ ABOUT section (Version info)
   - ❌ ALERTS section should NOT be visible
4. **Verify Other Sections Work**:
   - ✅ Can navigate to Subscription
   - ✅ Saved Analyses shows correct count
   - ✅ Export Data button functional

### Expected Results
- ✅ Alerts section completely hidden
- ✅ Other settings sections functional
- ✅ Clean, simplified settings interface

---

## Test 6: Backend Security Features

### Objective
Verify that backend security changes don't break app functionality.

### Steps
1. **Test Analysis Endpoint**:
   - Submit water chemistry analysis
   - ✅ Should work normally (no CORS errors)
   - ✅ Should receive valid AI response

2. **Test Credit Balance**:
   - Check credit balance in app
   - ✅ Should load without errors
   - ✅ Rate limiting shouldn't interfere with normal use

3. **Test Error Handling**:
   - Try invalid requests
   - ✅ Should receive proper error messages
   - ✅ No sensitive data in error responses

### Expected Results
- ✅ All API calls work normally
- ✅ No CORS or security header issues
- ✅ Error messages are user-friendly
- ✅ No breaking changes from security fixes

---

## Test 7: Cross-Session Persistence

### Objective
Verify that all data persists across app sessions and device restarts.

### Steps
1. **Create Test Data**:
   - Add 2-3 livestock items
   - Add health logs to each
   - Add 2-3 water measurements
   - Run 1-2 analyses

2. **Force App Close** → Wait 30 seconds → Relaunch

3. **Verify All Data**:
   - ✅ All livestock present with photos
   - ✅ All health logs preserved
   - ✅ All measurements in history
   - ✅ Analysis results accessible

4. **Background Test**:
   - Put app in background for 5+ minutes
   - Resume app
   - ✅ All data still present

### Expected Results
- ✅ 100% data persistence
- ✅ No data loss on app close/resume
- ✅ Photos and complex data preserved

---

## Test Results Template

**Test Session:** [Date/Time]
**Device:** [iPhone model/iOS version]
**App Version:** [Version number]

### Test Results Summary

| Test | Status | Notes |
|------|--------|-------|
| Health Log Persistence | ☐ | |
| Livestock Persistence | ☐ | |
| Temperature Units | ☐ | |
| Livestock List View | ☐ | |
| Settings View | ☐ | |
| Backend Security | ☐ | |
| Cross-Session Persistence | ☐ | |

### Issues Found
- List any bugs, unexpected behavior, or failed tests

### Screenshots Taken
- List any screenshots captured during testing

---

## Common Issues to Watch For

1. **Health logs not saving**: Check that "SAVE LOG" button was tapped
2. **Livestock not appearing**: Verify tank selection and app restart
3. **Temperature unit mismatch**: Ensure unit toggle was used before analysis
4. **Grid view showing**: App may need restart after update
5. **CORS errors**: Check network connection and backend status
6. **Rate limiting**: May trigger during rapid testing (429 errors)

---

## Testing Checklist

### Pre-Test Setup
- [ ] App updated to latest TestFlight build
- [ ] Test tank created with basic parameters
- [ ] Network connection stable
- [ ] Sufficient battery for extended testing

### Post-Test Cleanup
- [ ] Remove test livestock created during testing
- [ ] Clear test measurements if needed
- [ ] Reset any modified settings
- [ ] Document any issues found

---

## Contact Information

**Bug Reports:** [Your contact method]
**Test Results:** [Where to submit results]
**Questions:** [Support contact]

---

*This guide covers all changes from the recent development cycle. Update this document as new features are added.*