-- ============================================================================
-- ReefBuddy Schema Updates Migration
-- Migration: 0002_schema_updates.sql
-- Author: @data-steward
-- Description: Adds ammonia parameter, livestock categories, soft delete
--              support, and password authentication fields.
-- ============================================================================

-- ============================================================================
-- MEASUREMENTS TABLE UPDATES
-- Add ammonia parameter for nitrogen cycle monitoring.
-- Ammonia (NH3/NH4+) is critical for detecting cycling issues and fish stress.
-- Typically 0 ppm in established tanks; any detectable amount is concerning.
-- ============================================================================
ALTER TABLE measurements ADD COLUMN ammonia REAL CHECK (ammonia IS NULL OR ammonia >= 0);

-- ============================================================================
-- LIVESTOCK TABLE UPDATES
-- Add category column to classify livestock type for AI recommendations.
-- Categories help determine:
-- - Water parameter sensitivity (SPS corals need pristine water)
-- - Bioload calculations (fish produce more waste than corals)
-- - Compatibility checks between species
-- ============================================================================
ALTER TABLE livestock ADD COLUMN category TEXT CHECK (category IS NULL OR category IN ('SPS', 'LPS', 'Soft', 'Fish', 'Invertebrate'));

-- ============================================================================
-- SOFT DELETE SUPPORT
-- Add deleted_at column to all tables for soft delete functionality.
-- NULL = active record, timestamp = soft deleted record.
-- Soft deletes allow data recovery and maintain referential integrity
-- for historical analytics and AI trend analysis.
-- ============================================================================

-- Users table: soft delete for account deactivation
ALTER TABLE users ADD COLUMN deleted_at TEXT;

-- Tanks table: soft delete for tank removal
ALTER TABLE tanks ADD COLUMN deleted_at TEXT;

-- Measurements table: soft delete for erroneous entries
ALTER TABLE measurements ADD COLUMN deleted_at TEXT;

-- Livestock table: soft delete for removed/deceased livestock
ALTER TABLE livestock ADD COLUMN deleted_at TEXT;

-- ============================================================================
-- USER AUTHENTICATION
-- Add password_hash column for bcrypt-hashed passwords.
-- Nullable to support existing users and potential OAuth-only accounts.
-- bcrypt hashes are 60 characters in length.
-- ============================================================================
ALTER TABLE users ADD COLUMN password_hash TEXT;

-- ============================================================================
-- INDEXES FOR SOFT DELETE QUERIES
-- Add partial indexes to efficiently query non-deleted records.
-- These indexes only include rows where deleted_at IS NULL,
-- optimizing the most common query pattern.
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_users_active ON users(email) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_tanks_active ON tanks(user_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_measurements_active ON measurements(tank_id, measured_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_livestock_active ON livestock(tank_id) WHERE deleted_at IS NULL;

-- ============================================================================
-- End of Schema Updates Migration
-- ============================================================================
