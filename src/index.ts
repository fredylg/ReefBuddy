/**
 * ReefBuddy - Cloudflare Worker
 * Backend for saltwater aquarium water chemistry analysis and dosing recommendations
 *
 * @edge-engineer owns this file
 */

// @peculiar/x509 (credits/storekit.ts) uses tsyringe, which needs the Reflect metadata polyfill
// evaluated before it. Keep this the first import of the entry point.
import 'reflect-metadata';
import { authenticateRequest, resolveActor } from './auth/session';
import { handleCreditsPurchase } from './credits/storekit';
import { AuthenticatedContext, Env, isValidDeviceId } from './env';
import {
  ALLOWED_ORIGINS,
  CORS_HEADERS,
  SECURITY_HEADERS,
  checkIPRateLimit,
  debugLog,
  errorResponse,
  internalError,
  jsonResponse,
  setDebugLogging,
} from './http';
import { handleAnalysis, handleHealth } from './routes/analysis';
import { handleLogin, handleLogout, handleSignup } from './routes/auth';
import { handleGetCreditsBalance } from './routes/credits';
import { handleExportCSV, handleGetAverages, handleGetHistory, handleGetTrends } from './routes/history';
import {
  handleCreateLivestock,
  handleCreateLivestockLog,
  handleDeleteLivestock,
  handleGetLivestockLogs,
  handleListLivestock,
  handleUpdateLivestock,
} from './routes/livestock';
import {
  handleCreateMaintenanceSchedule,
  handleDeleteMaintenanceSchedule,
  handleListMaintenanceSchedules,
  handleUpdateMaintenanceSchedule,
} from './routes/maintenance';
import { handleCreateMeasurement } from './routes/measurements';
import {
  handleGetNotificationHistory,
  handleGetNotificationSettings,
  handleMarkNotificationsRead,
  handleRegisterPushToken,
  handleUnregisterPushToken,
  handleUpdateNotificationSettings,
} from './routes/notifications';
import { handleCreateTank, handleDeleteTank, handleGetTank, handleListTanks, handleUpdateTank } from './routes/tanks';
import { handleCreateWaterChange, handleDeleteWaterChange, handleListWaterChanges } from './routes/water-changes';

export type { Env } from './env';

// =============================================================================
// MAIN WORKER EXPORT (ES MODULES FORMAT)
// =============================================================================

// =============================================================================
// ROUTER
// =============================================================================

type RouteAuth = 'none' | 'session' | 'actor';
type RateScope = 'auth' | 'device';

interface RouteContext {
  request: Request;
  env: Env;
  params: string[];
  auth: AuthenticatedContext | null;
  deviceId: string | null;
}

interface Route {
  method: 'GET' | 'POST' | 'PUT' | 'DELETE';
  path: string | RegExp;
  auth: RouteAuth;
  /** Extra IP rate limit bucket for unauthenticated or write-heavy routes. */
  rate?: RateScope;
  handler: (c: RouteContext) => Promise<Response> | Response;
}

const RATE_LIMITS: Record<RateScope, { max: number; windowMs: number }> = {
  auth: { max: 10, windowMs: 60_000 },
  device: { max: 60, windowMs: 60_000 },
};

const ID = '([a-f0-9-]+)'; // pathnames are lowercased before matching, so UUIDs match in any case

