# ReefBuddy | Project Intelligence & Standards

## ⚠️ CRITICAL - READ FIRST ⚠️

### NEVER TOUCH THESE FILES (ALL AGENTS)
The following files are **SACRED** and must NEVER be deleted, moved, or recreated:
- **`iOS/ReefBuddy.xcodeproj/project.pbxproj`** - The Xcode project file
- **DO NOT use `rm`, `mv`, or recreate the `.xcodeproj` directory**
- **DO NOT suggest recreating the Xcode project**
- **If you need to add Swift files, UPDATE the existing pbxproj, don't recreate it**

### Before ANY iOS Work (ALL AGENTS)
Run the verification script FIRST:
```bash
./verify-xcode-project.sh
```

Or the quick check:
```bash
test -f "iOS/ReefBuddy.xcodeproj/project.pbxproj" && echo "✅ Safe to proceed" || echo "❌ STOP - File missing!"
```

If the script fails or file is missing, **STOP IMMEDIATELY** and alert the user.

### After ANY iOS Work (ALL AGENTS)
Run the verification script LAST:
```bash
./verify-xcode-project.sh
```

Or the quick check:
```bash
test -f "iOS/ReefBuddy.xcodeproj/project.pbxproj" && wc -l "iOS/ReefBuddy.xcodeproj/project.pbxproj"
```

The file should have ~477+ lines. If missing or <100 lines, **STOP** and restore from git:
```bash
git checkout HEAD -- iOS/ReefBuddy.xcodeproj/project.pbxproj
```

---

## 1. Project Overview
ReefBuddy is a high-contrast, New Brutalist iOS app for saltwater aquarium hobbyists. It uses Cloudflare Workers, D1, and AI to provide water chemistry analysis and dosing recommendations.

## 2. The Team & Roles
- **@ui-brutalist**: Lead Designer/Frontend. Owns `.swift` files, asset catalogs, AND `project.pbxproj`. **CRITICAL: Must update Xcode project whenever adding/removing Swift files.**
- **@edge-engineer**: Backend Architect. Owns `src/index.ts`, `wrangler.toml`, and AI integration.
- **@data-steward**: Database Admin. Owns `migrations/`, SQL schemas, and data integrity.
- **@tester-agent**: Quality Assurance. Owns `tests/`, automation scripts, and verification.

## 3. The "Definition of Done" (DoD)
A task is not complete until:
1. The developer agent (@ui-brutalist or @edge-engineer) implements the feature.
2. The **@tester-agent** creates and runs an automated script (Vitest/XCTest).
3. The **@tester-agent** confirms success. If it fails, the task is reverted to "In Progress" and assigned back to the developer with error logs.

## 4. Design Manifesto (New Brutalism)
- **Palette:** - Background: `#FFFFFF` (Pure White)
  - Text/Accents: `#000000` (Pure Black)
  - Action: `#00FFD1` (Electric Aquamarine)
  - Warning/Alert: `#FF3D00` (Safety Orange)
- **Visuals:** - Borders: Strict `3pt` or `4pt` solid black on all elements.
  - Radius: `0px` (Sharp corners only).
  - Shadows: Hard offset `5pt 5pt` black shadows. No blurs, no gradients.
- **Typography:** Bold, oversized headers. Use Grotesque sans-serif fonts.

## 5. Technical Stack & Constraints
- **Backend:** Cloudflare Workers (TypeScript/ES Modules).
- **Database:** Cloudflare D1 (SQLite at the edge).
- **Logic:** Workers KV for session tracking and Free Tier limits (3/month).
- **AI Gateway:** All LLM calls (Claude-3.5-Sonnet) must route through Cloudflare AI Gateway for caching.
- **Validation:** Use `Zod` for all incoming API request schemas.

## 6. Communication & Workflow
- **Task Tracking:** Always check `PLAN.md` before starting work.
- **State Management:** Update `PLAN.md` status:
  - `[ ]` To Do
  - `[/]` In Progress (Developer)
  - `[!]` Awaiting QA / Testing
  - `[x]` Verified & Done (Tester Only)
- **Handoffs:** When a feature is ready for QA, the developer must provide the **@tester-agent** with the specific file paths and expected behavior.

