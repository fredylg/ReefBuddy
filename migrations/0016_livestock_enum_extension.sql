-- Migration 0016: accept the iOS app's livestock categories and health statuses
-- (maintenance plan P3-02 note / I-06). SQLite cannot alter a CHECK constraint, so the
-- table is rebuilt exactly as in 0011 with wider constraints. Data is preserved.
--
-- New categories:      Anemone, Other
-- New health statuses: thriving, stressed, declining, critical
--
-- livestock_logs.livestock_id references livestock(id) and D1 enforces foreign keys. Dropping
-- the parent while child rows exist fails even with deferred checks (SQLite counts the dropped
-- parents as violations), so the child rows are parked in a scratch table and restored after
-- the rebuild. The whole file runs in one D1 transaction.

CREATE TABLE livestock_logs_backup AS SELECT * FROM livestock_logs;
DELETE FROM livestock_logs;

CREATE TABLE IF NOT EXISTS livestock_new (
    id TEXT PRIMARY KEY,
    tank_id TEXT NOT NULL,
    common_name TEXT NOT NULL,
    species TEXT NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    added_at TEXT NOT NULL DEFAULT (datetime('now')),
    category TEXT CHECK (category IS NULL OR category IN ('SPS', 'LPS', 'Soft', 'Fish', 'Invertebrate', 'Anemone', 'Other')),
    deleted_at TEXT,
    purchase_date TEXT,
    purchase_price REAL CHECK (purchase_price IS NULL OR purchase_price >= 0),
    health_status TEXT DEFAULT 'healthy' CHECK (health_status IS NULL OR health_status IN ('thriving', 'healthy', 'stressed', 'declining', 'critical', 'sick', 'deceased', 'quarantine')),
    notes TEXT,
    image_url TEXT,
    FOREIGN KEY (tank_id) REFERENCES tanks(id)
);

INSERT INTO livestock_new (
    id, tank_id, common_name, species, quantity, added_at, category, deleted_at,
    purchase_date, purchase_price, health_status, notes, image_url
)
SELECT
    id, tank_id, common_name, species, quantity, added_at, category, deleted_at,
    purchase_date, purchase_price, health_status, notes, image_url
FROM livestock;

DROP TABLE livestock;
ALTER TABLE livestock_new RENAME TO livestock;

CREATE INDEX IF NOT EXISTS idx_livestock_tank ON livestock(tank_id);
CREATE INDEX IF NOT EXISTS idx_livestock_active ON livestock(tank_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_livestock_health ON livestock(tank_id, health_status) WHERE deleted_at IS NULL;

INSERT INTO livestock_logs SELECT * FROM livestock_logs_backup;
DROP TABLE livestock_logs_backup;
