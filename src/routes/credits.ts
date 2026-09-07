import { checkDeviceCredits } from '../credits/store';
import { Env, isValidDeviceId } from '../env';
import { internalError, jsonResponse } from '../http';

// =============================================================================
// CREDITS HANDLERS
// =============================================================================

/**
 * Handle get credit balance
 * GET /credits/balance?deviceId=xxx
 */
export async function handleGetCreditsBalance(request: Request, env: Env): Promise<Response> {
  try {
    const url = new URL(request.url);
    const deviceId = url.searchParams.get('deviceId');

    if (!isValidDeviceId(deviceId)) {
      return jsonResponse(
        {
          error: 'Validation failed',
          message: 'deviceId query parameter is required and must be a valid device identifier',
        },
        400
      );
    }

    const credits = await checkDeviceCredits(env, deviceId);
    const freeLimit = parseInt(env.FREE_ANALYSIS_LIMIT || '3', 10);

    return jsonResponse({
      success: true,
      deviceId,
      freeLimit,
      freeUsed: freeLimit - credits.freeRemaining,
      freeRemaining: credits.freeRemaining,
      paidCredits: credits.paidCredits,
      totalCredits: credits.freeRemaining + credits.paidCredits,
      totalAnalyses: credits.totalAnalyses,
    });
  } catch (error) {
    console.error('Get credits balance error:', error);
    return internalError('Unhandled error', error);
  }
}
