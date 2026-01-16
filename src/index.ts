/**
 * ReefBuddy - Cloudflare Worker
 * Backend for saltwater aquarium water chemistry analysis and dosing recommendations
 *
 * @edge-engineer owns this file
 */

import { z } from 'zod';
import bcrypt from 'bcryptjs';
import {
  createCheckoutSession,
  handleWebhook,
  cancelSubscription,
  type StripeEnv,
} from './stripe';
import {
  getMeasurementHistory,
  getAllParameterTrends,
  getDailyAverages,
  getWeeklyAverages,
} from './historical';
import { exportMeasurementsToCSV, checkPremiumAccess } from './export';
import {
  RegisterTokenSchema,
  UpdateSettingsSchema,
  HistoryQuerySchema as NotificationHistoryQuerySchema,
  getUserNotificationSettings,
  initializeDefaultSettings,
  upsertNotificationSetting,
  getUserPushTokens,
  registerPushToken,
  unregisterPushToken,
  getNotificationHistory,
  markNotificationsRead,
  processAlertsForMeasurement,
  DEFAULT_THRESHOLDS,
  type ParameterName,
  type NotificationSetting,
} from './notifications';

// =============================================================================
// TYPE DEFINITIONS
// =============================================================================

/**
 * Environment bindings for the Worker
 */
export interface Env extends StripeEnv {
  // D1 Database for persistent storage
  DB: D1Database;

  // KV Namespace for session tracking and rate limiting
  REEF_KV: KVNamespace;

  // Environment variables
  ENVIRONMENT: string;
  FREE_TIER_LIMIT: string;
  CF_ACCOUNT_ID: string;

  // Secrets (set via wrangler secret)
  ANTHROPIC_API_KEY: string;

  // Stripe secrets (set via wrangler secret)
  // STRIPE_SECRET_KEY: string; - inherited from StripeEnv
  // STRIPE_WEBHOOK_SECRET: string; - inherited from StripeEnv
  // STRIPE_PRICE_ID: string; - inherited from StripeEnv

  // AI Gateway configuration
  AI_GATEWAY: {
    gateway_id: string;
  };
}

/**
 * Session data stored in KV
 */
interface SessionData {
  user_id: string;
  created_at: string;
}

/**
 * Authenticated request with user context
 */
interface AuthenticatedContext {
  userId: string;
  sessionToken: string;
}

// =============================================================================
// CONSTANTS
// =============================================================================

const SESSION_EXPIRY_SECONDS = 7 * 24 * 60 * 60; // 1 week in seconds
const BCRYPT_SALT_ROUNDS = 10;

// =============================================================================
// ZOD SCHEMAS FOR REQUEST VALIDATION
// =============================================================================

/**
 * Schema for water parameter readings submission
 * All values are in standard aquarium measurement units
 * Validation is relaxed to allow any numeric values - AI will analyze and provide feedback
 */
const WaterParametersSchema = z.object({
  salinity: z.number().optional().describe('Specific gravity'),
  temperature: z.number().optional().describe('Temperature in Fahrenheit'),
  ph: z.number().optional().describe('pH level'),
  alkalinity: z.number().optional().describe('Alkalinity in dKH'),
  calcium: z.number().optional().describe('Calcium in ppm'),
  magnesium: z.number().optional().describe('Magnesium in ppm'),
  nitrate: z.number().optional().describe('Nitrate in ppm'),
  phosphate: z.number().optional().describe('Phosphate in ppm'),
  ammonia: z.number().optional().describe('Ammonia in ppm'),
});

/**
 * Schema for analysis request
 */
const AnalysisRequestSchema = z.object({
  tankId: z.string().uuid(),
  parameters: WaterParametersSchema,
  tankVolume: z.number().positive().describe('Tank volume in gallons'),
});

/**
 * Schema for user signup request
 */
const SignupRequestSchema = z.object({
  email: z.string().email().max(255),
  password: z.string().min(8).max(128),
});

/**
 * Schema for user login request
 */
const LoginRequestSchema = z.object({
  email: z.string().email(),
  password: z.string(),
});

/**
 * Schema for creating a measurement
 */
const CreateMeasurementSchema = z.object({
  tank_id: z.string().uuid(),
  ph: z.number().optional(),
  alkalinity: z.number().optional(),
  calcium: z.number().optional(),
  magnesium: z.number().optional(),
  nitrate: z.number().optional(),
  phosphate: z.number().optional(),
  salinity: z.number().optional(),
  temperature: z.number().optional(),
  ammonia: z.number().optional(),
  nitrite: z.number().optional(),
  measured_at: z.string().datetime().optional(),
  notes: z.string().optional(),
});

/**
 * Schema for creating a tank (iOS sends snake_case)
 */
const TankCreateSchema = z.object({
  name: z.string().min(1).max(255).describe('Tank name'),
  volume_gallons: z.number().positive().describe('Tank volume in gallons'),
  tank_type: z.string().max(50).optional().describe('Type of tank (reef, fish-only, etc.)'),
});

/**
 * Schema for updating a tank (iOS sends snake_case)
 */
const TankUpdateSchema = z.object({
  name: z.string().min(1).max(255).optional().describe('Tank name'),
  volume_gallons: z.number().positive().optional().describe('Tank volume in gallons'),
  tank_type: z.string().max(50).optional().describe('Type of tank'),
});

/**
 * Schema for subscription checkout request
 */
const SubscriptionCheckoutSchema = z.object({
  successUrl: z.string().url(),
  cancelUrl: z.string().url(),
});

/**
 * Schema for subscription cancellation request
 */
const SubscriptionCancelSchema = z.object({
  cancelAtPeriodEnd: z.boolean().optional().default(true),
});

/**
 * Schema for historical data query parameters
 */
const HistoryQuerySchema = z.object({
  start: z.string().datetime().describe('Start date in ISO 8601 format'),
  end: z.string().datetime().describe('End date in ISO 8601 format'),
});

/**
 * Schema for trends query parameters
 */
const TrendsQuerySchema = z.object({
  days: z.coerce.number().min(1).max(365).default(30).describe('Number of days to analyze'),
});

/**
 * Schema for averages query parameters
 */
const AveragesQuerySchema = z.object({
  period: z.enum(['daily', 'weekly']).describe('Aggregation period'),
  count: z.coerce.number().min(1).max(365).default(30).describe('Number of periods to retrieve'),
});

/**
 * Schema for CSV export query parameters
 */
const ExportQuerySchema = z.object({
  start: z.string().datetime().describe('Start date in ISO 8601 format'),
  end: z.string().datetime().describe('End date in ISO 8601 format'),
});

// =============================================================================
// LIVESTOCK SCHEMAS
// =============================================================================

/**
 * Valid livestock categories from existing schema
 */
const LivestockCategoryEnum = z.enum(['SPS', 'LPS', 'Soft', 'Fish', 'Invertebrate']);

/**
 * Valid health status values
 */
const HealthStatusEnum = z.enum(['healthy', 'sick', 'deceased', 'quarantine']);

/**
 * Valid log types for livestock health tracking
 */
const LogTypeEnum = z.enum(['feeding', 'observation', 'treatment', 'death']);

/**
 * Schema for creating new livestock
 */
const LivestockCreateSchema = z.object({
  name: z.string().min(1).max(255).describe('Display name for the livestock'),
  species: z.string().max(255).optional().describe('Scientific or common species name'),
  category: LivestockCategoryEnum.describe('Type of livestock: SPS, LPS, Soft, Fish, or Invertebrate'),
  quantity: z.number().int().min(1).default(1).describe('Number of individuals'),
  purchaseDate: z.string().datetime().optional().describe('Date of purchase in ISO 8601 format'),
  purchasePrice: z.number().min(0).optional().describe('Purchase price'),
  healthStatus: HealthStatusEnum.optional().default('healthy').describe('Current health status'),
  notes: z.string().max(2000).optional().describe('Additional notes or observations'),
  imageUrl: z.string().url().max(2048).optional().describe('URL to livestock image'),
});

/**
 * Schema for updating livestock details
 */
const LivestockUpdateSchema = z.object({
  name: z.string().min(1).max(255).optional().describe('Display name for the livestock'),
  species: z.string().max(255).optional().describe('Scientific or common species name'),
  category: LivestockCategoryEnum.optional().describe('Type of livestock'),
  quantity: z.number().int().min(0).optional().describe('Number of individuals (0 for deceased)'),
  purchaseDate: z.string().datetime().optional().describe('Date of purchase in ISO 8601 format'),
  purchasePrice: z.number().min(0).optional().describe('Purchase price'),
  healthStatus: HealthStatusEnum.optional().describe('Current health status'),
  notes: z.string().max(2000).optional().describe('Additional notes or observations'),
  imageUrl: z.string().url().max(2048).optional().describe('URL to livestock image'),
});

/**
 * Schema for creating livestock health log entries
 */
