# ReefBuddy Implementation Roadmap

## Phase 1: Foundation & Infrastructure (Current)
- [ ] **Infrastructure Setup** (@edge-engineer)
    - Initialize `wrangler.toml` with D1 and KV namespaces.
    - Set up Cloudflare AI Gateway routing.
- [!] **Database Schema Design** (@data-steward) -- Awaiting QA
    - Create `0001_initial_schema.sql` (Tables: `users`, `tanks`, `measurements`, `livestock`).
    - Define SQLite types for water parameters (pH, Alk, Cal, Mag, NO3, PO4).
    - `0002_schema_updates.sql`: Added ammonia, category, deleted_at, password_hash columns.
    - **@tester-agent**: Verify files at `migrations/0001_initial_schema.sql` and `migrations/0002_schema_updates.sql`.
- [!] **Brutalist UI Kit** (@ui-brutalist) -- Awaiting QA
    - Define `BrutalistTheme.swift` (Colors, Border Widths, Hard Shadows).
    - Create reusable `BrutalistButton` and `BrutalistTextField` components.
    - Create complete iOS app structure with SwiftUI App protocol.
    - Implement data models, views, and networking layer.
    
    **@tester-agent**: Verify the following files:
    - **Xcode Project**: `iOS/ReefBuddy.xcodeproj/project.pbxproj`
    - **App Entry Point**: `iOS/ReefBuddy/Sources/App/ReefBuddyApp.swift`
    - **Root View**: `iOS/ReefBuddy/Sources/App/ContentView.swift`
    - **Icon Generator**: `iOS/ReefBuddy/Sources/App/AppIconGenerator.swift`
    - **Theme**: `iOS/ReefBuddy/Sources/Theme/BrutalistTheme.swift`
    - **Components**: 
        - `iOS/ReefBuddy/Sources/Components/BrutalistButton.swift`
        - `iOS/ReefBuddy/Sources/Components/BrutalistTextField.swift`
    - **Models**:
        - `iOS/ReefBuddy/Sources/Models/Tank.swift`
        - `iOS/ReefBuddy/Sources/Models/Measurement.swift`
    - **Views**:
        - `iOS/ReefBuddy/Sources/Views/TankListView.swift`
        - `iOS/ReefBuddy/Sources/Views/MeasurementEntryView.swift`
    - **Networking**: `iOS/ReefBuddy/Sources/Networking/APIClient.swift`
    - **Assets**: `iOS/ReefBuddy/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
    
    **Expected Behavior**:
    1. Project builds for iOS 18.0+ (iPhone only)
    2. App launches with tab navigation (Tanks, Measure, History, Settings)
    3. Theme follows New Brutalist design (sharp corners, 3-4pt borders, 5pt hard shadows)
    4. Color palette: Background #FFFFFF, Text #000000, Action #00FFD1, Warning #FF3D00
    5. TankListView displays tank cards and allows adding new tanks
    6. MeasurementEntryView allows entering water parameters with validation
    7. APIClient properly encodes/decodes JSON with snake_case conversion

## Phase 2: Core Logic (The "Reef Brain")
- [ ] **Measurement API** (@edge-engineer)
    - Build `POST /measurements` with Zod validation.
    - Implement the "Free Tier" check (3/month limit) using KV.
- [ ] **AI Analysis Engine** (@edge-engineer + @data-steward)
    - Design the prompt template that includes historical trends.
    - Connect Worker to Claude-3.5-Sonnet via AI Gateway.
- [ ] **Tank Dashboard** (@ui-brutalist)
    - Build the main view displaying current parameters in high-contrast tiles.

## Phase 3: Premium Features & Trends
- [ ] **Historical Charts** (@ui-brutalist + @data-steward)
    - Implement line charts for parameter trends (New Brutalist style: jagged lines, no fills).
- [ ] **Subscription Implementation** (@edge-engineer)
    - Integrate Stripe/RevenueCat for the $4.99/month tier.
- [ ] **Data Portability** (@data-steward)
    - Build the CSV export worker for premium users.

---

## Technical Debt / Notes
- *Note:* Ensure all AI recommendations include a "Consult a professional/test twice" disclaimer in the UI.
- *Note:* Hard shadows in SwiftUI should use `.shadow(color: .black, radius: 0, x: 5, y: 5)`.
