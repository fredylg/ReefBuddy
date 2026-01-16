-- ============================================================================
-- ReefBuddy Livestock Tracking Migration
-- Migration: 0004_livestock_tracking.sql
-- Author: @data-steward
-- Description: Enhances the livestock table with additional tracking fields
--              and creates a livestock_logs table for health/event logging.
-- ============================================================================

-- ============================================================================
-- LIVESTOCK TABLE ENHANCEMENTS
-- Add purchase tracking, health status, notes, and image support.
-- ============================================================================

-- Purchase date - when the livestock was acquired
ALTER TABLE livestock ADD COLUMN purchase_date TEXT;

-- Purchase price - cost of the livestock in user's currency
ALTER TABLE livestock ADD COLUMN purchase_price REAL CHECK (purchase_price IS NULL OR purchase_price >= 0);

-- Health status - current status of the livestock
-- healthy: Normal, thriving condition
-- sick: Showing signs of illness or stress
-- deceased: No longer alive
-- quarantine: Isolated for observation or treatment
ALTER TABLE livestock ADD COLUMN health_status TEXT DEFAULT 'healthy' CHECK (health_status IS NULL OR health_status IN ('healthy', 'sick', 'deceased', 'quarantine'));

-- Notes - free-form text for additional observations
ALTER TABLE livestock ADD COLUMN notes TEXT;

-- Image URL - reference to an uploaded image of the livestock
ALTER TABLE livestock ADD COLUMN image_url TEXT;

-- ============================================================================
-- LIVESTOCK_LOGS TABLE
-- Tracks health events, feedings, observations, treatments, and deaths
-- for each livestock entry. Provides historical health timeline.
-- ============================================================================
CREATE TABLE IF NOT EXISTS livestock_logs (
    id TEXT PRIMARY KEY,
    livestock_id TEXT NOT NULL,
    -- Log type categorizes the entry:
    -- feeding: Feeding event with details
    -- observation: General observation or behavior note
    -- treatment: Medical treatment or intervention
    -- death: Mortality event (should update livestock health_status)
    log_type TEXT NOT NULL CHECK (log_type IN ('feeding', 'observation', 'treatment', 'death')),
    -- Description of the event
    description TEXT,
    -- When the event occurred (defaults to now)
    logged_at TEXT NOT NULL DEFAULT (datetime('now')),
    -- Standard timestamps
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (livestock_id) REFERENCES livestock(id)
);

-- ============================================================================
-- INDEXES FOR LIVESTOCK_LOGS
-- Optimize queries for listing logs by livestock and date range.
-- ============================================================================

-- Primary query pattern: Get logs for a specific livestock item, newest first
CREATE INDEX IF NOT EXISTS idx_livestock_logs_livestock ON livestock_logs(livestock_id, logged_at DESC);

-- Query pattern: Filter by log type (e.g., all feeding events)
CREATE INDEX IF NOT EXISTS idx_livestock_logs_type ON livestock_logs(log_type, logged_at DESC);

-- ============================================================================
-- ADDITIONAL LIVESTOCK INDEXES
-- Optimize queries for health status filtering.
-- ============================================================================

-- Query pattern: Find livestock by health status (e.g., all sick animals)
CREATE INDEX IF NOT EXISTS idx_livestock_health ON livestock(tank_id, health_status) WHERE deleted_at IS NULL;

-- ============================================================================
-- End of Livestock Tracking Migration
-- ============================================================================