const LivestockLogSchema = z.object({
  logType: LogTypeEnum.describe('Type of log entry: feeding, observation, treatment, or death'),
  description: z.string().max(2000).optional().describe('Details about the event'),
  loggedAt: z.string().datetime().optional().describe('When the event occurred (defaults to now)'),
});

// Export schemas for external use
export type WaterParameters = z.infer<typeof WaterParametersSchema>;
export type AnalysisRequest = z.infer<typeof AnalysisRequestSchema>;
export type SignupRequest = z.infer<typeof SignupRequestSchema>;
export type LoginRequest = z.infer<typeof LoginRequestSchema>;
export type CreateMeasurement = z.infer<typeof CreateMeasurementSchema>;
export type SubscriptionCheckout = z.infer<typeof SubscriptionCheckoutSchema>;
export type SubscriptionCancel = z.infer<typeof SubscriptionCancelSchema>;
export type LivestockCreate = z.infer<typeof LivestockCreateSchema>;
export type LivestockUpdate = z.infer<typeof LivestockUpdateSchema>;
export type LivestockLog = z.infer<typeof LivestockLogSchema>;

// =============================================================================
// UTILITY FUNCTIONS
// =============================================================================

/**
 * Generate a cryptographically secure session token
 */
function generateSessionToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

/**
 * Generate a UUID v4
 */
function generateUUID(): string {
  return crypto.randomUUID();
}

/**
 * Create a JSON response with CORS headers
 */
function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

/**
 * Create an error response
 */
function errorResponse(error: string, message: string, status: number): Response {
  return jsonResponse({ error, message }, status);
}

// =============================================================================
// AI GATEWAY INTEGRATION
// =============================================================================

/**
 * Call AI Gateway for water chemistry analysis
 * Routes requests through Cloudflare AI Gateway for caching and analytics
 */
async function callAIGateway(env: Env, prompt: string): Promise<string> {
  if (!env.ANTHROPIC_API_KEY || !env.CF_ACCOUNT_ID) {
    console.log('AI Gateway not fully configured, returning placeholder');
    return JSON.stringify({
      status: 'not_configured',
      message: 'AI Gateway requires ANTHROPIC_API_KEY secret and CF_ACCOUNT_ID.',
      recommendation: 'Please configure your Cloudflare AI Gateway.',
    });
  }

  const gatewayUrl = `https://gateway.ai.cloudflare.com/v1/${env.CF_ACCOUNT_ID}/${env.AI_GATEWAY.gateway_id}/anthropic/v1/messages`;

  try {
    const response = await fetch(gatewayUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-3-haiku-20240307',
        max_tokens: 1024,
        messages: [{ role: 'user', content: prompt }],
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`AI Gateway error: ${response.status} - ${errorText}`);
      return JSON.stringify({
        status: 'error',
        message: `AI Gateway returned ${response.status}`,
        details: errorText,
      });
    }

    const data = (await response.json()) as { content: Array<{ text: string }> };
    return data.content[0].text;
  } catch (error) {
    console.error('AI Gateway fetch error:', error);
    return JSON.stringify({
      status: 'error',
      message: error instanceof Error ? error.message : 'Unknown error calling AI Gateway',
    });
  }
}

// =============================================================================
// SUBSCRIPTION & RATE LIMITING
// =============================================================================

/**
 * User data from database
 */
interface UserRecord {
  id: string;
  email: string;
  subscription_tier: string;
  stripe_customer_id: string | null;
  stripe_subscription_id: string | null;
}

/**
 * Get user subscription tier from database
 */
async function getUserSubscriptionTier(
  env: Env,
  userId: string
): Promise<{ tier: string; isPremium: boolean; user: UserRecord | null }> {
  try {
    // Try full query with stripe columns first
    const user = (await env.DB.prepare(
      'SELECT id, email, subscription_tier, stripe_customer_id, stripe_subscription_id FROM users WHERE id = ?'
    )
      .bind(userId)
      .first()) as UserRecord | null;

    if (!user) {
      return { tier: 'free', isPremium: false, user: null };
    }

    const isPremium = user.subscription_tier === 'premium';
    return { tier: user.subscription_tier, isPremium, user };
  } catch {
    // Fall back to basic query if stripe columns don't exist
    try {
      const user = (await env.DB.prepare(
        'SELECT id, email, subscription_tier FROM users WHERE id = ?'
      )
        .bind(userId)
        .first()) as UserRecord | null;

      if (!user) {
        return { tier: 'free', isPremium: false, user: null };
      }

      const isPremium = user.subscription_tier === 'premium';
      return { tier: user.subscription_tier, isPremium, user };
    } catch {
      // No user table or other error - default to free tier
      return { tier: 'free', isPremium: false, user: null };
    }
  }
}

/**
 * Update user subscription tier in database
 */
async function updateUserSubscription(
  env: Env,
  userId: string,
  tier: 'free' | 'premium',
  stripeCustomerId?: string,
  stripeSubscriptionId?: string
): Promise<void> {
  if (stripeCustomerId && stripeSubscriptionId) {
    await env.DB.prepare(
      'UPDATE users SET subscription_tier = ?, stripe_customer_id = ?, stripe_subscription_id = ? WHERE id = ?'
    )
      .bind(tier, stripeCustomerId, stripeSubscriptionId, userId)
      .run();
  } else if (tier === 'free') {
    await env.DB.prepare(
      'UPDATE users SET subscription_tier = ?, stripe_subscription_id = NULL WHERE id = ?'
    )
      .bind(tier, userId)
      .run();
  } else {
    await env.DB.prepare('UPDATE users SET subscription_tier = ? WHERE id = ?').bind(tier, userId).run();
  }
}

/**
 * Find user by Stripe subscription ID
 */
async function findUserByStripeSubscription(
  env: Env,
  subscriptionId: string
): Promise<UserRecord | null> {
  return (await env.DB.prepare('SELECT * FROM users WHERE stripe_subscription_id = ?')
    .bind(subscriptionId)
    .first()) as UserRecord | null;
}

/**
 * Check and enforce free tier limits using KV
 * Premium users have unlimited access
 * Free tier users get 3 analysis requests per month
 */
async function checkRateLimit(
  env: Env,
  userId: string
): Promise<{ allowed: boolean; remaining: number; isPremium: boolean }> {
  // Check if user is premium
  const { isPremium } = await getUserSubscriptionTier(env, userId);

  if (isPremium) {
    return { allowed: true, remaining: -1, isPremium: true }; // -1 indicates unlimited
  }

  const key = `rate:${userId}:${new Date().toISOString().slice(0, 7)}`;
  const limit = parseInt(env.FREE_TIER_LIMIT || '3', 10);

  const currentCount = parseInt((await env.REEF_KV.get(key)) || '0', 10);

  if (currentCount >= limit) {
    return { allowed: false, remaining: 0, isPremium: false };
  }

  await env.REEF_KV.put(key, String(currentCount + 1), {
    expirationTtl: 60 * 60 * 24 * 32,
  });

  return { allowed: true, remaining: limit - currentCount - 1, isPremium: false };
}

/**
 * Premium middleware - checks if user has premium subscription
 * Returns 402 Payment Required if not premium
 */
async function requirePremium(
  env: Env,
  auth: AuthenticatedContext
): Promise<Response | null> {
  const { isPremium } = await getUserSubscriptionTier(env, auth.userId);

  if (!isPremium) {
    return errorResponse(
      'Payment Required',
      'This feature requires a premium subscription. Upgrade to premium for $4.99/month.',
      402
    );
  }

  return null; // User is premium, proceed
}

// =============================================================================
// SESSION MANAGEMENT
// =============================================================================

/**
 * Create a session in KV and return the token
 */
