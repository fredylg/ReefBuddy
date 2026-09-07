import { z } from 'zod';
import { processAlertsForMeasurement } from '../notifications';
import { AuthenticatedContext, Env } from '../env';
import { errorResponse, generateUUID, internalError, jsonResponse } from '../http';
import { CreateMeasurementSchema } from '../schemas';

// =============================================================================
// MEASUREMENT HANDLERS
// =============================================================================

/**
 * Handle creating a new measurement
 * POST /measurements (authenticated)
 */
export async function handleCreateMeasurement(
  request: Request,
  env: Env,
  auth: AuthenticatedContext
): Promise<Response> {
  try {    let body;
    try {
      body = await request.json();
    } catch (jsonError) {
      throw jsonError;
    }

    const validationResult = CreateMeasurementSchema.safeParse(body);
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
    
    // Normalize tank_id to lowercase for case-insensitive lookup (iOS sends uppercase UUIDs)
    const normalizedTankId = data.tank_id.toLowerCase();    // Verify the tank belongs to the authenticated user (case-insensitive lookup)
    const tank = (await env.DB.prepare('SELECT id, user_id, name FROM tanks WHERE id = ? AND deleted_at IS NULL')
      .bind(normalizedTankId)
      .first()) as { id: string; user_id: string; name: string } | null;    if (!tank) {      return errorResponse('Not found', 'Tank not found', 404);
    }

    if (tank.user_id !== auth.userId) {      return errorResponse('Forbidden', 'You do not have access to this tank', 403);
    }

    // Create measurement
    // Use the actual tank.id from database (lowercase) to satisfy foreign key constraint
    // Backward compatibility: if salinity is sent without salinity_unit, treat as SG (all legacy apps used SG only)
    const salinityUnit = data.salinity_unit ?? (data.salinity != null ? 'SG' : null);

    const measurementId = generateUUID();
    const measuredAt = data.measured_at || new Date().toISOString();
    await env.DB.prepare(
      `INSERT INTO measurements (id, tank_id, measured_at, ph, alkalinity, calcium, magnesium, nitrate, phosphate, salinity, salinity_unit, temperature, ammonia, nitrite, notes)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    )
      .bind(
        measurementId,
        tank.id,
        measuredAt,
        data.ph ?? null,
        data.alkalinity ?? null,
        data.calcium ?? null,
        data.magnesium ?? null,
        data.nitrate ?? null,
        data.phosphate ?? null,
        data.salinity ?? null,
        salinityUnit,
        data.temperature ?? null,
        data.ammonia ?? null,
        data.nitrite ?? null,
        data.notes ?? null
      )
      .run();
    // Check for parameter alerts and send notifications
    let alerts: Array<{
      parameter: string;
      value: number;
      thresholdType: 'min' | 'max';
      thresholdValue: number;
      message: string;
    }> = [];

    try {
      alerts = await processAlertsForMeasurement(
        env.DB,
        auth.userId,
        {
          id: measurementId,
          tank_id: tank.id, // Use the actual tank.id from database (lowercase)
          ph: data.ph,
          alkalinity: data.alkalinity,
          calcium: data.calcium,
          magnesium: data.magnesium,
          ammonia: data.ammonia,
          nitrate: data.nitrate,
          phosphate: data.phosphate,
          salinity: data.salinity,
          salinity_unit: salinityUnit,
          temperature: data.temperature,
          nitrite: data.nitrite,
        },
        tank.name
      );
    } catch (alertError) {
      // Log error but don't fail the measurement creation
      console.error('Error processing alerts:', alertError);
    }

    return jsonResponse(
      {
        success: true,
        data: {
          id: measurementId,
          tank_id: tank.id, // Return the actual tank.id from database (lowercase) for consistency
          measured_at: measuredAt,
          ph: data.ph ?? null,
          alkalinity: data.alkalinity ?? null,
          calcium: data.calcium ?? null,
          magnesium: data.magnesium ?? null,
          nitrate: data.nitrate ?? null,
          phosphate: data.phosphate ?? null,
          salinity: data.salinity ?? null,
          salinity_unit: salinityUnit ?? null,
          temperature: data.temperature ?? null,
          ammonia: data.ammonia ?? null,
          nitrite: data.nitrite ?? null,
          notes: data.notes ?? null,
        },
        alerts: alerts.length > 0 ? alerts : undefined,
      },
      201
    );
  } catch (error) {    console.error('Create measurement error:', error);
    return internalError('Unhandled error', error);
  }
}
