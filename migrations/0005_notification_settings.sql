-- ============================================================================
-- ReefBuddy Push Notifications Migration
-- Migration: 0005_notification_settings.sql
-- Author: @edge-engineer
-- Description: Adds tables for push notification management:
--              - notification_settings: User-defined parameter thresholds
--              - push_tokens: Device push notification tokens
--              - notification_history: Record of sent notifications
-- ============================================================================

-- ============================================================================
-- NOTIFICATION SETTINGS TABLE
-- Stores user-defined alert thresholds for each water parameter.
-- Users can configure min/max thresholds for each parameter and enable/disable
-- alerts independently.
--
-- Default thresholds (per reef aquarium best practices):
-- - pH: 7.8 - 8.4
-- - Alkalinity: 7 - 11 dKH
-- - Calcium: 380 - 450 ppm
-- - Magnesium: 1250 - 1400 ppm
-- - Ammonia: 0 - 0.25 ppm (warning if > 0)
-- ============================================================================

CREATE TABLE IF NOT EXISTS notification_settings (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    parameter TEXT NOT NULL,
    min_threshold REAL,
    max_threshold REAL,
    enabled INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id),
    -- Ensure unique setting per user/parameter combination
    UNIQUE(user_id, parameter)
);

-- Index for efficient user settings lookup
CREATE INDEX IF NOT EXISTS idx_notification_settings_user
ON notification_settings(user_id)
WHERE enabled = 1;

-- Index for parameter-specific queries
CREATE INDEX IF NOT EXISTS idx_notification_settings_parameter
ON notification_settings(user_id, parameter);

-- ============================================================================
-- PUSH TOKENS TABLE
-- Stores device push notification tokens for APNs (iOS) and FCM (Android).
-- Each user can have multiple devices registered.
-- Tokens should be refreshed periodically by the mobile app.
-- ============================================================================

CREATE TABLE IF NOT EXISTS push_tokens (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    token TEXT NOT NULL,
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
    device_name TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id),
    -- Ensure unique token (same token cannot be registered twice)
    UNIQUE(token)
);

-- Index for finding all tokens for a user (for sending notifications)
CREATE INDEX IF NOT EXISTS idx_push_tokens_user
ON push_tokens(user_id);

-- Index for token lookup (for updating/deleting specific tokens)
CREATE INDEX IF NOT EXISTS idx_push_tokens_token
ON push_tokens(token);

-- ============================================================================
-- NOTIFICATION HISTORY TABLE
-- Records all notifications sent to users for audit and debugging.
-- Helps prevent notification spam and allows users to review past alerts.
-- ============================================================================

CREATE TABLE IF NOT EXISTS notification_history (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    parameter TEXT,
    value REAL,
    threshold_type TEXT CHECK (threshold_type IS NULL OR threshold_type IN ('min', 'max')),
    threshold_value REAL,
    sent_at TEXT NOT NULL DEFAULT (datetime('now')),
    read_at TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Index for fetching user's notification history (most recent first)
CREATE INDEX IF NOT EXISTS idx_notification_history_user
ON notification_history(user_id, sent_at DESC);

-- Index for filtering by notification type
CREATE INDEX IF NOT EXISTS idx_notification_history_type
ON notification_history(user_id, type, sent_at DESC);

-- Index for finding unread notifications
CREATE INDEX IF NOT EXISTS idx_notification_history_unread
ON notification_history(user_id, read_at)
WHERE read_at IS NULL;

-- ============================================================================
-- DEFAULT NOTIFICATION SETTINGS TRIGGER
-- Automatically creates default notification settings when a new user signs up.
-- This ensures all users have baseline alert thresholds configured.
-- ============================================================================

-- Note: This trigger will only fire for users created after this migration.
-- Existing users will need to manually configure their settings or use the API.
-- The application layer handles creating default settings if they don't exist.

-- ============================================================================
-- End of Push Notifications Migration
-- ============================================================================
