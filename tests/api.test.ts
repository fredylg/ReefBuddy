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

import { describe, it, expect, beforeEach, vi, afterEach } from "vitest";
import {
  env,
  createExecutionContext,
  waitOnExecutionContext,
  SELF,
} from "cloudflare:test";
import worker from "../src/index";

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
  deviceId: "TEST-DEVICE-001", // Device identifier for credits tracking
  tankId: "550e8400-e29b-41d4-a716-446655440000", // Valid UUID
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
async function postAnalyze(body: Record<string, unknown>): Promise<Response> {
  // Ensure deviceId is present (required for the API)
  const requestBody = {
    deviceId: "TEST-DEVICE-001",
    ...body,
  };
  return SELF.fetch("http://localhost/analyze", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(requestBody),
  });
}

/**
 * Generate a valid UUID
 */
function generateUUID(): string {
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === "x" ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

// =============================================================================
// TEST SUITES
// =============================================================================

describe("GET /", () => {
  it("should return API information", async () => {
    const response = await SELF.fetch("http://localhost/");
    expect(response.status).toBe(200);

    const data = (await response.json()) as {
      service: string;
      version: string;
      endpoints: Record<string, string>;
    };
    expect(data.service).toBe("ReefBuddy API");
    expect(data.version).toBe("1.0.0");
    expect(data.endpoints).toBeDefined();
  });

  it("should return JSON content-type header", async () => {
    const response = await SELF.fetch("http://localhost/");
    expect(response.headers.get("Content-Type")).toBe("application/json");
  });
});

describe("GET /health", () => {
  it("should return healthy status", async () => {
    const response = await SELF.fetch("http://localhost/health");
    expect(response.status).toBe(200);

    const data = (await response.json()) as {
      status: string;
      service: string;
      timestamp: string;
    };
    expect(data.status).toBe("healthy");
    expect(data.service).toBe("ReefBuddy API");
    expect(data.timestamp).toBeDefined();
  });
});

describe("POST /analyze - Zod Validation", () => {
  describe("Valid Parameter Ranges", () => {
    it("should accept valid measurement data with all required fields", async () => {
      const response = await postAnalyze(validAnalysisRequest);
      // May return 200 (success) or error if AI Gateway not configured
      expect([200, 500]).toContain(response.status);

      if (response.status === 200) {
        const data = (await response.json()) as { success: boolean; tankId: string };
        expect(data.success).toBe(true);
        expect(data.tankId).toBe(validAnalysisRequest.tankId);
      }
    });

    it("should accept minimum valid parameter values", async () => {
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

    it("should accept maximum valid parameter values", async () => {
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

    it("should accept request with only required parameters (no optional)", async () => {
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

  describe("Invalid Parameter Ranges", () => {
    it("should reject request missing tankId", async () => {
      const missingTankId = {
        parameters: validWaterParameters,
        tankVolume: 75,
      };

      const response = await postAnalyze(missingTankId);
      expect(response.status).toBe(400);

      const data = (await response.json()) as { error: string };
      expect(data.error).toBe("Validation failed");
    });

    it("should reject request with invalid tankId format (not UUID)", async () => {
      const invalidTankId = {
        tankId: "not-a-valid-uuid",
        parameters: validWaterParameters,
        tankVolume: 75,
      };

      const response = await postAnalyze(invalidTankId);
      expect(response.status).toBe(400);
    });

    it("should reject request missing parameters object", async () => {
      const missingParams = {
        tankId: generateUUID(),
        tankVolume: 75,
      };

      const response = await postAnalyze(missingParams);
      expect(response.status).toBe(400);
    });

    it("should reject request missing tankVolume", async () => {
      const missingVolume = {
        tankId: generateUUID(),
        parameters: validWaterParameters,
      };

      const response = await postAnalyze(missingVolume);
      expect(response.status).toBe(400);
    });

    it("should reject pH value below minimum (< 7.8)", async () => {
      const lowPh = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, ph: 7.7 },
      };

      const response = await postAnalyze(lowPh);
      expect(response.status).toBe(400);

      const data = (await response.json()) as { details: { fieldErrors: Record<string, string[]> } };
      expect(data.details.fieldErrors.parameters).toBeDefined();
    });

    it("should reject pH value above maximum (> 8.6)", async () => {
      const highPh = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, ph: 8.7 },
      };

      const response = await postAnalyze(highPh);
      expect(response.status).toBe(400);
    });

    it("should reject salinity below minimum (< 1.020)", async () => {
      const lowSalinity = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, salinity: 1.019 },
      };

      const response = await postAnalyze(lowSalinity);
      expect(response.status).toBe(400);
    });

    it("should reject salinity above maximum (> 1.030)", async () => {
      const highSalinity = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, salinity: 1.031 },
      };

      const response = await postAnalyze(highSalinity);
      expect(response.status).toBe(400);
    });

    it("should reject temperature below minimum (< 72)", async () => {
      const lowTemp = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, temperature: 71 },
      };

      const response = await postAnalyze(lowTemp);
      expect(response.status).toBe(400);
    });

    it("should reject temperature above maximum (> 84)", async () => {
      const highTemp = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, temperature: 85 },
      };

      const response = await postAnalyze(highTemp);
      expect(response.status).toBe(400);
    });

    it("should reject alkalinity below minimum (< 6)", async () => {
      const lowAlk = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, alkalinity: 5.9 },
      };

      const response = await postAnalyze(lowAlk);
      expect(response.status).toBe(400);
    });

    it("should reject alkalinity above maximum (> 12)", async () => {
      const highAlk = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, alkalinity: 12.1 },
      };

      const response = await postAnalyze(highAlk);
      expect(response.status).toBe(400);
    });

    it("should reject calcium below minimum (< 350)", async () => {
      const lowCa = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, calcium: 349 },
      };

      const response = await postAnalyze(lowCa);
      expect(response.status).toBe(400);
    });

    it("should reject calcium above maximum (> 500)", async () => {
      const highCa = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, calcium: 501 },
      };

      const response = await postAnalyze(highCa);
      expect(response.status).toBe(400);
    });

    it("should reject magnesium below minimum (< 1200)", async () => {
      const lowMg = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, magnesium: 1199 },
      };

      const response = await postAnalyze(lowMg);
      expect(response.status).toBe(400);
    });

    it("should reject magnesium above maximum (> 1500)", async () => {
      const highMg = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, magnesium: 1501 },
      };

      const response = await postAnalyze(highMg);
      expect(response.status).toBe(400);
    });

    it("should reject negative nitrate value", async () => {
      const negativeNitrate = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, nitrate: -1 },
      };

      const response = await postAnalyze(negativeNitrate);
      expect(response.status).toBe(400);
    });

    it("should reject nitrate above maximum (> 50)", async () => {
      const highNitrate = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, nitrate: 51 },
      };

      const response = await postAnalyze(highNitrate);
      expect(response.status).toBe(400);
    });

    it("should reject negative phosphate value", async () => {
      const negativePhosphate = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, phosphate: -0.01 },
      };

      const response = await postAnalyze(negativePhosphate);
      expect(response.status).toBe(400);
    });

    it("should reject phosphate above maximum (> 0.5)", async () => {
      const highPhosphate = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, phosphate: 0.51 },
      };

      const response = await postAnalyze(highPhosphate);
      expect(response.status).toBe(400);
    });

    it("should reject negative ammonia value", async () => {
      const negativeAmmonia = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, ammonia: -0.1 },
      };

      const response = await postAnalyze(negativeAmmonia);
      expect(response.status).toBe(400);
    });

    it("should reject ammonia above maximum (> 1)", async () => {
      const highAmmonia = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        parameters: { ...validWaterParameters, ammonia: 1.1 },
      };

      const response = await postAnalyze(highAmmonia);
      expect(response.status).toBe(400);
    });

    it("should reject non-positive tank volume", async () => {
      const zeroVolume = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        tankVolume: 0,
      };

      const response = await postAnalyze(zeroVolume);
      expect(response.status).toBe(400);
    });

    it("should reject negative tank volume", async () => {
      const negativeVolume = {
        ...validAnalysisRequest,
        tankId: generateUUID(),
        tankVolume: -10,
      };

      const response = await postAnalyze(negativeVolume);
      expect(response.status).toBe(400);
    });

    it("should reject non-numeric parameter values", async () => {
      const stringParams = {
        tankId: generateUUID(),
        parameters: {
          ...validWaterParameters,
          ph: "eight point two",
        },
        tankVolume: 75,
      };

      const response = await postAnalyze(stringParams);
      expect(response.status).toBe(400);
    });
  });
});

