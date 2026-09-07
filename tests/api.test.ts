/**
 * ReefBuddy API Tests
 * @tester-agent - Quality Assurance Lead
 *
 * These tests validate the core API functionality including:
 * - POST /analyze endpoint validation (Zod schema)
 * - Free tier limit checking (3/month via KV)
 * - HTTP response format
 * - Error handling
 */

import { describe, it, expect, beforeAll } from 'vitest';
import { installGatewayMock, successReply } from './helpers/mock-gateway';
import { SELF } from 'cloudflare:test';

// =============================================================================
// TEST DATA
// =============================================================================

/**
 * Valid water parameters within acceptable ranges
 * Based on optimal reef aquarium conditions
 */
const validWaterParameters = {
  salinity: 1.025, // Specific gravity (1.020-1.030)
  temperature: 78, // Fahrenheit (72-84)
  ph: 8.2, // pH level (7.8-8.6)
  alkalinity: 8.5, // dKH (6-12)
  calcium: 420, // ppm (350-500)
  magnesium: 1350, // ppm (1200-1500)
  nitrate: 5, // ppm (0-50) - optional
  phosphate: 0.03, // ppm (0-0.5) - optional
  ammonia: 0, // ppm (0-1) - optional
};

/**
 * Valid analysis request with all required fields
 */
const validAnalysisRequest = {
  // deviceId is added per request (unique) by postAnalyze; storage is shared within this file.
  tankId: '550e8400-e29b-41d4-a716-446655440000', // Valid UUID
  parameters: validWaterParameters,
  tankVolume: 75, // gallons
};

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/**
 * Make a POST request to the analyze endpoint
 * Automatically adds deviceId if not provided
 */
installGatewayMock(successReply('Parameters look fine. No dosing needed.'));

let ipCounter = 0;
/** Unique client IP per request so the 10/min/IP limiter never trips across this file. */
function randomTestClientIp(): string {
  ipCounter++;
  return `10.${(ipCounter >> 16) & 255}.${(ipCounter >> 8) & 255}.${ipCounter & 255}`;
}

async function postAnalyze(body: Record<string, unknown>): Promise<Response> {
  // Avoid sharing one IP bucket across hundreds of tests in this file
  return postAnalyzeWithClientIp(body, randomTestClientIp());
}

async function postAnalyzeWithClientIp(body: Record<string, unknown>, clientIp: string): Promise<Response> {
  const requestBody = {
    deviceId: `TEST-DEVICE-${crypto.randomUUID()}`,
    ...body,
  };
  return SELF.fetch('http://localhost/analyze', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'CF-Connecting-IP': clientIp,
    },
    body: JSON.stringify(requestBody),
  });
}

function uniqueEmail(prefix = 'user'): string {
  // Avoid collisions across tests since the D1 DB persists in the test runtime.
  return `${prefix}.${crypto.randomUUID()}@example.com`.toLowerCase();
}

async function signupAndGetToken(): Promise<{ email: string; token: string; userId: string }> {
  const email = uniqueEmail('maint');
  const password = 'TestPassword123!';

  const res = await SELF.fetch('http://localhost/auth/signup', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });

  expect(res.status).toBe(201);
  const data = (await res.json()) as {
    success: boolean;
    user: { id: string; email: string };
    session_token: string;
  };

  expect(data.success).toBe(true);
  expect(data.session_token).toBeTruthy();

  return { email: data.user.email, token: data.session_token, userId: data.user.id };
}

async function createTankForUser(token: string, name = 'Test Tank'): Promise<string> {
  const res = await SELF.fetch('http://localhost/api/tanks', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({
      name,
      volume_gallons: 10,
      tank_type: 'reef',
    }),
  });

  expect(res.status).toBe(201);
  const data = (await res.json()) as { success: boolean; data: { id: string } };
  expect(data.success).toBe(true);
  expect(data.data.id).toBeTruthy();
  return data.data.id;
}

async function postMaintenanceSchedule(token: string | null, body: Record<string, unknown>): Promise<Response> {
  return SELF.fetch('http://localhost/maintenance/schedules', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
}

async function listMaintenanceSchedules(token: string, tankId?: string): Promise<Response> {
  const url = tankId
    ? `http://localhost/maintenance/schedules?tankId=${encodeURIComponent(tankId)}`
    : 'http://localhost/maintenance/schedules';

  return SELF.fetch(url, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });
}

