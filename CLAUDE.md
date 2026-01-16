# ReefBuddy | Project Intelligence & Standards

## 1. Project Overview
ReefBuddy is a high-contrast, New Brutalist iOS app for saltwater aquarium hobbyists. It uses Cloudflare Workers, D1, and AI to provide water chemistry analysis and dosing recommendations.

## 2. The Team & Roles
- **@ui-brutalist**: Lead Designer/Frontend. Owns `.swift` files and asset catalogs.
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
- **Deploy:** `npx wrangler deploy`

## 8. iOS/Xcode Project Guidelines (CRITICAL)

### Xcode Project Structure
The iOS app uses a manual Xcode project at `iOS/ReefBuddy.xcodeproj/`. The `project.pbxproj` file is critical and must be properly maintained.

### IMPORTANT: When Adding New Swift Files
When @ui-brutalist creates or modifies Swift files, they MUST also update `iOS/ReefBuddy.xcodeproj/project.pbxproj` to include:
1. **PBXBuildFile entry** - for compiling the source file
2. **PBXFileReference entry** - for referencing the file
3. **PBXGroup entry** - for organizing in the correct folder group
4. **Add to PBXSourcesBuildPhase** - to include in the build

### Fixing Missing project.pbxproj
If the project.pbxproj file is missing or corrupted:

1. **Delete and recreate the .xcodeproj directory:**
   ```bash
   rm -rf iOS/ReefBuddy.xcodeproj
   mkdir -p iOS/ReefBuddy.xcodeproj
   ```

2. **Create a fresh project.pbxproj with all Swift files:**
   - List all Swift files: `find iOS/ReefBuddy/Sources -name "*.swift"`
   - Generate proper UUIDs (16-character hex) for each file
   - Include all required sections: PBXBuildFile, PBXFileReference, PBXGroup, PBXNativeTarget, PBXProject, etc.

3. **Required project.pbxproj format:**
   - Must start with `// !$*UTF8*$!`
   - archiveVersion = 1
   - objectVersion = 56
   - Target iOS 18.0+ (`IPHONEOS_DEPLOYMENT_TARGET = 18.0`)
   - iPhone only (`TARGETED_DEVICE_FAMILY = 1`)
   - Bundle ID: `com.reefbuddy.app`

### Current iOS Source Files (update this list when adding files)
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
│   └── BrutalistTextField.swift
├── Models/
│   ├── Tank.swift
│   ├── Measurement.swift
│   └── User.swift
├── Views/
│   ├── TankListView.swift
│   ├── MeasurementEntryView.swift
│   ├── AnalysisView.swift
│   ├── HistoryView.swift
│   ├── ChartView.swift
│   ├── SubscriptionView.swift
│   └── ExportView.swift
└── Networking/
    └── APIClient.swift
```

### Verification
After any iOS file changes, verify the project opens:
```bash
open iOS/ReefBuddy.xcodeproj
```

If it fails with "missing project.pbxproj", follow the fix steps above.
