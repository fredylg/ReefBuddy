import { z } from 'zod';
import { AuthenticatedContext, Env } from '../env';
import { errorResponse, generateUUID, internalError, jsonResponse, readJson } from '../http';
import { verifyTankOwnership } from './history';
import { LivestockCreateSchema, LivestockLogSchema, LivestockUpdateSchema } from '../schemas';

// =============================================================================
// LIVESTOCK HANDLERS
// =============================================================================

/**
 * Livestock record from database
 */
export interface LivestockRecord {
  id: string;
  tank_id: string;
  common_name: string; // Database uses common_name, not name
  species: string | null;
  category: string | null;
  quantity: number;
  purchase_date: string | null;
  purchase_price: number | null;
  health_status: string | null;
  notes: string | null;
  image_url: string | null;
  added_at: string;
  deleted_at: string | null;
}

/**
 * Livestock log record from database
 */
export interface LivestockLogRecord {
  id: string;
  livestock_id: string;
  log_type: string;
  description: string | null;
  logged_at: string;
  created_at: string;
}

/**
 * Verify livestock ownership helper
 * Returns livestock if found, belongs to user's tank, and not deleted, or error response
 */
export async function verifyLivestockOwnership(
  env: Env,
  livestockId: string,
  userId: string
): Promise<LivestockRecord | Response> {
  // Normalize livestockId to lowercase for case-insensitive matching (iOS sends uppercase UUIDs)
  const normalizedLivestockId = livestockId.toLowerCase();
  const livestock = (await env.DB.prepare(
    `SELECT l.* FROM livestock l
     JOIN tanks t ON l.tank_id = t.id
     WHERE l.id = ? AND t.user_id = ? AND l.deleted_at IS NULL AND t.deleted_at IS NULL`
  )
    .bind(normalizedLivestockId, userId)
    .first()) as LivestockRecord | null;

  if (!livestock) {
    // Check if livestock exists at all (without user check) to provide better error message
    const anyLivestock = (await env.DB.prepare(
      `SELECT l.id, l.tank_id, t.user_id FROM livestock l
       JOIN tanks t ON l.tank_id = t.id
       WHERE l.id = ? AND l.deleted_at IS NULL`
    )
      .bind(normalizedLivestockId)
      .first()) as { id: string; tank_id: string; user_id: string } | null;

    if (anyLivestock) {
      return errorResponse('Forbidden', 'You do not have access to this livestock', 403);
    } else {
      return errorResponse('Not found', 'Livestock not found', 404);
    }
  }

  return livestock;
}

/**
 * Handle creating new livestock
 * POST /tanks/:tankId/livestock (authenticated)
 */
