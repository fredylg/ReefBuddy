/**
 * ReefBuddy - Data Export Module
 * Provides CSV export functionality for measurement data.
 *
 * @data-steward owns this file
 */

import { getMeasurementHistory, Measurement } from './historical';

// =============================================================================
// TYPE DEFINITIONS
// =============================================================================

/**
 * Tank information for export metadata
 */
export interface TankInfo {
  id: string;
  name: string;
  volume_gallons: number;
  tank_type: string;
  created_at: string;
}

/**
 * D1Database interface for type safety
 */
interface D1Database {
  prepare(query: string): D1PreparedStatement;
}

interface D1PreparedStatement {
  bind(...values: unknown[]): D1PreparedStatement;
  all<T = unknown>(): Promise<D1Result<T>>;
  first<T = unknown>(): Promise<T | null>;
}

interface D1Result<T> {
  results: T[];
  success: boolean;
  meta?: Record<string, unknown>;
}

// =============================================================================
// CSV EXPORT FUNCTIONS
// =============================================================================

/**
 * CSV column headers for measurement export
 */
const CSV_HEADERS = [
  'Measurement ID',
  'Measured At (ISO 8601)',
  'pH',
  'Alkalinity (dKH)',
  'Calcium (ppm)',
  'Magnesium (ppm)',
  'Nitrate (ppm)',
  'Phosphate (ppm)',
  'Salinity',
  'Salinity unit',
  'Temperature (F)',
  'Ammonia (ppm)',
  'Nitrite (ppm)',
  'Notes',
];

/**
 * Escape a value for CSV format.
 * Wraps in quotes if contains comma, quote, or newline.
 *
 * @param value - Value to escape
 * @returns Escaped CSV value
 */
function escapeCSVValue(value: string | number | null | undefined): string {
  if (value === null || value === undefined) {
    return '';
  }

  const stringValue = String(value);

  // Check if value needs quoting
  if (stringValue.includes(',') || stringValue.includes('"') || stringValue.includes('\n')) {
    // Escape double quotes by doubling them
    return `"${stringValue.replace(/"/g, '""')}"`;
  }

  return stringValue;
}

/**
 * Convert a measurement record to a CSV row.
 *
 * @param measurement - Measurement record
 * @returns CSV row as string
 */
function measurementToCSVRow(measurement: Measurement): string {
  const values = [
    measurement.id,
    measurement.measured_at,
    measurement.ph,
    measurement.alkalinity,
    measurement.calcium,
    measurement.magnesium,
    measurement.nitrate,
    measurement.phosphate,
    measurement.salinity,
    measurement.salinity_unit ?? '',
    measurement.temperature,
    measurement.ammonia,
    measurement.nitrite,
    measurement.notes,
  ];

  return values.map(escapeCSVValue).join(',');
}

/**
 * Generate metadata rows for the CSV export.
 *
 * @param tank - Tank information
 * @param startDate - Export start date
 * @param endDate - Export end date
 * @param recordCount - Number of records exported
 * @returns Array of metadata lines
 */
function generateMetadataRows(
  tank: TankInfo,
  startDate: string,
  endDate: string,
  recordCount: number
): string[] {
  const exportedAt = new Date().toISOString();

  return [
    '# ReefBuddy Measurement Export',
    `# Tank Name: ${escapeCSVValue(tank.name)}`,
    `# Tank ID: ${tank.id}`,
    `# Tank Volume: ${tank.volume_gallons} gallons`,
    `# Tank Type: ${tank.tank_type || 'Not specified'}`,
    `# Date Range: ${startDate} to ${endDate}`,
    `# Record Count: ${recordCount}`,
    `# Exported At: ${exportedAt}`,
    '#',
  ];
}

/**
 * Export measurements to CSV format.
 *
 * @param db - D1 database instance
 * @param tankId - UUID of the tank
 * @param startDate - Start date in ISO 8601 format
 * @param endDate - End date in ISO 8601 format
 * @returns CSV string with metadata header and measurement data
 */
export async function exportMeasurementsToCSV(
  db: D1Database,
  tankId: string,
  startDate: string,
  endDate: string
): Promise<string> {
  // Fetch tank information for metadata
  const tank = await db
    .prepare(
      `
    SELECT id, name, volume_gallons, tank_type, created_at
    FROM tanks
    WHERE id = ?
      AND deleted_at IS NULL
  `
    )
    .bind(tankId)
    .first<TankInfo>();

  if (!tank) {
    throw new Error('Tank not found');
  }

  // Fetch measurements using the historical data access layer
  const measurements = await getMeasurementHistory(db, tankId, startDate, endDate);

  // Build CSV content
  const lines: string[] = [];

  // Add metadata rows
  lines.push(...generateMetadataRows(tank, startDate, endDate, measurements.length));

  // Add header row
  lines.push(CSV_HEADERS.join(','));

  // Add data rows
  for (const measurement of measurements) {
    lines.push(measurementToCSVRow(measurement));
  }

  return lines.join('\n');
}