describe("POST /analyze - HTTP Response Format", () => {
  it("should return JSON content-type header", async () => {
    const response = await postAnalyze(validAnalysisRequest);
    expect(response.headers.get("Content-Type")).toBe("application/json");
  });

  it("should return 400 Bad Request for validation errors", async () => {
    const invalidRequest = { tankId: "invalid" };
    const response = await postAnalyze(invalidRequest);
    expect(response.status).toBe(400);
  });

  it("should include detailed error messages for validation failures", async () => {
    const invalidRequest = {
      tankId: "not-uuid",
      parameters: { ph: 14.5 }, // Missing required fields, invalid pH
      tankVolume: -1,
    };

    const response = await postAnalyze(invalidRequest);
    expect(response.status).toBe(400);

    const data = (await response.json()) as {
      error: string;
      details: { fieldErrors: Record<string, string[]>; formErrors: string[] };
    };
    expect(data.error).toBe("Validation failed");
    expect(data.details).toBeDefined();
  });

  it("should return CORS headers", async () => {
    const response = await postAnalyze(validAnalysisRequest);
    expect(response.headers.get("Access-Control-Allow-Origin")).toBe("*");
  });
});

describe("OPTIONS /analyze - CORS Preflight", () => {
  it("should return 204 No Content for OPTIONS request", async () => {
    const response = await SELF.fetch("http://localhost/analyze", {
      method: "OPTIONS",
    });
    expect(response.status).toBe(204);
  });

  it("should return correct CORS headers", async () => {
    const response = await SELF.fetch("http://localhost/analyze", {
      method: "OPTIONS",
    });

    expect(response.headers.get("Access-Control-Allow-Origin")).toBe("*");
    expect(response.headers.get("Access-Control-Allow-Methods")).toContain("POST");
  });
});

