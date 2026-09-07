# Maintenance schedules (local notifications + DB analytics)

## Goal

Implement **water change / filter / testing schedules with reminders** that:

- **Increase usage** by nudging recurring maintenance behaviors (testing, water changes, filter service).
- **Increase IAP conversion** indirectly by driving more frequent measurement entry → more opportunities to run **AI analysis** (credits).
- **Deliver reminders via local notifications only** (on-device) to avoid any new hosting/servicing costs for notifications.
- **Persist configuration in D1** (“how users set them”) for analytics and future cross-device restore/sync.
- **Minimize database changes**: add **one** small table; reuse existing auth and tank ownership checks.

Non-goals (MVP):

- Server-sent push notifications for maintenance schedules (no APNs, no cron).
- Complex recurrence rules (e.g., “first business day”, “skip holidays”).
- Per-occurrence storage in DB (no expansion tables).

---

## Current state (reusable pieces)

Backend already has:

- `push_tokens`, `notification_history`, `notification_settings` (migration `migrations/0005_notification_settings.sql`)
- Auth endpoints and session validation
- Tank ownership and measurement/history endpoints

iOS already has:

- New Brutalist design system (pure white/black, aquamarine actions, safety orange warnings, thick borders, hard shadows)
- Settings-style navigation patterns and multiple CRUD-ish screens

---

## High-level architecture

### Delivery mechanism: local notifications (iOS only)

- iOS schedules reminders using `UNUserNotificationCenter`.
- Notifications include `userInfo` with `scheduleId`, `tankId`, and `type` for deep linking.
- Notifications continue to work when the device is offline.

### Persistence mechanism: D1 configuration storage (backend)

- Backend stores schedule configuration so you can:
  - measure adoption and preferences (“how users set them”)
  - pre-fill schedules on new device / reinstall later (Phase 2)
  - support support/debugging (“what did the user configure?”)

### Cost profile

- **No** new third-party services.
- **No** Worker cron triggers, **no** APNs outbound calls.
- Only lightweight D1 reads/writes during schedule CRUD and optional sync.

---

## Data model (minimal migration)

### New table: `maintenance_schedules`

One table is enough for the MVP.

Fields are intentionally simple:

- `id` TEXT PK (UUID)
- `user_id` TEXT NOT NULL
- `tank_id` TEXT NULL (supports global reminders later; MVP uses tank-bound)
- `type` TEXT NOT NULL (`water_change` | `filter` | `testing`)
- `enabled` INTEGER NOT NULL DEFAULT 1
- `schedule_kind` TEXT NOT NULL (`interval_days` | `weekly`)
- `interval_days` INTEGER NULL
- `weekdays` TEXT NULL (comma list e.g. `"1,4"` for Mon/Thu; ISO weekday 1–7)
- `time_local` TEXT NOT NULL (`HH:MM`)
- `timezone` TEXT NOT NULL (IANA TZ e.g. `"Australia/Sydney"`)
- `notes` TEXT NULL (stores optional UI metadata; e.g., testing checklist)
- `created_at` TEXT NOT NULL DEFAULT (datetime('now'))
- `updated_at` TEXT NOT NULL DEFAULT (datetime('now'))

Why we store `time_local` + `timezone`:

- It preserves what the user actually chose.
- It enables analytics (time-of-day preferences).
- It allows later restore on other devices without guessing.

Why we do **not** store `next_run_at`:

- Server is not responsible for scheduling or sending.
- iOS will compute occurrences locally.

### Indexes (keep it cheap)

- `idx_maintenance_schedules_user` on `(user_id)`
- `idx_maintenance_schedules_user_tank` on `(user_id, tank_id)`

### Migration file

Create `migrations/0013_maintenance_schedules.sql`:

```sql
CREATE TABLE IF NOT EXISTS maintenance_schedules (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  tank_id TEXT,
  type TEXT NOT NULL CHECK (type IN ('water_change', 'filter', 'testing')),
  enabled INTEGER NOT NULL DEFAULT 1,
  schedule_kind TEXT NOT NULL CHECK (schedule_kind IN ('interval_days', 'weekly')),
  interval_days INTEGER,
  weekdays TEXT,
  time_local TEXT NOT NULL,
  timezone TEXT NOT NULL,
  notes TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (tank_id) REFERENCES tanks(id)
);

CREATE INDEX IF NOT EXISTS idx_maintenance_schedules_user
ON maintenance_schedules(user_id);

CREATE INDEX IF NOT EXISTS idx_maintenance_schedules_user_tank
ON maintenance_schedules(user_id, tank_id);
```

---

## Backend API (store config only)

All endpoints require authentication (existing session token pattern).

### Endpoints

- `GET /maintenance/schedules?tankId=<uuid?>`
- `POST /maintenance/schedules`
- `PUT /maintenance/schedules/:id`
- `DELETE /maintenance/schedules/:id`

### Request/response contracts

#### Schedule object (API)

