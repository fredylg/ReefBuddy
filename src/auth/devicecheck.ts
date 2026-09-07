import { z } from 'zod';
import { SignJWT, importPKCS8 } from 'jose';
import { AI_SYSTEM_PROMPT, extractAnthropicAssistantText } from '../ai/gateway';
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
    body: JSON.stringify({ device_token: deviceToken, timestamp: Date.now(), transaction_id: crypto.randomUUID(), ...extra }),
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

export function deviceCheckFailure(status: number, text: string, json: Record<string, unknown> | null): DeviceCheckResult {
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
      const update = await deviceCheckRequest(env, isDevelopment, 'update_two_bits', deviceToken, { bit0: false, bit1: true });
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
export async function markDeviceFreeTierConsumed(env: Env, deviceToken: string, isDevelopment: boolean): Promise<boolean> {
  try {
    const update = await deviceCheckRequest(env, isDevelopment, 'update_two_bits', deviceToken, { bit0: true, bit1: true });
    if (update.status !== 200) console.warn('DeviceCheck: could not set free-tier bit (' + update.status + ')');
    return update.status === 200;
  } catch (error) {
    console.warn('DeviceCheck: could not set free-tier bit:', error);
    return false;
  }
}

/** Outcome of an AI Gateway call. Errors never travel on the same channel as model text. */
export type AIGatewayResult =
  | { ok: true; text: string; stopReason: string | null; usage: { input: number; output: number } | null }
  | { ok: false; kind: 'not_configured' | 'upstream' | 'bad_shape' | 'network'; status: number; retryable: boolean; message: string };

/** Default model and output budget; overridable per environment via AI_MODEL / AI_MAX_TOKENS (P3-21). */
export const DEFAULT_AI_MODEL = 'claude-haiku-4-5';
export const DEFAULT_AI_MAX_TOKENS = 2048;
/** Extra tokens granted on one retry when the first reply was cut off by max_tokens (P3-22). */
export const AI_TRUNCATION_RETRY_EXTRA_TOKENS = 1024;

/**
 * JSON schema for the analysis reply (structured output). Mirrors the iOS AnalysisContent model, so
 * every client receives one fixed shape. All objects must set additionalProperties:false.
 */
export const ANALYSIS_OUTPUT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['summary', 'recommendations', 'warnings', 'dosingAdvice'],
  properties: {
    summary: { type: 'string', description: 'Two to four plain sentences assessing the readings overall' },
    recommendations: { type: 'array', items: { type: 'string' }, description: 'Specific next steps, one per item' },
    warnings: { type: 'array', items: { type: 'string' }, description: 'Urgent risks only; empty when none' },
    dosingAdvice: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['product', 'amount', 'frequency', 'reason'],
        properties: {
          product: { type: 'string', description: 'Product type, e.g. two-part alkalinity supplement' },
          amount: { type: 'string', description: 'Amount scaled to the stated tank volume' },
          frequency: { type: 'string' },
          reason: { type: 'string' },
        },
      },
      description: 'Empty when nothing should be dosed',
    },
  },
} as const;

export const AnalysisOutputSchema = z.object({
  summary: z.string(),
  recommendations: z.array(z.string()),
  warnings: z.array(z.string()),
  dosingAdvice: z.array(z.object({ product: z.string(), amount: z.string(), frequency: z.string(), reason: z.string() })),
});
export type AnalysisOutput = z.infer<typeof AnalysisOutputSchema>;

export function aiModel(env: Env): string {
  return env.AI_MODEL || DEFAULT_AI_MODEL;
}
export function aiMaxTokens(env: Env): number {
  const n = parseInt(env.AI_MAX_TOKENS || '', 10);
  return Number.isFinite(n) && n > 0 ? n : DEFAULT_AI_MAX_TOKENS;
}

/**
 * Call the model through Cloudflare AI Gateway.
 * Retries live in the gateway (cf-aig-* headers); this function makes one attempt, plus one more
 * when Anthropic answers 429 with a short Retry-After or the network drops (P3-24).
 */