export async function handleCreateLivestock(
  request: Request,
  env: Env,
  auth: AuthenticatedContext,
  tankId: string
): Promise<Response> {
  try {
    // Verify tank ownership
    const tankResult = await verifyTankOwnership(env, tankId, auth.userId);
    if (tankResult instanceof Response) {
      return tankResult;
    }

    const parsedBody = await readJson(request);

    if (!parsedBody.ok) return parsedBody.response;

    const body = parsedBody.body;
    const validationResult = LivestockCreateSchema.safeParse(body);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          details: z.flattenError(validationResult.error),
        },
        400
      );
    }

    const data = validationResult.data; // Create livestock
    // Use provided ID if available (for retroactive compatibility), otherwise generate new one
    const livestockId = data.id ? data.id.toLowerCase() : generateUUID().toLowerCase(); // Normalize to lowercase for consistency
    const normalizedTankId = tankId.toLowerCase(); // Normalize to match database format

    // Check if livestock with this ID already exists
    const existing = (await env.DB.prepare('SELECT id FROM livestock WHERE id = ? AND deleted_at IS NULL')
      .bind(livestockId)
      .first()) as { id: string } | null;

    if (existing) {
      // Return existing livestock instead of creating duplicate
      const existingLivestock = (await env.DB.prepare(
        `SELECT l.* FROM livestock l
         JOIN tanks t ON l.tank_id = t.id
         WHERE l.id = ? AND t.user_id = ? AND l.deleted_at IS NULL`
      )
        .bind(livestockId, auth.userId)
        .first()) as LivestockRecord | null;

      if (existingLivestock) {
        return jsonResponse({
          success: true,
          livestock: {
            id: existingLivestock.id,
            tank_id: existingLivestock.tank_id,
            name: existingLivestock.common_name,
            species: existingLivestock.species,
            category: existingLivestock.category,
            quantity: existingLivestock.quantity,
            purchase_date: existingLivestock.purchase_date,
            purchase_price: existingLivestock.purchase_price,
            health_status: existingLivestock.health_status,
            notes: existingLivestock.notes,
            image_url: existingLivestock.image_url,
            added_at: existingLivestock.added_at,
          },
        });
      } else {
        return errorResponse('Conflict', 'Livestock with this ID already exists but belongs to another user', 409);
      }
    }
    const now = new Date().toISOString();
    await env.DB.prepare(
      `INSERT INTO livestock (id, tank_id, common_name, species, category, quantity, purchase_date, purchase_price, health_status, notes, image_url, added_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    )
      .bind(
        livestockId,
        normalizedTankId,
        data.name,
        data.species ?? data.name, // Use name as fallback if species not provided (database requires NOT NULL)
        data.category,
        data.quantity,
        data.purchaseDate ?? null,
        data.purchasePrice ?? null,
        data.healthStatus ?? 'healthy',
        data.notes ?? null,
        data.imageUrl ?? null,
        now
      )
      .run();
    return jsonResponse(
      {
        success: true,
        livestock: {
          id: livestockId,
          tank_id: normalizedTankId,
          name: data.name, // API response uses 'name', maps from common_name
          species: data.species ?? null,
          category: data.category,
          quantity: data.quantity,
          purchase_date: data.purchaseDate ?? null,
          purchase_price: data.purchasePrice ?? null,
          health_status: data.healthStatus ?? 'healthy',
          notes: data.notes ?? null,
          image_url: data.imageUrl ?? null,
          added_at: now,
        },
      },
      201
    );
  } catch (error) {
    console.error('Create livestock error:', error);
    return internalError('Unhandled error', error);
  }
}

/**
 * Handle listing tank livestock
 * GET /tanks/:tankId/livestock (authenticated)
 */
export async function handleListLivestock(env: Env, auth: AuthenticatedContext, tankId: string): Promise<Response> {
  try {
    // Verify tank ownership
    const tankResult = await verifyTankOwnership(env, tankId, auth.userId);
    if (tankResult instanceof Response) {
      return tankResult;
    }

    // Get all non-deleted livestock for this tank
    // Normalize tankId to lowercase for case-insensitive matching (iOS sends uppercase UUIDs)
    const normalizedTankId = tankId.toLowerCase();
    const result = await env.DB.prepare(
      `SELECT * FROM livestock WHERE tank_id = ? AND deleted_at IS NULL ORDER BY added_at DESC`
    )
      .bind(normalizedTankId)
      .all<LivestockRecord>();

    const livestock = result.results;

    return jsonResponse({
      success: true,
      tank_id: tankId,
      tank_name: tankResult.name,
      count: livestock.length,
      livestock: livestock.map((item) => ({
        id: item.id,
        tank_id: item.tank_id,
        name: item.common_name, // Map common_name to name in API response
        species: item.species,
        category: item.category,
        quantity: item.quantity,
        purchase_date: item.purchase_date,
        purchase_price: item.purchase_price,
        health_status: item.health_status,
        notes: item.notes,
        image_url: item.image_url,
        added_at: item.added_at,
      })),
    });
  } catch (error) {
    console.error('List livestock error:', error);
    return internalError('Unhandled error', error);
  }
}

/**
 * Handle updating livestock details
 * PUT /livestock/:id (authenticated)
 */
export async function handleUpdateLivestock(
  request: Request,
  env: Env,
  auth: AuthenticatedContext,
  livestockId: string
): Promise<Response> {
  try {
    // Verify livestock ownership
    const livestockResult = await verifyLivestockOwnership(env, livestockId, auth.userId);
    if (livestockResult instanceof Response) {
      return livestockResult;
    }

    const parsedBody = await readJson(request);

    if (!parsedBody.ok) return parsedBody.response;

    const body = parsedBody.body;

    const validationResult = LivestockUpdateSchema.safeParse(body);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          details: z.flattenError(validationResult.error),
        },
        400
      );
    }

    const data = validationResult.data;

    // Build dynamic update query
    const updates: string[] = [];
    const values: (string | number | null)[] = [];

    if (data.name !== undefined) {
      updates.push('common_name = ?');
      values.push(data.name);
    }
    if (data.species !== undefined) {
      updates.push('species = ?');
      values.push(data.species);
    }
    if (data.category !== undefined) {
      updates.push('category = ?');
      values.push(data.category);
    }
    if (data.quantity !== undefined) {
      updates.push('quantity = ?');
      values.push(data.quantity);
    }
    if (data.purchaseDate !== undefined) {
      updates.push('purchase_date = ?');
      values.push(data.purchaseDate);
    }
    if (data.purchasePrice !== undefined) {
      updates.push('purchase_price = ?');
      values.push(data.purchasePrice);
    }
    if (data.healthStatus !== undefined) {
      updates.push('health_status = ?');
      values.push(data.healthStatus);
    }
    if (data.notes !== undefined) {
      updates.push('notes = ?');
      values.push(data.notes);
    }
    if (data.imageUrl !== undefined) {
      updates.push('image_url = ?');
      values.push(data.imageUrl);
    }

    if (updates.length === 0) {
      return jsonResponse(
        {
          error: 'Bad request',
          message: 'No fields to update',
        },
        400
      );
    }

    // Normalize livestockId to lowercase for case-insensitive matching (iOS sends uppercase UUIDs)
    const normalizedLivestockId = livestockId.toLowerCase();
    values.push(normalizedLivestockId);

    await env.DB.prepare(`UPDATE livestock SET ${updates.join(', ')} WHERE id = ?`)
      .bind(...values)
      .run();

    // Fetch updated record
    const updated = (await env.DB.prepare('SELECT * FROM livestock WHERE id = ?')
      .bind(normalizedLivestockId)
      .first()) as LivestockRecord | null;

    if (!updated) {
      return errorResponse('Not found', 'Livestock not found after update', 404);
    }

    return jsonResponse({
      success: true,
      livestock: {
        id: updated.id,
        tank_id: updated.tank_id,
        name: updated.common_name, // Map common_name to name in API response
        species: updated.species,
        category: updated.category,
        quantity: updated.quantity,
        purchase_date: updated.purchase_date,
        purchase_price: updated.purchase_price,
        health_status: updated.health_status,
        notes: updated.notes,
        image_url: updated.image_url,
        added_at: updated.added_at,
      },
    });
  } catch (error) {
    console.error('Update livestock error:', error);
    return internalError('Unhandled error', error);
  }
}

/**
 * Handle soft-deleting livestock
 * DELETE /livestock/:id (authenticated)
 */
export async function handleDeleteLivestock(
  env: Env,
  auth: AuthenticatedContext,
  livestockId: string
): Promise<Response> {
  try {
    // Verify livestock ownership
    const livestockResult = await verifyLivestockOwnership(env, livestockId, auth.userId);
    if (livestockResult instanceof Response) {
      return livestockResult;
    }

    // Soft delete the livestock (normalize livestockId for case-insensitive matching)
    const normalizedLivestockId = livestockId.toLowerCase();
    const now = new Date().toISOString();
    await env.DB.prepare('UPDATE livestock SET deleted_at = ? WHERE id = ?').bind(now, normalizedLivestockId).run();

    return jsonResponse({
      success: true,
      message: 'Livestock deleted successfully',
      livestock_id: livestockId,
      deleted_at: now,
    });
  } catch (error) {
    console.error('Delete livestock error:', error);
    return internalError('Unhandled error', error);
  }
}

/**
 * Handle creating a livestock log entry
 * POST /livestock/:id/logs (authenticated)
 */
export async function handleCreateLivestockLog(
  request: Request,
  env: Env,
  auth: AuthenticatedContext,
  livestockId: string
): Promise<Response> {
  try {
    // Verify livestock ownership
    const livestockResult = await verifyLivestockOwnership(env, livestockId, auth.userId);
    if (livestockResult instanceof Response) {
      return livestockResult;
    }

    const parsedBody = await readJson(request);

    if (!parsedBody.ok) return parsedBody.response;

    const body = parsedBody.body;

    const validationResult = LivestockLogSchema.safeParse(body);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          details: z.flattenError(validationResult.error),
        },
        400
      );
    }

    const data = validationResult.data;

    // Normalize livestockId to lowercase for case-insensitive matching (iOS sends uppercase UUIDs)
    const normalizedLivestockId = livestockId.toLowerCase();

    // Create log entry
    const logId = generateUUID();
    const loggedAt = data.loggedAt || new Date().toISOString();
    const now = new Date().toISOString();

    await env.DB.prepare(
      `INSERT INTO livestock_logs (id, livestock_id, log_type, description, logged_at, created_at)
       VALUES (?, ?, ?, ?, ?, ?)`
    )
      .bind(logId, normalizedLivestockId, data.logType, data.description ?? null, loggedAt, now)
      .run();

    // If log type is 'death', update livestock health_status to 'deceased'
    if (data.logType === 'death') {
      await env.DB.prepare('UPDATE livestock SET health_status = ? WHERE id = ?')
        .bind('deceased', normalizedLivestockId)
        .run();
    }

    return jsonResponse(
      {
        success: true,
        log: {
          id: logId,
          livestock_id: livestockId,
          log_type: data.logType,
          description: data.description ?? null,
          logged_at: loggedAt,
          created_at: now,
        },
      },
      201
    );
  } catch (error) {
    console.error('Create livestock log error:', error);
    return internalError('Unhandled error', error);
  }
}

/**
 * Handle getting livestock logs
 * GET /livestock/:id/logs (authenticated)
 */
export async function handleGetLivestockLogs(
  env: Env,
  auth: AuthenticatedContext,
  livestockId: string
): Promise<Response> {
  try {
    // Verify livestock ownership
    const livestockResult = await verifyLivestockOwnership(env, livestockId, auth.userId);
    if (livestockResult instanceof Response) {
      return livestockResult;
    }

    // Get all logs for this livestock (normalize livestockId for case-insensitive matching)
    const normalizedLivestockId = livestockId.toLowerCase();
    const result = await env.DB.prepare(`SELECT * FROM livestock_logs WHERE livestock_id = ? ORDER BY logged_at DESC`)
      .bind(normalizedLivestockId)
      .all<LivestockLogRecord>();

    const logs = result.results;

    return jsonResponse({
      success: true,
      livestock_id: livestockId,
      livestock_name: livestockResult.common_name,
      count: logs.length,
      logs: logs.map((log) => ({
        id: log.id,
        livestock_id: log.livestock_id,
        log_type: log.log_type,
        description: log.description,
        logged_at: log.logged_at,
        created_at: log.created_at,
      })),
    });
  } catch (error) {
    console.error('Get livestock logs error:', error);
    return internalError('Unhandled error', error);
  }
}
