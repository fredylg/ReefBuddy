import { z } from 'zod';
import { getOrCreateDeviceUser } from '../auth/session';
import { AuthenticatedContext, Env } from '../env';
import { errorResponse, generateUUID, internalError, jsonResponse, readJson } from '../http';
import { TankCreateSchema, TankUpdateSchema } from '../schemas';

// =============================================================================
// TANK HANDLERS
// =============================================================================

/**
 * Tank record from database
 */
export interface TankRecord {
  id: string;
  user_id: string;
  name: string;
  volume_gallons: number;
  tank_type: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

/**
 * Handle listing all tanks for the authenticated user or device
 * GET /api/tanks (authenticated or device-based)
 * Supports both authenticated requests (v1.0.1+) and device-based requests (v1.0.2+)
 */
export async function handleListTanks(
  env: Env,
  auth: AuthenticatedContext | null,
  deviceId: string | null
): Promise<Response> {
  try {
    // Determine user ID: use authenticated user if available, otherwise use device-based user
    let userId: string;
    if (auth) {
      // Authenticated request (backward compatible with v1.0.1+)
      userId = auth.userId;
    } else if (deviceId) {
      // Device-based request (v1.0.2+)
      userId = await getOrCreateDeviceUser(env, deviceId);
    } else {
      // Neither auth nor device ID provided
      return errorResponse(
        'Unauthorized',
        'Either authentication token or device ID is required',
        401
      );
    }

    const result = await env.DB.prepare(
      'SELECT * FROM tanks WHERE user_id = ? AND deleted_at IS NULL ORDER BY created_at DESC'
    )
      .bind(userId)
      .all<TankRecord>();

    const tanks = result.results;

    return jsonResponse({
      success: true,
      data: tanks.map((tank) => ({
        id: tank.id,
        user_id: tank.user_id,
        name: tank.name,
        volume_gallons: tank.volume_gallons,
        tank_type: tank.tank_type,
        created_at: tank.created_at,
        updated_at: tank.updated_at,
      })),
    });
  } catch (error) {
    console.error('List tanks error:', error);
    return internalError('Unhandled error', error);
  }
}

/**
 * Handle getting a single tank
 * GET /api/tanks/:id (authenticated)
 */
export async function handleGetTank(
  env: Env,
  auth: AuthenticatedContext,
  tankId: string
): Promise<Response> {
  try {
    // Normalize tankId to lowercase for case-insensitive matching (iOS sends uppercase UUIDs)
    const normalizedTankId = tankId.toLowerCase();
    const tank = (await env.DB.prepare(
      'SELECT * FROM tanks WHERE id = ? AND user_id = ? AND deleted_at IS NULL'
    )
      .bind(normalizedTankId, auth.userId)
      .first()) as TankRecord | null;

    if (!tank) {
      return errorResponse('Not found', 'Tank not found', 404);
    }

    return jsonResponse({
      success: true,
      data: {
        id: tank.id,
        user_id: tank.user_id,
        name: tank.name,
        volume_gallons: tank.volume_gallons,
        tank_type: tank.tank_type,
        created_at: tank.created_at,
        updated_at: tank.updated_at,
      },
    });
  } catch (error) {
    console.error('Get tank error:', error);
    return internalError('Unhandled error', error);
  }
}

/**
 * Handle creating a new tank
 * POST /api/tanks (authenticated or device-based)
 * Supports both authenticated requests (v1.0.1+) and device-based requests (v1.0.2+)
 */
export async function handleCreateTank(
  request: Request,
  env: Env,
  auth: AuthenticatedContext | null,
  deviceId: string | null
): Promise<Response> {
  try {
    const parsedBody = await readJson(request);
    if (!parsedBody.ok) return parsedBody.response;
    const body = parsedBody.body;

    const validationResult = TankCreateSchema.safeParse(body);
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

    // Determine user ID: use authenticated user if available, otherwise use device-based user
    let userId: string;
    if (auth) {
      // Authenticated request (backward compatible with v1.0.1+)
      userId = auth.userId;
    } else if (deviceId) {
      // Device-based request (v1.0.2+)
      userId = await getOrCreateDeviceUser(env, deviceId);
    } else {
      // Neither auth nor device ID provided
      return errorResponse(
        'Unauthorized',
        'Either authentication token or device ID is required',
        401
      );
    }

    const tankId = generateUUID();
    const now = new Date().toISOString();

    await env.DB.prepare(
      `INSERT INTO tanks (id, user_id, name, volume_gallons, tank_type, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`
    )
      .bind(tankId, userId, data.name, data.volume_gallons, data.tank_type ?? null, now, now)
      .run();

    return jsonResponse(
      {
        success: true,
        data: {
          id: tankId,
          user_id: userId,
          name: data.name,
          volume_gallons: data.volume_gallons,
          tank_type: data.tank_type ?? null,
          created_at: now,
          updated_at: now,
        },
      },
      201
    );
  } catch (error) {
    console.error('Create tank error:', error);
    return internalError('Unhandled error', error);
  }
}

/**
 * Handle updating a tank
 * PUT /api/tanks/:id (authenticated)
 */
export async function handleUpdateTank(
  request: Request,
  env: Env,
  auth: AuthenticatedContext,
  tankId: string
): Promise<Response> {
  try {
    // Normalize tankId to lowercase for case-insensitive matching (iOS sends uppercase UUIDs)
    const normalizedTankId = tankId.toLowerCase();
    // Verify tank exists and belongs to user
    const existingTank = (await env.DB.prepare(
      'SELECT * FROM tanks WHERE id = ? AND user_id = ? AND deleted_at IS NULL'
    )
      .bind(normalizedTankId, auth.userId)
      .first()) as TankRecord | null;

    if (!existingTank) {
      return errorResponse('Not found', 'Tank not found', 404);
    }

    const parsedBody = await readJson(request);

    if (!parsedBody.ok) return parsedBody.response;

    const body = parsedBody.body;

    const validationResult = TankUpdateSchema.safeParse(body);
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
    const updates: string[] = ['updated_at = ?'];
    const values: (string | number | null)[] = [new Date().toISOString()];

    if (data.name !== undefined) {
      updates.push('name = ?');
      values.push(data.name);
    }
    if (data.volume_gallons !== undefined) {
      updates.push('volume_gallons = ?');
      values.push(data.volume_gallons);
    }
    if (data.tank_type !== undefined) {
      updates.push('tank_type = ?');
      values.push(data.tank_type);
    }

    values.push(normalizedTankId);

    await env.DB.prepare(`UPDATE tanks SET ${updates.join(', ')} WHERE id = ?`)
      .bind(...values)
      .run();

    // Fetch updated record
    const updated = (await env.DB.prepare('SELECT * FROM tanks WHERE id = ?')
      .bind(normalizedTankId)
      .first()) as TankRecord;

    return jsonResponse({
      success: true,
      data: {
        id: updated.id,
        user_id: updated.user_id,
        name: updated.name,
        volume_gallons: updated.volume_gallons,
        tank_type: updated.tank_type,
        created_at: updated.created_at,
        updated_at: updated.updated_at,
      },
    });
  } catch (error) {
    console.error('Update tank error:', error);
    return internalError('Unhandled error', error);
  }
}

/**
 * Handle deleting a tank (soft delete)
 * DELETE /api/tanks/:id (authenticated)
 */
export async function handleDeleteTank(
  env: Env,
  auth: AuthenticatedContext,
  tankId: string
): Promise<Response> {
  try {
    // Normalize tankId to lowercase for case-insensitive matching (iOS sends uppercase UUIDs)
    const normalizedTankId = tankId.toLowerCase();
    // Verify tank exists and belongs to user
    const existingTank = (await env.DB.prepare(
      'SELECT * FROM tanks WHERE id = ? AND user_id = ? AND deleted_at IS NULL'
    )
      .bind(normalizedTankId, auth.userId)
      .first()) as TankRecord | null;

    if (!existingTank) {
      return errorResponse('Not found', 'Tank not found', 404);
    }

    // Soft delete the tank
    const now = new Date().toISOString();
    await env.DB.prepare('UPDATE tanks SET deleted_at = ? WHERE id = ?').bind(now, normalizedTankId).run();

    return jsonResponse({
      success: true,
      message: 'Tank deleted successfully',
    });
  } catch (error) {
    console.error('Delete tank error:', error);
    return internalError('Unhandled error', error);
  }
}
