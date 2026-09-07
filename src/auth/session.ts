import { AuthenticatedContext, Env, SESSION_EXPIRY_SECONDS, SessionData, isValidDeviceId } from '../env';
import { errorResponse, generateSessionToken, generateUUID } from '../http';

// =============================================================================
// SESSION MANAGEMENT
// =============================================================================

/**
 * Create a session in KV and return the token
 */
export async function createSession(env: Env, userId: string): Promise<string> {
  const token = generateSessionToken();
  const sessionData: SessionData = {
    user_id: userId,
    created_at: new Date().toISOString(),
  };

  await env.REEF_KV.put(`session:${token}`, JSON.stringify(sessionData), {
    expirationTtl: SESSION_EXPIRY_SECONDS,
  });

  return token;
}

/**
 * Validate a session token and return the session data
 */
export async function validateSession(env: Env, token: string): Promise<SessionData | null> {
  const data = await env.REEF_KV.get(`session:${token}`);
  if (!data) return null;

  try {
    return JSON.parse(data) as SessionData;
  } catch {
    return null;
  }
}

/**
 * Invalidate (delete) a session
 */
export async function invalidateSession(env: Env, token: string): Promise<void> {
  await env.REEF_KV.delete(`session:${token}`);
}

/**
 * Extract session token from Authorization header
 * Expected format: "Bearer <token>"
 */
export function extractSessionToken(request: Request): string | null {
  const authHeader = request.headers.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return null;
  }
  return authHeader.slice(7);
}

/**
 * Session middleware - validates authentication and returns user context
 */
export async function authenticateRequest(
  request: Request,
  env: Env
): Promise<AuthenticatedContext | Response> {
  const token = extractSessionToken(request);

  if (!token) {
    return errorResponse('Unauthorized', 'Missing or invalid Authorization header', 401);
  }

  const session = await validateSession(env, token);

  if (!session) {
    return errorResponse('Unauthorized', 'Invalid or expired session token', 401);
  }

  return {
    userId: session.user_id,
    sessionToken: token,
  };
}

/**
 * Try to authenticate request, but return null instead of error if auth fails
 * Used for endpoints that support both authenticated and device-based access
 */
export async function tryAuthenticateRequest(
  request: Request,
  env: Env
): Promise<AuthenticatedContext | null> {
  const token = extractSessionToken(request);
  if (!token) {
    return null;
  }

  const session = await validateSession(env, token);
  if (!session) {
    return null;
  }

  return {
    userId: session.user_id,
    sessionToken: token,
  };
}

/**
 * Get or create a device-based user for unauthenticated requests
 * Creates a user with email format: device_${deviceId}@reefbuddy.device
 * This allows device-based tank creation without requiring authentication
 */
export async function getOrCreateDeviceUser(
  env: Env,
  deviceId: string
): Promise<string> {
  const deviceEmail = `device_${deviceId}@reefbuddy.device`;

  // Try to find existing device user
  const existingUser = (await env.DB.prepare(
    'SELECT id FROM users WHERE email = ?'
  )
    .bind(deviceEmail)
    .first()) as { id: string } | null;

  if (existingUser) {
    return existingUser.id;
  }

  // Create new device user
  const userId = generateUUID();
  const now = new Date().toISOString();

  await env.DB.prepare(
    'INSERT INTO users (id, email, subscription_tier, created_at, updated_at) VALUES (?, ?, ?, ?, ?)'
  )
    .bind(userId, deviceEmail, 'free', now, now)
    .run();

  return userId;
}

/**
 * Session-or-device authentication for every app-facing route (P3-02).
 * A valid Bearer session wins; otherwise a well-formed X-Device-ID resolves to that device's user.
 */
export async function resolveActor(request: Request, env: Env): Promise<AuthenticatedContext | Response> {
  const session = await tryAuthenticateRequest(request, env);
  if (session) return session;

  const deviceId = request.headers.get('X-Device-ID');
  if (!isValidDeviceId(deviceId)) {
    return errorResponse('Unauthorized', 'Missing authentication token or device ID (send Authorization: Bearer <token> or X-Device-ID)', 401);
  }

  const deviceUserId = await getOrCreateDeviceUser(env, deviceId);
  return { userId: deviceUserId, sessionToken: null };
}