describe("Rate Limiting - Free Tier (3/month)", () => {
  // Note: These tests require KV namespace to be properly bound in test environment
  // The rate limiting uses the tankId as the user identifier

  it("should include rate limit remaining in successful response", async () => {
    const uniqueTankId = generateUUID();
    const request = {
      ...validAnalysisRequest,
      tankId: uniqueTankId,
    };

    const response = await postAnalyze(request);

    // Check if rate limit info is present (when not a validation error)
    if (response.status === 200) {
      const data = (await response.json()) as { rateLimitRemaining: number };
      expect(data.rateLimitRemaining).toBeDefined();
      expect(typeof data.rateLimitRemaining).toBe("number");
    }
  });

  it("should decrement rate limit on each request", async () => {
    const uniqueTankId = generateUUID();
    const request = {
      ...validAnalysisRequest,
      tankId: uniqueTankId,
    };

    // First request
    const response1 = await postAnalyze(request);
    let remaining1 = 2;

    if (response1.status === 200) {
      const data1 = (await response1.json()) as { rateLimitRemaining: number };
      remaining1 = data1.rateLimitRemaining;
    }

    // Second request
    const response2 = await postAnalyze(request);

    if (response2.status === 200) {
      const data2 = (await response2.json()) as { rateLimitRemaining: number };
      expect(data2.rateLimitRemaining).toBe(remaining1 - 1);
    }
  });

  it("should return 429 when rate limit exceeded", async () => {
    const uniqueTankId = generateUUID();
    const request = {
      ...validAnalysisRequest,
      tankId: uniqueTankId,
    };

    // Make 4 requests (limit is 3)
    await postAnalyze(request);
    await postAnalyze(request);
    await postAnalyze(request);
    const response4 = await postAnalyze(request);

    expect(response4.status).toBe(429);
  });

  it("should include upgrade message when rate limit exceeded", async () => {
    const uniqueTankId = generateUUID();
    const request = {
      ...validAnalysisRequest,
      tankId: uniqueTankId,
    };

    // Exhaust rate limit
    await postAnalyze(request);
    await postAnalyze(request);
    await postAnalyze(request);
    const response = await postAnalyze(request);

    expect(response.status).toBe(429);

    const data = (await response.json()) as { error: string; message: string };
    expect(data.error).toBe("Rate limit exceeded");
    expect(data.message).toContain("Upgrade");
  });

  it("should track rate limits per tankId (user)", async () => {
    const tankId1 = generateUUID();
    const tankId2 = generateUUID();

    // Exhaust rate limit for tankId1
    const request1 = { ...validAnalysisRequest, tankId: tankId1 };
    await postAnalyze(request1);
    await postAnalyze(request1);
    await postAnalyze(request1);

    // tankId2 should still have quota
    const request2 = { ...validAnalysisRequest, tankId: tankId2 };
    const response = await postAnalyze(request2);

    expect(response.status).not.toBe(429);
  });

  it("should not count validation failures against rate limit", async () => {
    const uniqueTankId = generateUUID();

    // Make invalid requests (should not count)
    const invalidRequest = {
      tankId: uniqueTankId,
      parameters: { ph: 15 }, // Invalid
      tankVolume: 75,
    };

    await postAnalyze(invalidRequest);
    await postAnalyze(invalidRequest);
    await postAnalyze(invalidRequest);
    await postAnalyze(invalidRequest);

    // Valid request should still work
    const validRequest = {
      ...validAnalysisRequest,
      tankId: uniqueTankId,
    };

    const response = await postAnalyze(validRequest);
    expect(response.status).not.toBe(429);
  });
});

