/**
 * ReefBuddy - Historical Data Access Layer
 * Provides functions for retrieving and analyzing historical measurement data.
 *
 * @data-steward owns this file
 */

// =============================================================================
// TYPE DEFINITIONS
// =============================================================================

/**
 * Water parameter measurement record
 */
export interface Measurement {
  id: string;
  tank_id: string;
  measured_at: string;
  ph: number | null;
  alkalinity: number | null;
  calcium: number | null;
  magnesium: number | null;
  nitrate: number | null;
  phosphate: number | null;
  salinity: number | null;
  temperature: number | null;
  ammonia: number | null;
}

/**
 * Trend direction for a parameter
 */
export type TrendDirection = 'up' | 'down' | 'stable';

/**
 * Trend data for a single parameter
 */
export interface ParameterTrend {
  parameter: string;
  direction: TrendDirection;
  change_percent: number;
  first_value: number | null;
  last_value: number | null;
  avg_value: number | null;
  min_value: number | null;
  max_value: number | null;
  sample_count: number;
}

/**
 * All parameter trends for a tank
 */
export interface TankTrends {
  tank_id: string;
  period_days: number;
  start_date: string;
  end_date: string;
  trends: Record<string, ParameterTrend>;
}

/**
 * Daily/weekly aggregate data
 */
