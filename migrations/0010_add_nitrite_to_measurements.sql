-- ============================================================================
-- ReefBuddy Add Nitrite Column Migration
-- Migration: 0010_add_nitrite_to_measurements.sql
-- Description: Adds nitrite (NO2) parameter to measurements table.
--              Nitrite is part of the nitrogen cycle and should be 0 ppm
--              in established tanks. Any detectable amount indicates
--              incomplete cycling or filter issues.
-- ============================================================================

ALTER TABLE measurements ADD COLUMN nitrite REAL CHECK (nitrite IS NULL OR nitrite >= 0);

-- ============================================================================
-- End of Migration
-- ============================================================================
