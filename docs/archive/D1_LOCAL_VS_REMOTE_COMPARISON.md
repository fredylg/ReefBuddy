# D1 Local vs Cloudflare (Remote) Schema Comparison

**Date:** 2026-02-05  
**Method:** Direct database queries via `wrangler d1 execute` (local and remote), not migrations.

---

## Summary

**Result: Local and remote schemas are identical.** No tables or columns need to be added to local.

---

## Tables Compared

| Table | In Local | In Remote | Columns Match |
|-------|----------|-----------|---------------|
| d1_migrations | Yes | Yes | Yes |
| device_credits | Yes | Yes | Yes |
| livestock | Yes | Yes | Yes |
| livestock_logs | Yes | Yes | Yes |
| measurements | Yes | Yes | Yes |
| notification_history | Yes | Yes | Yes |
| notification_settings | Yes | Yes | Yes |
| purchase_history | Yes | Yes | Yes |
| push_tokens | Yes | Yes | Yes |
| tanks | Yes | Yes | Yes |
| users | Yes | Yes | Yes |

No extra tables exist in remote that are missing in local.

---

## Column Lists (by table)

### device_credits
- **Local & remote:** device_id, free_used, paid_credits, total_analyses, created_at, updated_at

### livestock
- **Local & remote:** id, tank_id, common_name, species, quantity, added_at, category, deleted_at, purchase_date, purchase_price, health_status, notes, image_url

### livestock_logs
- **Local & remote:** id, livestock_id, log_type, description, logged_at, created_at

### measurements
- **Local & remote:** id, tank_id, measured_at, ph, alkalinity, calcium, magnesium, nitrate, phosphate, salinity, temperature, created_at, ammonia, deleted_at, notes, nitrite, salinity_unit

### notification_history
- **Local & remote:** id, user_id, type, title, body, parameter, value, threshold_type, threshold_value, sent_at, read_at

### notification_settings
- **Local & remote:** id, user_id, parameter, min_threshold, max_threshold, enabled, created_at, updated_at

### purchase_history
- **Local & remote:** id, device_id, product_id, credits_added, apple_transaction_id, receipt_data, created_at

### push_tokens
- **Local & remote:** id, user_id, token, platform, device_name, created_at, updated_at

### tanks
- **Local & remote:** id, user_id, name, volume_gallons, tank_type, created_at, updated_at, deleted_at

### users
- **Local & remote:** id, email, subscription_tier, created_at, updated_at, deleted_at, password_hash, stripe_customer_id, stripe_subscription_id

---

## Migrations Applied

| Migration | Local | Remote |
|-----------|--------|--------|
| 0001_initial_schema.sql | Applied | Applied |
| 0002_schema_updates.sql | Applied | Applied |
| 0003_add_stripe_subscription.sql | Applied | Applied |
| 0004_livestock_tracking.sql | Applied | Applied |
| 0005_notification_settings.sql | Applied | Applied |
| 0006_historical_features.sql | Applied | Applied |
| 0007_iap_credits.sql | Applied | Applied |
| 0009_add_notes_to_measurements.sql | Applied | Applied |
| 0010_add_nitrite_to_measurements.sql | Applied | Applied |
| 0011_rename_livestock_name_to_common_name.sql | Applied | Applied |
| 0012_add_salinity_unit.sql | Applied | Applied |

Same 11 migration files are applied in both environments (0008 is skipped in both).

---

## Conclusion

- **Tables to add in local:** None.
- **Columns to add in local:** None.

Local D1 was brought in sync with Cloudflare when `npx wrangler d1 migrations apply reef-db --local` was run (including 0012_add_salinity_unit.sql). Direct `PRAGMA table_info()` and `sqlite_master` checks show identical table and column definitions in local and remote.

If you previously saw “no such table” or missing-column errors in local, they were likely from:
1. Running tests before applying migrations, or  
2. A different local DB path (e.g. vitest using an in-process D1 that doesn’t use `.wrangler/state/v3/d1`).

To re-apply all migrations to local from scratch: delete `.wrangler/state/v3/d1` (or the local DB file) and run `npx wrangler d1 migrations apply reef-db --local` again.