```json
{
  "id": "uuid",
  "tankId": "uuid",
  "type": "water_change | filter | testing",
  "enabled": true,
  "scheduleKind": "interval_days | weekly",
  "intervalDays": 7,
  "weekdays": [1, 4],
  "timeLocal": "19:30",
  "timezone": "Australia/Sydney",
  "notes": "{\"checklist\":[\"ALK\",\"CA\",\"MG\"]}",
  "createdAt": "2026-04-08T00:00:00.000Z",
  "updatedAt": "2026-04-08T00:00:00.000Z"
}
```

#### `POST /maintenance/schedules`

Request:

```json
{
  "tankId": "uuid",
  "type": "testing",
  "enabled": true,
  "scheduleKind": "weekly",
  "weekdays": [1, 4],
  "timeLocal": "19:30",
  "timezone": "Australia/Sydney",
  "notes": "{\"checklist\":[\"ALK\",\"NO3\"]}"
}
```

Response (201):

```json
{ "success": true, "schedule": { "...": "..." } }
```

#### Validation rules (Zod)

- `timezone`: required, non-empty string
- `timeLocal`: required, matches `^\d{2}:\d{2}$`
- `type`: enum
- `scheduleKind`: enum
- If `scheduleKind=interval_days` → `intervalDays` required and integer >= 1
- If `scheduleKind=weekly` → `weekdays` required, array of ints in 1..7, length >= 1
- `tankId` must belong to authenticated user (existing tank ownership checks)

### Backend behavior notes

- Backend never schedules or sends notifications.
- Backend stores configuration exactly as chosen.
- Backend is tolerant of UI metadata in `notes` to avoid schema churn.

---

## iOS: UX and visual spec (New Brutalism)

This section is intentionally descriptive so implementation matches ReefBuddy’s current style:

- **Background**: Pure white `#FFFFFF`
- **Text**: Pure black `#000000`
- **Primary/action**: Electric Aquamarine `#00FFD1`
- **Destructive/warning**: Safety Orange `#FF3D00`
- **Borders**: 3–4pt solid black
- **Corners**: 0 radius (sharp)
- **Shadows**: hard offset 5pt × 5pt black, no blur
- **Typography**: bold, oversized headers; grotesque/sans feel consistent with the app

### Navigation entry point

Add a new Settings row:

- Label: **Maintenance Schedules**
- Left icon: simple black calendar/checkmark glyph
- Row container: white, thick black border, hard shadow
- Tap pushes schedule list view

### Screen: Maintenance Schedules (list)

#### Header block

- Title: **MAINTENANCE SCHEDULES** (bold, large)
- Subtitle: “Reminders are scheduled on this device.”
- Layout: left-aligned, generous padding, no translucency

#### Primary CTA: “+ ADD SCHEDULE”

- Background: `#00FFD1`
- Text: `#000000`, bold (all caps OK)
- Border: 3–4pt black
- Shadow: hard 5×5 black
- Pressed state: shift down/right by 2pt and reduce shadow to simulate “pressed slab”

#### Schedule card design

Each schedule is a “slab card”:

- Card: white background, 3pt black border, hard shadow
- Padding: generous; text should not feel cramped

Card content:

- **Type badge** (top-left)
  - Text: `WATER CHANGE` / `FILTER` / `TESTING`
  - Style A (default): white fill, 2–3pt black border, black text
  - Style B (selected emphasis / optional): black fill, white text, black border
- **Title** (bold): “Water change” (or user-custom label later)
- **Summary line** (medium): “Every 7 days at 7:30 PM” or “Mon + Thu at 7:30 PM”
- **Tank line** (small, bold): “Tank: Display Reef 75g”
- **Toggle (right aligned)**
  - On: aquamarine fill with black border
  - Off: white fill with black border
  - Thumb: square, high-contrast (avoid iOS soft pill aesthetic)

Disabled schedule visual:

- Keep border/shadow (still brutalist)
- Slightly reduce text contrast to dark gray (`#222`/`#333`)
- Optional small “DISABLED” stamp in orange `#FF3D00`

Empty state:

- Large bordered panel: “NO SCHEDULES YET”
- Short description + examples
- Button: “+ ADD SCHEDULE” (same primary)

### Screen: Add/Edit Schedule

All form sections are framed as brutalist panels:

- white background
- thick black border
- hard shadow
- section title labels bold

#### Section: Type (tabs)

Rectangular segmented control (no rounding):

- `WATER CHANGE` | `FILTER` | `TESTING`
- Selected: aquamarine fill + black text + thick border
- Unselected: white fill + black text + thick border

#### Section: Tank

- Framed row with label `TANK`
- Selected tank in bold
- Chevron indicator
- If only one tank: still show, but disabled style (same frame)

#### Section: Frequency

Two big rectangular selectors:

- **EVERY N DAYS**
  - Stepper: `[-] 7 [+]` with square buttons, thick borders
- **WEEKLY**
  - Weekday chips: `MON TUE WED THU FRI SAT SUN`
    - Selected: black fill + white text (or aquamarine + black)
    - Unselected: white fill + black border

#### Section: Time

Wrap the platform picker inside a brutalist frame:

