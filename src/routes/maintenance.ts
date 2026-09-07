import { z } from 'zod';
import { AuthenticatedContext, Env } from '../env';
import { errorResponse, generateUUID, internalError, jsonResponse, readJson } from '../http';
import { verifyTankOwnership } from './history';
import {
  MaintenanceScheduleCreateSchema,
  MaintenanceScheduleKindEnum,
  MaintenanceScheduleTypeEnum,
  MaintenanceScheduleUpdateSchema,
} from '../schemas';

// =============================================================================
// MAINTENANCE SCHEDULES HANDLERS
// =============================================================================

export type MaintenanceScheduleType = z.infer<typeof MaintenanceScheduleTypeEnum>;
export type MaintenanceScheduleKind = z.infer<typeof MaintenanceScheduleKindEnum>;

export interface MaintenanceScheduleRecord {
  id: string;
  user_id: string;
  tank_id: string | null;
  type: MaintenanceScheduleType;
  enabled: number;
  schedule_kind: MaintenanceScheduleKind;
  interval_days: number | null;
  weekdays: string | null;
  time_local: string;
  timezone: string;
  notes: string | null;
  created_at: string;
  updated_at: string;
}

export function weekdaysStringToArray(weekdays: string | null): number[] | null {
  if (!weekdays) return null;
  const parts = weekdays
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean)
    .map((s) => Number(s))
    .filter((n) => Number.isInteger(n));
  if (parts.length === 0) return null;
  return parts;
}

export function weekdaysArrayToString(weekdays: number[] | undefined): string | null {
  if (!weekdays || weekdays.length === 0) return null;
  const normalized = Array.from(new Set(weekdays)).sort((a, b) => a - b);
  return normalized.join(',');
}

export function scheduleRecordToApi(record: MaintenanceScheduleRecord) {
  return {
    id: record.id,
    tankId: record.tank_id,
    type: record.type,
    enabled: record.enabled === 1,
    scheduleKind: record.schedule_kind,
    intervalDays: record.interval_days,
    weekdays: weekdaysStringToArray(record.weekdays),
    timeLocal: record.time_local,
    timezone: record.timezone,
    notes: record.notes,
    createdAt: record.created_at,
    updatedAt: record.updated_at,
  };
}

export async function getMaintenanceScheduleForUser(
  env: Env,
  userId: string,
  scheduleId: string
): Promise<MaintenanceScheduleRecord | null> {
  const normalizedId = scheduleId.toLowerCase();
  const row = (await env.DB.prepare(
    'SELECT * FROM maintenance_schedules WHERE id = ? AND user_id = ? AND deleted_at IS NULL'
  )
    .bind(normalizedId, userId)
    .first()) as MaintenanceScheduleRecord | null;
  return row;
}

/**
 * GET /maintenance/schedules?tankId=<uuid?>
 */
export async function handleListMaintenanceSchedules(
  request: Request,
  env: Env,
  auth: AuthenticatedContext
): Promise<Response> {
  try {
    const url = new URL(request.url);
    const tankId = url.searchParams.get('tankId');

    if (tankId) {
      const parsed = z.uuid().safeParse(tankId);
      if (!parsed.success) {
        return jsonResponse({ error: 'Validation failed', details: z.flattenError(parsed.error) }, 400);
      }

      const tankResult = await verifyTankOwnership(env, tankId, auth.userId);
      if (tankResult instanceof Response) return tankResult;

      const result = await env.DB.prepare(
        `SELECT * FROM maintenance_schedules
         WHERE deleted_at IS NULL AND user_id = ? AND tank_id = ?
         ORDER BY created_at DESC`
      )
        .bind(auth.userId, tankResult.id)
        .all<MaintenanceScheduleRecord>();

      const schedules = result.results.map(scheduleRecordToApi);
      return jsonResponse({ success: true, schedules });
    }

    const result = await env.DB.prepare(
      `SELECT * FROM maintenance_schedules
       WHERE deleted_at IS NULL AND user_id = ?
       ORDER BY created_at DESC`
    )
      .bind(auth.userId)
      .all<MaintenanceScheduleRecord>();

    const schedules = result.results.map(scheduleRecordToApi);
    return jsonResponse({ success: true, schedules });
  } catch (error) {
    console.error('List maintenance schedules error:', error);
    return internalError('Unhandled error', error);
  }
}

