import { z } from 'zod';
import {
  RegisterTokenSchema,
  UpdateSettingsSchema,
  getUserNotificationSettings,
  initializeDefaultSettings,
  upsertNotificationSetting,
  getUserPushTokens,
  registerPushToken,
  unregisterPushToken,
  getNotificationHistory,
  markNotificationsRead,
  DEFAULT_THRESHOLDS,
  type ParameterName,
  type NotificationSetting,
  HistoryQuerySchema as NotificationHistoryQuerySchema,
} from '../notifications';
import { AuthenticatedContext, Env } from '../env';
import { errorResponse, internalError, jsonResponse, readJson } from '../http';
import { LowercaseUuid } from '../schemas';

// =============================================================================
// NOTIFICATION HANDLERS
// =============================================================================

/**
 * Handle registering a push token
 * POST /notifications/token (authenticated)
 */
export async function handleRegisterPushToken(
  request: Request,
  env: Env,
  auth: AuthenticatedContext
): Promise<Response> {
  try {
    const parsedBody = await readJson(request);
    if (!parsedBody.ok) return parsedBody.response;
    const body = parsedBody.body;

    const validationResult = RegisterTokenSchema.safeParse(body);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          details: z.flattenError(validationResult.error),
        },
        400
      );
    }

    const { token, platform, deviceName } = validationResult.data;

    const pushToken = await registerPushToken(env.DB, auth.userId, token, platform, deviceName);

    return jsonResponse(
      {
        success: true,
        token: {
          id: pushToken.id,
          platform: pushToken.platform,
          device_name: pushToken.device_name,
          created_at: pushToken.created_at,
        },
      },
      201
    );
  } catch (error) {
    console.error('Register push token error:', error);
    return internalError('Unhandled error', error);
  }
}

/**
 * Handle unregistering a push token
 * DELETE /notifications/token (authenticated)
 */
export async function handleUnregisterPushToken(
  request: Request,
  env: Env,
  auth: AuthenticatedContext
): Promise<Response> {
  try {
    const parsedBody = await readJson(request);
    if (!parsedBody.ok) return parsedBody.response;
    const body = parsedBody.body;

    const tokenSchema = z.object({ token: z.string().min(1) });
    const validationResult = tokenSchema.safeParse(body);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          details: z.flattenError(validationResult.error),
        },
        400
      );
    }

    const { token } = validationResult.data;

    // Verify the token belongs to this user before deleting
    const userTokens = await getUserPushTokens(env.DB, auth.userId);
    const ownsToken = userTokens.some((t) => t.token === token);

    if (!ownsToken) {
      return errorResponse('Not found', 'Push token not found or does not belong to this user', 404);
    }

    const deleted = await unregisterPushToken(env.DB, token);

    if (!deleted) {
      return errorResponse('Not found', 'Push token not found', 404);
    }

    return jsonResponse({
      success: true,
      message: 'Push token unregistered successfully',
    });
  } catch (error) {
    console.error('Unregister push token error:', error);
    return internalError('Unhandled error', error);
  }
}

/**
 * Handle getting notification settings
 * GET /notifications/settings (authenticated)
 */
export async function handleGetNotificationSettings(env: Env, auth: AuthenticatedContext): Promise<Response> {
  try {
    let settings = await getUserNotificationSettings(env.DB, auth.userId);

    // If no settings exist, initialize with defaults
    if (settings.length === 0) {
      settings = await initializeDefaultSettings(env.DB, auth.userId);
    }

    // Transform settings to a more user-friendly format
    const settingsMap: Record<
      string,
      {
        minThreshold: number | null;
        maxThreshold: number | null;
        enabled: boolean;
        defaultMin: number | null;
        defaultMax: number | null;
      }
    > = {};

    for (const setting of settings) {
      const defaults = DEFAULT_THRESHOLDS[setting.parameter];
      settingsMap[setting.parameter] = {
        minThreshold: setting.min_threshold,
        maxThreshold: setting.max_threshold,
        enabled: setting.enabled,
        defaultMin: defaults?.min ?? null,
        defaultMax: defaults?.max ?? null,
      };
    }

    return jsonResponse({
      success: true,
      settings: settingsMap,
    });
  } catch (error) {
    console.error('Get notification settings error:', error);
    return internalError('Unhandled error', error);
  }
}

/**
 * Handle updating notification settings
 * PUT /notifications/settings (authenticated)
 */
