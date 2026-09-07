import { z } from 'zod';
import bcrypt from 'bcryptjs';
import { createSession, extractSessionToken, invalidateSession } from '../auth/session';
import { BCRYPT_SALT_ROUNDS, Env, SESSION_EXPIRY_SECONDS } from '../env';
import { errorResponse, generateUUID, internalError, jsonResponse, readJson } from '../http';
import { LoginRequestSchema, SignupRequestSchema } from '../schemas';

// =============================================================================
// AUTH HANDLERS
// =============================================================================

/**
 * Handle user signup
 * POST /auth/signup
 */
export async function handleSignup(request: Request, env: Env): Promise<Response> {
  try {
    const parsedBody = await readJson(request);
    if (!parsedBody.ok) return parsedBody.response;
    const body = parsedBody.body;

    const validationResult = SignupRequestSchema.safeParse(body);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          details: z.flattenError(validationResult.error),
        },
        400
      );
    }

    const { email, password } = validationResult.data;

    // Device users are modelled as device_<id>@reefbuddy.device; nobody may register that domain (B-08).
    if (email.toLowerCase().endsWith('@reefbuddy.device')) {
      return errorResponse('Validation failed', 'This email domain cannot be used', 400);
    }

    // Check if user already exists
    const existingUser = await env.DB.prepare('SELECT id FROM users WHERE email = ?').bind(email.toLowerCase()).first();

    if (existingUser) {
      return errorResponse('Conflict', 'A user with this email already exists', 409);
    }

    // Hash password with bcrypt
    const passwordHash = await bcrypt.hash(password, BCRYPT_SALT_ROUNDS);

    // Create user
    const userId = generateUUID();
    try {
      await env.DB.prepare('INSERT INTO users (id, email, password_hash, subscription_tier) VALUES (?, ?, ?, ?)')
        .bind(userId, email.toLowerCase(), passwordHash, 'free')
        .run();
    } catch (insertError) {
      // Two concurrent signups for the same email: the UNIQUE constraint decides, not a 500.
      if (insertError instanceof Error && /UNIQUE constraint failed/i.test(insertError.message)) {
        return errorResponse('Conflict', 'A user with this email already exists', 409);
      }
      throw insertError;
    }

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
    return internalError('Unhandled error', error);
  }
}

/**
 * Handle user login
 * POST /auth/login
 */
export async function handleLogin(request: Request, env: Env): Promise<Response> {
  try {
    const parsedBody = await readJson(request);
    if (!parsedBody.ok) return parsedBody.response;
    const body = parsedBody.body;

    const validationResult = LoginRequestSchema.safeParse(body);
    if (!validationResult.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          details: z.flattenError(validationResult.error),
        },
        400
      );
    }

    const { email, password } = validationResult.data;

    // Find user by email
    const user = (await env.DB.prepare('SELECT id, email, password_hash, subscription_tier FROM users WHERE email = ?')
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
    return internalError('Unhandled error', error);
  }
}

/**
 * Handle user logout
 * POST /auth/logout
 */
export async function handleLogout(request: Request, env: Env): Promise<Response> {
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
    return internalError('Unhandled error', error);
  }
}