## 7. Development Commands
- **Local Dev:** `npx wrangler dev`
- **Database:** `npx wrangler d1 migrations apply reef-db --local`
- **Test Execution:** `npx vitest run` (Backend) | `xcodebuild test` (iOS)
- **Deploy Backend:** `npx wrangler deploy`
- **Deploy Website:** `npx wrangler pages deploy web --project-name reefbuddy-site`
- **Verify Xcode Project:** `./verify-xcode-project.sh` (Run before/after ANY iOS work)
- **Setup Git Hooks:** `./setup-hooks.sh` (Enables pre-commit validation to prevent UUID collisions)

## 8. Promotional Website

### Overview
Single-page promotional website hosted on Cloudflare Pages at https://reefbuddy-site.pages.dev

### File Structure
```
web/
├── index.html    # Single-page promotional site
├── style.css     # New Brutalist CSS design system
└── README.md     # Website documentation
```

### Design System
The website uses the same New Brutalist design as the iOS app:
- **Colors:** `#FFFFFF` (white), `#000000` (black), `#00FFD1` (aquamarine), `#FF3D00` (orange)
- **Borders:** 3-4pt solid black
- **Corners:** 0px radius (sharp only)
- **Shadows:** Hard offset 5px 5px, no blur
- **Typography:** Space Grotesk (grotesque sans-serif)

### Deployment
```bash
# Deploy to Cloudflare Pages
npx wrangler pages deploy web --project-name reefbuddy-site
```

### Local Preview
```bash
open web/index.html
# or
npx serve web
```

## 9. iOS/Xcode Project Guidelines (CRITICAL)

### 🚨 ABSOLUTE RULE: NEVER DELETE OR RECREATE project.pbxproj 🚨
**The file `iOS/ReefBuddy.xcodeproj/project.pbxproj` must NEVER be deleted, moved, or recreated under ANY circumstances.**

If you think you need to recreate it, **YOU ARE WRONG**. Stop and ask the user instead.

### ⚠️ MANDATORY FOR ALL AGENTS DOING iOS WORK ⚠️

#### STEP 1: Before Starting ANY iOS Work
```bash
# Run this FIRST - if it fails, STOP and alert user
test -f "iOS/ReefBuddy.xcodeproj/project.pbxproj" && echo "✅ Safe to proceed" || echo "❌ STOP!"

# Optional: Enable automatic git validation (recommended)
./setup-hooks.sh
```

#### STEP 2: Do Your iOS Work
When @ui-brutalist creates or modifies Swift files, EDIT the existing `project.pbxproj` to add:
1. **PBXBuildFile entry** - for compiling the source file
2. **PBXFileReference entry** - for referencing the file
3. **PBXGroup entry** - for organizing in the correct folder group
4. **Add to PBXSourcesBuildPhase** - to include in the build

**⚠️ CRITICAL: UUID Uniqueness Check**
- **ALWAYS verify UUID uniqueness** before adding new entries to project.pbxproj
- UUID collisions cause Xcode to crash immediately on project open
- Check for duplicates: `grep "8A1B2C3D000000XX" iOS/ReefBuddy.xcodeproj/project.pbxproj | wc -l` (should be 1)
- Use unique UUIDs following the pattern: `8A1B2C3D000000XX` where XX is a unique hex value
- **Example collision that caused crash:** UUID `8A1B2C3D00000030` was used for both root PBXGroup AND AddLivestockView.swift → Xcode crash
- **Fix:** Changed AddLivestockView.swift to use `8A1B2C3D00000031A` (unique)

**NEVER use `rm -rf iOS/ReefBuddy.xcodeproj`**
**NEVER recreate the directory**
**ONLY EDIT the existing file**

#### STEP 3: After Completing ANY iOS Work
```bash
# Verify the file still exists and is valid
test -f "iOS/ReefBuddy.xcodeproj/project.pbxproj" && wc -l "iOS/ReefBuddy.xcodeproj/project.pbxproj"
# Should show ~500+ lines
```

If the file is missing or has <100 lines:
```bash
# Restore from git IMMEDIATELY
git checkout HEAD -- iOS/ReefBuddy.xcodeproj/project.pbxproj
```