/**
 * POST /maintenance/schedules
 */
export async function handleCreateMaintenanceSchedule(
  request: Request,
  env: Env,
  auth: AuthenticatedContext
): Promise<Response> {
  try {
    const parsedBody = await readJson(request);
    if (!parsedBody.ok) return parsedBody.response;
    const body = parsedBody.body;
    const validationResult = MaintenanceScheduleCreateSchema.safeParse(body);
    if (!validationResult.success) {
      return jsonResponse({ error: 'Validation failed', details: z.flattenError(validationResult.error) }, 400);
    }

    const data = validationResult.data;
    const tankResult = await verifyTankOwnership(env, data.tankId, auth.userId);
    if (tankResult instanceof Response) return tankResult;

    const scheduleId = generateUUID();
    const now = new Date().toISOString();

    const weekdays = data.scheduleKind === 'weekly' ? weekdaysArrayToString(data.weekdays) : null;
    const intervalDays = data.scheduleKind === 'interval_days' ? data.intervalDays! : null;

    await env.DB.prepare(
      `INSERT INTO maintenance_schedules
       (id, user_id, tank_id, type, enabled, schedule_kind, interval_days, weekdays, time_local, timezone, notes, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    )
      .bind(
        scheduleId,
        auth.userId,
        tankResult.id,
        data.type,
        data.enabled ? 1 : 0,
        data.scheduleKind,
        intervalDays,
        weekdays,
        data.timeLocal,
        data.timezone,
        data.notes ?? null,
        now,
        now
      )
      .run();

    const created = await getMaintenanceScheduleForUser(env, auth.userId, scheduleId);
    if (!created) {
      return errorResponse('Internal server error', 'Failed to create schedule', 500);
    }

    return jsonResponse({ success: true, schedule: scheduleRecordToApi(created) }, 201);
  } catch (error) {
    console.error('Create maintenance schedule error:', error);
    return internalError('Unhandled error', error);
  }
}

/**
 * PUT /maintenance/schedules/:id
 */
export async function handleUpdateMaintenanceSchedule(
  request: Request,
  env: Env,
  auth: AuthenticatedContext,
  scheduleId: string
): Promise<Response> {
  try {
    const existing = await getMaintenanceScheduleForUser(env, auth.userId, scheduleId);
    if (!existing) {
      return errorResponse('Not found', 'Schedule not found', 404);
    }

    const parsedBody = await readJson(request);

    if (!parsedBody.ok) return parsedBody.response;

    const body = parsedBody.body;
    const validationResult = MaintenanceScheduleUpdateSchema.safeParse(body);
    if (!validationResult.success) {
      return jsonResponse({ error: 'Validation failed', details: z.flattenError(validationResult.error) }, 400);
    }
    const data = validationResult.data;

    // Determine the effective scheduleKind for conditional validation
    const nextKind: MaintenanceScheduleKind = (data.scheduleKind ?? existing.schedule_kind) as MaintenanceScheduleKind;
    const nextIntervalDays = data.intervalDays ?? existing.interval_days ?? null;
    const nextWeekdaysArray = data.weekdays ?? weekdaysStringToArray(existing.weekdays) ?? null;

    if (nextKind === 'interval_days') {
      if (nextIntervalDays == null) {
        return jsonResponse(
          {
            error: 'Validation failed',
            details: {
              formErrors: [],
              fieldErrors: { intervalDays: ['intervalDays is required when scheduleKind=interval_days'] },
            },
          },
          400
        );
      }
    } else {
      if (!nextWeekdaysArray || nextWeekdaysArray.length === 0) {
        return jsonResponse(
          {
            error: 'Validation failed',
            details: { formErrors: [], fieldErrors: { weekdays: ['weekdays is required when scheduleKind=weekly'] } },
          },
          400
        );
      }
    }

    // If tankId is changing, verify ownership
    let tankIdToStore = existing.tank_id;
    if (data.tankId) {
      const tankResult = await verifyTankOwnership(env, data.tankId, auth.userId);
      if (tankResult instanceof Response) return tankResult;
      tankIdToStore = tankResult.id;
    }

    const updates: string[] = ['updated_at = ?'];
    const values: (string | number | null)[] = [new Date().toISOString()];

    if (data.type !== undefined) {
      updates.push('type = ?');
      values.push(data.type);
    }
    if (data.enabled !== undefined) {
      updates.push('enabled = ?');
      values.push(data.enabled ? 1 : 0);
    }
    if (data.timezone !== undefined) {
      updates.push('timezone = ?');
      values.push(data.timezone);
    }
    if (data.timeLocal !== undefined) {
      updates.push('time_local = ?');
      values.push(data.timeLocal);
    }
    if (data.notes !== undefined) {
      updates.push('notes = ?');
      values.push(data.notes ?? null);
    }
    if (data.scheduleKind !== undefined) {
      updates.push('schedule_kind = ?');
      values.push(data.scheduleKind);
    }

    // Persist tank change if requested
    if (data.tankId !== undefined) {
      updates.push('tank_id = ?');
      values.push(tankIdToStore);
    }

    // Recurrence fields: normalize to chosen kind
    if (data.scheduleKind !== undefined || data.intervalDays !== undefined || data.weekdays !== undefined) {
      if (nextKind === 'interval_days') {
        updates.push('interval_days = ?');
        values.push(nextIntervalDays);
        updates.push('weekdays = ?');
        values.push(null);
      } else {
        updates.push('interval_days = ?');
        values.push(null);
        updates.push('weekdays = ?');
        values.push(weekdaysArrayToString(nextWeekdaysArray ?? undefined));
      }
    }

    values.push(scheduleId.toLowerCase(), auth.userId);

    await env.DB.prepare(`UPDATE maintenance_schedules SET ${updates.join(', ')} WHERE id = ? AND user_id = ?`)
      .bind(...values)
      .run();

    const updated = await getMaintenanceScheduleForUser(env, auth.userId, scheduleId);
    if (!updated) {
      return errorResponse('Internal server error', 'Failed to load updated schedule', 500);
    }

    return jsonResponse({ success: true, schedule: scheduleRecordToApi(updated) });
  } catch (error) {
    console.error('Update maintenance schedule error:', error);
    return internalError('Unhandled error', error);
  }
}

/**
 * DELETE /maintenance/schedules/:id
 */
export async function handleDeleteMaintenanceSchedule(
  env: Env,
  auth: AuthenticatedContext,
  scheduleId: string
): Promise<Response> {
  try {
    const existing = await getMaintenanceScheduleForUser(env, auth.userId, scheduleId);
    if (!existing) {
      return errorResponse('Not found', 'Schedule not found', 404);
    }

    // Soft delete: water_changes.source_schedule_id references this row (FK), and the app syncs isDeleted.
    const now = new Date().toISOString();
    await env.DB.prepare(
      'UPDATE maintenance_schedules SET deleted_at = ?, updated_at = ? WHERE id = ? AND user_id = ? AND deleted_at IS NULL'
    )
      .bind(now, now, scheduleId.toLowerCase(), auth.userId)
      .run();

    return jsonResponse({ success: true });
  } catch (error) {
    console.error('Delete maintenance schedule error:', error);
    return internalError('Unhandled error', error);
  }
}
