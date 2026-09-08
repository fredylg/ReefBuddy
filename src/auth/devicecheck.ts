import { SignJWT, importPKCS8 } from 'jose';
import { Env } from '../env';
import { debugLog } from '../http';

// =============================================================================
// APPLE DEVICECHECK INTEGRATION
// =============================================================================

/**
 * DeviceCheck validation result
 */
export interface DeviceCheckResult {
  valid: boolean;
  error?: string;
  /** DeviceCheck bit0: set once this physical device has used its free analyses (B-04). */
  freeTierConsumed?: boolean;
}

/**
 * Check if DeviceCheck is configured
 */
export function isDeviceCheckConfigured(env: Env): boolean {
  return !!(env.APPLE_KEY_ID && env.APPLE_PRIVATE_KEY && env.APPLE_TEAM_ID);
}

/**
 * Generate a JWT for Apple DeviceCheck API authentication
 * @param env - Worker environment with Apple credentials
 */
export async function generateAppleJWT(env: Env): Promise<string> {
  if (!env.APPLE_KEY_ID || !env.APPLE_PRIVATE_KEY || !env.APPLE_TEAM_ID) {
    throw new Error('Apple DeviceCheck credentials not configured');
  }

  // Import the private key (PKCS8 PEM format)
  const privateKey = await importPKCS8(env.APPLE_PRIVATE_KEY, 'ES256');

  // Generate JWT with required claims
  const jwt = await new SignJWT({})
    .setProtectedHeader({ alg: 'ES256', kid: env.APPLE_KEY_ID })
    .setIssuedAt()
    .setIssuer(env.APPLE_TEAM_ID)
    .setExpirationTime('5m')
    .sign(privateKey);

  return jwt;
}

export type DeviceCheckEndpoint = 'query_two_bits' | 'update_two_bits';

export async function deviceCheckRequest(
  env: Env,
  isDevelopment: boolean,
  endpoint: DeviceCheckEndpoint,
  deviceToken: string,
  extra: Record<string, unknown> = {}
): Promise<{ status: number; text: string; json: Record<string, unknown> | null }> {
  const base = isDevelopment
    ? 'https://api.development.devicecheck.apple.com/v1/'
    : 'https://api.devicecheck.apple.com/v1/';
  const jwt = await generateAppleJWT(env);
  const response = await fetch(base + endpoint, {
    method: 'POST',
    headers: { Authorization: 'Bearer ' + jwt, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      device_token: deviceToken,
      timestamp: Date.now(),
      transaction_id: crypto.randomUUID(),
      ...extra,
    }),
  });
  const text = await response.text();
  let json: Record<string, unknown> | null = null;
  try {
    const parsed = JSON.parse(text);
    if (parsed && typeof parsed === 'object') json = parsed as Record<string, unknown>;
  } catch {
    /* Apple returns plain text for some outcomes, e.g. "Failed to find bit state" */
  }
  return { status: response.status, text, json };
}

export function deviceCheckFailure(
  status: number,
  text: string,
  json: Record<string, unknown> | null
): DeviceCheckResult {
  const reason = (json && typeof json.reason === 'string' ? json.reason : text) || 'DeviceCheck returned ' + status;
  if (status === 400) {
    console.error('DeviceCheck rejected token (400): ' + reason);
    return { valid: false, error: 'Invalid device token format: ' + reason };
  }
  if (status === 401) {
    console.error('DeviceCheck authentication failed (401): ' + reason);
    return { valid: false, error: 'DeviceCheck authentication failed: ' + reason };
  }
  console.error('DeviceCheck returned ' + status + ': ' + reason);
  return { valid: false, error: 'DeviceCheck returned ' + status + ': ' + reason };
}

/**
 * Validate a device token with Apple's DeviceCheck API and read the device's free-tier bit.
 *
 * 1. query_two_bits: 200 with {bit0, bit1} means a genuine device we have seen before; bit0 is the
 *    "free analyses consumed" marker that follows the physical device across reinstalls and
 *    rotated device ids (B-04).
 * 2. 200 without bit state means a genuine device we have never marked; update_two_bits(bit1=true)
 *    then both validates the token (Apple rejects invalid tokens with 400) and records first sight.
 * 3. 400/401 mean an invalid token or a bad server credential.
 */
export async function validateDeviceToken(
  env: Env,
  deviceToken: string,
  isDevelopment: boolean = false
): Promise<DeviceCheckResult> {
  if (!isDeviceCheckConfigured(env)) {
    console.warn('DeviceCheck not configured - skipping device validation');
    return { valid: true };
  }
  // DeviceCheck tokens are base64 and typically 1000+ characters
  if (!deviceToken || deviceToken.length < 500) {
    return { valid: false, error: 'Invalid device token format - token too short' };
  }
  try {
    atob(deviceToken.substring(0, 100));
  } catch {
    return { valid: false, error: 'Invalid device token format - not valid base64' };
  }

  try {
    const query = await deviceCheckRequest(env, isDevelopment, 'query_two_bits', deviceToken);
    if (query.status === 200 && query.json && typeof query.json.bit0 === 'boolean') {
      debugLog('DeviceCheck bits: bit0=' + query.json.bit0 + ' bit1=' + query.json.bit1);
      return { valid: true, freeTierConsumed: query.json.bit0 === true };
    }
    if (query.status === 200) {
      const update = await deviceCheckRequest(env, isDevelopment, 'update_two_bits', deviceToken, {
        bit0: false,
        bit1: true,
      });
      if (update.status === 200) {
        debugLog('DeviceCheck: first sight of device, bits initialised');
        return { valid: true, freeTierConsumed: false };
      }
      return deviceCheckFailure(update.status, update.text, update.json);
    }
    return deviceCheckFailure(query.status, query.text, query.json);
  } catch (error) {
    console.error('DeviceCheck validation error:', error);
    return { valid: false, error: error instanceof Error ? error.message : 'Unknown error' };
  }
}

/** Record on the physical device that its free analyses are used up (DeviceCheck bit0). Best effort. */
export async function markDeviceFreeTierConsumed(
  env: Env,
  deviceToken: string,
  isDevelopment: boolean
): Promise<boolean> {
  try {
    const update = await deviceCheckRequest(env, isDevelopment, 'update_two_bits', deviceToken, {
      bit0: true,
      bit1: true,
    });
    if (update.status !== 200) console.warn('DeviceCheck: could not set free-tier bit (' + update.status + ')');
    return update.status === 200;
  } catch (error) {
    console.warn('DeviceCheck: could not set free-tier bit:', error);
    return false;
  }
}