- Display selected time as a large bold line (e.g., “7:30 PM”) above the picker
- Keep the picker background white and framed

#### Section: Testing checklist (type=TESTING)

Grid chips:

- `ALK`, `CA`, `MG`, `NO3`, `PO4`, `PH`, `SAL`, `TEMP`
- Selected: aquamarine fill, black text
- Unselected: white fill, black border

Persist checklist in `notes` (e.g., JSON string) to avoid schema changes.

#### Save/Delete actions

- Primary button: **SAVE SCHEDULE**
  - aquamarine fill, black border, hard shadow
- Destructive (edit only): **DELETE SCHEDULE**
  - orange fill, black border, hard shadow
- Confirmation modal: bordered, big bold text; no rounded corners

### Notification permission UX (for adoption)

First time user saves a schedule:

- If permission not determined:
  - show a brutalist sheet:
    - Title: “ENABLE REMINDERS”
    - Body: “ReefBuddy uses notifications to remind you about maintenance.”
    - Buttons:
      - `ALLOW NOTIFICATIONS` (aquamarine)
      - `NOT NOW` (outlined)
- If denied:
  - show an orange warning card on list screen:
    - “Notifications are off. Turn them on in Settings to receive reminders.”
    - Button: “OPEN SETTINGS” (outlined)

---

## iOS: Local notification scheduling logic

### Identifiers (avoid duplicates)

Use stable identifiers so edits replace existing scheduled notifications:

- Weekly repeating: `maintenance.{scheduleId}`
- Interval-days: schedule a rolling window of occurrences:
  - `maintenance.{scheduleId}.{yyyyMMdd}`

### Weekly schedules

- Use `UNCalendarNotificationTrigger(dateMatching:repeats:)` with:
  - weekday
  - hour/minute derived from `timeLocal`
  - repeats = true

### “Every N days” schedules (interval_days)

iOS does not have a perfect “every N days forever at local time” repeating trigger across timezone/DST changes.

MVP approach (recommended):

- Compute next occurrences in local timezone
- Schedule the next 30–60 days worth (or next 10 occurrences)
- Refresh scheduled occurrences:
  - on app launch
  - when schedules change
  - optionally when entering schedules screen

This preserves the user’s chosen **local time** even across DST changes.

### Deep linking on tap

Include in `userInfo`:

```json
{ "kind": "maintenance", "scheduleId": "<uuid>", "tankId": "<uuid>", "type": "testing" }
```

On open:

- Navigate to tank context
- Present contextual actions:
  - “Enter test results”
  - “Log water change”
  - “Run AI analysis” (credits)

---

## Sync strategy (local-first, DB as record of configuration)

### Create/update/delete flow (iOS)

When user saves:

1. Save schedule locally (UserDefaults/local JSON)
2. Request permission if needed
3. Schedule/cancel local notifications
4. POST/PUT to backend to persist configuration

If backend fails:

- Keep local notifications working
- Mark schedule as `needsSync = true` locally and retry on next app launch

### Read flow (Phase 2)

MVP does not require server restore; however, storing config makes it easy later:

- On login: fetch schedules and reconcile (last-write-wins by `updated_at`)

---

## How this drives engagement + IAP

- Reminders create recurring entry points into the app.
- Reminder tap routes users to “do the thing” (test/log), which naturally leads to:
  - measurement entry
  - optional analysis run (`POST /analyze`) → consumes credits
- The UX should always present “Run analysis” as a high-contrast, primary action **after** the user logs tests (value moment).

---

## Task breakdown by agent

### Backend agent: @edge-engineer

- **Migration**
  - Add `migrations/0013_maintenance_schedules.sql`
  - Apply locally + remote as needed
- **API**
  - Implement CRUD endpoints listed above in `src/index.ts`
  - Add Zod schemas and validation
  - Enforce tank ownership
- **Tests**
  - Add Vitest coverage for validation + ownership + CRUD

### iOS agent: @ui-brutalist

- **UI**
  - Add Settings entry row
  - Implement list screen (cards, empty state, toggles)
  - Implement add/edit screen (tabs, chips, stepper, framed pickers)
- **Local notifications**
  - Permission UX (first save)
  - Scheduling engine (weekly + interval rolling window)
  - Stable notification identifiers, cancel/update behavior
- **Sync**
  - Local-first store + best-effort backend sync with retry
  - Deep link navigation from notification taps

### Data steward: @data-steward

- Review migration for minimalism and indexing
- Ensure fields capture “how users set them” without churn
- Validate query patterns for analytics (by user, by tank, by type)

### Tester: @tester-agent

- Backend: add/extend test suite for schedules endpoints and validation
- iOS: manual QA checklist for permission flows, duplicates, edits, DST edge cases

---

## Acceptance criteria (MVP)

- Users can create, edit, enable/disable, and delete maintenance schedules.
- Reminders fire locally at the expected local times.
- Editing a schedule updates notifications without duplicates.
- Backend stores schedule configuration accurately with minimal schema changes.
- UI matches New Brutalist system (colors, borders, shadows, typography).
- No APNs usage, no cron triggers, no new services introduced.