const ROUTES: Route[] = [
  { method: 'GET', path: '/', auth: 'none', handler: () => handleRoot() },
  { method: 'GET', path: '/health', auth: 'none', handler: (c) => handleHealth(c.env) },

  // Accounts (kept for a future login feature, P-01 b)
  { method: 'POST', path: '/auth/signup', auth: 'none', rate: 'auth', handler: (c) => handleSignup(c.request, c.env) },
  { method: 'POST', path: '/auth/login', auth: 'none', rate: 'auth', handler: (c) => handleLogin(c.request, c.env) },
  { method: 'POST', path: '/auth/logout', auth: 'none', handler: (c) => handleLogout(c.request, c.env) },

  // Tanks
  {
    method: 'GET',
    path: '/api/tanks',
    auth: 'actor',
    rate: 'device',
    handler: (c) => handleListTanks(c.env, c.auth, c.deviceId),
  },
  {
    method: 'POST',
    path: '/api/tanks',
    auth: 'actor',
    rate: 'device',
    handler: (c) => handleCreateTank(c.request, c.env, c.auth, c.deviceId),
  },
  {
    method: 'GET',
    path: new RegExp(`^/api/tanks/${ID}$`),
    auth: 'actor',
    rate: 'device',
    handler: (c) => handleGetTank(c.env, c.auth!, c.params[0]),
  },
  {
    method: 'PUT',
    path: new RegExp(`^/api/tanks/${ID}$`),
    auth: 'actor',
    rate: 'device',
    handler: (c) => handleUpdateTank(c.request, c.env, c.auth!, c.params[0]),
  },
  {
    method: 'DELETE',
    path: new RegExp(`^/api/tanks/${ID}$`),
    auth: 'actor',
    rate: 'device',
    handler: (c) => handleDeleteTank(c.env, c.auth!, c.params[0]),
  },

  // Measurements and analysis
  {
    method: 'POST',
    path: '/api/measurements',
    auth: 'actor',
    rate: 'device',
    handler: (c) => handleCreateMeasurement(c.request, c.env, c.auth!),
  },
  { method: 'POST', path: '/analyze', auth: 'none', handler: (c) => handleAnalysis(c.request, c.env) }, // own 10/min limiter + credits

  // Credits
  {
    method: 'GET',
    path: '/credits/balance',
    auth: 'none',
    rate: 'device',
    handler: (c) => handleGetCreditsBalance(c.request, c.env),
  },
  {
    method: 'POST',
    path: '/credits/purchase',
    auth: 'none',
    rate: 'device',
    handler: (c) => handleCreditsPurchase(c.request, c.env),
  },

  // History (P-03 a: device-facing)
  {
    method: 'GET',
    path: new RegExp(`^/tanks/${ID}/history$`),
    auth: 'actor',
    rate: 'device',
    handler: (c) => handleGetHistory(c.request, c.env, c.auth!, c.params[0]),
  },
  {
    method: 'GET',
    path: new RegExp(`^/tanks/${ID}/trends$`),
    auth: 'actor',
    rate: 'device',
    handler: (c) => handleGetTrends(c.request, c.env, c.auth!, c.params[0]),
  },
  {
    method: 'GET',
    path: new RegExp(`^/tanks/${ID}/averages$`),
    auth: 'actor',
    rate: 'device',
    handler: (c) => handleGetAverages(c.request, c.env, c.auth!, c.params[0]),
  },
  {
    method: 'GET',
    path: new RegExp(`^/tanks/${ID}/export$`),
    auth: 'actor',
    rate: 'device',
    handler: (c) => handleExportCSV(c.request, c.env, c.auth!, c.params[0]),
  },

  // Maintenance schedules and water changes
  {
    method: 'GET',
    path: '/maintenance/schedules',
    auth: 'actor',
    rate: 'device',
    handler: (c) => handleListMaintenanceSchedules(c.request, c.env, c.auth!),
  },
  {
    method: 'POST',
    path: '/maintenance/schedules',
    auth: 'actor',
    rate: 'device',
    handler: (c) => handleCreateMaintenanceSchedule(c.request, c.env, c.auth!),
  },
  {
    method: 'PUT',
    path: new RegExp(`^/maintenance/schedules/${ID}$`),
    auth: 'actor',
    rate: 'device',
    handler: (c) => handleUpdateMaintenanceSchedule(c.request, c.env, c.auth!, c.params[0]),
  },
  {
    method: 'DELETE',
    path: new RegExp(`^/maintenance/schedules/${ID}$`),
    auth: 'actor',
    rate: 'device',
    handler: (c) => handleDeleteMaintenanceSchedule(c.env, c.auth!, c.params[0]),
  },
  {
    method: 'POST',
    path: new RegExp(`^/api/tanks/${ID}/water-changes$`),
    auth: 'actor',
    rate: 'device',
    handler: (c) => handleCreateWaterChange(c.request, c.env, c.auth!, c.params[0]),
  },
  {
    method: 'GET',
    path: new RegExp(`^/api/tanks/${ID}/water-changes$`),
    auth: 'actor',
    rate: 'device',
    handler: (c) => handleListWaterChanges(c.request, c.env, c.auth!, c.params[0]),
  },
  {
    method: 'DELETE',
    path: new RegExp(`^/api/water-changes/${ID}$`),
    auth: 'actor',
    rate: 'device',
    handler: (c) => handleDeleteWaterChange(c.env, c.auth!, c.params[0]),
  },

  // Livestock (the /api family is what the app calls)
  {
    method: 'POST',
    path: new RegExp(`^/api/tanks/${ID}/livestock$`),
    auth: 'actor',
    rate: 'device',
    handler: (c) => handleCreateLivestock(c.request, c.env, c.auth!, c.params[0]),
  },
  {
    method: 'GET',
    path: new RegExp(`^/api/tanks/${ID}/livestock$`),
    auth: 'actor',
    rate: 'device',
    handler: (c) => handleListLivestock(c.env, c.auth!, c.params[0]),
  },
  {
    method: 'PUT',
    path: new RegExp(`^/api/livestock/${ID}$`),
    auth: 'actor',
    rate: 'device',
    handler: (c) => handleUpdateLivestock(c.request, c.env, c.auth!, c.params[0]),
  },
  {
    method: 'DELETE',
    path: new RegExp(`^/api/livestock/${ID}$`),
    auth: 'actor',
    rate: 'device',
    handler: (c) => handleDeleteLivestock(c.env, c.auth!, c.params[0]),
  },
  {
    method: 'POST',
    path: new RegExp(`^/api/livestock/${ID}/logs$`),
    auth: 'actor',
    rate: 'device',
    handler: (c) => handleCreateLivestockLog(c.request, c.env, c.auth!, c.params[0]),
  },
  {
    method: 'GET',
    path: new RegExp(`^/api/livestock/${ID}/logs$`),
    auth: 'actor',
    rate: 'device',
    handler: (c) => handleGetLivestockLogs(c.env, c.auth!, c.params[0]),
  },

  // Notifications (session only; push is a separate plan, P-02)
  {
    method: 'POST',
    path: '/notifications/token',
    auth: 'session',
    handler: (c) => handleRegisterPushToken(c.request, c.env, c.auth!),
  },
  {
    method: 'DELETE',
    path: '/notifications/token',
    auth: 'session',
    handler: (c) => handleUnregisterPushToken(c.request, c.env, c.auth!),
  },
  {
    method: 'GET',
    path: '/notifications/settings',
    auth: 'session',
    handler: (c) => handleGetNotificationSettings(c.env, c.auth!),
  },
  {
    method: 'PUT',
    path: '/notifications/settings',
    auth: 'session',
    handler: (c) => handleUpdateNotificationSettings(c.request, c.env, c.auth!),
  },
  {
    method: 'GET',
    path: '/notifications/history',
    auth: 'session',
    handler: (c) => handleGetNotificationHistory(c.request, c.env, c.auth!),
  },
  {
    method: 'POST',
    path: '/notifications/read',
    auth: 'session',
    handler: (c) => handleMarkNotificationsRead(c.request, c.env, c.auth!),
  },
];

