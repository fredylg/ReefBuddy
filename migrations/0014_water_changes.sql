-- Migration: 0014_water_changes.sql
-- Description: Tracks completed water change events for each tank.

CREATE TABLE IF NOT EXISTS water_changes (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  tank_id TEXT NOT NULL,
  performed_at TEXT NOT NULL DEFAULT (datetime('now')),
  percent_replaced REAL CHECK (percent_replaced IS NULL OR (percent_replaced > 0 AND percent_replaced <= 100)),
  gallons_replaced REAL CHECK (gallons_replaced IS NULL OR gallons_replaced > 0),
  notes TEXT,
  source_schedule_id TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  deleted_at TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (tank_id) REFERENCES tanks(id),
  FOREIGN KEY (source_schedule_id) REFERENCES maintenance_schedules(id),
  CHECK (percent_replaced IS NOT NULL OR gallons_replaced IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_water_changes_user_tank_performed
  ON water_changes(user_id, tank_id, performed_at DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_water_changes_tank_performed
  ON water_changes(tank_id, performed_at DESC)
  WHERE deleted_at IS NULL;