async function createSession(env: Env, userId: string): Promise<string> {
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
async function validateSession(env: Env, token: string): Promise<SessionData | null> {
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
async function invalidateSession(env: Env, token: string): Promise<void> {
  await env.REEF_KV.delete(`session:${token}`);
}

/**
 * Extract session token from Authorization header
 * Expected format: "Bearer <token>"
 */
function extractSessionToken(request: Request): string | null {
  const authHeader = request.headers.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return null;
  }
  return authHeader.slice(7);
}

/**
 * Session middleware - validates authentication and returns user context
 */
async function authenticateRequest(
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

// =============================================================================
// AUTH HANDLERS
// =============================================================================

/**
 * Handle user signup
 * POST /auth/signup
 */
async function handleSignup(request: Request, env: Env): Promise<Response> {
  try {
    const body = await request.json();

    const validationResult = SignupRequestSchema.safeParse(body);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          details: validationResult.error.flatten(),
        },
        400
      );
    }

    const { email, password } = validationResult.data;

    // Check if user already exists
    const existingUser = await env.DB.prepare('SELECT id FROM users WHERE email = ?')
      .bind(email.toLowerCase())
      .first();

    if (existingUser) {
      return errorResponse('Conflict', 'A user with this email already exists', 409);
    }

    // Hash password with bcrypt
    const passwordHash = await bcrypt.hash(password, BCRYPT_SALT_ROUNDS);

    // Create user
    const userId = generateUUID();
    await env.DB.prepare(
      'INSERT INTO users (id, email, password_hash, subscription_tier) VALUES (?, ?, ?, ?)'
    )
      .bind(userId, email.toLowerCase(), passwordHash, 'free')
      .run();

    // Create session
    const sessionToken = await createSession(env, userId);

    return jsonResponse(
      {
        success: true,
        user: {
          id: userId,
          email: email.toLowerCase(),
          subscription_tier: 'free',
        },
        session_token: sessionToken,
        expires_in: SESSION_EXPIRY_SECONDS,
      },
      201
    );
  } catch (error) {
    console.error('Signup error:', error);
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

/**
 * Handle user login
 * POST /auth/login
 */
async function handleLogin(request: Request, env: Env): Promise<Response> {
  try {
    const body = await request.json();

    const validationResult = LoginRequestSchema.safeParse(body);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          details: validationResult.error.flatten(),
        },
        400
      );
    }

    const { email, password } = validationResult.data;

    // Find user by email
    const user = (await env.DB.prepare(
      'SELECT id, email, password_hash, subscription_tier FROM users WHERE email = ?'
    )
      .bind(email.toLowerCase())
      .first()) as {
      id: string;
      email: string;
      password_hash: string | null;
      subscription_tier: string;
    } | null;

    if (!user || !user.password_hash) {
      return errorResponse('Unauthorized', 'Invalid email or password', 401);
    }

    // Verify password
    const passwordValid = await bcrypt.compare(password, user.password_hash);

    if (!passwordValid) {
      return errorResponse('Unauthorized', 'Invalid email or password', 401);
    }

    // Create session
    const sessionToken = await createSession(env, user.id);

    return jsonResponse({
      success: true,
      user: {
        id: user.id,
        email: user.email,
        subscription_tier: user.subscription_tier,
      },
      session_token: sessionToken,
      expires_in: SESSION_EXPIRY_SECONDS,
    });
  } catch (error) {
    console.error('Login error:', error);
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

/**
 * Handle user logout
 * POST /auth/logout
 */
async function handleLogout(request: Request, env: Env): Promise<Response> {
  try {
    const token = extractSessionToken(request);

    if (!token) {
      return errorResponse('Unauthorized', 'Missing or invalid Authorization header', 401);
    }

    // Invalidate the session
    await invalidateSession(env, token);

    return jsonResponse({
      success: true,
      message: 'Successfully logged out',
    });
  } catch (error) {
    console.error('Logout error:', error);
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

// =============================================================================
// TANK HANDLERS
// =============================================================================

/**
 * Tank record from database
 */
interface TankRecord {
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
 * Handle listing all tanks for the authenticated user
 * GET /api/tanks (authenticated)
 */
async function handleListTanks(env: Env, auth: AuthenticatedContext): Promise<Response> {
  try {
    const result = await env.DB.prepare(
      'SELECT * FROM tanks WHERE user_id = ? AND deleted_at IS NULL ORDER BY created_at DESC'
    )
      .bind(auth.userId)
      .all();

    const tanks = result.results as TankRecord[];

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
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

/**
 * Handle getting a single tank
 * GET /api/tanks/:id (authenticated)
 */
async function handleGetTank(
  env: Env,
  auth: AuthenticatedContext,
  tankId: string
): Promise<Response> {
  try {
    const tank = (await env.DB.prepare(
      'SELECT * FROM tanks WHERE id = ? AND user_id = ? AND deleted_at IS NULL'
    )
      .bind(tankId, auth.userId)
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
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

/**
 * Handle creating a new tank
 * POST /api/tanks (authenticated)
 */
async function handleCreateTank(
  request: Request,
  env: Env,
  auth: AuthenticatedContext
): Promise<Response> {
  try {
    const body = await request.json();

    const validationResult = TankCreateSchema.safeParse(body);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          details: validationResult.error.flatten(),
        },
        400
      );
    }

    const data = validationResult.data;

    const tankId = generateUUID();
    const now = new Date().toISOString();

    await env.DB.prepare(
      `INSERT INTO tanks (id, user_id, name, volume_gallons, tank_type, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`
    )
      .bind(tankId, auth.userId, data.name, data.volume_gallons, data.tank_type ?? null, now, now)
      .run();

    return jsonResponse(
      {
        success: true,
        data: {
          id: tankId,
          user_id: auth.userId,
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
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

/**
 * Handle updating a tank
 * PUT /api/tanks/:id (authenticated)
 */
async function handleUpdateTank(
  request: Request,
  env: Env,
  auth: AuthenticatedContext,
  tankId: string
): Promise<Response> {
  try {
    // Verify tank exists and belongs to user
    const existingTank = (await env.DB.prepare(
      'SELECT * FROM tanks WHERE id = ? AND user_id = ? AND deleted_at IS NULL'
    )
      .bind(tankId, auth.userId)
      .first()) as TankRecord | null;

    if (!existingTank) {
      return errorResponse('Not found', 'Tank not found', 404);
    }

    const body = await request.json();

    const validationResult = TankUpdateSchema.safeParse(body);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          details: validationResult.error.flatten(),
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

    values.push(tankId);

    await env.DB.prepare(`UPDATE tanks SET ${updates.join(', ')} WHERE id = ?`)
      .bind(...values)
      .run();

    // Fetch updated record
    const updated = (await env.DB.prepare('SELECT * FROM tanks WHERE id = ?')
      .bind(tankId)
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
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

/**
 * Handle deleting a tank (soft delete)
 * DELETE /api/tanks/:id (authenticated)
 */
async function handleDeleteTank(
  env: Env,
  auth: AuthenticatedContext,
  tankId: string
): Promise<Response> {
  try {
    // Verify tank exists and belongs to user
    const existingTank = (await env.DB.prepare(
      'SELECT * FROM tanks WHERE id = ? AND user_id = ? AND deleted_at IS NULL'
    )
      .bind(tankId, auth.userId)
      .first()) as TankRecord | null;

    if (!existingTank) {
      return errorResponse('Not found', 'Tank not found', 404);
    }

    // Soft delete the tank
    const now = new Date().toISOString();
    await env.DB.prepare('UPDATE tanks SET deleted_at = ? WHERE id = ?').bind(now, tankId).run();

    return jsonResponse({
      success: true,
      message: 'Tank deleted successfully',
    });
  } catch (error) {
    console.error('Delete tank error:', error);
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

// =============================================================================
// MEASUREMENT HANDLERS
// =============================================================================

/**
 * Handle creating a new measurement
 * POST /measurements (authenticated)
 */
async function handleCreateMeasurement(
  request: Request,
  env: Env,
  auth: AuthenticatedContext
): Promise<Response> {
  try {
    const body = await request.json();

    const validationResult = CreateMeasurementSchema.safeParse(body);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          details: validationResult.error.flatten(),
        },
        400
      );
    }

    const data = validationResult.data;

    // Verify the tank belongs to the authenticated user
    const tank = (await env.DB.prepare('SELECT id, user_id, name FROM tanks WHERE id = ? AND deleted_at IS NULL')
      .bind(data.tank_id)
      .first()) as { id: string; user_id: string; name: string } | null;

    if (!tank) {
      return errorResponse('Not found', 'Tank not found', 404);
    }

    if (tank.user_id !== auth.userId) {
      return errorResponse('Forbidden', 'You do not have access to this tank', 403);
    }

    // Create measurement
    const measurementId = generateUUID();
    const measuredAt = data.measured_at || new Date().toISOString();

    await env.DB.prepare(
      `INSERT INTO measurements (id, tank_id, measured_at, ph, alkalinity, calcium, magnesium, nitrate, phosphate, salinity, temperature, ammonia, nitrite, notes)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    )
      .bind(
        measurementId,
        data.tank_id,
        measuredAt,
        data.ph ?? null,
        data.alkalinity ?? null,
        data.calcium ?? null,
        data.magnesium ?? null,
        data.nitrate ?? null,
        data.phosphate ?? null,
        data.salinity ?? null,
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
          tank_id: data.tank_id,
          ph: data.ph,
          alkalinity: data.alkalinity,
          calcium: data.calcium,
          magnesium: data.magnesium,
          ammonia: data.ammonia,
          nitrate: data.nitrate,
          phosphate: data.phosphate,
          salinity: data.salinity,
          temperature: data.temperature,
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
          tank_id: data.tank_id,
          measured_at: measuredAt,
          ph: data.ph ?? null,
          alkalinity: data.alkalinity ?? null,
          calcium: data.calcium ?? null,
          magnesium: data.magnesium ?? null,
          nitrate: data.nitrate ?? null,
          phosphate: data.phosphate ?? null,
          salinity: data.salinity ?? null,
          temperature: data.temperature ?? null,
          ammonia: data.ammonia ?? null,
          nitrite: data.nitrite ?? null,
          notes: data.notes ?? null,
        },
        alerts: alerts.length > 0 ? alerts : undefined,
      },
      201
    );
  } catch (error) {
    console.error('Create measurement error:', error);
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

// =============================================================================
// ANALYSIS HANDLER
// =============================================================================

/**
 * Handle water analysis request
 * POST /analyze
 */
async function handleAnalysis(request: Request, env: Env): Promise<Response> {
  try {
    const body = await request.json();

    const validationResult = AnalysisRequestSchema.safeParse(body);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          details: validationResult.error.flatten(),
        },
        400
      );
    }

    const { tankId, parameters, tankVolume } = validationResult.data;

    // Check rate limit (using tankId as user identifier for now)
    const rateLimit = await checkRateLimit(env, tankId);

    if (!rateLimit.allowed) {
      return jsonResponse(
        {
          error: 'Rate limit exceeded',
          message: 'Free tier limit of 3 analyses per month reached. Upgrade for unlimited access.',
        },
        429
      );
    }

    // Build parameter list dynamically based on what was provided
    const paramLines: string[] = [];
    if (parameters.salinity !== undefined) paramLines.push(`- Salinity: ${parameters.salinity}`);
    if (parameters.temperature !== undefined) paramLines.push(`- Temperature: ${parameters.temperature}°F`);
    if (parameters.ph !== undefined) paramLines.push(`- pH: ${parameters.ph}`);
    if (parameters.alkalinity !== undefined) paramLines.push(`- Alkalinity: ${parameters.alkalinity} dKH`);
    if (parameters.calcium !== undefined) paramLines.push(`- Calcium: ${parameters.calcium} ppm`);
    if (parameters.magnesium !== undefined) paramLines.push(`- Magnesium: ${parameters.magnesium} ppm`);
    if (parameters.nitrate !== undefined) paramLines.push(`- Nitrate: ${parameters.nitrate} ppm`);
    if (parameters.phosphate !== undefined) paramLines.push(`- Phosphate: ${parameters.phosphate} ppm`);
    if (parameters.ammonia !== undefined) paramLines.push(`- Ammonia: ${parameters.ammonia} ppm`);

    if (paramLines.length === 0) {
      return jsonResponse(
        {
          error: 'No parameters provided',
          message: 'Please provide at least one water parameter to analyze.',
        },
        400
      );
    }

    const prompt = `Analyze these saltwater aquarium water parameters and provide dosing recommendations:
Tank Volume: ${tankVolume} gallons
Parameters:
${paramLines.join('\n')}

Provide specific dosing recommendations to bring parameters to optimal reef levels. If any values are outside typical reef tank ranges, highlight this as a warning.`;

    const aiResponse = await callAIGateway(env, prompt);

    // Try to parse AI response, fallback to raw string
    let analysis: unknown;
    try {
      analysis = JSON.parse(aiResponse);
    } catch {
      analysis = { recommendation: aiResponse };
    }

    return jsonResponse({
      success: true,
      tankId,
      analysis,
      rateLimitRemaining: rateLimit.remaining,
    });
  } catch (error) {
    console.error('Analysis error:', error);
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

/**
 * Health check endpoint
 */
function handleHealth(env: Env): Response {
  return jsonResponse({
    status: 'healthy',
    service: 'ReefBuddy API',
    version: '1.0.0',
    environment: env.ENVIRONMENT || 'unknown',
    timestamp: new Date().toISOString(),
  });
}

// =============================================================================
// SUBSCRIPTION HANDLERS
// =============================================================================

/**
 * Handle subscription checkout session creation
 * POST /subscriptions/create (authenticated)
 */
async function handleSubscriptionCreate(
  request: Request,
  env: Env,
  auth: AuthenticatedContext
): Promise<Response> {
  try {
    const body = await request.json();

    const validationResult = SubscriptionCheckoutSchema.safeParse(body);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          details: validationResult.error.flatten(),
        },
        400
      );
    }

    const { successUrl, cancelUrl } = validationResult.data;

    // Get user email for Stripe
    const { user } = await getUserSubscriptionTier(env, auth.userId);
    if (!user) {
      return errorResponse('Not found', 'User not found', 404);
    }

    // Check if user already has premium
    if (user.subscription_tier === 'premium') {
      return jsonResponse(
        {
          error: 'Already subscribed',
          message: 'You already have an active premium subscription.',
        },
        400
      );
    }

    // Create Stripe checkout session
    const result = await createCheckoutSession(env, auth.userId, user.email, successUrl, cancelUrl);

    if (!result.success) {
      return errorResponse('Stripe error', result.error || 'Failed to create checkout session', 500);
    }

    return jsonResponse({
      success: true,
      sessionId: result.sessionId,
      checkoutUrl: result.url,
    });
  } catch (error) {
    console.error('Subscription create error:', error);
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

/**
 * Handle Stripe webhook events
 * POST /subscriptions/webhook (public - verified by signature)
 */
async function handleSubscriptionWebhook(request: Request, env: Env): Promise<Response> {
  try {
    const payload = await request.text();
    const signatureHeader = request.headers.get('Stripe-Signature');

    if (!signatureHeader) {
      return errorResponse('Bad request', 'Missing Stripe-Signature header', 400);
    }

    const result = await handleWebhook(env, payload, signatureHeader);

    if (!result.success) {
      console.error('Webhook error:', result.error);
      return errorResponse('Webhook error', result.error || 'Failed to process webhook', 400);
    }

    // Process specific events
    switch (result.eventType) {
      case 'checkout.session.completed': {
        if (result.userId && result.subscriptionId) {
          // Upgrade user to premium
          await updateUserSubscription(
            env,
            result.userId,
            'premium',
            undefined, // Customer ID from subscription if needed
            result.subscriptionId
          );
          console.log(`User ${result.userId} upgraded to premium`);
        }
        break;
      }

      case 'customer.subscription.deleted': {
        if (result.subscriptionId) {
          // Find user by subscription ID and downgrade
          const user = await findUserByStripeSubscription(env, result.subscriptionId);
          if (user) {
            await updateUserSubscription(env, user.id, 'free');
            console.log(`User ${user.id} downgraded to free`);
          } else if (result.userId) {
            // Fallback to userId from metadata
            await updateUserSubscription(env, result.userId, 'free');
            console.log(`User ${result.userId} downgraded to free (via metadata)`);
          }
        }
        break;
      }

      default:
        // Other events acknowledged but not processed
        console.log(`Webhook event ${result.eventType} acknowledged`);
    }

    return jsonResponse({ received: true });
  } catch (error) {
    console.error('Webhook processing error:', error);
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

/**
 * Handle get subscription status
 * GET /subscriptions/status (authenticated)
 */
async function handleSubscriptionStatus(env: Env, auth: AuthenticatedContext): Promise<Response> {
  try {
    const { tier, isPremium, user } = await getUserSubscriptionTier(env, auth.userId);

    if (!user) {
      return errorResponse('Not found', 'User not found', 404);
    }

    // Get rate limit info for free users
    let rateLimitInfo = null;
    if (!isPremium) {
      const key = `rate:${auth.userId}:${new Date().toISOString().slice(0, 7)}`;
      const currentCount = parseInt((await env.REEF_KV.get(key)) || '0', 10);
      const limit = parseInt(env.FREE_TIER_LIMIT || '3', 10);
      rateLimitInfo = {
        used: currentCount,
        limit,
        remaining: Math.max(0, limit - currentCount),
      };
    }

    return jsonResponse({
      success: true,
      subscription: {
        tier,
        isPremium,
        stripeSubscriptionId: user.stripe_subscription_id,
        features: isPremium
          ? {
              analysesPerMonth: 'unlimited',
              csvExport: true,
              historicalCharts: true,
            }
          : {
              analysesPerMonth: 3,
              csvExport: false,
              historicalCharts: false,
            },
      },
      rateLimit: rateLimitInfo,
      pricing: {
        premiumPrice: '$4.99/month',
        features: [
          'Unlimited water analyses',
          'CSV export of measurements',
          'Historical trend charts',
          'Priority AI recommendations',
        ],
      },
    });
  } catch (error) {
    console.error('Subscription status error:', error);
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

/**
 * Handle subscription cancellation
 * POST /subscriptions/cancel (authenticated)
 */
async function handleSubscriptionCancel(
  request: Request,
  env: Env,
  auth: AuthenticatedContext
): Promise<Response> {
  try {
    const body = await request.json();

    const validationResult = SubscriptionCancelSchema.safeParse(body);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          details: validationResult.error.flatten(),
        },
        400
      );
    }

    const { cancelAtPeriodEnd } = validationResult.data;

    const { user, isPremium } = await getUserSubscriptionTier(env, auth.userId);

    if (!user) {
      return errorResponse('Not found', 'User not found', 404);
    }

    if (!isPremium || !user.stripe_subscription_id) {
      return jsonResponse(
        {
          error: 'No active subscription',
          message: 'You do not have an active premium subscription to cancel.',
        },
        400
      );
    }

    const result = await cancelSubscription(env, user.stripe_subscription_id, cancelAtPeriodEnd);

    if (!result.success) {
      return errorResponse('Stripe error', result.error || 'Failed to cancel subscription', 500);
    }

    // If canceling immediately, update the database now
    if (!cancelAtPeriodEnd) {
      await updateUserSubscription(env, auth.userId, 'free');
    }

    return jsonResponse({
      success: true,
      message: cancelAtPeriodEnd
        ? 'Subscription will be canceled at the end of the current billing period. You will retain premium access until then.'
        : 'Subscription canceled immediately. Your account has been downgraded to free tier.',
      cancelAtPeriodEnd,
    });
  } catch (error) {
    console.error('Subscription cancel error:', error);
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

// =============================================================================
// HISTORICAL DATA HANDLERS
// =============================================================================

/**
 * Verify tank ownership helper
 * Returns tank if found and owned by user, or error response
 */
async function verifyTankOwnership(
  env: Env,
  tankId: string,
  userId: string
): Promise<{ id: string; user_id: string; name: string } | Response> {
  const tank = (await env.DB.prepare(
    'SELECT id, user_id, name FROM tanks WHERE id = ? AND deleted_at IS NULL'
  )
    .bind(tankId)
    .first()) as { id: string; user_id: string; name: string } | null;

  if (!tank) {
    return errorResponse('Not found', 'Tank not found', 404);
  }

  if (tank.user_id !== userId) {
    return errorResponse('Forbidden', 'You do not have access to this tank', 403);
  }

  return tank;
}

/**
 * Handle historical measurements request
 * GET /tanks/:tankId/history?start=&end=
 */
async function handleGetHistory(
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

    // Parse and validate query parameters
    const url = new URL(request.url);
    const queryParams = {
      start: url.searchParams.get('start'),
      end: url.searchParams.get('end'),
    };

    const validationResult = HistoryQuerySchema.safeParse(queryParams);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          message: 'start and end query parameters are required in ISO 8601 format',
          details: validationResult.error.flatten(),
        },
        400
      );
    }

    const { start, end } = validationResult.data;

    // Fetch historical measurements
    const measurements = await getMeasurementHistory(env.DB, tankId, start, end);

    return jsonResponse({
      success: true,
      tank_id: tankId,
      tank_name: tankResult.name,
      start_date: start,
      end_date: end,
      count: measurements.length,
      measurements,
    });
  } catch (error) {
    console.error('Get history error:', error);
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

/**
 * Handle parameter trends request
 * GET /tanks/:tankId/trends?days=30
 */
async function handleGetTrends(
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

    // Parse and validate query parameters
    const url = new URL(request.url);
    const queryParams = {
      days: url.searchParams.get('days') || '30',
    };

    const validationResult = TrendsQuerySchema.safeParse(queryParams);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          details: validationResult.error.flatten(),
        },
        400
      );
    }

    const { days } = validationResult.data;

    // Get all parameter trends
    const trends = await getAllParameterTrends(env.DB, tankId, days);

    return jsonResponse({
      success: true,
      tank_name: tankResult.name,
      ...trends,
    });
  } catch (error) {
    console.error('Get trends error:', error);
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

/**
 * Handle aggregated averages request
 * GET /tanks/:tankId/averages?period=daily|weekly&count=30
 */
async function handleGetAverages(
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

    // Parse and validate query parameters
    const url = new URL(request.url);
    const queryParams = {
      period: url.searchParams.get('period'),
      count: url.searchParams.get('count') || '30',
    };

    const validationResult = AveragesQuerySchema.safeParse(queryParams);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          message: 'period query parameter is required (daily or weekly)',
          details: validationResult.error.flatten(),
        },
        400
      );
    }

    const { period, count } = validationResult.data;

    // Get aggregated data based on period
    let averages;
    if (period === 'daily') {
      averages = await getDailyAverages(env.DB, tankId, count);
    } else {
      averages = await getWeeklyAverages(env.DB, tankId, count);
    }

    return jsonResponse({
      success: true,
      tank_id: tankId,
      tank_name: tankResult.name,
      period,
      count: averages.length,
      averages,
    });
  } catch (error) {
    console.error('Get averages error:', error);
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

/**
 * Handle CSV export request (Premium only)
 * GET /tanks/:tankId/export?start=&end=
 */
async function handleExportCSV(
  request: Request,
  env: Env,
  auth: AuthenticatedContext,
  tankId: string
): Promise<Response> {
  try {
    // Check premium access
    const isPremium = await checkPremiumAccess(env.DB, auth.userId);
    if (!isPremium) {
      return errorResponse(
        'Payment Required',
        'CSV export is a premium feature. Upgrade to premium for $4.99/month.',
        402
      );
    }

    // Verify tank ownership
    const tankResult = await verifyTankOwnership(env, tankId, auth.userId);
    if (tankResult instanceof Response) {
      return tankResult;
    }

    // Parse and validate query parameters
    const url = new URL(request.url);
    const queryParams = {
      start: url.searchParams.get('start'),
      end: url.searchParams.get('end'),
    };

    const validationResult = ExportQuerySchema.safeParse(queryParams);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          message: 'start and end query parameters are required in ISO 8601 format',
          details: validationResult.error.flatten(),
        },
        400
      );
    }

    const { start, end } = validationResult.data;

    // Generate CSV content
    const csvContent = await exportMeasurementsToCSV(env.DB, tankId, start, end);

    // Create filename with tank name and date range
    const startDate = start.split('T')[0];
    const endDate = end.split('T')[0];
    const filename = `reefbuddy_${tankResult.name.replace(/[^a-zA-Z0-9]/g, '_')}_${startDate}_${endDate}.csv`;

    // Return CSV as downloadable file
    return new Response(csvContent, {
      status: 200,
      headers: {
        'Content-Type': 'text/csv; charset=utf-8',
        'Content-Disposition': `attachment; filename="${filename}"`,
      },
    });
  } catch (error) {
    console.error('Export CSV error:', error);
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

// =============================================================================
// NOTIFICATION HANDLERS
// =============================================================================

/**
 * Handle registering a push token
 * POST /notifications/token (authenticated)
 */
async function handleRegisterPushToken(
  request: Request,
  env: Env,
  auth: AuthenticatedContext
): Promise<Response> {
  try {
    const body = await request.json();

    const validationResult = RegisterTokenSchema.safeParse(body);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          details: validationResult.error.flatten(),
        },
        400
      );
    }

    const { token, platform, deviceName } = validationResult.data;

    const pushToken = await registerPushToken(env.DB, auth.userId, token, platform, deviceName);

    return jsonResponse(
      {
        success: true,
        token: {
          id: pushToken.id,
          platform: pushToken.platform,
          device_name: pushToken.device_name,
          created_at: pushToken.created_at,
        },
      },
      201
    );
  } catch (error) {
    console.error('Register push token error:', error);
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

/**
 * Handle unregistering a push token
 * DELETE /notifications/token (authenticated)
 */
async function handleUnregisterPushToken(
  request: Request,
  env: Env,
  auth: AuthenticatedContext
): Promise<Response> {
  try {
    const body = await request.json();

    const tokenSchema = z.object({ token: z.string().min(1) });
    const validationResult = tokenSchema.safeParse(body);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          details: validationResult.error.flatten(),
        },
        400
      );
    }

    const { token } = validationResult.data;

    // Verify the token belongs to this user before deleting
    const userTokens = await getUserPushTokens(env.DB, auth.userId);
    const ownsToken = userTokens.some((t) => t.token === token);

    if (!ownsToken) {
      return errorResponse('Not found', 'Push token not found or does not belong to this user', 404);
    }

    const deleted = await unregisterPushToken(env.DB, token);

    if (!deleted) {
      return errorResponse('Not found', 'Push token not found', 404);
    }

    return jsonResponse({
      success: true,
      message: 'Push token unregistered successfully',
    });
  } catch (error) {
    console.error('Unregister push token error:', error);
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

/**
 * Handle getting notification settings
 * GET /notifications/settings (authenticated)
 */
async function handleGetNotificationSettings(
  env: Env,
  auth: AuthenticatedContext
): Promise<Response> {
  try {
    let settings = await getUserNotificationSettings(env.DB, auth.userId);

    // If no settings exist, initialize with defaults
    if (settings.length === 0) {
      settings = await initializeDefaultSettings(env.DB, auth.userId);
    }

    // Transform settings to a more user-friendly format
    const settingsMap: Record<string, {
      minThreshold: number | null;
      maxThreshold: number | null;
      enabled: boolean;
      defaultMin: number | null;
      defaultMax: number | null;
    }> = {};

    for (const setting of settings) {
      const defaults = DEFAULT_THRESHOLDS[setting.parameter];
      settingsMap[setting.parameter] = {
        minThreshold: setting.min_threshold,
        maxThreshold: setting.max_threshold,
        enabled: setting.enabled,
        defaultMin: defaults?.min ?? null,
        defaultMax: defaults?.max ?? null,
      };
    }

    return jsonResponse({
      success: true,
      settings: settingsMap,
    });
  } catch (error) {
    console.error('Get notification settings error:', error);
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

/**
 * Handle updating notification settings
 * PUT /notifications/settings (authenticated)
 */
async function handleUpdateNotificationSettings(
  request: Request,
  env: Env,
  auth: AuthenticatedContext
): Promise<Response> {
  try {
    const body = await request.json();

    const validationResult = UpdateSettingsSchema.safeParse(body);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          details: validationResult.error.flatten(),
        },
        400
      );
    }

    const { settings } = validationResult.data;

    // Update each setting
    const updatedSettings: NotificationSetting[] = [];
    for (const setting of settings) {
      // Get existing setting or defaults
      const existingSettings = await getUserNotificationSettings(env.DB, auth.userId);
      const existing = existingSettings.find((s) => s.parameter === setting.parameter);
      const defaults = DEFAULT_THRESHOLDS[setting.parameter as ParameterName];

      const minThreshold = setting.minThreshold !== undefined
        ? setting.minThreshold
        : (existing?.min_threshold ?? defaults?.min ?? null);

      const maxThreshold = setting.maxThreshold !== undefined
        ? setting.maxThreshold
        : (existing?.max_threshold ?? defaults?.max ?? null);

      const enabled = setting.enabled !== undefined
        ? setting.enabled
        : (existing?.enabled ?? true);

      const updated = await upsertNotificationSetting(
        env.DB,
        auth.userId,
        setting.parameter as ParameterName,
        minThreshold,
        maxThreshold,
        enabled
      );

      updatedSettings.push(updated);
    }

    return jsonResponse({
      success: true,
      message: `Updated ${updatedSettings.length} notification setting(s)`,
      settings: updatedSettings.map((s) => ({
        parameter: s.parameter,
        minThreshold: s.min_threshold,
        maxThreshold: s.max_threshold,
        enabled: s.enabled,
      })),
    });
  } catch (error) {
    console.error('Update notification settings error:', error);
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

/**
 * Handle getting notification history
 * GET /notifications/history (authenticated)
 */
async function handleGetNotificationHistory(
  request: Request,
  env: Env,
  auth: AuthenticatedContext
): Promise<Response> {
  try {
    const url = new URL(request.url);
    const queryParams = {
      limit: url.searchParams.get('limit') || '50',
      offset: url.searchParams.get('offset') || '0',
      type: url.searchParams.get('type') || undefined,
      unreadOnly: url.searchParams.get('unreadOnly') || 'false',
    };

    const validationResult = NotificationHistoryQuerySchema.safeParse(queryParams);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          details: validationResult.error.flatten(),
        },
        400
      );
    }

    const { limit, offset, type, unreadOnly } = validationResult.data;

    const { notifications, total } = await getNotificationHistory(
      env.DB,
      auth.userId,
      limit,
      offset,
      type,
      unreadOnly
    );

    return jsonResponse({
      success: true,
      total,
      limit,
      offset,
      notifications: notifications.map((n) => ({
        id: n.id,
        type: n.type,
        title: n.title,
        body: n.body,
        parameter: n.parameter,
        value: n.value,
        thresholdType: n.threshold_type,
        thresholdValue: n.threshold_value,
        sentAt: n.sent_at,
        readAt: n.read_at,
      })),
    });
  } catch (error) {
    console.error('Get notification history error:', error);
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

/**
 * Handle marking notifications as read
 * POST /notifications/read (authenticated)
 */
async function handleMarkNotificationsRead(
  request: Request,
  env: Env,
  auth: AuthenticatedContext
): Promise<Response> {
  try {
    const body = await request.json();

    const markReadSchema = z.object({
      notificationIds: z.array(z.string().uuid()).optional(),
    });

    const validationResult = markReadSchema.safeParse(body);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          details: validationResult.error.flatten(),
        },
        400
      );
    }

    const { notificationIds } = validationResult.data;

    const markedCount = await markNotificationsRead(env.DB, auth.userId, notificationIds);

    return jsonResponse({
      success: true,
      message: notificationIds
        ? `Marked ${markedCount} notification(s) as read`
        : `Marked all (${markedCount}) notifications as read`,
      markedCount,
    });
  } catch (error) {
    console.error('Mark notifications read error:', error);
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

// =============================================================================
// LIVESTOCK HANDLERS
// =============================================================================

/**
 * Livestock record from database
 */
interface LivestockRecord {
  id: string;
  tank_id: string;
  name: string;
  species: string | null;
  category: string | null;
  quantity: number;
  purchase_date: string | null;
  purchase_price: number | null;
  health_status: string | null;
  notes: string | null;
  image_url: string | null;
  added_at: string;
  created_at: string;
  deleted_at: string | null;
}

/**
 * Livestock log record from database
 */
interface LivestockLogRecord {
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
async function verifyLivestockOwnership(
  env: Env,
  livestockId: string,
  userId: string
): Promise<LivestockRecord | Response> {
  const livestock = (await env.DB.prepare(
    `SELECT l.* FROM livestock l
     JOIN tanks t ON l.tank_id = t.id
     WHERE l.id = ? AND t.user_id = ? AND l.deleted_at IS NULL AND t.deleted_at IS NULL`
  )
    .bind(livestockId, userId)
    .first()) as LivestockRecord | null;

  if (!livestock) {
    return errorResponse('Not found', 'Livestock not found or you do not have access', 404);
  }

  return livestock;
}

/**
 * Handle creating new livestock
 * POST /tanks/:tankId/livestock (authenticated)
 */
async function handleCreateLivestock(
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

    const body = await request.json();

    const validationResult = LivestockCreateSchema.safeParse(body);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          details: validationResult.error.flatten(),
        },
        400
      );
    }

    const data = validationResult.data;

    // Create livestock
    const livestockId = generateUUID();
    const now = new Date().toISOString();

    await env.DB.prepare(
      `INSERT INTO livestock (id, tank_id, name, species, category, quantity, purchase_date, purchase_price, health_status, notes, image_url, added_at, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    )
      .bind(
        livestockId,
        tankId,
        data.name,
        data.species ?? null,
        data.category,
        data.quantity,
        data.purchaseDate ?? null,
        data.purchasePrice ?? null,
        data.healthStatus ?? 'healthy',
        data.notes ?? null,
        data.imageUrl ?? null,
        now,
        now
      )
      .run();

    return jsonResponse(
      {
        success: true,
        livestock: {
          id: livestockId,
          tank_id: tankId,
          name: data.name,
          species: data.species ?? null,
          category: data.category,
          quantity: data.quantity,
          purchase_date: data.purchaseDate ?? null,
          purchase_price: data.purchasePrice ?? null,
          health_status: data.healthStatus ?? 'healthy',
          notes: data.notes ?? null,
          image_url: data.imageUrl ?? null,
          added_at: now,
          created_at: now,
        },
      },
      201
    );
  } catch (error) {
    console.error('Create livestock error:', error);
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

/**
 * Handle listing tank livestock
 * GET /tanks/:tankId/livestock (authenticated)
 */
async function handleListLivestock(
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

    // Get all non-deleted livestock for this tank
    const result = await env.DB.prepare(
      `SELECT * FROM livestock WHERE tank_id = ? AND deleted_at IS NULL ORDER BY added_at DESC`
    )
      .bind(tankId)
      .all();

    const livestock = result.results as LivestockRecord[];

    return jsonResponse({
      success: true,
      tank_id: tankId,
      tank_name: tankResult.name,
      count: livestock.length,
      livestock: livestock.map((item) => ({
        id: item.id,
        tank_id: item.tank_id,
        name: item.name,
        species: item.species,
        category: item.category,
        quantity: item.quantity,
        purchase_date: item.purchase_date,
        purchase_price: item.purchase_price,
        health_status: item.health_status,
        notes: item.notes,
        image_url: item.image_url,
        added_at: item.added_at,
        created_at: item.created_at,
      })),
    });
  } catch (error) {
    console.error('List livestock error:', error);
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

/**
 * Handle updating livestock details
 * PUT /livestock/:id (authenticated)
 */
async function handleUpdateLivestock(
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

    const body = await request.json();

    const validationResult = LivestockUpdateSchema.safeParse(body);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          details: validationResult.error.flatten(),
        },
        400
      );
    }

    const data = validationResult.data;

    // Build dynamic update query
    const updates: string[] = [];
    const values: (string | number | null)[] = [];

    if (data.name !== undefined) {
      updates.push('name = ?');
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

    values.push(livestockId);

    await env.DB.prepare(`UPDATE livestock SET ${updates.join(', ')} WHERE id = ?`)
      .bind(...values)
      .run();

    // Fetch updated record
    const updated = (await env.DB.prepare('SELECT * FROM livestock WHERE id = ?')
      .bind(livestockId)
      .first()) as LivestockRecord;

    return jsonResponse({
      success: true,
      livestock: {
        id: updated.id,
        tank_id: updated.tank_id,
        name: updated.name,
        species: updated.species,
        category: updated.category,
        quantity: updated.quantity,
        purchase_date: updated.purchase_date,
        purchase_price: updated.purchase_price,
        health_status: updated.health_status,
        notes: updated.notes,
        image_url: updated.image_url,
        added_at: updated.added_at,
        created_at: updated.created_at,
      },
    });
  } catch (error) {
    console.error('Update livestock error:', error);
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

/**
 * Handle soft-deleting livestock
 * DELETE /livestock/:id (authenticated)
 */
async function handleDeleteLivestock(
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

    // Soft delete the livestock
    const now = new Date().toISOString();
    await env.DB.prepare('UPDATE livestock SET deleted_at = ? WHERE id = ?')
      .bind(now, livestockId)
      .run();

    return jsonResponse({
      success: true,
      message: 'Livestock deleted successfully',
      livestock_id: livestockId,
      deleted_at: now,
    });
  } catch (error) {
    console.error('Delete livestock error:', error);
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

/**
 * Handle creating a livestock log entry
 * POST /livestock/:id/logs (authenticated)
 */
async function handleCreateLivestockLog(
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

    const body = await request.json();

    const validationResult = LivestockLogSchema.safeParse(body);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          details: validationResult.error.flatten(),
        },
        400
      );
    }

    const data = validationResult.data;

    // Create log entry
    const logId = generateUUID();
    const loggedAt = data.loggedAt || new Date().toISOString();
    const now = new Date().toISOString();

    await env.DB.prepare(
      `INSERT INTO livestock_logs (id, livestock_id, log_type, description, logged_at, created_at)
       VALUES (?, ?, ?, ?, ?, ?)`
    )
      .bind(logId, livestockId, data.logType, data.description ?? null, loggedAt, now)
      .run();

    // If log type is 'death', update livestock health_status to 'deceased'
    if (data.logType === 'death') {
      await env.DB.prepare('UPDATE livestock SET health_status = ? WHERE id = ?')
        .bind('deceased', livestockId)
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
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

/**
 * Handle getting livestock logs
 * GET /livestock/:id/logs (authenticated)
 */
async function handleGetLivestockLogs(
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

    // Get all logs for this livestock
    const result = await env.DB.prepare(
      `SELECT * FROM livestock_logs WHERE livestock_id = ? ORDER BY logged_at DESC`
    )
      .bind(livestockId)
      .all();

    const logs = result.results as LivestockLogRecord[];

    return jsonResponse({
      success: true,
      livestock_id: livestockId,
      livestock_name: livestockResult.name,
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
    return errorResponse(
      'Internal server error',
      error instanceof Error ? error.message : 'Unknown error',
      500
    );
  }
}

// =============================================================================
// MAIN WORKER EXPORT (ES MODULES FORMAT)
// =============================================================================

export default {
  async fetch(request: Request, env: Env, _ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    const { pathname } = url;
    const method = request.method;

    // CORS headers for all responses
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    // Handle CORS preflight
    if (method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    let response: Response;

    switch (true) {
      // Root endpoint
      case pathname === '/' && method === 'GET':
        response = jsonResponse({
          service: 'ReefBuddy API',
          version: '1.0.0',
          description: 'Water chemistry analysis for saltwater aquariums',
          endpoints: {
            'GET /': 'This information',
            'GET /health': 'Health check',
            'POST /auth/signup': 'Create a new user account',
            'POST /auth/login': 'Login and get session token',
            'POST /auth/logout': 'Logout and invalidate session (requires auth)',
            'GET /api/tanks': 'List all tanks (requires auth)',
            'POST /api/tanks': 'Create a new tank (requires auth)',
            'GET /api/tanks/:id': 'Get a specific tank (requires auth)',
            'PUT /api/tanks/:id': 'Update a tank (requires auth)',
            'DELETE /api/tanks/:id': 'Delete a tank (requires auth)',
            'POST /measurements': 'Record water measurements (requires auth)',
            'POST /analyze': 'Analyze water parameters and get dosing recommendations',
            'POST /subscriptions/create': 'Create Stripe checkout session (requires auth)',
            'POST /subscriptions/webhook': 'Handle Stripe webhooks (public)',
            'GET /subscriptions/status': 'Get subscription status (requires auth)',
            'POST /subscriptions/cancel': 'Cancel subscription (requires auth)',
            'GET /tanks/:tankId/history': 'Get historical measurements (requires auth)',
            'GET /tanks/:tankId/trends': 'Get parameter trends over time (requires auth)',
            'GET /tanks/:tankId/averages': 'Get daily/weekly averages (requires auth)',
            'GET /tanks/:tankId/export': 'Export measurements to CSV (premium only)',
            'POST /tanks/:tankId/livestock': 'Add new livestock to tank (requires auth)',
            'GET /tanks/:tankId/livestock': 'List tank livestock (requires auth)',
            'PUT /livestock/:id': 'Update livestock details (requires auth)',
            'DELETE /livestock/:id': 'Soft delete livestock (requires auth)',
            'POST /livestock/:id/logs': 'Add health log entry (requires auth)',
            'GET /livestock/:id/logs': 'Get livestock health logs (requires auth)',
            'POST /notifications/token': 'Register push notification token (requires auth)',
            'DELETE /notifications/token': 'Unregister push notification token (requires auth)',
            'GET /notifications/settings': 'Get alert notification settings (requires auth)',
            'PUT /notifications/settings': 'Update alert notification settings (requires auth)',
            'GET /notifications/history': 'Get notification history (requires auth)',
            'POST /notifications/read': 'Mark notifications as read (requires auth)',
          },
        });
        break;

      // Health check
      case pathname === '/health' && method === 'GET':
        response = handleHealth(env);
        break;

      // Auth endpoints (public)
      case pathname === '/auth/signup' && method === 'POST':
        response = await handleSignup(request, env);
        break;

      case pathname === '/auth/login' && method === 'POST':
        response = await handleLogin(request, env);
        break;

      // Auth endpoints (requires authentication)
      case pathname === '/auth/logout' && method === 'POST': {
        response = await handleLogout(request, env);
        break;
      }

      // Tank CRUD endpoints (requires authentication)
      // GET /api/tanks - List all tanks
      case pathname === '/api/tanks' && method === 'GET': {
        const authResult = await authenticateRequest(request, env);
        if (authResult instanceof Response) {
          response = authResult;
        } else {
          response = await handleListTanks(env, authResult);
        }
        break;
      }

      // POST /api/tanks - Create a new tank
      case pathname === '/api/tanks' && method === 'POST': {
        const authResult = await authenticateRequest(request, env);
        if (authResult instanceof Response) {
          response = authResult;
        } else {
          response = await handleCreateTank(request, env, authResult);
        }
        break;
      }

      // GET /api/tanks/:id - Get a specific tank
      case pathname.match(/^\/api\/tanks\/([a-f0-9-]+)$/) !== null && method === 'GET': {
        const match = pathname.match(/^\/api\/tanks\/([a-f0-9-]+)$/);
        const tankId = match![1];
        const authResult = await authenticateRequest(request, env);
        if (authResult instanceof Response) {
          response = authResult;
        } else {
          response = await handleGetTank(env, authResult, tankId);
        }
        break;
      }

      // PUT /api/tanks/:id - Update a tank
      case pathname.match(/^\/api\/tanks\/([a-f0-9-]+)$/) !== null && method === 'PUT': {
        const match = pathname.match(/^\/api\/tanks\/([a-f0-9-]+)$/);
        const tankId = match![1];
        const authResult = await authenticateRequest(request, env);
        if (authResult instanceof Response) {
          response = authResult;
        } else {
          response = await handleUpdateTank(request, env, authResult, tankId);
        }
        break;
      }

      // DELETE /api/tanks/:id - Delete a tank
      case pathname.match(/^\/api\/tanks\/([a-f0-9-]+)$/) !== null && method === 'DELETE': {
        const match = pathname.match(/^\/api\/tanks\/([a-f0-9-]+)$/);
        const tankId = match![1];
        const authResult = await authenticateRequest(request, env);
        if (authResult instanceof Response) {
          response = authResult;
        } else {
          response = await handleDeleteTank(env, authResult, tankId);
        }
        break;
      }

      // Measurements endpoint (requires authentication)
      case pathname === '/measurements' && method === 'POST': {
        const authResult = await authenticateRequest(request, env);
        if (authResult instanceof Response) {
          response = authResult;
        } else {
          response = await handleCreateMeasurement(request, env, authResult);
        }
        break;
      }

      // Analysis endpoint (public, rate-limited)
      case pathname === '/analyze' && method === 'POST':
        response = await handleAnalysis(request, env);
        break;

      // Subscription endpoints
      case pathname === '/subscriptions/create' && method === 'POST': {
        const authResult = await authenticateRequest(request, env);
        if (authResult instanceof Response) {
          response = authResult;
        } else {
          response = await handleSubscriptionCreate(request, env, authResult);
        }
        break;
      }

      case pathname === '/subscriptions/webhook' && method === 'POST':
        response = await handleSubscriptionWebhook(request, env);
        break;

      case pathname === '/subscriptions/status' && method === 'GET': {
        const authResult = await authenticateRequest(request, env);
        if (authResult instanceof Response) {
          response = authResult;
        } else {
          response = await handleSubscriptionStatus(env, authResult);
        }
        break;
      }

      case pathname === '/subscriptions/cancel' && method === 'POST': {
        const authResult = await authenticateRequest(request, env);
        if (authResult instanceof Response) {
          response = authResult;
        } else {
          response = await handleSubscriptionCancel(request, env, authResult);
        }
        break;
      }

      // Historical data endpoints (requires authentication)
      // Pattern: /tanks/:tankId/history
      case pathname.match(/^\/tanks\/([a-f0-9-]+)\/history$/) !== null && method === 'GET': {
        const match = pathname.match(/^\/tanks\/([a-f0-9-]+)\/history$/);
        const tankId = match![1];
        const authResult = await authenticateRequest(request, env);
        if (authResult instanceof Response) {
          response = authResult;
        } else {
          response = await handleGetHistory(request, env, authResult, tankId);
        }
        break;
      }

      // Pattern: /tanks/:tankId/trends
      case pathname.match(/^\/tanks\/([a-f0-9-]+)\/trends$/) !== null && method === 'GET': {
        const match = pathname.match(/^\/tanks\/([a-f0-9-]+)\/trends$/);
        const tankId = match![1];
        const authResult = await authenticateRequest(request, env);
        if (authResult instanceof Response) {
          response = authResult;
        } else {
          response = await handleGetTrends(request, env, authResult, tankId);
        }
        break;
      }

      // Pattern: /tanks/:tankId/averages
      case pathname.match(/^\/tanks\/([a-f0-9-]+)\/averages$/) !== null && method === 'GET': {
        const match = pathname.match(/^\/tanks\/([a-f0-9-]+)\/averages$/);
        const tankId = match![1];
        const authResult = await authenticateRequest(request, env);
        if (authResult instanceof Response) {
          response = authResult;
        } else {
          response = await handleGetAverages(request, env, authResult, tankId);
        }
        break;
      }

      // Pattern: /tanks/:tankId/export (Premium only)
      case pathname.match(/^\/tanks\/([a-f0-9-]+)\/export$/) !== null && method === 'GET': {
        const match = pathname.match(/^\/tanks\/([a-f0-9-]+)\/export$/);
        const tankId = match![1];
        const authResult = await authenticateRequest(request, env);
        if (authResult instanceof Response) {
          response = authResult;
        } else {
          response = await handleExportCSV(request, env, authResult, tankId);
        }
        break;
      }

      // Livestock endpoints (requires authentication)
      // Pattern: POST /tanks/:tankId/livestock - Create livestock
      case pathname.match(/^\/tanks\/([a-f0-9-]+)\/livestock$/) !== null && method === 'POST': {
        const match = pathname.match(/^\/tanks\/([a-f0-9-]+)\/livestock$/);
        const tankId = match![1];
        const authResult = await authenticateRequest(request, env);
        if (authResult instanceof Response) {
          response = authResult;
        } else {
          response = await handleCreateLivestock(request, env, authResult, tankId);
        }
        break;
      }

      // Pattern: GET /tanks/:tankId/livestock - List livestock
      case pathname.match(/^\/tanks\/([a-f0-9-]+)\/livestock$/) !== null && method === 'GET': {
        const match = pathname.match(/^\/tanks\/([a-f0-9-]+)\/livestock$/);
        const tankId = match![1];
        const authResult = await authenticateRequest(request, env);
        if (authResult instanceof Response) {
          response = authResult;
        } else {
          response = await handleListLivestock(env, authResult, tankId);
        }
        break;
      }

      // Pattern: PUT /livestock/:id - Update livestock
      case pathname.match(/^\/livestock\/([a-f0-9-]+)$/) !== null && method === 'PUT': {
        const match = pathname.match(/^\/livestock\/([a-f0-9-]+)$/);
        const livestockId = match![1];
        const authResult = await authenticateRequest(request, env);
        if (authResult instanceof Response) {
          response = authResult;
        } else {
          response = await handleUpdateLivestock(request, env, authResult, livestockId);
        }
        break;
      }

      // Pattern: DELETE /livestock/:id - Delete livestock
      case pathname.match(/^\/livestock\/([a-f0-9-]+)$/) !== null && method === 'DELETE': {
        const match = pathname.match(/^\/livestock\/([a-f0-9-]+)$/);
        const livestockId = match![1];
        const authResult = await authenticateRequest(request, env);
        if (authResult instanceof Response) {
          response = authResult;
        } else {
          response = await handleDeleteLivestock(env, authResult, livestockId);
        }
        break;
      }

      // Pattern: POST /livestock/:id/logs - Create livestock log
      case pathname.match(/^\/livestock\/([a-f0-9-]+)\/logs$/) !== null && method === 'POST': {
        const match = pathname.match(/^\/livestock\/([a-f0-9-]+)\/logs$/);
        const livestockId = match![1];
        const authResult = await authenticateRequest(request, env);
        if (authResult instanceof Response) {
          response = authResult;
        } else {
          response = await handleCreateLivestockLog(request, env, authResult, livestockId);
        }
        break;
      }

      // Pattern: GET /livestock/:id/logs - Get livestock logs
      case pathname.match(/^\/livestock\/([a-f0-9-]+)\/logs$/) !== null && method === 'GET': {
        const match = pathname.match(/^\/livestock\/([a-f0-9-]+)\/logs$/);
        const livestockId = match![1];
        const authResult = await authenticateRequest(request, env);
        if (authResult instanceof Response) {
          response = authResult;
        } else {
          response = await handleGetLivestockLogs(env, authResult, livestockId);
        }
        break;
      }

      // Notification endpoints (requires authentication)
      // POST /notifications/token - Register push token
      case pathname === '/notifications/token' && method === 'POST': {
        const authResult = await authenticateRequest(request, env);
        if (authResult instanceof Response) {
          response = authResult;
        } else {
          response = await handleRegisterPushToken(request, env, authResult);
        }
        break;
      }

      // DELETE /notifications/token - Unregister push token
      case pathname === '/notifications/token' && method === 'DELETE': {
        const authResult = await authenticateRequest(request, env);
        if (authResult instanceof Response) {
          response = authResult;
        } else {
          response = await handleUnregisterPushToken(request, env, authResult);
        }
        break;
      }

      // GET /notifications/settings - Get notification settings
      case pathname === '/notifications/settings' && method === 'GET': {
        const authResult = await authenticateRequest(request, env);
        if (authResult instanceof Response) {
          response = authResult;
        } else {
          response = await handleGetNotificationSettings(env, authResult);
        }
        break;
      }

      // PUT /notifications/settings - Update notification settings
      case pathname === '/notifications/settings' && method === 'PUT': {
        const authResult = await authenticateRequest(request, env);
        if (authResult instanceof Response) {
          response = authResult;
        } else {
          response = await handleUpdateNotificationSettings(request, env, authResult);
        }
        break;
      }

      // GET /notifications/history - Get notification history
      case pathname === '/notifications/history' && method === 'GET': {
        const authResult = await authenticateRequest(request, env);
        if (authResult instanceof Response) {
          response = authResult;
        } else {
          response = await handleGetNotificationHistory(request, env, authResult);
        }
        break;
      }

      // POST /notifications/read - Mark notifications as read
      case pathname === '/notifications/read' && method === 'POST': {
        const authResult = await authenticateRequest(request, env);
        if (authResult instanceof Response) {
          response = authResult;
        } else {
          response = await handleMarkNotificationsRead(request, env, authResult);
        }
        break;
      }

      // 404 for unknown routes
      default:
        response = errorResponse('Not found', `Route ${method} ${pathname} does not exist`, 404);
    }

    // Add CORS headers to response
    Object.entries(corsHeaders).forEach(([key, value]) => {
      response.headers.set(key, value);
    });

    return response;
  },
} satisfies ExportedHandler<Env>;
