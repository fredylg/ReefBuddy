/**
 * ReefBuddy - Cloudflare Worker
 * Backend for saltwater aquarium water chemistry analysis and dosing recommendations
 *
 * @edge-engineer owns this file
 */

import { z } from 'zod';

// =============================================================================
// TYPE DEFINITIONS
// =============================================================================

/**
 * Environment bindings for the Worker
 */
export interface Env {
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

  // AI Gateway configuration
  AI_GATEWAY: {
    gateway_id: string;
  };
}

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

// Export schemas for external use
export type WaterParameters = z.infer<typeof WaterParametersSchema>;
export type AnalysisRequest = z.infer<typeof AnalysisRequestSchema>;

// =============================================================================
// AI GATEWAY INTEGRATION
// =============================================================================

/**
 * AI Gateway routing configuration
 * All LLM calls must route through Cloudflare AI Gateway for caching
 */
interface AIGatewayConfig {
  accountId: string;
  gatewayId: string;
}

/**
 * Call AI Gateway for water chemistry analysis
 * Routes requests through Cloudflare AI Gateway for caching and analytics
 *
 * @param env - Worker environment bindings
 * @param prompt - The prompt to send to the AI model
 * @returns AI-generated response
 */
async function callAIGateway(
  env: Env,
  prompt: string,
  _config?: AIGatewayConfig
): Promise<string> {
  // Check if AI Gateway is configured
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
        model: 'claude-3-haiku-20240307', // Using Haiku for cost efficiency
        max_tokens: 1024,
        messages: [
          {
            role: 'user',
            content: prompt,
          },
        ],
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

    const data = await response.json() as { content: Array<{ text: string }> };
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
// RATE LIMITING (FREE TIER)
// =============================================================================

/**
 * Check and enforce free tier limits using KV
 * Users get 3 analysis requests per month on the free tier
 */
async function checkRateLimit(env: Env, userId: string): Promise<{ allowed: boolean; remaining: number }> {
  const key = `rate:${userId}:${new Date().toISOString().slice(0, 7)}`; // Monthly key
  const limit = parseInt(env.FREE_TIER_LIMIT || '3', 10);

  const currentCount = parseInt(await env.REEF_KV.get(key) || '0', 10);

  if (currentCount >= limit) {
    return { allowed: false, remaining: 0 };
  }

  // Increment count
  await env.REEF_KV.put(key, String(currentCount + 1), {
    expirationTtl: 60 * 60 * 24 * 32, // 32 days TTL
  });

  return { allowed: true, remaining: limit - currentCount - 1 };
}

// =============================================================================
// REQUEST HANDLERS
// =============================================================================

/**
 * Handle water analysis request
 */
async function handleAnalysis(request: Request, env: Env): Promise<Response> {
  try {
    const body = await request.json();

    // Validate request body with Zod
    const validationResult = AnalysisRequestSchema.safeParse(body);

    if (!validationResult.success) {
      return new Response(
        JSON.stringify({
          error: 'Validation failed',
          details: validationResult.error.flatten(),
        }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    const { tankId, parameters, tankVolume } = validationResult.data;

    // Check rate limit (using tankId as user identifier for now)
    const rateLimit = await checkRateLimit(env, tankId);

    if (!rateLimit.allowed) {
      return new Response(
        JSON.stringify({
          error: 'Rate limit exceeded',
          message: 'Free tier limit of 3 analyses per month reached. Upgrade for unlimited access.',
        }),
        {
          status: 429,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    // Build AI prompt for water chemistry analysis
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

    // Call AI Gateway for analysis
    const aiResponse = await callAIGateway(env, prompt);

    return new Response(
      JSON.stringify({
        success: true,
        tankId,
        analysis: JSON.parse(aiResponse),
        rateLimitRemaining: rateLimit.remaining,
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('Analysis error:', error);
    return new Response(
      JSON.stringify({
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error',
      }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      }
    );
  }
}

/**
 * Health check endpoint
 */
function handleHealth(env: Env): Response {
  return new Response(
    JSON.stringify({
      status: 'healthy',
      service: 'ReefBuddy API',
      version: '1.0.0',
      environment: env.ENVIRONMENT || 'unknown',
      timestamp: new Date().toISOString(),
    }),
    {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    }
  );
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
      'Access-Control-Allow-Headers': 'Content-Type',
    };

    // Handle CORS preflight
    if (method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    // Route handling
    let response: Response;

    switch (true) {
      case pathname === '/' && method === 'GET':
        response = new Response(
          JSON.stringify({
            service: 'ReefBuddy API',
            version: '1.0.0',
            description: 'Water chemistry analysis for saltwater aquariums',
            endpoints: {
              'GET /': 'This information',
              'GET /health': 'Health check',
              'POST /analyze': 'Analyze water parameters and get dosing recommendations',
            },
          }),
          {
            status: 200,
            headers: { 'Content-Type': 'application/json' },
          }
        );
        break;

      case pathname === '/health' && method === 'GET':
        response = handleHealth(env);
        break;

      case pathname === '/analyze' && method === 'POST':
        response = await handleAnalysis(request, env);
        break;

      default:
        response = new Response(
          JSON.stringify({
            error: 'Not found',
            message: `Route ${method} ${pathname} does not exist`,
          }),
          {
            status: 404,
            headers: { 'Content-Type': 'application/json' },
          }
        );
    }

    // Add CORS headers to response
    Object.entries(corsHeaders).forEach(([key, value]) => {
      response.headers.set(key, value);
    });

    return response;
  },
} satisfies ExportedHandler<Env>;
