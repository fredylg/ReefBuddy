-- Migration: 0013_maintenance_schedules.sql
-- Description: Adds maintenance schedule configuration storage (local notifications are scheduled on-device).
-- Notes: Backend stores config only for analytics and future sync; no cron/push.

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