export interface AggregateData {
  period: string;
  period_start: string;
  period_end?: string;
  sample_count: number;
  avg_ph: number | null;
  avg_alkalinity: number | null;
  avg_calcium: number | null;
  avg_magnesium: number | null;
  avg_nitrate: number | null;
  avg_phosphate: number | null;
  avg_salinity: number | null;
  avg_temperature: number | null;
  avg_ammonia: number | null;
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
// CONSTANTS
// =============================================================================

/**
 * List of all water parameters for iteration
 */
const WATER_PARAMETERS = [
  'ph',
  'alkalinity',
  'calcium',
  'magnesium',
  'nitrate',
  'phosphate',
  'salinity',
  'temperature',
  'ammonia',
] as const;

/**
 * Threshold for considering a trend as "stable" (percentage change)
 * Values below this are considered stable, above/below are up/down
 */
const TREND_STABILITY_THRESHOLD = 5;

// =============================================================================
// HISTORICAL DATA FUNCTIONS
// =============================================================================

/**
 * Fetch measurements within a date range for a specific tank.
 *
 * @param db - D1 database instance
 * @param tankId - UUID of the tank
 * @param startDate - Start date in ISO 8601 format (inclusive)
 * @param endDate - End date in ISO 8601 format (inclusive)
 * @returns Array of measurements sorted by date descending
 */
export async function getMeasurementHistory(
  db: D1Database,
  tankId: string,
  startDate: string,
  endDate: string
): Promise<Measurement[]> {
  const query = `
    SELECT
      id, tank_id, measured_at, ph, alkalinity, calcium,
      magnesium, nitrate, phosphate, salinity, temperature, ammonia
    FROM measurements
    WHERE tank_id = ?
      AND measured_at >= ?
      AND measured_at <= ?
      AND deleted_at IS NULL
    ORDER BY measured_at DESC
  `;

  const result = await db.prepare(query).bind(tankId, startDate, endDate).all<Measurement>();

  return result.results;
}

/**
 * Calculate trend direction for a specific parameter over a number of days.
 * Compares the average of the first half of readings to the second half.
 *
 * @param db - D1 database instance
 * @param tankId - UUID of the tank
 * @param parameter - Name of the water parameter
 * @param days - Number of days to analyze
 * @returns Trend information for the parameter
 */
export async function getParameterTrends(
  db: D1Database,
  tankId: string,
  parameter: string,
  days: number
): Promise<ParameterTrend> {
  // Validate parameter name to prevent SQL injection
  if (!WATER_PARAMETERS.includes(parameter as (typeof WATER_PARAMETERS)[number])) {
    throw new Error(`Invalid parameter: ${parameter}`);
  }

  const endDate = new Date().toISOString();
  const startDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();

  // Get all measurements for the period
  const query = `
    SELECT ${parameter} as value, measured_at
    FROM measurements
    WHERE tank_id = ?
      AND measured_at >= ?
      AND measured_at <= ?
      AND ${parameter} IS NOT NULL
      AND deleted_at IS NULL
    ORDER BY measured_at ASC
  `;

  const result = await db
    .prepare(query)
    .bind(tankId, startDate, endDate)
    .all<{ value: number; measured_at: string }>();

  const values = result.results.filter((r) => r.value !== null);

  if (values.length === 0) {
    return {
      parameter,
      direction: 'stable',
      change_percent: 0,
      first_value: null,
      last_value: null,
      avg_value: null,
      min_value: null,
      max_value: null,
      sample_count: 0,
    };
  }

  const numericValues = values.map((v) => v.value);
  const firstValue = numericValues[0];
  const lastValue = numericValues[numericValues.length - 1];
  const avgValue = numericValues.reduce((a, b) => a + b, 0) / numericValues.length;
  const minValue = Math.min(...numericValues);
  const maxValue = Math.max(...numericValues);

  // Calculate trend direction using linear regression slope
  let direction: TrendDirection = 'stable';
  let changePercent = 0;

  if (values.length >= 2 && firstValue !== 0) {
    changePercent = ((lastValue - firstValue) / Math.abs(firstValue)) * 100;

    if (changePercent > TREND_STABILITY_THRESHOLD) {
      direction = 'up';
    } else if (changePercent < -TREND_STABILITY_THRESHOLD) {
      direction = 'down';
    }
  }

  return {
    parameter,
    direction,
    change_percent: Math.round(changePercent * 100) / 100,
    first_value: firstValue,
    last_value: lastValue,
    avg_value: Math.round(avgValue * 100) / 100,
    min_value: minValue,
    max_value: maxValue,
    sample_count: values.length,
  };
}

/**
 * Get trends for all water parameters.
 *
 * @param db - D1 database instance
 * @param tankId - UUID of the tank
 * @param days - Number of days to analyze
 * @returns All parameter trends
 */
export async function getAllParameterTrends(
  db: D1Database,
  tankId: string,
  days: number
): Promise<TankTrends> {
  const endDate = new Date().toISOString();
  const startDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();

  const trends: Record<string, ParameterTrend> = {};

  // Get trends for each parameter
  for (const param of WATER_PARAMETERS) {
    trends[param] = await getParameterTrends(db, tankId, param, days);
  }

  return {
    tank_id: tankId,
    period_days: days,
    start_date: startDate,
    end_date: endDate,
    trends,
  };
}

/**
 * Get daily averages for a tank over a number of days.
 *
 * @param db - D1 database instance
 * @param tankId - UUID of the tank
 * @param days - Number of days to retrieve
 * @returns Array of daily aggregate data
 */
export async function getDailyAverages(
  db: D1Database,
  tankId: string,
  days: number
): Promise<AggregateData[]> {
  const startDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString().split('T')[0];

  const query = `
    SELECT
      measurement_date as period,
      measurement_date as period_start,
      sample_count,
      avg_ph,
      avg_alkalinity,
      avg_calcium,
      avg_magnesium,
      avg_nitrate,
      avg_phosphate,
      avg_salinity,
      avg_temperature,
      avg_ammonia
    FROM v_daily_averages
    WHERE tank_id = ?
      AND measurement_date >= ?
    ORDER BY measurement_date DESC
  `;

  const result = await db.prepare(query).bind(tankId, startDate).all<AggregateData>();

  return result.results;
}

/**
 * Get weekly averages for a tank over a number of weeks.
 *
 * @param db - D1 database instance
 * @param tankId - UUID of the tank
 * @param weeks - Number of weeks to retrieve
 * @returns Array of weekly aggregate data
 */
export async function getWeeklyAverages(
  db: D1Database,
  tankId: string,
  weeks: number
): Promise<AggregateData[]> {
  const startDate = new Date(Date.now() - weeks * 7 * 24 * 60 * 60 * 1000)
    .toISOString()
    .split('T')[0];

  const query = `
    SELECT
      year_week as period,
      week_start as period_start,
      week_end as period_end,
      sample_count,
      avg_ph,
      avg_alkalinity,
      avg_calcium,
      avg_magnesium,
      avg_nitrate,
      avg_phosphate,
      avg_salinity,
      avg_temperature,
      avg_ammonia
    FROM v_weekly_averages
    WHERE tank_id = ?
      AND week_start >= ?
    ORDER BY week_start DESC
  `;

  const result = await db.prepare(query).bind(tankId, startDate).all<AggregateData>();

  return result.results;
}

/**
 * Get monthly averages for a tank over a number of months.
 *
 * @param db - D1 database instance
 * @param tankId - UUID of the tank
 * @param months - Number of months to retrieve
 * @returns Array of monthly aggregate data
 */
export async function getMonthlyAverages(
  db: D1Database,
  tankId: string,
  months: number
): Promise<AggregateData[]> {
  const startDate = new Date(Date.now() - months * 30 * 24 * 60 * 60 * 1000)
    .toISOString()
    .split('T')[0];

  const query = `
    SELECT
      year_month as period,
      month_start as period_start,
      month_end as period_end,
      sample_count,
      avg_ph,
      avg_alkalinity,
      avg_calcium,
      avg_magnesium,
      avg_nitrate,
      avg_phosphate,
      avg_salinity,
      avg_temperature,
      avg_ammonia
    FROM v_monthly_averages
    WHERE tank_id = ?
      AND month_start >= ?
    ORDER BY month_start DESC
  `;

  const result = await db.prepare(query).bind(tankId, startDate).all<AggregateData>();

  return result.results;
}
