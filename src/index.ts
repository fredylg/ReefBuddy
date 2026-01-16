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
 */
const WaterParametersSchema = z.object({
  salinity: z.number().min(1.020).max(1.030).describe('Specific gravity (1.020-1.030)'),
  temperature: z.number().min(72).max(84).describe('Temperature in Fahrenheit'),
  ph: z.number().min(7.8).max(8.6).describe('pH level'),
  alkalinity: z.number().min(6).max(12).describe('Alkalinity in dKH'),
  calcium: z.number().min(350).max(500).describe('Calcium in ppm'),
  magnesium: z.number().min(1200).max(1500).describe('Magnesium in ppm'),
  nitrate: z.number().min(0).max(50).optional().describe('Nitrate in ppm'),
  phosphate: z.number().min(0).max(0.5).optional().describe('Phosphate in ppm'),
  ammonia: z.number().min(0).max(1).optional().describe('Ammonia in ppm'),
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
  tankId: z.string().uuid(),
  ph: z.number().min(0).max(14).optional(),
  alkalinity: z.number().min(0).optional(),
  calcium: z.number().min(0).optional(),
  magnesium: z.number().min(0).optional(),
  nitrate: z.number().min(0).optional(),
  phosphate: z.number().min(0).optional(),
  salinity: z.number().min(0).optional(),
  temperature: z.number().min(0).optional(),
  ammonia: z.number().min(0).optional(),
  measuredAt: z.string().datetime().optional(),
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

// Export schemas for external use
export type WaterParameters = z.infer<typeof WaterParametersSchema>;
export type AnalysisRequest = z.infer<typeof AnalysisRequestSchema>;
export type SignupRequest = z.infer<typeof SignupRequestSchema>;
export type LoginRequest = z.infer<typeof LoginRequestSchema>;
export type CreateMeasurement = z.infer<typeof CreateMeasurementSchema>;
export type SubscriptionCheckout = z.infer<typeof SubscriptionCheckoutSchema>;
export type SubscriptionCancel = z.infer<typeof SubscriptionCancelSchema>;

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
    const tank = (await env.DB.prepare('SELECT id, user_id FROM tanks WHERE id = ?')
      .bind(data.tankId)
      .first()) as { id: string; user_id: string } | null;

    if (!tank) {
      return errorResponse('Not found', 'Tank not found', 404);
    }

    if (tank.user_id !== auth.userId) {
      return errorResponse('Forbidden', 'You do not have access to this tank', 403);
    }

    // Create measurement
    const measurementId = generateUUID();
    const measuredAt = data.measuredAt || new Date().toISOString();

    await env.DB.prepare(
      `INSERT INTO measurements (id, tank_id, measured_at, ph, alkalinity, calcium, magnesium, nitrate, phosphate, salinity, temperature, ammonia)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    )
      .bind(
        measurementId,
        data.tankId,
        measuredAt,
        data.ph ?? null,
        data.alkalinity ?? null,
        data.calcium ?? null,
        data.magnesium ?? null,
        data.nitrate ?? null,
        data.phosphate ?? null,
        data.salinity ?? null,
        data.temperature ?? null,
        data.ammonia ?? null
      )
      .run();

    return jsonResponse(
      {
        success: true,
        measurement: {
          id: measurementId,
          tank_id: data.tankId,
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
        },
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

    const prompt = `Analyze these saltwater aquarium water parameters and provide dosing recommendations:
Tank Volume: ${tankVolume} gallons
Parameters:
- Salinity: ${parameters.salinity}
- Temperature: ${parameters.temperature}F
- pH: ${parameters.ph}
- Alkalinity: ${parameters.alkalinity} dKH
- Calcium: ${parameters.calcium} ppm
- Magnesium: ${parameters.magnesium} ppm
${parameters.nitrate !== undefined ? `- Nitrate: ${parameters.nitrate} ppm` : ''}
${parameters.phosphate !== undefined ? `- Phosphate: ${parameters.phosphate} ppm` : ''}
${parameters.ammonia !== undefined ? `- Ammonia: ${parameters.ammonia} ppm` : ''}

Provide specific dosing recommendations to bring parameters to optimal reef levels.`;

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
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
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
