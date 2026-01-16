/**
 * ReefBuddy - Push Notifications Module
 * Handles parameter alerts, push notification delivery, and notification management
 *
 * @edge-engineer owns this file
 */

import { z } from 'zod';

// =============================================================================
// TYPE DEFINITIONS
// =============================================================================

/**
 * Water parameter names that can have alert thresholds
 */
export type ParameterName =
  | 'ph'
  | 'alkalinity'
  | 'calcium'
  | 'magnesium'
  | 'ammonia'
  | 'nitrate'
  | 'phosphate'
  | 'salinity'
  | 'temperature';

/**
 * Notification setting for a single parameter
 */
export interface NotificationSetting {
  id: string;
  user_id: string;
  parameter: ParameterName;
  min_threshold: number | null;
  max_threshold: number | null;
  enabled: boolean;
  created_at: string;
  updated_at: string;
}

/**
 * Push token record
 */
export interface PushToken {
  id: string;
  user_id: string;
  token: string;
  platform: 'ios' | 'android';
  device_name: string | null;
  created_at: string;
  updated_at: string;
}

/**
 * Notification history record
 */
export interface NotificationHistoryRecord {
  id: string;
  user_id: string;
  type: string;
  title: string;
  body: string;
  parameter: string | null;
  value: number | null;
  threshold_type: 'min' | 'max' | null;
  threshold_value: number | null;
  sent_at: string;
  read_at: string | null;
}

/**
 * Measurement data for alert checking
 */
export interface MeasurementData {
  id: string;
  tank_id: string;
  ph?: number | null;
  alkalinity?: number | null;
  calcium?: number | null;
  magnesium?: number | null;
  ammonia?: number | null;
  nitrate?: number | null;
  phosphate?: number | null;
  salinity?: number | null;
  temperature?: number | null;
}

/**
 * Alert generated when a parameter is out of range
 */
export interface ParameterAlert {
  parameter: ParameterName;
  value: number;
  thresholdType: 'min' | 'max';
  thresholdValue: number;
  message: string;
}

/**
 * Result of sending a push notification
 */
export interface PushResult {
  success: boolean;
  token: string;
  error?: string;
}

// =============================================================================
// ZOD SCHEMAS
// =============================================================================

/**
 * Schema for registering a push token
 */
export const RegisterTokenSchema = z.object({
  token: z.string().min(1).max(500),
  platform: z.enum(['ios', 'android']),
  deviceName: z.string().max(100).optional(),
});

/**
 * Schema for updating notification settings
 */
export const UpdateSettingsSchema = z.object({
  settings: z.array(
    z.object({
      parameter: z.enum([
        'ph',
        'alkalinity',
        'calcium',
        'magnesium',
        'ammonia',
        'nitrate',
        'phosphate',
        'salinity',
        'temperature',
      ]),
      minThreshold: z.number().nullable().optional(),
      maxThreshold: z.number().nullable().optional(),
      enabled: z.boolean().optional(),
    })
  ),
});

/**
 * Schema for notification history query
 */
export const HistoryQuerySchema = z.object({
  limit: z.coerce.number().min(1).max(100).default(50),
  offset: z.coerce.number().min(0).default(0),
  type: z.string().optional(),
  unreadOnly: z.coerce.boolean().default(false),
});

// =============================================================================
// DEFAULT THRESHOLDS
// =============================================================================

/**
 * Default alert thresholds for reef aquarium parameters
 * Based on best practices for saltwater reef tanks
 */
export const DEFAULT_THRESHOLDS: Record<
  ParameterName,
  { min: number | null; max: number | null; unit: string }
> = {
  ph: { min: 7.8, max: 8.4, unit: '' },
  alkalinity: { min: 7, max: 11, unit: 'dKH' },
  calcium: { min: 380, max: 450, unit: 'ppm' },
  magnesium: { min: 1250, max: 1400, unit: 'ppm' },
  ammonia: { min: 0, max: 0.25, unit: 'ppm' },
  nitrate: { min: 0, max: 20, unit: 'ppm' },
  phosphate: { min: 0, max: 0.1, unit: 'ppm' },
  salinity: { min: 1.023, max: 1.026, unit: 'SG' },
  temperature: { min: 75, max: 80, unit: 'F' },
};