export async function handleUpdateNotificationSettings(
  request: Request,
  env: Env,
  auth: AuthenticatedContext
): Promise<Response> {
  try {
    const parsedBody = await readJson(request);
    if (!parsedBody.ok) return parsedBody.response;
    const body = parsedBody.body;

    const validationResult = UpdateSettingsSchema.safeParse(body);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          details: z.flattenError(validationResult.error),
        },
        400
      );
    }

    const { settings } = validationResult.data;

    // Update each setting
    const updatedSettings: NotificationSetting[] = [];
    const existingSettings = await getUserNotificationSettings(env.DB, auth.userId);
    for (const setting of settings) {
      const existing = existingSettings.find((s) => s.parameter === setting.parameter);
      const defaults = DEFAULT_THRESHOLDS[setting.parameter as ParameterName];

      const minThreshold =
        setting.minThreshold !== undefined ? setting.minThreshold : (existing?.min_threshold ?? defaults?.min ?? null);

      const maxThreshold =
        setting.maxThreshold !== undefined ? setting.maxThreshold : (existing?.max_threshold ?? defaults?.max ?? null);

      const enabled = setting.enabled !== undefined ? setting.enabled : (existing?.enabled ?? true);

      const updated = await upsertNotificationSetting(
        env.DB,
        auth.userId,
        setting.parameter as ParameterName,
        minThreshold,
        maxThreshold,
        enabled
      );

      updatedSettings.push(updated);
    }

    return jsonResponse({
      success: true,
      message: `Updated ${updatedSettings.length} notification setting(s)`,
      settings: updatedSettings.map((s) => ({
        parameter: s.parameter,
        minThreshold: s.min_threshold,
        maxThreshold: s.max_threshold,
        enabled: s.enabled,
      })),
    });
  } catch (error) {
    console.error('Update notification settings error:', error);
    return internalError('Unhandled error', error);
  }
}

/**
 * Handle getting notification history
 * GET /notifications/history (authenticated)
 */
export async function handleGetNotificationHistory(
  request: Request,
  env: Env,
  auth: AuthenticatedContext
): Promise<Response> {
  try {
    const url = new URL(request.url);
    const queryParams = {
      limit: url.searchParams.get('limit') || '50',
      offset: url.searchParams.get('offset') || '0',
      type: url.searchParams.get('type') || undefined,
      unreadOnly: url.searchParams.get('unreadOnly') || 'false',
    };

    const validationResult = NotificationHistoryQuerySchema.safeParse(queryParams);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          details: z.flattenError(validationResult.error),
        },
        400
      );
    }

    const { limit, offset, type, unreadOnly } = validationResult.data;

    const { notifications, total } = await getNotificationHistory(env.DB, auth.userId, limit, offset, type, unreadOnly);

    return jsonResponse({
      success: true,
      total,
      limit,
      offset,
      notifications: notifications.map((n) => ({
        id: n.id,
        type: n.type,
        title: n.title,
        body: n.body,
        parameter: n.parameter,
        value: n.value,
        thresholdType: n.threshold_type,
        thresholdValue: n.threshold_value,
        sentAt: n.sent_at,
        readAt: n.read_at,
      })),
    });
  } catch (error) {
    console.error('Get notification history error:', error);
    return internalError('Unhandled error', error);
  }
}

/**
 * Handle marking notifications as read
 * POST /notifications/read (authenticated)
 */
export async function handleMarkNotificationsRead(
  request: Request,
  env: Env,
  auth: AuthenticatedContext
): Promise<Response> {
  try {
    const parsedBody = await readJson(request);
    if (!parsedBody.ok) return parsedBody.response;
    const body = parsedBody.body;

    const markReadSchema = z.object({
      notificationIds: z.array(LowercaseUuid).optional(),
    });

    const validationResult = markReadSchema.safeParse(body);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          details: z.flattenError(validationResult.error),
        },
        400
      );
    }

    const { notificationIds } = validationResult.data;

    const markedCount = await markNotificationsRead(env.DB, auth.userId, notificationIds);

    return jsonResponse({
      success: true,
      message: notificationIds
        ? `Marked ${markedCount} notification(s) as read`
        : `Marked all (${markedCount}) notifications as read`,
      markedCount,
    });
  } catch (error) {
    console.error('Mark notifications read error:', error);
    return internalError('Unhandled error', error);
  }
}