export async function callAIGateway(env: Env, prompt: string, options: { maxTokens?: number } = {}): Promise<AIGatewayResult> {
  if (!env.ANTHROPIC_API_KEY || !env.CF_ACCOUNT_ID) {
    console.error('AI Gateway not configured: ANTHROPIC_API_KEY and CF_ACCOUNT_ID are required');
    return { ok: false, kind: 'not_configured', status: 503, retryable: false, message: 'AI analysis is not configured on this server.' };
  }

  const gatewayUrl = 'https://gateway.ai.cloudflare.com/v1/' + env.CF_ACCOUNT_ID + '/' + env.AI_GATEWAY_ID + '/anthropic/v1/messages';
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    'x-api-key': env.ANTHROPIC_API_KEY,
    'anthropic-version': '2023-06-01',
    'cf-aig-max-attempts': '3',
    'cf-aig-retry-delay': '1000',
    'cf-aig-backoff': 'exponential',
  };
  if (env.CF_AI_GATEWAY_TOKEN) headers['cf-aig-authorization'] = 'Bearer ' + env.CF_AI_GATEWAY_TOKEN;

  const body = JSON.stringify({
    model: aiModel(env),
    max_tokens: options.maxTokens ?? aiMaxTokens(env),
    system: AI_SYSTEM_PROMPT,
    messages: [{ role: 'user', content: prompt }],
    output_config: { format: { type: 'json_schema', schema: ANALYSIS_OUTPUT_SCHEMA } },
  });

  const attempt = async (): Promise<Response> => fetch(gatewayUrl, { method: 'POST', headers, body, signal: AbortSignal.timeout(25_000) });

  let response: Response;
  try {
    response = await attempt();
    if (response.status === 429) {
      const retryAfter = Number(response.headers.get('retry-after') || '0');
      if (retryAfter > 0 && retryAfter <= 5) {
        await new Promise((resolve) => setTimeout(resolve, retryAfter * 1000));
        response = await attempt();
      }
    }
  } catch (firstError) {
    console.warn('AI Gateway network error, retrying once:', firstError);
    try {
      response = await attempt();
    } catch (error) {
      console.error('AI Gateway fetch error:', error);
      return { ok: false, kind: 'network', status: 502, retryable: true, message: 'Could not reach the AI service. Please try again.' };
    }
  }

  if (!response.ok) {
    const statusCode = response.status;
    const errorText = (await response.text()).slice(0, 500);
    console.error('AI Gateway error ' + statusCode + ': ' + errorText);
    const retryable = statusCode === 529 || statusCode === 503 || statusCode === 429;
    return {
      ok: false,
      kind: 'upstream',
      status: statusCode,
      retryable,
      message: retryable
        ? 'The AI service is temporarily unavailable. Please try again in a moment.'
        : 'The AI service could not process this analysis.',
    };
  }

  const data = (await response.json()) as { stop_reason?: string | null; usage?: { input_tokens?: number; output_tokens?: number } };
  const text = extractAnthropicAssistantText(data);
  if (text == null && data?.stop_reason !== 'refusal') {
    console.error('AI Gateway returned 200 but no assistant text. stop_reason=' + (data?.stop_reason ?? 'n/a'));
    return { ok: false, kind: 'bad_shape', status: 502, retryable: true, message: 'The AI service returned an unexpected response.' };
  }
  return {
    ok: true,
    text: text ?? '',
    stopReason: data?.stop_reason ?? null,
    usage: data?.usage ? { input: data.usage.input_tokens ?? 0, output: data.usage.output_tokens ?? 0 } : null,
  };
}

/** Parse the model's structured reply; null when it does not match the schema (legacy/prose path). */
export function parseStructuredAnalysis(text: string): AnalysisOutput | null {
  try {
    const parsed = AnalysisOutputSchema.safeParse(JSON.parse(text));
    return parsed.success ? parsed.data : null;
  } catch {
    return null;
  }
}

/** Plain-text rendering of a structured analysis for clients that only read `recommendation`. */
export function renderAnalysisText(a: AnalysisOutput): string {
  const lines: string[] = [a.summary.trim()];
  if (a.warnings.length) lines.push('', 'Warnings:', ...a.warnings.map((w) => '- ' + w));
  if (a.recommendations.length) lines.push('', 'Recommendations:', ...a.recommendations.map((r) => '- ' + r));
  if (a.dosingAdvice.length) lines.push('', 'Dosing:', ...a.dosingAdvice.map((d) => '- ' + d.product + ': ' + d.amount + ', ' + d.frequency + ' (' + d.reason + ')'));
  return lines.join('\n');
}
