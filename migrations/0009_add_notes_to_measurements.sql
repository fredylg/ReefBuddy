-- ============================================================================
-- ReefBuddy Migration: 0009 - Add Notes to Measurements
-- ============================================================================
-- Adds notes column to measurements table to store user observations
-- Notes are optional and stored as TEXT for user observations about their tank
-- ============================================================================

-- Add notes column to measurements table
ALTER TABLE measurements ADD COLUMN notes TEXT;

-- ============================================================================
-- End of Migration 0009
-- ============================================================================