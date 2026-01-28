-- ============================================================================
-- ReefBuddy Livestock Schema Alignment Migration
-- Migration: 0011_rename_livestock_name_to_common_name.sql
-- Description: Renames 'name' column to 'common_name' in livestock table
--              to match the actual database schema used by the application.
--              Also removes 'created_at' column as it's not used.
--              
--              IMPORTANT: This migration is for PRODUCTION only.
--              Local databases already have 'common_name' and should skip this.
-- ============================================================================

-- This migration assumes the table has 'name' column (production case)
-- If your local database already has 'common_name', mark this migration as applied:
--   npx wrangler d1 migrations apply reef-db --local --skip-migration 0011

-- Step 1: Create new table with correct schema
CREATE TABLE IF NOT EXISTS livestock_new (
    id TEXT PRIMARY KEY,
    tank_id TEXT NOT NULL,
    common_name TEXT NOT NULL,
    species TEXT NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    added_at TEXT NOT NULL DEFAULT (datetime('now')),
    category TEXT CHECK (category IS NULL OR category IN ('SPS', 'LPS', 'Soft', 'Fish', 'Invertebrate')),
    deleted_at TEXT,
    purchase_date TEXT,
    purchase_price REAL CHECK (purchase_price IS NULL OR purchase_price >= 0),
    health_status TEXT DEFAULT 'healthy' CHECK (health_status IS NULL OR health_status IN ('healthy', 'sick', 'deceased', 'quarantine')),
    notes TEXT,
    image_url TEXT,
    FOREIGN KEY (tank_id) REFERENCES tanks(id)
);

-- Step 2: Copy data from old table (production has 'name' column)
INSERT INTO livestock_new (
    id, tank_id, common_name, species, quantity, added_at, category, deleted_at,
    purchase_date, purchase_price, health_status, notes, image_url
)
SELECT 
    id, 
    tank_id, 
    name as common_name,  -- Rename 'name' to 'common_name'
    COALESCE(species, name) as species,  -- Ensure species is NOT NULL (use name as fallback)
    quantity, 
    added_at, 
    category, 
    deleted_at,
    purchase_date, 
    purchase_price, 
    health_status, 
    notes, 
    image_url
FROM livestock;

-- Step 3: Drop old table
DROP TABLE livestock;

-- Step 4: Rename new table
ALTER TABLE livestock_new RENAME TO livestock;

-- Step 5: Recreate indexes
CREATE INDEX IF NOT EXISTS idx_livestock_tank ON livestock(tank_id);
CREATE INDEX IF NOT EXISTS idx_livestock_active ON livestock(tank_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_livestock_health ON livestock(tank_id, health_status) WHERE deleted_at IS NULL;

-- ============================================================================
-- End of Livestock Schema Alignment Migration
-- ============================================================================
