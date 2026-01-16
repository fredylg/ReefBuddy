# ReefBuddy Development Plan

## Phase 1: Core Backend Infrastructure

### Database & Migrations
- [x] Initial D1 schema (users, tanks, measurements, livestock)
- [x] Migration 0002: Add ammonia, category, deleted_at, password_hash columns
- [x] Soft delete support with partial indexes

### Authentication API
- [x] `POST /auth/signup` - Create user with bcrypt password hash
- [x] `POST /auth/login` - Validate password, create session in KV
- [x] `POST /auth/logout` - Invalidate session in KV
- [x] Session middleware for protected routes

### Measurement API
- [x] `POST /measurements` - Persist water readings to D1 (authenticated)

### Analysis API
- [x] `POST /analyze` - AI-powered water chemistry analysis
- [x] Rate limiting (3/month free tier via KV)
- [x] AI Gateway integration for LLM calls

---

## Handoff to @tester-agent

**Status:** All Phase 1 backend endpoints are implemented and ready for QA testing.

### Endpoint Documentation for Testing

#### 1. POST /auth/signup
Create a new user account with password authentication.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "securepassword123"
}
```

**Response (201):**
```json
{
  "success": true,
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "subscription_tier": "free"
  },
  "session_token": "hex-token-64-chars",
  "expires_in": 604800
}
```

**Error Cases:**
- 400: Validation failed (invalid email format, password < 8 chars)
- 409: Email already exists

---

#### 2. POST /auth/login
Authenticate and receive a session token.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "securepassword123"
}
```

**Response (200):**
```json
{
  "success": true,
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "subscription_tier": "free"
  },
  "session_token": "hex-token-64-chars",
  "expires_in": 604800
}
```

**Error Cases:**
- 400: Validation failed
- 401: Invalid email or password

---

#### 3. POST /auth/logout
Invalidate the current session.

**Headers:**
```
Authorization: Bearer <session_token>
```

**Response (200):**
```json
{
  "success": true,
  "message": "Successfully logged out"
}
```

**Error Cases:**
- 401: Missing or invalid Authorization header

---

#### 4. POST /measurements (Authenticated)
Record water parameter measurements for a tank.

**Headers:**
```
Authorization: Bearer <session_token>
```

**Request:**
```json
{
  "tankId": "uuid-of-tank",
  "ph": 8.2,
  "alkalinity": 8.5,
  "calcium": 420,
  "magnesium": 1350,
  "nitrate": 5,
  "phosphate": 0.03,
  "salinity": 1.025,
  "temperature": 78,
  "ammonia": 0,
  "measuredAt": "2024-01-15T10:00:00Z"
}
```

**Notes:**
- All parameters except `tankId` are optional
- `measuredAt` defaults to current timestamp if not provided
- Tank must belong to the authenticated user

**Response (201):**
```json
{
  "success": true,
  "measurement": {
    "id": "uuid",
    "tank_id": "uuid",
    "measured_at": "2024-01-15T10:00:00Z",
    "ph": 8.2,
    "alkalinity": 8.5,
    "calcium": 420,
    "magnesium": 1350,
    "nitrate": 5,
    "phosphate": 0.03,
    "salinity": 1.025,
    "temperature": 78,
    "ammonia": 0
  }
}
```

**Error Cases:**
- 400: Validation failed
- 401: Unauthorized (missing/invalid session)
- 403: Forbidden (tank belongs to different user)
- 404: Tank not found

---

### Session Token Details
- Stored in KV with pattern: `session:{token}`
- Value: `{"user_id": "uuid", "created_at": "iso-timestamp"}`
- TTL: 604800 seconds (1 week)
- Format: 64-character hex string

### Test Commands
```bash
# Run all backend tests
npx vitest run

# Run specific test file
npx vitest run tests/api.test.ts
npx vitest run tests/db.test.ts
npx vitest run tests/ai-gateway.test.ts

# Local development server
npx wrangler dev

# Apply migrations locally
npx wrangler d1 migrations apply reef-db --local
```

---

## Phase 2: iOS App

### Brutalist UI Kit
- [x] BrutalistTheme.swift - Design system (colors, typography, spacing, shadows)
- [x] BrutalistButton.swift - Primary/secondary/destructive button styles
- [x] BrutalistTextField.swift - Text input, text area, picker, stepper components

### Data Models
- [x] Tank.swift - Tank model with TankType enum
- [x] Measurement.swift - Water parameter model with ranges
- [x] User.swift - User model with subscription tiers

### Core Views
- [x] ReefBuddyApp.swift - Main app entry with AppState
- [x] ContentView.swift - Root tab navigation
- [x] TankListView.swift - Tank list with cards and add tank sheet
- [x] MeasurementEntryView.swift - Water parameter form with validation
- [x] AnalysisView.swift - AI analysis display with warnings/recommendations

