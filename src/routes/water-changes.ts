import { z } from 'zod';
import { AuthenticatedContext, Env } from '../env';
import { errorResponse, generateUUID, internalError, jsonResponse, readJson } from '../http';
import { verifyTankOwnership } from './history';
import { getMaintenanceScheduleForUser } from './maintenance';
import { WaterChangeCreateSchema, WaterChangeListQuerySchema } from '../schemas';

// =============================================================================
// WATER CHANGE HANDLERS
// =============================================================================

export interface WaterChangeRecord {
  id: string;
  user_id: string;
  tank_id: string;
  performed_at: string;
  percent_replaced: number | null;
  gallons_replaced: number | null;
  notes: string | null;
  source_schedule_id: string | null;
  created_at: string;
  updated_at: string;
}

export function waterChangeRecordToApi(record: WaterChangeRecord) {
  return {
    id: record.id,
    tankId: record.tank_id,
    performedAt: record.performed_at,
    percentReplaced: record.percent_replaced,
    gallonsReplaced: record.gallons_replaced,
    notes: record.notes,
    sourceScheduleId: record.source_schedule_id,
    createdAt: record.created_at,
    updatedAt: record.updated_at,
    needsSync: false,
    isDeleted: false,
  };
}

/**
 * POST /api/tanks/:tankId/water-changes
 */
export async function handleCreateWaterChange(
  request: Request,
  env: Env,
  auth: AuthenticatedContext,
  tankId: string
): Promise<Response> {
  try {
    const parsedBody = await readJson(request);
    if (!parsedBody.ok) return parsedBody.response;
    const body = parsedBody.body;
    const validationResult = WaterChangeCreateSchema.safeParse(body);
    if (!validationResult.success) {
      return jsonResponse(
        { error: 'Validation failed', details: z.flattenError(validationResult.error) },
        400
      );
    }

    const tankResult = await verifyTankOwnership(env, tankId, auth.userId);
    if (tankResult instanceof Response) return tankResult;

    const data = validationResult.data;
    if (data.sourceScheduleId) {
      const schedule = await getMaintenanceScheduleForUser(env, auth.userId, data.sourceScheduleId);
      if (!schedule || schedule.tank_id !== tankResult.id || schedule.type !== 'water_change') {
        return errorResponse('Validation failed', 'sourceScheduleId is not a water change schedule for this tank', 400);
      }
    }

    const id = generateUUID();
    const now = new Date().toISOString();
    const performedAt = data.performedAt ?? now;

    await env.DB.prepare(
      `INSERT INTO water_changes
       (id, user_id, tank_id, performed_at, percent_replaced, gallons_replaced, notes, source_schedule_id, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    )
      .bind(
        id,
        auth.userId,
        tankResult.id,
        performedAt,
        data.percentReplaced ?? null,
        data.gallonsReplaced ?? null,
        data.notes ?? null,
        data.sourceScheduleId?.toLowerCase() ?? null,
        now,
        now
      )
      .run();

    const created = (await env.DB.prepare(
      'SELECT * FROM water_changes WHERE id = ? AND user_id = ? AND deleted_at IS NULL'
    )
      .bind(id, auth.userId)
      .first()) as WaterChangeRecord | null;

    if (!created) {
      return errorResponse('Internal server error', 'Failed to create water change', 500);
    }

    return jsonResponse({ success: true, data: waterChangeRecordToApi(created) }, 201);
  } catch (error) {
    console.error('Create water change error:', error);
    return internalError('Unhandled error', error);
  }
}

/**
 * GET /api/tanks/:tankId/water-changes?limit=50
 */
export async function handleListWaterChanges(
  request: Request,
  env: Env,
  auth: AuthenticatedContext,
  tankId: string
): Promise<Response> {
  try {
    const tankResult = await verifyTankOwnership(env, tankId, auth.userId);
    if (tankResult instanceof Response) return tankResult;

    const url = new URL(request.url);
    const validationResult = WaterChangeListQuerySchema.safeParse({
      limit: url.searchParams.get('limit') ?? undefined,
    });
    if (!validationResult.success) {
      return jsonResponse(
        { error: 'Validation failed', details: z.flattenError(validationResult.error) },
        400
      );
    }

    const result = await env.DB.prepare(
      `SELECT * FROM water_changes
       WHERE user_id = ? AND tank_id = ? AND deleted_at IS NULL
       ORDER BY performed_at DESC
       LIMIT ?`
    )
      .bind(auth.userId, tankResult.id, validationResult.data.limit)
      .all();

    const waterChanges = ((result.results ?? []) as unknown as WaterChangeRecord[]).map(waterChangeRecordToApi);
    return jsonResponse({ success: true, data: waterChanges });
  } catch (error) {
    console.error('List water changes error:', error);
    return internalError('Unhandled error', error);
  }
}

/**
 * DELETE /api/water-changes/:id
 */
export async function handleDeleteWaterChange(
  env: Env,
  auth: AuthenticatedContext,
  waterChangeId: string
): Promise<Response> {
  try {
    const existing = (await env.DB.prepare(
      'SELECT * FROM water_changes WHERE id = ? AND user_id = ? AND deleted_at IS NULL'
    )
      .bind(waterChangeId.toLowerCase(), auth.userId)
      .first()) as WaterChangeRecord | null;

    if (!existing) {
      return errorResponse('Not found', 'Water change not found', 404);
    }

    const now = new Date().toISOString();
    await env.DB.prepare(
      'UPDATE water_changes SET deleted_at = ?, updated_at = ? WHERE id = ? AND user_id = ?'
    )
      .bind(now, now, waterChangeId.toLowerCase(), auth.userId)
      .run();

    return jsonResponse({ success: true });
  } catch (error) {
    console.error('Delete water change error:', error);
    return internalError('Unhandled error', error);
  }
}