describe("Error Handling", () => {
  it("should return 404 for unknown routes", async () => {
    const response = await SELF.fetch("http://localhost/unknown-endpoint");
    expect(response.status).toBe(404);

    const data = (await response.json()) as { error: string };
    expect(data.error).toBe("Not found");
  });

  it("should return 404 for wrong HTTP method on known route", async () => {
    const response = await SELF.fetch("http://localhost/analyze", {
      method: "GET",
    });
    expect(response.status).toBe(404);
  });

  it("should handle malformed JSON gracefully", async () => {
    const response = await SELF.fetch("http://localhost/analyze", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: "{ invalid json }",
    });

    expect(response.status).toBe(500);

    const data = (await response.json()) as { error: string };
    expect(data.error).toBe("Internal server error");
  });

  it("should handle empty request body", async () => {
    const response = await SELF.fetch("http://localhost/analyze", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: "",
    });

    expect(response.status).toBe(500);
  });
});

describe("Input Sanitization", () => {
  it("should handle extremely large tank volume", async () => {
    const largeVolume = {
      ...validAnalysisRequest,
      tankId: generateUUID(),
      tankVolume: Number.MAX_SAFE_INTEGER,
    };

    const response = await postAnalyze(largeVolume);
    // Should either accept or fail gracefully (not crash)
    expect([200, 400, 500]).toContain(response.status);
  });

  it("should handle floating point precision for parameters", async () => {
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
