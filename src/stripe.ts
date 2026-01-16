/**
 * ReefBuddy - Stripe Integration
 * Subscription management using Stripe API (fetch-based for Workers compatibility)
 *
 * @edge-engineer owns this file
 */

import { z } from 'zod';

// =============================================================================
// TYPE DEFINITIONS
// =============================================================================

/**
 * Stripe environment variables
 */
export interface StripeEnv {
  STRIPE_SECRET_KEY: string;
  STRIPE_WEBHOOK_SECRET: string;
  STRIPE_PRICE_ID: string;
}

/**
 * Checkout session creation result
 */
export interface CheckoutSessionResult {
  success: boolean;
  sessionId?: string;
  url?: string;
  error?: string;
}

/**
 * Webhook processing result
 */
export interface WebhookResult {
  success: boolean;
  eventType?: string;
  userId?: string;
  subscriptionId?: string;
  error?: string;
}

/**
 * Subscription cancellation result
 */
export interface CancelSubscriptionResult {
  success: boolean;
  subscriptionId?: string;
  error?: string;
}

/**
 * Subscription status result
 */
export interface SubscriptionStatusResult {
  success: boolean;
  status?: 'active' | 'canceled' | 'past_due' | 'none';
  subscriptionId?: string;
  currentPeriodEnd?: string;
  cancelAtPeriodEnd?: boolean;
  error?: string;
}

// =============================================================================
// STRIPE API CONSTANTS
// =============================================================================

const STRIPE_API_BASE = 'https://api.stripe.com/v1';
const STRIPE_API_VERSION = '2023-10-16';

// =============================================================================
// ZOD SCHEMAS FOR STRIPE WEBHOOK EVENTS
// =============================================================================

/**
 * Stripe checkout.session.completed event data
 */
const CheckoutSessionCompletedSchema = z.object({
  id: z.string(),
  object: z.literal('checkout.session'),
  customer: z.string().nullable(),
  subscription: z.string().nullable(),
  client_reference_id: z.string().nullable(),
  metadata: z.record(z.string(), z.string()).optional(),
});

/**
 * Stripe customer.subscription.deleted event data
 */
const SubscriptionDeletedSchema = z.object({
  id: z.string(),
  object: z.literal('subscription'),
  customer: z.string(),
  metadata: z.record(z.string(), z.string()).optional(),
});

/**
 * Stripe webhook event wrapper
 */
const StripeEventSchema = z.object({
  id: z.string(),
  type: z.string(),
  data: z.object({
    object: z.unknown(),
  }),
});

export type StripeEvent = z.infer<typeof StripeEventSchema>;

// =============================================================================
// STRIPE API UTILITIES
// =============================================================================

/**
 * Create authorization header for Stripe API
 */
function getStripeAuthHeader(secretKey: string): string {
  return `Basic ${btoa(`${secretKey}:`)}`;
}

/**
 * Make a request to Stripe API
 */
async function stripeRequest<T>(
  secretKey: string,
  endpoint: string,
  method: 'GET' | 'POST' | 'DELETE' = 'GET',
  body?: URLSearchParams
): Promise<T> {
  const response = await fetch(`${STRIPE_API_BASE}${endpoint}`, {
    method,
    headers: {
      Authorization: getStripeAuthHeader(secretKey),
      'Content-Type': 'application/x-www-form-urlencoded',
      'Stripe-Version': STRIPE_API_VERSION,
    },
    body: body?.toString(),
  });

  const data = await response.json();

  if (!response.ok) {
    const error = data as { error?: { message?: string } };
    throw new Error(error.error?.message || `Stripe API error: ${response.status}`);
  }

  return data as T;
}

// =============================================================================
// STRIPE WEBHOOK SIGNATURE VERIFICATION
// =============================================================================

/**
 * Compute HMAC-SHA256 signature for webhook verification
 */
async function computeHmacSha256(secret: string, payload: string): Promise<string> {
  const encoder = new TextEncoder();
  const keyData = encoder.encode(secret);
  const payloadData = encoder.encode(payload);

  const key = await crypto.subtle.importKey(
    'raw',
    keyData,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );

  const signature = await crypto.subtle.sign('HMAC', key, payloadData);
  return Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

/**
 * Parse Stripe webhook signature header
 */
function parseSignatureHeader(header: string): { timestamp: string; signatures: string[] } {
  const parts = header.split(',');
  let timestamp = '';
  const signatures: string[] = [];

  for (const part of parts) {
    const [key, value] = part.split('=');
    if (key === 't') {
      timestamp = value;
    } else if (key === 'v1') {
      signatures.push(value);
    }
  }

  return { timestamp, signatures };
}

/**
 * Verify Stripe webhook signature
 */
export async function verifyWebhookSignature(
  payload: string,
  signatureHeader: string,
  webhookSecret: string,
  tolerance = 300 // 5 minutes
): Promise<boolean> {
  const { timestamp, signatures } = parseSignatureHeader(signatureHeader);

  if (!timestamp || signatures.length === 0) {
    return false;
  }

  // Check timestamp tolerance
  const timestampAge = Math.floor(Date.now() / 1000) - parseInt(timestamp, 10);
  if (timestampAge > tolerance) {
    return false;
  }

  // Compute expected signature
  const signedPayload = `${timestamp}.${payload}`;
  const expectedSignature = await computeHmacSha256(webhookSecret, signedPayload);

  // Compare signatures (timing-safe comparison)
  return signatures.some((sig) => timingSafeEqual(sig, expectedSignature));
}

/**
 * Timing-safe string comparison to prevent timing attacks
 */
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) {
    return false;
  }

  let result = 0;
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }

  return result === 0;
}

