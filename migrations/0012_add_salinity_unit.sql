-- Migration: 0012_add_salinity_unit.sql
-- Description: Adds salinity_unit to measurements table.
-- Values: 'SG' (specific gravity) or 'PPT' (parts per thousand).
-- Nullable for backward compatibility with existing rows.

ALTER TABLE measurements ADD COLUMN salinity_unit TEXT CHECK (salinity_unit IS NULL OR salinity_unit IN ('SG', 'PPT'));