### Networking
- [x] APIClient.swift - Backend API client with all endpoints

### Assets
- [!] AccentColor.colorset - Electric Aquamarine (#00FFD1)
- [!] AppIcon.appiconset - Brutalist "RB" icon on aquamarine background
- [!] AppIconGenerator.swift - SwiftUI preview for icon generation

---

## Handoff to @tester-agent (iOS UI)

**Status:** Phase 2 Brutalist UI Kit and Tank Dashboard are ready for QA testing.

### Files Created/Modified for Review

**Theme & Components (New Brutalist Design System):**
```
iOS/ReefBuddy/Sources/Theme/BrutalistTheme.swift
iOS/ReefBuddy/Sources/Components/BrutalistButton.swift
iOS/ReefBuddy/Sources/Components/BrutalistTextField.swift
```

**Data Models:**
```
iOS/ReefBuddy/Sources/Models/Tank.swift
iOS/ReefBuddy/Sources/Models/Measurement.swift
iOS/ReefBuddy/Sources/Models/User.swift
```

**App & Views:**
```
iOS/ReefBuddy/Sources/App/ReefBuddyApp.swift
iOS/ReefBuddy/Sources/App/ContentView.swift
iOS/ReefBuddy/Sources/App/AppIconGenerator.swift
iOS/ReefBuddy/Sources/Views/TankListView.swift
iOS/ReefBuddy/Sources/Views/MeasurementEntryView.swift
iOS/ReefBuddy/Sources/Views/AnalysisView.swift
```

**Networking:**
```
iOS/ReefBuddy/Sources/Networking/APIClient.swift
```

**Assets:**
```
iOS/ReefBuddy/Resources/Assets.xcassets/AccentColor.colorset/Contents.json
iOS/ReefBuddy/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json
```

**Xcode Project:**
```
iOS/ReefBuddy.xcodeproj/project.pbxproj
```

### Design Verification Checklist

Per CLAUDE.md New Brutalist Manifesto, verify:

1. **Colors:**
   - [ ] Background is pure white (#FFFFFF)
   - [ ] Text/Accents are pure black (#000000)
   - [ ] Action color is Electric Aquamarine (#00FFD1)
   - [ ] Warning color is Safety Orange (#FF3D00)

2. **Borders & Corners:**
   - [ ] All borders are 3pt or 4pt solid black
   - [ ] All corners are 0px radius (sharp corners)
   - [ ] No rounded elements

3. **Shadows:**
   - [ ] Hard offset shadows at 5pt x 5pt
   - [ ] No blur, no gradients
   - [ ] Pure black shadow color

4. **Typography:**
   - [ ] Bold, oversized headers
   - [ ] Grotesque sans-serif fonts (SF Pro)

### Functional Testing Checklist

**Tank List View:**
- [ ] Displays sample tanks in DEBUG mode
- [ ] Tank cards show name, type, volume, age
- [ ] Selected tank has "ACTIVE" badge
- [ ] Add tank sheet opens correctly
- [ ] Delete confirmation alert works

**Measurement Entry View:**
- [ ] All parameter fields accept numeric input
- [ ] Target ranges display correctly
- [ ] Border color changes based on value status
- [ ] "Analyze Parameters" button works
- [ ] "Save Without Analysis" button works

**Analysis View:**
- [ ] Displays parameter grid with status
- [ ] Shows warnings section when present
- [ ] Shows recommendations section
- [ ] Shows dosing advice cards
- [ ] Share functionality works

**Navigation:**
- [ ] Tab bar shows 4 tabs (Tanks, Measure, History, Settings)
- [ ] Tab switching works correctly
- [ ] Header shows "REEFBUDDY" and free tier badge

### Test Commands
```bash
# Build and run on simulator
xcodebuild -project iOS/ReefBuddy.xcodeproj -scheme ReefBuddy -destination 'platform=iOS Simulator,name=iPhone 15' build

# Run UI tests (when available)
xcodebuild test -project iOS/ReefBuddy.xcodeproj -scheme ReefBuddy -destination 'platform=iOS Simulator,name=iPhone 15'
```

---

## Phase 2.5: Subscription System

### Database & Migrations
- [x] Migration 0003: Add stripe_customer_id, stripe_subscription_id columns
- [x] Indexes for subscription lookups

### Subscription API
- [!] `POST /subscriptions/create` - Create Stripe checkout session (requires auth)
- [!] `POST /subscriptions/webhook` - Handle Stripe webhook events
- [!] `GET /subscriptions/status` - Get current subscription status (requires auth)
- [!] `POST /subscriptions/cancel` - Cancel subscription (requires auth)

### Stripe Integration
- [x] `src/stripe.ts` - Stripe API client using fetch (Workers compatible)
- [x] Webhook signature verification (HMAC-SHA256)
- [x] Checkout session creation
- [x] Subscription cancellation

### Rate Limiting & Premium
- [x] Premium users bypass rate limits (unlimited analyses)
- [x] `requirePremium()` middleware for premium-only endpoints
- [x] CSV export gated behind premium tier

### Pricing
- Free tier: 3 analyses/month
- Premium tier: $4.99/month, unlimited analyses, CSV export, historical charts

---

## Handoff to @tester-agent (Subscription System)

**Status:** Phase 2.5 Subscription System is ready for QA testing.

### Files Created/Modified for Review

**Backend Subscription:**
```
src/stripe.ts             - Stripe API integration
src/index.ts              - Subscription endpoints added
migrations/0003_add_stripe_subscription.sql
wrangler.toml             - Stripe configuration added
```

### Endpoint Documentation for Testing

#### 1. POST /subscriptions/create (Authenticated)
Create a Stripe checkout session for premium subscription.

**Headers:**
```
Authorization: Bearer <session_token>
```

**Request:**
```json
{
  "successUrl": "https://app.reefbuddy.com/subscription/success",
  "cancelUrl": "https://app.reefbuddy.com/subscription/cancel"
}
```

**Response (200):**
```json
{
  "success": true,
  "sessionId": "cs_test_xxxxx",
  "checkoutUrl": "https://checkout.stripe.com/c/pay/cs_test_xxxxx"
}
```

**Error Cases:**
- 400: Already subscribed
- 401: Unauthorized
- 500: Stripe error (not configured)

---

#### 2. POST /subscriptions/webhook (Public)
Handle Stripe webhook events. Verified by signature.

**Headers:**
```
Stripe-Signature: t=xxx,v1=xxx
```

**Request Body:** Raw Stripe event JSON

**Response (200):**
```json
{
  "received": true
}
```

**Handled Events:**
- `checkout.session.completed` -> User upgraded to premium
- `customer.subscription.deleted` -> User downgraded to free

**Error Cases:**
- 400: Missing Stripe-Signature header
- 400: Invalid webhook signature

---

#### 3. GET /subscriptions/status (Authenticated)
Get current subscription status and rate limit info.

**Headers:**
```
Authorization: Bearer <session_token>
```

**Response (200) - Free User:**
```json
{
  "success": true,
  "subscription": {
    "tier": "free",
    "isPremium": false,
    "stripeSubscriptionId": null,
    "features": {
      "analysesPerMonth": 3,
      "csvExport": false,
      "historicalCharts": false
    }
  },
  "rateLimit": {
    "used": 1,
    "limit": 3,
    "remaining": 2
  },
  "pricing": {
    "premiumPrice": "$4.99/month",
    "features": [
      "Unlimited water analyses",
      "CSV export of measurements",
      "Historical trend charts",
      "Priority AI recommendations"
    ]
  }
}
```

**Response (200) - Premium User:**
```json
{
  "success": true,
  "subscription": {
    "tier": "premium",
    "isPremium": true,
    "stripeSubscriptionId": "sub_xxxxx",
    "features": {
      "analysesPerMonth": "unlimited",
      "csvExport": true,
      "historicalCharts": true
    }
  },
  "rateLimit": null,
  "pricing": { ... }
}
```

---

#### 4. POST /subscriptions/cancel (Authenticated)
Cancel premium subscription.

**Headers:**
```
Authorization: Bearer <session_token>
```

**Request:**
```json
{
  "cancelAtPeriodEnd": true
}
```

**Response (200):**
```json
{
  "success": true,
  "message": "Subscription will be canceled at the end of the current billing period...",
  "cancelAtPeriodEnd": true
}
```

**Error Cases:**
- 400: No active subscription
- 401: Unauthorized
- 500: Stripe error

---

### Setup Instructions for Testing

1. **Apply migration locally:**
```bash
npx wrangler d1 migrations apply reef-db --local
```

2. **Set Stripe test secrets (optional for local testing):**
```bash
wrangler secret put STRIPE_SECRET_KEY
# Enter: sk_test_xxxxx

wrangler secret put STRIPE_WEBHOOK_SECRET
# Enter: whsec_xxxxx
```

3. **Update STRIPE_PRICE_ID in wrangler.toml:**
   - Create a product in Stripe Dashboard
   - Set price to $4.99/month recurring
   - Copy the price_xxxxx ID

4. **Test webhook locally with Stripe CLI:**
```bash
stripe listen --forward-to localhost:8787/subscriptions/webhook
```

---

## Phase 3: Advanced Features (Pending)
- [ ] Livestock tracking
- [ ] Historical trends and charts
- [ ] Push notifications for parameter alerts
- [x] Premium subscription features