// =============================================================================
// STRIPE API FUNCTIONS
// =============================================================================

/**
 * Create a Stripe Checkout Session for subscription
 * @param env - Stripe environment variables
 * @param userId - ReefBuddy user ID (stored in client_reference_id)
 * @param userEmail - User's email for Stripe prefill
 * @param successUrl - URL to redirect on successful payment
 * @param cancelUrl - URL to redirect on cancelled payment
 */
export async function createCheckoutSession(
  env: StripeEnv,
  userId: string,
  userEmail: string,
  successUrl: string,
  cancelUrl: string
): Promise<CheckoutSessionResult> {
  if (!env.STRIPE_SECRET_KEY || !env.STRIPE_PRICE_ID) {
    return {
      success: false,
      error: 'Stripe not configured. Set STRIPE_SECRET_KEY and STRIPE_PRICE_ID.',
    };
  }

  try {
    const body = new URLSearchParams({
      mode: 'subscription',
      'line_items[0][price]': env.STRIPE_PRICE_ID,
      'line_items[0][quantity]': '1',
      success_url: successUrl,
      cancel_url: cancelUrl,
      client_reference_id: userId,
      customer_email: userEmail,
      'subscription_data[metadata][user_id]': userId,
      'metadata[user_id]': userId,
    });

    interface CheckoutSession {
      id: string;
      url: string;
    }

    const session = await stripeRequest<CheckoutSession>(
      env.STRIPE_SECRET_KEY,
      '/checkout/sessions',
      'POST',
      body
    );

    return {
      success: true,
      sessionId: session.id,
      url: session.url,
    };
  } catch (error) {
    console.error('Stripe createCheckoutSession error:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create checkout session',
    };
  }
}

/**
 * Handle Stripe webhook event
 * @param env - Stripe environment variables
 * @param payload - Raw webhook payload
 * @param signatureHeader - Stripe-Signature header value
 */
export async function handleWebhook(
  env: StripeEnv,
  payload: string,
  signatureHeader: string
): Promise<WebhookResult> {
  if (!env.STRIPE_WEBHOOK_SECRET) {
    return {
      success: false,
      error: 'Stripe webhook secret not configured.',
    };
  }

  // Verify webhook signature
  const isValid = await verifyWebhookSignature(payload, signatureHeader, env.STRIPE_WEBHOOK_SECRET);

  if (!isValid) {
    return {
      success: false,
      error: 'Invalid webhook signature.',
    };
  }

  // Parse event
  let event: StripeEvent;
  try {
    const parsed = JSON.parse(payload);
    const validationResult = StripeEventSchema.safeParse(parsed);
    if (!validationResult.success) {
      return {
        success: false,
        error: 'Invalid webhook event format.',
      };
    }
    event = validationResult.data;
  } catch {
    return {
      success: false,
      error: 'Failed to parse webhook payload.',
    };
  }

  // Handle specific event types
  switch (event.type) {
    case 'checkout.session.completed': {
      const sessionResult = CheckoutSessionCompletedSchema.safeParse(event.data.object);
      if (!sessionResult.success) {
        return {
          success: false,
          error: 'Invalid checkout.session.completed event data.',
        };
      }

      const session = sessionResult.data;
      const userId = session.client_reference_id || session.metadata?.user_id;

      if (!userId) {
        return {
          success: false,
          error: 'No user ID found in checkout session.',
        };
      }

      return {
        success: true,
        eventType: 'checkout.session.completed',
        userId: userId,
        subscriptionId: session.subscription ?? undefined,
      };
    }

    case 'customer.subscription.deleted': {
      const subscriptionResult = SubscriptionDeletedSchema.safeParse(event.data.object);
      if (!subscriptionResult.success) {
        return {
          success: false,
          error: 'Invalid customer.subscription.deleted event data.',
        };
      }

      const subscription = subscriptionResult.data;
      const deletedUserId: string | undefined = subscription.metadata?.user_id;

      return {
        success: true,
        eventType: 'customer.subscription.deleted',
        userId: deletedUserId,
        subscriptionId: subscription.id,
      };
    }

    case 'invoice.payment_failed': {
      // Handle payment failure - could trigger email notification
      return {
        success: true,
        eventType: 'invoice.payment_failed',
      };
    }

    case 'customer.subscription.updated': {
      // Handle subscription updates (e.g., plan changes)
      return {
        success: true,
        eventType: 'customer.subscription.updated',
      };
    }

    default:
      // Acknowledge unknown events without error
      return {
        success: true,
        eventType: event.type,
      };
  }
}

