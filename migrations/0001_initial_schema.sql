-- ============================================================================
-- ReefBuddy Initial Schema Migration
-- Migration: 0001_initial_schema.sql
-- Author: @data-steward
-- Description: Creates the initial database tables for ReefBuddy:
--              - users: User accounts and subscription info
--              - tanks: Aquarium tank definitions
--              - measurements: Water parameter readings
--              - livestock: Tank inhabitants tracking
-- ============================================================================

-- ============================================================================
-- USERS TABLE
-- Stores user account information and subscription status.
-- ============================================================================
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    subscription_tier TEXT NOT NULL DEFAULT 'free',
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Email index for login lookups
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- ============================================================================
-- TANKS TABLE
-- Stores aquarium tank definitions linked to users.
-- ============================================================================
CREATE TABLE IF NOT EXISTS tanks (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    volume_gallons REAL NOT NULL,
    tank_type TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- User tanks index for listing user's tanks
CREATE INDEX IF NOT EXISTS idx_tanks_user ON tanks(user_id);

-- ============================================================================
-- MEASUREMENTS TABLE
-- Stores water parameter readings for each tank.
-- All parameters are optional - users may only test some parameters.
-- ============================================================================
CREATE TABLE IF NOT EXISTS measurements (
    id TEXT PRIMARY KEY,
    tank_id TEXT NOT NULL,
    measured_at TEXT NOT NULL DEFAULT (datetime('now')),
    ph REAL,
    alkalinity REAL,
    calcium REAL,
    magnesium REAL,
    nitrate REAL,
    phosphate REAL,
    salinity REAL,
    temperature REAL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (tank_id) REFERENCES tanks(id)
);

-- Tank measurements index for historical queries
CREATE INDEX IF NOT EXISTS idx_measurements_tank ON measurements(tank_id, measured_at DESC);

-- ============================================================================
-- LIVESTOCK TABLE
-- Tracks livestock (fish, corals, invertebrates) in each tank.
-- ============================================================================
CREATE TABLE IF NOT EXISTS livestock (
    id TEXT PRIMARY KEY,
    tank_id TEXT NOT NULL,
    name TEXT NOT NULL,
    species TEXT,
    quantity INTEGER NOT NULL DEFAULT 1,
    added_at TEXT NOT NULL DEFAULT (datetime('now')),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (tank_id) REFERENCES tanks(id)
);

-- Tank livestock index for listing
CREATE INDEX IF NOT EXISTS idx_livestock_tank ON livestock(tank_id);

-- ============================================================================
-- End of Initial Schema Migration
-- ============================================================================
