-- ============================================================================
-- ReefBuddy Initial Database Schema
-- Migration: 0001_initial_schema.sql
-- Author: @data-steward
-- Description: Creates the foundational tables for the ReefBuddy application
-- ============================================================================

-- Enable foreign key enforcement (required for D1/SQLite)
PRAGMA foreign_keys = ON;

-- ============================================================================
-- USERS TABLE
-- Purpose: Stores user account information and subscription status.
-- The subscription_tier determines access to premium features and
-- the number of AI-powered water chemistry analyses allowed per month.
-- Free tier: 3 analyses/month | Premium tier: Unlimited
-- ============================================================================
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,                          -- UUID for user identification
    email TEXT NOT NULL UNIQUE,                   -- User's email address (unique constraint)
    created_at TEXT NOT NULL DEFAULT (datetime('now')), -- ISO8601 timestamp of account creation
    subscription_tier TEXT NOT NULL DEFAULT 'free' CHECK (subscription_tier IN ('free', 'premium'))
);

-- Index for email lookups during authentication
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- ============================================================================
-- TANKS TABLE
-- Purpose: Represents individual saltwater aquarium tanks owned by users.
-- Each user can have multiple tanks. Tracks basic tank configuration
-- including volume and salt mix type for accurate dosing calculations.
-- ============================================================================
CREATE TABLE IF NOT EXISTS tanks (
    id TEXT PRIMARY KEY,                          -- UUID for tank identification
    user_id TEXT NOT NULL,                        -- Foreign key to users table
    name TEXT NOT NULL,                           -- User-defined tank name (e.g., "Living Room Reef")
    volume_gallons REAL NOT NULL CHECK (volume_gallons > 0), -- Tank volume in US gallons
    salt_type TEXT,                               -- Salt mix brand (e.g., "Red Sea Coral Pro", "Instant Ocean")
    created_at TEXT NOT NULL DEFAULT (datetime('now')), -- ISO8601 timestamp of tank creation

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Index for fetching all tanks belonging to a user
CREATE INDEX IF NOT EXISTS idx_tanks_user_id ON tanks(user_id);

-- ============================================================================
-- MEASUREMENTS TABLE
-- Purpose: Stores water chemistry test results for each tank.
-- This is the core data table that powers AI-driven analysis.
-- All parameter values use appropriate precision for saltwater aquariums:
-- - pH: typically 7.8-8.5 (REAL for decimal precision)
-- - Alkalinity: typically 7-12 dKH (REAL)
-- - Calcium: typically 380-450 ppm (REAL)
-- - Magnesium: typically 1250-1400 ppm (REAL)
-- - Nitrate: typically 0-20 ppm (REAL)
-- - Phosphate: typically 0-0.1 ppm (REAL, requires high precision)
-- - Salinity: typically 1.024-1.026 specific gravity or 35 ppt (REAL)
-- - Temperature: typically 75-82°F (REAL)
-- ============================================================================
CREATE TABLE IF NOT EXISTS measurements (
    id TEXT PRIMARY KEY,                          -- UUID for measurement identification
    tank_id TEXT NOT NULL,                        -- Foreign key to tanks table
    measured_at TEXT NOT NULL DEFAULT (datetime('now')), -- ISO8601 timestamp of when test was taken

    -- Water chemistry parameters (all nullable to allow partial test entries)
    ph REAL CHECK (ph IS NULL OR (ph >= 0 AND ph <= 14)),
    alkalinity REAL CHECK (alkalinity IS NULL OR alkalinity >= 0),    -- dKH (degrees of carbonate hardness)
    calcium REAL CHECK (calcium IS NULL OR calcium >= 0),             -- ppm (parts per million)
    magnesium REAL CHECK (magnesium IS NULL OR magnesium >= 0),       -- ppm
    nitrate REAL CHECK (nitrate IS NULL OR nitrate >= 0),             -- ppm
    phosphate REAL CHECK (phosphate IS NULL OR phosphate >= 0),       -- ppm
    salinity REAL CHECK (salinity IS NULL OR salinity >= 0),          -- specific gravity or ppt
    temperature REAL CHECK (temperature IS NULL OR temperature >= 0), -- degrees Fahrenheit

    FOREIGN KEY (tank_id) REFERENCES tanks(id) ON DELETE CASCADE
);

-- Composite index for fetching measurements by tank, ordered by date (most common query)
CREATE INDEX IF NOT EXISTS idx_measurements_tank_date ON measurements(tank_id, measured_at DESC);

-- Index for date-range queries across all tanks (for analytics/reports)
CREATE INDEX IF NOT EXISTS idx_measurements_date ON measurements(measured_at);

-- ============================================================================
-- LIVESTOCK TABLE
-- Purpose: Tracks fish, corals, and invertebrates in each tank.
-- Used for AI recommendations - different species have different
-- water parameter requirements and bioload impacts.
-- ============================================================================
CREATE TABLE IF NOT EXISTS livestock (
    id TEXT PRIMARY KEY,                          -- UUID for livestock entry identification
    tank_id TEXT NOT NULL,                        -- Foreign key to tanks table
    species TEXT NOT NULL,                        -- Scientific name (e.g., "Amphiprion ocellaris")
    common_name TEXT,                             -- Common name (e.g., "Ocellaris Clownfish")
    quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0), -- Number of this species
    added_at TEXT NOT NULL DEFAULT (datetime('now')), -- ISO8601 timestamp when added to tank

    FOREIGN KEY (tank_id) REFERENCES tanks(id) ON DELETE CASCADE
);

-- Index for fetching all livestock in a tank
CREATE INDEX IF NOT EXISTS idx_livestock_tank_id ON livestock(tank_id);

-- ============================================================================
-- End of Initial Schema Migration
-- ============================================================================