/**
 * Cancel a Stripe subscription
 * @param env - Stripe environment variables
 * @param subscriptionId - Stripe subscription ID to cancel
 * @param cancelAtPeriodEnd - If true, cancel at end of billing period
 */
export async function cancelSubscription(
  env: StripeEnv,
  subscriptionId: string,
  cancelAtPeriodEnd = true
): Promise<CancelSubscriptionResult> {
  if (!env.STRIPE_SECRET_KEY) {
    return {
      success: false,
      error: 'Stripe not configured.',
    };
  }

  try {
    if (cancelAtPeriodEnd) {
      // Cancel at period end (user keeps access until then)
      const body = new URLSearchParams({
        cancel_at_period_end: 'true',
      });

      interface Subscription {
        id: string;
      }

      await stripeRequest<Subscription>(
        env.STRIPE_SECRET_KEY,
        `/subscriptions/${subscriptionId}`,
        'POST',
        body
      );
    } else {
      // Cancel immediately
      interface Subscription {
        id: string;
      }

      await stripeRequest<Subscription>(
        env.STRIPE_SECRET_KEY,
        `/subscriptions/${subscriptionId}`,
        'DELETE'
      );
    }

    return {
      success: true,
      subscriptionId,
    };
  } catch (error) {
    console.error('Stripe cancelSubscription error:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to cancel subscription',
    };
  }
}

/**
 * Get subscription status from Stripe
 * @param env - Stripe environment variables
 * @param customerId - Stripe customer ID
 */
export async function getSubscriptionStatus(
  env: StripeEnv,
  customerId: string
): Promise<SubscriptionStatusResult> {
  if (!env.STRIPE_SECRET_KEY) {
    return {
      success: false,
      error: 'Stripe not configured.',
    };
  }

  try {
    interface SubscriptionList {
      data: Array<{
        id: string;
        status: string;
        current_period_end: number;
        cancel_at_period_end: boolean;
      }>;
    }

    const subscriptions = await stripeRequest<SubscriptionList>(
      env.STRIPE_SECRET_KEY,
      `/subscriptions?customer=${customerId}&status=all&limit=1`
    );

    if (subscriptions.data.length === 0) {
      return {
        success: true,
        status: 'none',
      };
    }

    const subscription = subscriptions.data[0];
    const status = subscription.status as 'active' | 'canceled' | 'past_due';

    return {
      success: true,
      status,
      subscriptionId: subscription.id,
      currentPeriodEnd: new Date(subscription.current_period_end * 1000).toISOString(),
      cancelAtPeriodEnd: subscription.cancel_at_period_end,
    };
  } catch (error) {
    console.error('Stripe getSubscriptionStatus error:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to get subscription status',
    };
  }
}

/**
 * Create or retrieve a Stripe customer
 * @param env - Stripe environment variables
 * @param email - Customer email
 * @param userId - ReefBuddy user ID
 */
export async function createOrGetCustomer(
  env: StripeEnv,
  email: string,
  userId: string
): Promise<{ success: boolean; customerId?: string; error?: string }> {
  if (!env.STRIPE_SECRET_KEY) {
    return {
      success: false,
      error: 'Stripe not configured.',
    };
  }

  try {
    // Search for existing customer by email
    interface CustomerList {
      data: Array<{ id: string }>;
    }

    const existingCustomers = await stripeRequest<CustomerList>(
      env.STRIPE_SECRET_KEY,
      `/customers?email=${encodeURIComponent(email)}&limit=1`
    );

    if (existingCustomers.data.length > 0) {
      return {
        success: true,
        customerId: existingCustomers.data[0].id,
      };
    }

    // Create new customer
    const body = new URLSearchParams({
      email,
      'metadata[user_id]': userId,
    });

    interface Customer {
      id: string;
    }

    const customer = await stripeRequest<Customer>(
      env.STRIPE_SECRET_KEY,
      '/customers',
      'POST',
      body
    );

    return {
      success: true,
      customerId: customer.id,
    };
  } catch (error) {
    console.error('Stripe createOrGetCustomer error:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create customer',
    };
  }
}