/**
 * Human-readable names for parameters
 */
const PARAMETER_NAMES: Record<ParameterName, string> = {
  ph: 'pH',
  alkalinity: 'Alkalinity',
  calcium: 'Calcium',
  magnesium: 'Magnesium',
  ammonia: 'Ammonia',
  nitrate: 'Nitrate',
  phosphate: 'Phosphate',
  salinity: 'Salinity',
  temperature: 'Temperature',
};

// =============================================================================
// ALERT CHECKING FUNCTIONS
// =============================================================================

/**
 * Check if a measurement value is out of range based on settings
 * @param measurement - The measurement data to check
 * @param settings - User's notification settings for each parameter
 * @returns Array of alerts for parameters that are out of range
 */
export function checkParameterAlerts(
  measurement: MeasurementData,
  settings: NotificationSetting[]
): ParameterAlert[] {
  const alerts: ParameterAlert[] = [];

  // Create a map of settings by parameter for efficient lookup
  const settingsMap = new Map<string, NotificationSetting>();
  for (const setting of settings) {
    if (setting.enabled) {
      settingsMap.set(setting.parameter, setting);
    }
  }

  // Check each parameter in the measurement
  const parametersToCheck: Array<{ name: ParameterName; value: number | null | undefined }> = [
    { name: 'ph', value: measurement.ph },
    { name: 'alkalinity', value: measurement.alkalinity },
    { name: 'calcium', value: measurement.calcium },
    { name: 'magnesium', value: measurement.magnesium },
    { name: 'ammonia', value: measurement.ammonia },
    { name: 'nitrate', value: measurement.nitrate },
    { name: 'phosphate', value: measurement.phosphate },
    { name: 'salinity', value: measurement.salinity },
    { name: 'temperature', value: measurement.temperature },
  ];

  for (const param of parametersToCheck) {
    if (param.value === null || param.value === undefined) {
      continue;
    }

    const setting = settingsMap.get(param.name);
    if (!setting) {
      continue;
    }

    // Check minimum threshold
    if (setting.min_threshold !== null && param.value < setting.min_threshold) {
      alerts.push({
        parameter: param.name,
        value: param.value,
        thresholdType: 'min',
        thresholdValue: setting.min_threshold,
        message: formatAlertMessage(param.name, param.value, 'min', setting.min_threshold),
      });
    }

    // Check maximum threshold
    if (setting.max_threshold !== null && param.value > setting.max_threshold) {
      alerts.push({
        parameter: param.name,
        value: param.value,
        thresholdType: 'max',
        thresholdValue: setting.max_threshold,
        message: formatAlertMessage(param.name, param.value, 'max', setting.max_threshold),
      });
    }
  }

  return alerts;
}

/**
 * Format an alert message for a parameter that is out of range
 * @param parameter - The parameter name
 * @param value - The measured value
 * @param thresholdType - Whether it's a min or max threshold violation
 * @param threshold - The threshold value that was violated
 * @returns Formatted alert message string
 */
export function formatAlertMessage(
  parameter: ParameterName,
  value: number,
  thresholdType: 'min' | 'max',
  threshold: number
): string {
  const paramName = PARAMETER_NAMES[parameter];
  const defaults = DEFAULT_THRESHOLDS[parameter];
  const unit = defaults.unit;

  const valueStr = unit ? `${value}${unit}` : `${value}`;
  const thresholdStr = unit ? `${threshold}${unit}` : `${threshold}`;

  if (thresholdType === 'min') {
    return `${paramName} is too low at ${valueStr} (minimum: ${thresholdStr})`;
  } else {
    return `${paramName} is too high at ${valueStr} (maximum: ${thresholdStr})`;
  }
}

// =============================================================================
// PUSH NOTIFICATION DELIVERY
// =============================================================================

/**
 * APNs (Apple Push Notification service) configuration
 * In production, this would use JWT authentication with Apple Developer credentials
 */
interface APNsConfig {
  teamId: string;
  keyId: string;
  privateKey: string;
  bundleId: string;
  production: boolean;
}

/**
 * FCM (Firebase Cloud Messaging) configuration
 * In production, this would use a service account key
 */
