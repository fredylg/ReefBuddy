import { Env } from './env';

// =============================================================================
// CORS AND SECURITY CONFIGURATION
// =============================================================================

export const ALLOWED_ORIGINS = [
  'capacitor://localhost', // iOS app
  'ionic://localhost', // iOS app alternative
  'http://localhost:8100', // Local development
  'http://localhost:3000', // Web development
  'http://localhost:8787', // Wrangler dev
];

// CORS and security headers for all responses
// Access-Control-Allow-Origin is decided per request in the router (allow-listed origins only).
export const CORS_HEADERS = {
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Device-ID',
};

export const SECURITY_HEADERS = {
  'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
  'X-XSS-Protection': '1; mode=block',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'Permissions-Policy': 'geolocation=(), microphone=(), camera=()',
};

// =============================================================================
// UTILITY FUNCTIONS
// =============================================================================

/**
 * Generate a cryptographically secure session token
 */
export function generateSessionToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

/**
 * Generate a UUID v4
 */
export function generateUUID(): string {
  return crypto.randomUUID();
}

/**
 * Create a JSON response with CORS headers
 */
export function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...CORS_HEADERS,
      ...SECURITY_HEADERS,
    },
  });
}

/**
 * Create an error response
 */
export function errorResponse(error: string, message: string, status: number): Response {
  return new Response(JSON.stringify({ error, message }), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...CORS_HEADERS,
      ...SECURITY_HEADERS,
    },
  });
}

/**
 * Parse a JSON request body. Malformed JSON is a client error (400), never a 500.
 * Usage: const parsed = await readJson(request); if (!parsed.ok) return parsed.response;
 */
export async function readJson(
  request: Request
): Promise<{ ok: true; body: unknown } | { ok: false; response: Response }> {
  try {
    return { ok: true, body: await request.json() };
  } catch {
    return {
      ok: false,
      response: jsonResponse({ error: 'Invalid JSON', message: 'Request body is not valid JSON' }, 400),
    };
  }
}

/**
 * 500 response. The client gets a generic message; the real error goes to the logs (B-13).
 */
export function internalError(context: string, error: unknown): Response {
  console.error(context + ':', error instanceof Error ? error.stack || error.message : error);
  return errorResponse('Internal server error', 'Something went wrong. Please try again.', 500);
}

/** Verbose logging is off in production (B-11). Set per request from env.ENVIRONMENT. */
let debugLoggingEnabled = false;
/** Called once per request by the router. */
export function setDebugLogging(enabled: boolean): void {
  debugLoggingEnabled = enabled;
}
export function debugLog(...args: unknown[]): void {
  if (debugLoggingEnabled) console.log(...args);
}

// =============================================================================
// IP RATE LIMITING (KV-backed sliding window)
// =============================================================================

/**
 * IP rate limit result
 */
export interface RateLimitResult {
  allowed: boolean;
  remaining: number;
  resetAt: number;
}

/**
 * Check and update IP-based rate limit using KV
 * Provides defense-in-depth beyond the credit system
 * @param env - Worker environment
 * @param ip - Client IP address
 * @param maxRequests - Maximum requests per window (default: 10)
 * @param windowMs - Time window in milliseconds (default: 60000 = 1 minute)
 * @param scope - Key prefix so different limiters do not share counters
 * @param onError - What to do when KV is unavailable: 'allow' keeps the API up for cheap routes,
 *   'deny' fails closed for routes that spend money (the AI analysis, security plan item H3)
 */
export async function checkIPRateLimit(
  env: Env,
  ip: string,
  maxRequests: number = 10,
  windowMs: number = 60000,
  scope: string = 'ip',
  onError: 'allow' | 'deny' = 'allow'
): Promise<RateLimitResult> {
  const key = `ratelimit:${scope}:${ip}`;
  const now = Date.now();

  try {
    const data = (await env.REEF_KV.get(key, 'json')) as { count: number; windowStart: number } | null;

    if (!data || now - data.windowStart > windowMs) {
      // New window - reset counter
      await env.REEF_KV.put(
        key,
        JSON.stringify({ count: 1, windowStart: now }),
        { expirationTtl: Math.ceil(windowMs / 1000) * 2 } // TTL = 2x window for safety
      );
      return { allowed: true, remaining: maxRequests - 1, resetAt: now + windowMs };
    }

    if (data.count >= maxRequests) {
      // Rate limit exceeded
      return { allowed: false, remaining: 0, resetAt: data.windowStart + windowMs };
    }

    // Increment counter
    await env.REEF_KV.put(key, JSON.stringify({ count: data.count + 1, windowStart: data.windowStart }), {
      expirationTtl: Math.ceil(windowMs / 1000) * 2,
    });

    return { allowed: true, remaining: maxRequests - data.count - 1, resetAt: data.windowStart + windowMs };
  } catch (error) {
    console.warn(`Rate limit check failed (${scope}), ${onError === 'deny' ? 'blocking' : 'allowing'} request:`, error);
    if (onError === 'deny') {
      return { allowed: false, remaining: 0, resetAt: now + windowMs };
    }
    return { allowed: true, remaining: maxRequests, resetAt: now + windowMs };
  }
}
