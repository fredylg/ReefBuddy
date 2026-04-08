-- Migration: 0013_maintenance_schedules.sql
-- Description: Adds maintenance schedule configuration storage (local notifications are scheduled on-device).
-- Notes: Backend stores config only for analytics and future sync; no cron/push.

CREATE TABLE IF NOT EXISTS maintenance_schedules (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  tank_id TEXT,
  type TEXT NOT NULL CHECK (type IN ('water_change', 'filter', 'testing')),
  enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0, 1)),
  schedule_kind TEXT NOT NULL CHECK (schedule_kind IN ('interval_days', 'weekly')),
  interval_days INTEGER CHECK (interval_days IS NULL OR interval_days >= 1),
  weekdays TEXT,
  time_local TEXT NOT NULL CHECK (
    length(time_local) = 5
    AND substr(time_local, 3, 1) = ':'
    AND CAST(substr(time_local, 1, 2) AS INTEGER) BETWEEN 0 AND 23
    AND CAST(substr(time_local, 4, 2) AS INTEGER) BETWEEN 0 AND 59
  ),
  timezone TEXT NOT NULL CHECK (length(timezone) > 0),
  notes TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  deleted_at TEXT,
  CHECK (
    (schedule_kind = 'interval_days' AND interval_days IS NOT NULL AND weekdays IS NULL)
    OR
    (schedule_kind = 'weekly' AND weekdays IS NOT NULL AND interval_days IS NULL)
  ),
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (tank_id) REFERENCES tanks(id)
);

CREATE INDEX IF NOT EXISTS idx_maintenance_schedules_user_active
ON maintenance_schedules(user_id)
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_maintenance_schedules_user_tank_active
ON maintenance_schedules(user_id, tank_id)
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_maintenance_schedules_user_type_active
ON maintenance_schedules(user_id, type)
WHERE deleted_at IS NULL;
