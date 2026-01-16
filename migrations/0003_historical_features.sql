-- ============================================================================
-- ReefBuddy Historical Features Migration
-- Migration: 0003_historical_features.sql
-- Author: @data-steward
-- Description: Adds indexes for efficient date-range queries, trend support,
--              and aggregation views for daily/weekly/monthly averages.
-- ============================================================================

-- ============================================================================
-- DATE-RANGE QUERY INDEXES
-- Optimize historical measurement queries by tank and date range.
-- These indexes support efficient date filtering for trend analysis.
-- ============================================================================

-- Primary index for date-range queries on active measurements
-- Covers queries like: WHERE tank_id = ? AND measured_at BETWEEN ? AND ?
CREATE INDEX IF NOT EXISTS idx_measurements_tank_date_range
ON measurements(tank_id, measured_at)
WHERE deleted_at IS NULL;

-- Index for descending date order (most recent first)
CREATE INDEX IF NOT EXISTS idx_measurements_tank_date_desc
ON measurements(tank_id, measured_at DESC)
WHERE deleted_at IS NULL;

-- ============================================================================
-- DAILY AVERAGES VIEW
-- Aggregates measurements by day for charting and trend analysis.
-- Calculates AVG for all water parameters grouped by tank and date.
-- ============================================================================

CREATE VIEW IF NOT EXISTS v_daily_averages AS
SELECT
    tank_id,
    DATE(measured_at) AS measurement_date,
    COUNT(*) AS sample_count,
    ROUND(AVG(ph), 2) AS avg_ph,
    ROUND(AVG(alkalinity), 2) AS avg_alkalinity,
    ROUND(AVG(calcium), 1) AS avg_calcium,
    ROUND(AVG(magnesium), 1) AS avg_magnesium,
    ROUND(AVG(nitrate), 2) AS avg_nitrate,
    ROUND(AVG(phosphate), 3) AS avg_phosphate,
    ROUND(AVG(salinity), 4) AS avg_salinity,
    ROUND(AVG(temperature), 1) AS avg_temperature,
    ROUND(AVG(ammonia), 3) AS avg_ammonia,
    MIN(measured_at) AS first_reading,
    MAX(measured_at) AS last_reading
FROM measurements
WHERE deleted_at IS NULL
GROUP BY tank_id, DATE(measured_at);

-- ============================================================================
-- WEEKLY AVERAGES VIEW
-- Aggregates measurements by ISO week for longer-term trend analysis.
-- Uses strftime('%Y-%W') for ISO year-week format.
-- ============================================================================

CREATE VIEW IF NOT EXISTS v_weekly_averages AS
SELECT
    tank_id,
    strftime('%Y-%W', measured_at) AS year_week,
    DATE(measured_at, 'weekday 0', '-6 days') AS week_start,
    DATE(measured_at, 'weekday 0') AS week_end,
    COUNT(*) AS sample_count,
    ROUND(AVG(ph), 2) AS avg_ph,
    ROUND(AVG(alkalinity), 2) AS avg_alkalinity,
    ROUND(AVG(calcium), 1) AS avg_calcium,
    ROUND(AVG(magnesium), 1) AS avg_magnesium,
    ROUND(AVG(nitrate), 2) AS avg_nitrate,
    ROUND(AVG(phosphate), 3) AS avg_phosphate,
    ROUND(AVG(salinity), 4) AS avg_salinity,
    ROUND(AVG(temperature), 1) AS avg_temperature,
    ROUND(AVG(ammonia), 3) AS avg_ammonia,
    MIN(measured_at) AS first_reading,
    MAX(measured_at) AS last_reading
FROM measurements
WHERE deleted_at IS NULL
GROUP BY tank_id, strftime('%Y-%W', measured_at);

-- ============================================================================
-- MONTHLY AVERAGES VIEW
-- Aggregates measurements by month for long-term trend analysis.
-- Uses strftime('%Y-%m') for year-month format.
-- ============================================================================

CREATE VIEW IF NOT EXISTS v_monthly_averages AS
SELECT
    tank_id,
    strftime('%Y-%m', measured_at) AS year_month,
    DATE(measured_at, 'start of month') AS month_start,
    DATE(measured_at, 'start of month', '+1 month', '-1 day') AS month_end,
    COUNT(*) AS sample_count,
    ROUND(AVG(ph), 2) AS avg_ph,
    ROUND(AVG(alkalinity), 2) AS avg_alkalinity,
    ROUND(AVG(calcium), 1) AS avg_calcium,
    ROUND(AVG(magnesium), 1) AS avg_magnesium,
    ROUND(AVG(nitrate), 2) AS avg_nitrate,
    ROUND(AVG(phosphate), 3) AS avg_phosphate,
    ROUND(AVG(salinity), 4) AS avg_salinity,
    ROUND(AVG(temperature), 1) AS avg_temperature,
    ROUND(AVG(ammonia), 3) AS avg_ammonia,
    MIN(measured_at) AS first_reading,
    MAX(measured_at) AS last_reading
FROM measurements
WHERE deleted_at IS NULL
GROUP BY tank_id, strftime('%Y-%m', measured_at);

-- ============================================================================
-- PARAMETER STATISTICS VIEW
-- Provides min, max, avg, and standard deviation for trend analysis.
-- Used by getParameterTrends() to calculate trend direction.
-- ============================================================================

CREATE VIEW IF NOT EXISTS v_parameter_stats AS
SELECT
    tank_id,
    DATE(measured_at) AS measurement_date,
    -- pH statistics
    AVG(ph) AS avg_ph,
    MIN(ph) AS min_ph,
    MAX(ph) AS max_ph,
    -- Alkalinity statistics
    AVG(alkalinity) AS avg_alkalinity,
    MIN(alkalinity) AS min_alkalinity,
    MAX(alkalinity) AS max_alkalinity,
    -- Calcium statistics
    AVG(calcium) AS avg_calcium,
    MIN(calcium) AS min_calcium,
    MAX(calcium) AS max_calcium,
    -- Magnesium statistics
    AVG(magnesium) AS avg_magnesium,
    MIN(magnesium) AS min_magnesium,
    MAX(magnesium) AS max_magnesium,
    -- Nitrate statistics
    AVG(nitrate) AS avg_nitrate,
    MIN(nitrate) AS min_nitrate,
    MAX(nitrate) AS max_nitrate,
    -- Phosphate statistics
    AVG(phosphate) AS avg_phosphate,
    MIN(phosphate) AS min_phosphate,
    MAX(phosphate) AS max_phosphate,
    -- Salinity statistics
    AVG(salinity) AS avg_salinity,
    MIN(salinity) AS min_salinity,
    MAX(salinity) AS max_salinity,
    -- Temperature statistics
    AVG(temperature) AS avg_temperature,
    MIN(temperature) AS min_temperature,
    MAX(temperature) AS max_temperature,
    -- Ammonia statistics
    AVG(ammonia) AS avg_ammonia,
    MIN(ammonia) AS min_ammonia,
    MAX(ammonia) AS max_ammonia
FROM measurements
WHERE deleted_at IS NULL
GROUP BY tank_id, DATE(measured_at);

-- ============================================================================
-- End of Historical Features Migration
-- ============================================================================