interface FCMConfig {
  projectId: string;
  privateKey: string;
  clientEmail: string;
}

/**
 * Send a push notification to a device
 * This is a placeholder implementation - actual APNs/FCM integration would require:
 * - APNs: JWT token generation, HTTP/2 connection to Apple servers
 * - FCM: OAuth2 token generation, HTTP request to FCM API
 *
 * @param token - The device push token
 * @param platform - 'ios' for APNs, 'android' for FCM
 * @param title - Notification title
 * @param body - Notification body text
 * @param data - Optional additional data payload
 * @returns Result of the push notification attempt
 */
export async function sendPushNotification(
  token: string,
  platform: 'ios' | 'android',
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<PushResult> {
  // In production, this would:
  // 1. For iOS (APNs): Generate JWT, send HTTP/2 request to api.push.apple.com
  // 2. For Android (FCM): Get OAuth2 token, send HTTP request to FCM API

  // For now, we log the notification and return success
  // This allows the notification history to be recorded and tested
  console.log(`[${platform.toUpperCase()}] Push notification to ${token.substring(0, 20)}...`);
  console.log(`  Title: ${title}`);
  console.log(`  Body: ${body}`);
  if (data) {
    console.log(`  Data: ${JSON.stringify(data)}`);
  }

  // Placeholder: In production, check the actual response from APNs/FCM
  // and return appropriate success/failure status

  return {
    success: true,
    token,
  };
}

/**
 * Send push notifications to all of a user's devices
 * @param tokens - Array of push tokens for the user
 * @param title - Notification title
 * @param body - Notification body text
 * @param data - Optional additional data payload
 * @returns Array of results for each token
 */
export async function sendToAllDevices(
  tokens: PushToken[],
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<PushResult[]> {
  const results = await Promise.all(
    tokens.map((t) => sendPushNotification(t.token, t.platform, title, body, data))
  );

  return results;
}

// =============================================================================
// DATABASE OPERATIONS
// =============================================================================

/**
 * Get notification settings for a user
 * If the user has no settings, returns empty array (defaults should be created via API)
 */
export async function getUserNotificationSettings(
  db: D1Database,
  userId: string
): Promise<NotificationSetting[]> {
  const result = await db
    .prepare(
      `SELECT id, user_id, parameter, min_threshold, max_threshold, enabled, created_at, updated_at
       FROM notification_settings
       WHERE user_id = ?
       ORDER BY parameter`
    )
    .bind(userId)
    .all();

  return (result.results || []).map((row) => ({
    id: row.id as string,
    user_id: row.user_id as string,
    parameter: row.parameter as ParameterName,
    min_threshold: row.min_threshold as number | null,
    max_threshold: row.max_threshold as number | null,
    enabled: Boolean(row.enabled),
    created_at: row.created_at as string,
    updated_at: row.updated_at as string,
  }));
}

/**
 * Create or update notification settings for a user
 * Uses SQLite UPSERT (INSERT OR REPLACE) for atomic operation
 */
export async function upsertNotificationSetting(
  db: D1Database,
  userId: string,
  parameter: ParameterName,
  minThreshold: number | null,
  maxThreshold: number | null,
  enabled: boolean
): Promise<NotificationSetting> {
  const id = crypto.randomUUID();
  const now = new Date().toISOString();

  await db
    .prepare(
      `INSERT INTO notification_settings (id, user_id, parameter, min_threshold, max_threshold, enabled, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(user_id, parameter) DO UPDATE SET
         min_threshold = excluded.min_threshold,
         max_threshold = excluded.max_threshold,
         enabled = excluded.enabled,
         updated_at = excluded.updated_at`
    )
    .bind(id, userId, parameter, minThreshold, maxThreshold, enabled ? 1 : 0, now, now)
    .run();

  // Fetch the actual record (may have been updated rather than inserted)
  const result = await db
    .prepare(
      `SELECT id, user_id, parameter, min_threshold, max_threshold, enabled, created_at, updated_at
       FROM notification_settings
       WHERE user_id = ? AND parameter = ?`
    )
    .bind(userId, parameter)
    .first();

  return {
    id: result!.id as string,
    user_id: result!.user_id as string,
    parameter: result!.parameter as ParameterName,
    min_threshold: result!.min_threshold as number | null,
    max_threshold: result!.max_threshold as number | null,
    enabled: Boolean(result!.enabled),
    created_at: result!.created_at as string,
    updated_at: result!.updated_at as string,
  };
}

/**
 * Initialize default notification settings for a user
 * Called when user first accesses notification settings
 */
export async function initializeDefaultSettings(
  db: D1Database,
  userId: string
): Promise<NotificationSetting[]> {
  const settings: NotificationSetting[] = [];

  for (const [param, defaults] of Object.entries(DEFAULT_THRESHOLDS)) {
    const setting = await upsertNotificationSetting(
      db,
      userId,
      param as ParameterName,
      defaults.min,
      defaults.max,
      true // Enabled by default
    );
    settings.push(setting);
  }

  return settings;
}

/**
 * Get push tokens for a user
 */
export async function getUserPushTokens(db: D1Database, userId: string): Promise<PushToken[]> {
  const result = await db
    .prepare(
      `SELECT id, user_id, token, platform, device_name, created_at, updated_at
       FROM push_tokens
       WHERE user_id = ?
       ORDER BY created_at DESC`
    )
    .bind(userId)
    .all();

  return (result.results || []).map((row) => ({
    id: row.id as string,
    user_id: row.user_id as string,
    token: row.token as string,
    platform: row.platform as 'ios' | 'android',
    device_name: row.device_name as string | null,
    created_at: row.created_at as string,
    updated_at: row.updated_at as string,
  }));
}

/**
 * Register or update a push token for a user
 */
export async function registerPushToken(
  db: D1Database,
  userId: string,
  token: string,
  platform: 'ios' | 'android',
  deviceName?: string
): Promise<PushToken> {
  const id = crypto.randomUUID();
  const now = new Date().toISOString();

  // Use UPSERT to handle token registration/update
  // If token already exists (for any user), update it to the current user
  await db
    .prepare(
      `INSERT INTO push_tokens (id, user_id, token, platform, device_name, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(token) DO UPDATE SET
         user_id = excluded.user_id,
         platform = excluded.platform,
         device_name = excluded.device_name,
         updated_at = excluded.updated_at`
    )
    .bind(id, userId, token, platform, deviceName || null, now, now)
    .run();

  // Fetch the actual record
  const result = await db
    .prepare(
      `SELECT id, user_id, token, platform, device_name, created_at, updated_at
       FROM push_tokens
       WHERE token = ?`
    )
    .bind(token)
    .first();

  return {
    id: result!.id as string,
    user_id: result!.user_id as string,
    token: result!.token as string,
    platform: result!.platform as 'ios' | 'android',
    device_name: result!.device_name as string | null,
    created_at: result!.created_at as string,
    updated_at: result!.updated_at as string,
  };
}

/**
 * Unregister a push token
 */
export async function unregisterPushToken(db: D1Database, token: string): Promise<boolean> {
  const result = await db.prepare(`DELETE FROM push_tokens WHERE token = ?`).bind(token).run();

  return (result.meta?.changes ?? 0) > 0;
}

/**
 * Record a notification in history
 */
export async function recordNotification(
  db: D1Database,
  userId: string,
  type: string,
  title: string,
  body: string,
  parameter?: string,
  value?: number,
  thresholdType?: 'min' | 'max',
  thresholdValue?: number
): Promise<NotificationHistoryRecord> {
  const id = crypto.randomUUID();
  const now = new Date().toISOString();

  await db
    .prepare(
      `INSERT INTO notification_history (id, user_id, type, title, body, parameter, value, threshold_type, threshold_value, sent_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    )
    .bind(
      id,
      userId,
      type,
      title,
      body,
      parameter || null,
      value ?? null,
      thresholdType || null,
      thresholdValue ?? null,
      now
    )
    .run();

  return {
    id,
    user_id: userId,
    type,
    title,
    body,
    parameter: parameter || null,
    value: value ?? null,
    threshold_type: thresholdType || null,
    threshold_value: thresholdValue ?? null,
    sent_at: now,
    read_at: null,
  };
}

/**
 * Get notification history for a user
 */
export async function getNotificationHistory(
  db: D1Database,
  userId: string,
  limit: number = 50,
  offset: number = 0,
  type?: string,
  unreadOnly: boolean = false
): Promise<{ notifications: NotificationHistoryRecord[]; total: number }> {
  // Build query based on filters
  let whereClause = 'WHERE user_id = ?';
  const params: (string | number)[] = [userId];

  if (type) {
    whereClause += ' AND type = ?';
    params.push(type);
  }

  if (unreadOnly) {
    whereClause += ' AND read_at IS NULL';
  }

  // Get total count
  const countResult = await db
    .prepare(`SELECT COUNT(*) as count FROM notification_history ${whereClause}`)
    .bind(...params)
    .first();
  const total = (countResult?.count as number) || 0;

  // Get paginated results
  const query = `
    SELECT id, user_id, type, title, body, parameter, value, threshold_type, threshold_value, sent_at, read_at
    FROM notification_history
    ${whereClause}
    ORDER BY sent_at DESC
    LIMIT ? OFFSET ?
  `;

  const result = await db
    .prepare(query)
    .bind(...params, limit, offset)
    .all();

  const notifications = (result.results || []).map((row) => ({
    id: row.id as string,
    user_id: row.user_id as string,
    type: row.type as string,
    title: row.title as string,
    body: row.body as string,
    parameter: row.parameter as string | null,
    value: row.value as number | null,
    threshold_type: row.threshold_type as 'min' | 'max' | null,
    threshold_value: row.threshold_value as number | null,
    sent_at: row.sent_at as string,
    read_at: row.read_at as string | null,
  }));

  return { notifications, total };
}

/**
 * Mark notifications as read
 */
export async function markNotificationsRead(
  db: D1Database,
  userId: string,
  notificationIds?: string[]
): Promise<number> {
  const now = new Date().toISOString();

  if (notificationIds && notificationIds.length > 0) {
    // Mark specific notifications as read
    const placeholders = notificationIds.map(() => '?').join(',');
    const result = await db
      .prepare(
        `UPDATE notification_history
         SET read_at = ?
         WHERE user_id = ? AND id IN (${placeholders}) AND read_at IS NULL`
      )
      .bind(now, userId, ...notificationIds)
      .run();

    return result.meta?.changes ?? 0;
  } else {
    // Mark all notifications as read
    const result = await db
      .prepare(
        `UPDATE notification_history
         SET read_at = ?
         WHERE user_id = ? AND read_at IS NULL`
      )
      .bind(now, userId)
      .run();

    return result.meta?.changes ?? 0;
  }
}

// =============================================================================
// HIGH-LEVEL NOTIFICATION WORKFLOW
// =============================================================================

/**
 * Process alerts for a measurement and send notifications if needed
 * This is the main entry point called after saving a measurement
 *
 * @param db - D1 database instance
 * @param userId - User ID who owns the tank
 * @param measurement - The measurement data to check
 * @param tankName - Name of the tank for notification context
 * @returns Array of alerts that were generated (and notifications sent)
 */
export async function processAlertsForMeasurement(
  db: D1Database,
  userId: string,
  measurement: MeasurementData,
  tankName: string
): Promise<ParameterAlert[]> {
  // Get user's notification settings
  let settings = await getUserNotificationSettings(db, userId);

  // If no settings exist, initialize with defaults
  if (settings.length === 0) {
    settings = await initializeDefaultSettings(db, userId);
  }

  // Check for alerts
  const alerts = checkParameterAlerts(measurement, settings);

  if (alerts.length === 0) {
    return [];
  }

  // Get user's push tokens
  const tokens = await getUserPushTokens(db, userId);

  // Process each alert
  for (const alert of alerts) {
    const title = `Alert: ${PARAMETER_NAMES[alert.parameter]}`;
    const body = `${tankName}: ${alert.message}`;

    // Send push notifications to all devices
    if (tokens.length > 0) {
      await sendToAllDevices(tokens, title, body, {
        type: 'parameter_alert',
        parameter: alert.parameter,
        tankId: measurement.tank_id,
      });
    }

    // Record in notification history
    await recordNotification(
      db,
      userId,
      'parameter_alert',
      title,
      body,
      alert.parameter,
      alert.value,
      alert.thresholdType,
      alert.thresholdValue
    );
  }

  return alerts;
}