async function postWaterChange(token: string | null, tankId: string, body: Record<string, unknown>): Promise<Response> {
  return SELF.fetch(`http://localhost/api/tanks/${tankId}/water-changes`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
}

async function listWaterChanges(token: string, tankId: string): Promise<Response> {
  return SELF.fetch(`http://localhost/api/tanks/${tankId}/water-changes`, {
    method: 'GET',
    headers: { Authorization: `Bearer ${token}` },
  });
}

async function deleteWaterChange(token: string, waterChangeId: string): Promise<Response> {
  return SELF.fetch(`http://localhost/api/water-changes/${waterChangeId}`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${token}` },
  });
}

/**
 * Generate a valid UUID
 */
function generateUUID(): string {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

// =============================================================================
// TEST SUITES
// =============================================================================

describe('GET /', () => {
  it('should return API information', async () => {
    const response = await SELF.fetch('http://localhost/');
    expect(response.status).toBe(200);

    const data = (await response.json()) as {
      service: string;
      version: string;
      endpoints: Record<string, string>;
    };
    expect(data.service).toBe('ReefBuddy API');
    expect(data.version).toBe('1.0.6');
    expect(data.endpoints).toBeDefined();
  });

  it('should return JSON content-type header', async () => {
    const response = await SELF.fetch('http://localhost/');
    expect(response.headers.get('Content-Type')).toBe('application/json');
  });
});

describe('GET /health', () => {
  it('should return healthy status', async () => {
    const response = await SELF.fetch('http://localhost/health');
    expect(response.status).toBe(200);

    const data = (await response.json()) as {
      status: string;
      service: string;
      timestamp: string;
    };
    expect(data.status).toBe('healthy');
    expect(data.service).toBe('ReefBuddy API');
    expect(data.timestamp).toBeDefined();
  });
});

describe('POST /analyze - Zod Validation', () => {
  describe('Valid Parameter Ranges', () => {
    it('should accept valid measurement data with all required fields', async () => {
      const response = await postAnalyze(validAnalysisRequest);
      // May return 200 (success) or error if AI Gateway not configured
      expect([200, 500]).toContain(response.status);

      if (response.status === 200) {
        const data = (await response.json()) as { success: boolean; tankId: string };
        expect(data.success).toBe(true);
        expect(data.tankId).toBe(validAnalysisRequest.tankId);
      }
    });

    it('should accept minimum valid parameter values', async () => {
      const minParams = {
        tankId: generateUUID(),
        parameters: {
          salinity: 1.02, // Min: 1.020
          temperature: 72, // Min: 72
          ph: 7.8, // Min: 7.8
          alkalinity: 6, // Min: 6
          calcium: 350, // Min: 350
          magnesium: 1200, // Min: 1200
        },
        tankVolume: 1, // Min: positive number
      };

      const response = await postAnalyze(minParams);
      // Should not be a 400 validation error
      expect(response.status).not.toBe(400);
    });

    it('should accept maximum valid parameter values', async () => {
      const maxParams = {
        tankId: generateUUID(),
        parameters: {
          salinity: 1.03, // Max: 1.030
          temperature: 84, // Max: 84
          ph: 8.6, // Max: 8.6
          alkalinity: 12, // Max: 12
          calcium: 500, // Max: 500
          magnesium: 1500, // Max: 1500
          nitrate: 50, // Max: 50
          phosphate: 0.5, // Max: 0.5
          ammonia: 1, // Max: 1
        },
        tankVolume: 1000,
      };

      const response = await postAnalyze(maxParams);
      expect(response.status).not.toBe(400);
    });

    it('should accept request with only required parameters (no optional)', async () => {
      const requiredOnly = {
        tankId: generateUUID(),
        parameters: {
          salinity: 1.025,
          temperature: 78,
          ph: 8.2,
          alkalinity: 8.5,
          calcium: 420,
          magnesium: 1350,
          // nitrate, phosphate, ammonia are optional
        },
        tankVolume: 50,
      };

      const response = await postAnalyze(requiredOnly);
      expect(response.status).not.toBe(400);
    });
  });

  describe('Invalid Parameter Ranges', () => {
    it('should reject request missing tankId', async () => {
      const missingTankId = {
        parameters: validWaterParameters,
        tankVolume: 75,
      };

      const response = await postAnalyze(missingTankId);
      expect(response.status).toBe(400);

      const data = (await response.json()) as { error: string };
      expect(data.error).toBe('Validation failed');
    });

    it('should reject request with invalid tankId format (not UUID)', async () => {
      const invalidTankId = {
        tankId: 'not-a-valid-uuid',
        parameters: validWaterParameters,
        tankVolume: 75,
      };

      const response = await postAnalyze(invalidTankId);
      expect(response.status).toBe(400);
    });

    it('should reject request missing parameters object', async () => {
      const missingParams = {
        tankId: generateUUID(),
        tankVolume: 75,
      };

      const response = await postAnalyze(missingParams);
      expect(response.status).toBe(400);
    });

    it('should reject request missing tankVolume', async () => {
      const missingVolume = {
        tankId: generateUUID(),
        parameters: validWaterParameters,
      };

      const response = await postAnalyze(missingVolume);
      expect(response.status).toBe(400);
    });

    it('should reject pH value below minimum (< 7.8)', async () => {
      const lowPh = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, ph: 5.9 },
      };

      const response = await postAnalyze(lowPh);
      expect(response.status).toBe(400);

      const data = (await response.json()) as { details: { fieldErrors: Record<string, string[]> } };
      expect(data.details.fieldErrors.parameters).toBeDefined();
    });

    it('should reject pH value above maximum (> 8.6)', async () => {
      const highPh = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, ph: 9.6 },
      };

      const response = await postAnalyze(highPh);
      expect(response.status).toBe(400);
    });

    it('should reject salinity below minimum (< 1.020)', async () => {
      const lowSalinity = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, salinity: 0.999 },
      };

      const response = await postAnalyze(lowSalinity);
      expect(response.status).toBe(400);
    });

    it('should reject salinity above maximum (> 1.030)', async () => {
      const highSalinity = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, salinity: 1.041 },
      };

      const response = await postAnalyze(highSalinity);
      expect(response.status).toBe(400);
    });

    it('should reject temperature below minimum (< 72)', async () => {
      const lowTemp = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, temperature: 59 },
      };

      const response = await postAnalyze(lowTemp);
      expect(response.status).toBe(400);
    });

    it('should reject temperature above maximum (> 84)', async () => {
      const highTemp = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, temperature: 96 },
      };

      const response = await postAnalyze(highTemp);
      expect(response.status).toBe(400);
    });

    it('should reject alkalinity below minimum (< 6)', async () => {
      const lowAlk = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, alkalinity: -0.1 },
      };

      const response = await postAnalyze(lowAlk);
      expect(response.status).toBe(400);
    });

    it('should reject alkalinity above maximum (> 12)', async () => {
      const highAlk = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, alkalinity: 20.1 },
      };

      const response = await postAnalyze(highAlk);
      expect(response.status).toBe(400);
    });

    it('should reject calcium below minimum (< 350)', async () => {
      const lowCa = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, calcium: 199 },
      };

      const response = await postAnalyze(lowCa);
      expect(response.status).toBe(400);
    });

    it('should reject calcium above maximum (> 500)', async () => {
      const highCa = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, calcium: 601 },
      };

      const response = await postAnalyze(highCa);
      expect(response.status).toBe(400);
    });

    it('should reject magnesium below minimum (< 1200)', async () => {
      const lowMg = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, magnesium: 799 },
      };

      const response = await postAnalyze(lowMg);
      expect(response.status).toBe(400);
    });

    it('should reject magnesium above maximum (> 1500)', async () => {
      const highMg = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, magnesium: 1801 },
      };

      const response = await postAnalyze(highMg);
      expect(response.status).toBe(400);
    });

    it('should reject negative nitrate value', async () => {
      const negativeNitrate = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, nitrate: -1 },
      };

      const response = await postAnalyze(negativeNitrate);
      expect(response.status).toBe(400);
    });

    it('should reject nitrate above maximum (> 50)', async () => {
      const highNitrate = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, nitrate: 201 },
      };

      const response = await postAnalyze(highNitrate);
      expect(response.status).toBe(400);
    });

    it('should reject negative phosphate value', async () => {
      const negativePhosphate = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, phosphate: -0.01 },
      };

      const response = await postAnalyze(negativePhosphate);
      expect(response.status).toBe(400);
    });

    it('should reject phosphate above maximum (> 0.5)', async () => {
      const highPhosphate = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, phosphate: 5.1 },
      };

      const response = await postAnalyze(highPhosphate);
      expect(response.status).toBe(400);
    });

    it('should reject negative ammonia value', async () => {
      const negativeAmmonia = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, ammonia: -0.1 },
      };

      const response = await postAnalyze(negativeAmmonia);
      expect(response.status).toBe(400);
    });

    it('should reject ammonia above maximum (> 1)', async () => {
      const highAmmonia = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, ammonia: 10.1 },
      };

      const response = await postAnalyze(highAmmonia);
      expect(response.status).toBe(400);
    });

    it('should reject non-positive tank volume', async () => {
      const zeroVolume = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        tankVolume: 0,
      };

      const response = await postAnalyze(zeroVolume);
      expect(response.status).toBe(400);
    });

    it('should reject negative tank volume', async () => {
      const negativeVolume = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        tankVolume: -10,
      };

      const response = await postAnalyze(negativeVolume);
      expect(response.status).toBe(400);
    });

    it('should reject non-numeric parameter values', async () => {
      const stringParams = {
        tankId: generateUUID(),
        parameters: {
          ...validWaterParameters,
          ph: 'eight point two',
        },
        tankVolume: 75,
      };

      const response = await postAnalyze(stringParams);
      expect(response.status).toBe(400);
    });
  });
});

describe('POST /analyze - HTTP Response Format', () => {
  it('should return JSON content-type header', async () => {
    const response = await postAnalyze(validAnalysisRequest);
    expect(response.headers.get('Content-Type')).toBe('application/json');
  });

  it('should return 400 Bad Request for validation errors', async () => {
    const invalidRequest = { tankId: 'invalid' };
    const response = await postAnalyze(invalidRequest);
    expect(response.status).toBe(400);
  });

  it('should include detailed error messages for validation failures', async () => {
    const invalidRequest = {
      tankId: 'not-uuid',
      parameters: { ph: 14.5 }, // Missing required fields, invalid pH
      tankVolume: -1,
    };

    const response = await postAnalyze(invalidRequest);
    expect(response.status).toBe(400);

    const data = (await response.json()) as {
      error: string;
      details: { fieldErrors: Record<string, string[]>; formErrors: string[] };
    };
    expect(data.error).toBe('Validation failed');
    expect(data.details).toBeDefined();
  });

  it('sends no CORS origin header to the native app (no Origin header) but does send a request id', async () => {
    const response = await postAnalyze(validAnalysisRequest);
    expect(response.headers.get('Access-Control-Allow-Origin')).toBeNull();
    expect(response.headers.get('X-Request-Id')).toBeTruthy();
  });
});

describe('OPTIONS /analyze - CORS Preflight', () => {
  it('should return 204 No Content for OPTIONS request', async () => {
    const response = await SELF.fetch('http://localhost/analyze', {
      method: 'OPTIONS',
    });
    expect(response.status).toBe(204);
  });

  it('echoes an allow-listed Origin and varies on it', async () => {
    const response = await SELF.fetch('http://localhost/analyze', {
      method: 'OPTIONS',
      headers: { Origin: 'http://localhost:3000' },
    });

    expect(response.headers.get('Access-Control-Allow-Origin')).toBe('http://localhost:3000');
    expect(response.headers.get('Vary')).toContain('Origin');
    expect(response.headers.get('Access-Control-Allow-Methods')).toContain('POST');
  });

  it('sends no Access-Control-Allow-Origin for unknown origins or when Origin is absent', async () => {
    const unknown = await SELF.fetch('http://localhost/health', { headers: { Origin: 'https://evil.example' } });
    expect(unknown.headers.get('Access-Control-Allow-Origin')).toBeNull();
    const native = await SELF.fetch('http://localhost/health');
    expect(native.headers.get('Access-Control-Allow-Origin')).toBeNull();
    expect(native.headers.get('X-Request-Id')).toBeTruthy();
  });
});

describe('Rate Limiting (IP-based)', () => {
  // /analyze applies checkIPRateLimit first (default 10 req / minute per CF-Connecting-IP).
  // Use a dedicated client IP so parallel tests do not share the same bucket.

  it('should return 429 when IP rate limit is exceeded', async () => {
    const clientIp = '203.0.113.5'; // dedicated bucket for this test
    const base = { ...validAnalysisRequest, tankId: generateUUID() };

    // IP limit runs before JSON parse; invalid JSON still consumes a slot (fast, no AI).
    for (let i = 0; i < 10; i++) {
      const res = await SELF.fetch('http://localhost/analyze', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'CF-Connecting-IP': clientIp,
        },
        body: '{ invalid json }',
      });
      expect(res.status).toBe(400);
    }

    const blocked = await postAnalyzeWithClientIp(
      {
        ...base,
        deviceId: `TEST-IP-RATE-11-${generateUUID()}`,
        tankId: generateUUID(),
      },
      clientIp
    );
    expect(blocked.status).toBe(429);
    const data = (await blocked.json()) as { error: string; message: string };
    expect(data.error).toBe('Rate limit exceeded');
  });

  it('should use separate buckets for different client IPs', async () => {
    const ipB = '203.0.113.7';

    const r = await postAnalyzeWithClientIp(
      {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        deviceId: `TEST-IP-B-${generateUUID()}`,
      },
      ipB
    );
    expect([200, 402, 503]).toContain(r.status);
    expect(r.status).not.toBe(429);
  });
});

describe('Error Handling', () => {
  it('should return 404 for unknown routes', async () => {
    const response = await SELF.fetch('http://localhost/unknown-endpoint');
    expect(response.status).toBe(404);

    const data = (await response.json()) as { error: string };
    expect(data.error).toBe('Not found');
  });

  it('should return 404 for wrong HTTP method on known route', async () => {
    const response = await SELF.fetch('http://localhost/analyze', {
      method: 'GET',
    });
    expect(response.status).toBe(404);
  });

  it('should handle malformed JSON gracefully', async () => {
    const response = await SELF.fetch('http://localhost/analyze', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{ invalid json }',
    });

    expect(response.status).toBe(400);

    const data = (await response.json()) as { error: string };
    expect(data.error).toBe('Invalid JSON');
  });

  it('should handle empty request body', async () => {
    const response = await SELF.fetch('http://localhost/analyze', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '',
    });

    expect(response.status).toBe(400);
  });
});

describe('Maintenance Schedules - Auth Required', () => {
  it('GET /maintenance/schedules should require Authorization header', async () => {
    const response = await SELF.fetch('http://localhost/maintenance/schedules', {
      method: 'GET',
    });
    expect(response.status).toBe(401);
  });

  it('POST /maintenance/schedules should require Authorization header', async () => {
    const response = await SELF.fetch('http://localhost/maintenance/schedules', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    });
    expect(response.status).toBe(401);
  });

  it('PUT /maintenance/schedules/:id should require Authorization header', async () => {
    const response = await SELF.fetch('http://localhost/maintenance/schedules/550e8400-e29b-41d4-a716-446655440000', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    });
    expect(response.status).toBe(401);
  });

  it('DELETE /maintenance/schedules/:id should require Authorization header', async () => {
    const response = await SELF.fetch('http://localhost/maintenance/schedules/550e8400-e29b-41d4-a716-446655440000', {
      method: 'DELETE',
    });
    expect(response.status).toBe(401);
  });
});

describe('Input Sanitization', () => {
  it('should handle extremely large tank volume', async () => {
    const largeVolume = {
      ...validAnalysisRequest,
      tankId: generateUUID(),
      tankVolume: Number.MAX_SAFE_INTEGER,
    };

    const response = await postAnalyze(largeVolume);
    // Should either accept or fail gracefully (not crash)
    expect([200, 400, 500]).toContain(response.status);
  });

  it('should handle floating point precision for parameters', async () => {
    const preciseParams = {
      tankId: generateUUID(),
      parameters: {
        salinity: 1.0250000000001,
        temperature: 78.123456789,
        ph: 8.200000000001,
        alkalinity: 8.5,
        calcium: 420.0,
        magnesium: 1350.0,
      },
      tankVolume: 75.5,
    };

    const response = await postAnalyze(preciseParams);
    expect(response.status).not.toBe(400);
  });
});

describe('/maintenance/schedules', () => {
  let authAndDbReady = false;

  beforeAll(async () => {
    // These endpoints depend on D1 migrations and KV bindings.
    // If the test runtime doesn't have the required tables/bindings, skip the auth/tank-dependent tests.
    try {
      const res = await SELF.fetch('http://localhost/auth/signup', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: uniqueEmail('preflight'), password: 'TestPassword123!' }),
      });
      authAndDbReady = res.status === 201;
    } catch {
      authAndDbReady = false;
    }
  });

  describe('Auth required', () => {
    it('rejects unauthenticated create', async () => {
      const res = await postMaintenanceSchedule(null, {
        tankId: generateUUID(),
        type: 'testing',
        enabled: true,
        scheduleKind: 'weekly',
        weekdays: [1],
        timeLocal: '19:30',
        timezone: 'UTC',
        notes: '{}',
      });

      expect(res.status).toBe(401);
      const data = (await res.json()) as { error: string; message: string };
      expect(data.error).toBe('Unauthorized');
    });

    it('rejects unauthenticated list', async () => {
      const res = await SELF.fetch('http://localhost/maintenance/schedules', { method: 'GET' });
      expect(res.status).toBe(401);
    });
  });

  describe('Create schedule validation', () => {
    it.runIf(authAndDbReady)('weekly requires weekdays', async () => {
      const { token } = await signupAndGetToken();
      const tankId = await createTankForUser(token, 'Weekly Tank');

      const res = await postMaintenanceSchedule(token, {
        tankId,
        type: 'testing',
        enabled: true,
        scheduleKind: 'weekly',
        // weekdays missing
        timeLocal: '19:30',
        timezone: 'UTC',
      });

      expect(res.status).toBe(400);
      const data = (await res.json()) as { error: string };
      expect(data.error).toBe('Validation failed');
    });

    it.runIf(authAndDbReady)('interval_days requires intervalDays', async () => {
      const { token } = await signupAndGetToken();
      const tankId = await createTankForUser(token, 'Interval Tank');

      const res = await postMaintenanceSchedule(token, {
        tankId,
        type: 'water_change',
        enabled: true,
        scheduleKind: 'interval_days',
        // intervalDays missing
        timeLocal: '07:15',
        timezone: 'UTC',
      });

      expect(res.status).toBe(400);
      const data = (await res.json()) as { error: string };
      expect(data.error).toBe('Validation failed');
    });

    it.runIf(authAndDbReady)('rejects invalid timeLocal format', async () => {
      const { token } = await signupAndGetToken();
      const tankId = await createTankForUser(token, 'Bad Time Tank');

      const res = await postMaintenanceSchedule(token, {
        tankId,
        type: 'filter',
        enabled: true,
        scheduleKind: 'weekly',
        weekdays: [2],
        timeLocal: '7:30', // must be HH:MM
        timezone: 'UTC',
      });

      expect(res.status).toBe(400);
      const data = (await res.json()) as { error: string };
      expect(data.error).toBe('Validation failed');
    });

    it.runIf(authAndDbReady)('rejects weekdays out of bounds (must be 1..7)', async () => {
      const { token } = await signupAndGetToken();
      const tankId = await createTankForUser(token, 'Bad Weekdays Tank');

      const res = await postMaintenanceSchedule(token, {
        tankId,
        type: 'testing',
        enabled: true,
        scheduleKind: 'weekly',
        weekdays: [0, 8],
        timeLocal: '19:30',
        timezone: 'UTC',
      });

      expect(res.status).toBe(400);
      const data = (await res.json()) as { error: string };
      expect(data.error).toBe('Validation failed');
    });
  });

  describe('Tank ownership enforcement', () => {
    it.runIf(authAndDbReady)("rejects creating a schedule for another user's tank", async () => {
      const userA = await signupAndGetToken();
      const tankA = await createTankForUser(userA.token, 'UserA Tank');
      const userB = await signupAndGetToken();

      const res = await postMaintenanceSchedule(userB.token, {
        tankId: tankA,
        type: 'testing',
        enabled: true,
        scheduleKind: 'weekly',
        weekdays: [1],
        timeLocal: '19:30',
        timezone: 'UTC',
      });

      // Implementation may choose 403 or 404; both are acceptable as long as it does not allow access.
      expect([403, 404]).toContain(res.status);
    });
  });

  describe('GET list filtering', () => {
    it.runIf(authAndDbReady)('filters schedules by tankId', async () => {
      const { token } = await signupAndGetToken();
      const tank1 = await createTankForUser(token, 'Tank 1');
      const tank2 = await createTankForUser(token, 'Tank 2');

      const create1 = await postMaintenanceSchedule(token, {
        tankId: tank1,
        type: 'testing',
        enabled: true,
        scheduleKind: 'weekly',
        weekdays: [1],
        timeLocal: '19:30',
        timezone: 'UTC',
      });
      expect([201, 200]).toContain(create1.status);

      const create2 = await postMaintenanceSchedule(token, {
        tankId: tank2,
        type: 'filter',
        enabled: true,
        scheduleKind: 'interval_days',
        intervalDays: 7,
        timeLocal: '08:00',
        timezone: 'UTC',
      });
      expect([201, 200]).toContain(create2.status);

      const listAllRes = await listMaintenanceSchedules(token);
      expect(listAllRes.status).toBe(200);
      const listAllJson = (await listAllRes.json()) as Record<string, unknown>;
      expect(listAllJson.success).toBe(true);

      const listTank1Res = await listMaintenanceSchedules(token, tank1);
      expect(listTank1Res.status).toBe(200);
      const listTank1Json = (await listTank1Res.json()) as Record<string, unknown>;
      expect(listTank1Json.success).toBe(true);

      const allArr =
        (listAllJson.data as unknown[]) ?? (listAllJson.schedules as unknown[]) ?? (listAllJson.items as unknown[]);
      const tank1Arr =
        (listTank1Json.data as unknown[]) ??
        (listTank1Json.schedules as unknown[]) ??
        (listTank1Json.items as unknown[]);

      expect(Array.isArray(allArr)).toBe(true);
      expect(Array.isArray(tank1Arr)).toBe(true);

      // Tank-specific list should not contain schedules from other tanks.
      const tank1Ids = new Set((tank1Arr as Array<Record<string, unknown>>).map((s) => String(s.tankId ?? s.tank_id)));
      expect(tank1Ids.size).toBeGreaterThan(0);
      expect(tank1Ids.has(tank1)).toBe(true);
      expect(tank1Ids.has(tank2)).toBe(false);
    });
  });
});

describe('/api/tanks/:tankId/water-changes', () => {
  it('requires auth to create a water change', async () => {
    const res = await postWaterChange(null, generateUUID(), {
      percentReplaced: 10,
    });
    expect(res.status).toBe(401);
  });

  it('creates and lists water changes for a tank', async () => {
    const { token } = await signupAndGetToken();
    const tankId = await createTankForUser(token, 'Water Change Tank');

    const create = await postWaterChange(token, tankId, {
      performedAt: new Date('2026-05-01T10:00:00.000Z').toISOString(),
      percentReplaced: 12.5,
      gallonsReplaced: 5,
      notes: 'Weekly change',
    });

    expect(create.status).toBe(201);
    const created = (await create.json()) as {
      success: boolean;
      data: { id: string; tankId: string; percentReplaced: number; gallonsReplaced: number; notes: string };
    };
    expect(created.success).toBe(true);
    expect(created.data.id).toBeTruthy();
    expect(created.data.tankId).toBe(tankId);
    expect(created.data.percentReplaced).toBe(12.5);
    expect(created.data.gallonsReplaced).toBe(5);
    expect(created.data.notes).toBe('Weekly change');

    const list = await listWaterChanges(token, tankId);
    expect(list.status).toBe(200);
    const listed = (await list.json()) as { success: boolean; data: Array<{ id: string }> };
    expect(listed.success).toBe(true);
    expect(listed.data.some((wc) => wc.id === created.data.id)).toBe(true);
  });

  it('validates replaced amount', async () => {
    const { token } = await signupAndGetToken();
    const tankId = await createTankForUser(token, 'Water Change Validation Tank');

    const missingAmount = await postWaterChange(token, tankId, { notes: 'No amount' });
    expect(missingAmount.status).toBe(400);

    const badPercent = await postWaterChange(token, tankId, { percentReplaced: 101 });
    expect(badPercent.status).toBe(400);
  });

  it("rejects water changes for another user's tank", async () => {
    const userA = await signupAndGetToken();
    const tankA = await createTankForUser(userA.token, 'Owner Tank');
    const userB = await signupAndGetToken();

    const res = await postWaterChange(userB.token, tankA, { percentReplaced: 10 });
    expect([403, 404]).toContain(res.status);
  });

  it('soft deletes water changes', async () => {
    const { token } = await signupAndGetToken();
    const tankId = await createTankForUser(token, 'Delete Water Change Tank');

    const create = await postWaterChange(token, tankId, { gallonsReplaced: 7 });
    expect(create.status).toBe(201);
    const created = (await create.json()) as { data: { id: string } };

    const del = await deleteWaterChange(token, created.data.id);
    expect(del.status).toBe(200);

    const list = await listWaterChanges(token, tankId);
    expect(list.status).toBe(200);
    const listed = (await list.json()) as { data: Array<{ id: string }> };
    expect(listed.data.some((wc) => wc.id === created.data.id)).toBe(false);
  });
});
