-- Migration 0015: index cleanup, nitrite in aggregate views, ISO weeks
-- (maintenance plan P3-26; review items M-02, B-27, B-30)
--
-- Note on numbering: there is no 0008. It was never created; D1 tracks migrations by
-- filename, so the gap is harmless and must not be "filled".

-- ----------------------------------------------------------------------------
-- Redundant indexes (write cost on every insert, no read benefit)
-- ----------------------------------------------------------------------------
DROP INDEX IF EXISTS idx_measurements_tank;             -- same columns as idx_measurements_active
DROP INDEX IF EXISTS idx_measurements_tank_date_range;  -- same columns as idx_measurements_active
DROP INDEX IF EXISTS idx_measurements_tank_date_desc;   -- identical to idx_measurements_active
DROP INDEX IF EXISTS idx_users_email;                   -- users.email is UNIQUE (implicit index)
DROP INDEX IF EXISTS idx_purchase_history_transaction;  -- apple_transaction_id is UNIQUE
DROP INDEX IF EXISTS idx_push_tokens_token;             -- push_tokens.token is UNIQUE

-- FK column used when a maintenance schedule is looked up from a water change
CREATE INDEX IF NOT EXISTS idx_water_changes_source_schedule
ON water_changes(source_schedule_id)
WHERE source_schedule_id IS NOT NULL;

-- ----------------------------------------------------------------------------
-- Views: v_parameter_stats was never referenced; the averages views gain nitrite
-- and the weekly view uses a consistent Monday-start week.
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS v_parameter_stats;
DROP VIEW IF EXISTS v_daily_averages;
DROP VIEW IF EXISTS v_weekly_averages;
DROP VIEW IF EXISTS v_monthly_averages;

CREATE VIEW v_daily_averages AS
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
    ROUND(AVG(nitrite), 3) AS avg_nitrite,
    MIN(measured_at) AS first_reading,
    MAX(measured_at) AS last_reading
FROM measurements
WHERE deleted_at IS NULL
GROUP BY tank_id, DATE(measured_at);

-- Weeks start on Monday: shift each reading back to its Monday, then group on that date.
CREATE VIEW v_weekly_averages AS
SELECT
    tank_id,
    strftime('%Y-%W', DATE(measured_at, '-' || ((strftime('%w', measured_at) + 6) % 7) || ' days')) AS year_week,
    DATE(measured_at, '-' || ((strftime('%w', measured_at) + 6) % 7) || ' days') AS week_start,
    DATE(measured_at, '-' || ((strftime('%w', measured_at) + 6) % 7) || ' days', '+6 days') AS week_end,
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
    ROUND(AVG(nitrite), 3) AS avg_nitrite,
    MIN(measured_at) AS first_reading,
    MAX(measured_at) AS last_reading
FROM measurements
WHERE deleted_at IS NULL
GROUP BY tank_id, DATE(measured_at, '-' || ((strftime('%w', measured_at) + 6) % 7) || ' days');

CREATE VIEW v_monthly_averages AS
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
    ROUND(AVG(nitrite), 3) AS avg_nitrite,
    MIN(measured_at) AS first_reading,
    MAX(measured_at) AS last_reading
FROM measurements
WHERE deleted_at IS NULL
GROUP BY tank_id, strftime('%Y-%m', measured_at);
