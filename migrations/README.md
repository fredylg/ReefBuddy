# Database migrations (Cloudflare D1, `reef-db`)

Wrangler applies the files in this directory in filename order and records each one in the
`d1_migrations` table. All 15 files below are applied to production and to the Vitest database
(`tests/apply-d1-migrations.ts` replays them into Miniflare before each suite).

```bash
npm run db:migrate           # local dev database (--env dev)
npm run db:migrate:remote    # production — ask before running
npx wrangler d1 migrations list reef-db --remote
```

| File | What it does |
|------|--------------|
| `0001_initial_schema.sql` | users, sessions, tanks, measurements, analyses |
| `0002_schema_updates.sql` | early column additions |
| `0003_add_stripe_subscription.sql` | subscription columns (superseded by 0007) |
| `0004_livestock_tracking.sql` | livestock, livestock_logs |
| `0005_notification_settings.sql` | push_tokens, notification_settings, notification_history |
| `0006_historical_features.sql` | date-range indexes and daily/weekly/monthly average views |
| `0007_iap_credits.sql` | device_credits, purchase_history (credits replace subscriptions) |
| `0009_add_notes_to_measurements.sql` | measurements.notes |
| `0010_add_nitrite_to_measurements.sql` | measurements.nitrite |
| `0011_rename_livestock_name_to_common_name.sql` | livestock.name → common_name (table rebuild) |
| `0012_add_salinity_unit.sql` | measurements.salinity_unit |
| `0013_maintenance_schedules.sql` | maintenance_schedules |
| `0014_water_changes.sql` | water_changes |
| `0015_index_cleanup_and_nitrite_views.sql` | drops duplicate indexes, nitrite in the views, ISO weeks |
| `0016_livestock_enum_extension.sql` | wider livestock category / health CHECK constraints (table rebuild) |

## Numbering: there is no 0008

`0008` was never created (confirmed from git history and the production `d1_migrations` table in the
September 2026 review). D1 tracks migrations by filename, not by sequence number, so the gap is
harmless. Do not create a file named `0008_*` now: it would sort before already-applied migrations
and be applied out of order on a fresh database.

## Rules

1. **Never edit an applied migration.** Add a new file; the next number is `0017`.
2. **Soft-delete only.** Application code marks rows deleted (`is_deleted`, `deleted_at`); it must not
   `DELETE FROM` user data. The only permitted hard deletes are `push_tokens` (device tokens are not
   user data) and the scratch-table shuffles inside a table-rebuild migration (see 0016).
   `npm run lint:migrations` enforces this and runs as part of `npm run deploy`.
3. **SQLite cannot `ALTER` a CHECK constraint or drop a column with dependents.** Rebuild the table
   the way 0011 and 0016 do: create the new table, copy, drop, rename, recreate indexes. Park child
   rows in a scratch table first when foreign keys point at the table being rebuilt (0016).
4. **No `GREATEST`/`LEAST`.** SQLite uses `MAX(a, b)` / `MIN(a, b)` with two arguments.
5. Test every migration locally against a copy of production first:
   `npx wrangler d1 export reef-db --remote --output backups/prod.sql` (the `backups/` folder is
   git-ignored), import it into the local database, then `npm run db:migrate`.
