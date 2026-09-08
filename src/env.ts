// =============================================================================
// APP IDENTITY
// =============================================================================

/** Fallback when APPLE_BUNDLE_ID is not set in wrangler.toml (P3-09). */
export const DEFAULT_BUNDLE_ID = 'au.com.aethers.reefbuddy';

/**
 * Device identifiers are client-supplied (identifierForVendor UUIDs from iOS, plus a few legacy
 * test ids). Bound them to a safe charset and length so arbitrary strings cannot create rows (B-07).
 */
export const DEVICE_ID_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._:-]{7,127}$/;
export function isValidDeviceId(value: string | null | undefined): value is string {
  return typeof value === 'string' && DEVICE_ID_PATTERN.test(value);
}

// =============================================================================
// TYPE DEFINITIONS
// =============================================================================

/**
 * Environment bindings for the Worker
 */
/**
 * Worker bindings. The binding names and types come from `worker-configuration.d.ts`, which is
 * generated from wrangler.toml by `npm run types` (rerun after changing wrangler.toml or .dev.vars).
 * Only the fields whose generated type is wrongly required (optional secrets/vars) are re-declared here.
 */
export interface Env extends Omit<
  Cloudflare.Env,
  'ALLOW_SANDBOX_PURCHASES' | 'CF_AI_GATEWAY_TOKEN' | 'APPLE_KEY_ID' | 'APPLE_PRIVATE_KEY' | 'APPLE_TEAM_ID'
> {
  /** Set to 'true' to accept Sandbox/Xcode StoreKit transactions in production (TestFlight). Default: Production only. */
  ALLOW_SANDBOX_PURCHASES?: string;
  /** Optional: AI Gateway authentication token */
  CF_AI_GATEWAY_TOKEN?: string;
  /** Apple DeviceCheck secrets (optional; DeviceCheck is skipped when unset outside production) */
  APPLE_KEY_ID?: string;
  APPLE_PRIVATE_KEY?: string;
  APPLE_TEAM_ID?: string;
}

/**
 * Session data stored in KV
 */
export interface SessionData {
  user_id: string;
  created_at: string;
}

/**
 * Authenticated request with user context
 */
export interface AuthenticatedContext {
  userId: string;
  sessionToken: string | null; // null for device-based users (no session)
}

// =============================================================================
// CONSTANTS
// =============================================================================

export const SESSION_EXPIRY_SECONDS = 7 * 24 * 60 * 60; // 1 week in seconds
export const BCRYPT_SALT_ROUNDS = 10;

/** Reported by `/` and `/health`; keep in step with the iOS marketing version and package.json. */
export const API_VERSION = '1.0.8';