function handleRoot(): Response {
  const endpoints: Record<string, string> = {};
  for (const r of ROUTES) {
    const path =
      typeof r.path === 'string'
        ? r.path
        : r.path.source
            .replace(/^\^|\$$/g, '')
            .replace(/\(\[a-f0-9-\]\+\)/g, ':id')
            .replace(/\\\//g, '/');
    endpoints[`${r.method} ${path}`] =
      r.auth === 'session' ? 'session required' : r.auth === 'actor' ? 'session or X-Device-ID' : 'public';
  }
  return jsonResponse({
    service: 'ReefBuddy API',
    version: '1.0.6',
    description: 'Water chemistry analysis for saltwater aquariums',
    endpoints,
  });
}

function matchRoute(method: string, pathname: string): { route: Route; params: string[] } | null {
  for (const route of ROUTES) {
    if (route.method !== method) continue;
    if (typeof route.path === 'string') {
      if (route.path === pathname) return { route, params: [] };
    } else {
      const m = pathname.match(route.path);
      if (m) return { route, params: m.slice(1) };
    }
  }
  return null;
}

function corsOriginFor(request: Request): string | null {
  const origin = request.headers.get('Origin');
  if (!origin) return null; // native app and server-to-server: no CORS headers needed
  return ALLOWED_ORIGINS.includes(origin) ? origin : null;
}

export default {
  async fetch(request: Request, env: Env, _ctx: ExecutionContext): Promise<Response> {
    setDebugLogging(env.ENVIRONMENT !== 'production');

    const url = new URL(request.url);
    // Lowercase once: route literals are lowercase and UUIDs from iOS arrive uppercase (P3-01).
    const pathname = url.pathname.toLowerCase();
    const method = request.method;
    const requestId = request.headers.get('cf-ray') || crypto.randomUUID();
    const allowedOrigin = corsOriginFor(request);

    const finalize = (response: Response): Response => {
      const headers = response.headers;
      for (const [k, v] of Object.entries({ ...CORS_HEADERS, ...SECURITY_HEADERS })) headers.set(k, v);
      if (allowedOrigin) {
        headers.set('Access-Control-Allow-Origin', allowedOrigin);
        headers.set('Vary', 'Origin');
      } else {
        headers.delete('Access-Control-Allow-Origin');
      }
      headers.set('X-Request-Id', requestId);
      return response;
    };

    debugLog(`${method} ${pathname} [${requestId}]`);

    if (method === 'OPTIONS') {
      return finalize(new Response(null, { status: 204 }));
    }

    const matched = matchRoute(method, pathname);
    if (!matched) {
      return finalize(errorResponse('Not found', `Route ${method} ${pathname} does not exist`, 404));
    }
    const { route, params } = matched;

    try {
      if (route.rate) {
        const ip = request.headers.get('CF-Connecting-IP') || request.headers.get('X-Forwarded-For') || 'unknown';
        const limit = RATE_LIMITS[route.rate];
        const rl = await checkIPRateLimit(env, ip, limit.max, limit.windowMs, route.rate);
        if (!rl.allowed) {
          return finalize(
            jsonResponse(
              {
                error: 'Rate limit exceeded',
                message: 'Too many requests. Please wait before trying again.',
                resetAt: new Date(rl.resetAt).toISOString(),
              },
              429
            )
          );
        }
      }

      let auth: AuthenticatedContext | null = null;
      if (route.auth === 'session') {
        const result = await authenticateRequest(request, env);
        if (result instanceof Response) return finalize(result);
        auth = result;
      } else if (route.auth === 'actor') {
        const result = await resolveActor(request, env);
        if (result instanceof Response) return finalize(result);
        auth = result;
      }

      const deviceId = request.headers.get('X-Device-ID');
      const response = await route.handler({
        request,
        env,
        params,
        auth,
        deviceId: isValidDeviceId(deviceId) ? deviceId : null,
      });
      return finalize(response);
    } catch (error) {
      return finalize(internalError(`${method} ${pathname} [${requestId}]`, error));
    }
  },
} satisfies ExportedHandler<Env>;