### @ui-brutalist Mandatory Checklist (EVERY iOS Task)
Before marking any iOS task complete, @ui-brutalist MUST verify:
- [ ] Run pre-flight check: `test -f "iOS/ReefBuddy.xcodeproj/project.pbxproj"`
- [ ] All new Swift files have PBXFileReference entries in existing pbxproj
- [ ] All new Swift files have PBXBuildFile entries in existing pbxproj
- [ ] All new Swift files are in correct PBXGroup in existing pbxproj
- [ ] All new Swift files are in PBXSourcesBuildPhase in existing pbxproj
- [ ] **UUID uniqueness verified** - Check that all new UUIDs are unique: `grep "8A1B2C3D000000" iOS/ReefBuddy.xcodeproj/project.pbxproj | sort | uniq -d` (should return nothing)
- [ ] Run post-flight check: `wc -l "iOS/ReefBuddy.xcodeproj/project.pbxproj"` (should be ~500+ lines)
- [ ] Update the "Current iOS Source Files" list in this document
- [ ] **NEVER ran `rm`, `mv`, or recreated the `.xcodeproj` directory**

### Xcode Project Structure
The iOS app uses a manual Xcode project at `iOS/ReefBuddy.xcodeproj/`. The `project.pbxproj` file is critical and must be properly maintained BY EDITING IT, not recreating it.

### Emergency Recovery ONLY (If File Is Missing)
**ONLY if the file is truly missing and git restore fails:**
```bash
# Last resort - restore from git
git checkout HEAD -- iOS/ReefBuddy.xcodeproj/project.pbxproj

# If that fails, alert the user immediately
# DO NOT attempt to recreate the file yourself
```

### Current iOS Source Files (update this list when adding files)
**Total: 28 Swift files** (verify with: `find iOS/ReefBuddy/Sources -name "*.swift" | wc -l`)
```
iOS/ReefBuddy/Sources/
├── App/
│   ├── ReefBuddyApp.swift
│   ├── ContentView.swift
│   └── AppIconGenerator.swift
├── Theme/
│   └── BrutalistTheme.swift
├── Components/
│   ├── BrutalistButton.swift
│   ├── BrutalistTextField.swift
│   ├── BrutalistLoadingView.swift    # IAP Credits loading indicator
│   └── ShareSheet.swift
├── Models/
│   ├── Tank.swift
│   ├── Measurement.swift
│   ├── User.swift
│   ├── Livestock.swift
│   └── SavedAnalysis.swift           # Saved AI analyses model
├── Views/
│   ├── TankListView.swift
│   ├── MeasurementEntryView.swift
│   ├── AnalysisView.swift
│   ├── HistoryView.swift
│   ├── ChartView.swift
│   ├── PurchaseCreditsView.swift     # IAP Credits purchase UI
│   ├── SavedAnalysesView.swift       # View saved AI analyses
│   ├── ExportView.swift
│   ├── LivestockListView.swift
│   ├── LivestockDetailView.swift
│   ├── AddLivestockView.swift
│   └── NotificationSettingsView.swift
├── Store/
│   ├── StoreManager.swift            # IAP Credits (StoreKit 2)
│   └── AnalysisStorage.swift         # Local persistence for saved analyses
└── Networking/
    └── APIClient.swift
```

### Verification
After any iOS file changes, verify the project opens:
```bash
open iOS/ReefBuddy.xcodeproj
```

If it fails with "missing project.pbxproj", follow the fix steps above.

### Common Issues & Solutions

#### Xcode Crashes on Project Open
**Symptom:** Xcode shows "The project is damaged and cannot be opened" with errors like "unrecognized selector sent to instance".

**Common Causes:**
1. **UUID Collision (CRITICAL):** Two or more entries share the same UUID
   - **Check:** `grep "8A1B2C3D000000" iOS/ReefBuddy.xcodeproj/project.pbxproj | sort | uniq -d`
   - **Fix:** Change the duplicate UUID to a unique value (e.g., increment the hex value)
   - **Example:** UUID `8A1B2C3D00000031` was used for both PBXGroup and PBXBuildFile → crash with "unrecognized selector" error

2. **Invalid iOS Deployment Target:** Using non-existent iOS version (e.g., iOS 18.0)
   - **Check:** `grep "IPHONEOS_DEPLOYMENT_TARGET" iOS/ReefBuddy.xcodeproj/project.pbxproj`
   - **Fix:** Use valid iOS version (e.g., 16.0, 17.0)

3. **Corrupted User Data:** Corrupted xcuserdata folders
   - **Fix:** `rm -rf iOS/ReefBuddy.xcodeproj/project.xcworkspace/xcuserdata iOS/ReefBuddy.xcodeproj/xcuserdata`

4. **Workspace File Issue:** Invalid contents.xcworkspacedata
   - **Check:** Should use `location = "self:"` not `location = "group:ReefBuddy.xcodeproj"`

**Prevention:** Always verify UUID uniqueness before committing changes to project.pbxproj.
