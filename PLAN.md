# ReefBuddy Implementation Roadmap

## Phase 1: Foundation & Infrastructure (Current)
- [ ] **Infrastructure Setup** (@edge-engineer)
    - Initialize `wrangler.toml` with D1 and KV namespaces.
    - Set up Cloudflare AI Gateway routing.
- [ ] **Database Schema Design** (@data-steward)
    - Create `0001_initial_schema.sql` (Tables: `users`, `tanks`, `measurements`, `livestock`).
    - Define SQLite types for water parameters (pH, Alk, Cal, Mag, NO3, PO4).
- [ ] **Brutalist UI Kit** (@ui-brutalist)
    - Define `BrutalistTheme.swift` (Colors, Border Widths, Hard Shadows).
    - Create reusable `BrutalistButton` and `BrutalistTextField` components.

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