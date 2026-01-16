-- ============================================================================
-- MIGRATION 0007: In-App Purchase Credits System
-- ============================================================================
-- Replaces subscription model with consumable credit packs
-- Credits tracked per device (no user authentication required)
-- ============================================================================

-- Device credits tracking table
CREATE TABLE IF NOT EXISTS device_credits (
    device_id TEXT PRIMARY KEY,
    free_used INTEGER NOT NULL DEFAULT 0,        -- 0-3, tracks free tier usage
    paid_credits INTEGER NOT NULL DEFAULT 0,     -- purchased credits balance
    total_analyses INTEGER NOT NULL DEFAULT 0,   -- lifetime analysis count
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Purchase history for audit and duplicate prevention
CREATE TABLE IF NOT EXISTS purchase_history (
    id TEXT PRIMARY KEY,
    device_id TEXT NOT NULL,
    product_id TEXT NOT NULL,                    -- 'credits_5' or 'credits_50'
    credits_added INTEGER NOT NULL,
    apple_transaction_id TEXT UNIQUE,            -- prevents duplicate redemption
    receipt_data TEXT,                           -- stored for verification
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (device_id) REFERENCES device_credits(device_id)
);

-- Index for quick device lookups
CREATE INDEX IF NOT EXISTS idx_purchase_history_device ON purchase_history(device_id);

-- Index for transaction lookups (duplicate prevention)
CREATE INDEX IF NOT EXISTS idx_purchase_history_transaction ON purchase_history(apple_transaction_id);
